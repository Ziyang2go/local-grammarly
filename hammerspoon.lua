-- slack-grammarly: rephrase + write helpers
local SCRIPT = os.getenv("HOME") .. "/Work/slack-grammarly/rephrase.py"

local function callLLM(text, mode)
    local tmpfile = os.tmpname()
    local f = io.open(tmpfile, "w")
    f:write(text)
    f:close()

    local cmd = string.format(
        "/bin/cat %q | /usr/bin/env python3 %q --mode %s",
        tmpfile, SCRIPT, mode
    )
    local result, status = hs.execute(cmd, true)
    os.remove(tmpfile)

    if status and result and result ~= "" then
        return result
    end
    return nil
end

local function pasteAndRestore(text)
    local original = hs.pasteboard.getContents()
    hs.pasteboard.setContents(text)
    hs.eventtap.keyStroke({"cmd"}, "v", 0)
    hs.timer.doAfter(0.4, function()
        if original then hs.pasteboard.setContents(original) end
    end)
end

-- fn+F1: rephrase selected text in place
hs.hotkey.bind({}, "f1", function()
    local original = hs.pasteboard.getContents()
    hs.pasteboard.clearContents()
    hs.eventtap.keyStroke({"cmd"}, "c", 0)
    hs.timer.usleep(150000)

    local selected = hs.pasteboard.getContents()
    if not selected or selected == "" then
        if original then hs.pasteboard.setContents(original) end
        hs.alert.show("Nothing selected", 1)
        return
    end

    local result = callLLM(selected, "rephrase")
    if not result then
        if original then hs.pasteboard.setContents(original) end
        hs.alert.show("Rephrase failed", 1)
        return
    end

    pasteAndRestore(result)
end)

-- Multi-line write prompt via webview
local writeView = nil
local writeUserContent = nil

local WRITE_HTML = [[
<!DOCTYPE html>
<html>
<head>
<style>
  html, body { margin: 0; padding: 0; height: 100%; font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #1e1e1e; color: #eee; }
  .wrap { padding: 14px; box-sizing: border-box; height: 100%; display: flex; flex-direction: column; }
  .label { font-size: 12px; opacity: 0.7; margin-bottom: 6px; }
  textarea {
    flex: 1; width: 100%; box-sizing: border-box;
    font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 14px;
    padding: 10px; border-radius: 6px; border: 1px solid #444;
    background: #2a2a2a; color: #eee; resize: none; outline: none;
  }
  textarea:focus { border-color: #007AFF; }
  .row { margin-top: 10px; display: flex; justify-content: space-between; align-items: center; }
  .hint { font-size: 11px; opacity: 0.5; }
  .buttons { display: flex; gap: 8px; }
  button { font: inherit; font-size: 13px; padding: 6px 14px; border-radius: 5px; border: none; cursor: pointer; }
  .cancel { background: #3a3a3a; color: #eee; }
  .send { background: #007AFF; color: white; }
</style>
</head>
<body>
<div class="wrap">
  <div class="label">What should the message say?</div>
  <textarea id="t" autofocus placeholder="e.g. tell jamie I will review the PR after lunch"></textarea>
  <div class="row">
    <span class="hint">⌘+Enter to send · Esc to cancel</span>
    <div class="buttons">
      <button class="cancel" onclick="cancel()">Cancel</button>
      <button class="send" onclick="send()">Send</button>
    </div>
  </div>
</div>
<script>
  const post = (action, text) => webkit.messageHandlers.writePrompt.postMessage({action, text});
  const send = () => post('send', document.getElementById('t').value);
  const cancel = () => post('cancel', '');
  document.getElementById('t').addEventListener('keydown', e => {
    if (e.metaKey && e.key === 'Enter') { e.preventDefault(); send(); }
    if (e.key === 'Escape') { e.preventDefault(); cancel(); }
  });
  setTimeout(() => document.getElementById('t').focus(), 50);
</script>
</body>
</html>
]]

local function closeWriteView()
    if writeView then
        writeView:delete()
        writeView = nil
    end
    writeUserContent = nil
end

local function showWritePrompt()
    closeWriteView()

    local prevWin = hs.window.focusedWindow()

    local screen = hs.screen.mainScreen():frame()
    local w, h = 640, 280
    local x = screen.x + (screen.w - w) / 2
    local y = screen.y + (screen.h - h) / 3

    writeUserContent = hs.webview.usercontent.new("writePrompt")
    writeUserContent:setCallback(function(msg)
        local body = msg.body or {}
        local action = body.action
        local instruction = body.text

        closeWriteView()
        if prevWin then prevWin:focus() end

        if action ~= "send" or not instruction or instruction == "" then
            return
        end

        hs.timer.doAfter(0.1, function()
            local alert = hs.alert.show("Writing…", 99)
            local result = callLLM(instruction, "write")
            hs.alert.closeSpecific(alert)

            if not result then
                hs.alert.show("Write failed", 1.5)
                return
            end

            pasteAndRestore(result)
        end)
    end)

    writeView = hs.webview.new({x=x, y=y, w=w, h=h}, {}, writeUserContent)
        :windowStyle({"titled", "closable", "resizable"})
        :windowTitle("Write a message")
        :allowTextEntry(true)
        :level(hs.drawing.windowLevels.modalPanel)
        :html(WRITE_HTML)
        :bringToFront(true)
        :show()

    hs.timer.doAfter(0.05, function()
        if writeView then writeView:bringToFront(true) end
    end)
end

hs.hotkey.bind({}, "f2", showWritePrompt)
