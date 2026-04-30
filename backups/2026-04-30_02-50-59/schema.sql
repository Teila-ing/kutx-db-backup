


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



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






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


CREATE OR REPLACE FUNCTION "public"."set_ref_by_batiment"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO batiment_ref_seq (batiment_id, last_ref)
  VALUES (NEW.batiment_id, 1)
  ON CONFLICT (batiment_id) DO UPDATE
    SET last_ref = batiment_ref_seq.last_ref + 1
  RETURNING last_ref INTO NEW.ref_num;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_ref_by_batiment"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_ref_by_site"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO site_ref_seq (site_id, last_ref)
  VALUES (NEW.site_id, 1)
  ON CONFLICT (site_id) DO UPDATE
    SET last_ref = site_ref_seq.last_ref + 1
  RETURNING last_ref INTO NEW.ref_num;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_ref_by_site"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_by"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_by := auth.uid();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_by"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_belongs_to_project_with_photo"("photo_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$BEGIN
  RETURN EXISTS (
    -- Via site
    SELECT 1
    FROM information_photos ip
    LEFT JOIN informations_site is2 ON ip.informations_site_id = is2.id
    LEFT JOIN sites s ON is2.site_id = s.id
    LEFT JOIN projets p ON s.projet_id = p.id
    LEFT JOIN projets_utilisateurs up ON p.id = up.projet_id
    WHERE ip.id = photo_id
    AND up.user_id = auth.uid()::uuid
  )
  OR EXISTS (
    -- Via bâtiment
    SELECT 1
    FROM information_photos ip
    LEFT JOIN informations_batiment ib ON ip.informations_batiment_id = ib.id
    LEFT JOIN batiments b ON ib.batiment_id = b.id
    LEFT JOIN sites s ON b.site_id = s.id
    LEFT JOIN projets p ON s.projet_id = p.id
    LEFT JOIN projets_utilisateurs up ON p.id = up.projet_id
    WHERE ip.id = photo_id
    AND up.user_id = auth.uid()::uuid
  );
END;$$;


ALTER FUNCTION "public"."user_belongs_to_project_with_photo"("photo_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."batiment_ref_seq" (
    "batiment_id" "uuid" NOT NULL,
    "last_ref" integer DEFAULT 0
);


ALTER TABLE "public"."batiment_ref_seq" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."batiments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "uuid",
    "nom" "text" NOT NULL,
    "usage_actuel" "text",
    "historique" "text",
    "projet_id" "uuid",
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



COMMENT ON COLUMN "public"."batiments"."projet_id" IS 'Projet auquel appartient le bâtiment';



COMMENT ON COLUMN "public"."batiments"."created_at" IS 'Date de création de l''info en BD';



COMMENT ON COLUMN "public"."batiments"."created_by" IS 'Utilisateur créateur';



COMMENT ON COLUMN "public"."batiments"."updated_by" IS 'Utilisateur modificateur';



CREATE TABLE IF NOT EXISTS "public"."commentaires" (
    "formulaire_site_id" "uuid",
    "auteur_id" "uuid" DEFAULT "gen_random_uuid"(),
    "texte" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "date_modification" timestamp without time zone,
    "formulaire_batiment_id" "uuid",
    "id" "uuid" NOT NULL
);


ALTER TABLE "public"."commentaires" OWNER TO "postgres";


COMMENT ON TABLE "public"."commentaires" IS 'Les commentaires des utilisateurs sur une informations';



CREATE TABLE IF NOT EXISTS "public"."documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "projet_id" "uuid" NOT NULL,
    "nom_fichier" "text" NOT NULL,
    "chemin_bucket" "text" NOT NULL,
    "type_document" "text",
    "taille_octets" integer,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "uploaded_by" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "is_valide" boolean DEFAULT false
);


ALTER TABLE "public"."documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."information_photos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "informations_site_id" "uuid",
    "informations_batiment_id" "uuid",
    "url" "text" NOT NULL,
    "legende" "text",
    "created_by" "uuid",
    "updated_by" "uuid",
    "path" "text"
);


ALTER TABLE "public"."information_photos" OWNER TO "postgres";


COMMENT ON TABLE "public"."information_photos" IS 'Lien d''une photo sur une prise d''information';



COMMENT ON COLUMN "public"."information_photos"."id" IS 'Identifiant unique';



COMMENT ON COLUMN "public"."information_photos"."informations_site_id" IS 'Si la photo appartient à une info d''un site';



COMMENT ON COLUMN "public"."information_photos"."informations_batiment_id" IS 'Si la photo appartient à une info d''un bâtiment';



COMMENT ON COLUMN "public"."information_photos"."url" IS 'URL de l''image';



COMMENT ON COLUMN "public"."information_photos"."legende" IS 'Légende de l''image';



COMMENT ON COLUMN "public"."information_photos"."created_by" IS 'Créateur';



