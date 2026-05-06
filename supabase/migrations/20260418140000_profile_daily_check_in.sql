-- 个人页「签到天数」：按本地日历日累计，同日仅计一次（由客户端传入日期）

alter table public.profiles
  add column if not exists check_in_total integer not null default 0;

alter table public.profiles
  add column if not exists last_check_in_date date;

create or replace function public.daily_check_in(check_day date)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total int;
  v_last date;
begin
  if auth.uid() is null then
    return json_build_object('ok', false);
  end if;
  if check_day is null then
    return json_build_object('ok', false);
  end if;

  select check_in_total, last_check_in_date into v_total, v_last
  from public.profiles
  where id = auth.uid();

  if not found then
    return json_build_object('ok', false, 'error', 'no_profile');
  end if;

  if v_last is not null and v_last = check_day then
    return json_build_object(
      'ok', true,
      'already_today', true,
      'total', coalesce(v_total, 0)
    );
  end if;

  update public.profiles
  set
    check_in_total = coalesce(check_in_total, 0) + 1,
    last_check_in_date = check_day,
    updated_at = now()
  where id = auth.uid();

  return json_build_object(
    'ok', true,
    'already_today', false,
    'total', coalesce(v_total, 0) + 1
  );
end;
$$;

grant execute on function public.daily_check_in(date) to authenticated;
