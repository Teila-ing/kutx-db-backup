
\restrict csQ0fvkc4RE99X3wYcOXMkhZOhs6Xf1zzdYfdnDR982kmUzfx8V7aTJaORulsWR

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict csQ0fvkc4RE99X3wYcOXMkhZOhs6Xf1zzdYfdnDR982kmUzfx8V7aTJaORulsWR

RESET ALL;