COMMENT ON COLUMN "public"."information_photos"."updated_by" IS 'Modificateur';



CREATE TABLE IF NOT EXISTS "public"."informations_batiment" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "batiment_id" "uuid",
    "auteur" "uuid",
    "date" timestamp without time zone DEFAULT "now"(),
    "description" "text",
    "theme_id" "uuid",
    "sous_theme_id" "uuid",
    "impact" integer,
    "plan_id" "uuid",
    "pos_x" double precision,
    "pos_y" double precision,
    "created_by" "uuid",
    "updated_by" "uuid",
    "ref_num" integer
);


ALTER TABLE "public"."informations_batiment" OWNER TO "postgres";


COMMENT ON TABLE "public"."informations_batiment" IS 'Prise d''informations sur un bâtiment';



COMMENT ON COLUMN "public"."informations_batiment"."id" IS 'Identifiant unique';



COMMENT ON COLUMN "public"."informations_batiment"."batiment_id" IS 'Identifiant auquel appartient la prise d''info';



COMMENT ON COLUMN "public"."informations_batiment"."auteur" IS 'Identifiant de l''auteur';



COMMENT ON COLUMN "public"."informations_batiment"."date" IS 'Date de la prise d''info';



COMMENT ON COLUMN "public"."informations_batiment"."description" IS 'Description de la prise d''info';



COMMENT ON COLUMN "public"."informations_batiment"."theme_id" IS 'Identifiant du thème principal de l''info';



COMMENT ON COLUMN "public"."informations_batiment"."sous_theme_id" IS 'Identifiant du sous thème de l''info';



COMMENT ON COLUMN "public"."informations_batiment"."impact" IS 'Impact de l''information';



COMMENT ON COLUMN "public"."informations_batiment"."plan_id" IS 'Identifiant du plan sur lequel l''info est prise';



COMMENT ON COLUMN "public"."informations_batiment"."pos_x" IS 'La position x de l''info prise sur le plan';



COMMENT ON COLUMN "public"."informations_batiment"."pos_y" IS 'La position y de la prise d''info sur le plan';



CREATE TABLE IF NOT EXISTS "public"."informations_site" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "uuid",
    "auteur" "uuid",
    "date" timestamp without time zone DEFAULT "now"(),
    "description" "text",
    "theme_id" "uuid",
    "sous_theme_id" "uuid",
    "impact" integer,
    "latitude" double precision,
    "longitude" double precision,
    "created_by" "uuid",
    "updated_by" "uuid",
    "ref_num" integer
);


ALTER TABLE "public"."informations_site" OWNER TO "postgres";


COMMENT ON TABLE "public"."informations_site" IS 'Prise d''informations sur un site';



COMMENT ON COLUMN "public"."informations_site"."id" IS 'Identifiant unique de la prise d''info';



COMMENT ON COLUMN "public"."informations_site"."site_id" IS 'Identifiant unique du site relié à l''information';



COMMENT ON COLUMN "public"."informations_site"."auteur" IS 'L''auteur de la prise d''info';



COMMENT ON COLUMN "public"."informations_site"."date" IS 'Date de la prise d''info';



COMMENT ON COLUMN "public"."informations_site"."description" IS 'Description de la prise d''info';



COMMENT ON COLUMN "public"."informations_site"."theme_id" IS 'Identifiant du thème principal de la prise d''info';



COMMENT ON COLUMN "public"."informations_site"."sous_theme_id" IS 'Identifiant du sous-thème de l''info';



COMMENT ON COLUMN "public"."informations_site"."impact" IS 'Impact de l''info';



COMMENT ON COLUMN "public"."informations_site"."latitude" IS 'Latitude de la prise d''info sur le site';



COMMENT ON COLUMN "public"."informations_site"."longitude" IS 'Longitude de la prise d''info sur le site';



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "projet_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "titre" "text" NOT NULL,
    "description" "text",
    "is_read" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid" NOT NULL,
    CONSTRAINT "notifications_type_check" CHECK (("type" = ANY (ARRAY['document_review'::"text", 'extracted_info'::"text", 'action_required'::"text"])))
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


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



CREATE TABLE IF NOT EXISTS "public"."profils" (
    "id" "uuid" NOT NULL,
    "nom" "text",
    "prenom" "text",
    "projet_id" "uuid",
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."profils" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nom" "text" NOT NULL,
    "adresse" "text",
    "annee_construction" "text",
    "description" "text",
    "date_creation" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid",
    "active" boolean DEFAULT true NOT NULL,
    "current_phase_name" "text"
);


ALTER TABLE "public"."projets" OWNER TO "postgres";


COMMENT ON TABLE "public"."projets" IS 'Les projets';



COMMENT ON COLUMN "public"."projets"."id" IS 'Identifiant unique du projet';



COMMENT ON COLUMN "public"."projets"."nom" IS 'Nom du projet';



