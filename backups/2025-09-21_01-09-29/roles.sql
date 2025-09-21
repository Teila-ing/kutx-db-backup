
\restrict TJoD5PRfMN3NmZGV7JWbJZ7QSLFIX8nkyeauP6XzZ88QFriax0VlP6Qg2DSVInz

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict TJoD5PRfMN3NmZGV7JWbJZ7QSLFIX8nkyeauP6XzZ88QFriax0VlP6Qg2DSVInz

RESET ALL;
