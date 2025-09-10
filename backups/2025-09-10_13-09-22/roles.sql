
\restrict Z13ds70Hg6I2bPnBIYnLjTm5Zh9ip7oPSfHirzwU9UKXF6OgBF1qSffOlOeCvrz

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict Z13ds70Hg6I2bPnBIYnLjTm5Zh9ip7oPSfHirzwU9UKXF6OgBF1qSffOlOeCvrz

RESET ALL;
