# local-grammarly

A tiny macOS helper that rephrases messages and drafts new ones from short instructions, powered by a Groq-hosted LLM. It works in any app — local, Mail, Notes, etc. — by intercepting hotkeys via Hammerspoon.

- **fn+F1** — rephrase the currently selected text in place (fix grammar, keep tone)
- **fn+F2** — open a small prompt window, type what you want to say, and paste the written message into the focused app

## Requirements

- macOS
- Python 3 (ships with macOS)
- [Hammerspoon](https://www.hammerspoon.org/)
- A [Groq](https://console.groq.com/) API key

## Install

1. **Clone the repo**

   ```sh
   git clone <this-repo>  '~/Work/local-grammarly'
   cd '~/Work/local-grammarly'
   ```

   The Lua script expects the repo at `~/Work/local-grammarly`. If you put it elsewhere, edit the `SCRIPT` path at the top of `hammerspoon.lua`.

2. **Add your Groq API key**

   Create `.env` in the repo root:

   ```sh
   GROQ_API_KEY=your_key_here
   # optional, defaults to llama-3.3-70b-versatile
   # GROQ_MODEL=llama-3.3-70b-versatile
   ```

3. **Install Hammerspoon**

   ```sh
   brew install --cask hammerspoon
   ```

   Open Hammerspoon once and grant it Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility).

4. **Wire up the Hammerspoon config**

   Load the Lua script from your Hammerspoon config:

   ```sh
   mkdir -p ~/.hammerspoon
   echo 'dofile(os.getenv("HOME") .. "/Work/local-grammarly/hammerspoon.lua")' >> ~/.hammerspoon/init.lua
   ```

   Then reload the Hammerspoon config (menu bar icon → Reload Config).

## Usage

- Select some text anywhere and press **fn+F1** — it gets replaced with a cleaned-up version.
- Press **fn+F2**, type an instruction (e.g. "tell jamie I'll review the PR after lunch"), hit ⌘+Enter, and the generated message is pasted into the previously focused app.
