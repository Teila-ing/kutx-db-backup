
\restrict gG1LUdzNwZa2MPnWLj7EhJoNCuL1PXoQQfPeoj9N4OBT0dbaFCDAkKI0XurbzhW

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict gG1LUdzNwZa2MPnWLj7EhJoNCuL1PXoQQfPeoj9N4OBT0dbaFCDAkKI0XurbzhW

RESET ALL;
