
\restrict ucPByYYY9FwLPchDy67G3dhCZdP89qTV7pieLLF1iOYfN9WH1AHIIfEsHIXJx4w


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



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






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



CREATE TABLE IF NOT EXISTS "public"."information_photos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "informations_site_id" "uuid",
    "informations_batiment_id" "uuid",
    "url" "text" NOT NULL,
    "legende" "text",
    "created_by" "uuid",
    "updated_by" "uuid"
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
    "updated_by" "uuid"
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
    "updated_by" "uuid"
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



CREATE TABLE IF NOT EXISTS "public"."plans_batiment" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "batiment_id" "uuid",
    "nom" "text",
    "image_url" "text",
    "created_by" "uuid",
    "updated_by" "uuid",
    "type" "text"
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
    "photo" "text",
    "description" "text",
    "date_creation" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."projets" OWNER TO "postgres";


COMMENT ON TABLE "public"."projets" IS 'Les projets';



COMMENT ON COLUMN "public"."projets"."id" IS 'Identifiant unique du projet';



COMMENT ON COLUMN "public"."projets"."nom" IS 'Nom du projet';



COMMENT ON COLUMN "public"."projets"."adresse" IS 'Adresse du projet';



COMMENT ON COLUMN "public"."projets"."annee_construction" IS 'Année de construction du projet';



COMMENT ON COLUMN "public"."projets"."photo" IS 'URL photo du projet';



COMMENT ON COLUMN "public"."projets"."description" IS 'Description du projet';



COMMENT ON COLUMN "public"."projets"."date_creation" IS 'Date de création du projet';



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



CREATE TABLE IF NOT EXISTS "public"."sites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nom" "text" NOT NULL,
    "projet_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."sites" OWNER TO "postgres";


COMMENT ON TABLE "public"."sites" IS 'Les sites où se situent les bâtiments';



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
    "is_global" boolean DEFAULT true NOT NULL,
    "projet_id" "uuid",
    CONSTRAINT "ck_themes_batiment_global_xor_projet" CHECK ((("is_global" AND ("projet_id" IS NULL)) OR ((NOT "is_global") AND ("projet_id" IS NOT NULL))))
);


ALTER TABLE "public"."themes_batiment" OWNER TO "postgres";


COMMENT ON TABLE "public"."themes_batiment" IS 'Les thèmes liés au bâtiment';



COMMENT ON COLUMN "public"."themes_batiment"."id" IS 'Identifiant unique';



COMMENT ON COLUMN "public"."themes_batiment"."nom" IS 'Nom du thème';



CREATE TABLE IF NOT EXISTS "public"."themes_site" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nom" "text" NOT NULL,
    "is_global" boolean DEFAULT true NOT NULL,
    "projet_id" "uuid",
    CONSTRAINT "ck_themes_site_global_xor_projet" CHECK ((("is_global" AND ("projet_id" IS NULL)) OR ((NOT "is_global") AND ("projet_id" IS NOT NULL))))
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



ALTER TABLE ONLY "public"."batiments"
    ADD CONSTRAINT "batiments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."information_photos"
    ADD CONSTRAINT "diagnostic_photos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."informations_batiment"
    ADD CONSTRAINT "diagnostics_batiment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."informations_site"
    ADD CONSTRAINT "diagnostics_site_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plans_batiment"
    ADD CONSTRAINT "plans_batiment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profils"
    ADD CONSTRAINT "profils_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projets"
    ADD CONSTRAINT "projets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projets_utilisateurs"
    ADD CONSTRAINT "projets_utilisateurs_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."utilisateurs_informations_batiment"
    ADD CONSTRAINT "utilisateurs_informations_batiment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."utilisateurs_informations_site"
    ADD CONSTRAINT "utilisateurs_informations_site_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."batiments"
    ADD CONSTRAINT "batiments_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."batiments"
    ADD CONSTRAINT "batiments_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "public"."sites"("id") ON DELETE CASCADE;



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



