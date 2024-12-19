create extension if not exists vector;

create table public.accounts (
    id uuid not null primary key,
    created_at timestamp with time zone default current_timestamp,
    name text,
    username text,
    email text not null,
    avatar_url text,
    details jsonb default '{}'::jsonb,
    is_agent boolean default false not null,
    location text,
    profile_line text,
    signed_tos boolean default false not null,
    unique(email)
);

create table public.rooms (
    id uuid not null primary key,
    created_at timestamp with time zone default current_timestamp
);


create table public.participants (
    id uuid not null primary key,
    created_at timestamp with time zone default current_timestamp not null,
    user_id uuid not null references public.accounts on delete cascade,
    room_id uuid not null references public.rooms on delete cascade,
    user_state text,
    last_message_read uuid
);


create table public.memories (
    id uuid not null primary key,
    type text not null,
    content jsonb not null,
    embedding vector(1536),
    user_id uuid not null references public.accounts on delete cascade,
    room_id uuid not null references public.rooms on delete cascade,
    agent_id uuid not null,
    "unique" boolean default FALSE,
    created_at timestamp with time zone not null
);

create index memory_embedding_idx on
  public.memories using ivfflat (embedding vector_cosine_ops)
  with (lists = 100);


create table public.relationships (
    id uuid not null primary key,
    user_a uuid not null references public.accounts on delete cascade,
    user_b uuid not null references public.accounts on delete cascade,
    status text default 'active',
    created_at timestamp with time zone default current_timestamp
);


create table public.goals (
    id uuid not null primary key,
    room_id uuid not null references public.rooms on delete cascade,
    user_id uuid references public.accounts on delete set null,
    name text not null,
    status text not null,
    objectives jsonb not null,
    created_at timestamp with time zone default current_timestamp
);

