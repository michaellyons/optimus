CREATE OR REPLACE FUNCTION public.check_similarity_and_insert(
    query_table_name text,
    query_userId uuid,
    query_content jsonb,
    query_roomId uuid,
    query_embedding vector,
    similarity_threshold double precision,
    query_createdAt timestamptz
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    similar_found BOOLEAN := FALSE;
    select_query TEXT;
    insert_query TEXT;
BEGIN
    -- Only perform the similarity check if query_embedding is not NULL
    IF query_embedding IS NOT NULL THEN
        -- Build a dynamic query to check for existing similar embeddings using cosine distance
        select_query := format(
            'SELECT EXISTS (' ||
                'SELECT 1 ' ||
                'FROM %I ' ||
                'WHERE "userId" = %L ' ||
                'AND "roomId" = %L ' ||
                'AND "type" = %L ' ||  -- Filter by the 'type' field using query_table_name
                'AND "embedding" <=> %L < %L ' ||
                'LIMIT 1' ||
            ')',
            query_table_name,
            query_userId,
            query_roomId,
            query_table_name,  -- Use query_table_name to filter by 'type'
            query_embedding,
            similarity_threshold
        );

        -- Execute the query to check for similarity
        EXECUTE select_query INTO similar_found;
    END IF;

    -- Prepare the insert query with 'unique' field set based on the presence of similar records or NULL query_embedding
    insert_query := format(
        'INSERT INTO %I ("userId", "content", "roomId", "type", "embedding", "unique", "createdAt") ' ||  -- Insert into the 'memories' table
        'VALUES (%L, %L, %L, %L, %L, %L, %L)',
        query_table_name,
        query_userId,
        query_content,
        query_roomId,
        query_table_name,  -- Use query_table_name as the 'type' value
        query_embedding,
        NOT similar_found OR query_embedding IS NULL  -- Set 'unique' to true if no similar record is found or query_embedding is NULL
    );

    -- Execute the insert query
    EXECUTE insert_query;
END;
$$;

CREATE OR REPLACE FUNCTION public.count_memories(
    query_table_name text,
    query_roomId uuid,
    query_unique boolean DEFAULT false
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    query TEXT;
    total BIGINT;
BEGIN
    -- Initialize the base query
    query := format('SELECT COUNT(*) FROM %I WHERE "type" = %L', query_table_name, query_table_name);

    -- Add condition for roomId if not null, ensuring proper spacing
    IF query_roomId IS NOT NULL THEN
        query := query || format(' AND "roomId" = %L', query_roomId);
    END IF;

    -- Add condition for unique if TRUE, ensuring proper spacing
    IF query_unique THEN
        query := query || ' AND "unique" = TRUE';
    END IF;

    -- Debug: Output the constructed query
    RAISE NOTICE 'Executing query: %', query;

    -- Execute the constructed query
    EXECUTE query INTO total;
    RETURN total;
END;
$$;


CREATE OR REPLACE FUNCTION public.get_embedding_list(
    query_table_name text,
    query_threshold integer,
    query_input text,
    query_field_name text,
    query_field_sub_name text,
    query_match_count integer
)
RETURNS TABLE("embedding" vector, "levenshtein_score" integer)
LANGUAGE plpgsql
AS $$
DECLARE
    QUERY TEXT;
BEGIN
    -- Check the length of query_input
    IF LENGTH(query_input) > 255 THEN
        -- For inputs longer than 255 characters, use exact match only
        QUERY := format(
            'SELECT "embedding", 0 AS levenshtein_score ' ||  -- Return 0 for levenshtein_score as it's an exact match
            'FROM %I ' ||
            'WHERE "type" = %L AND ' ||
            '(content->>%L)::TEXT = %L ' ||
            'LIMIT %L',
            query_table_name,
            query_table_name,
            query_field_name,
            query_input,
            query_match_count
        );
    ELSE
        -- For inputs of 255 characters or less, use Levenshtein distance
        QUERY := format(
            'SELECT "embedding", ' ||
            'levenshtein(%L, (content->>%L)::TEXT) AS levenshtein_score ' ||
            'FROM %I ' ||
            'WHERE "type" = %L AND ' ||
            'levenshtein(%L, (content->>%L)::TEXT) <= %L ' ||
            'ORDER BY levenshtein_score ' ||
            'LIMIT %L',
            query_input,
            query_field_name,
            query_table_name,
            query_table_name,
            query_input,
            query_field_name,
            query_threshold,
            query_match_count
        );
    END IF;
    
    -- Execute the query and return the result
    RETURN QUERY EXECUTE QUERY;
END;
$$;


CREATE OR REPLACE FUNCTION public.get_goals(
    query_roomId uuid,
    query_userId uuid DEFAULT NULL::uuid,
    only_in_progress boolean DEFAULT true,
    row_count integer DEFAULT 5
)
RETURNS SETOF public.goals
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM goals
    WHERE
        (query_userId IS NULL OR "userId" = query_userId)
        AND ("roomId" = query_roomId)
        AND (NOT only_in_progress OR "status" = 'IN_PROGRESS')
    LIMIT row_count;
END;
$$;

