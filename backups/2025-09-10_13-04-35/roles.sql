
\restrict 7JxFwyAc3TP2AHX611oTBs0cWffsZaUfTCsMEHguqBChnNcIZeT0gozcFUU7wqe

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict 7JxFwyAc3TP2AHX611oTBs0cWffsZaUfTCsMEHguqBChnNcIZeT0gozcFUU7wqe

RESET ALL;
