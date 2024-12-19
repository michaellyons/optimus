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
