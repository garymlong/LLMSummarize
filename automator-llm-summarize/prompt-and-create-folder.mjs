#!/usr/bin/env node
/**
 * Prompts for a new folder name using Clack and creates the folder.
 * Intended to be run from Terminal (e.g. via Automator) so the TUI is visible.
 * Creates the folder in ~/Desktop by default; set NEW_FOLDER_BASE to override.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { intro, text, outro, cancel, isCancel } from "@clack/prompts";

const INVALID_CHARS = /[/:\\*?"<>|]/;

function getBaseDir() {
  const base = process.env.NEW_FOLDER_BASE;
  if (base && path.isAbsolute(base)) return base;
  const home = process.env.HOME;
  if (!home) throw new Error("HOME not set");
  return path.join(home, "Desktop");
}

function validateFolderName(value) {
  if (value == null || String(value).trim() === "") {
    return "Please enter a folder name.";
  }
  const name = String(value).trim();
  if (INVALID_CHARS.test(name)) {
    return "Name cannot contain / \\ : * ? \" < > |";
  }
  if (name.startsWith(".") && name.length === 1) {
    return "Name cannot be just a dot.";
  }
  return undefined;
}

async function main() {
  const baseDir = getBaseDir();

  intro(
    "\x1b[1m\x1b[36m New folder \x1b[0m\n\x1b[2mEnter a name and we'll create it on your Desktop.\x1b[0m"
  );

  const folderName = await text({
    message: "Folder name",
    placeholder: "e.g. Project Alpha",
    validate: validateFolderName,
  });

  if (isCancel(folderName)) {
    cancel("No folder created.");
    process.exit(0);
  }

  const fullPath = path.join(baseDir, String(folderName).trim());

  try {
    if (fs.existsSync(fullPath)) {
      outro(`\x1b[33mAlready exists:\x1b[0m ${fullPath}`);
      process.exit(1);
    }
    fs.mkdirSync(fullPath, { recursive: false });
    outro(`\x1b[32mCreated:\x1b[0m ${fullPath}`);
  } catch (err) {
    console.error("\x1b[31mError:\x1b[0m", err.message);
    process.exit(1);
  }
}

main();
