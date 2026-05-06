-- E 点（商城 / 补给舱共用）与签到连续天数；每日签到发放 E 点
-- 规则：基础 15 E点/次；连续第 N 天（N≥2）额外 +(N-1)，最多 +7 → 单次最高 22 E点
-- （盲盒券 100 E点/张，约 5～7 天纯签到可换 1 张）

alter table public.profiles
  add column if not exists e_points integer not null default 0;

alter table public.profiles
  add column if not exists check_in_streak integer not null default 0;

create or replace function public.daily_check_in(check_day date)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total int;
  v_last date;
  v_streak int;
  v_ep int;
  v_new_streak int;
  v_reward int;
begin
  if auth.uid() is null then
    return json_build_object('ok', false);
  end if;
  if check_day is null then
    return json_build_object('ok', false);
  end if;

  select
    check_in_total,
    last_check_in_date,
    coalesce(check_in_streak, 0),
    coalesce(e_points, 0)
  into v_total, v_last, v_streak, v_ep
  from public.profiles
  where id = auth.uid();

  if not found then
    return json_build_object('ok', false, 'error', 'no_profile');
  end if;

  if v_last is not null and v_last = check_day then
    return json_build_object(
      'ok', true,
      'already_today', true,
      'total', coalesce(v_total, 0),
      'e_points', v_ep,
      'e_points_granted', 0,
      'check_in_streak', v_streak
    );
  end if;

  if v_last is null then
    v_new_streak := 1;
  elsif v_last = (check_day - 1) then
    v_new_streak := coalesce(v_streak, 0) + 1;
  else
    v_new_streak := 1;
  end if;

  v_reward := 15 + least(greatest(v_new_streak - 1, 0), 7);

  update public.profiles
  set
    check_in_total = coalesce(check_in_total, 0) + 1,
    last_check_in_date = check_day,
    check_in_streak = v_new_streak,
    e_points = coalesce(e_points, 0) + v_reward,
    updated_at = now()
  where id = auth.uid();

  select coalesce(e_points, 0) into v_ep
  from public.profiles
  where id = auth.uid();

  return json_build_object(
    'ok', true,
    'already_today', false,
    'total', coalesce(v_total, 0) + 1,
    'e_points_granted', v_reward,
    'e_points', v_ep,
    'check_in_streak', v_new_streak
  );
end;
$$;

grant execute on function public.daily_check_in(date) to authenticated;
