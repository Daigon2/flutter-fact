-- Paket B foundation. No active reward rule, online award engine or production seed data.
create table app.collected_facts (
 user_id uuid not null references app.profiles on delete restrict,
 fact_id bigint not null references app.facts on delete restrict,
 first_recorded_at timestamptz not null default clock_timestamp(), confirmed_at timestamptz,
 origin text not null check(origin in ('offline_note','online_discovery','hunt','group')),
 version bigint not null default 1 check(version>0), primary key(user_id,fact_id),
 check((origin='offline_note' and confirmed_at is null) or (origin<>'offline_note' and confirmed_at is not null)),
 check(confirmed_at is null or confirmed_at>=first_recorded_at)
);
create index collected_fact_fk on app.collected_facts(fact_id);
create index collected_own_confirmation on app.collected_facts(user_id,confirmed_at desc);
create table app.saved_facts (
 user_id uuid not null references app.profiles on delete restrict,
 fact_id bigint not null references app.facts on delete restrict,
 saved_at timestamptz not null default clock_timestamp(), primary key(user_id,fact_id)
);
create index saved_fact_fk on app.saved_facts(fact_id);

-- Immutable definitions. The check cannot be lifted by an API flag or table row.
-- Activation requires a separate reviewed migration and actual reward engine.
create table private.reward_rules (
 id uuid primary key default gen_random_uuid(), rule_version bigint not null unique check(rule_version>0),
 reason text not null check(reason in ('discover','find')),
 coins bigint not null check(coins>=0), xp bigint not null check(xp>=0), score bigint not null check(score>=0),
 active boolean not null default false, created_at timestamptz not null default clock_timestamp(),
 constraint reward_activation_pending check(not active), unique(id,reason)
);
create table private.reward_claims (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references app.profiles on delete restrict,
 fact_id bigint not null references app.facts on delete restrict,
 reason text not null check(reason in ('discover','find')), reward_rule_id uuid not null,
 foreign key(reward_rule_id,reason) references private.reward_rules(id,reason) on delete restrict,
 created_at timestamptz not null default clock_timestamp(), unique(user_id,fact_id,reason), unique(user_id,id)
);
create index reward_claim_fact_fk on private.reward_claims(fact_id);
create index reward_claim_rule_fk on private.reward_claims(reward_rule_id);
create table private.wallet_entries (
 id bigint generated always as identity primary key, user_id uuid not null references app.profiles on delete restrict,
 kind text not null check(kind in ('reward','purchase','refund','adjustment')),
 source_key text not null check(length(source_key) between 1 and 200),
 claim_id uuid unique, coin_delta bigint not null check(coin_delta<>0), reversal_of bigint unique,
 reason text check(reason is null or length(reason) between 1 and 4000),
 created_at timestamptz not null default clock_timestamp(), unique(user_id,source_key), unique(user_id,id),
 foreign key(user_id,claim_id) references private.reward_claims(user_id,id) on delete restrict,
 foreign key(user_id,reversal_of) references private.wallet_entries(user_id,id) on delete restrict,
 check(reversal_of is null or reversal_of<>id),
 check((kind='reward' and claim_id is not null and coin_delta>0 and reversal_of is null) or
       (kind='purchase' and claim_id is null and coin_delta<0 and reversal_of is null) or
       (kind='refund' and claim_id is null and coin_delta>0 and reversal_of is not null and reason is not null) or
       (kind='adjustment' and claim_id is null and reason is not null))
);
create index wallet_entries_owner on private.wallet_entries(user_id,created_at,id);
create table private.progress_entries (
 id bigint generated always as identity primary key, user_id uuid not null references app.profiles on delete restrict,
 claim_id uuid not null, xp_delta bigint not null check(xp_delta>=0), score_delta bigint not null check(score_delta>=0),
 created_at timestamptz not null default clock_timestamp(), unique(claim_id),
 check(xp_delta>0 or score_delta>0),
 foreign key(user_id,claim_id) references private.reward_claims(user_id,id) on delete restrict
);
create index progress_entries_owner on private.progress_entries(user_id,created_at,id);
create table app.wallet_balances (
 user_id uuid primary key references app.profiles on delete restrict,
 coin_balance bigint not null default 0 check(coin_balance>=0), version bigint not null default 1 check(version>0),
 updated_at timestamptz not null default clock_timestamp()
);
create table app.progress_totals (
 user_id uuid primary key references app.profiles on delete restrict,
 xp bigint not null default 0 check(xp>=0), score bigint not null default 0 check(score>=0),
 version bigint not null default 1 check(version>0), updated_at timestamptz not null default clock_timestamp()
);
create trigger reward_rule_immutable before update or delete on private.reward_rules for each row execute function private.append_only();
create trigger reward_claim_immutable before update or delete on private.reward_claims for each row execute function private.append_only();
create trigger wallet_journal_immutable before update or delete on private.wallet_entries for each row execute function private.append_only();
create trigger progress_journal_immutable before update or delete on private.progress_entries for each row execute function private.append_only();
-- Defense in depth: even a trusted accidental INSERT cannot consume a lifetime claim before activation.
create function private.guard_reward_claim() returns trigger language plpgsql set search_path='' as $$
begin raise exception using errcode='0A000',message='reward claims not activated'; end $$;
create trigger reward_claim_activation_guard before insert on private.reward_claims for each row execute function private.guard_reward_claim();

