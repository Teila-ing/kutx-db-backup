
\restrict MGhty4VEGnhEqp0y5Ape2csrbpkRuYCt9Ic0hvCzqGIcljeaaCBUt9EdH3yr0CE

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict MGhty4VEGnhEqp0y5Ape2csrbpkRuYCt9Ic0hvCzqGIcljeaaCBUt9EdH3yr0CE

RESET ALL;
