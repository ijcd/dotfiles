-- pr_router.lua — route a PR URL to open on the operator's current screen.
--
-- Usage from hs CLI (requires "Install Command Line Tool" in Hammerspoon menu):
--   hs -c "openPR('https://github.com/org/repo/pull/123')"
--
-- Logic:
--   current screen = screen of focused window (mouse screen as fallback)
--   if any browser window already exists on current screen → open there
--   otherwise → open on the second monitor (non-primary screen)

local M = {}

local BROWSER_BUNDLES = {
  "com.google.Chrome",
  "com.brave.Browser",
  "company.thebrowser.Browser",
  "com.apple.Safari",
  "org.mozilla.firefox",
  "org.mozilla.firefoxdeveloperedition",
}

local function isBrowserWindow(win)
  local app = win:application()
  if not app then return false end
  local bid = app:bundleID()
  for _, b in ipairs(BROWSER_BUNDLES) do
    if bid == b then return true end
  end
  return false
end

local function currentScreen()
  local fw = hs.window.focusedWindow()
  if fw then return fw:screen() end
  return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
end

local function secondScreen()
  local all = hs.screen.allScreens()
  if #all >= 2 then
    local primary = hs.screen.primaryScreen()
    for _, s in ipairs(all) do
      if s ~= primary then return s end
    end
  end
  return hs.screen.mainScreen()
end

local function browserOnScreen(screen)
  for _, w in ipairs(hs.window.allWindows()) do
    if isBrowserWindow(w) and w:screen() == screen then
      return true
    end
  end
  return false
end

local function newestBrowserWindow()
  -- Hammerspoon doesn't expose window creation time.
  -- Best proxy: the frontmost browser app's focused window, else any browser window.
  for _, w in ipairs(hs.window.orderedWindows()) do
    if isBrowserWindow(w) then return w end
  end
  return nil
end

function M.open(url)
  local target = currentScreen()
  if not browserOnScreen(target) then
    target = secondScreen()
  end

  -- Shell-escape single quotes in the URL for the shell command.
  local escaped = url:gsub("'", "'\\''")
  hs.execute("open '" .. escaped .. "'")

  -- After the OS creates the window, move it to target if needed.
  hs.timer.doAfter(0.8, function()
    local win = newestBrowserWindow()
    if win then
      if win:screen() ~= target then
        win:moveToScreen(target, false, true)
      end
      win:focus()
    end
  end)
end

-- Global entry point callable from `hs -c`
_G.openPR = function(url) M.open(url) end

return M
