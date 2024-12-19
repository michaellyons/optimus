create or replace function get_goals(
  query_roomId uuid,
  query_userId uuid,
  only_in_progress boolean,
  row_count int
)
returns setof goals
language sql
as $$
  select * from goals
  where "roomId" = query_roomId
  and "userId" = query_userId
  and (only_in_progress is not true or "status" = 'IN_PROGRESS')
  limit row_count;
$$;

create or replace function count_goals(
  query_roomId uuid
)
returns bigint
language sql
as $$
  select count(*) from goals
  where "roomId" = query_roomId;
$$;

create or replace function get_relationship(
  usera uuid,
  userb uuid
)
returns setof relationships
language sql
as $$
  select * from relationships
  where ("userA" = usera and "userB" = userb)
  or ("userA" = userb and "userB" = usera);
$$;
