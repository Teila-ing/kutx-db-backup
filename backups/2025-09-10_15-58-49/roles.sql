
\restrict pp6jTByx3oHUIQpQfszncXezPY0ueI95815Apoh9yz5V8UONa15tlEkWc1m96C3

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER ROLE "anon" SET "statement_timeout" TO '3s';

ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';

ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

\unrestrict pp6jTByx3oHUIQpQfszncXezPY0ueI95815Apoh9yz5V8UONa15tlEkWc1m96C3

RESET ALL;
