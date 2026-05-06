-- 环球快讯模考：每日全员同一份试卷 JSON（运维/定时任务写入；客户端只读或通过 CDN 托管同名 JSON 文件）

create table if not exists public.news_mock_daily_papers (
  content_date date primary key,
  paper_json jsonb not null,
  updated_at timestamptz not null default now()
);

comment on table public.news_mock_daily_papers is
  'Daily shared news mock paper JSON for all users; key is Asia/Shanghai calendar date string side.';

create index if not exists news_mock_daily_papers_updated_at_idx
  on public.news_mock_daily_papers (updated_at desc);

alter table public.news_mock_daily_papers enable row level security;

create policy "news_mock_daily_papers_select_public"
  on public.news_mock_daily_papers
  for select
  to anon, authenticated
  using (true);
