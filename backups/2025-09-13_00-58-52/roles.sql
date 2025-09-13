
\restrict t77iBlNjZWmJLyLPG5IhJ0n1pfBdw94u3vrV4PP46AZPbTpfOl4Va2HyLjh9H0r

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict t77iBlNjZWmJLyLPG5IhJ0n1pfBdw94u3vrV4PP46AZPbTpfOl4Va2HyLjh9H0r

RESET ALL;
