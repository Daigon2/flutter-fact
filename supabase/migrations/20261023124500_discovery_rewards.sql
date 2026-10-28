begin;
-- D15: only the first discover per user/fact awards 50 coins, 10 XP, 10 ranking score.
-- No find, backfill, submission bonus, kiosk or zero-value claim semantics activated.
alter table private.reward_rules drop constraint reward_activation_pending;
alter table private.reward_rules add constraint active_reward_scope check(not active or (reason='discover' and coins>0 and xp>0 and score>0));
create table private.reward_rule_current (
 reason text primary key check(reason='discover'), reward_rule_id uuid not null,
 version bigint not null check(version>0), changed_at timestamptz not null default clock_timestamp(),
 foreign key(reward_rule_id,reason) references private.reward_rules(id,reason) on delete restrict
);
alter table private.reward_rule_current enable row level security;
create table private.reward_config_commands (
 operation_id uuid primary key, payload_hash text not null check(payload_hash ~ '^[0-9a-f]{64}$'),
 result jsonb not null, created_at timestamptz not null default clock_timestamp()
);
alter table private.reward_config_commands enable row level security;
create trigger reward_config_command_immutable before update or delete on private.reward_config_commands for each row execute function private.append_only();
create function private.guard_reward_current() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if current_user<>'postgres' then raise exception using errcode='42501',message='trusted SQL reward configuration required'; end if;
 if tg_op='DELETE' then raise exception using errcode='55000',message='reward pointer cannot be deleted; revoke collection RPC to pause'; end if;
 if tg_op='UPDATE' and (new.reason<>old.reason or new.version<>old.version+1) then raise exception using errcode='40001',message='reward pointer version conflict'; end if;
 if tg_op='INSERT' and new.version<>1 then raise exception using errcode='40001',message='initial reward pointer version must be 1'; end if;
 perform 1 from private.reward_rules where id=new.reward_rule_id and reason=new.reason and active and coins>0 and xp>0 and score>0;
 if not found then raise exception using errcode='23514',message='positive active discover rule required'; end if;
 new.changed_at:=clock_timestamp(); return new;
