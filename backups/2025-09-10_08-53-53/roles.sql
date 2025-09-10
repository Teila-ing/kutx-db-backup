
\restrict jmCGlxn2asyUQnOa8x2pUZKUnuzxyXsvQav4Q2C8sXoU3rdFZIhsZhUjO9KeYhJ

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict jmCGlxn2asyUQnOa8x2pUZKUnuzxyXsvQav4Q2C8sXoU3rdFZIhsZhUjO9KeYhJ

RESET ALL;
