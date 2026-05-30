-- Eager-load deps so the first `hs -c` call doesn't time out on lazy load.
require("hs.window")
require("hs.screen")
require("hs.mouse")
require("hs.timer")
require("hs.spaces")

-- pr_router.lua — route a PR URL to open on the operator's current screen + Space.
--
-- Usage from hs CLI (requires `hs.ipc.cliInstall()` once):
--   hs -c "openPR('https://github.com/org/repo/pull/123')"
--
-- Rule:
--   current screen = screen containing the focused window (mouse screen as fallback)
--   if a Firefox window is visible on the current screen AND current Space → focus it,
--     and the URL lands as a new tab in that window (`open -a Firefox URL` adds to active).
--   otherwise → spawn a new Firefox window (`open -na ... --new-window`), let it land on
--     the current macOS Space (default behavior for new windows), and nudge it to the
--     current screen if Firefox restored it to a previous screen position.

local M = {}

local FIREFOX_BUNDLES = {
  "org.mozilla.firefox",
  "org.mozilla.firefoxdeveloperedition",
}

local function isFirefox(win)
  local app = win:application()
  if not app then return false end
  for _, b in ipairs(FIREFOX_BUNDLES) do
    if app:bundleID() == b then return true end
  end
  return false
end

local function currentScreen()
  local fw = hs.window.focusedWindow()
  if fw then return fw:screen() end
  return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
end

local function listContains(list, x)
  for _, v in ipairs(list or {}) do
    if v == x then return true end
  end
  return false
end

-- Returns a Firefox window visible on the given screen AND on the current Space, or nil.
local function firefoxOnCurrentScreenAndSpace(screen)
  local current_space = hs.spaces.focusedSpace()
  for _, w in ipairs(hs.window.allWindows()) do
    if isFirefox(w) and w:screen() == screen then
      local spaces = hs.spaces.windowSpaces(w)
      if listContains(spaces, current_space) then
        return w
      end
    end
  end
  return nil
end

local function newestFirefoxWindow()
  for _, w in ipairs(hs.window.orderedWindows()) do
    if isFirefox(w) then return w end
  end
  return nil
end

function M.open(url)
  local screen = currentScreen()
  local escaped = url:gsub("'", "'\\''")
  local existing = firefoxOnCurrentScreenAndSpace(screen)

  if existing then
    -- Bring the visible Firefox forward; `open -a Firefox URL` (no -n) then adds a tab to it.
    existing:focus()
    hs.timer.doAfter(0.1, function()
      hs.execute("open -a 'Firefox' '" .. escaped .. "'")
    end)
  else
    -- Spawn a new Firefox window. New windows open on the current macOS Space by default;
    -- still nudge to current screen in case Firefox restored a previous screen position.
    hs.execute("open -na 'Firefox' --args --new-window '" .. escaped .. "'")
    hs.timer.doAfter(0.8, function()
      local win = newestFirefoxWindow()
      if win then
        if win:screen() ~= screen then
          win:moveToScreen(screen, false, true)
        end
        win:focus()
      end
    end)
  end
end

-- Global entry point callable from `hs -c`
_G.openPR = function(url) M.open(url) end

return M
