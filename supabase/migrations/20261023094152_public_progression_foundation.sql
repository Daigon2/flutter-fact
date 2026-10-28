-- Preserve the existing own-profile column order; append the readable visibility toggle.
create or replace view public.profiles with(security_invoker=true) as
 select id,public_handle,username,version,created_at,updated_at,show_in_rankings from app.profiles;
-- Unseeded catalogs/ownership. No grant/award, purchase, price, level or trophy threshold engine.
create table app.cosmetic_slots (
 id text primary key check(id ~ '^[a-z][a-z0-9_]*$' and length(id)<=64), label text not null check(btrim(label)<>''),
 public_safe boolean not null default false, status text not null default 'draft' check(status in ('draft','active','archived'))
);
create table app.cosmetic_items (
 id uuid primary key default gen_random_uuid(), key text not null unique check(key ~ '^[a-z][a-z0-9_]*$' and length(key)<=128),
 slot_id text not null references app.cosmetic_slots on delete restrict, label text not null check(btrim(label)<>''),
 public_safe boolean not null default false, status text not null default 'draft' check(status in ('draft','active','archived')), unique(id,slot_id)
);
create index cosmetic_item_slot on app.cosmetic_items(slot_id);
create table app.user_cosmetic_items (
 user_id uuid not null references app.profiles on delete restrict, item_id uuid not null references app.cosmetic_items on delete restrict,
 acquired_at timestamptz not null default clock_timestamp(), primary key(user_id,item_id)
);
create index owned_item_fk on app.user_cosmetic_items(item_id);
create table app.player_customizations (
 user_id uuid primary key references app.profiles on delete restrict, version bigint not null default 0 check(version>=0),
 updated_at timestamptz not null default clock_timestamp()
);
create table app.user_equipment (
 user_id uuid not null, slot_id text not null, item_id uuid not null, updated_at timestamptz not null default clock_timestamp(),
 primary key(user_id,slot_id), foreign key(user_id,item_id) references app.user_cosmetic_items(user_id,item_id) on delete restrict,
 foreign key(item_id,slot_id) references app.cosmetic_items(id,slot_id) on delete restrict
);
create index equipment_item_slot_fk on app.user_equipment(item_id,slot_id);
create index equipment_owner_item_fk on app.user_equipment(user_id,item_id);
create table app.medal_definitions (
 id uuid primary key default gen_random_uuid(), key text not null unique check(key ~ '^[a-z][a-z0-9_]*$' and length(key)<=128), title text not null check(btrim(title)<>''),
 city_id uuid references app.cities on delete restrict,
 public_safe boolean not null default false, status text not null default 'draft' check(status in ('draft','active','archived')),
 check(city_id is null or not public_safe)
);
create index medal_city_fk on app.medal_definitions(city_id) where city_id is not null;
create table app.user_medals (
 user_id uuid not null references app.profiles on delete restrict, medal_id uuid not null references app.medal_definitions on delete restrict,
 awarded_at timestamptz not null default clock_timestamp(), primary key(user_id,medal_id)
);
create index medal_definition_fk on app.user_medals(medal_id);
create table app.user_medal_showcase (
 user_id uuid not null, medal_id uuid not null, position smallint not null check(position between 1 and 3), selected_at timestamptz not null default clock_timestamp(), primary key(user_id,position), unique(user_id,medal_id),
 foreign key(user_id,medal_id) references app.user_medals(user_id,medal_id) on delete restrict
);
create index showcase_medal_fk on app.user_medal_showcase(medal_id);
-- Changing approved metadata requires explicit re-review, including identifiers/labels with possible city references.
create function private.guard_public_catalog() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if old.public_safe and new.public_safe and (to_jsonb(new)-'public_safe'-'status') is distinct from (to_jsonb(old)-'public_safe'-'status') then
 raise exception using errcode='55000',message='unapprove public metadata before changing it'; end if;
 return new;
end $$;
create trigger slot_public_review before update on app.cosmetic_slots for each row execute function private.guard_public_catalog();
create trigger item_public_review before update on app.cosmetic_items for each row execute function private.guard_public_catalog();
create trigger medal_public_review before update on app.medal_definitions for each row execute function private.guard_public_catalog();
do $$ declare t text; begin
 foreach t in array array['cosmetic_slots','cosmetic_items','user_cosmetic_items','player_customizations','user_equipment','medal_definitions','user_medals','user_medal_showcase'] loop
  execute format('alter table app.%I enable row level security',t);
 end loop;
 foreach t in array array['cosmetic_slots','cosmetic_items','medal_definitions'] loop
  execute format('create policy runtime_catalog on app.%I for select to fact_runtime using(true)',t);
 end loop;
 foreach t in array array['user_cosmetic_items','user_medals'] loop
  execute format('create policy runtime_ownership on app.%I for select to fact_runtime using(user_id=private.request_actor())',t);
 end loop;
 foreach t in array array['player_customizations','user_equipment','user_medal_showcase'] loop
  execute format('create policy runtime_customization on app.%I to fact_runtime using(user_id=private.request_actor()) with check(user_id=private.request_actor())',t);
 end loop;
