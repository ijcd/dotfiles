-- Function to toggle "always on top" for the currently focused window
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "T", function()
  -- Helper function for showing errors
  local function showError(message, duration)
    duration = duration or 5 -- Default duration 5 seconds
    print("Error:", message)
    hs.alert.show(message, duration)
  end

  local win = hs.window.focusedWindow()
  if not win then
    showError("No focused window found.", 2)
    return
  end

  -- *** Experimental: Check for potential direct level/setLevel methods ***
  if type(win.level) ~= "function" or type(win.setLevel) ~= "function" then
    -- Print inspect output if methods are missing
    print("Error: Focused window object is missing required methods (level/setLevel). Inspecting object:")
    print(hs.inspect(win))
    showError("Window object missing methods for direct call.", 5)
    return
  end

  -- Attempt to read current level directly
  local currentLevel = win:level()
  local normalLevel = hs.canvas.windowLevels.normal
  local floatingLevel = hs.canvas.windowLevels.floating

  -- Debug prints
  print("Direct Read - Current Level:", currentLevel, "Type:", type(currentLevel))
  print("Direct Read - Comparison (current == normal):", currentLevel == normalLevel)

  -- Calculate target level
  local newLevel = (currentLevel == normalLevel) and floatingLevel or normalLevel
  print("Direct Read - Calculated New Level:", newLevel)

  -- *** Experimental: Attempt direct setLevel call ***
  local success, err = pcall(function()
    win:setLevel(newLevel) -- Direct call attempt
  end)

  if success then
    print("Direct setLevel call pcall SUCCEEDED (effect not guaranteed)")
    local state = (newLevel == floatingLevel) and "ON" or "OFF"
    hs.alert.show("Always on Top (Direct Attempt): " .. state)
  else
    print("Direct setLevel call pcall FAILED:", err)
    showError("Direct setLevel call failed: " .. tostring(err))
  end
end)

-- Ensure any trailing code related to the old logic is removed or commented out if necessary

