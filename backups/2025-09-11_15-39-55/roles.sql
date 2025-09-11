
\restrict oDLcEbQMiKLMsiWma5T0Qx5eYRU9n13BilZUJmXQ5QjsU5EhoMvf1nEvtZ7NKCi

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict oDLcEbQMiKLMsiWma5T0Qx5eYRU9n13BilZUJmXQ5QjsU5EhoMvf1nEvtZ7NKCi

RESET ALL;
