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
      m."roomId" = $1
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