ALTER TABLE ONLY "public"."information_photos"
    ADD CONSTRAINT "information_photos_informations_batiment_id_fkey" FOREIGN KEY ("informations_batiment_id") REFERENCES "public"."informations_batiment"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."information_photos"
    ADD CONSTRAINT "information_photos_informations_site_id_fkey" FOREIGN KEY ("informations_site_id") REFERENCES "public"."informations_site"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plans_batiment"
    ADD CONSTRAINT "plans_batiment_batiment_id_fkey" FOREIGN KEY ("batiment_id") REFERENCES "public"."batiments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profils"
    ADD CONSTRAINT "profils_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."profils"
    ADD CONSTRAINT "profils_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id");



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



ALTER TABLE ONLY "public"."themes_batiment"
    ADD CONSTRAINT "themes_batiment_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."themes_site"
    ADD CONSTRAINT "themes_site_projet_id_fkey" FOREIGN KEY ("projet_id") REFERENCES "public"."projets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."utilisateurs_informations_batiment"
    ADD CONSTRAINT "utilisateurs_diagnostics_batiment_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."utilisateurs_informations_site"
    ADD CONSTRAINT "utilisateurs_diagnostics_site_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."utilisateurs_informations_batiment"
    ADD CONSTRAINT "utilisateurs_informations_batiment_information_id_fkey" FOREIGN KEY ("informations_id") REFERENCES "public"."informations_batiment"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."utilisateurs_informations_site"
    ADD CONSTRAINT "utilisateurs_informations_site_informations_id_fkey" FOREIGN KEY ("informations_id") REFERENCES "public"."informations_site"("id") ON DELETE CASCADE;



CREATE POLICY "Enable delete for project members and owners" ON "public"."information_photos" FOR DELETE TO "authenticated" USING (("public"."user_belongs_to_project_with_photo"("id") AND (("auth"."uid"())::"text" = ("created_by")::"text")));



CREATE POLICY "Enable delete for users based on user_id" ON "public"."utilisateurs_informations_batiment" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Enable insert for authenticated users" ON "public"."information_photos" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"())::"text" = ("created_by")::"text"));



CREATE POLICY "Enable insert for authenticated users only" ON "public"."batiments" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."plans_batiment" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."projets_utilisateurs" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."themes_batiment" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."themes_site" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."utilisateurs_informations_batiment" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."utilisateurs_informations_site" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable read access for all users" ON "public"."batiments" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."informations_batiment" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."informations_site" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."plans_batiment" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."projets" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."projets_utilisateurs" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."sites" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."utilisateurs_informations_batiment" FOR SELECT TO "authenticated" USING (true);



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



CREATE POLICY "Enable update for project members and owners" ON "public"."information_photos" FOR UPDATE TO "authenticated" USING (("public"."user_belongs_to_project_with_photo"("id") AND (("auth"."uid"())::"text" = ("created_by")::"text"))) WITH CHECK ((("auth"."uid"())::"text" = ("updated_by")::"text"));



CREATE POLICY "Users can delete batiments" ON "public"."batiments" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete diagnostics" ON "public"."informations_site" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete plans" ON "public"."plans_batiment" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete projets" ON "public"."projets" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete sites" ON "public"."sites" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete their diagnostics" ON "public"."informations_batiment" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can delete their profile" ON "public"."profils" FOR DELETE TO "authenticated" USING (("id" = "auth"."uid"()));



CREATE POLICY "Users can delete their project links" ON "public"."projets_utilisateurs" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



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



CREATE POLICY "Users can update projets" ON "public"."projets" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can update sites" ON "public"."sites" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can update their diagnostics" ON "public"."informations_batiment" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can update their profile" ON "public"."profils" FOR UPDATE TO "authenticated" USING (("id" = "auth"."uid"()));



ALTER TABLE "public"."batiments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."information_photos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."informations_batiment" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."informations_site" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."plans_batiment" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profils" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projets_utilisateurs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sous_themes_batiment" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sous_themes_site" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."themes_batiment" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."themes_site" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."utilisateurs_informations_batiment" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."utilisateurs_informations_site" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































GRANT ALL ON FUNCTION "public"."set_created_by"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_created_by"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_created_by"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_by"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_by"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_by"() TO "service_role";



