CREATE OR REPLACE FUNCTION public.create_room(roomId uuid)
RETURNS void AS $$
BEGIN
    -- Attempt to insert a new room with the given roomId
    INSERT INTO public.rooms (id) VALUES (roomId);
EXCEPTION
    WHEN others THEN
        -- If an error occurs, raise a notice with the error message
        RAISE NOTICE 'Error creating room: Could not find the function public.create_room(roomId) in the schema cache';
END;
$$ LANGUAGE plpgsql;
