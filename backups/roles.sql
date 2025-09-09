
\restrict pyeUJOK6LabcNA9iS7RhMadW6vGFFczj4RE7e426GSnZfNHsv8IMXk3nEwbg50Q

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict pyeUJOK6LabcNA9iS7RhMadW6vGFFczj4RE7e426GSnZfNHsv8IMXk3nEwbg50Q

RESET ALL;