COMMENT ON COLUMN "public"."projets"."adresse" IS 'Adresse du projet';



COMMENT ON COLUMN "public"."projets"."annee_construction" IS 'Année de construction du projet';



COMMENT ON COLUMN "public"."projets"."description" IS 'Description du projet';



COMMENT ON COLUMN "public"."projets"."date_creation" IS 'Date de création du projet';



CREATE TABLE IF NOT EXISTS "public"."projets_phases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "projet_id" "uuid" NOT NULL,
    "ordre" integer DEFAULT 0 NOT NULL,
    "phase_id" "uuid" DEFAULT "gen_random_uuid"()
);


ALTER TABLE "public"."projets_phases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projets_themes_batiments" (
    "projet_id" "uuid" NOT NULL,
    "theme_id" "uuid" NOT NULL
);


ALTER TABLE "public"."projets_themes_batiments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projets_themes_sites" (
    "projet_id" "uuid" NOT NULL,
    "theme_id" "uuid" NOT NULL
);


ALTER TABLE "public"."projets_themes_sites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projets_utilisateurs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "projet_id" "uuid",
    "user_id" "uuid",
    "role" "text"
);


ALTER TABLE "public"."projets_utilisateurs" OWNER TO "postgres";


COMMENT ON TABLE "public"."projets_utilisateurs" IS 'Les utilisateurs participant à des projets';



COMMENT ON COLUMN "public"."projets_utilisateurs"."id" IS 'Identifiant unique de la liaison';



COMMENT ON COLUMN "public"."projets_utilisateurs"."projet_id" IS 'Identifiant du projet';



COMMENT ON COLUMN "public"."projets_utilisateurs"."user_id" IS 'Identifiant de l''utilisateur participant au projet';



COMMENT ON COLUMN "public"."projets_utilisateurs"."role" IS 'Rôle de l''utilisateur dans le projet';



CREATE TABLE IF NOT EXISTS "public"."site_ref_seq" (
    "site_id" "uuid" NOT NULL,
    "last_ref" integer DEFAULT 0
);


ALTER TABLE "public"."site_ref_seq" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nom" "text" NOT NULL,
    "projet_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."sites" OWNER TO "postgres";


COMMENT ON TABLE "public"."sites" IS 'Les adresses où se situent les bâtiments';



COMMENT ON COLUMN "public"."sites"."id" IS 'Identifiant du site';



COMMENT ON COLUMN "public"."sites"."nom" IS 'Nom du site';



COMMENT ON COLUMN "public"."sites"."projet_id" IS 'Identifiant du projet rataché au site';



CREATE TABLE IF NOT EXISTS "public"."sous_themes_batiment" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "theme_id" "uuid",
    "nom" "text" NOT NULL
);


ALTER TABLE "public"."sous_themes_batiment" OWNER TO "postgres";


COMMENT ON TABLE "public"."sous_themes_batiment" IS 'Les sous thèmes liés au bâtiment';



COMMENT ON COLUMN "public"."sous_themes_batiment"."id" IS 'Identifiant unique';



COMMENT ON COLUMN "public"."sous_themes_batiment"."theme_id" IS 'Identifiant du thème lié';



COMMENT ON COLUMN "public"."sous_themes_batiment"."nom" IS 'Le nom du sous thème';



CREATE TABLE IF NOT EXISTS "public"."sous_themes_site" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "theme_id" "uuid",
    "nom" "text" NOT NULL
);


ALTER TABLE "public"."sous_themes_site" OWNER TO "postgres";


COMMENT ON TABLE "public"."sous_themes_site" IS 'Les sous thèmes liés au site';



CREATE TABLE IF NOT EXISTS "public"."themes_batiment" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nom" "text" NOT NULL,
    "is_global" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."themes_batiment" OWNER TO "postgres";


COMMENT ON TABLE "public"."themes_batiment" IS 'Les thèmes liés au bâtiment';



COMMENT ON COLUMN "public"."themes_batiment"."id" IS 'Identifiant unique';



COMMENT ON COLUMN "public"."themes_batiment"."nom" IS 'Nom du thème';



CREATE TABLE IF NOT EXISTS "public"."themes_site" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nom" "text" NOT NULL,
    "is_global" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."themes_site" OWNER TO "postgres";


COMMENT ON TABLE "public"."themes_site" IS 'Les thèmes liés au site';



CREATE TABLE IF NOT EXISTS "public"."utilisateurs_informations_batiment" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "informations_id" "uuid",
    "user_id" "uuid",
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."utilisateurs_informations_batiment" OWNER TO "postgres";


COMMENT ON TABLE "public"."utilisateurs_informations_batiment" IS 'Liens entre les utilisateurs et les infos prise du bâtitment les concernants';



CREATE TABLE IF NOT EXISTS "public"."utilisateurs_informations_site" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "informations_id" "uuid",
    "user_id" "uuid",
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."utilisateurs_informations_site" OWNER TO "postgres";


