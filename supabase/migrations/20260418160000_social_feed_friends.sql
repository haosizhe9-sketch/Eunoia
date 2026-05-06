-- 社交：广场动态、点赞、评论、好友请求、站内通知；profiles 公开可读（登录用户）与 eunoia_id。

-- ——— profiles：展示用公开 ID ———
alter table public.profiles
  add column if not exists eunoia_id text;

-- 登录用户可读取他人资料（用于社交广场与搜索）
drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

-- 注册时写入 eunoia_id（与 Auth 邮箱 @ 前缀一致，应用内账号）
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  email_local text;
begin
  email_local := lower(nullif(trim(split_part(coalesce(new.email::text, ''), '@', 1)), ''));
  if email_local is null or email_local = '' then
    email_local := 'user_' || substr(replace(new.id::text, '-', ''), 1, 12);
  end if;

  insert into public.profiles (id, display_name, eunoia_id)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
      nullif(split_part(coalesce(new.email::text, ''), '@', 1), ''),
      '用户'
    ),
    email_local
  );

  return new;
end;
$$;

-- 历史用户回填 eunoia_id
update public.profiles p
set eunoia_id = lower(nullif(trim(split_part(u.email::text, '@', 1)), ''))
from auth.users u
where p.id = u.id
  and (p.eunoia_id is null or trim(p.eunoia_id) = '');

update public.profiles p
set eunoia_id = 'user_' || substr(replace(p.id::text, '-', ''), 1, 12)
where p.eunoia_id is null or trim(p.eunoia_id) = '';

-- 处理极小概率冲突：同一前缀重复则追加 id 片段
with ranked as (
  select
    id,
    eunoia_id,
    row_number() over (partition by lower(eunoia_id) order by created_at) as rn
  from public.profiles
)
update public.profiles p
set eunoia_id = p.eunoia_id || '_' || substr(replace(p.id::text, '-', ''), 1, 8)
from ranked r
where p.id = r.id and r.rn > 1;

drop index if exists profiles_eunoia_id_lower_key;
create unique index if not exists profiles_eunoia_id_lower_key
  on public.profiles (lower(eunoia_id))
  where eunoia_id is not null and trim(eunoia_id) <> '';

-- ——— 动态 ———
create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  like_count integer not null default 0,
  comment_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_posts_body_len check (char_length(trim(body)) > 0 and char_length(body) <= 8000)
);

create index if not exists community_posts_created_at_idx on public.community_posts (created_at desc);

alter table public.community_posts enable row level security;

create policy "community_posts_select_auth"
  on public.community_posts for select
  to authenticated
  using (true);

create policy "community_posts_insert_own"
  on public.community_posts for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "community_posts_update_own"
  on public.community_posts for update
  to authenticated
  using (auth.uid() = author_id);

create policy "community_posts_delete_own"
  on public.community_posts for delete
  to authenticated
  using (auth.uid() = author_id);

create trigger community_posts_set_updated_at
  before update on public.community_posts
  for each row execute function public.set_profiles_updated_at();

-- ——— 点赞 ———
create table if not exists public.community_post_likes (
  post_id uuid not null references public.community_posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index if not exists community_post_likes_user_idx on public.community_post_likes (user_id);

alter table public.community_post_likes enable row level security;

create policy "community_post_likes_select_auth"
  on public.community_post_likes for select
  to authenticated
  using (true);

create policy "community_post_likes_insert_own"
  on public.community_post_likes for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "community_post_likes_delete_own"
  on public.community_post_likes for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.community_post_likes_adjust_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.community_posts set like_count = like_count + 1 where id = new.post_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.community_posts set like_count = greatest(like_count - 1, 0) where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists community_post_likes_adjust on public.community_post_likes;
create trigger community_post_likes_adjust
  after insert or delete on public.community_post_likes
  for each row execute function public.community_post_likes_adjust_count();

-- ——— 评论 ———
create table if not exists public.community_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint community_post_comments_body_len check (char_length(trim(body)) > 0 and char_length(body) <= 4000)
);

create index if not exists community_post_comments_post_idx on public.community_post_comments (post_id, created_at);

