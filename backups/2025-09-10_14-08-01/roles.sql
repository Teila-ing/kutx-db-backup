
\restrict MTecMuhXZaeLrUpRY3ftDve37SdXa6dxyW1do0RfF4kG1GyLGhC82VGIOhL5xr0

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict MTecMuhXZaeLrUpRY3ftDve37SdXa6dxyW1do0RfF4kG1GyLGhC82VGIOhL5xr0

RESET ALL;
