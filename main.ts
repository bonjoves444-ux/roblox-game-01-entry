// Sunbloom Meadow: Flower Rush - the entrypoint that hands the game in.
// It copies the place, the Luau source, the screenshots and the play link
// from this repository into the output directory, then writes dossier.json
// with the kit's buildDossier library, exactly as the gate rebuilds it.

import { cpSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

// The output directory comes from the environment, as the grader sets it;
// locally it defaults to /output, and it is never deleted, only filled.
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

// The repository root is the folder this file lives in.
const repoRoot = dirname(fileURLToPath(import.meta.url));

// Copy one entry of the repository into the output directory.
function handIn(name: string): void {
	const from = join(repoRoot, name);
	const to = join(outputDir, name);
	if (!existsSync(from)) {
		throw new Error(`Sunbloom Meadow: ${name} is missing from the repository`);
	}
	cpSync(from, to, { recursive: true });
}

// The program runs twice and both runs must write the same bytes: every
// step here is a plain copy plus a deterministic dossier build, so the
// two runs agree byte for byte.
mkdirSync(outputDir, { recursive: true });
handIn("game.rbxl");
handIn("src");
handIn("screenshots");
handIn("PLAY.json");

// The dossier is built from the files as they now sit in the output
// directory, with the gate's own caps: 64 KiB of text, at most 4 shots of
// at most 256 KiB each.
const dossier = buildDossier(outputDir, {
	text_max_bytes: 65536,
	screenshots: { max: 4, max_bytes: 256 * 1024 },
});
writeFileSync(join(outputDir, "dossier.json"), dossier);

console.log(`Sunbloom Meadow handed in to ${outputDir} (${dossier.length} dossier bytes)`);