COMMENT ON TABLE "public"."utilisateurs_informations_site" IS 'Les utilisateurs liés à une prise d''information de site';



COMMENT ON COLUMN "public"."utilisateurs_informations_site"."id" IS 'Identifiant unique';



COMMENT ON COLUMN "public"."utilisateurs_informations_site"."informations_id" IS 'Identifiant de la prise d''information du site';



COMMENT ON COLUMN "public"."utilisateurs_informations_site"."user_id" IS 'Identifiant de l''utilisateur lié à la prise d''information';



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


CREATE TABLE IF NOT EXISTS "public"."v2_projets_themes" (
    "projet_id" "uuid" NOT NULL,
    "theme_name" "text" NOT NULL,
    "used_for" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    CONSTRAINT "check_used_for_values" CHECK (("used_for" <@ ARRAY['site'::"text", 'batiment'::"text", 'document'::"text"]))
);


ALTER TABLE "public"."v2_projets_themes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."v2_releves" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cible_type" "text" NOT NULL,
    "phase_id" "uuid",
    "projet_id" "uuid",
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
    CONSTRAINT "v2_releves_cible_type_check" CHECK (("cible_type" = ANY (ARRAY['site'::"text", 'batiment'::"text", 'document'::"text"])))
);


ALTER TABLE "public"."v2_releves" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."v2_themes" (
    "id" "uuid" NOT NULL,
    "nom" "text" NOT NULL,
    "applicable_a" "text" NOT NULL,
    CONSTRAINT "v2_themes_applicable_a_check" CHECK (("applicable_a" = ANY (ARRAY['site'::"text", 'batiment'::"text"])))
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



ALTER TABLE ONLY "public"."batiment_ref_seq"
    ADD CONSTRAINT "batiment_ref_seq_pkey" PRIMARY KEY ("batiment_id");



ALTER TABLE ONLY "public"."batiments"
    ADD CONSTRAINT "batiments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."commentaires"
    ADD CONSTRAINT "commentaires_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."information_photos"
    ADD CONSTRAINT "diagnostic_photos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."informations_batiment"
    ADD CONSTRAINT "diagnostics_batiment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."informations_site"
    ADD CONSTRAINT "diagnostics_site_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."phases"
    ADD CONSTRAINT "phases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plans_batiment"
    ADD CONSTRAINT "plans_batiment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profils"
    ADD CONSTRAINT "profils_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projets_phases"
    ADD CONSTRAINT "projets_phases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projets_phases"
    ADD CONSTRAINT "projets_phases_projet_id_ordre_key" UNIQUE ("projet_id", "ordre");



ALTER TABLE ONLY "public"."projets"
    ADD CONSTRAINT "projets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projets_themes_batiments"
    ADD CONSTRAINT "projets_themes_batiments_pkey" PRIMARY KEY ("projet_id", "theme_id");



ALTER TABLE ONLY "public"."projets_themes_sites"
    ADD CONSTRAINT "projets_themes_sites_pkey" PRIMARY KEY ("projet_id", "theme_id");



ALTER TABLE ONLY "public"."projets_utilisateurs"
    ADD CONSTRAINT "projets_utilisateurs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_ref_seq"
    ADD CONSTRAINT "site_ref_seq_pkey" PRIMARY KEY ("site_id");



ALTER TABLE ONLY "public"."sites"
    ADD CONSTRAINT "sites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sous_themes_batiment"
    ADD CONSTRAINT "sous_themes_batiment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sous_themes_site"
    ADD CONSTRAINT "sous_themes_site_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."themes_batiment"
    ADD CONSTRAINT "themes_batiment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."themes_site"
    ADD CONSTRAINT "themes_site_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."informations_batiment"
    ADD CONSTRAINT "uq_batiment_ref" UNIQUE ("batiment_id", "ref_num");



ALTER TABLE ONLY "public"."informations_site"
    ADD CONSTRAINT "uq_site_ref" UNIQUE ("site_id", "ref_num");



ALTER TABLE ONLY "public"."utilisateurs_informations_batiment"
    ADD CONSTRAINT "utilisateurs_informations_batiment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."utilisateurs_informations_site"
    ADD CONSTRAINT "utilisateurs_informations_site_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."v2_commentaires"
    ADD CONSTRAINT "v2_commentaires_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."v2_photos"
    ADD CONSTRAINT "v2_photos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."v2_projets_themes"
    ADD CONSTRAINT "v2_projets_themes_pkey" PRIMARY KEY ("projet_id", "theme_name");



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."v2_themes"
    ADD CONSTRAINT "v2_themes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."v2_utilisateurs_releves"
    ADD CONSTRAINT "v2_utilisateurs_releves_pkey" PRIMARY KEY ("releve_id", "user_id");



ALTER TABLE ONLY "public"."zones_plan"
    ADD CONSTRAINT "zones_plan_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_form_batiment_plan_ref" ON "public"."informations_batiment" USING "btree" ("plan_id", "ref_num");



CREATE INDEX "idx_form_site_plan_ref" ON "public"."informations_site" USING "btree" ("site_id", "ref_num");



CREATE INDEX "idx_notif_user_projet" ON "public"."notifications" USING "btree" ("user_id", "projet_id", "is_read", "created_at" DESC);



CREATE INDEX "idx_phases_projet" ON "public"."projets_phases" USING "btree" ("projet_id", "ordre");



CREATE OR REPLACE TRIGGER "set_created_by_batiments" BEFORE INSERT ON "public"."batiments" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_diagnostic_photos" BEFORE INSERT ON "public"."information_photos" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_diagnostics_batiment" BEFORE INSERT ON "public"."informations_batiment" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_diagnostics_site" BEFORE INSERT ON "public"."informations_site" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_plans_batiment" BEFORE INSERT ON "public"."plans_batiment" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_profils" BEFORE INSERT ON "public"."profils" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_projets" BEFORE INSERT ON "public"."projets" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_sites" BEFORE INSERT ON "public"."sites" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_utilisateurs_diagnostics_batiment" BEFORE INSERT ON "public"."utilisateurs_informations_batiment" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_created_by_utilisateurs_diagnostics_site" BEFORE INSERT ON "public"."utilisateurs_informations_site" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_batiments" BEFORE UPDATE ON "public"."batiments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_diagnostic_photos" BEFORE UPDATE ON "public"."information_photos" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_diagnostics_batiment" BEFORE UPDATE ON "public"."informations_batiment" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_diagnostics_site" BEFORE UPDATE ON "public"."informations_site" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_plans_batiment" BEFORE UPDATE ON "public"."plans_batiment" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_profils" BEFORE UPDATE ON "public"."profils" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_projets" BEFORE UPDATE ON "public"."projets" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_sites" BEFORE UPDATE ON "public"."sites" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_utilisateurs_diagnostics_batiment" BEFORE UPDATE ON "public"."utilisateurs_informations_batiment" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "set_updated_by_utilisateurs_diagnostics_site" BEFORE UPDATE ON "public"."utilisateurs_informations_site" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_by"();



CREATE OR REPLACE TRIGGER "trigger_set_ref" BEFORE INSERT ON "public"."informations_batiment" FOR EACH ROW EXECUTE FUNCTION "public"."set_ref_by_batiment"();



CREATE OR REPLACE TRIGGER "trigger_set_ref" BEFORE INSERT ON "public"."informations_site" FOR EACH ROW EXECUTE FUNCTION "public"."set_ref_by_site"();



ALTER TABLE ONLY "public"."batiments"
    ADD CONSTRAINT "batiments_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."batiments"
    ADD CONSTRAINT "batiments_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "public"."sites"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."commentaires"
    ADD CONSTRAINT "commentaires_auteur_id_fkey" FOREIGN KEY ("auteur_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."commentaires"
    ADD CONSTRAINT "commentaires_formulaire_batiment_id_fkey" FOREIGN KEY ("formulaire_batiment_id") REFERENCES "public"."informations_batiment"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."commentaires"
    ADD CONSTRAINT "commentaires_formulaire_site_id_fkey" FOREIGN KEY ("formulaire_site_id") REFERENCES "public"."informations_site"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."informations_batiment"
    ADD CONSTRAINT "diagnostics_batiment_auteur_fkey" FOREIGN KEY ("auteur") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."informations_batiment"
    ADD CONSTRAINT "diagnostics_batiment_batiment_id_fkey" FOREIGN KEY ("batiment_id") REFERENCES "public"."batiments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."informations_batiment"
    ADD CONSTRAINT "diagnostics_batiment_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."plans_batiment"("id");



ALTER TABLE ONLY "public"."informations_batiment"
    ADD CONSTRAINT "diagnostics_batiment_sous_theme_id_fkey" FOREIGN KEY ("sous_theme_id") REFERENCES "public"."sous_themes_batiment"("id");



ALTER TABLE ONLY "public"."informations_batiment"
    ADD CONSTRAINT "diagnostics_batiment_theme_id_fkey" FOREIGN KEY ("theme_id") REFERENCES "public"."themes_batiment"("id");



ALTER TABLE ONLY "public"."informations_site"
    ADD CONSTRAINT "diagnostics_site_auteur_fkey" FOREIGN KEY ("auteur") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."informations_site"
    ADD CONSTRAINT "diagnostics_site_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "public"."sites"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."informations_site"
    ADD CONSTRAINT "diagnostics_site_sous_theme_id_fkey" FOREIGN KEY ("sous_theme_id") REFERENCES "public"."sous_themes_site"("id");



ALTER TABLE ONLY "public"."informations_site"
    ADD CONSTRAINT "diagnostics_site_theme_id_fkey" FOREIGN KEY ("theme_id") REFERENCES "public"."themes_site"("id");



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."information_photos"
    ADD CONSTRAINT "information_photos_informations_batiment_id_fkey" FOREIGN KEY ("informations_batiment_id") REFERENCES "public"."informations_batiment"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."information_photos"
    ADD CONSTRAINT "information_photos_informations_site_id_fkey" FOREIGN KEY ("informations_site_id") REFERENCES "public"."informations_site"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."informations_batiment"
    ADD CONSTRAINT "informations_batiment_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plans_batiment"
    ADD CONSTRAINT "plans_batiment_batiment_id_fkey" FOREIGN KEY ("batiment_id") REFERENCES "public"."batiments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profils"
    ADD CONSTRAINT "profils_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."profils"
    ADD CONSTRAINT "profils_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id");



ALTER TABLE ONLY "public"."projets"
    ADD CONSTRAINT "projets_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."projets_phases"
    ADD CONSTRAINT "projets_phases_phase_id_fkey" FOREIGN KEY ("phase_id") REFERENCES "public"."phases"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projets_phases"
    ADD CONSTRAINT "projets_phases_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projets_themes_batiments"
    ADD CONSTRAINT "projets_themes_batiments_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projets_themes_batiments"
    ADD CONSTRAINT "projets_themes_batiments_theme_id_fkey" FOREIGN KEY ("theme_id") REFERENCES "public"."themes_batiment"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projets_themes_sites"
    ADD CONSTRAINT "projets_themes_sites_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projets_themes_sites"
    ADD CONSTRAINT "projets_themes_sites_theme_id_fkey" FOREIGN KEY ("theme_id") REFERENCES "public"."themes_site"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projets_utilisateurs"
    ADD CONSTRAINT "projets_utilisateurs_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projets_utilisateurs"
    ADD CONSTRAINT "projets_utilisateurs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sites"
    ADD CONSTRAINT "sites_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sous_themes_batiment"
    ADD CONSTRAINT "sous_themes_batiment_theme_id_fkey" FOREIGN KEY ("theme_id") REFERENCES "public"."themes_batiment"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sous_themes_site"
    ADD CONSTRAINT "sous_themes_site_theme_id_fkey" FOREIGN KEY ("theme_id") REFERENCES "public"."themes_site"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."utilisateurs_informations_batiment"
    ADD CONSTRAINT "utilisateurs_diagnostics_batiment_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."utilisateurs_informations_site"
    ADD CONSTRAINT "utilisateurs_diagnostics_site_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."utilisateurs_informations_batiment"
    ADD CONSTRAINT "utilisateurs_informations_batiment_information_id_fkey" FOREIGN KEY ("informations_id") REFERENCES "public"."informations_batiment"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."utilisateurs_informations_site"
    ADD CONSTRAINT "utilisateurs_informations_site_informations_id_fkey" FOREIGN KEY ("informations_id") REFERENCES "public"."informations_site"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_commentaires"
    ADD CONSTRAINT "v2_commentaires_auteur_id_fkey" FOREIGN KEY ("auteur_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."v2_commentaires"
    ADD CONSTRAINT "v2_commentaires_releve_id_fkey" FOREIGN KEY ("releve_id") REFERENCES "public"."v2_releves"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_photos"
    ADD CONSTRAINT "v2_photos_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."v2_photos"
    ADD CONSTRAINT "v2_photos_releve_id_fkey" FOREIGN KEY ("releve_id") REFERENCES "public"."v2_releves"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_projets_themes"
    ADD CONSTRAINT "v2_projets_themes_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_auteur_id_fkey" FOREIGN KEY ("auteur_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_batiment_id_fkey" FOREIGN KEY ("batiment_id") REFERENCES "public"."batiments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "public"."documents"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_phase_id_fkey" FOREIGN KEY ("phase_id") REFERENCES "public"."projets_phases"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."plans_batiment"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_releves"
    ADD CONSTRAINT "v2_releves_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "public"."sites"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_utilisateurs_releves"
    ADD CONSTRAINT "v2_utilisateurs_releves_releve_id_fkey" FOREIGN KEY ("releve_id") REFERENCES "public"."v2_releves"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."v2_utilisateurs_releves"
    ADD CONSTRAINT "v2_utilisateurs_releves_utilisateur_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."zones_plan"
    ADD CONSTRAINT "zones_plans_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."zones_plan"
    ADD CONSTRAINT "zones_plans_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."plans_batiment"("id") ON UPDATE CASCADE ON DELETE CASCADE;



CREATE POLICY "Enable del access for all users" ON "public"."batiment_ref_seq" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable del access for all users" ON "public"."site_ref_seq" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable del for authenticated users only" ON "public"."projets_themes_batiments" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable del for authenticated users only" ON "public"."projets_themes_sites" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable delete for authenticated users only" ON "public"."sous_themes_batiment" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable delete for authenticated users only" ON "public"."sous_themes_site" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable delete for authenticated users only" ON "public"."themes_batiment" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable delete for authenticated users only" ON "public"."themes_site" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Enable delete for project members and owners" ON "public"."information_photos" FOR DELETE TO "authenticated" USING (("public"."user_belongs_to_project_with_photo"("id") AND (("auth"."uid"())::"text" = ("created_by")::"text")));



CREATE POLICY "Enable delete for users based on user_id" ON "public"."commentaires" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "auteur_id"));



CREATE POLICY "Enable delete for users based on user_id" ON "public"."utilisateurs_informations_batiment" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Enable delete for users based on user_id" ON "public"."v2_releves" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "auteur_id"));



CREATE POLICY "Enable delete for users based on user_id" ON "public"."zones_plan" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "created_by"));