alter table app.collected_facts enable row level security;
alter table app.saved_facts enable row level security;
alter table app.wallet_balances enable row level security;
alter table app.progress_totals enable row level security;
alter table private.reward_rules enable row level security;
alter table private.reward_claims enable row level security;
alter table private.wallet_entries enable row level security;
alter table private.progress_entries enable row level security;
create policy own_collection on app.collected_facts for select to authenticated using(user_id=(select auth.uid()) and (select private.is_registered()));
create policy own_saved on app.saved_facts for select to authenticated using(user_id=(select auth.uid()) and (select private.is_registered()));
create policy own_balance on app.wallet_balances for select to authenticated using(user_id=(select auth.uid()) and (select private.is_registered()));
create policy own_progress on app.progress_totals for select to authenticated using(user_id=(select auth.uid()) and (select private.is_registered()));
create policy runtime_collection on app.collected_facts to fact_runtime using(true) with check(true);
create policy runtime_saved on app.saved_facts to fact_runtime using(true) with check(true);
grant select,insert on app.collected_facts to fact_runtime;
grant select,insert,delete on app.saved_facts to fact_runtime;
grant select on app.collected_facts,app.saved_facts,app.wallet_balances,app.progress_totals to authenticated;
-- No API/runtime grants for claims, rules, journals or balance/progress writes.

