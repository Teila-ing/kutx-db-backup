


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "kutx";


ALTER SCHEMA "kutx" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "hypopg" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "index_advisor" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."project_role_enum" AS ENUM (
    'project_user',
    'project_admin'
);


ALTER TYPE "public"."project_role_enum" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_platform_role"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT kutx_role FROM public.profiles WHERE id = auth.uid();
$$;


ALTER FUNCTION "public"."get_my_platform_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_project_role"("p_id" "uuid") RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT project_role FROM public.project_members 
  WHERE project_id = p_id AND user_id = auth.uid();
$$;


ALTER FUNCTION "public"."get_my_project_role"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_project"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$                                                                              
    BEGIN                                                                              
      INSERT INTO public.project_members (                                             
        project_id,                                                                    
        user_id,                                                                       
        invitation_email,                                                              
        status,                                                                        
        project_role,                                                                  
        role 
      )                                                                                
      VALUES (                                                                         
        NEW.id,                                                                        
        COALESCE(NEW.created_by, auth.uid()),                                          
        (SELECT email FROM auth.users WHERE id = COALESCE(NEW.created_by, auth.uid())),
        'accepted',                                                                    
        'project_admin',                                                               
        NULL                                                                           
      );                                                                               
      RETURN NEW;                                                                      
    END;                                                                               
    $$;


ALTER FUNCTION "public"."handle_new_project"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$BEGIN                                                                       
      -- Idempotent profile write (UPSERT)                                      
      INSERT INTO public.profiles (id, email, first_name, last_name, enterprise,
  job_role,kutx_role)                                                                     
      VALUES (                                                                  
        NEW.id,                                                                 
        NEW.email,                                                              
        NEW.raw_user_meta_data->>'first_name',                                  
        NEW.raw_user_meta_data->>'last_name',                                   
        NEW.raw_user_meta_data->>'enterprise',                                  
        NEW.raw_user_meta_data->>'job_role',
        COALESCE(new.raw_app_meta_data->>'roleUser', 'kutx_user')                                     
      )                                                                         
      ON CONFLICT (id)                                                          
      DO UPDATE SET                                                             
        email = COALESCE(EXCLUDED.email, profiles.email),                       
        first_name = COALESCE(EXCLUDED.first_name, profiles.first_name),        
        last_name = COALESCE(EXCLUDED.last_name, profiles.last_name),           
        enterprise = COALESCE(EXCLUDED.enterprise, profiles.enterprise),        
        job_role = COALESCE(EXCLUDED.job_role, profiles.job_role),
        kutx_role = EXCLUDED.kutx_role;

      IF (TG_OP = 'INSERT') THEN
        UPDATE public.project_members
        SET
          user_id = NEW.id,
          status = CASE
            WHEN NEW.confirmed_at IS NOT NULL THEN 'accepted'
            ELSE 'pending'
          END
        WHERE invitation_email = NEW.email
          AND user_id IS NULL;
      END IF;
  
      IF (TG_OP = 'UPDATE' AND OLD.confirmed_at IS NULL AND NEW.confirmed_at IS NOT NULL) THEN
        UPDATE public.project_members
        SET status = 'accepted'
        WHERE invitation_email = NEW.email
          AND user_id = NEW.id
          AND status = 'pending';
      END IF;

      RETURN NEW;
    END;$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_email_taken"("p_email" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$                                                                              
    BEGIN                                                                              
      RETURN EXISTS (SELECT 1 FROM auth.users WHERE email = p_email);                  
    END;                                                                               
    $$;


