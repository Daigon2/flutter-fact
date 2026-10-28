create table app.fact_submissions (
 id uuid primary key default gen_random_uuid(), author_id uuid not null references app.profiles on delete restrict,
 target_fact_id bigint references app.facts on delete restrict, base_version bigint,
 payload_version integer not null check(payload_version=1), draft_payload jsonb not null check(jsonb_typeof(draft_payload)='object' and octet_length(draft_payload::text)<=65536),
 state text not null default 'draft' check(state in ('draft','submitted','approved','rejected','withdrawn')),
 reviewer_id uuid references app.profiles on delete restrict, review_note text, reviewed_at timestamptz,
 version bigint not null default 1 check(version>0), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check((target_fact_id is null and base_version is null) or (target_fact_id is not null and base_version is not null and base_version>0)),
 check((state in ('approved','rejected') and reviewer_id is not null and reviewed_at is not null) or (state not in ('approved','rejected') and reviewer_id is null and reviewed_at is null))
);
create index submissions_author on app.fact_submissions(author_id,created_at desc);
create index submissions_target on app.fact_submissions(target_fact_id) where target_fact_id is not null;
create index submissions_reviewer on app.fact_submissions(reviewer_id) where reviewer_id is not null;
create table private.fact_revisions (
 fact_id bigint not null references app.facts on delete restrict, revision_no bigint not null check(revision_no>0),
 submission_id uuid references app.fact_submissions on delete restrict, published_by uuid not null references app.profiles on delete restrict,
 snapshot jsonb not null check(jsonb_typeof(snapshot)='object'), created_at timestamptz not null default now(), primary key(fact_id,revision_no)
);
alter table app.facts add constraint published_fact_revision_fk foreign key(id,published_revision) references private.fact_revisions(fact_id,revision_no) deferrable initially deferred;
create index revision_submission on private.fact_revisions(submission_id) where submission_id is not null;
create index revision_publisher on private.fact_revisions(published_by);
create trigger revision_append_only before update or delete on private.fact_revisions for each row execute function private.append_only();

create table app.media_assets (
 id uuid primary key default gen_random_uuid(), owner_id uuid references app.profiles on delete restrict,
 storage_bucket text, storage_path text, external_url text check(external_url is null or external_url ~ '^https?://'),
 thumbnail_asset_id uuid references app.media_assets on delete restrict,
 content_sha256 text check(content_sha256 is null or content_sha256 ~ '^[0-9a-f]{64}$'),
 byte_size bigint check(byte_size>0), width integer check(width>0), height integer check(height>0), mime_type text,
 source_url text, license text, attribution text, year integer, provenance text,
 state text not null default 'draft' check(state in ('draft','ready','blocked')), frozen_at timestamptz,
 created_at timestamptz not null default now(),
 check((storage_bucket is null)=(storage_path is null)),
 check((storage_path is not null)::integer+(external_url is not null)::integer=1),
 check(storage_path is null or (storage_path<>'' and storage_path !~ '(^/|(^|/)\.\.(/|$))')),
 check(state<>'ready' or (storage_path is not null and content_sha256 is not null and byte_size is not null and mime_type is not null and frozen_at is not null)),
 check(thumbnail_asset_id is distinct from id), unique(storage_bucket,storage_path)
);
create index media_owner on app.media_assets(owner_id) where owner_id is not null;
create index media_thumbnail on app.media_assets(thumbnail_asset_id) where thumbnail_asset_id is not null;
create table app.fact_media (
 fact_id bigint not null references app.facts on delete restrict, media_id uuid not null references app.media_assets on delete restrict,
 role text not null check(role in ('hero','historical','puzzle','illustration')), position integer not null check(position>0), language_code app.language_code,
 primary key(fact_id,media_id,role), unique(fact_id,role,position)
);
create index fact_media_asset on app.fact_media(media_id);

