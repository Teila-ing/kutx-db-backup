
\restrict 7FZgJbr8J84jBFBawChsiNYI8vWVVUk5YB4o0iQh8SNTpZhmPHgNT3qAv1zeW34

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict 7FZgJbr8J84jBFBawChsiNYI8vWVVUk5YB4o0iQh8SNTpZhmPHgNT3qAv1zeW34

RESET ALL;