create function private.record_offline_collection(p_fact_id bigint,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare args jsonb; cached jsonb; c app.collected_facts;
begin
 args:=jsonb_build_object('fact_id',p_fact_id);
 cached:=private.command_begin(p_operation,'record_offline_collection',args); if cached is not null then return cached; end if;
 if not exists(select 1 from app.facts f join app.cities city on city.id=f.city_id where f.id=p_fact_id and f.status='published' and city.status='live') then
 raise exception using errcode='22023',message='published fact required'; end if;
 insert into app.collected_facts(user_id,fact_id,origin) values(private.request_actor(),p_fact_id,'offline_note') on conflict(user_id,fact_id) do nothing;
 select * into strict c from app.collected_facts where user_id=private.request_actor() and fact_id=p_fact_id;
 return private.command_finish(p_operation,'record_offline_collection',args,c.version,
 jsonb_build_object('fact_id',p_fact_id,'origin',c.origin,'confirmed_at',c.confirmed_at,'rewarded',false));
end $$;
create function private.set_saved(p_fact_id bigint,p_saved boolean,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare args jsonb; cached jsonb;
begin
 args:=jsonb_build_object('fact_id',p_fact_id,'saved',p_saved);
 cached:=private.command_begin(p_operation,'set_saved',args); if cached is not null then return cached; end if;
 if p_saved is null then raise exception using errcode='22023',message='saved boolean required'; end if;
 if p_saved then
  if not exists(select 1 from app.facts f join app.cities city on city.id=f.city_id where f.id=p_fact_id and f.status='published' and city.status='live') then
   raise exception using errcode='22023',message='published fact required'; end if;
  insert into app.saved_facts(user_id,fact_id) values(private.request_actor(),p_fact_id) on conflict(user_id,fact_id) do nothing;
 else
  -- Removing one's own saved row remains possible after content is archived.
  delete from app.saved_facts where user_id=private.request_actor() and fact_id=p_fact_id;
 end if;
 return private.command_finish(p_operation,'set_saved',args,null,jsonb_build_object('fact_id',p_fact_id,'saved',p_saved));
end $$;
create function private.collect_fact(p_fact_id bigint,p_lat double precision,p_lng double precision,p_accuracy_m double precision,p_measured_at timestamptz,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare args jsonb; cached jsonb; received_at timestamptz:=clock_timestamp(); f_location extensions.geography;
begin
 args:=jsonb_build_object('fact_id',p_fact_id,'lat',p_lat,'lng',p_lng,'accuracy_m',p_accuracy_m,'measured_at',p_measured_at);
 cached:=private.command_begin(p_operation,'collect_fact',args); if cached is not null then return cached; end if;
 if p_lat is null or p_lng is null or p_lat::text in ('NaN','Infinity','-Infinity') or p_lng::text in ('NaN','Infinity','-Infinity') or
 p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception using errcode='22023',message='finite latitude/longitude required'; end if;
 if p_accuracy_m is null or p_accuracy_m::text in ('NaN','Infinity','-Infinity') or p_accuracy_m<0 or p_accuracy_m>30 then
 raise exception using errcode='22023',message='GPS accuracy must be between 0 and 30 metres'; end if;
 if p_measured_at is null or not isfinite(p_measured_at) or p_measured_at<received_at-interval '30 seconds' or p_measured_at>received_at+interval '5 seconds' then
 raise exception using errcode='22023',message='GPS measurement exceeds 30s age or 5s future skew'; end if;
 select f.location into f_location from app.facts f join app.cities city on city.id=f.city_id where f.id=p_fact_id and f.status='published' and city.status='live';
 if not found or f_location is null then raise exception using errcode='22023',message='published located fact required'; end if;
 if not extensions.st_dwithin(f_location,extensions.st_setsrid(extensions.st_makepoint(p_lng,p_lat),4326)::extensions.geography,50) then
 raise exception using errcode='22023',message='outside 50 metre collection radius'; end if;
 -- D14: no production reward rule and no decision about zero-reward/retroactive claims.
 -- No confirmation, claim, journal, balance, XP, score or receipt is written on this path.
 raise exception using errcode='0A000',message='online collection and reward rules not activated';
end $$;
create function public.record_offline_collection(p_fact_id bigint,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.record_offline_collection(p_fact_id,p_operation) $$;
create function public.set_saved(p_fact_id bigint,p_saved boolean,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.set_saved(p_fact_id,p_saved,p_operation) $$;
create function public.collect_fact(p_fact_id bigint,p_lat double precision,p_lng double precision,p_accuracy_m double precision,p_measured_at timestamptz,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.collect_fact(p_fact_id,p_lat,p_lng,p_accuracy_m,p_measured_at,p_operation) $$;
create view public.collected_facts with(security_invoker=true) as select user_id,fact_id,first_recorded_at,confirmed_at,origin,version from app.collected_facts;
create view public.saved_facts with(security_invoker=true) as select user_id,fact_id,saved_at from app.saved_facts;
-- Empty journals mathematically mean zero; rows appear through the current user's protected profile.
create view public.wallet_balance with(security_invoker=true) as select p.id as user_id,coalesce(b.coin_balance,0)::bigint as coin_balance,coalesce(b.version,0)::bigint as version from app.profiles p left join app.wallet_balances b on b.user_id=p.id;
create view public.progress_totals with(security_invoker=true) as select p.id as user_id,coalesce(t.xp,0)::bigint as xp,coalesce(t.score,0)::bigint as score,coalesce(t.version,0)::bigint as version from app.profiles p left join app.progress_totals t on t.user_id=p.id;
grant select on public.collected_facts,public.saved_facts,public.wallet_balance,public.progress_totals to authenticated;

revoke execute on function private.guard_reward_claim(),private.record_offline_collection(bigint,uuid),private.set_saved(bigint,boolean,uuid),private.collect_fact(bigint,double precision,double precision,double precision,timestamptz,uuid),
 public.record_offline_collection(bigint,uuid),public.set_saved(bigint,boolean,uuid),public.collect_fact(bigint,double precision,double precision,double precision,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function private.record_offline_collection(bigint,uuid),private.set_saved(bigint,boolean,uuid),private.collect_fact(bigint,double precision,double precision,double precision,timestamptz,uuid),
 public.record_offline_collection(bigint,uuid),public.set_saved(bigint,boolean,uuid),public.collect_fact(bigint,double precision,double precision,double precision,timestamptz,uuid) to authenticated;
-- Transfer ownership only after explicit ACLs are complete (postgres has NOINHERIT membership).
grant create on schema private to fact_runtime;
alter function private.record_offline_collection(bigint,uuid) owner to fact_runtime;
alter function private.set_saved(bigint,boolean,uuid) owner to fact_runtime;
alter function private.collect_fact(bigint,double precision,double precision,double precision,timestamptz,uuid) owner to fact_runtime;
revoke create on schema private from fact_runtime;
;
