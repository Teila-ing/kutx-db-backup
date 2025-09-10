
\restrict auvtXFIsAYlHk06lTG7c56Jk0wrBfEKkD3XS8UWtnOdJGpYfurh2ZZ8ZCHAR5Kc

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict auvtXFIsAYlHk06lTG7c56Jk0wrBfEKkD3XS8UWtnOdJGpYfurh2ZZ8ZCHAR5Kc

RESET ALL;
