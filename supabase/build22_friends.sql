-- Splits8 · 빌드 22 (1.1.0) 친구 요청 수락 방식
-- 1.1.0 출시할 때 Supabase 대시보드 → SQL Editor 에 통째로 붙여 넣고 Run.
-- (먼저 올리면 지금 쓰는 빌드 21 에서도 "수락 전 요청"의 기록이 안 보이게 됨 — 그래도 깨지지는 않음)
--
-- 바뀌는 것
--  1) 친구 목록 함수 friends_with_best: 수락된 친구만 기록(splits)을 돌려줌 · 상대의 공개 범위를 지킴
--     · 같은 사람이 두 줄로 오지 않게 한 줄로 합침 · 요청 방향(incoming / outgoing / mutual)을 함께 돌려줌
--  2) 새 함수 respond_friend(other, accept): 받은 요청 수락 / 거절
--  3) 앱에서 직접 'accepted' 줄을 넣거나 상태를 바꿀 수 없게 막음 (수락은 함수로만)

-- 1) 친구 목록 + 최고 Full Simulation (수락된 친구만 기록)
drop function if exists public.friends_with_best();
create or replace function public.friends_with_best()
returns table (user_id uuid, nickname text, division text, avatar_url text, best_date text, splits int[],
               status text, direction text)
language sql stable security definer set search_path = public as $$
  with rows as (
    select case when requester = auth.uid() then addressee else requester end as uid,
           status,
           (requester = auth.uid()) as sent
    from public.friendships
    where auth.uid() is not null and (requester = auth.uid() or addressee = auth.uid())
  ),
  f as (
    select uid,
           case when bool_or(status = 'accepted') then 'accepted' else 'pending' end as status,
           case when bool_or(sent) and bool_or(not sent) then 'mutual'
                when bool_or(sent) then 'outgoing' else 'incoming' end as direction
    from rows group by uid
  ),
  best as (
    select distinct on (r.user_id) r.user_id, r.date, r.splits
    from public.records r
    join f on f.uid = r.user_id and f.status = 'accepted'
    join public.profiles p on p.id = r.user_id and p.visibility in ('friends', 'public')
    where r.mode = 'sim' and r.splits is not null and array_length(r.splits, 1) = 16
    order by r.user_id, r.total_s asc
  )
  select p.id, p.nickname, coalesce(p.division, ''), p.avatar_url,
         to_char(b.date, 'DD Mon YYYY'), b.splits, f.status, f.direction
  from f join public.profiles p on p.id = f.uid
  left join best b on b.user_id = p.id
  where p.nickname is not null
  order by (f.status = 'accepted') desc, p.nickname;
$$;
revoke all on function public.friends_with_best() from public;
revoke all on function public.friends_with_best() from anon;
grant execute on function public.friends_with_best() to authenticated;

-- 2) 받은 요청에 답하기: accept = true 면 친구, false 면 요청 지움
create or replace function public.respond_friend(other uuid, accept boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or other = auth.uid() then return; end if;
  if not exists (select 1 from public.friendships where requester = other and addressee = auth.uid()) then
    return;   -- 받은 요청이 없음
  end if;
  if accept then
    update public.friendships set status = 'accepted' where requester = other and addressee = auth.uid();
    update public.friendships set status = 'accepted' where requester = auth.uid() and addressee = other;
  else
    delete from public.friendships where requester = other and addressee = auth.uid();
    delete from public.friendships where requester = auth.uid() and addressee = other and status = 'pending';
  end if;
end $$;
revoke all on function public.respond_friend(uuid, boolean) from public;
revoke all on function public.respond_friend(uuid, boolean) from anon;
grant execute on function public.respond_friend(uuid, boolean) to authenticated;

-- 3) 규칙: 직접 넣는 줄은 'pending' 만 · 상태 바꾸기는 함수(add_friend / respond_friend)로만
drop policy if exists friendships_insert on public.friendships;
create policy friendships_insert on public.friendships for insert
  with check (requester = auth.uid() and status = 'pending');
drop policy if exists friendships_update on public.friendships;
-- (update 규칙 없음 = 앱에서 직접 수정 불가. 함수는 security definer 라 그대로 동작)

-- 참고: add_friend 는 그대로 둠 — 상대가 이미 나에게 요청했으면 내가 추가하는 순간 서로 친구(= 수락).
