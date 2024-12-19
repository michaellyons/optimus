create or replace function search_memories(
  query_table_name text,
  query_roomId uuid,
  query_embedding vector,
  query_match_threshold float,
  query_match_count int,
  query_unique boolean
)
returns table (memory jsonb)
language plpgsql stable
as $$
declare
  query_text text;
begin
  query_text := format(
    'select
      m.*
    from
      %I m
    where
      m.roomId = $1
      and (m.embedding <=> $2) < (1 - $3)
      and m.unique = $4
    order by
      (m.embedding <=> $2)
    limit
      $5',
    query_table_name
  );
  return query execute query_text using query_roomId, query_embedding, query_match_threshold, query_unique, query_match_count;
end;
$$;

create or replace function get_embedding_list(
  query_table_name text,
  query_roomId uuid
)
returns table (embedding vector)
language plpgsql stable
as $$
declare
  query_text text;
begin
  query_text := format(
    'select
      m.embedding
    from
      %I m
    where
      m.roomId = $1',
    query_table_name
  );
  return query execute query_text using query_roomId;
end;
$$;

create or replace function count_memories(
  query_table_name text,
  query_roomId uuid,
  query_unique boolean
)
returns bigint
language plpgsql stable
as $$
declare
  query_text text;
  total bigint;
begin
  query_text := format(
    'select
      count(*)
    from
      %I m
    where
      m.roomId = $1
      and m.unique = $2',
    query_table_name
  );
  execute query_text into total using query_roomId, query_unique;
  return total;
end;
$$;

create or replace function remove_memories(
  query_table_name text,
  query_roomId uuid
)
returns void
language plpgsql
as $$
declare
  query_text text;
begin
  query_text := format(
    'delete from
      %I
    where
      roomId = $1',
    query_table_name
  );
  execute query_text using query_roomId;
end;
$$;

create or replace function check_similarity_and_insert(
  query_table_name text,
  query_userId uuid,
  query_content text,
  query_roomId uuid,
  query_embedding vector,
  query_createdAt timestamptz,
  similarity_threshold float
)
returns void
language plpgsql
as $$
declare
  vector_dimension int;
  existing_similarity float;
begin
  vector_dimension := get_embedding_dimension();
  execute format(
    'select
      (m.embedding <=> $1)
    from
      %I m
    where
      m.userId = $2
      and m.content = $3
      and m.roomId = $4
    order by
      (m.embedding <=> $1)
    limit 1',
    query_table_name
  ) into existing_similarity using query_embedding, query_userId, query_content, query_roomId;
  if existing_similarity is null or existing_similarity > similarity_threshold then
    execute format(
      'insert into %I (content, userId, roomId, embedding, createdAt)
      values ($1, $2, $3, $4, $5)',
      query_table_name
    ) using query_content, query_userId, query_roomId, query_embedding, query_createdAt;
  end if;
end;
$$;
