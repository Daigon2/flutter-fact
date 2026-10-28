-- Paket A1. Execute as postgres. No production data; no auth metadata used as authority.

create schema if not exists extensions;
create extension if not exists postgis with schema extensions;
create schema app;
create schema private;
create role fact_runtime nologin noinherit nobypassrls;
-- PostgreSQL 17 owner transfers require SET membership; the trusted migration role retains administration.
grant fact_runtime to postgres with set true;
grant fact_runtime to postgres with inherit false;
grant usage on schema app, private, extensions to fact_runtime;
grant usage on schema app, private, extensions to anon, authenticated;
revoke all on schema app, private from public;
revoke create on schema public from public, anon, authenticated;
-- Defaults are per creator: protect both migration creator and function owner.
alter default privileges for role postgres in schema app, private, public revoke all on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema app, private, public revoke all on sequences from anon, authenticated, service_role;
alter default privileges for role postgres in schema app, private, public revoke execute on functions from public, anon, authenticated, service_role;
-- Runtime never creates objects: owner transfers retain the postgres creator ACL.
-- No ALTER DEFAULT PRIVILEGES FOR fact_runtime is needed or permitted by this migration role.

create domain app.language_code as text check (value ~ '^[a-z]{2,3}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?$');
create table app.cities (
 id uuid primary key default gen_random_uuid(), slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
 country_code text not null check (country_code ~ '^[A-Z]{2}$'), timezone text not null check (length(timezone)>0),
 center extensions.geography(point,4326), map_bounds jsonb check (map_bounds is null or jsonb_typeof(map_bounds)='object'),
 status text not null default 'draft' check(status in ('draft','live','archived')),
 catalog_version bigint not null default 1 check(catalog_version>0), created_at timestamptz not null default now()
);
create table app.city_texts (city_id uuid not null references app.cities on delete restrict, language_code app.language_code not null, name text not null check(btrim(name)<>''), intro text, primary key(city_id,language_code));
create table app.city_aliases (city_id uuid not null references app.cities on delete restrict, alias text not null check(btrim(alias)<>''), normalized_alias text generated always as (lower(btrim(alias))) stored, primary key(city_id,alias));
create index city_alias_search on app.city_aliases(normalized_alias);
create table app.categories (id text primary key check(id ~ '^[a-z][a-z0-9_]*$'), sort_order integer not null default 0);
create table app.category_texts (category_id text not null references app.categories on delete restrict, language_code app.language_code not null, label text not null check(btrim(label)<>''), primary key(category_id,language_code));
create table app.genres (id text primary key check(id ~ '^[a-z][a-z0-9_]*$'));
create table app.genre_texts (genre_id text not null references app.genres on delete restrict, language_code app.language_code not null, label text not null check(btrim(label)<>''), description text, primary key(genre_id,language_code));
create table app.city_zones (id uuid primary key default gen_random_uuid(), city_id uuid not null references app.cities on delete restrict, code integer not null, label text, unique(city_id,code), unique(city_id,id));

