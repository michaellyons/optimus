ALTER TABLE public.participants RENAME COLUMN user_id TO userId;
ALTER TABLE public.memories RENAME COLUMN user_id TO userId;
ALTER TABLE public.memories RENAME COLUMN agent_id TO agentId;
ALTER TABLE public.goals RENAME COLUMN user_id TO userId;
ALTER TABLE public.goals RENAME COLUMN room_id TO roomId;
ALTER TABLE public.relationships RENAME COLUMN user_a TO userA;
ALTER TABLE public.relationships RENAME COLUMN user_b TO userB;
