
\restrict iQRZa2tVQrIxqMtXck1V23ScDjMmjGiBnoC5AsX0t68mExiDb4mkdlaK02oXS0C

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict iQRZa2tVQrIxqMtXck1V23ScDjMmjGiBnoC5AsX0t68mExiDb4mkdlaK02oXS0C

RESET ALL;