end $$;
grant select on app.cosmetic_slots,app.cosmetic_items,app.medal_definitions,app.user_cosmetic_items,app.user_medals,app.player_customizations,app.user_equipment,app.user_medal_showcase to fact_runtime;
grant insert on app.player_customizations,app.user_equipment,app.user_medal_showcase to fact_runtime;
grant update(version,updated_at) on app.player_customizations to fact_runtime;
grant delete on app.user_equipment,app.user_medal_showcase to fact_runtime;
-- No ownership INSERT/grant/award privileges. A client cannot fabricate inventory or medals.
create function private.customization_begin(p_expected_version bigint) returns void language plpgsql security definer set search_path='' as $$
declare v bigint;
begin
 if not private.is_registered() then raise exception using errcode='42501',message='registered account required'; end if;
 if p_expected_version is null or p_expected_version<0 then raise exception using errcode='22023',message='nonnegative expected customization version required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fact.customization.user:'||private.request_actor()::text,0));
 select version into v from app.player_customizations where user_id=private.request_actor() for update;
 if not found then
  if p_expected_version<>0 then raise exception using errcode='40001',message='customization version conflict'; end if;
  insert into app.player_customizations(user_id) values(private.request_actor());
 elsif v<>p_expected_version then raise exception using errcode='40001',message='customization version conflict'; end if;
