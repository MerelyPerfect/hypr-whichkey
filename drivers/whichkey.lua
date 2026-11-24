-- hypr-whichkey driver for Hyprland's Lua config (0.57+).
-- Usage in hyprland.lua:   dofile(os.getenv("HOME") .. "/.config/hypr-whichkey/whichkey.lua")
-- Polls modifier state every 50ms and publishes "<mask> <monitor>" while SUPER is held.
-- The overlay handles the show-delay, so this stays dumb and cheap.
local state_file = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-whichkey"
local last

local function down(a, b) return hl.is_key_down(a) or hl.is_key_down(b) end
local function write(s)
    if s == last then return end
    last = s
    local f = io.open(state_file, "w")
    if f then f:write(s, "\n"); f:close() end
end

hl.timer(function()
    if not down("Super_L", "Super_R") then return write("0") end
    local mask = 64
    if down("Shift_L", "Shift_R")     then mask = mask + 1 end
    if down("Control_L", "Control_R") then mask = mask + 4 end
    if down("Alt_L", "Alt_R")         then mask = mask + 8 end
    local mon = hl.get_active_monitor()
    write(mask .. " " .. (mon and mon.name or ""))
end, { timeout = 50, type = "repeat" })
