-- 听力 / 阅读 模拟练习错题（Practice 今日任务）

create table if not exists public.practice_exam_wrongs (
  user_id uuid not null references auth.users (id) on delete cascade,
  skill text not null check (skill in ('listening', 'reading')),
  question_key text not null,
  title text not null,
  description text not null default '',
  user_answer text not null default '',
  correct_answer text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, skill, question_key)
);

create index if not exists practice_exam_wrongs_user_updated_idx
  on public.practice_exam_wrongs (user_id, updated_at desc);

alter table public.practice_exam_wrongs enable row level security;

create policy "practice_exam_wrongs_select_own"
  on public.practice_exam_wrongs for select
  using (auth.uid() = user_id);

create policy "practice_exam_wrongs_insert_own"
  on public.practice_exam_wrongs for insert
  with check (auth.uid() = user_id);

create policy "practice_exam_wrongs_update_own"
  on public.practice_exam_wrongs for update
  using (auth.uid() = user_id);

create policy "practice_exam_wrongs_delete_own"
  on public.practice_exam_wrongs for delete
  using (auth.uid() = user_id);

drop trigger if exists practice_exam_wrongs_set_updated_at on public.practice_exam_wrongs;
create trigger practice_exam_wrongs_set_updated_at
  before update on public.practice_exam_wrongs
  for each row execute function public.set_profiles_updated_at();