create table app.puzzles (
 id uuid primary key default gen_random_uuid(), fact_id bigint not null references app.facts on delete restrict,
 current_version_id uuid, archived_at timestamptz, version bigint not null default 1 check(version>0), created_at timestamptz not null default now()
);
create index puzzles_fact on app.puzzles(fact_id);
create table app.puzzle_versions (
 id uuid primary key default gen_random_uuid(), puzzle_id uuid not null references app.puzzles on delete restrict,
 revision_no integer not null check(revision_no>=1), presentation_type text not null check(btrim(presentation_type)<>''),
 evaluation_type text not null check(evaluation_type in ('text','number','choice','count','combination','estimate','manual')),
 difficulty text not null check(difficulty in ('leicht','mittel','schwer')), gps_radius_m integer check(gps_radius_m>0),
 quality smallint check(quality between 1 and 3), findability text, provenance text,
 state text not null default 'draft' check(state in ('draft','published')), published_at timestamptz,
 created_at timestamptz not null default now(),
 check((state='draft' and published_at is null) or (state='published' and published_at is not null)),
 unique(puzzle_id,revision_no), unique(puzzle_id,id)
);
alter table app.puzzles add foreign key(id,current_version_id) references app.puzzle_versions(puzzle_id,id) on delete restrict;
create index puzzle_current on app.puzzles(id,current_version_id) where current_version_id is not null;
create table app.puzzle_texts (
 puzzle_version_id uuid not null references app.puzzle_versions on delete restrict, language_code app.language_code not null,
 question text not null check(btrim(question)<>'' and octet_length(question)<=16384), operand_labels jsonb check(operand_labels is null or jsonb_typeof(operand_labels)='array'),
 photo_media_id uuid references app.media_assets on delete restrict,
 primary key(puzzle_version_id,language_code)
);
create index puzzle_photo on app.puzzle_texts(photo_media_id) where photo_media_id is not null;
create table app.puzzle_choices (
 puzzle_version_id uuid not null, language_code app.language_code not null, choice_id text not null check(choice_id ~ '^[A-Za-z0-9_-]{1,64}$'),
 position smallint not null check(position>0), label text not null check(btrim(label)<>'' and octet_length(label)<=4096),
 primary key(puzzle_version_id,language_code,choice_id), unique(puzzle_version_id,language_code,position),
 foreign key(puzzle_version_id,language_code) references app.puzzle_texts on delete restrict
);
create table private.puzzle_solutions (
 puzzle_version_id uuid not null, language_code app.language_code not null,
 accepted_texts text[], expected_number numeric, tolerance numeric check(tolerance>=0 and tolerance::text not in ('NaN','Infinity','-Infinity')),
 correct_choice_id text, combination_rule jsonb, explanation text,
 validation_version integer not null default 1 check(validation_version=1), primary key(puzzle_version_id,language_code),
 foreign key(puzzle_version_id,language_code) references app.puzzle_texts on delete restrict,
 foreign key(puzzle_version_id,language_code,correct_choice_id) references app.puzzle_choices(puzzle_version_id,language_code,choice_id) on delete restrict,
 check(expected_number is null or expected_number::text not in ('NaN','Infinity','-Infinity')),
 check(accepted_texts is null or (cardinality(accepted_texts) between 1 and 100 and array_position(accepted_texts,null) is null and octet_length(accepted_texts::text)<=16384)),
 check(explanation is null or octet_length(explanation)<=16384),
 check(combination_rule is null or (jsonb_typeof(combination_rule)='object' and octet_length(combination_rule::text)<=8192))
);
create index solution_correct on private.puzzle_solutions(puzzle_version_id,language_code,correct_choice_id);
create table private.puzzle_hints (
 puzzle_version_id uuid not null, language_code app.language_code not null, hint_index smallint not null check(hint_index>0),
 text text not null check(btrim(text)<>'' and octet_length(text)<=16384), cost_rule_id uuid,
 primary key(puzzle_version_id,language_code,hint_index),
 foreign key(puzzle_version_id,language_code) references app.puzzle_texts on delete restrict,
 constraint hint_cost_activation_pending check(cost_rule_id is null)
);

-- Every child mutation locks the SAME parent version as publishing. Do not move children between versions.
create function private.guard_puzzle_child() returns trigger language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_state text;
begin
 v_id := case when tg_op='DELETE' then old.puzzle_version_id else new.puzzle_version_id end;
 if tg_op='UPDATE' and (new.puzzle_version_id,new.language_code) is distinct from (old.puzzle_version_id,old.language_code) then
 raise exception using errcode='55000',message='puzzle child identity is immutable'; end if;
 select state into v_state from app.puzzle_versions where id=v_id for update;
 if v_state is distinct from 'draft' then raise exception using errcode='55000',message='published puzzle version is immutable'; end if;
 if tg_op='DELETE' then return old; end if; return new;
end $$;
create function private.validate_puzzle(p_version uuid) returns void language plpgsql security definer set search_path='' as $$
declare v app.puzzle_versions; t record; s private.puzzle_solutions; n integer; reference_ids text[]; ids text[]; reference_correct text;
begin
 select * into strict v from app.puzzle_versions where id=p_version for update;
 if not exists(select 1 from app.puzzle_texts where puzzle_version_id=p_version) then raise exception using errcode='23514',message='puzzle requires a playable language'; end if;
 -- Combination AST evaluation/manual evidence rules are not implemented in A. No pretend validation.
 if v.evaluation_type in ('combination','manual') then raise exception using errcode='0A000',message='evaluation type not activated'; end if;
 if v.presentation_type in ('photo','image','foto') and exists(select 1 from app.puzzle_texts where puzzle_version_id=p_version and photo_media_id is null) then
 raise exception using errcode='23514',message='image puzzle requires frozen media'; end if;
 for t in select * from app.puzzle_texts where puzzle_version_id=p_version order by language_code loop
  select * into s from private.puzzle_solutions where puzzle_version_id=p_version and language_code=t.language_code;
  if not found then raise exception using errcode='23514',message='missing solution for playable language'; end if;
  select count(*),array_agg(choice_id order by choice_id) into n,ids from app.puzzle_choices where puzzle_version_id=p_version and language_code=t.language_code;
  if v.evaluation_type='choice' then
   if n<2 or s.correct_choice_id is null or s.accepted_texts is not null or s.expected_number is not null or s.tolerance is not null or s.combination_rule is not null then
    raise exception using errcode='23514',message='choice puzzle requires at least two options and only a correct option solution'; end if;
   if reference_ids is null then reference_ids:=ids; reference_correct:=s.correct_choice_id;
   elsif ids is distinct from reference_ids or s.correct_choice_id is distinct from reference_correct then
    raise exception using errcode='23514',message='choice IDs and correct choice must agree across languages'; end if;
  elsif v.evaluation_type='text' then
   if s.accepted_texts is null or exists(select 1 from unnest(s.accepted_texts) a where btrim(a)='') or s.correct_choice_id is not null or s.expected_number is not null or s.tolerance is not null or s.combination_rule is not null or n<>0 then
    raise exception using errcode='23514',message='invalid text solution'; end if;
  elsif v.evaluation_type in ('number','count','estimate') then
   if s.expected_number is null or s.accepted_texts is not null or s.correct_choice_id is not null or s.combination_rule is not null or n<>0 then
    raise exception using errcode='23514',message='invalid numeric solution'; end if;
   if v.evaluation_type='count' and (s.expected_number<0 or s.expected_number<>trunc(s.expected_number) or coalesce(s.tolerance,0)<>trunc(coalesce(s.tolerance,0))) then
    raise exception using errcode='23514',message='count requires nonnegative integer expected value and integer tolerance'; end if;
  end if;
  if t.photo_media_id is not null then
   -- Row lock serializes media state changes with this publication.
   perform 1 from app.media_assets m where m.id=t.photo_media_id and m.state='ready' and m.frozen_at is not null and m.storage_path is not null for share;
   if not found then raise exception using errcode='23514',message='media finalization required'; end if;
  end if;
 end loop;
