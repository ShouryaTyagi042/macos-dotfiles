local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Driven by AppleScript, not the `media_change` event.
--
-- `media_change` and nowplaying-cli both read Apple's private MediaRemote
-- framework, which was restricted to first-party apps in macOS 15.4. On 26.x
-- `nowplaying-cli get title artist` returns "null null" even with a track
-- loaded, so the event never fires and the item never draws. Spotify's own
-- AppleScript dictionary still works, so we poll that instead.
--
-- Consequence: this covers Spotify only. The `if application "Spotify" is
-- running` guard matters — a bare `tell application "Spotify"` would launch
-- Spotify every poll.

local POLL_SECONDS = 2
local ART_DIR = "/tmp/sketchybar-spotify-art"

-- Spotify serves 640x640 covers. SketchyBar's image `scale` is relative to the
-- source pixels, so a raw cover renders ~544px tall and paints over the rest of
-- the bar. Downscale on disk to a fixed size instead, then a constant scale
-- gives a predictable height no matter what the source resolution is.
-- ART_PX at 2x for retina crispness; displayed height is ART_PX * ART_SCALE.
local ART_PX = 44
local ART_SCALE = 0.5

local QUERY = [[osascript -e '
if application "Spotify" is running then
  tell application "Spotify"
    return (player state as text) & "\n" & name of current track & "\n" & artist of current track & "\n" & id of current track & "\n" & artwork url of current track
  end tell
else
  return "stopped"
end if' 2>/dev/null]]

local function spotify(command)
  return "osascript -e 'if application \"Spotify\" is running then tell application \"Spotify\" to "
    .. command .. "' >/dev/null 2>&1"
end

local media_cover = sbar.add("item", "media.cover", {
  position = "right",
  background = {
    image = {
      scale = ART_SCALE,
      corner_radius = 9,
      border_width = 1,
      border_color = colors.with_alpha(colors.spotify, 0.6),
    },
    color = colors.transparent,
    border_width = 0,
  },
  label = { drawing = false },
  icon = { drawing = false },
  drawing = false,
  update_freq = POLL_SECONDS,
  updates = true,
  popup = {
    align = "center",
    horizontal = true,
  }
})

local media_artist = sbar.add("item", "media.artist", {
  position = "right",
  drawing = false,
  padding_left = 3,
  padding_right = 0,
  width = 0,
  icon = { drawing = false },
  label = {
    width = 0,
    font = { size = 9 },
    color = colors.with_alpha(colors.white, 0.6),
    max_chars = 18,
    y_offset = 6,
  },
})

local media_title = sbar.add("item", "media.title", {
  position = "right",
  drawing = false,
  padding_left = 3,
  padding_right = 0,
  icon = { drawing = false },
  label = {
    font = { size = 11 },
    color = colors.white,
    width = 0,
    max_chars = 16,
    y_offset = -5,
  },
})

sbar.add("item", "media.back", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.back, color = colors.white },
  label = { drawing = false },
  click_script = spotify("previous track"),
})
local play_pause = sbar.add("item", "media.play_pause", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.play_pause, color = colors.spotify },
  label = { drawing = false },
  click_script = spotify("playpause"),
})
sbar.add("item", "media.forward", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.forward, color = colors.white },
  label = { drawing = false },
  click_script = spotify("next track"),
})

local interrupt = 0
local function animate_detail(detail)
  if (not detail) then interrupt = interrupt - 1 end
  if interrupt > 0 and (not detail) then return end

  sbar.animate("tanh", 30, function()
    media_artist:set({ label = { width = detail and "dynamic" or 0 } })
    media_title:set({ label = { width = detail and "dynamic" or 0 } })
  end)
end

local current_track = nil
local current_art = nil

local function set_artwork(track_id, url)
  if not url or url == "" or track_id == current_art then return end
  current_art = track_id

  -- Cache per track id so sketchybar sees a new path and reloads the image;
  -- reusing one filename would show a stale cover. The size is part of the
  -- name so tuning ART_PX invalidates anything cached at the old size.
  local path = ART_DIR .. "/" .. string.gsub(track_id, "[^%w]", "_") .. "-" .. ART_PX .. ".jpg"
  sbar.exec(
    "mkdir -p " .. ART_DIR .. " && { [ -f " .. path .. " ] || { curl -sfL -m 5 -o " .. path .. " '" .. url
      .. "' && sips -Z " .. ART_PX .. " " .. path .. " >/dev/null 2>&1; }; }",
    function()
      media_cover:set({ background = { image = { string = path, scale = ART_SCALE } } })
    end
  )
end

local function poll()
  sbar.exec(QUERY, function(result)
    local lines = {}
    for line in string.gmatch(result or "", "[^\r\n]+") do
      lines[#lines + 1] = line
    end

    local state = lines[1]
    if state ~= "playing" and state ~= "paused" then
      if current_track ~= nil then
        current_track = nil
        current_art = nil
        media_cover:set({ drawing = false, popup = { drawing = false } })
        media_artist:set({ drawing = false })
        media_title:set({ drawing = false })
      end
      return
    end

    local title, artist, track_id, art_url = lines[2], lines[3], lines[4], lines[5]
    local playing = (state == "playing")

    -- Dim the cover while paused so the bar reads at a glance
    media_cover:set({
      drawing = true,
      background = {
        image = {
          border_color = playing and colors.with_alpha(colors.spotify, 0.6)
            or colors.with_alpha(colors.grey, 0.5),
        },
      },
    })
    media_artist:set({ drawing = true, label = { string = artist or "" } })
    media_title:set({ drawing = true, label = { string = title or "" } })
    play_pause:set({ icon = { color = playing and colors.spotify or colors.grey } })

    if track_id then set_artwork(track_id, art_url) end

    -- Only slide the details out when the track actually changes, otherwise
    -- every 2s poll would re-trigger the animation.
    if track_id ~= current_track then
      current_track = track_id
      if playing then
        animate_detail(true)
        interrupt = interrupt + 1
        sbar.delay(5, animate_detail)
      end
    end
  end)
end

media_cover:subscribe({ "routine", "forced", "system_woke" }, poll)

media_cover:subscribe("mouse.entered", function(env)
  interrupt = interrupt + 1
  animate_detail(true)
end)

media_cover:subscribe("mouse.exited", function(env)
  animate_detail(false)
end)

media_cover:subscribe("mouse.clicked", function(env)
  media_cover:set({ popup = { drawing = "toggle" } })
end)

media_title:subscribe("mouse.exited.global", function(env)
  media_cover:set({ popup = { drawing = false } })
end)
