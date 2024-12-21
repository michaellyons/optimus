import { PostgresDatabaseAdapter } from "@ai16z/adapter-postgres";
import { DiscordClientInterface } from "@ai16z/client-discord";
import { SupabaseDatabaseAdapter } from "./supabase-adapter.ts"
import { AutoClientInterface } from "@ai16z/client-auto";
import { TelegramClientInterface } from "@ai16z/client-telegram";
import { TwitterClientInterface } from "@ai16z/client-twitter";
import {
  DbCacheAdapter,
  defaultCharacter,
  ICacheManager,
  IDatabaseCacheAdapter,
  stringToUuid,
  AgentRuntime,
  CacheManager,
  Character,
  IAgentRuntime,
  ModelProviderName,
  elizaLogger,
  settings,
  IDatabaseAdapter,
  validateCharacterConfig,
} from "@ai16z/eliza";
import { bootstrapPlugin } from "@ai16z/plugin-bootstrap";
import { solanaPlugin } from "@ai16z/plugin-solana";
import { nodePlugin } from "@ai16z/plugin-node";
import fs from "fs";
import yargs from "yargs";
import path from "path";
import { fileURLToPath } from "url";
import { character } from "./character.ts";
import type { DirectClient } from "@ai16z/client-direct";
// import { Resource } from 'sst'

// import * as dotenv from 'dotenv'
// dotenv.populate(process.env, {
//   SUPABASE_URL: Resource.SUPABASE_URL.value,
//   SUPABASE_ANON_KEY: Resource.SUPABASE_ANON_KEY.value,
//   OPENAI_API_KEY: Resource.OPENAI_API_KEY.value,
//   DISCORD_APPLICATION_ID: Resource.DISCORD_APPLICATION_ID.value,
//   DISCORD_API_TOKEN: Resource.DISCORD_API_TOKEN.value,
// })


const __filename = fileURLToPath(import.meta.url); // get the resolved path to the file
const __dirname = path.dirname(__filename); // get the name of the directory

export const wait = (minTime: number = 1000, maxTime: number = 3000) => {
  const waitTime =
    Math.floor(Math.random() * (maxTime - minTime + 1)) + minTime;
  return new Promise((resolve) => setTimeout(resolve, waitTime));
};

export function parseArguments(): {
  character?: string;
  characters?: string;
} {
  try {
    return yargs(process.argv.slice(2))
      .option("character", {
        type: "string",
        description: "Path to the character JSON file",
      })
      .option("characters", {
        type: "string",
        description: "Comma separated list of paths to character JSON files",
      })
      .parseSync();
  } catch (error) {
    console.error("Error parsing arguments:", error);
    return {};
  }
}

export async function loadCharacters(
  charactersArg: string
): Promise<Character[]> {
  let characterPaths = charactersArg?.split(",").map((filePath) => {
    if (path.basename(filePath) === filePath) {
      filePath = "characters/" + filePath;
    }
    return path.resolve(process.cwd(), filePath.trim());
  });

  const loadedCharacters = [];

  if (characterPaths?.length > 0) {
    for (const path of characterPaths) {
      try {
        const character = JSON.parse(fs.readFileSync(path, "utf8"));

        validateCharacterConfig(character);

        loadedCharacters.push(character);
      } catch (e) {
        console.error(`Error loading character from ${path}: ${e}`);
        // don't continue to load if a specified file is not found
        process.exit(1);
      }
    }
  }

  if (loadedCharacters.length === 0) {
    console.log("No characters found, using default character");
    loadedCharacters.push(defaultCharacter);
  }

  return loadedCharacters;
}