end $$;
create trigger reward_current_guard before insert or update or delete on private.reward_rule_current for each row execute function private.guard_reward_current();
-- Easy adjustment through trusted SQL only. No API role or runtime role can insert/change rules.
create function private.configure_discovery_reward_rule(p_coins bigint,p_xp bigint,p_score bigint,p_expected_version bigint,p_reason text,p_operation uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare c private.reward_rule_current; new_rule private.reward_rules; next_rule_version bigint; args jsonb; args_hash text; previous private.reward_config_commands; result jsonb;
begin
 if current_user<>'postgres' then raise exception using errcode='42501',message='trusted SQL reward configuration required'; end if;
 if p_coins is null or p_xp is null or p_score is null or p_coins<=0 or p_xp<=0 or p_score<=0 then raise exception using errcode='22023',message='positive reward values required; zero semantics not activated'; end if;
 if p_reason is null or btrim(p_reason)='' or length(p_reason)>4000 then raise exception using errcode='22023',message='configuration reason required'; end if;
 if p_operation is null then raise exception using errcode='22023',message='operation_id required'; end if;
 args:=jsonb_build_object('coins',p_coins,'xp',p_xp,'score',p_score,'expected_version',p_expected_version,'reason',p_reason);
 args_hash:=encode(sha256(convert_to(args::text,'UTF8')),'hex');
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fact.reward.config.discover',0));
 select * into previous from private.reward_config_commands where operation_id=p_operation;
 if found then
  if previous.payload_hash is distinct from args_hash then raise exception using errcode='22023',message='configuration operation payload conflict'; end if;
  return previous.result;
 end if;
 select * into c from private.reward_rule_current where reason='discover' for update;
 if (found and c.version is distinct from p_expected_version) or (not found and p_expected_version is distinct from 0::bigint) then
 raise exception using errcode='40001',message='reward configuration version conflict'; end if;
 select coalesce(max(rule_version),0)+1 into next_rule_version from private.reward_rules;
 insert into private.reward_rules(rule_version,reason,coins,xp,score,active) values(next_rule_version,'discover',p_coins,p_xp,p_score,true) returning * into new_rule;
 insert into private.reward_rule_current(reason,reward_rule_id,version) values('discover',new_rule.id,1)
 on conflict(reason) do update set reward_rule_id=excluded.reward_rule_id,version=reward_rule_current.version+1 returning * into c;
 insert into private.audit_log(action,entity_type,entity_id,reason,operation_id,changes)
 values('configure_reward','reward_rule',new_rule.id::text,p_reason,p_operation,jsonb_build_object('reason','discover','rule_version',new_rule.rule_version,'config_version',c.version,'coins',p_coins,'xp',p_xp,'score',p_score,'database_role',current_user));
 result:=jsonb_build_object('operation_id',p_operation,'rule_id',new_rule.id,'rule_version',new_rule.rule_version,'config_version',c.version,'coins',new_rule.coins,'xp',new_rule.xp,'score',new_rule.score);
 insert into private.reward_config_commands(operation_id,payload_hash,result) values(p_operation,args_hash,result);
 return result;
end $$;
revoke execute on function private.guard_reward_current(),private.configure_discovery_reward_rule(bigint,bigint,bigint,bigint,text,uuid) from public,anon,authenticated,service_role,fact_runtime;
-- This is the only production rule seed, explicitly approved by the user. No content/user/test data.
select private.configure_discovery_reward_rule(50,10,10,0,'User-approved initial discover reward: 50 coins, 10 XP, 10 ranking score','70000000-0000-4000-8000-000000000001');

create policy runtime_reward_rule_read on private.reward_rules for select to fact_runtime using(true);
create policy runtime_reward_current_read on private.reward_rule_current for select to fact_runtime using(true);
-- SELECT FOR SHARE also needs the UPDATE USING policy; actual updates fail WITH CHECK/trigger.
create policy runtime_reward_current_lock on private.reward_rule_current for update to fact_runtime using(true) with check(false);
create policy runtime_claim_read on private.reward_claims for select to fact_runtime using(user_id=private.request_actor());
create policy runtime_claim_insert on private.reward_claims for insert to fact_runtime with check(user_id=private.request_actor());
create policy runtime_wallet_journal on private.wallet_entries to fact_runtime using(user_id=private.request_actor()) with check(user_id=private.request_actor());
create policy runtime_progress_journal on private.progress_entries to fact_runtime using(user_id=private.request_actor()) with check(user_id=private.request_actor());
create policy runtime_wallet_projection on app.wallet_balances to fact_runtime using(user_id=private.request_actor()) with check(user_id=private.request_actor());
create policy runtime_progress_projection on app.progress_totals to fact_runtime using(user_id=private.request_actor()) with check(user_id=private.request_actor());
grant select on private.reward_rules,private.reward_rule_current,private.reward_claims,private.wallet_entries,private.progress_entries,app.wallet_balances,app.progress_totals to fact_runtime;
grant insert on private.reward_claims,private.wallet_entries,private.progress_entries,app.wallet_balances,app.progress_totals to fact_runtime;
grant update(coin_balance,version,updated_at) on app.wallet_balances to fact_runtime;
grant update(xp,score,version,updated_at) on app.progress_totals to fact_runtime;
grant update(confirmed_at,origin,version) on app.collected_facts to fact_runtime;
-- FOR SHARE needs UPDATE capability; the pointer trigger forbids actual runtime mutation.
grant update(reason) on private.reward_rule_current to fact_runtime;
grant usage on sequence private.wallet_entries_id_seq,private.progress_entries_id_seq to fact_runtime;
create or replace function private.guard_reward_claim() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not private.is_registered() or new.user_id is distinct from private.request_actor() then raise exception using errcode='42501',message='own registered reward claim required'; end if;
 if new.reason<>'discover' then raise exception using errcode='0A000',message='only discover rewards activated'; end if;
 perform 1 from private.reward_rule_current c join private.reward_rules r on r.id=c.reward_rule_id and r.reason=c.reason
 where c.reason=new.reason and c.reward_rule_id=new.reward_rule_id and r.active and r.coins>0 and r.xp>0 and r.score>0 for share of c;
 if not found then raise exception using errcode='23514',message='claim must bind current positive discover rule'; end if;
 new.created_at:=clock_timestamp(); return new;
end $$;
revoke execute on function private.guard_reward_claim() from public,anon,authenticated,service_role;
grant create on schema private to fact_runtime;
alter function private.guard_reward_claim() owner to fact_runtime;
-- Existing Definer is owned by NOINHERIT role: replace it explicitly AS owner; preserve its ACL.
set local role fact_runtime;
create function private.check_collection_measurement(p_lat double precision,p_lng double precision,p_accuracy_m double precision,p_measured_at timestamptz,p_received_at timestamptz) returns void language plpgsql immutable security invoker set search_path='' as $$
begin
 if p_received_at is null or not isfinite(p_received_at) then raise exception using errcode='22023',message='finite server receipt time required'; end if;
 if p_lat is null or p_lng is null or p_lat::text in ('NaN','Infinity','-Infinity') or p_lng::text in ('NaN','Infinity','-Infinity') or
 p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception using errcode='22023',message='finite latitude/longitude required'; end if;
 if p_accuracy_m is null or p_accuracy_m::text in ('NaN','Infinity','-Infinity') or p_accuracy_m<0 or p_accuracy_m>30 then
 raise exception using errcode='22023',message='GPS accuracy must be between 0 and 30 metres'; end if;
 if p_measured_at is null or not isfinite(p_measured_at) or p_measured_at<p_received_at-interval '30 seconds' or p_measured_at>p_received_at+interval '5 seconds' then
 raise exception using errcode='22023',message='GPS measurement exceeds 30s age or 5s future skew'; end if;
end $$;
revoke execute on function private.check_collection_measurement(double precision,double precision,double precision,timestamptz,timestamptz) from public,anon,authenticated,service_role;
create or replace function private.collect_fact(p_fact_id bigint,p_lat double precision,p_lng double precision,p_accuracy_m double precision,p_measured_at timestamptz,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 args jsonb; cached jsonb; received_at timestamptz:=clock_timestamp(); confirmed_time timestamptz;
 actor uuid:=private.request_actor(); fact_city uuid; f_location extensions.geography;
 rule private.reward_rules; claim private.reward_claims; collection app.collected_facts;
 balance app.wallet_balances; progress app.progress_totals; is_new_claim boolean;
begin
 args:=jsonb_build_object('fact_id',p_fact_id,'lat',p_lat,'lng',p_lng,'accuracy_m',p_accuracy_m,'measured_at',p_measured_at at time zone 'UTC');
 cached:=private.command_begin(p_operation,'collect_fact',args); if cached is not null then return cached; end if;
 perform private.check_collection_measurement(p_lat,p_lng,p_accuracy_m,p_measured_at,received_at);
 -- Fixed order: city, fact, current rule, per-user award lock, collection/journals/projections.
 select city_id into fact_city from app.facts where id=p_fact_id and status='published';
 if not found then raise exception using errcode='22023',message='published located fact required'; end if;
 perform 1 from app.cities where id=fact_city and status='live' for share;
 if not found then raise exception using errcode='22023',message='live city required'; end if;
 select location into f_location from app.facts where id=p_fact_id and city_id=fact_city and status='published' for share;
 if not found or f_location is null then raise exception using errcode='22023',message='published located fact required'; end if;
 if not extensions.st_dwithin(f_location,extensions.st_setsrid(extensions.st_makepoint(p_lng,p_lat),4326)::extensions.geography,50) then
 raise exception using errcode='22023',message='outside 50 metre collection radius'; end if;
 select r.* into rule from private.reward_rule_current c join private.reward_rules r on r.id=c.reward_rule_id and r.reason=c.reason
 where c.reason='discover' and r.active and r.coins>0 and r.xp>0 and r.score>0 for share of c;
 if not found then raise exception using errcode='0A000',message='discover reward configuration unavailable'; end if;
 -- User advisory lock avoids a profile-row-lock/receipt-FK deadlock with concurrent offline notes.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fact.reward.user:'||actor::text,0));
 insert into private.reward_claims(user_id,fact_id,reason,reward_rule_id) values(actor,p_fact_id,'discover',rule.id)
 on conflict(user_id,fact_id,reason) do nothing returning * into claim;
 is_new_claim:=found;
 if is_new_claim then
  confirmed_time:=clock_timestamp();
  insert into app.collected_facts(user_id,fact_id,first_recorded_at,confirmed_at,origin) values(actor,p_fact_id,confirmed_time,confirmed_time,'online_discovery')
  on conflict(user_id,fact_id) do update set
   confirmed_at=coalesce(collected_facts.confirmed_at,greatest(collected_facts.first_recorded_at,excluded.confirmed_at)),
   origin=case when collected_facts.confirmed_at is null then 'online_discovery' else collected_facts.origin end,
   version=case when collected_facts.confirmed_at is null then collected_facts.version+1 else collected_facts.version end returning * into collection;
  insert into private.wallet_entries(user_id,kind,source_key,claim_id,coin_delta) values(actor,'reward','discover:'||claim.id::text,claim.id,rule.coins);
  insert into private.progress_entries(user_id,claim_id,xp_delta,score_delta) values(actor,claim.id,rule.xp,rule.score);
  insert into app.wallet_balances(user_id,coin_balance) values(actor,rule.coins)
  on conflict(user_id) do update set coin_balance=wallet_balances.coin_balance+excluded.coin_balance,version=wallet_balances.version+1,updated_at=clock_timestamp() returning * into balance;
  insert into app.progress_totals(user_id,xp,score) values(actor,rule.xp,rule.score)
  on conflict(user_id) do update set xp=progress_totals.xp+excluded.xp,score=progress_totals.score+excluded.score,version=progress_totals.version+1,updated_at=clock_timestamp() returning * into progress;
 else
  select * into strict claim from private.reward_claims where user_id=actor and fact_id=p_fact_id and reason='discover';
  select * into strict collection from app.collected_facts where user_id=actor and fact_id=p_fact_id and confirmed_at is not null;
  select * into strict balance from app.wallet_balances where user_id=actor;
  select * into strict progress from app.progress_totals where user_id=actor;
 end if;
 return private.command_finish(p_operation,'collect_fact',args,collection.version,
  jsonb_build_object('fact_id',p_fact_id,'confirmed_at',collection.confirmed_at,'origin',collection.origin,
   'rewarded',is_new_claim,'already_claimed',not is_new_claim,'reward_rule_id',claim.reward_rule_id,
   'credited_coins',case when is_new_claim then rule.coins else 0 end,'credited_xp',case when is_new_claim then rule.xp else 0 end,
   'credited_score',case when is_new_claim then rule.score else 0 end,'coin_balance',balance.coin_balance,'xp',progress.xp,'score',progress.score));
end $$;
reset role;
revoke create on schema private to fact_runtime;
commit;
;
