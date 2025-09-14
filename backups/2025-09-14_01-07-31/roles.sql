
\restrict Sicmizh4ZpQeZpQxTsB2BJKjsSL4EDkLfCl6KBxukfj05bHGLeXwo3klSjpsUws

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict Sicmizh4ZpQeZpQxTsB2BJKjsSL4EDkLfCl6KBxukfj05bHGLeXwo3klSjpsUws

RESET ALL;