CREATE POLICY "Enable insert access for all users" ON "public"."v2_projets_themes" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users" ON "public"."information_photos" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"())::"text" = ("created_by")::"text"));



CREATE POLICY "Enable insert for authenticated users only" ON "public"."batiment_ref_seq" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."batiments" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."commentaires" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."documents" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."plans_batiment" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."projets_phases" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."projets_themes_batiments" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."projets_themes_sites" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."projets_utilisateurs" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."site_ref_seq" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."sous_themes_batiment" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."sous_themes_site" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."themes_batiment" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."themes_site" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."utilisateurs_informations_batiment" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."utilisateurs_informations_site" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."v2_releves" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."v2_utilisateurs_releves" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."zones_plan" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable read access for all users" ON "public"."batiment_ref_seq" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."batiments" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."commentaires" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."documents" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."informations_batiment" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."informations_site" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."phases" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."plans_batiment" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."projets" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."projets_phases" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."projets_themes_batiments" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."projets_themes_sites" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."projets_utilisateurs" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."site_ref_seq" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."sites" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."utilisateurs_informations_batiment" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_commentaires" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_photos" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_projets_themes" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_releves" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_themes" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."v2_utilisateurs_releves" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."zones_plan" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable select for project members" ON "public"."information_photos" FOR SELECT TO "authenticated" USING (
CASE
    WHEN ("informations_site_id" IS NOT NULL) THEN (EXISTS ( SELECT 1
       FROM ((("public"."informations_site" "is2"
         JOIN "public"."sites" "s" ON (("is2"."site_id" = "s"."id")))
         JOIN "public"."projets" "p" ON (("s"."projet_id" = "p"."id")))
         JOIN "public"."projets_utilisateurs" "up" ON (("p"."id" = "up"."projet_id")))
      WHERE (("is2"."id" = "information_photos"."informations_site_id") AND ("up"."user_id" = "auth"."uid"()))))
    WHEN ("informations_batiment_id" IS NOT NULL) THEN (EXISTS ( SELECT 1
       FROM (((("public"."informations_batiment" "ib"
         JOIN "public"."batiments" "b" ON (("ib"."batiment_id" = "b"."id")))
         JOIN "public"."sites" "s" ON (("b"."site_id" = "s"."id")))
         JOIN "public"."projets" "p" ON (("s"."projet_id" = "p"."id")))
         JOIN "public"."projets_utilisateurs" "up" ON (("p"."id" = "up"."projet_id")))
      WHERE (("ib"."id" = "information_photos"."informations_batiment_id") AND ("up"."user_id" = "auth"."uid"()))))
    ELSE false
