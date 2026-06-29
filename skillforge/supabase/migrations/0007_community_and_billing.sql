-- 0007_community_and_billing.sql
-- Community (friends, study groups, clubs, discussion, mentorship) + billing.

-- ---------------------------------------------------------------------------
-- Community
-- ---------------------------------------------------------------------------
create type friend_status as enum ('pending', 'accepted', 'blocked');

create table friendships (
  requester_id uuid not null references profiles(id) on delete cascade,
  addressee_id uuid not null references profiles(id) on delete cascade,
  status       friend_status not null default 'pending',
  created_at   timestamptz not null default now(),
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create table study_groups (
  id          uuid primary key default gen_random_uuid(),
  career_id   uuid references careers(id) on delete set null,
  name        text not null,
  description text,
  is_club     boolean not null default false,      -- career "club" vs ad-hoc group
  owner_id    uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now()
);

create table group_members (
  group_id    uuid not null references study_groups(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  role        text not null default 'member',      -- member | mentor | owner
  joined_at   timestamptz not null default now(),
  primary key (group_id, user_id)
);

-- Discussion boards: a post belongs to a group (or is global when group_id null).
create table posts (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid references study_groups(id) on delete cascade,
  career_id   uuid references careers(id) on delete set null,
  author_id   uuid not null references profiles(id) on delete cascade,
  title       text,
  body        text not null,
  created_at  timestamptz not null default now()
);

create table comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references posts(id) on delete cascade,
  author_id   uuid not null references profiles(id) on delete cascade,
  body        text not null,
  created_at  timestamptz not null default now()
);

create index idx_posts_group on posts(group_id, created_at desc);
create index idx_comments_post on comments(post_id, created_at);

-- ---------------------------------------------------------------------------
-- Billing (Stripe). subscriptions.status is written ONLY by the verified
-- stripe-webhook Edge Function; clients never write it.
-- ---------------------------------------------------------------------------
create type sub_status as enum ('trialing', 'active', 'past_due', 'canceled', 'incomplete');

create table subscriptions (
  user_id              uuid primary key references profiles(id) on delete cascade,
  stripe_customer_id   text unique,
  stripe_subscription_id text unique,
  plan                 plan_tier not null default 'free',
  status               sub_status not null default 'active',
  current_period_end   timestamptz,
  cancel_at_period_end boolean not null default false,
  updated_at           timestamptz not null default now()
);

-- Idempotency log for Stripe webhook events (dedupe by event id).
create table stripe_events (
  id           text primary key,                   -- Stripe event id
  type         text not null,
  processed_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Audit log for the admin panel (content + moderation actions).
-- ---------------------------------------------------------------------------
create table audit_log (
  id          bigserial primary key,
  actor_id    uuid references profiles(id) on delete set null,
  action      text not null,
  entity      text not null,
  entity_id   text,
  meta        jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
