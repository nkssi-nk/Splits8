-- Splits8 · Supabase 스키마 (README "Backend" 기준)
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여 넣고 Run.
-- 계정·친구·순위표·대회 목록에만 쓰입니다. 심박 원본은 절대 올리지 않습니다.

create extension if not exists pgcrypto;

-- 프로필
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text unique check (nickname ~ '^[a-z0-9_]{3,16}$'),
  division text,
  avatar_url text,
  visibility text not null default 'friends' check (visibility in ('friends','public','private')),
  created_at timestamptz not null default now()
);

-- 친구 (requester → addressee)
create table if not exists public.friendships (
  requester uuid not null references public.profiles(id) on delete cascade,
  addressee uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  primary key (requester, addressee)
);

-- 기록 요약 (총 시간 · 16구간 · Roxzone 합계)
create table if not exists public.records (
  id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  mode text not null check (mode in ('training','sim','race')),
  date date not null,
  total_s int not null,
  splits int[],
  rox_s int,
  event_id uuid,
  division text,
  created_at timestamptz not null default now()
);
create index if not exists records_user_mode on public.records(user_id, mode);

-- 대회 목록 (공개 읽기 · 수동 갱신)
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  city text not null,
  venue text not null,
  region text not null check (region in ('korea','asia','europe','americas')),
  start_date date not null,
  end_date date not null
);

-- 아바타 저장소 (공개 읽기 · 본인만 쓰기)
insert into storage.buckets (id, name, public) values ('avatars','avatars', true) on conflict (id) do nothing;

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.records enable row level security;
alter table public.events enable row level security;

-- 두 사람이 친구인지 (accepted)
create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted' and ((f.requester = a and f.addressee = b) or (f.requester = b and f.addressee = a))
  );
$$;

-- profiles: 본인 전부 / 남은 private 아니면 읽기
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select using (id = auth.uid() or visibility <> 'private');
drop policy if exists profiles_write on public.profiles;
create policy profiles_write on public.profiles for insert with check (id = auth.uid());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update using (id = auth.uid());

-- friendships: 관련된 사람만
drop policy if exists friendships_read on public.friendships;
create policy friendships_read on public.friendships for select using (requester = auth.uid() or addressee = auth.uid());
drop policy if exists friendships_insert on public.friendships;
create policy friendships_insert on public.friendships for insert with check (requester = auth.uid());
drop policy if exists friendships_update on public.friendships;
create policy friendships_update on public.friendships for update using (addressee = auth.uid() or requester = auth.uid());
drop policy if exists friendships_delete on public.friendships;
create policy friendships_delete on public.friendships for delete using (requester = auth.uid() or addressee = auth.uid());

-- records: 본인 / 공개 / 친구(friends 설정)
drop policy if exists records_read on public.records;
create policy records_read on public.records for select using (
  user_id = auth.uid()
  or exists (select 1 from public.profiles p where p.id = records.user_id and p.visibility = 'public')
  or (public.are_friends(auth.uid(), user_id)
      and exists (select 1 from public.profiles p where p.id = records.user_id and p.visibility = 'friends'))
);
drop policy if exists records_write on public.records;
create policy records_write on public.records for insert with check (user_id = auth.uid());
drop policy if exists records_update on public.records;
create policy records_update on public.records for update using (user_id = auth.uid());
drop policy if exists records_delete on public.records;
create policy records_delete on public.records for delete using (user_id = auth.uid());

-- events: 누구나 읽기
drop policy if exists events_read on public.events;
create policy events_read on public.events for select using (true);