ALTER FUNCTION "public"."is_email_taken"("p_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_created_by"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.created_by is null then
    new.created_by := auth.uid();
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."set_created_by"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_by"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_by := auth.uid();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_by"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."batiments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "uuid",
    "nom" "text" NOT NULL,
    "usage_actuel" "text",
    "historique" "text",
    "project_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."batiments" OWNER TO "postgres";


COMMENT ON TABLE "public"."batiments" IS 'Bâtiment et ses informations';



COMMENT ON COLUMN "public"."batiments"."id" IS 'identifiant unique du bâtiment';



COMMENT ON COLUMN "public"."batiments"."site_id" IS 'identifiant du site auquel appartient le bâtiment';



COMMENT ON COLUMN "public"."batiments"."nom" IS 'Nom du bâtiment';



COMMENT ON COLUMN "public"."batiments"."usage_actuel" IS 'Usage actuel du bâtiment';



COMMENT ON COLUMN "public"."batiments"."historique" IS 'Historique du bâtiment';



COMMENT ON COLUMN "public"."batiments"."project_id" IS 'Projet auquel appartient le bâtiment';



COMMENT ON COLUMN "public"."batiments"."created_at" IS 'Date de création de l''info en BD';



COMMENT ON COLUMN "public"."batiments"."created_by" IS 'Utilisateur créateur';



COMMENT ON COLUMN "public"."batiments"."updated_by" IS 'Utilisateur modificateur';



CREATE TABLE IF NOT EXISTS "public"."doc_to_review" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "uploaded_by" "uuid" NOT NULL,
    "doc_name" "text",
    "doc_link" "text",
    "phase_name" "text",
    "project_id" "uuid" NOT NULL,
    "assigned_users" "text"[],
    "review_state" "text" DEFAULT 'to_review'::"text",
    "read_only" boolean DEFAULT false,
    "is_external_upload" boolean DEFAULT false,
    "deadline" "date"
);


ALTER TABLE "public"."doc_to_review" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."doc_to_review_state" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "doc_to_review_id" "uuid" DEFAULT "gen_random_uuid"(),
    "user_id" "uuid" DEFAULT "gen_random_uuid"(),
    "state" "text",
    "updated_at" timestamp without time zone
);


ALTER TABLE "public"."doc_to_review_state" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."phases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nom" "text",
    "ordre" real,
    "type" "text"
);


ALTER TABLE "public"."phases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."plans_batiment" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "batiment_id" "uuid",
    "nom" "text",
    "image_url" "text",
    "created_by" "uuid",
    "updated_by" "uuid",
    "type" "text",
    "ordre" bigint,
    "image_plan_path" "text"
);


ALTER TABLE "public"."plans_batiment" OWNER TO "postgres";


COMMENT ON TABLE "public"."plans_batiment" IS 'Plans des bâtiments';



COMMENT ON COLUMN "public"."plans_batiment"."id" IS 'Identifiant unique du plan';



COMMENT ON COLUMN "public"."plans_batiment"."batiment_id" IS 'Identifiant du bâtiment auquel le plan appartient';



COMMENT ON COLUMN "public"."plans_batiment"."nom" IS 'Nom du plan';



COMMENT ON COLUMN "public"."plans_batiment"."image_url" IS 'URL de l''image du plan';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "updated_at" timestamp with time zone,
    "enterprise" "text",
    "first_name" "text",
    "job_role" "text",
    "last_name" "text",
    "kutx_role" "text" DEFAULT 'kutx_user'::"text",
    "preferences" "jsonb" DEFAULT '{}'::"jsonb",
    CONSTRAINT "check_valid_kutx_role" CHECK (("kutx_role" = ANY (ARRAY['kutx_user'::"text", 'kutx_creator'::"text", 'kutx_super_admin'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."project_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "project_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "invitation_email" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "role" "text",
    "project_role" "public"."project_role_enum" DEFAULT 'project_user'::"public"."project_role_enum"
);


ALTER TABLE "public"."project_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."project_phases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "project_id" "uuid" NOT NULL,
    "ordre" integer DEFAULT 0 NOT NULL,
    "phase_id" "uuid" DEFAULT "gen_random_uuid"()
);


ALTER TABLE "public"."project_phases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nom" "text" NOT NULL,
    "adresse" "text",
    "annee_construction" "text",
    "description" "text",
    "date_creation" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid",
    "active" boolean DEFAULT true NOT NULL,
    "current_phase_name" "text",
    "latitude" double precision,
    "longitude" double precision
);


ALTER TABLE "public"."projects" OWNER TO "postgres";


COMMENT ON TABLE "public"."projects" IS 'Les projets';



COMMENT ON COLUMN "public"."projects"."id" IS 'Identifiant unique du projet';



COMMENT ON COLUMN "public"."projects"."nom" IS 'Nom du projet';



COMMENT ON COLUMN "public"."projects"."adresse" IS 'Adresse du projet';



COMMENT ON COLUMN "public"."projects"."annee_construction" IS 'Année de construction du projet';



COMMENT ON COLUMN "public"."projects"."description" IS 'Description du projet';



COMMENT ON COLUMN "public"."projects"."date_creation" IS 'Date de création du projet';



CREATE TABLE IF NOT EXISTS "public"."releve_field_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "project_id" "uuid" NOT NULL,
    "key" "text" NOT NULL,
    "label" "text" NOT NULL,
    "type" "text" NOT NULL,
    "options" "jsonb",
    "required" boolean DEFAULT false NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "releve_field_config_type_check" CHECK (("type" = ANY (ARRAY['text'::"text", 'number'::"text", 'boolean'::"text", 'select'::"text", 'date'::"text"])))
);


