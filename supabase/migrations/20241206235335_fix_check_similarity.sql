CREATE OR REPLACE FUNCTION public.check_similarity_and_insert(
    query_table_name text,
    query_table_type text,
    query_userId uuid,
    query_content jsonb,
    query_roomId uuid,
    query_embedding vector,
    similarity_threshold double precision,
    query_createdAt timestamptz,
    query_id uuid DEFAULT NULL
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
            query_table_type,
            query_embedding,
            similarity_threshold
        );

        -- Execute the query to check for similarity
        EXECUTE select_query INTO similar_found;
    END IF;

    -- Prepare the insert query with 'unique' field set based on the presence of similar records or NULL query_embedding
    -- Include the optional 'id' field if provided
    insert_query := format(
        'INSERT INTO %I ("id", "userId", "content", "roomId", "type", "embedding", "unique", "createdAt") ' ||  -- Insert into the 'memories' table
        'VALUES (%L, %L, %L, %L, %L, %L, %L, %L)',
        query_table_name,
        COALESCE(query_id, uuid_generate_v4()),  -- Use the provided id or generate a new one if NULL
        query_userId,
        query_content,
        query_roomId,
        query_table_type,  -- Use query_table_name as the 'type' value
        query_embedding,
        NOT similar_found OR query_embedding IS NULL,  -- Set 'unique' to true if no similar record is found or query_embedding is NULL
        query_createdAt
    );

    -- Execute the insert query
    EXECUTE insert_query;
END;
$$;