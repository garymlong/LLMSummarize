# Plan: Automator app with Clack prompt → create LLM summarize folder

- [x] Research Clack (bomb.sh) and Automator
- [x] Design flow: Automator app → AppleScript opens Terminal → Node script (Clack + mkdir)
- [x] Implement Node script with @clack/prompts (intro, text, validate, outro/cancel)
- [x] Add package.json and RunInTerminal.applescript
- [x] Document setup and customisation in README

## References

- [Clack – Getting started](https://bomb.sh/docs/clack/basics/getting-started/)
- [Clack – Prompts](https://bomb.sh/docs/clack/packages/prompts/)
- [Apple – Automator](https://developer.apple.com/documentation/automator)
- [Run script in Terminal from Automator](https://apple.stackexchange.com/questions/313325) (AppleScript `tell application "Terminal" to do script`)

## Decisions

- **Why Terminal?** Clack is a TUI and needs a real TTY; Automator’s “Run Shell Script” runs headless, so we use AppleScript to open Terminal and run the Node script there.
- **Folder location:** Default is `~/Desktop`; overridable via env `NEW_FOLDER_BASE`.
- **Validation:** Non-empty, no `/ \ : * ? " < > |` in the name.
