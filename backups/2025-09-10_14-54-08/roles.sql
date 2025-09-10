
\restrict koYptiyAw7ayM6JprbrAcPG9SM9iqd8hpBmV0E0W4FOJWyGhm9xNzCIYo5HXWS0

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict koYptiyAw7ayM6JprbrAcPG9SM9iqd8hpBmV0E0W4FOJWyGhm9xNzCIYo5HXWS0

RESET ALL;