-- storage: avatars 공개 읽기, 본인 파일만 쓰기
drop policy if exists avatars_read on storage.objects;
create policy avatars_read on storage.objects for select using (bucket_id = 'avatars');
drop policy if exists avatars_write on storage.objects;
create policy avatars_write on storage.objects for insert with check (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg');
drop policy if exists avatars_update on storage.objects;
create policy avatars_update on storage.objects for update using (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg');

-- 닉네임 사용 가능?
create or replace function public.nickname_available(n text) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (select 1 from public.profiles where nickname = lower(n) and id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid));
$$;

-- 친구 찾기 (빌드 20): 이메일 전체 또는 닉네임 전체가 정확히 맞는 한 사람만 돌려줌.
-- 앞 글자만으로 찾는 기능은 없음 (모르는 사람을 훑어볼 수 없게). 로그인한 사람만 쓸 수 있고, 이메일 자체는 돌려주지 않음.
-- 기록을 "나만 보기"로 둔 사람은 찾아지지 않음 (프로필 읽기 규칙과 같음).
-- Apple 로 가입하면서 이메일을 가린 사람은 가입 이메일이 가려진 주소라서 닉네임으로만 찾아짐.
create or replace function public.find_user(q text)
returns table (id uuid, nickname text, division text, avatar_url text)
language sql stable security definer set search_path = public as $$
  select p.id, p.nickname, coalesce(p.division, ''), p.avatar_url
  from public.profiles p
  left join auth.users u on u.id = p.id
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.nickname is not null
    and p.visibility <> 'private'
    and length(btrim(q)) between 3 and 254
    and (p.nickname = lower(btrim(q)) or lower(u.email) = lower(btrim(q)))
  order by (p.nickname = lower(btrim(q))) desc
  limit 1;
$$;
revoke all on function public.find_user(text) from public;
revoke all on function public.find_user(text) from anon;
grant execute on function public.find_user(text) to authenticated;

-- 친구 추가: 상대가 이미 나를 추가했으면 바로 accepted, 아니면 pending
create or replace function public.add_friend(other uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if other = auth.uid() then return; end if;
  if exists (select 1 from public.friendships where requester = other and addressee = auth.uid()) then
    update public.friendships set status = 'accepted' where requester = other and addressee = auth.uid();
    insert into public.friendships (requester, addressee, status) values (auth.uid(), other, 'accepted')
      on conflict (requester, addressee) do update set status = 'accepted';
  else
    insert into public.friendships (requester, addressee, status) values (auth.uid(), other, 'pending')
      on conflict do nothing;
  end if;
end $$;

-- 내 친구 목록 + 각자의 최고 Full Simulation
create or replace function public.friends_with_best()
returns table (user_id uuid, nickname text, division text, avatar_url text, best_date text, splits int[], status text)
language sql stable security definer set search_path = public as $$
  with f as (
    select case when requester = auth.uid() then addressee else requester end as uid, status
    from public.friendships where requester = auth.uid() or addressee = auth.uid()
  ),
  best as (
    select distinct on (r.user_id) r.user_id, r.date, r.splits
    from public.records r join f on f.uid = r.user_id
    where r.mode = 'sim' and r.splits is not null and array_length(r.splits, 1) = 16
    order by r.user_id, r.total_s asc
  )
  select p.id, p.nickname, coalesce(p.division, ''), p.avatar_url,
         to_char(b.date, 'DD Mon YYYY'), b.splits, f.status
  from f join public.profiles p on p.id = f.uid
  left join best b on b.user_id = p.id
  where p.nickname is not null
  order by p.nickname;
$$;

-- 순위표: kind = 'sim' | 'race' | 'station', station = 0…7 (SkiErg … Wall Balls)
create or replace function public.leaderboard(kind text, station int, div text)
returns table (user_id uuid, nickname text, division text, avatar_url text, t int)
language sql stable security definer set search_path = public as $$
  with people as (
    select auth.uid() as uid
    union
    select case when requester = auth.uid() then addressee else requester end
    from public.friendships where status = 'accepted' and (requester = auth.uid() or addressee = auth.uid())
  ),
  vals as (
    select r.user_id,
      case when kind = 'station' then r.splits[station * 2 + 2] else r.total_s end as t
    from public.records r join people on people.uid = r.user_id
    where ((kind = 'race' and r.mode = 'race') or (kind <> 'race' and r.mode = 'sim'))
      and (kind <> 'station' or (r.splits is not null and array_length(r.splits, 1) = 16))
  )
  select p.id, p.nickname, coalesce(p.division, ''), p.avatar_url, min(v.t)::int
  from vals v join public.profiles p on p.id = v.user_id
  where v.t is not null and p.nickname is not null
    and (div is null or p.division = div or p.id = auth.uid())
    and (p.id = auth.uid() or p.visibility <> 'private')
  group by p.id, p.nickname, p.division, p.avatar_url
  order by min(v.t);
$$;

-- 계정 삭제 (앱 심사 요구 사항)
create or replace function public.delete_account() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from auth.users where id = auth.uid();
end $$;

-- 대회 목록 초기값 (hyrox.com Find My Race · 2026-09-29 확인)
insert into public.events (city, venue, region, start_date, end_date) values
('Seoul','KINTEX, Goyang','korea','2026-11-13','2026-11-15'),
('Incheon','Songdo Convensia','korea','2027-05-13','2027-05-16'),
('Shanghai','China','asia','2026-10-31','2026-11-01'),
('Guangzhou','China','asia','2026-11-21','2026-11-22'),
('Singapore','Singapore','asia','2026-11-26','2026-11-29'),
('Sanya','China','asia','2026-12-05','2026-12-06'),
('Melbourne','Australia','asia','2026-12-09','2026-12-13'),
('Kuala Lumpur','Malaysia','asia','2026-12-10','2026-12-13'),
('Hong Kong','Hong Kong','asia','2027-01-07','2027-01-10'),
('Osaka','Japan','asia','2027-01-21','2027-01-25'),
('Auckland','New Zealand','asia','2027-02-04','2027-02-07'),
('Bangkok','Thailand','asia','2027-02-11','2027-02-14'),
('Taipei','Chinese Taipei','asia','2027-03-12','2027-03-14'),
('Brisbane','Australia','asia','2027-03-31','2027-04-04'),
('Nagoya','Japan','asia','2027-04-16','2027-04-18'),
('World Championships','AsiaWorld-Expo, Hong Kong','asia','2027-06-10','2027-06-13'),
('Hamburg','Germany','europe','2026-10-28','2026-11-01'),
('Barcelona','Spain','europe','2026-11-11','2026-11-15'),
('London','ExCeL London','europe','2026-12-02','2026-12-06'),
('Stockholm','Sweden','europe','2026-12-10','2026-12-13'),
('Paris','France','europe','2026-12-12','2026-12-20'),
('Amsterdam','Netherlands','europe','2027-01-22','2027-01-31'),
('Dallas','USA','americas','2026-11-18','2026-11-22'),
('Anaheim','USA','americas','2026-12-03','2026-12-06'),
('Chicago','USA','americas','2027-02-11','2027-02-15');
