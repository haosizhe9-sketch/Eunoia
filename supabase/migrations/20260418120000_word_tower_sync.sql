-- 爬词塔：历史最高层数（profiles）与错题库（词级）

alter table public.profiles
  add column if not exists word_tower_max_floor integer not null default 0;

create table if not exists public.word_tower_wrong_words (
  user_id uuid not null references auth.users (id) on delete cascade,
  english text not null,
  chinese text not null,
  wrong_chinese text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, english)
);

create index if not exists word_tower_wrong_words_user_updated_idx
  on public.word_tower_wrong_words (user_id, updated_at desc);

alter table public.word_tower_wrong_words enable row level security;

create policy "word_tower_wrong_select_own"
  on public.word_tower_wrong_words for select
  using (auth.uid() = user_id);

create policy "word_tower_wrong_insert_own"
  on public.word_tower_wrong_words for insert
  with check (auth.uid() = user_id);

create policy "word_tower_wrong_update_own"
  on public.word_tower_wrong_words for update
  using (auth.uid() = user_id);

create policy "word_tower_wrong_delete_own"
  on public.word_tower_wrong_words for delete
  using (auth.uid() = user_id);

create or replace function public.merge_word_tower_max_floor(new_floor integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;
  if new_floor is null or new_floor < 1 then
    return;
  end if;
  update public.profiles
  set
    word_tower_max_floor = greatest(coalesce(word_tower_max_floor, 0), new_floor),
    updated_at = now()
  where id = auth.uid();
end;
$$;

grant execute on function public.merge_word_tower_max_floor(integer) to authenticated;

drop trigger if exists word_tower_wrong_words_set_updated_at on public.word_tower_wrong_words;
create trigger word_tower_wrong_words_set_updated_at
  before update on public.word_tower_wrong_words
  for each row execute function public.set_profiles_updated_at();