create table app.profiles (
 id uuid primary key references auth.users on delete restrict, public_handle uuid not null unique default gen_random_uuid(),
 username text, username_set_at timestamptz, username_changed_at timestamptz,
 show_in_rankings boolean not null default true,
 version bigint not null default 1 check(version>0), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint username_format check(username is null or (username ~ '^[a-z0-9_]{3,24}$' and username=lower(username))),
 constraint username_timestamps check((username is null and username_set_at is null and username_changed_at is null) or (username is not null and username_set_at is not null and username_changed_at is null))
);
create unique index profiles_username_unique on app.profiles(lower(username)) where username is not null;
-- Initial assignment only; a later rename requires a separately reviewed command.
create table app.account_preferences (
 user_id uuid primary key references app.profiles on delete restrict, hometown_city_id uuid references app.cities on delete restrict,
 hometown_text text, content_language app.language_code,
 version bigint not null default 1 check(version>0), updated_at timestamptz not null default now()
);
create index preference_hometown on app.account_preferences(hometown_city_id) where hometown_city_id is not null;
create table private.user_roles (
 user_id uuid not null references app.profiles on delete restrict, role text not null check(role in ('editor','moderator','admin')),
 granted_by uuid references app.profiles on delete restrict, granted_at timestamptz not null default now(), revoked_at timestamptz,
 primary key(user_id,role), check(revoked_at is null or revoked_at>=granted_at)
);
create index role_granter on private.user_roles(granted_by) where granted_by is not null;
create table private.audit_log (
 id bigint generated always as identity primary key, actor_id uuid references app.profiles on delete restrict,
 action text not null check(btrim(action)<>''), entity_type text not null, entity_id text not null, reason text,
 operation_id uuid, occurred_at timestamptz not null default clock_timestamp(),
 changes jsonb not null default '{}'::jsonb check(jsonb_typeof(changes)='object' and octet_length(changes::text)<=16384)
);
create index audit_actor on private.audit_log(actor_id,occurred_at desc);
create table private.command_receipts (
 actor_id uuid not null references app.profiles on delete restrict, operation_id uuid not null,
 command text not null, payload_hash text not null check(payload_hash ~ '^[0-9a-f]{64}$'), result jsonb not null,
 created_at timestamptz not null default now(), primary key(actor_id,operation_id)
);

-- Same trusted PostgREST request-GUC semantics as Supabase auth.uid()/auth.jwt().
-- Runtime has no auth-schema privileges; API verifies JWTs before setting these values.
-- No user_metadata field is used for authorization. Helpers remain internal-only.
create function private.request_claims() returns jsonb language sql stable security invoker set search_path='' as $$
 select coalesce(nullif(current_setting('request.jwt.claim',true),''),nullif(current_setting('request.jwt.claims',true),''))::jsonb
$$;
create function private.request_actor() returns uuid language sql stable security invoker set search_path='' as $$
 select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub'))::uuid
$$;
create function private.is_registered() returns boolean language sql stable security definer set search_path='' as $$
 select private.request_actor() is not null and not coalesce((private.request_claims()->>'is_anonymous')::boolean,false)
 and exists(select 1 from app.profiles p where p.id=private.request_actor())
$$;
create function private.has_role(p_roles text[]) returns boolean language sql stable security definer set search_path='' as $$
 select private.is_registered() and exists(select 1 from private.user_roles r where r.user_id=private.request_actor() and r.revoked_at is null and r.role=any(p_roles))
$$;
create function private.append_only() returns trigger language plpgsql set search_path='' as $$
 begin raise exception using errcode='55000',message='append-only record'; end $$;
create trigger audit_append_only before update or delete on private.audit_log for each row execute function private.append_only();
create trigger receipts_append_only before update or delete on private.command_receipts for each row execute function private.append_only();
create function private.create_profile() returns trigger language plpgsql security definer set search_path='' as $$
 begin
 if not coalesce(new.is_anonymous,false) then
  insert into app.profiles(id) values(new.id);
  insert into app.account_preferences(user_id) values(new.id);
 end if;
 return new;
 end $$;
create trigger fact_auth_profile after insert on auth.users for each row execute function private.create_profile();