END);



CREATE POLICY "Enable update access for all users" ON "public"."batiment_ref_seq" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "Enable update access for all users" ON "public"."documents" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "Enable update access for all users" ON "public"."site_ref_seq" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "Enable update access for all users" ON "public"."v2_projets_themes" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update access for all users" ON "public"."v2_releves" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update for authenticated users only" ON "public"."commentaires" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "auteur_id"));



CREATE POLICY "Enable update for authenticated users only" ON "public"."sous_themes_batiment" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update for authenticated users only" ON "public"."sous_themes_site" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update for authenticated users only" ON "public"."themes_batiment" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update for authenticated users only" ON "public"."themes_site" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable update for project members and owners" ON "public"."information_photos" FOR UPDATE TO "authenticated" USING (("public"."user_belongs_to_project_with_photo"("id") AND (("auth"."uid"())::"text" = ("created_by")::"text"))) WITH CHECK ((("auth"."uid"())::"text" = ("updated_by")::"text"));



CREATE POLICY "Enable update for users based on user_id" ON "public"."zones_plan" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "created_by"));



CREATE POLICY "Users can delete batiments" ON "public"."batiments" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete diagnostics" ON "public"."informations_site" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete plans" ON "public"."plans_batiment" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete projets" ON "public"."projets" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete sites" ON "public"."sites" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete their diagnostics" ON "public"."informations_batiment" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete their profile" ON "public"."profils" FOR DELETE TO "authenticated" USING (("id" = "auth"."uid"()));