ALTER TABLE "public"."releve_field_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nom" "text" NOT NULL,
    "project_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."sites" OWNER TO "postgres";


COMMENT ON TABLE "public"."sites" IS 'Les adresses où se situent les bâtiments';



COMMENT ON COLUMN "public"."sites"."id" IS 'Identifiant du site';



COMMENT ON COLUMN "public"."sites"."nom" IS 'Nom du site';



COMMENT ON COLUMN "public"."sites"."project_id" IS 'Identifiant du projet rataché au site';



CREATE TABLE IF NOT EXISTS "public"."v2_commentaires" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "releve_id" "uuid" NOT NULL,
    "texte" "text" NOT NULL,
    "auteur_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."v2_commentaires" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."v2_photos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "releve_id" "uuid" NOT NULL,
    "url" "text" NOT NULL,
    "legende" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."v2_photos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."v2_project_themes" (
    "project_id" "uuid" NOT NULL,
    "theme_id" "uuid" NOT NULL,
    "cible" "text" NOT NULL,
    CONSTRAINT "check_cible_values" CHECK (("cible" = ANY (ARRAY['site'::"text", 'batiment'::"text", 'document'::"text"])))
);


ALTER TABLE "public"."v2_project_themes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."v2_releves" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cible_type" "text" NOT NULL,
    "project_id" "uuid",
    "site_id" "uuid",
    "batiment_id" "uuid",
    "plan_id" "uuid",
    "auteur_id" "uuid",
    "pos_x" double precision,
    "pos_y" double precision,
    "impact" integer,
    "description" "text",
    "theme_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "document_id" "uuid",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "phase_name" "text" DEFAULT ''::"text",
    "details" "jsonb" DEFAULT '{}'::"jsonb",
    CONSTRAINT "v2_releves_cible_type_check" CHECK (("cible_type" = ANY (ARRAY['site'::"text", 'batiment'::"text", 'document'::"text"])))
);


ALTER TABLE "public"."v2_releves" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."v2_themes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nom" "text" NOT NULL,
    "applicable_a" "text" NOT NULL,
    "project_id" "uuid",
    CONSTRAINT "v2_themes_applicable_a_check" CHECK (("applicable_a" = ANY (ARRAY['site'::"text", 'batiment'::"text", 'document'::"text"])))
);


ALTER TABLE "public"."v2_themes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."v2_utilisateurs_releves" (
    "releve_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."v2_utilisateurs_releves" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."zones_plan" (
    "type" "text" DEFAULT 'poly'::"text",
    "titre" "text" NOT NULL,
    "points" "jsonb" NOT NULL,
    "plan_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid" DEFAULT "gen_random_uuid"(),
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."zones_plan" OWNER TO "postgres";


COMMENT ON TABLE "public"."zones_plan" IS 'Liste des zones des plans';



ALTER TABLE ONLY "public"."batiments"
    ADD CONSTRAINT "batiments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."doc_to_review"
    ADD CONSTRAINT "doc_to_review_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."doc_to_review_state"
    ADD CONSTRAINT "doc_to_review_state_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."phases"
    ADD CONSTRAINT "phases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plans_batiment"
    ADD CONSTRAINT "plans_batiment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."project_members"
    ADD CONSTRAINT "project_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."project_phases"
    ADD CONSTRAINT "project_phases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."project_phases"
    ADD CONSTRAINT "project_phases_project_id_ordre_key" UNIQUE ("project_id", "ordre");



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."releve_field_config"
    ADD CONSTRAINT "releve_field_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."releve_field_config"
    ADD CONSTRAINT "releve_field_config_project_id_key_key" UNIQUE ("project_id", "key");



ALTER TABLE ONLY "public"."sites"
    ADD CONSTRAINT "sites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."project_members"
    ADD CONSTRAINT "unique_invitation_per_project" UNIQUE ("project_id", "invitation_email");



