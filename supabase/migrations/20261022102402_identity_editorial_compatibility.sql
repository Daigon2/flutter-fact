-- Initial username assignment remains compatible with the existing Flutter view UPDATE.
-- Only the username column is granted; the trigger derives timestamps/version and rejects renames.
create function private.guard_initial_username() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.username is not null then raise exception using errcode='55000',message='username already assigned; rename disabled'; end if;
 if new.username is null or lower(new.username) !~ '^[a-z0-9_]{3,24}$' then raise exception using errcode='22023',message='username requires 3-24 ASCII letters, digits or underscore'; end if;
 new.username:=lower(new.username);
 new.username_set_at:=clock_timestamp(); new.username_changed_at:=null;
 new.updated_at:=clock_timestamp(); new.version:=old.version+1;
 return new;
end $$;
create trigger initial_username_guard before update of username on app.profiles for each row execute function private.guard_initial_username();
create policy own_initial_username on app.profiles for update to authenticated
 using(id=(select auth.uid()) and username is null and (select private.is_registered()))
 with check(id=(select auth.uid()) and username is not null and (select private.is_registered()));
grant update(username) on app.profiles,public.profiles to authenticated;

-- Payload v1 is deliberately typed and whitelist-only. Only NEW facts are approved here.
-- No media/puzzles/edits or arbitrary status/author/quality fields can be smuggled in via JSON.
create function private.approve_new_fact_submission(p_id uuid,p_expected_version bigint,p_quality_score smallint,p_reason text,p_operation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 args jsonb; cached jsonb; s app.fact_submissions; payload jsonb; tr jsonb; src jsonb;
 f app.facts; snapshot jsonb; lat double precision; lng double precision;
 city uuid; category text; genre text; zone uuid;
begin
 if not private.has_role(array['editor','admin']) then raise exception using errcode='42501',message='editor role required'; end if;
 args:=jsonb_build_object('id',p_id,'expected_version',p_expected_version,'quality_score',p_quality_score,'reason',p_reason);
 cached:=private.command_begin(p_operation,'approve_new_fact_submission',args); if cached is not null then return cached; end if;
 if p_reason is null or btrim(p_reason)='' or length(p_reason)>4000 then raise exception using errcode='22023',message='review reason required'; end if;
 if p_quality_score is null or p_quality_score not between 1 and 3 then raise exception using errcode='22023',message='editor quality score 1-3 required'; end if;
 select * into s from app.fact_submissions where id=p_id for update;
 if not found or s.state<>'submitted' or s.version is distinct from p_expected_version then raise exception using errcode='40001',message='submission state/version conflict'; end if;
 if s.target_fact_id is not null then raise exception using errcode='0A000',message='published fact revision application not activated'; end if;
 payload:=s.draft_payload;
 if s.payload_version<>1 or exists(select 1 from jsonb_object_keys(payload) k where k<>all(array['city_id','category_id','genre_id','zone_id','latitude','longitude','texts','sources'])) then
 raise exception using errcode='22023',message='unsupported submission payload fields'; end if;
 if jsonb_typeof(payload->'city_id') is distinct from 'string' or jsonb_typeof(payload->'category_id') is distinct from 'string' or
 jsonb_typeof(payload->'latitude') is distinct from 'number' or jsonb_typeof(payload->'longitude') is distinct from 'number' or
 jsonb_typeof(payload->'texts') is distinct from 'array' or jsonb_typeof(payload->'sources') is distinct from 'array' or
 jsonb_array_length(payload->'texts') not between 1 and 50 or jsonb_array_length(payload->'sources') not between 1 and 50 or
 (payload ? 'genre_id' and jsonb_typeof(payload->'genre_id') not in ('string','null')) or
 (payload ? 'zone_id' and jsonb_typeof(payload->'zone_id') not in ('string','null')) then
 raise exception using errcode='22023',message='invalid typed submission fields'; end if;
 begin
 city:=(payload->>'city_id')::uuid; category:=payload->>'category_id'; genre:=payload->>'genre_id'; zone:=(payload->>'zone_id')::uuid;
 lat:=(payload->>'latitude')::double precision; lng:=(payload->>'longitude')::double precision;
 exception when invalid_text_representation or numeric_value_out_of_range then raise exception using errcode='22023',message='invalid submission identifier or coordinates'; end;
 if lat::text in ('NaN','Infinity','-Infinity') or lng::text in ('NaN','Infinity','-Infinity') or lat not between -90 and 90 or lng not between -180 and 180 then
 raise exception using errcode='22023',message='submission coordinates out of range'; end if;
 insert into app.facts(city_id,category_id,genre_id,zone_id,location,quality_score,origin,author_id,default_language)
 values(city,category,genre,zone,extensions.st_setsrid(extensions.st_makepoint(lng,lat),4326)::extensions.geography,p_quality_score,'community',s.author_id,'de') returning * into f;
 for tr in select value from jsonb_array_elements(payload->'texts') loop
  if jsonb_typeof(tr) is distinct from 'object' or exists(select 1 from jsonb_object_keys(tr) k where k<>all(array['language_code','title','body','body_extra','body_background','body_today','place','caption','source_display'])) then
   raise exception using errcode='22023',message='unsupported text fields'; end if;
  if jsonb_typeof(tr->'language_code') is distinct from 'string' or jsonb_typeof(tr->'title') is distinct from 'string' or jsonb_typeof(tr->'body') is distinct from 'string' or
   exists(select 1 from jsonb_each(tr) field where field.key<>'language_code' and jsonb_typeof(field.value) not in ('string','null')) then
   raise exception using errcode='22023',message='invalid typed text fields'; end if;
  insert into app.fact_texts(fact_id,language_code,title,body,body_extra,body_background,body_today,place,caption,source_display,translation_status)
  values(f.id,tr->>'language_code',tr->>'title',tr->>'body',tr->>'body_extra',tr->>'body_background',tr->>'body_today',tr->>'place',tr->>'caption',tr->>'source_display','approved');
 end loop;
 for src in select value from jsonb_array_elements(payload->'sources') loop
  if jsonb_typeof(src) is distinct from 'object' or exists(select 1 from jsonb_object_keys(src) k where k<>all(array['position','citation','url','accessed_on','language_code'])) then
   raise exception using errcode='22023',message='unsupported source fields'; end if;
  if jsonb_typeof(src->'position') is distinct from 'number' or jsonb_typeof(src->'citation') is distinct from 'string' or
   exists(select 1 from jsonb_each(src) field where field.key<>'position' and jsonb_typeof(field.value) not in ('string','null')) then
   raise exception using errcode='22023',message='invalid typed source fields'; end if;
  begin
   insert into app.fact_sources(fact_id,position,citation,url,accessed_on,language_code)
   values(f.id,(src->>'position')::integer,src->>'citation',src->>'url',(src->>'accessed_on')::date,src->>'language_code');
  exception when invalid_text_representation or numeric_value_out_of_range or invalid_datetime_format or datetime_field_overflow then
   raise exception using errcode='22023',message='invalid typed source value'; end;
 end loop;
 perform private.validate_fact(f.id);
 snapshot:=jsonb_build_object('fact',to_jsonb(f),'texts',(select coalesce(jsonb_agg(to_jsonb(t) order by t.language_code),'[]') from app.fact_texts t where t.fact_id=f.id),
 'sources',(select coalesce(jsonb_agg(to_jsonb(srcrow) order by srcrow.position),'[]') from app.fact_sources srcrow where srcrow.fact_id=f.id),'media','[]'::jsonb);
 insert into private.fact_revisions(fact_id,revision_no,submission_id,published_by,snapshot) values(f.id,1,s.id,private.request_actor(),snapshot);
 update app.facts set status='published',published_revision=1,published_at=clock_timestamp(),version=version+1,updated_at=clock_timestamp() where id=f.id returning * into f;
 update app.fact_submissions set state='approved',reviewer_id=private.request_actor(),review_note=p_reason,reviewed_at=clock_timestamp(),version=version+1,updated_at=clock_timestamp() where id=s.id returning * into s;
 insert into private.audit_log(actor_id,action,entity_type,entity_id,reason,operation_id,changes)
 values(private.request_actor(),'approve','submission',s.id::text,p_reason,p_operation,jsonb_build_object('fact_id',f.id,'revision',1,'submission_version',s.version));
 return private.command_finish(p_operation,'approve_new_fact_submission',args,s.version,jsonb_build_object('submission_id',s.id,'state',s.state,'fact_id',f.id,'fact_version',f.version,'revision',1));
end $$;
create function public.approve_new_fact_submission(p_id uuid,p_expected_version bigint,p_quality_score smallint,p_reason text,p_operation uuid) returns jsonb language sql security invoker set search_path='' as $$
 select private.approve_new_fact_submission(p_id,p_expected_version,p_quality_score,p_reason,p_operation)
$$;
-- Approving through the dedicated endpoint makes the editor's quality decision explicit.
-- Existing transition_submission submit/withdraw/reject contracts remain unchanged.
grant select on app.genres,app.city_zones to fact_runtime;
create policy runtime_read_genres on app.genres for select to fact_runtime using(true);
create policy runtime_read_zones on app.city_zones for select to fact_runtime using(true);
grant insert on app.facts,app.fact_texts,app.fact_sources to fact_runtime;
grant usage on sequence app.facts_id_seq to fact_runtime;

revoke execute on function private.guard_initial_username(),private.approve_new_fact_submission(uuid,bigint,smallint,text,uuid),public.approve_new_fact_submission(uuid,bigint,smallint,text,uuid) from public,anon,authenticated,service_role;
grant execute on function private.approve_new_fact_submission(uuid,bigint,smallint,text,uuid),public.approve_new_fact_submission(uuid,bigint,smallint,text,uuid) to authenticated;
-- Transfer ownership only after explicit ACLs are complete (postgres has NOINHERIT membership).
grant create on schema private to fact_runtime;
alter function private.guard_initial_username() owner to fact_runtime;
alter function private.approve_new_fact_submission(uuid,bigint,smallint,text,uuid) owner to fact_runtime;
revoke create on schema private from fact_runtime;
;