CREATE POLICY "Users can delete their project links" ON "public"."projets_utilisateurs" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."projets" "p"
  WHERE (("p"."id" = "projets_utilisateurs"."projet_id") AND ("p"."created_by" = "auth"."uid"())))));



CREATE POLICY "Users can delete their site diagnostics" ON "public"."utilisateurs_informations_site" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can insert diagnostics" ON "public"."informations_site" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Users can insert projets" ON "public"."projets" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Users can insert sites" ON "public"."sites" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Users can insert their own diagnostics" ON "public"."informations_batiment" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Users can read sous themes batiment" ON "public"."sous_themes_batiment" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Users can read sous themes site" ON "public"."sous_themes_site" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Users can read their profile" ON "public"."profils" FOR SELECT TO "authenticated" USING (("id" = "auth"."uid"()));



CREATE POLICY "Users can read their site diagnostics" ON "public"."utilisateurs_informations_site" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can read themes batiment" ON "public"."themes_batiment" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Users can read themes site" ON "public"."themes_site" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Users can update batiments" ON "public"."batiments" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can update diagnostics" ON "public"."informations_site" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can update plans" ON "public"."plans_batiment" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can update projets" ON "public"."projets" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "Users can update sites" ON "public"."sites" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can update their profile" ON "public"."profils" FOR UPDATE TO "authenticated" USING (("id" = "auth"."uid"()));