end $$;
create function private.guard_puzzle_version() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then
  if old.state='published' then raise exception using errcode='55000',message='published puzzle version is immutable'; end if; return old;
 end if;
 if tg_op='INSERT' and new.state<>'draft' then raise exception using errcode='55000',message='insert a draft first'; end if;
 if tg_op='UPDATE' then
  if old.state='published' then raise exception using errcode='55000',message='published puzzle version is immutable'; end if;
  if (new.id,new.puzzle_id,new.revision_no) is distinct from (old.id,old.puzzle_id,old.revision_no) then raise exception using errcode='55000',message='version identity is immutable'; end if;
  if new.state='published' then
   -- This trigger is a second integrity barrier even for trusted SQL writes.
   if (to_jsonb(new)-'state'-'published_at') is distinct from (to_jsonb(old)-'state'-'published_at') then raise exception using errcode='55000',message='save content before publication'; end if;
   perform private.validate_puzzle(old.id); new.published_at:=clock_timestamp();
  end if;
 end if;
 return new;
end $$;
create trigger puzzle_version_guard before insert or update or delete on app.puzzle_versions for each row execute function private.guard_puzzle_version();
create trigger puzzle_text_guard before insert or update or delete on app.puzzle_texts for each row execute function private.guard_puzzle_child();
create trigger puzzle_choice_guard before insert or update or delete on app.puzzle_choices for each row execute function private.guard_puzzle_child();
create trigger puzzle_solution_guard before insert or update or delete on private.puzzle_solutions for each row execute function private.guard_puzzle_child();
create trigger puzzle_hint_guard before insert or update or delete on private.puzzle_hints for each row execute function private.guard_puzzle_child();
create function private.guard_puzzle_identity() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception using errcode='55000',message='archive puzzle identities instead'; end if;
 if tg_op='UPDATE' and (new.id,new.fact_id) is distinct from (old.id,old.fact_id) then raise exception using errcode='55000',message='puzzle identity is immutable'; end if;
 if new.current_version_id is not null then
  perform 1 from app.puzzle_versions where id=new.current_version_id and puzzle_id=new.id and state='published' for share;
  if not found then raise exception using errcode='23514',message='current puzzle version must be published and belong to puzzle'; end if;
 end if;
 return new;
end $$;
create trigger puzzle_identity_guard before insert or update or delete on app.puzzles for each row execute function private.guard_puzzle_identity();

-- Storage finalizer deliberately absent. Until independently verified object-write protection exists,
-- no role, including a SQL admin following normal triggers, can label an asset ready/frozen.
create function private.guard_media() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform pg_catalog.pg_advisory_xact_lock(779100);
 if tg_op<>'INSERT' and old.frozen_at is not null then raise exception using errcode='55000',message='frozen media is immutable'; end if;
 if tg_op='DELETE' then return old; end if;
 if tg_op='UPDATE' and new.id<>old.id then raise exception using errcode='55000',message='media identity is immutable'; end if;
 if new.state='ready' or new.frozen_at is not null then raise exception using errcode='0A000',message='trusted storage finalization not activated'; end if;
 if new.thumbnail_asset_id is not null and exists(
  with recursive links(id,thumbnail_asset_id) as (
   select id,thumbnail_asset_id from app.media_assets where id=new.thumbnail_asset_id
   union select m.id,m.thumbnail_asset_id from app.media_assets m join links l on m.id=l.thumbnail_asset_id
  ) select 1 from links where id=new.id
 ) then raise exception using errcode='23514',message='thumbnail cycle'; end if;
 return new;
end $$;
create trigger media_guard before insert or update or delete on app.media_assets for each row execute function private.guard_media();

create function private.guard_fact_child() returns trigger language plpgsql security definer set search_path='' as $$
declare v_id bigint; v_status text;
begin
 v_id:=case when tg_op='DELETE' then old.fact_id else new.fact_id end;
 if tg_op='UPDATE' and new.fact_id<>old.fact_id then raise exception using errcode='55000',message='fact child identity is immutable'; end if;
 select status into v_status from app.facts where id=v_id for update;
 if v_status is distinct from 'draft' then raise exception using errcode='55000',message='published fact edits require a new reviewed revision; not activated'; end if;
 if tg_op='DELETE' then return old; end if; return new;