ALTER TABLE ONLY "public"."project_members"
    ADD CONSTRAINT "unique_project_user" UNIQUE ("project_id", "user_id");



ALTER TABLE ONLY "public"."v2_commentaires"
    ADD CONSTRAINT "v2_commentaires_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."v2_photos"
    ADD CONSTRAINT "v2_photos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."v2_project_themes"
    ADD CONSTRAINT "v2_project_themes_pkey" PRIMARY KEY ("project_id", "theme_id", "cible");



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."v2_themes"
    ADD CONSTRAINT "v2_themes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."v2_utilisateurs_releves"
    ADD CONSTRAINT "v2_utilisateurs_releves_pkey" PRIMARY KEY ("releve_id", "user_id");



ALTER TABLE ONLY "public"."zones_plan"
    ADD CONSTRAINT "zones_plan_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_phases_project" ON "public"."project_phases" USING "btree" ("project_id", "ordre");



CREATE INDEX "idx_project_members_email" ON "public"."project_members" USING "btree" ("invitation_email");



CREATE INDEX "idx_project_members_user_id" ON "public"."project_members" USING "btree" ("user_id");



CREATE INDEX "project_phases_project_id_idx" ON "public"."project_phases" USING "btree" ("project_id");



CREATE INDEX "v2_releves_projet_id_idx" ON "public"."v2_releves" USING "btree" ("project_id");



CREATE OR REPLACE TRIGGER "on_project_created" AFTER INSERT ON "public"."projects" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_project"();



CREATE OR REPLACE TRIGGER "set_created_by_batiments" BEFORE INSERT ON "public"."batiments" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_plans_batiment" BEFORE INSERT ON "public"."plans_batiment" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_projects" BEFORE INSERT ON "public"."projects" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_sites" BEFORE INSERT ON "public"."sites" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_batiments" BEFORE UPDATE ON "public"."batiments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_plans_batiment" BEFORE UPDATE ON "public"."plans_batiment" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_projects" BEFORE UPDATE ON "public"."projects" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_sites" BEFORE UPDATE ON "public"."sites" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



ALTER TABLE ONLY "public"."batiments"
    ADD CONSTRAINT "batiments_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."batiments"
    ADD CONSTRAINT "batiments_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "public"."sites"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."doc_to_review"
    ADD CONSTRAINT "doc_to_review_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."doc_to_review_state"
    ADD CONSTRAINT "doc_to_review_state_doc_to_review_id_fkey" FOREIGN KEY ("doc_to_review_id") REFERENCES "public"."doc_to_review"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."doc_to_review_state"
    ADD CONSTRAINT "doc_to_review_state_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."doc_to_review"
    ADD CONSTRAINT "doc_to_review_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plans_batiment"
    ADD CONSTRAINT "plans_batiment_batiment_id_fkey" FOREIGN KEY ("batiment_id") REFERENCES "public"."batiments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."project_members"
    ADD CONSTRAINT "project_members_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."project_members"
    ADD CONSTRAINT "project_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."project_phases"
    ADD CONSTRAINT "project_phases_phase_id_fkey" FOREIGN KEY ("phase_id") REFERENCES "public"."phases"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."project_phases"
    ADD CONSTRAINT "project_phases_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."releve_field_config"
    ADD CONSTRAINT "releve_field_config_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sites"
    ADD CONSTRAINT "sites_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_commentaires"
    ADD CONSTRAINT "v2_commentaires_auteur_id_fkey" FOREIGN KEY ("auteur_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."v2_commentaires"
    ADD CONSTRAINT "v2_commentaires_releve_id_fkey" FOREIGN KEY ("releve_id") REFERENCES "public"."v2_releves"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_photos"
    ADD CONSTRAINT "v2_photos_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."v2_photos"
    ADD CONSTRAINT "v2_photos_releve_id_fkey" FOREIGN KEY ("releve_id") REFERENCES "public"."v2_releves"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_project_themes"
    ADD CONSTRAINT "v2_project_themes_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_project_themes"
    ADD CONSTRAINT "v2_project_themes_theme_id_fkey" FOREIGN KEY ("theme_id") REFERENCES "public"."v2_themes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_auteur_id_fkey" FOREIGN KEY ("auteur_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_batiment_id_fkey" FOREIGN KEY ("batiment_id") REFERENCES "public"."batiments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "public"."doc_to_review"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."plans_batiment"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "public"."sites"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_themes"
    ADD CONSTRAINT "v2_themes_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_utilisateurs_releves"
    ADD CONSTRAINT "v2_utilisateurs_releves_releve_id_fkey" FOREIGN KEY ("releve_id") REFERENCES "public"."v2_releves"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_utilisateurs_releves"
    ADD CONSTRAINT "v2_utilisateurs_releves_utilisateur_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."zones_plan"
    ADD CONSTRAINT "zones_plans_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."zones_plan"
    ADD CONSTRAINT "zones_plans_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."plans_batiment"("id") ON UPDATE CASCADE ON DELETE CASCADE;



CREATE POLICY "Enable del access for all users" ON "public"."doc_to_review" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable del access for all users" ON "public"."project_phases" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable del access for all users" ON "public"."v2_project_themes" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable del access for all users" ON "public"."v2_themes" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable delete access for all users" ON "public"."v2_photos" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable delete access for all users" ON "public"."v2_utilisateurs_releves" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable delete for users based on user_id" ON "public"."v2_commentaires" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "auteur_id"));



