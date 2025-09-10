
\restrict EMOwye8r07J8MEkH6HwrGTB2yrXnjvjIODGtmdq4WzSui9dnTAXijdrZt45q2o7

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict EMOwye8r07J8MEkH6HwrGTB2yrXnjvjIODGtmdq4WzSui9dnTAXijdrZt45q2o7

RESET ALL;
