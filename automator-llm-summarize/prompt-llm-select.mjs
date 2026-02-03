#!/usr/bin/env node
/**
 * Prompts the user to select a model from the list of
 * available localLLM models running on LLAMA-SERVER.
 */
import * as fs from "node:fs";
import { intro, select, outro, cancel, isCancel } from "@clack/prompts";

const LLAMA_SERVER_PORT = 11434;
/** Use 127.0.0.1 so Node targets IPv4; localhost can resolve to ::1 and llama-server may listen only on IPv4. */
const LLAMA_SERVER_HOST = "127.0.0.1";

async function getModels() {
  // curl http://127.0.0.1:${LLAMA_SERVER_PORT}/v1/models to get the list of models
  const model = { id: "", description: "" };
  const url = `http://${LLAMA_SERVER_HOST}:${LLAMA_SERVER_PORT}/v1/models`;
  try {
    const response = await fetch(url,
                                  { method: "GET",
                                    headers: { "Content-Type": "application/json" }
                                  });

    if (!response.ok) {
      console.error("Error getting models:", response.statusText);
      return [];
    }
    
    const data = await response.json();
    const models = [];
    console.log("Available models:");
    data.data.forEach(model => {
      //console.log(model.id);
      models.push({ id: model.id, 
                    description: model.status.value === "loaded" ?
                    "Loaded" : "Not loaded" });
    });
    return models;
  } catch (error) {
    console.error("Error getting models:", error);
    return [];
  }
}

async function main() {
  const models = await getModels();

  //console.log(models);

  intro(
    "\x1b[1m\x1b[36m LLAMA-SERVER models \x1b[0m\n\x1b[2mChoose a model to use for summarization.\x1b[0m"
  );

  const defaultModelIndex = models.findIndex(model => model.description === "Loaded");
  //console.log("Found default model index:", defaultModelIndex);
  if (defaultModelIndex >= 0) {
    models.unshift({ id: models[defaultModelIndex].id, description: "Pre-Loaded" });
  }

  const selectedModelName = await select({
    message: "Select Model (Control+C to Cancel):",
    options: models.map(model => ({ 
      value: model.id, 
      label: model.id, 
      hint: model.description 
    })),
    maxItems: 20, //max number of models to show
    //initialValue: defaultModelIndex >= 0 ? defaultModelIndex : 0,
  });

  if (isCancel(selectedModelName)) {
    cancel("Exiting...");
    process.stdout.write("CANCELLED\n");
    const resultFile = process.env.LLM_RESULT_FILE;
    if (resultFile) {
      try {
        fs.writeFileSync(resultFile, "", "utf8");
      } catch (err) {
        console.error("Error writing result file:", err.message);
      }
    }
    process.exit(0);
  }

  try {
    outro(`\x1b[32mSelected:\x1b[0m ${selectedModelName}`);
    return selectedModelName;
  } catch (err) {
    console.error("\x1b[31mError:\x1b[0m", err.message);
    process.exit(1);
  }
}

main()
  .then((value) => {
    if (value != null) {
      process.stdout.write("SELECTED:" + value + "\n");
      const resultFile = process.env.LLM_RESULT_FILE;
      if (resultFile) {
        try {
          fs.writeFileSync(resultFile, value, "utf8");
        } catch (err) {
          console.error("Error writing result file:", err.message);
        }
      }
    }
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
