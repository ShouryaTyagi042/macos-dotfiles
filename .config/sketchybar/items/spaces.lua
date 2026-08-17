local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

-- AeroSpace, not yabai. ~/.aerospace.toml fires this on every workspace switch
-- via exec-on-workspace-change; without registering it here nothing arrives.
sbar.add("event", "aerospace_workspace_change")

local WORKSPACE_COUNT = 10

local spaces = {}
local brackets = {}

for i = 1, WORKSPACE_COUNT, 1 do
  -- Named "space.N" because menus.lua toggles the whole /space\..*/ group
  local space = sbar.add("item", "space." .. i, {
    drawing = false,
    icon = {
      font = { family = settings.font.numbers },
      string = i,
      padding_left = 12,
      padding_right = 8,
      color = colors.grey,
      highlight_color = colors.blue,
    },
    label = {
      padding_right = 16,
      color = colors.grey,
      highlight_color = colors.white,
      font = "sketchybar-app-font:Regular:16.0",
      y_offset = -1,
    },
    padding_right = 1,
    padding_left = 1,
    background = {
      color = colors.bg1,
      border_width = 1,
      height = 26,
      border_color = colors.black,
    },
    click_script = "aerospace workspace " .. i,
  })

  spaces[i] = space

  -- Single-item bracket, so a focused workspace gets a double border
  brackets[i] = sbar.add("bracket", { space.name }, {
    drawing = false,
    background = {
      color = colors.transparent,
      border_color = colors.bg2,
      height = 28,
      border_width = 2,
    },
  })

  sbar.add("item", "space.padding." .. i, {
    drawing = false,
    width = settings.group_paddings,
  })
end

-- One `aerospace list-windows` call feeds every workspace, rather than ten.
-- Empty, unfocused workspaces stay hidden, so the bar only shows what exists.
local function update_spaces(focused)
  sbar.exec("aerospace list-windows --all --format '%{workspace}|%{app-name}'", function(windows)
    local icon_lines = {}

    for line in string.gmatch(windows or "", "[^\r\n]+") do
      local workspace, app = string.match(line, "^%s*(%S+)%s*|%s*(.-)%s*$")
      if workspace and app then
        local icon = app_icons[app] or app_icons["Default"]
        icon_lines[workspace] = (icon_lines[workspace] or "") .. icon
      end
    end

    for i = 1, WORKSPACE_COUNT, 1 do
      local key = tostring(i)
      local selected = (key == focused)
      local occupied = icon_lines[key] ~= nil

      -- All ten stay visible so the row never shifts position. Empty ones are
      -- dimmed rather than hidden, so the occupied ones read at a glance.
      -- `highlight` overrides these colours with the *_highlight values when
      -- the workspace is focused.
      local icon_color = occupied and colors.white or colors.with_alpha(colors.grey, 0.5)
      local label_color = occupied and colors.grey or colors.with_alpha(colors.grey, 0.4)
      local border = colors.bg2
      if selected then
        border = colors.blue
      elseif not occupied then
        border = colors.with_alpha(colors.bg2, 0.4)
      end

      spaces[i]:set({
        drawing = true,
        icon = { highlight = selected, color = icon_color },
        label = {
          highlight = selected,
          color = label_color,
          string = icon_lines[key] or " —",
        },
        background = {
          color = occupied and colors.bg1 or colors.with_alpha(colors.bg1, 0.4),
          border_color = border,
        },
      })
      brackets[i]:set({
        drawing = true,
        background = { border_color = border },
      })
      sbar.set("space.padding." .. i, { drawing = true })
    end
  end)
end

local function refresh()
  sbar.exec("aerospace list-workspaces --focused", function(focused)
    update_spaces((focused or ""):gsub("%s+", ""))
  end)
end

local space_observer = sbar.add("item", { drawing = false, updates = true })

space_observer:subscribe("aerospace_workspace_change", function(env)
  update_spaces(env.FOCUSED_WORKSPACE)
end)

-- Windows open, close and move between workspaces without the focused
-- workspace changing, so the icon rows need refreshing on app switches too.
space_observer:subscribe("front_app_switched", refresh)
space_observer:subscribe("system_woke", refresh)

-- menus.lua reveals the whole /space\..*/ group on swap-back, which would also
-- reveal the empty workspaces. Re-apply visibility afterwards.
space_observer:subscribe("swap_menus_and_spaces", refresh)

local spaces_indicator = sbar.add("item", {
  padding_left = -3,
  padding_right = 0,
  icon = {
    padding_left = 8,
    padding_right = 9,
    color = colors.grey,
    string = icons.switch.on,
  },
  label = {
    width = 0,
    padding_left = 0,
    padding_right = 8,
    string = "Spaces",
    color = colors.bg1,
  },
  background = {
    color = colors.with_alpha(colors.grey, 0.0),
    border_color = colors.with_alpha(colors.bg1, 0.0),
  }
})

spaces_indicator:subscribe("swap_menus_and_spaces", function(env)
  local currently_on = spaces_indicator:query().icon.value == icons.switch.on
  spaces_indicator:set({
    icon = currently_on and icons.switch.off or icons.switch.on
  })
end)

spaces_indicator:subscribe("mouse.entered", function(env)
  sbar.animate("tanh", 30, function()
    spaces_indicator:set({
      background = {
        color = { alpha = 1.0 },
        border_color = { alpha = 1.0 },
      },
      icon = { color = colors.bg1 },
      label = { width = "dynamic" }
    })
  end)
end)

spaces_indicator:subscribe("mouse.exited", function(env)
  sbar.animate("tanh", 30, function()
    spaces_indicator:set({
      background = {
        color = { alpha = 0.0 },
        border_color = { alpha = 0.0 },
      },
      icon = { color = colors.grey },
      label = { width = 0, }
    })
  end)
end)

spaces_indicator:subscribe("mouse.clicked", function(env)
  sbar.trigger("swap_menus_and_spaces")
end)

-- Paint the initial state; no event fires until the first workspace switch.
refresh()