export function getTokenForProvider(
  provider: ModelProviderName,
  character: Character
) {
  switch (provider) {
    case ModelProviderName.OPENAI:
      return (
        character.settings?.secrets?.OPENAI_API_KEY || settings.OPENAI_API_KEY
      );
    case ModelProviderName.LLAMACLOUD:
      return (
        character.settings?.secrets?.LLAMACLOUD_API_KEY ||
        settings.LLAMACLOUD_API_KEY ||
        character.settings?.secrets?.TOGETHER_API_KEY ||
        settings.TOGETHER_API_KEY ||
        character.settings?.secrets?.XAI_API_KEY ||
        settings.XAI_API_KEY ||
        character.settings?.secrets?.OPENAI_API_KEY ||
        settings.OPENAI_API_KEY
      );
    case ModelProviderName.ANTHROPIC:
      return (
        character.settings?.secrets?.ANTHROPIC_API_KEY ||
        character.settings?.secrets?.CLAUDE_API_KEY ||
        settings.ANTHROPIC_API_KEY ||
        settings.CLAUDE_API_KEY
      );
    case ModelProviderName.REDPILL:
      return (
        character.settings?.secrets?.REDPILL_API_KEY || settings.REDPILL_API_KEY
      );
    case ModelProviderName.OPENROUTER:
      return (
        character.settings?.secrets?.OPENROUTER || settings.OPENROUTER_API_KEY
      );
    case ModelProviderName.GROK:
      return character.settings?.secrets?.GROK_API_KEY || settings.GROK_API_KEY;
    case ModelProviderName.HEURIST:
      return (
        character.settings?.secrets?.HEURIST_API_KEY || settings.HEURIST_API_KEY
      );
    case ModelProviderName.GROQ:
      return character.settings?.secrets?.GROQ_API_KEY || settings.GROQ_API_KEY;
  }
}

function initializeDatabase(dataDir: string) {
  if (process.env.POSTGRES_URL) {
    const db = new PostgresDatabaseAdapter({
      connectionString: process.env.POSTGRES_URL,
    });
    return db;
  } else if (process.env.SUPABASE_URL) {
    const db = new SupabaseDatabaseAdapter(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_ANON_KEY!,
    );
    return db;
  } else {
    process.exit(1)
  }
}

export async function initializeClients(
  character: Character,
  runtime: IAgentRuntime
) {
  const clients = [];
  const clientTypes = character.clients?.map((str) => str.toLowerCase()) || [];

  if (clientTypes.includes("auto")) {
    const autoClient = await AutoClientInterface.start(runtime);
    if (autoClient) clients.push(autoClient);
  }

  if (clientTypes.includes("discord")) {
    clients.push(await DiscordClientInterface.start(runtime));
  }

  if (clientTypes.includes("telegram")) {
    const telegramClient = await TelegramClientInterface.start(runtime);
    if (telegramClient) clients.push(telegramClient);
  }

  if (clientTypes.includes("twitter")) {
    const twitterClients = await TwitterClientInterface.start(runtime);
    clients.push(twitterClients);
  }

  if (character.plugins?.length > 0) {
    for (const plugin of character.plugins) {
      if (plugin.clients) {
        for (const client of plugin.clients) {
          clients.push(await client.start(runtime));
        }
      }
    }
  }

  return clients;
}

export function createAgent(
  character: Character,
  db: IDatabaseAdapter,
  cache: ICacheManager,
  token: string
) {
  elizaLogger.success(
    elizaLogger.successesTitle,
    "Creating runtime for character",
    character.name
  );
  return new AgentRuntime({
    databaseAdapter: db,
    agentId: character.agentId,
    token,
    modelProvider: character.modelProvider,
    evaluators: [],
    character,
    plugins: [
      bootstrapPlugin,
      nodePlugin,
      character.settings.secrets?.WALLET_PUBLIC_KEY ? solanaPlugin : null,
    ].filter(Boolean),
    providers: [],
    actions: [],
    services: [],
    managers: [],
    cacheManager: cache,
  });
}

function initializeDbCache(character: Character, db: IDatabaseCacheAdapter) {
  const cache = new CacheManager(new DbCacheAdapter(db, character.id));
  return cache;
}

async function startAgent(character: Character, directClient?: DirectClient) {
  try {
    character.id ??= stringToUuid(character.name);
    character.username ??= character.name;

    const token = getTokenForProvider(character.modelProvider, character);
    const dataDir = path.join(__dirname, "../data");

    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }

    const db = initializeDatabase(dataDir);

    await db.init();
    const cache = initializeDbCache(character, db);
    const runtime = createAgent(character, db, cache, token);

    await runtime.initialize();
    const clients = await initializeClients(character, runtime);

    if (directClient) {
      directClient.registerAgent(runtime);
    }

    return { runtime, clients }; // Modified to return both runtime and clients
  } catch (error) {
    elizaLogger.error(
      `Error starting agent for character ${character.name}:`,
      error
    );
    console.error(error);
    throw error;
  }
}

