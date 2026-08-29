-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Unbind web apps removed via `omarchy webapp remove`
hl.unbind("SUPER + SHIFT + X")        -- was: X
hl.unbind("SUPER + SHIFT + ALT + X")  -- was: X Post
hl.unbind("SUPER + SHIFT + ALT + G")  -- was: WhatsApp
hl.unbind("SUPER + SHIFT + P")        -- was: Google Photos
hl.unbind("SUPER + SHIFT + CTRL + G") -- was: Google Messages
hl.unbind("SUPER + SHIFT + S")        -- was: Google Maps
hl.unbind("SUPER + SHIFT + M")        -- was: Music (Spotify)
hl.unbind("SUPER + SHIFT + G")        -- was: Signal
hl.unbind("SUPER + SHIFT + SLASH")    -- was: Passwords (1Password)
hl.unbind("SUPER + SHIFT + A")        -- was: ChatGPT
hl.unbind("SUPER + SHIFT + ALT + A")  -- was: Grok

-- Double-tap Super to toggle the DeepSeek quick-access dropdown.
o.bind("SUPER_L", "DeepSeek quick access", "omarchy-super-tap", { release = true, ignore_mods = true })