CREATE POLICY "Users see own notifications" ON "public"."notifications" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users update own notifications" ON "public"."notifications" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."batiment_ref_seq" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."batiments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."commentaires" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."information_photos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."informations_batiment" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."informations_site" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."phases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."plans_batiment" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profils" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "projet_utilisateurs update informations_batiments" ON "public"."informations_batiment" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."projets_utilisateurs" "pu"
     JOIN "public"."batiments" "b" ON (("b"."projet_id" = "pu"."projet_id")))
  WHERE (("pu"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("b"."id" = "informations_batiment"."batiment_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."projets_utilisateurs" "pu"
     JOIN "public"."batiments" "b" ON (("b"."projet_id" = "pu"."projet_id")))
  WHERE (("pu"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("b"."id" = "informations_batiment"."batiment_id")))));



ALTER TABLE "public"."projets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projets_phases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projets_themes_batiments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projets_themes_sites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projets_utilisateurs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."site_ref_seq" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sous_themes_batiment" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sous_themes_site" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."themes_batiment" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."themes_site" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."utilisateurs_informations_batiment" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."utilisateurs_informations_site" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_commentaires" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_photos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_projets_themes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_releves" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_themes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."v2_utilisateurs_releves" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."zones_plan" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";








































































































































































GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_created_by"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_created_by"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_created_by"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_ref_by_batiment"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_ref_by_batiment"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_ref_by_batiment"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_ref_by_site"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_ref_by_site"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_ref_by_site"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_by"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_by"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_by"() TO "service_role";



GRANT ALL ON FUNCTION "public"."user_belongs_to_project_with_photo"("photo_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."user_belongs_to_project_with_photo"("photo_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_belongs_to_project_with_photo"("photo_id" "uuid") TO "service_role";


















GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."batiment_ref_seq" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."batiment_ref_seq" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."batiment_ref_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."batiments" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."batiments" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."batiments" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."commentaires" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."commentaires" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."commentaires" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."documents" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."documents" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."documents" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."information_photos" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."information_photos" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."information_photos" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."informations_batiment" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."informations_batiment" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."informations_batiment" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."informations_site" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."informations_site" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."informations_site" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."notifications" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."notifications" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."notifications" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."phases" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."phases" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."phases" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."plans_batiment" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."plans_batiment" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."plans_batiment" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."profils" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."profils" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."profils" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_phases" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_phases" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_phases" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_themes_batiments" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_themes_batiments" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_themes_batiments" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_themes_sites" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_themes_sites" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_themes_sites" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_utilisateurs" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_utilisateurs" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projets_utilisateurs" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."site_ref_seq" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."site_ref_seq" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."site_ref_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sites" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sites" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sites" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sous_themes_batiment" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sous_themes_batiment" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sous_themes_batiment" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sous_themes_site" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sous_themes_site" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sous_themes_site" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."themes_batiment" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."themes_batiment" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."themes_batiment" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."themes_site" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."themes_site" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."themes_site" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."utilisateurs_informations_batiment" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."utilisateurs_informations_batiment" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."utilisateurs_informations_batiment" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."utilisateurs_informations_site" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."utilisateurs_informations_site" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."utilisateurs_informations_site" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_commentaires" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_commentaires" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_commentaires" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_photos" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_photos" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_photos" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_projets_themes" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_projets_themes" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."v2_projets_themes" TO "service_role";



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
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "service_role";



































