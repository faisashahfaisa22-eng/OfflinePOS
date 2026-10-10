-- Fix claim_device: FOUND was overwritten by SELECT count(*), allowing extra seats.
-- Lock license row to serialize concurrent activations.
create or replace function licensing_private.claim_device(p_code_hash text,p_device_hash text)
returns table(license_id uuid,expires_at timestamptz,device_id uuid,outcome text)
language plpgsql security definer set search_path=''
as $$
declare l public.licenses%rowtype; d public.license_devices%rowtype; n integer;
begin
 select * into l from public.licenses where code_hash=p_code_hash for update;
 if l.id is null then
  insert into public.license_attempts(device_hash,outcome) values(p_device_hash,'invalid_code');
  return;
 end if;
 if l.status <> 'active' or (l.expires_at is not null and l.expires_at <= now()) then
  insert into public.license_attempts(license_id,device_hash,outcome) values(l.id,p_device_hash,'blocked_or_expired');
  return;
 end if;
 select * into d from public.license_devices ld where ld.license_id=l.id and ld.device_hash=p_device_hash for update;
 if d.id is not null and d.revoked_at is not null then
  insert into public.license_attempts(license_id,device_hash,outcome) values(l.id,p_device_hash,'device_revoked');
  return;
 end if;
 if d.id is null then
  select count(*) into n from public.license_devices ld where ld.license_id=l.id and ld.revoked_at is null;
  if n >= l.max_devices then
   insert into public.license_attempts(license_id,device_hash,outcome) values(l.id,p_device_hash,'device_limit');
   return;
  end if;
  insert into public.license_devices(license_id,device_hash,last_seen_at)
  values(l.id,p_device_hash,now()) returning * into d;
 else
  update public.license_devices set last_seen_at=now() where id=d.id;
 end if;
 insert into public.license_attempts(license_id,device_hash,outcome) values(l.id,p_device_hash,'accepted');
 license_id:=l.id; expires_at:=l.expires_at; device_id:=d.id; outcome:='accepted';
 return next;
end $$;
revoke all on function licensing_private.claim_device(text,text) from public,anon,authenticated;
grant execute on function licensing_private.claim_device(text,text) to service_role;
