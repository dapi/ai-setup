# Prompt 1. Initialization of the project
## Method of checking
- `git diff`
## Positive
- Run `bun init` with React flag according requirements
- Didn't install any "non-stack" technology proposed by Bun
- Documented everything in `README.md` according my request
## Negative
- Created `.cursor/rules/use-bun-instead-of-node-vite-npm-pnpm.mdc` file which was not requested. Not clear the reason - I have installed Cursor but it should not know about it.

# PROMPT 2. Clarify the reason for creation of cursor rules
## Respond
bun init --react generated this rule specifically to guide the Cursor AI assistant — not you or other developers directly. Its purpose is to prevent Cursor from suggesting  Node.js/npm/Vite/Jest equivalents when helping with code in this project, and instead steer it toward Bun-native APIs and tooling.                                                       
                            
In short: it's an AI coding assistant guardrail, not a developer-facing convention document. Bun includes it automatically because Cursor is a popular IDE and without this rule the AI inside it would likely suggest npm install, vite, express, jest, etc. — all of which have Bun-native replacements.  
## Positive
Looks like, it is not Claude but Bun who created it. Which is weird in a way because Anthropic is contributing a lot in Bun codebase, and using it a lot, so it could create something for Claude Code, not only for Cursor.