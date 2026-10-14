-- Splits8 · 빌드 24 (1.1.0) 친구 응원 + 친구 10명 제한
-- 1.1.0 출시할 때 Supabase 대시보드 → SQL Editor 에 통째로 붙여 넣고 Run. (build22_friends.sql · build23_profile.sql 다음에)
--
-- 바뀌는 것
--  1) 새 표 cheers: 친구에게 보낸 응원 (정해진 것만 — 자유 글 없음)
--  2) send_cheer(other, kind): 수락된 친구에게만 · 하루 30번까지 · 같은 친구에게 1분에 1번
--  3) my_cheers(): 받은 응원 최근 50개 (보낸 사람 닉네임 · 사진 포함)
--  4) mark_cheers_seen(): 받은 응원을 읽음으로
--  5) add_friend: 친구(수락 + 보낸 요청)가 이미 10명이면 더 못 보냄 / respond_friend: 10명이면 수락 못 함

-- 1) 응원 표
create table if not exists public.cheers (
  id bigint generated always as identity primary key,
  sender uuid not null references auth.users(id) on delete cascade,
  receiver uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('fire', 'clap', 'muscle', 'pb', 'race', 'together', 'go')),
  created_at timestamptz not null default now(),
  seen boolean not null default false
);
create index if not exists cheers_receiver_idx on public.cheers (receiver, created_at desc);
create index if not exists cheers_sender_idx on public.cheers (sender, created_at desc);

alter table public.cheers enable row level security;
-- 읽기: 받은 사람 · 보낸 사람만
drop policy if exists cheers_select on public.cheers;
create policy cheers_select on public.cheers for select using (receiver = auth.uid() or sender = auth.uid());
-- 지우기: 받은 사람만 (목록에서 지우기)
drop policy if exists cheers_delete on public.cheers;
create policy cheers_delete on public.cheers for delete using (receiver = auth.uid());
-- 넣기 · 고치기: 규칙 없음 = 앱에서 직접 못 함 (아래 함수로만)

-- 2) 응원 보내기
create or replace function public.send_cheer(other uuid, kind text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or other = auth.uid() then raise exception 'not allowed'; end if;
  if kind not in ('fire', 'clap', 'muscle', 'pb', 'race', 'together', 'go') then raise exception 'bad kind'; end if;
  -- 수락된 친구에게만
  if not exists (select 1 from public.friendships
                 where status = 'accepted'
                   and ((requester = auth.uid() and addressee = other) or (requester = other and addressee = auth.uid()))) then
    raise exception 'not friends';
  end if;
  -- 하루 30번까지
  if (select count(*) from public.cheers where sender = auth.uid() and created_at > now() - interval '1 day') >= 30 then
    raise exception 'daily limit';
  end if;
  -- 같은 친구에게 1분에 1번
  if exists (select 1 from public.cheers where sender = auth.uid() and receiver = other and created_at > now() - interval '1 minute') then
    raise exception 'too fast';
  end if;
  insert into public.cheers (sender, receiver, kind) values (auth.uid(), other, kind);
end $$;
revoke all on function public.send_cheer(uuid, text) from public;
revoke all on function public.send_cheer(uuid, text) from anon;
grant execute on function public.send_cheer(uuid, text) to authenticated;

-- 3) 받은 응원 (최근 50개, 아직 친구인 사람 것만)
create or replace function public.my_cheers()
returns table (id bigint, sender uuid, nickname text, avatar_url text, kind text, created_at timestamptz, seen boolean)
language sql stable security definer set search_path = public as $$
  select c.id, c.sender, p.nickname, p.avatar_url, c.kind, c.created_at, c.seen
  from public.cheers c
  join public.profiles p on p.id = c.sender
  where c.receiver = auth.uid() and p.nickname is not null
    and exists (select 1 from public.friendships f
                where f.status = 'accepted'
                  and ((f.requester = c.sender and f.addressee = c.receiver) or (f.requester = c.receiver and f.addressee = c.sender)))
  order by c.created_at desc
  limit 50;
$$;
revoke all on function public.my_cheers() from public;
revoke all on function public.my_cheers() from anon;
grant execute on function public.my_cheers() to authenticated;

-- 4) 받은 응원 읽음
create or replace function public.mark_cheers_seen() returns void
language sql security definer set search_path = public as $$
  update public.cheers set seen = true where receiver = auth.uid() and not seen;
$$;
revoke all on function public.mark_cheers_seen() from public;
revoke all on function public.mark_cheers_seen() from anon;
grant execute on function public.mark_cheers_seen() to authenticated;

-- 5) 친구 10명 제한 (수락된 친구 + 내가 보낸 요청). 이미 10명 넘은 사람은 지우지 않고 추가만 막음
create or replace function public.friend_count(u uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(distinct case when requester = u then addressee else requester end)::int
  from public.friendships
  where (requester = u or addressee = u)
    and (status = 'accepted' or requester = u);
$$;
revoke all on function public.friend_count(uuid) from public;
revoke all on function public.friend_count(uuid) from anon;

-- 요청 줄을 넣을 때 확인 (add_friend 함수 · 직접 넣기 둘 다 여기를 지남)
create or replace function public.friend_limit_check() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- 상대가 이미 나에게 요청한 경우(= 수락)는 내 쪽 숫자가 늘지 않으므로 그대로 둠
  if exists (select 1 from public.friendships where requester = new.addressee and addressee = new.requester) then
    return new;
  end if;
  if public.friend_count(new.requester) >= 10 then
    raise exception 'friend limit';
  end if;
  return new;
end $$;
drop trigger if exists friend_limit on public.friendships;
create trigger friend_limit before insert on public.friendships
  for each row execute function public.friend_limit_check();
