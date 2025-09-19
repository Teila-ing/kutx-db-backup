
\restrict aY2yet6rv2olsff6gZka64go9i4JVHuqIoK4XqNhXGX2KLT8oDsqtWCOG3b2vyf

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict aY2yet6rv2olsff6gZka64go9i4JVHuqIoK4XqNhXGX2KLT8oDsqtWCOG3b2vyf

RESET ALL;