end $$;
create trigger fact_text_guard before insert or update or delete on app.fact_texts for each row execute function private.guard_fact_child();
create trigger fact_source_guard before insert or update or delete on app.fact_sources for each row execute function private.guard_fact_child();
create trigger fact_media_guard before insert or update or delete on app.fact_media for each row execute function private.guard_fact_child();
create trigger fact_hint_guard before insert or update or delete on app.fact_navigation_hints for each row execute function private.guard_fact_child();
create trigger fact_external_guard before insert or update or delete on app.fact_external_ids for each row execute function private.guard_fact_child();
create function private.validate_fact(p_fact bigint) returns void language plpgsql security definer set search_path='' as $$
declare f app.facts;
begin
 select * into strict f from app.facts where id=p_fact for update;
 if f.location is null or f.quality_score is null then raise exception using errcode='23514',message='publication requires location and quality'; end if;
 perform 1 from app.cities c where c.id=f.city_id and c.status='live' for share;
 if not found then raise exception using errcode='23514',message='publication requires live city'; end if;
 if not exists(select 1 from app.fact_texts t where t.fact_id=f.id and t.language_code='de' and t.translation_status='approved' and btrim(t.title)<>'' and btrim(t.body)<>'') then
 raise exception using errcode='23514',message='approved complete base text required'; end if;
 if not exists(select 1 from app.city_texts t where t.city_id=f.city_id and t.language_code='de') or
 not exists(select 1 from app.category_texts t where t.category_id=f.category_id and t.language_code=f.default_language) then
 raise exception using errcode='23514',message='base city/category translation required'; end if;
 -- An approved translation must fill every field populated in the German base.
 -- This makes language-row fallback explicit and prevents partially empty approved public translations.
 if exists(
  select 1 from app.fact_texts base join app.fact_texts tr on tr.fact_id=base.fact_id and tr.translation_status='approved'
  cross join lateral jsonb_each_text(to_jsonb(base)-'fact_id'-'language_code'-'translation_status') b
  where base.fact_id=f.id and base.language_code='de' and btrim(coalesce(b.value,''))<>''
  and btrim(coalesce(to_jsonb(tr)->>b.key,''))=''
 ) then raise exception using errcode='23514',message='approved translation must cover all populated German base fields'; end if;
 if not exists(select 1 from app.fact_sources s where s.fact_id=f.id) then raise exception using errcode='23514',message='publication requires source'; end if;
 if exists(select 1 from app.fact_media fm join app.media_assets m on m.id=fm.media_id where fm.fact_id=f.id and (m.state<>'ready' or m.frozen_at is null)) then
 raise exception using errcode='23514',message='media finalization required'; end if;
end $$;
create function private.guard_fact() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then
  if old.status<>'draft' then raise exception using errcode='55000',message='archive published facts instead'; end if; return old;
 end if;
 if tg_op='INSERT' and new.status<>'draft' then raise exception using errcode='55000',message='insert a fact draft first'; end if;
 if tg_op='UPDATE' then
  if new.id<>old.id then raise exception using errcode='55000',message='fact identity is immutable'; end if;
  if old.status<>'draft' then
   if old.status<>'published' or new.status<>'archived' or
    (to_jsonb(new)-'status'-'version'-'updated_at') is distinct from (to_jsonb(old)-'status'-'version'-'updated_at') then
    raise exception using errcode='55000',message='published fact edits not activated'; end if;
  elsif new.status='published' then
   if (to_jsonb(new)-'status'-'published_revision'-'published_at'-'version'-'updated_at') is distinct from (to_jsonb(old)-'status'-'published_revision'-'published_at'-'version'-'updated_at') then
    raise exception using errcode='55000',message='save fact content before publication'; end if;
   perform private.validate_fact(old.id);
  elsif new.status<>'draft' then raise exception using errcode='55000',message='invalid fact state transition';
  end if;
 end if;
 return new;
end $$;
create trigger fact_guard before insert or update or delete on app.facts for each row execute function private.guard_fact();