create table app.facts (
 id bigint generated always as identity primary key check(id>0), city_id uuid not null references app.cities on delete restrict,
 category_id text not null references app.categories on delete restrict, genre_id text references app.genres on delete restrict,
 zone_id uuid, location extensions.geography(point,4326), quality_score smallint check(quality_score between 1 and 3),
 origin text not null check(origin in ('editorial','community')), author_id uuid references app.profiles on delete restrict,
 status text not null default 'draft' check(status in ('draft','published','archived')),
 default_language app.language_code not null, hero_colors text[] not null default '{}',
 published_revision bigint, version bigint not null default 1 check(version>0), published_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(city_id,zone_id) references app.city_zones(city_id,id) on delete restrict,
 check((status='draft' and published_revision is null and published_at is null) or (status in ('published','archived') and published_revision is not null and published_revision>0 and published_at is not null)),
 check(cardinality(hero_colors)<=8)
);
create index facts_catalog on app.facts(city_id,status,id);
create index facts_category on app.facts(category_id,id);
create index facts_genre on app.facts(genre_id) where genre_id is not null;
create index facts_zone on app.facts(city_id,zone_id) where zone_id is not null;
create index facts_author on app.facts(author_id) where author_id is not null;
create index facts_location on app.facts using gist(location);
create table app.fact_texts (
 fact_id bigint not null references app.facts on delete restrict, language_code app.language_code not null,
 title text, body text, body_extra text, body_background text, body_today text, place text, caption text, source_display text,
 translation_status text not null default 'draft' check(translation_status in ('draft','approved')),
 primary key(fact_id,language_code)
);
create table app.fact_external_ids (source_system text not null check(btrim(source_system)<>''), external_id text not null check(btrim(external_id)<>''), fact_id bigint not null references app.facts on delete restrict, primary key(source_system,external_id));
create index external_fact on app.fact_external_ids(fact_id);
create table app.fact_sources (
 id uuid primary key default gen_random_uuid(), fact_id bigint not null references app.facts on delete restrict,
 position integer not null check(position>0), url text check(url is null or url ~ '^https?://'), citation text not null check(btrim(citation)<>''),
 accessed_on date, language_code app.language_code, unique(fact_id,position)
);
create table app.fact_navigation_hints (
 fact_id bigint not null references app.facts on delete restrict, language_code app.language_code not null,
 hint_index smallint not null check(hint_index>0), text text not null check(btrim(text)<>''), kind text not null check(kind in ('station','next_station')),
 primary key(fact_id,language_code,hint_index)
);

-- Clients receive no DML grants. Only explicit RPCs introduced in A2 can mutate.
do $$ declare r record; begin
 for r in select tablename,schemaname from pg_tables where schemaname in ('app','private') loop
 execute format('alter table %I.%I enable row level security',r.schemaname,r.tablename);
 end loop;
end $$;
grant select on app.profiles, app.account_preferences to authenticated;
create policy own_profile on app.profiles for select to authenticated using(id=(select auth.uid()) and (select private.is_registered()));
create policy own_preferences on app.account_preferences for select to authenticated using(user_id=(select auth.uid()) and (select private.is_registered()));
-- Fixed capability role: no LOGIN, no membership granted to API roles, no BYPASSRLS.
grant select on app.profiles, private.user_roles to fact_runtime;
grant insert on app.profiles, app.account_preferences, private.audit_log, private.command_receipts to fact_runtime;
grant select on private.command_receipts to fact_runtime;
grant usage on sequence private.audit_log_id_seq to fact_runtime;
create policy runtime_profile on app.profiles to fact_runtime using(true) with check(true);
create policy runtime_preferences on app.account_preferences to fact_runtime using(true) with check(true);
create policy runtime_roles on private.user_roles for select to fact_runtime using(true);
create policy runtime_audit on private.audit_log for insert to fact_runtime with check(true);
create policy runtime_receipts on private.command_receipts to fact_runtime using(true) with check(true);

revoke all on all tables in schema app,private from public, anon, authenticated, service_role;
grant select on app.profiles,app.account_preferences to authenticated;
revoke all on all sequences in schema app,private from public,anon,authenticated,service_role;
revoke execute on all functions in schema private from public,anon,authenticated,service_role;
grant execute on function private.is_registered(),private.has_role(text[]) to authenticated;
grant create on schema private to fact_runtime;
alter function private.request_claims() owner to fact_runtime;
alter function private.request_actor() owner to fact_runtime;
alter function private.is_registered() owner to fact_runtime;
alter function private.has_role(text[]) owner to fact_runtime;
alter function private.create_profile() owner to fact_runtime;
revoke create on schema private from fact_runtime;
-- Only migration owner controls role assignments until a separately reviewed admin command exists.
create view public.profiles with(security_invoker=true) as select id,public_handle,username,version,created_at,updated_at from app.profiles;
grant select on public.profiles to authenticated;
;