CREATE POLICY "Enable delete for users based on user_id" ON "public"."v2_releves" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "auteur_id"));



CREATE POLICY "Enable delete for users based on user_id" ON "public"."zones_plan" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "created_by"));



CREATE POLICY "Enable full read access to all authenticated users" ON "public"."project_members" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable insert access for all users" ON "public"."doc_to_review_state" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."batiments" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."doc_to_review" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."plans_batiment" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."project_members" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."project_phases" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."v2_commentaires" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."v2_photos" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."v2_project_themes" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."v2_releves" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."v2_themes" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."v2_utilisateurs_releves" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."zones_plan" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable read access for all users" ON "public"."batiments" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."doc_to_review" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."phases" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."plans_batiment" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."project_phases" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."sites" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_commentaires" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_photos" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_project_themes" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_releves" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_themes" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_utilisateurs_releves" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."zones_plan" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable update access for all users" ON "public"."doc_to_review" FOR UPDATE TO "authenticated" USING (("read_only" = false)) WITH CHECK (true);



CREATE POLICY "Enable update access for all users" ON "public"."doc_to_review_state" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update access for all users" ON "public"."project_phases" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update access for all users" ON "public"."v2_photos" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update access for all users" ON "public"."v2_project_themes" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update access for all users" ON "public"."v2_releves" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update access for all users" ON "public"."v2_utilisateurs_releves" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update for authenticated users only" ON "public"."project_members" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update for authenticated users only" ON "public"."v2_commentaires" FOR UPDATE TO "authenticated" USING (true) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "auteur_id"));



CREATE POLICY "Enable update for authenticated users only" ON "public"."v2_themes" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update for users based on user_id" ON "public"."zones_plan" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "created_by"));



CREATE POLICY "Field config - Read by project members or kutx_super_admin" ON "public"."releve_field_config" FOR SELECT TO "authenticated" USING (((( SELECT "public"."get_my_platform_role"() AS "get_my_platform_role") = 'kutx_super_admin'::"text") OR (( SELECT "public"."get_my_project_role"("releve_field_config"."project_id") AS "get_my_project_role") IS NOT NULL)));



CREATE POLICY "Field config - Write by project_admin or kutx_super_admin" ON "public"."releve_field_config" TO "authenticated" USING (((( SELECT "public"."get_my_platform_role"() AS "get_my_platform_role") = 'kutx_super_admin'::"text") OR (( SELECT "public"."get_my_project_role"("releve_field_config"."project_id") AS "get_my_project_role") = 'project_admin'::"text"))) WITH CHECK (((( SELECT "public"."get_my_platform_role"() AS "get_my_platform_role") = 'kutx_super_admin'::"text") OR (( SELECT "public"."get_my_project_role"("releve_field_config"."project_id") AS "get_my_project_role") = 'project_admin'::"text")));



CREATE POLICY "Members - Read members of my project" ON "public"."project_members" FOR SELECT TO "authenticated" USING (((( SELECT "public"."get_my_platform_role"() AS "get_my_platform_role") = 'kutx_super_admin'::"text") OR (( SELECT "public"."get_my_project_role"("project_members"."project_id") AS "get_my_project_role") IS NOT NULL)));