GRANT ALL ON FUNCTION "public"."user_belongs_to_project_with_photo"("photo_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."user_belongs_to_project_with_photo"("photo_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_belongs_to_project_with_photo"("photo_id" "uuid") TO "service_role";


















GRANT ALL ON TABLE "public"."batiments" TO "anon";
GRANT ALL ON TABLE "public"."batiments" TO "authenticated";
GRANT ALL ON TABLE "public"."batiments" TO "service_role";



GRANT ALL ON TABLE "public"."information_photos" TO "anon";
GRANT ALL ON TABLE "public"."information_photos" TO "authenticated";
GRANT ALL ON TABLE "public"."information_photos" TO "service_role";



GRANT ALL ON TABLE "public"."informations_batiment" TO "anon";
GRANT ALL ON TABLE "public"."informations_batiment" TO "authenticated";
GRANT ALL ON TABLE "public"."informations_batiment" TO "service_role";



GRANT ALL ON TABLE "public"."informations_site" TO "anon";
GRANT ALL ON TABLE "public"."informations_site" TO "authenticated";
GRANT ALL ON TABLE "public"."informations_site" TO "service_role";



GRANT ALL ON TABLE "public"."plans_batiment" TO "anon";
GRANT ALL ON TABLE "public"."plans_batiment" TO "authenticated";
GRANT ALL ON TABLE "public"."plans_batiment" TO "service_role";



GRANT ALL ON TABLE "public"."profils" TO "anon";
GRANT ALL ON TABLE "public"."profils" TO "authenticated";
GRANT ALL ON TABLE "public"."profils" TO "service_role";



GRANT ALL ON TABLE "public"."projets" TO "anon";
GRANT ALL ON TABLE "public"."projets" TO "authenticated";
GRANT ALL ON TABLE "public"."projets" TO "service_role";



GRANT ALL ON TABLE "public"."projets_utilisateurs" TO "anon";
GRANT ALL ON TABLE "public"."projets_utilisateurs" TO "authenticated";
GRANT ALL ON TABLE "public"."projets_utilisateurs" TO "service_role";



GRANT ALL ON TABLE "public"."sites" TO "anon";
GRANT ALL ON TABLE "public"."sites" TO "authenticated";
GRANT ALL ON TABLE "public"."sites" TO "service_role";



GRANT ALL ON TABLE "public"."sous_themes_batiment" TO "anon";
GRANT ALL ON TABLE "public"."sous_themes_batiment" TO "authenticated";
GRANT ALL ON TABLE "public"."sous_themes_batiment" TO "service_role";



GRANT ALL ON TABLE "public"."sous_themes_site" TO "anon";
GRANT ALL ON TABLE "public"."sous_themes_site" TO "authenticated";
GRANT ALL ON TABLE "public"."sous_themes_site" TO "service_role";



GRANT ALL ON TABLE "public"."themes_batiment" TO "anon";
GRANT ALL ON TABLE "public"."themes_batiment" TO "authenticated";
GRANT ALL ON TABLE "public"."themes_batiment" TO "service_role";



GRANT ALL ON TABLE "public"."themes_site" TO "anon";
GRANT ALL ON TABLE "public"."themes_site" TO "authenticated";
GRANT ALL ON TABLE "public"."themes_site" TO "service_role";



GRANT ALL ON TABLE "public"."utilisateurs_informations_batiment" TO "anon";
GRANT ALL ON TABLE "public"."utilisateurs_informations_batiment" TO "authenticated";
GRANT ALL ON TABLE "public"."utilisateurs_informations_batiment" TO "service_role";



GRANT ALL ON TABLE "public"."utilisateurs_informations_site" TO "anon";
GRANT ALL ON TABLE "public"."utilisateurs_informations_site" TO "authenticated";
GRANT ALL ON TABLE "public"."utilisateurs_informations_site" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






























\unrestrict ucPByYYY9FwLPchDy67G3dhCZdP89qTV7pieLLF1iOYfN9WH1AHIIfEsHIXJx4w

RESET ALL;