end $$;
create function private.set_equipment(p_slot text,p_item_id uuid,p_expected_version bigint,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare args jsonb; cached jsonb; v bigint;
begin
 args:=jsonb_build_object('slot',p_slot,'item_id',p_item_id,'expected_version',p_expected_version);
 cached:=private.command_begin(p_operation,'set_equipment',args); if cached is not null then return cached; end if;
 if p_slot is null or length(p_slot)>64 or p_slot !~ '^[a-z][a-z0-9_]*$' then raise exception using errcode='22023',message='valid slot required'; end if;
 if not exists(select 1 from app.cosmetic_slots where id=p_slot) then raise exception using errcode='22023',message='existing slot required'; end if;
 perform private.customization_begin(p_expected_version);
 if p_item_id is not null and not exists(
  select 1 from app.user_cosmetic_items owned join app.cosmetic_items i on i.id=owned.item_id join app.cosmetic_slots s on s.id=i.slot_id
  where owned.user_id=private.request_actor() and owned.item_id=p_item_id and i.slot_id=p_slot and i.public_safe and i.status='active' and s.public_safe and s.status='active'
 ) then raise exception using errcode='42501',message='owned approved item in matching approved slot required'; end if;
 delete from app.user_equipment where user_id=private.request_actor() and slot_id=p_slot;
 if p_item_id is not null then insert into app.user_equipment(user_id,slot_id,item_id) values(private.request_actor(),p_slot,p_item_id); end if;
 update app.player_customizations set version=version+1,updated_at=clock_timestamp() where user_id=private.request_actor() returning version into v;
 return private.command_finish(p_operation,'set_equipment',args,v,jsonb_build_object('slot',p_slot,'item_id',p_item_id));
end $$;
create function private.set_showcase_medal(p_medal_id uuid,p_selected boolean,p_expected_version bigint,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare args jsonb; cached jsonb; v bigint; chosen_position smallint;
begin
 args:=jsonb_build_object('medal_id',p_medal_id,'selected',p_selected,'expected_version',p_expected_version);
 cached:=private.command_begin(p_operation,'set_showcase_medal',args); if cached is not null then return cached; end if;
 if p_medal_id is null or p_selected is null then raise exception using errcode='22023',message='medal and desired selected state required'; end if;
 perform private.customization_begin(p_expected_version);
 if not exists(select 1 from app.user_medals where user_id=private.request_actor() and medal_id=p_medal_id) then raise exception using errcode='42501',message='owned medal required'; end if;
 if p_selected then
  if not exists(select 1 from app.user_medals owned join app.medal_definitions m on m.id=owned.medal_id where owned.user_id=private.request_actor() and owned.medal_id=p_medal_id and m.public_safe and m.status='active' and m.city_id is null) then
   raise exception using errcode='42501',message='owned approved global medal required'; end if;
  select position into chosen_position from app.user_medal_showcase where user_id=private.request_actor() and medal_id=p_medal_id;
  if not found then
   select candidate::smallint into chosen_position from generate_series(1,3) as slots(candidate)
   where not exists(select 1 from app.user_medal_showcase selected where selected.user_id=private.request_actor() and selected.position=candidate)
   order by candidate limit 1;
   if not found then raise exception using errcode='23514',message='medal showcase is full (maximum 3)'; end if;
   insert into app.user_medal_showcase(user_id,medal_id,position) values(private.request_actor(),p_medal_id,chosen_position);
  end if;
 else delete from app.user_medal_showcase where user_id=private.request_actor() and medal_id=p_medal_id;
 end if;
 update app.player_customizations set version=version+1,updated_at=clock_timestamp() where user_id=private.request_actor() returning version into v;
 return private.command_finish(p_operation,'set_showcase_medal',args,v,jsonb_build_object('medal_id',p_medal_id,'selected',p_selected,'position',chosen_position));
end $$;
create function private.get_my_customization() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.request_actor();
begin
 if not private.is_registered() then raise exception using errcode='42501',message='registered account required'; end if;
 return jsonb_build_object('version',coalesce((select version from app.player_customizations where user_id=actor),0),
 'equipment',coalesce((select jsonb_agg(jsonb_build_object('slot',e.slot_id,'item_id',i.id,'item_key',i.key,'label',i.label) order by e.slot_id) from app.user_equipment e join app.cosmetic_items i on i.id=e.item_id where e.user_id=actor),'[]'::jsonb),
 'selected_medals',coalesce((select jsonb_agg(jsonb_build_object('medal_id',m.id,'key',m.key,'title',m.title,'position',s.position) order by s.position) from app.user_medal_showcase s join app.medal_definitions m on m.id=s.medal_id where s.user_id=actor),'[]'::jsonb),
 'owned_items',coalesce((select jsonb_agg(jsonb_build_object('item_id',i.id,'item_key',i.key,'slot',i.slot_id,'label',i.label,'public_safe',i.public_safe,'status',i.status) order by i.key) from app.user_cosmetic_items o join app.cosmetic_items i on i.id=o.item_id where o.user_id=actor),'[]'::jsonb),
 'earned_medals',coalesce((select jsonb_agg(jsonb_build_object('medal_id',m.id,'key',m.key,'title',m.title,'public_safe',m.public_safe,'status',m.status) order by m.key) from app.user_medals o join app.medal_definitions m on m.id=o.medal_id where o.user_id=actor),'[]'::jsonb));
end $$;
create function public.get_my_customization() returns jsonb language sql stable security invoker set search_path='' as $$ select private.get_my_customization() $$;
create function public.set_equipment(p_slot text,p_item_id uuid,p_expected_version bigint,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.set_equipment(p_slot,p_item_id,p_expected_version,p_operation) $$;
create function public.set_showcase_medal(p_medal_id uuid,p_selected boolean,p_expected_version bigint,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.set_showcase_medal(p_medal_id,p_selected,p_expected_version,p_operation) $$;
revoke execute on function private.guard_public_catalog(),private.customization_begin(bigint),private.set_equipment(text,uuid,bigint,uuid),private.set_showcase_medal(uuid,boolean,bigint,uuid),private.get_my_customization(),
 public.get_my_customization(),public.set_equipment(text,uuid,bigint,uuid),public.set_showcase_medal(uuid,boolean,bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function private.set_equipment(text,uuid,bigint,uuid),private.set_showcase_medal(uuid,boolean,bigint,uuid),private.get_my_customization(),
 public.get_my_customization(),public.set_equipment(text,uuid,bigint,uuid),public.set_showcase_medal(uuid,boolean,bigint,uuid) to authenticated;
grant create on schema private to fact_runtime;
alter function private.customization_begin(bigint) owner to fact_runtime;
alter function private.set_equipment(text,uuid,bigint,uuid) owner to fact_runtime;
alter function private.set_showcase_medal(uuid,boolean,bigint,uuid) owner to fact_runtime;
alter function private.get_my_customization() owner to fact_runtime;
revoke create on schema private from fact_runtime;

-- Separate read capability; never broadens actor-bound reward runtime RLS.
create role fact_public_reader nologin noinherit nobypassrls;
grant fact_public_reader to postgres with set true;
grant fact_public_reader to postgres with inherit false;
grant usage on schema app,private to fact_public_reader;
grant select(id,public_handle,username,show_in_rankings) on app.profiles to fact_public_reader;
grant select(user_id,score) on app.progress_totals to fact_public_reader;
grant select(user_id,slot_id,item_id) on app.user_equipment to fact_public_reader;
grant select(id,key,slot_id,label,public_safe,status) on app.cosmetic_items to fact_public_reader;
grant select(id,label,public_safe,status) on app.cosmetic_slots to fact_public_reader;
grant select(user_id,medal_id,position) on app.user_medal_showcase to fact_public_reader;
grant select(id,key,title,city_id,public_safe,status) on app.medal_definitions to fact_public_reader;
create policy visible_player on app.profiles for select to fact_public_reader using(username is not null and show_in_rankings);
create policy visible_player_score on app.progress_totals for select to fact_public_reader using(exists(select 1 from app.profiles p where p.id=user_id));
create policy visible_equipment on app.user_equipment for select to fact_public_reader using(exists(select 1 from app.profiles p where p.id=user_id));
create policy safe_cosmetic on app.cosmetic_items for select to fact_public_reader using(public_safe and status='active');
create policy safe_slot on app.cosmetic_slots for select to fact_public_reader using(public_safe and status='active');
create policy visible_showcase on app.user_medal_showcase for select to fact_public_reader using(exists(select 1 from app.profiles p where p.id=user_id));
create policy safe_global_medal on app.medal_definitions for select to fact_public_reader using(public_safe and status='active' and city_id is null);
create function private.get_leaderboard(p_limit integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if p_limit is null or p_limit<1 or p_limit>100 then raise exception using errcode='22023',message='leaderboard limit must be 1-100'; end if;
 with visible as (
 select p.id as user_id,p.public_handle,p.username,coalesce(t.score,0)::bigint as score
 from app.profiles p left join app.progress_totals t on t.user_id=p.id
 where p.username is not null and p.show_in_rankings
), ranked as materialized (
 select v.*,rank() over(order by v.score desc) as player_rank from visible v
), limited as (select * from ranked order by score desc,username,public_handle limit p_limit)
 select coalesce(jsonb_agg(jsonb_build_object('public_handle',p.public_handle,'username',p.username,'score',p.score,'rank',p.player_rank,
 'equipment',coalesce((select jsonb_agg(jsonb_build_object('slot',e.slot_id,'item_key',i.key,'label',i.label) order by e.slot_id)
  from app.user_equipment e join app.cosmetic_items i on i.id=e.item_id and i.slot_id=e.slot_id join app.cosmetic_slots slot on slot.id=e.slot_id where e.user_id=p.user_id),'[]'::jsonb),
 'medals',coalesce((select jsonb_agg(jsonb_build_object('key',m.key,'title',m.title) order by showcase.position)
  from app.user_medal_showcase showcase join app.medal_definitions m on m.id=showcase.medal_id where showcase.user_id=p.user_id),'[]'::jsonb)) order by p.score desc,p.username,p.public_handle),'[]'::jsonb) into result from limited p;
 return result;
end $$;
create function private.get_player_card(p_public_handle uuid) returns jsonb language sql stable security definer set search_path='' as $$
 with visible as (
 select p.id as user_id,p.public_handle,p.username,coalesce(t.score,0)::bigint as score
 from app.profiles p left join app.progress_totals t on t.user_id=p.id
 where p.username is not null and p.show_in_rankings
), ranked as materialized (
 select v.*,rank() over(order by v.score desc) as player_rank from visible v
)
 select jsonb_build_object('public_handle',p.public_handle,'username',p.username,'score',p.score,'rank',p.player_rank,
 'equipment',coalesce((select jsonb_agg(jsonb_build_object('slot',e.slot_id,'item_key',i.key,'label',i.label) order by e.slot_id)
  from app.user_equipment e join app.cosmetic_items i on i.id=e.item_id and i.slot_id=e.slot_id join app.cosmetic_slots slot on slot.id=e.slot_id where e.user_id=p.user_id),'[]'::jsonb),
 'medals',coalesce((select jsonb_agg(jsonb_build_object('key',m.key,'title',m.title) order by showcase.position)
  from app.user_medal_showcase showcase join app.medal_definitions m on m.id=showcase.medal_id where showcase.user_id=p.user_id),'[]'::jsonb)) from ranked p where p.public_handle=p_public_handle
$$;
create function public.get_leaderboard(p_limit integer) returns jsonb language sql stable security invoker set search_path='' as $$ select private.get_leaderboard(p_limit) $$;
create function public.get_player_card(p_public_handle uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select private.get_player_card(p_public_handle) $$;
revoke execute on function private.get_leaderboard(integer),private.get_player_card(uuid),public.get_leaderboard(integer),public.get_player_card(uuid) from public,anon,authenticated,service_role;
grant execute on function private.get_leaderboard(integer),private.get_player_card(uuid),public.get_leaderboard(integer),public.get_player_card(uuid) to anon,authenticated;
grant create on schema private to fact_public_reader;
alter function private.get_leaderboard(integer) owner to fact_public_reader;
alter function private.get_player_card(uuid) owner to fact_public_reader;
revoke create on schema private from fact_public_reader;
;
