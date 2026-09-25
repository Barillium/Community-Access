-- Local core only. Invitations, application fields and collective onboarding remain closed.
begin;
create schema if not exists access_private;
revoke all on schema access_private from public;
grant usage on schema access_private to authenticated;
create table public.communities(id uuid primary key default gen_random_uuid(), name text not null);
create table public.community_hosts(community_id uuid references public.communities not null, user_id uuid references auth.users not null, primary key(community_id,user_id));
create table public.applications(id uuid primary key default gen_random_uuid(), community_id uuid references public.communities not null, user_id uuid references auth.users not null, status text not null default 'pending' check(status in ('pending','approved','rejected','withdrawn')), decided_at timestamptz, unique(community_id,user_id));
create table public.memberships(community_id uuid references public.communities not null, user_id uuid references auth.users not null, active boolean not null default true, primary key(community_id,user_id));
create table public.events(id uuid primary key default gen_random_uuid(), community_id uuid references public.communities not null, title text not null, capacity integer not null check(capacity>0), minimum_age integer not null check(minimum_age>=0));
create table public.event_locations(event_id uuid primary key references public.events, location text not null);
create table public.event_requests(event_id uuid references public.events not null, user_id uuid references auth.users not null, status text not null default 'pending' check(status in ('pending','confirmed','rejected')), age_confirmed boolean not null check(age_confirmed), primary key(event_id,user_id));

create function access_private.is_host(c uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.community_hosts where community_id=c and user_id=auth.uid()); $$;
create function access_private.is_member(c uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.memberships where community_id=c and user_id=auth.uid() and active); $$;
create function access_private.can_view_location(e uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.events v where v.id=e and (access_private.is_host(v.community_id) or (access_private.is_member(v.community_id) and exists(select 1 from public.event_requests r where r.event_id=e and r.user_id=auth.uid() and r.status='confirmed')))); $$;
revoke all on all functions in schema access_private from public;
grant execute on all functions in schema access_private to authenticated;

alter table public.communities enable row level security;
alter table public.community_hosts enable row level security;
alter table public.applications enable row level security;
alter table public.memberships enable row level security;
alter table public.events enable row level security;
alter table public.event_locations enable row level security;
alter table public.event_requests enable row level security;
revoke all on public.communities,public.community_hosts,public.applications,public.memberships,public.events,public.event_locations,public.event_requests from anon,authenticated;
grant select on public.communities,public.community_hosts,public.applications,public.memberships,public.events,public.event_locations,public.event_requests to authenticated;
create policy communities_read on public.communities for select to authenticated using(access_private.is_host(id) or access_private.is_member(id));
create policy hosts_read on public.community_hosts for select to authenticated using(user_id=auth.uid());
create policy applications_read on public.applications for select to authenticated using(user_id=auth.uid() or access_private.is_host(community_id));
create policy memberships_read on public.memberships for select to authenticated using(user_id=auth.uid() or access_private.is_host(community_id));
create policy events_read on public.events for select to authenticated using(access_private.is_host(community_id) or access_private.is_member(community_id));
create policy locations_read on public.event_locations for select to authenticated using(access_private.can_view_location(event_id));
create policy requests_read on public.event_requests for select to authenticated using(user_id=auth.uid() or exists(select 1 from public.events e where e.id=event_id and access_private.is_host(e.community_id)));

create function public.decide_application(application_id uuid, approve boolean) returns void language plpgsql security definer set search_path='' as $$
declare a public.applications;
begin
 select * into a from public.applications where id=application_id for update;
 if not found or not access_private.is_host(a.community_id) then raise exception 'not permitted' using errcode='42501'; end if;
 if a.status=(case when approve then 'approved' else 'rejected' end) then return; end if;
 if a.status<>'pending' then raise exception 'invalid state'; end if;
 update public.applications set status=case when approve then 'approved' else 'rejected' end, decided_at=now() where id=a.id;
 if approve then insert into public.memberships values(a.community_id,a.user_id,true) on conflict(community_id,user_id) do update set active=true; end if;
end $$;
create function public.request_event(event_id uuid, age_confirmed boolean) returns void language plpgsql security definer set search_path='' as $$
declare e public.events;
begin
 select * into e from public.events where id=event_id;
 if not found then raise exception 'not permitted' using errcode='42501'; end if;
 perform 1 from public.memberships where community_id=e.community_id and user_id=auth.uid() and active for update;
 if not found then raise exception 'not permitted' using errcode='42501'; end if;
 if age_confirmed is distinct from true then raise exception 'age confirmation required'; end if;
 insert into public.event_requests values(e.id,auth.uid(),'pending',true) on conflict do nothing;
end $$;
create function public.confirm_event(target_event uuid, target_user uuid) returns void language plpgsql security definer set search_path='' as $$
declare e public.events;
begin
 select * into e from public.events where id=target_event for update;
 if not found or not access_private.is_host(e.community_id) then raise exception 'not permitted' using errcode='42501'; end if;
 perform 1 from public.memberships where community_id=e.community_id and user_id=target_user and active for update;
 if not found then raise exception 'inactive member'; end if;
 if exists(select 1 from public.event_requests where event_id=target_event and user_id=target_user and status='confirmed') then return; end if;
 if (select count(*) from public.event_requests where event_id=target_event and status='confirmed')>=e.capacity then raise exception 'event full'; end if;
 update public.event_requests set status='confirmed' where event_id=target_event and user_id=target_user and status='pending';
 if not found then raise exception 'pending request required'; end if;
end $$;
-- No product revoke endpoint until its effects on pending/confirmed requests are specified.
revoke all on function public.decide_application(uuid,boolean),public.request_event(uuid,boolean),public.confirm_event(uuid,uuid) from public,anon;
grant execute on function public.decide_application(uuid,boolean),public.request_event(uuid,boolean),public.confirm_event(uuid,uuid) to authenticated;
commit;
