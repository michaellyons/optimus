CREATE TABLE IF NOT EXISTS cache (
    "key" TEXT NOT NULL,
    "agentId" UUID NOT NULL,
    "value" JSONB NOT NULL DEFAULT '{}'::jsonb,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ,
    PRIMARY KEY ("key", "agentId")
);