class AgentRegistry {
  constructor() {
    this.agents = new Map();
  }

  async loadAgents() {
    const characters = await loadCharacters('alissa.character.json');
    for (const character of characters) {
      await this.registerAgent(character);
    }
  }

  async registerAgent(character) {
    if (this.agents.has(character.id)) {
      throw new Error(`Agent ${character.name} is already registered.`);
    }
    console.log("Register agent "+character.name)
    const agentData = await startAgent(character); // Call startAgent and store the return
    console.log(character.clients)
    // console.log(agentData)
    this.agents.set(character.id, { character, ...agentData, status: 'started' }); // Store agentData in the manager
  }

  async startAgent(characterId) {
    const agentData = this.agents.get(characterId);
    if (!agentData) {
      throw new Error(`Agent with ID ${characterId} is not registered.`);
    }
    if (agentData.status === 'running') {
      console.log(`Agent ${agentData.character.name} is already running.`);
      return;
    }
    agentData.status = 'running';
    console.log(`Agent ${agentData.character.name} started.`);
  }

  async stopAgent(characterId) {
    const agentData = this.agents.get(characterId);
    if (!agentData) {
      throw new Error(`Agent with ID ${characterId} is not registered.`);
    }
    if (agentData.status === 'stopped') {
      console.log(`Agent ${agentData.character.name} is already stopped.`);
      return;
    }
    agentData.status = 'stopped';
    console.log(`Agent ${agentData.character.name} stopped.`);
  }

  getStatusPage() {
    const statusPage = Array.from(this.agents.entries()).map(([key, agentData]) => ({
      id: agentData.id,
      key,
      name: agentData.character.name,
      status: agentData.status
    }));
    return statusPage;
  }
}

import { Hono } from 'hono';

const app = new Hono();

const agentRegistry = new AgentRegistry();
(async () => {
  await agentRegistry.loadAgents();
})()

app.post('/agents', async (c) => {
  try {
    const character = await c.req.parseBody();
    await agentRegistry.registerAgent(character);
    await agentRegistry.startAgent(character.id);
    return c.json({ message: `Agent ${character.name} registered and started.` });
  } catch (error) {
    console.error(error);
    return c.json({ error: error.message }, 500);
  }
});

app.get('/agents/:id/start', async (c) => {
  const characterId = c.req.param('id');
  try {
    await agentRegistry.startAgent(characterId);
    return c.json({ message: `Agent with ID ${characterId} started.` });
  } catch (error) {
    console.error(error);
    return c.json({ error: error.message }, 404);
  }
});

app.get('/agents/:id/stop', async (c) => {
  const characterId = c.req.param('id');
  try {
    await agentRegistry.stopAgent(characterId);
    return c.json({ message: `Agent with ID ${characterId} stopped.` });
  } catch (error) {
    console.error(error);
    return c.json({ error: error.message }, 404);
  }
});

app.get('/agents/status', async (c) => {
  try {
    const statusPage = agentRegistry.getStatusPage();
    return c.json({ agents: statusPage });
  } catch (error) {
    console.error(error);
    return c.json({ error: error.message }, 500);
  }
});

app.post('/agents/start-all', async (c) => {
  try {
    await agentRegistry.startAllAgents();
    return c.json({ message: 'All agents started.' });
  } catch (error) {
    console.error(error);
    return c.json({ error: error.message }, 500);
  }
});

app.post('/agents/stop-all', async (c) => {
  try {
    await agentRegistry.stopAllAgents();
    return c.json({ message: 'All agents stopped.' });
  } catch (error) {
    console.error(error);
    return c.json({ error: error.message }, 500);
  }
});

app.delete('/agents/:id', async (c) => {
  const characterId = c.req.param('id');
  try {
    agentRegistry.deleteAgent(characterId);
    return c.json({ message: `Agent with ID ${characterId} deleted.` });
  } catch (error) {
    console.error(error);
    return c.json({ error: error.message }, 404);
  }
});

export default app;