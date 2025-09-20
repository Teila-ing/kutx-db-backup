
\restrict xXS4RguwK0PAOEbVcaU01BD3vd9EbAzcOkuJIDidiY6UmSLbqGoH2PIn61JO4rt

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict xXS4RguwK0PAOEbVcaU01BD3vd9EbAzcOkuJIDidiY6UmSLbqGoH2PIn61JO4rt

RESET ALL;
