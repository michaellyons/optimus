import { Character, ModelProviderName, defaultCharacter } from "@ai16z/eliza";
import fs from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const alissaJsonPath = path.resolve(__dirname, '../characters/alissa.character.json');
const alissaData = JSON.parse(fs.readFileSync(alissaJsonPath, 'utf-8'));

export const character: Character = {
    ...alissaData,
    agentId: 'alissa'
} as Character;
