-- Assinatura completa do CRM EUREKA: roda no banco oficial e no banco restaurado; as duas saídas têm de ser idênticas.
-- Cobre: dados de TODAS as tabelas do schema public (linhas + hash do conteúdo), logins (auth.users/identities),
-- colunas, restrições, índices, regras de acesso (RLS), funções, automações (triggers), permissões e sequências.
\pset format unaligned
\pset tuples_only on
\pset footer off
create temp table _sig(k text, v text);
do $$
declare r record; n bigint; h text;
begin
  for r in select schemaname s, tablename t from pg_tables where schemaname='public'
           union all select 'auth','users' union all select 'auth','identities' order by 1,2 loop
    execute format('select count(*), coalesce(md5(string_agg(md5(x::text), '''' order by md5(x::text))), ''vazio'') from %I.%I x', r.s, r.t) into n, h;
    insert into _sig values ('dados '||r.s||'.'||r.t, n||' linhas '||h);
  end loop;
end $$;
insert into _sig select 'coluna '||table_name||'.'||column_name, data_type||' '||coalesce(column_default,'')||' '||is_nullable
  from information_schema.columns where table_schema='public';
insert into _sig select 'restricao '||conrelid::regclass||'.'||conname, pg_get_constraintdef(oid)
  from pg_constraint where connamespace='public'::regnamespace;
insert into _sig select 'indice '||indexname, indexdef from pg_indexes where schemaname='public';
insert into _sig select 'rls '||relname, relrowsecurity::text||relforcerowsecurity::text
  from pg_class where relnamespace='public'::regnamespace and relkind='r';
insert into _sig select 'politica '||tablename||'.'||policyname, cmd||' '||array_to_string(roles,',')||' '||coalesce(qual,'')||' '||coalesce(with_check,'')
  from pg_policies where schemaname='public';
insert into _sig select 'funcao '||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')', md5(pg_get_functiondef(p.oid))
  from pg_proc p where p.pronamespace='public'::regnamespace;
insert into _sig select 'trigger '||c.relnamespace::regnamespace||'.'||c.relname||'.'||t.tgname, md5(pg_get_triggerdef(t.oid))
  from pg_trigger t join pg_class c on c.oid=t.tgrelid
 where not t.tgisinternal and c.relnamespace in ('public'::regnamespace,'auth'::regnamespace) and t.tgname not like 'RI_%'
   and (c.relnamespace='public'::regnamespace or t.tgname like 'trg_%' or t.tgname='on_auth_user_created');
insert into _sig select 'permissao '||table_name||' '||grantee, string_agg(privilege_type, ',' order by privilege_type)
  from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated','service_role')
 group by table_name, grantee;
insert into _sig select 'sequencia '||sequencename, coalesce(last_value::text,'nula') from pg_sequences where schemaname='public';
select k||' = '||v from _sig order by k;
