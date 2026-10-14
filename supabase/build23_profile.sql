-- Splits8 · 빌드 23 가입 프로필 + 한 기기만 로그인
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 괜찮음.
-- (빌드 23 앱보다 먼저 올려도 됨. 이 SQL 이 없으면 빌드 23 앱은 프로필을 이 기기에만 저장하고, 기기 확인은 건너뜀)
--
-- 바뀌는 것
--  1) 새 표 profile_private: 성별 · 키 · 몸무게 · 태어난 해 · 대회 경험 · 대회 디비전 + 지금 로그인한 기기
--     → 본인만 읽고 쓸 수 있음 (친구 · 다른 사람에게 안 보임)
--     ※ profiles 표에 칸을 더하지 않은 이유: profiles 는 "나만 보기"가 아니면 로그인한 누구나 모든 칸을 읽을 수 있음
--       (schema.sql 의 profiles_read 규칙). 그래서 본인만 보는 값은 따로 표를 만듦. 닉네임 · 디비전 · 사진은 그대로 profiles 에.
--  2) 함수 claim_device(dev): 새로 로그인한 기기를 "지금 기기"로 적음 → 예전 기기는 다음 확인 때 스스로 로그아웃
--  3) 함수 active_device(): 서버에 적힌 "지금 기기" id 를 돌려줌 (본인 것만)
--  계정을 지우면(delete_account → auth.users 삭제) 이 표의 줄도 같이 지워짐 (on delete cascade)

-- 1) 본인만 보는 프로필 표
create table if not exists public.profile_private (
  id uuid primary key references auth.users(id) on delete cascade,
  sex text check (sex in ('M', 'W')),
  height_cm int check (height_cm between 100 and 250),
  weight_kg numeric(5, 1) check (weight_kg between 20 and 300),
  birth_year int check (birth_year between 1900 and 2100),
  raced boolean,
  race_division text check (race_division in ('openM', 'openW', 'proM', 'proW', 'dblM', 'dblMP',
                                              'dblW', 'dblWP', 'dblX', 'relay')),
  active_device text,
  active_device_at timestamptz,
  updated_at timestamptz not null default now()
);

-- (혹시 표가 예전 모양으로 먼저 만들어져 있어도 칸이 다 있게)
alter table public.profile_private add column if not exists sex text;
alter table public.profile_private add column if not exists height_cm int;
alter table public.profile_private add column if not exists weight_kg numeric(5, 1);
alter table public.profile_private add column if not exists birth_year int;
alter table public.profile_private add column if not exists raced boolean;
alter table public.profile_private add column if not exists race_division text;
alter table public.profile_private add column if not exists active_device text;
alter table public.profile_private add column if not exists active_device_at timestamptz;
alter table public.profile_private add column if not exists updated_at timestamptz not null default now();

-- 고칠 때마다 updated_at 을 지금 시각으로
create or replace function public.profile_private_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists profile_private_touch on public.profile_private;
create trigger profile_private_touch before update on public.profile_private
  for each row execute function public.profile_private_touch();

-- 규칙: 본인 줄만 읽기 · 넣기 · 고치기 · 지우기 (다른 사람은 어떤 칸도 못 읽음)
alter table public.profile_private enable row level security;
drop policy if exists profile_private_read on public.profile_private;
create policy profile_private_read on public.profile_private for select using (id = auth.uid());
drop policy if exists profile_private_insert on public.profile_private;
create policy profile_private_insert on public.profile_private for insert with check (id = auth.uid());
drop policy if exists profile_private_update on public.profile_private;
create policy profile_private_update on public.profile_private for update using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists profile_private_delete on public.profile_private;
create policy profile_private_delete on public.profile_private for delete using (id = auth.uid());

-- 로그인 안 한 사람(anon)은 이 표에 아예 접근 못 하게
revoke all on table public.profile_private from anon;
grant select, insert, update, delete on table public.profile_private to authenticated;

-- 2) 새로 로그인한 기기를 "지금 기기"로 적음 (본인 줄만, 없으면 만듦)
create or replace function public.claim_device(dev text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or dev is null or length(dev) not between 8 and 64 then return; end if;
  insert into public.profile_private (id, active_device, active_device_at)
    values (auth.uid(), dev, now())
  on conflict (id) do update
    set active_device = excluded.active_device, active_device_at = excluded.active_device_at;
end $$;
revoke all on function public.claim_device(text) from public;
revoke all on function public.claim_device(text) from anon;
grant execute on function public.claim_device(text) to authenticated;

-- 3) 서버에 적힌 "지금 기기" id (없으면 null)
create or replace function public.active_device() returns text
language sql stable security definer set search_path = public as $$
  select active_device from public.profile_private where id = auth.uid();
$$;
revoke all on function public.active_device() from public;
revoke all on function public.active_device() from anon;
grant execute on function public.active_device() to authenticated;

-- 참고: profiles 표 · 규칙은 바꾸지 않음 (친구가 보는 닉네임 · 디비전 · 사진 · 공개 범위는 그대로).