CREATE POLICY "Members - management by project_admin or kutx_super_admin" ON "public"."project_members" TO "authenticated" USING (((( SELECT "public"."get_my_platform_role"() AS "get_my_platform_role") = 'kutx_super_admin'::"text") OR (( SELECT "public"."get_my_project_role"("project_members"."project_id") AS "get_my_project_role") = 'project_admin'::"text")));



CREATE POLICY "Profiles - update by itself or kutx_super_admin" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() = "id") OR (( SELECT "public"."get_my_platform_role"() AS "get_my_platform_role") = 'kutx_super_admin'::"text")));



CREATE POLICY "Projects - Create for kutx_creator or kutx_super_admin" ON "public"."projects" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "public"."get_my_platform_role"() AS "get_my_platform_role") = ANY (ARRAY['kutx_creator'::"text", 'kutx_super_admin'::"text"])));



CREATE POLICY "Projects - Read my projects or kutx_super_admin" ON "public"."projects" FOR SELECT TO "authenticated" USING (((( SELECT "public"."get_my_platform_role"() AS "get_my_platform_role") = 'kutx_super_admin'::"text") OR (( SELECT "public"."get_my_project_role"("projects"."id") AS "get_my_project_role") IS NOT NULL)));



CREATE POLICY "Projects - Update/Delete by project_admin or kutx_super_admin" ON "public"."projects" TO "authenticated" USING (((( SELECT "public"."get_my_platform_role"() AS "get_my_platform_role") = 'kutx_super_admin'::"text") OR (( SELECT "public"."get_my_project_role"("projects"."id") AS "get_my_project_role") = 'project_admin'::"text")));



CREATE POLICY "Users can delete batiments" ON "public"."batiments" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete plans" ON "public"."plans_batiment" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete sites" ON "public"."sites" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can insert sites" ON "public"."sites" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Users can update batiments" ON "public"."batiments" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can update plans" ON "public"."plans_batiment" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can update sites" ON "public"."sites" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can update their own profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can view their own profile" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "Voir les collaborateurs de mes projets" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("id" IN ( SELECT "project_members"."user_id"
   FROM "public"."project_members"
  WHERE ("project_members"."project_id" IN ( SELECT "project_members_1"."project_id"
           FROM "public"."project_members" "project_members_1"
          WHERE ("project_members_1"."user_id" = "auth"."uid"()))))));



ALTER TABLE "public"."batiments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."doc_to_review" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."doc_to_review_state" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "enable delete" ON "public"."doc_to_review_state" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "eneable delete" ON "public"."project_members" FOR DELETE TO "authenticated" USING (true);



ALTER TABLE "public"."phases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."plans_batiment" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."project_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."project_phases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projects" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "read" ON "public"."doc_to_review_state" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."releve_field_config" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_commentaires" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_photos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_project_themes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_releves" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_themes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_utilisateurs_releves" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."zones_plan" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";












































































































































































































GRANT ALL ON FUNCTION "public"."get_my_platform_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_platform_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_platform_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_project_role"("p_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_project_role"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_project_role"("p_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_project"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_project"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_project"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_email_taken"("p_email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."is_email_taken"("p_email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_email_taken"("p_email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_created_by"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_created_by"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_created_by"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_by"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_by"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_by"() TO "service_role";
























GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."batiments" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."batiments" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."batiments" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."doc_to_review" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."doc_to_review" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."doc_to_review" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."doc_to_review_state" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."doc_to_review_state" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."doc_to_review_state" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."phases" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."phases" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."phases" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."plans_batiment" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."plans_batiment" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."plans_batiment" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."profiles" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."profiles" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."project_members" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."project_members" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."project_members" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."project_phases" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."project_phases" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."project_phases" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projects" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projects" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projects" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."releve_field_config" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."releve_field_config" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sites" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sites" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sites" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_commentaires" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_commentaires" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_commentaires" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_photos" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_photos" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_photos" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_project_themes" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_project_themes" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_project_themes" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_releves" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_releves" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_releves" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_themes" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_themes" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_themes" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_utilisateurs_releves" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_utilisateurs_releves" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_utilisateurs_releves" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."zones_plan" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."zones_plan" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."zones_plan" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLES TO "service_role";



































