-- Prepara um Postgres 17 vazio para receber o backup do CRM EUREKA como se fosse o Supabase.
do $$ declare r text; begin
  foreach r in array array['anon','authenticated','service_role','authenticator','supabase_auth_admin','supabase_admin','dashboard_user','pgbouncer','supabase_storage_admin','supabase_realtime_admin','supabase_replication_admin','supabase_read_only_user'] loop
    if not exists (select 1 from pg_roles where rolname = r) then execute format('create role %I nologin', r); end if;
  end loop; end $$;
alter role service_role bypassrls;
create schema if not exists extensions;
create extension if not exists "uuid-ossp" schema extensions;
create extension if not exists pgcrypto schema extensions;
create extension if not exists unaccent schema extensions;
drop schema public cascade;
