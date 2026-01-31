# LLMSummarize (Clack + Automator + LLAMA-SERVER API Call)

An Automator Quick Action **Application**, triggered by a text file in Finder, sends the path name to an AppleScript that opens to a Clack powered Terminal build in javascript. `prompt-llm-select.mjs` shows a Clack prompt for all of the available local LLM models that are found by querying the local model server running on port 11384.  After 

## LLM model selection (two-step workflow)

A two-step Automator workflow that (1) shows a Clack TUI in Terminal to pick an LLM model, then (2) displays the selected model name in a new Terminal window.

**Step 1 - Start Automation Workflow**: Create a new Quick Qction -> Choose -> Workflow receives current <files or folders> in <Finder>. For now, choose `Get Specified Finder Items` to avoid having to click on items to test over and over again.

**Step 2 — Get LLM model**: `GetLLMModels.applescript` runs `prompt-llm-select.mjs` in Terminal. The user selects a model (or cancels). The script writes the result to a temp file; the AppleScript polls for it and returns the model id to Automator. Follow the **Requirements** section below to install the dependencies and test out the script by iteself.

**Step 3 — Run the LLM and display summarized output in Swift Display Window**: The Xcode Project `LLMSummarizeDisplay` holds the swift command line application. Shift+Command+K, clean build. Command+B, build. Shift+Command+I profile (Release) build. Build the project. Product -> Copy Build Folder to get the output build folder. Create a symbolic link from that file to /usr/local/bin/LLMSummarizedDisplay:
'''bash
sudo ln -s /path/to/build/Project/Release/LLMSummarizeDisplay /usr/local/bin/LLMSummarizeDisplay
'''

**Setup**

- Ensure `prompt-llm-select.sh` is executable: `chmod +x sprompt-llm-select.sh`
- In Automator: add **Run AppleScript** (paste `GetLLMModels.applescript`)
- For future add ons, try adding another **Run AppleScript** (paste `RunSelectedModel.applescript`). It turns out that I just copied the command line Swift app call to the GetLLMModels.applescript so this is not necessary, but it could be a way to chain multiple LLMs together based on previous outputs. 

You can replace `show-selected-model.sh` with a script that does more (e.g. call an API with the model name).  It is just a test script for linking.

## Requirements

- **Node.js** (v18+) and **pnpm**
- **macOS** (Automator, Terminal)

## Setup

1. **Install dependencies**

   ```bash
   cd /path/to/automator-llm-summarize
   pnpm install
   ```

2. **Test the script**

   ```bash
   pnpm prompt
   ```

   You should see the Clack prompt in Terminal and be able to create a folder on your Desktop.

3. **Create the Automator Application**

   - Open **Automator** (Applications → Automator).
   - File → **New** → choose **Application** → Choose.
   - In the left column, select **Actions** → **Utilities** → double‑click **Run AppleScript**.
   - In the script area, replace the default script with the contents of `RunInTerminal.applescript`.
    - **Edit the first line** of the script: set `SCRIPT_DIR` to the **full path** of this folder (`automator-llm-summarize`), for example:
      - `set SCRIPT_DIR to "/Users/yourname/Models/LLMScripts/LLMSummarize/automator-llm-summarize"`
   - File → **Save** (e.g. name: `Create New Folder`, save to Applications or Desktop).

4. **Run the app**

   Right click on any text file in Finder and you can get the LLM of your choice to summarize the file.

## Customisation

- **Add features, buttons to LLMSummarizeDisplay App** We can customize the app to have the features that we want. Right now it has save and copy commands. 

## References

- [Clack – Getting started](https://bomb.sh/docs/clack/basics/getting-started/)
- [Clack – Prompts](https://bomb.sh/docs/clack/packages/prompts/)
- [Apple – Automator](https://developer.apple.com/documentation/automator)