-- Command retry serialization includes payload equality. Operation UUID is actor-scoped across commands.
create function private.command_begin(p_operation uuid,p_command text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r private.command_receipts;
begin
 if not private.is_registered() then raise exception using errcode='42501',message='registered account required'; end if;
 if p_operation is null then raise exception using errcode='22023',message='operation_id required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(private.request_actor()::text||p_operation::text,0));
 select * into r from private.command_receipts where actor_id=private.request_actor() and operation_id=p_operation;
 if found then
  if r.command<>p_command or r.payload_hash is distinct from encode(sha256(convert_to(p_payload::text,'UTF8')),'hex') then raise exception using errcode='22023',message='operation_id payload conflict'; end if;
  return r.result;
 end if;
 return null;
end $$;
create function private.command_finish(p_operation uuid,p_command text,p_payload jsonb,p_version bigint,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.is_registered() then raise exception using errcode='42501',message='registered account required'; end if;
 result:=jsonb_build_object('api_version',1,'operation_id',p_operation,'server_time',clock_timestamp(),'entity_version',p_version,'data',p_data);
 insert into private.command_receipts(actor_id,operation_id,command,payload_hash,result) values(private.request_actor(),p_operation,p_command,encode(sha256(convert_to(p_payload::text,'UTF8')),'hex'),result);
 return result;
end $$;
create function private.save_submission(p_id uuid,p_target bigint,p_base_version bigint,p_payload jsonb,p_expected_version bigint,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare args jsonb; cached jsonb; s app.fact_submissions; actor uuid:=private.request_actor();
begin
 args:=jsonb_build_object('id',p_id,'target',p_target,'base_version',p_base_version,'payload',p_payload,'expected_version',p_expected_version);
 cached:=private.command_begin(p_operation,'save_submission',args); if cached is not null then return cached; end if;
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>65536 then raise exception using errcode='22023',message='bounded object payload required'; end if;
 if p_target is not null and not exists(select 1 from app.facts where id=p_target and status='published' and version=p_base_version) then raise exception using errcode='40001',message='target fact version conflict'; end if;
 if p_id is null then
  if p_expected_version is distinct from 0::bigint then raise exception using errcode='40001',message='new submission requires expected_version 0'; end if;
  insert into app.fact_submissions(author_id,target_fact_id,base_version,payload_version,draft_payload) values(actor,p_target,p_base_version,1,p_payload) returning * into s;
 else
  select * into s from app.fact_submissions where id=p_id for update;
  if not found or s.author_id<>actor then raise exception using errcode='42501',message='submission not accessible'; end if;
  if s.state<>'draft' or s.version is distinct from p_expected_version then raise exception using errcode='40001',message='submission state/version conflict'; end if;
  update app.fact_submissions set target_fact_id=p_target,base_version=p_base_version,draft_payload=p_payload,version=version+1,updated_at=clock_timestamp() where id=p_id returning * into s;
 end if;
 return private.command_finish(p_operation,'save_submission',args,s.version,jsonb_build_object('submission_id',s.id,'state',s.state));
end $$;
create function private.transition_submission(p_id uuid,p_action text,p_note text,p_expected_version bigint,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare args jsonb; cached jsonb; s app.fact_submissions; next_state text;
begin
 args:=jsonb_build_object('id',p_id,'action',p_action,'note',p_note,'expected_version',p_expected_version);
 cached:=private.command_begin(p_operation,'transition_submission',args); if cached is not null then return cached; end if;
 select * into s from app.fact_submissions where id=p_id for update;
 if not found then raise exception using errcode='42501',message='submission not accessible'; end if;
 if s.version is distinct from p_expected_version then raise exception using errcode='40001',message='submission version conflict'; end if;
 if p_action='submit' and s.author_id=private.request_actor() and s.state='draft' then next_state:='submitted';
 elsif p_action='withdraw' and s.author_id=private.request_actor() and s.state in ('draft','submitted') then next_state:='withdrawn';
 elsif p_action='reject' and private.has_role(array['editor','admin']) and s.state='submitted' then
  if p_note is null or btrim(p_note)='' or length(p_note)>4000 then raise exception using errcode='22023',message='review reason required'; end if;
  next_state:='rejected';
 elsif p_action='approve' and private.has_role(array['editor','admin']) then
  raise exception using errcode='0A000',message='typed submission application and approval not activated';
 else raise exception using errcode='42501',message='submission transition not permitted'; end if;
 update app.fact_submissions set state=next_state,version=version+1,updated_at=clock_timestamp(),
 reviewer_id=case when next_state='rejected' then private.request_actor() else null end,
 review_note=case when next_state='rejected' then p_note else null end,
 reviewed_at=case when next_state='rejected' then clock_timestamp() else null end where id=p_id returning * into s;
 insert into private.audit_log(actor_id,action,entity_type,entity_id,reason,operation_id,changes)
 values(private.request_actor(),p_action,'submission',p_id::text,case when next_state='rejected' then p_note else null end,p_operation,jsonb_build_object('state',s.state,'version',s.version));
 return private.command_finish(p_operation,'transition_submission',args,s.version,jsonb_build_object('submission_id',s.id,'state',s.state));
end $$;
create function private.publish_fact(p_id bigint,p_expected_version bigint,p_reason text,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare args jsonb; cached jsonb; f app.facts; snapshot jsonb;
begin
 if not private.has_role(array['editor','admin']) then raise exception using errcode='42501',message='editor role required'; end if;
 args:=jsonb_build_object('id',p_id,'expected_version',p_expected_version,'reason',p_reason);
 cached:=private.command_begin(p_operation,'publish_fact',args); if cached is not null then return cached; end if;
 if p_reason is null or btrim(p_reason)='' or length(p_reason)>4000 then raise exception using errcode='22023',message='publication reason required'; end if;
 select * into f from app.facts where id=p_id for update;
 if not found or f.status<>'draft' or f.version is distinct from p_expected_version then raise exception using errcode='40001',message='fact state/version conflict'; end if;
 perform private.validate_fact(p_id);
 snapshot:=jsonb_build_object('fact',to_jsonb(f),'texts',(select coalesce(jsonb_agg(to_jsonb(t) order by t.language_code),'[]') from app.fact_texts t where t.fact_id=p_id),
 'sources',(select coalesce(jsonb_agg(to_jsonb(s) order by s.position),'[]') from app.fact_sources s where s.fact_id=p_id),
 'media',(select coalesce(jsonb_agg(to_jsonb(m) order by m.role,m.position),'[]') from app.fact_media m where m.fact_id=p_id));
 insert into private.fact_revisions(fact_id,revision_no,published_by,snapshot) values(p_id,1,private.request_actor(),snapshot);
 update app.facts set status='published',published_revision=1,published_at=clock_timestamp(),version=version+1,updated_at=clock_timestamp() where id=p_id returning * into f;
 insert into private.audit_log(actor_id,action,entity_type,entity_id,reason,operation_id,changes) values(private.request_actor(),'publish','fact',p_id::text,p_reason,p_operation,jsonb_build_object('revision',1,'version',f.version));
 return private.command_finish(p_operation,'publish_fact',args,f.version,jsonb_build_object('fact_id',p_id,'revision',1));
end $$;
create function private.publish_puzzle(p_id uuid,p_version_id uuid,p_expected_version bigint,p_reason text,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare args jsonb; cached jsonb; p app.puzzles; v app.puzzle_versions;
begin
 if not private.has_role(array['editor','admin']) then raise exception using errcode='42501',message='editor role required'; end if;
 args:=jsonb_build_object('id',p_id,'version_id',p_version_id,'expected_version',p_expected_version,'reason',p_reason);
 cached:=private.command_begin(p_operation,'publish_puzzle',args); if cached is not null then return cached; end if;
 if p_reason is null or btrim(p_reason)='' or length(p_reason)>4000 then raise exception using errcode='22023',message='publication reason required'; end if;
 -- Order: identity, then version. Child mutations lock only the version.
 select * into p from app.puzzles where id=p_id for update;
 if not found or p.archived_at is not null or p.version is distinct from p_expected_version then raise exception using errcode='40001',message='puzzle state/version conflict'; end if;
 if not exists(select 1 from app.facts where id=p.fact_id and status='published') then raise exception using errcode='23514',message='published fact required'; end if;
 select * into v from app.puzzle_versions where id=p_version_id and puzzle_id=p_id for update;
 if not found or v.state<>'draft' then raise exception using errcode='23514',message='own draft puzzle version required'; end if;
 perform private.validate_puzzle(p_version_id);
 update app.puzzle_versions set state='published' where id=p_version_id;
 update app.puzzles set current_version_id=p_version_id,version=version+1 where id=p_id returning * into p;
 insert into private.audit_log(actor_id,action,entity_type,entity_id,reason,operation_id,changes) values(private.request_actor(),'publish','puzzle',p_id::text,p_reason,p_operation,jsonb_build_object('version_id',p_version_id,'version',p.version));
 return private.command_finish(p_operation,'publish_puzzle',args,p.version,jsonb_build_object('puzzle_id',p_id,'puzzle_version_id',p_version_id));
end $$;

create function private.set_username(p_username text,p_expected_version bigint,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare args jsonb; cached jsonb; p app.profiles; normalized text:=lower(p_username);
begin
 args:=jsonb_build_object('username',p_username,'expected_version',p_expected_version);
 cached:=private.command_begin(p_operation,'set_username',args); if cached is not null then return cached; end if;
 if normalized is null or normalized !~ '^[a-z0-9_]{3,24}$' then raise exception using errcode='22023',message='username requires 3-24 ASCII letters, digits or underscore'; end if;
 select * into p from app.profiles where id=private.request_actor() for update;
 if not found or p.version is distinct from p_expected_version then raise exception using errcode='40001',message='profile version conflict'; end if;
 if p.username is not null then raise exception using errcode='55000',message='username already assigned; rename disabled'; end if;
 begin
 update app.profiles set username=normalized,username_set_at=clock_timestamp(),updated_at=clock_timestamp(),version=version+1 where id=private.request_actor() returning * into p;
 exception when unique_violation then raise exception using errcode='23505',message='username already occupied'; end;
 return private.command_finish(p_operation,'set_username',args,p.version,jsonb_build_object('username',p.username));
end $$;
create function private.set_rankings_visibility(p_visible boolean,p_expected_version bigint,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare args jsonb; cached jsonb; p app.profiles;
begin
 args:=jsonb_build_object('visible',p_visible,'expected_version',p_expected_version);
 cached:=private.command_begin(p_operation,'set_rankings_visibility',args); if cached is not null then return cached; end if;
 if p_visible is null then raise exception using errcode='22023',message='visible boolean required'; end if;
 select * into p from app.profiles where id=private.request_actor() for update;
 if not found or p.version is distinct from p_expected_version then raise exception using errcode='40001',message='profile version conflict'; end if;
 update app.profiles set show_in_rankings=p_visible,updated_at=clock_timestamp(),version=version+1 where id=private.request_actor() returning * into p;
 return private.command_finish(p_operation,'set_rankings_visibility',args,p.version,jsonb_build_object('visible',p.show_in_rankings));
end $$;

-- All new tables have RLS, including private solution tables.
do $$ declare r record; begin
 for r in select tablename,schemaname from pg_tables where schemaname in ('app','private') loop
  execute format('alter table %I.%I enable row level security',r.schemaname,r.tablename);
 end loop;
end $$;
-- Runtime only receives the capabilities exercised by the fixed SQL functions above.
grant select on app.cities,app.city_texts,app.categories,app.category_texts,app.facts,app.fact_texts,app.fact_sources,app.fact_media,app.media_assets,
 app.fact_submissions,app.puzzles,app.puzzle_versions,app.puzzle_texts,app.puzzle_choices,private.puzzle_solutions,private.puzzle_hints to fact_runtime;
-- Row-locking SELECT FOR SHARE requires an UPDATE capability; no exposed function exercises these ID updates.
grant update(id) on app.cities,app.media_assets to fact_runtime;
grant update(username,username_set_at,updated_at,version,show_in_rankings) on app.profiles to fact_runtime;
grant insert,update on app.fact_submissions to fact_runtime;
grant insert on private.fact_revisions to fact_runtime;
grant update(status,published_revision,published_at,version,updated_at) on app.facts to fact_runtime;
grant update(current_version_id,version) on app.puzzles to fact_runtime;
grant update(state,published_at) on app.puzzle_versions to fact_runtime;
do $$ declare t text; begin
 foreach t in array array['cities','city_texts','categories','category_texts','facts','fact_texts','fact_sources','fact_media','media_assets','fact_submissions','puzzles','puzzle_versions','puzzle_texts','puzzle_choices'] loop
  execute format('create policy runtime_access on app.%I to fact_runtime using(true) with check(true)',t);
 end loop;
 foreach t in array array['fact_revisions','puzzle_solutions','puzzle_hints'] loop
  execute format('create policy runtime_access on private.%I to fact_runtime using(true) with check(true)',t);
 end loop;
end $$;
-- Live roles are read from protected rows, never user_metadata or user-editable role claims.
create policy author_editor_submission on app.fact_submissions for select to authenticated using(
 (select private.is_registered()) and (author_id=(select auth.uid()) or (select private.has_role(array['editor','admin'])))
);
grant select on app.fact_submissions to authenticated;

create policy public_city on app.cities for select to anon,authenticated using(status='live');
create policy public_city_text on app.city_texts for select to anon,authenticated using(exists(select 1 from app.cities c where c.id=city_id));
create policy public_city_alias on app.city_aliases for select to anon,authenticated using(exists(select 1 from app.cities c where c.id=city_id));
create policy public_category on app.categories for select to anon,authenticated using(true);
create policy public_category_text on app.category_texts for select to anon,authenticated using(true);
create policy public_genre on app.genres for select to anon,authenticated using(true);
create policy public_genre_text on app.genre_texts for select to anon,authenticated using(true);
create policy public_zone on app.city_zones for select to anon,authenticated using(exists(select 1 from app.cities c where c.id=city_id));
create policy public_fact on app.facts for select to anon,authenticated using(status='published' and exists(select 1 from app.cities c where c.id=city_id));
create policy public_fact_text on app.fact_texts for select to anon,authenticated using(translation_status='approved' and exists(select 1 from app.facts f where f.id=fact_id));
create policy public_fact_source on app.fact_sources for select to anon,authenticated using(exists(select 1 from app.facts f where f.id=fact_id));
create policy public_fact_media on app.fact_media for select to anon,authenticated using(exists(select 1 from app.facts f where f.id=fact_id));
create policy public_media on app.media_assets for select to anon,authenticated using(state='ready' and exists(select 1 from app.fact_media fm where fm.media_id=id));
create policy public_puzzle on app.puzzles for select to anon,authenticated using(archived_at is null and current_version_id is not null and exists(select 1 from app.facts f where f.id=fact_id));
create policy public_puzzle_version on app.puzzle_versions for select to anon,authenticated using(state='published' and exists(select 1 from app.puzzles p where p.id=puzzle_id and p.current_version_id=puzzle_versions.id));
create policy public_puzzle_text on app.puzzle_texts for select to anon,authenticated using(exists(select 1 from app.puzzle_versions v where v.id=puzzle_version_id));
create policy public_puzzle_choice on app.puzzle_choices for select to anon,authenticated using(exists(select 1 from app.puzzle_versions v where v.id=puzzle_version_id));
-- No public navigation hints, solutions, puzzle hints, external IDs, revisions, roles or audit.
grant select on app.cities,app.city_texts,app.city_aliases,app.categories,app.category_texts,app.genres,app.genre_texts,app.city_zones,
 app.fact_texts,app.fact_sources,app.fact_media,app.puzzles,app.puzzle_versions,app.puzzle_texts,app.puzzle_choices to anon,authenticated;
-- Column grants prevent accidental auth UUID/author disclosure through a client-side base-table read.
grant select(id,city_id,category_id,genre_id,zone_id,location,quality_score,origin,status,default_language,hero_colors,published_revision,version,published_at) on app.facts to anon,authenticated;
grant select(id,storage_bucket,storage_path,external_url,thumbnail_asset_id,width,height,mime_type,source_url,license,attribution,year,provenance,state,frozen_at) on app.media_assets to anon,authenticated;

-- Public output contains no expected answers, correct choice IDs or paid hints.
create view public.facts with(security_invoker=true) as
select f.id,t.title as titel,t.body as text,t.body_extra as text2,t.body_background as text3,t.body_today as text4,
 t.place as ort,cat.label as kategorie,t.source_display as quelle,t.caption,
 ct.name as city,c.slug as city_slug,f.city_id,f.category_id,f.genre_id as genre,z.code as zone,
 extensions.st_y(f.location::extensions.geometry) as lat,extensions.st_x(f.location::extensions.geometry) as lng,
 f.quality_score,f.hero_colors as hero,(f.origin='community') as is_user_created,true as is_approved,f.version,f.published_at,
 'de'::text as content_language,false as is_language_fallback,
 coalesce((select jsonb_object_agg(i.language_code,jsonb_build_object('titel',i.title,'text',i.body,'text2',i.body_extra,'text3',i.body_background,'text4',i.body_today,'ort',i.place,'quelle',i.source_display,'caption',i.caption)) from app.fact_texts i where i.fact_id=f.id),'{}'::jsonb) as _i18n,
 '[]'::jsonb as puzzle_fit
from app.facts f join app.fact_texts t on t.fact_id=f.id and t.language_code='de'
join app.cities c on c.id=f.city_id join app.city_texts ct on ct.city_id=c.id and ct.language_code='de'
join app.category_texts cat on cat.category_id=f.category_id and cat.language_code='de'
left join app.city_zones z on z.id=f.zone_id and z.city_id=f.city_id
where f.status='published';
grant select on public.facts to anon,authenticated;
-- Requested-language endpoint explicitly marks the approved German fallback. No fallback for puzzles.
create function public.get_fact_text(p_fact_id bigint,p_language text) returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('fact_id',t.fact_id,'requested_language',p_language,'content_language',t.language_code,
 'is_language_fallback',t.language_code<>p_language,'title',t.title,'body',t.body,'body_extra',t.body_extra,'body_background',t.body_background,'body_today',t.body_today,'place',t.place,'caption',t.caption,'source_display',t.source_display)
 from app.fact_texts t where t.fact_id=p_fact_id and t.language_code in (p_language,'de')
 order by (t.language_code=p_language) desc limit 1
$$;

-- API wrappers execute with invoker privileges; privileged implementations are not in an API schema.
create function public.save_submission(p_id uuid,p_target bigint,p_base_version bigint,p_payload jsonb,p_expected_version bigint,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.save_submission(p_id,p_target,p_base_version,p_payload,p_expected_version,p_operation) $$;
create function public.transition_submission(p_id uuid,p_action text,p_note text,p_expected_version bigint,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.transition_submission(p_id,p_action,p_note,p_expected_version,p_operation) $$;
create function public.publish_fact(p_id bigint,p_expected_version bigint,p_reason text,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.publish_fact(p_id,p_expected_version,p_reason,p_operation) $$;
create function public.publish_puzzle(p_id uuid,p_version_id uuid,p_expected_version bigint,p_reason text,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.publish_puzzle(p_id,p_version_id,p_expected_version,p_reason,p_operation) $$;
create function public.set_username(p_username text,p_expected_version bigint,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.set_username(p_username,p_expected_version,p_operation) $$;
create function public.set_rankings_visibility(p_visible boolean,p_expected_version bigint,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.set_rankings_visibility(p_visible,p_expected_version,p_operation) $$;
create function public.check_username(p_username text) returns boolean language plpgsql stable security definer set search_path='' as $$
begin
 if p_username is null or lower(p_username) !~ '^[a-z0-9_]{3,24}$' then raise exception using errcode='22023',message='invalid username'; end if;
 return exists(select 1 from app.profiles p where p.username=lower(p_username));
end $$;
-- This read function is privileged but public wrapper must remain INVOKER: move implementation private.
alter function public.check_username(text) set schema private;
create function public.check_username(p_username text) returns boolean language sql stable security invoker set search_path='' as $$ select private.check_username(p_username) $$;


-- Existing A1 helpers are already owned by fact_runtime; do not silently attempt to revoke as postgres.
 do $$ declare r record; begin
  for r in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.prokind='f' and p.proowner='postgres'::regrole loop
   execute format('revoke execute on function %s from public,anon,authenticated,service_role',r.signature);
  end loop;
 end $$;
-- Triggers execute their bound functions; their functions are not RPCs.
grant execute on function private.save_submission(uuid,bigint,bigint,jsonb,bigint,uuid),private.transition_submission(uuid,text,text,bigint,uuid),
 private.publish_fact(bigint,bigint,text,uuid),private.publish_puzzle(uuid,uuid,bigint,text,uuid),
 private.set_username(text,bigint,uuid),private.set_rankings_visibility(boolean,bigint,uuid),private.check_username(text) to authenticated;
revoke execute on function public.get_fact_text(bigint,text),public.save_submission(uuid,bigint,bigint,jsonb,bigint,uuid),public.transition_submission(uuid,text,text,bigint,uuid),
 public.publish_fact(bigint,bigint,text,uuid),public.publish_puzzle(uuid,uuid,bigint,text,uuid),public.set_username(text,bigint,uuid),public.set_rankings_visibility(boolean,bigint,uuid),public.check_username(text) from public,anon,authenticated,service_role;
grant execute on function public.get_fact_text(bigint,text),public.check_username(text),private.check_username(text) to anon,authenticated;
grant execute on function public.save_submission(uuid,bigint,bigint,jsonb,bigint,uuid),public.transition_submission(uuid,text,text,bigint,uuid),
 public.publish_fact(bigint,bigint,text,uuid),public.publish_puzzle(uuid,uuid,bigint,text,uuid),public.set_username(text,bigint,uuid),public.set_rankings_visibility(boolean,bigint,uuid),public.check_username(text) to authenticated;
-- Transfer ownership only after explicit ACLs are complete (postgres has NOINHERIT membership).
grant create on schema private to fact_runtime;
do $$ declare r record; begin
 for r in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.prokind='f' and p.proowner='postgres'::regrole and p.proname<>'append_only' loop
  execute format('alter function %s owner to fact_runtime',r.signature);
 end loop;
end $$;
revoke create on schema private from fact_runtime;
;