alter table public.community_post_comments enable row level security;

create policy "community_post_comments_select_auth"
  on public.community_post_comments for select
  to authenticated
  using (true);

create policy "community_post_comments_insert_own"
  on public.community_post_comments for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "community_post_comments_delete_own_or_post_author"
  on public.community_post_comments for delete
  to authenticated
  using (
    auth.uid() = author_id
    or exists (
      select 1 from public.community_posts p
      where p.id = community_post_comments.post_id and p.author_id = auth.uid()
    )
  );

create or replace function public.community_post_comments_adjust_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.community_posts set comment_count = comment_count + 1 where id = new.post_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.community_posts set comment_count = greatest(comment_count - 1, 0) where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists community_post_comments_adjust on public.community_post_comments;
create trigger community_post_comments_adjust
  after insert or delete on public.community_post_comments
  for each row execute function public.community_post_comments_adjust_count();

-- ——— 站内通知 ———
create table if not exists public.social_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  actor_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('comment', 'like', 'friend_request')),
  post_id uuid references public.community_posts (id) on delete set null,
  friend_request_id uuid,
  snippet text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists social_notifications_recipient_idx on public.social_notifications (recipient_id, created_at desc);

alter table public.social_notifications enable row level security;

create policy "social_notifications_select_own"
  on public.social_notifications for select
  to authenticated
  using (auth.uid() = recipient_id);

create policy "social_notifications_update_own"
  on public.social_notifications for update
  to authenticated
  using (auth.uid() = recipient_id);

-- ——— 好友请求 ———
create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  constraint friend_requests_distinct check (requester_id <> addressee_id),
  constraint friend_requests_unique_pair unique (requester_id, addressee_id)
);

create index if not exists friend_requests_addressee_idx on public.friend_requests (addressee_id, status);

alter table public.friend_requests enable row level security;

create policy "friend_requests_select_parties"
  on public.friend_requests for select
  to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

create policy "friend_requests_insert_as_requester"
  on public.friend_requests for insert
  to authenticated
  with check (auth.uid() = requester_id);

create policy "friend_requests_update_addressee"
  on public.friend_requests for update
  to authenticated
  using (auth.uid() = addressee_id);

alter table public.social_notifications
  drop constraint if exists social_notifications_friend_request_fk;
alter table public.social_notifications
  add constraint social_notifications_friend_request_fk
  foreign key (friend_request_id) references public.friend_requests (id) on delete cascade;

create or replace function public.social_notify_on_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  post_author uuid;
begin
  select author_id into post_author from public.community_posts where id = new.post_id;
  if post_author is null or post_author = new.author_id then
    return new;
  end if;
  insert into public.social_notifications (recipient_id, actor_id, kind, post_id, snippet)
  values (
    post_author,
    new.author_id,
    'comment',
    new.post_id,
    left(trim(new.body), 200)
  );
  return new;
end;
$$;

drop trigger if exists social_notify_comment_trg on public.community_post_comments;
create trigger social_notify_comment_trg
  after insert on public.community_post_comments
  for each row execute function public.social_notify_on_comment();

create or replace function public.social_notify_on_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  post_author uuid;
begin
  select author_id into post_author from public.community_posts where id = new.post_id;
  if post_author is null or post_author = new.user_id then
    return new;
  end if;
  insert into public.social_notifications (recipient_id, actor_id, kind, post_id, snippet)
  values (post_author, new.user_id, 'like', new.post_id, null);
  return new;
end;
$$;

drop trigger if exists social_notify_like_trg on public.community_post_likes;
create trigger social_notify_like_trg
  after insert on public.community_post_likes
  for each row execute function public.social_notify_on_like();

create or replace function public.social_notify_on_friend_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'pending' then
    return new;
  end if;
  insert into public.social_notifications (recipient_id, actor_id, kind, friend_request_id, snippet)
  values (new.addressee_id, new.requester_id, 'friend_request', new.id, null);
  return new;
end;
$$;

drop trigger if exists social_notify_friend_request_trg on public.friend_requests;
create trigger social_notify_friend_request_trg
  after insert on public.friend_requests
  for each row execute function public.social_notify_on_friend_request();
