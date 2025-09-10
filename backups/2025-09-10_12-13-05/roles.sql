
\restrict Ff4xCfuPYQGhRUOUvwmLDULFAVHSw7pwVX8IiNx2HeD6KjAApaD3iUhwj05r6XC

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict Ff4xCfuPYQGhRUOUvwmLDULFAVHSw7pwVX8IiNx2HeD6KjAApaD3iUhwj05r6XC

RESET ALL;
