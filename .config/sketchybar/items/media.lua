local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Spotify: a compact cover in the bar, expanding to a mini-player popup.
--
-- State and control both go through helpers/spotify.sh, which drives Spotify's
-- AppleScript dictionary. The upstream `media_change` event and nowplaying-cli
-- read Apple's private MediaRemote framework, restricted to first-party apps in
-- macOS 15.4 — on 26.x it returns null even with a track loaded, so the item
-- never drew at all.
--
-- Layout note: sketchybar popups are a single row *or* a single column
-- (popup.horizontal is one flag for the whole popup), so this is one wide row
-- rather than the 2D panel a native widget would use. The three text lines are
-- stacked by giving their items zero width and offsetting the labels
-- vertically, then reserving the space with a spacer.

local HELPER = "$CONFIG_DIR/helpers/spotify.sh"

-- Poll slowly for the bar item; the popup needs a finer tick to animate the
-- scrubber, so the frequency is raised while it is open and dropped on close.
local POLL_IDLE = 2
local POLL_OPEN = 1

local ART_DIR = "/tmp/sketchybar-spotify-art"
-- SketchyBar's image `scale` multiplies the *source* pixels, so the art is
-- resized on disk to a known size and always rendered at ART_SCALE. Sizes are
-- 2x the displayed height for retina. Cover art from Spotify is 640x640; left
-- unscaled it renders ~544px tall and paints over the whole bar.
local ART_SCALE = 0.5
local ART_BAR_PX = 44  -- 22pt in the bar
local ART_POP_PX = 80  -- 40pt in the popup

local function fmt_time(seconds)
  if not seconds or seconds < 0 then seconds = 0 end
  local mins = math.floor(seconds / 60)
  local secs = math.floor(seconds % 60)
  return string.format("%d:%02d", mins, secs)
end

-- ─── bar item ──────────────────────────────────────────────────────────────

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
  update_freq = POLL_IDLE,
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

-- ─── popup: cover ──────────────────────────────────────────────────────────

local POPUP = "popup." .. media_cover.name

local pop_art = sbar.add("item", "media.pop.art", {
  position = POPUP,
  width = ART_POP_PX * ART_SCALE + 8,
  background = {
    image = {
      scale = ART_SCALE,
      corner_radius = 6,
      border_width = 0,
    },
    color = colors.transparent,
    border_width = 0,
    height = ART_POP_PX * ART_SCALE,
  },
  icon = { drawing = false },
  label = { drawing = false },
})

-- ─── popup: stacked title / album / artist ─────────────────────────────────
-- Zero-width items draw at the same x and overflow, so the vertical offsets
-- stack them into three lines. media_title/media_artist above use the same
-- trick in the bar itself.

local function text_line(name, y_offset, color, style, size)
  return sbar.add("item", name, {
    position = POPUP,
    width = 0,
    icon = { drawing = false },
    label = {
      string = "",
      width = 0,
      y_offset = y_offset,
      color = color,
      max_chars = 26,
      align = "left",
      font = {
        family = settings.font.text,
        style = settings.font.style_map[style],
        size = size,
      },
    },
  })
end

local pop_title = text_line("media.pop.title", 13, colors.white, "Bold", 13.0)
local pop_album = text_line("media.pop.album", 0, colors.spotify, "Semibold", 11.0)
local pop_artist = text_line("media.pop.artist", -13, colors.grey, "Semibold", 11.0)

-- Reserves the horizontal space the three zero-width lines overflow into
sbar.add("item", "media.pop.textpad", {
  position = POPUP,
  width = 210,
  icon = { drawing = false },
  label = { drawing = false },
})

-- ─── popup: transport ──────────────────────────────────────────────────────

local function button(name, glyph, action, color)
  return sbar.add("item", name, {
    position = POPUP,
    icon = {
      string = glyph,
      color = color or colors.white,
      font = { family = settings.font.text, size = 14.0 },
      padding_left = 6,
      padding_right = 6,
    },
    label = { drawing = false },
    click_script = HELPER .. " " .. action,
  })
end

local pop_shuffle = button("media.pop.shuffle", icons.media.shuffle, "shuffle", colors.grey)
button("media.pop.prev", icons.media.back, "prev")
local pop_play = button("media.pop.play", icons.media.play_pause, "playpause", colors.spotify)
button("media.pop.next", icons.media.forward, "next")
local pop_loop = button("media.pop.loop", icons.media.loop, "loop", colors.grey)

-- ─── popup: scrubber ───────────────────────────────────────────────────────

local pop_elapsed = sbar.add("item", "media.pop.elapsed", {
  position = POPUP,
  width = 40,
  icon = { drawing = false },
  label = {
    string = "0:00",
    color = colors.grey,
    font = { family = settings.font.numbers, size = 10.0 },
  },
})

local pop_progress = sbar.add("slider", "media.pop.progress", 150, {
  position = POPUP,
  slider = {
    highlight_color = colors.spotify,
    background = {
      height = 5,
      corner_radius = 3,
      color = colors.bg2,
    },
    knob = { string = "􀀁", drawing = true },
  },
  background = { color = colors.transparent, height = 2, border_width = 0 },
  -- Duration is appended per-track in render(); seeking needs it to turn the
  -- click percentage into a position in seconds.
  click_script = HELPER .. " seek $PERCENTAGE 0",
})

local pop_remaining = sbar.add("item", "media.pop.remaining", {
  position = POPUP,
  width = 44,
  icon = { drawing = false },
  label = {
    string = "-0:00",
    color = colors.grey,
    font = { family = settings.font.numbers, size = 10.0 },
  },
})

-- ─── popup: volume ─────────────────────────────────────────────────────────

sbar.add("item", "media.pop.volicon", {
  position = POPUP,
  icon = {
    string = icons.media.speaker,
    color = colors.grey,
    font = { family = settings.font.text, size = 12.0 },
    padding_left = 6,
    padding_right = 2,
  },
  label = { drawing = false },
})

local pop_volume = sbar.add("slider", "media.pop.volume", 70, {
  position = POPUP,
  slider = {
    highlight_color = colors.white,
    background = {
      height = 5,
      corner_radius = 3,
      color = colors.bg2,
    },
    knob = { string = "􀀁", drawing = true },
  },
  background = { color = colors.transparent, height = 2, border_width = 0 },
  click_script = HELPER .. " volume $PERCENTAGE",
})

-- ─── hover behaviour in the bar ────────────────────────────────────────────

local interrupt = 0
local function animate_detail(detail)
  if (not detail) then interrupt = interrupt - 1 end
  if interrupt > 0 and (not detail) then return end

  sbar.animate("tanh", 30, function()
    media_artist:set({ label = { width = detail and "dynamic" or 0 } })
    media_title:set({ label = { width = detail and "dynamic" or 0 } })
  end)
end

-- ─── artwork ───────────────────────────────────────────────────────────────

local current_track = nil
local current_art = nil

local function set_artwork(track_id, url)
  if not url or url == "" or track_id == current_art then return end
  current_art = track_id

  -- Cached per track id and per size: sketchybar caches images by path, so a
  -- fixed filename would keep showing the first cover it ever loaded.
  local slug = ART_DIR .. "/" .. string.gsub(track_id, "[^%w]", "_")
  local bar_path = slug .. "-" .. ART_BAR_PX .. ".jpg"
  local pop_path = slug .. "-" .. ART_POP_PX .. ".jpg"

  local fetch = "mkdir -p " .. ART_DIR .. " && { [ -f " .. pop_path .. " ] || { "
    .. "curl -sfL -m 5 -o " .. slug .. "-src.jpg '" .. url .. "' && "
    .. "cp " .. slug .. "-src.jpg " .. bar_path .. " && sips -Z " .. ART_BAR_PX .. " " .. bar_path .. " >/dev/null 2>&1 && "
    .. "cp " .. slug .. "-src.jpg " .. pop_path .. " && sips -Z " .. ART_POP_PX .. " " .. pop_path .. " >/dev/null 2>&1; "
    .. "rm -f " .. slug .. "-src.jpg; }; }"

  sbar.exec(fetch, function()
    media_cover:set({ background = { image = { string = bar_path, scale = ART_SCALE } } })
    pop_art:set({ background = { image = { string = pop_path, scale = ART_SCALE } } })
  end)
end

-- ─── poll ──────────────────────────────────────────────────────────────────

local function hide()
  if current_track == nil then return end
  current_track = nil
  current_art = nil
  media_cover:set({ drawing = false, popup = { drawing = false } })
  media_artist:set({ drawing = false })
  media_title:set({ drawing = false })
end

local function render(f)
  local playing = (f.state == "playing")
  local position = tonumber(f.position) or 0
  local duration = (tonumber(f.duration) or 0) / 1000  -- Spotify reports ms
  local percent = duration > 0 and math.floor(position / duration * 100) or 0

  media_cover:set({
    drawing = true,
    background = {
      image = {
        border_color = playing and colors.with_alpha(colors.spotify, 0.6)
          or colors.with_alpha(colors.grey, 0.5),
      },
    },
  })
  media_artist:set({ drawing = true, label = { string = f.artist or "" } })
  media_title:set({ drawing = true, label = { string = f.title or "" } })

  pop_title:set({ label = { string = f.title or "" } })
  pop_album:set({ label = { string = f.album or "" } })
  pop_artist:set({ label = { string = f.artist or "" } })

  pop_play:set({ icon = { string = playing and icons.media.pause or icons.media.play } })
  pop_shuffle:set({ icon = { color = f.shuffling == "true" and colors.spotify or colors.grey } })
  pop_loop:set({ icon = { color = f.repeating == "true" and colors.spotify or colors.grey } })

  pop_elapsed:set({ label = { string = fmt_time(position) } })
  pop_remaining:set({ label = { string = "-" .. fmt_time(duration - position) } })
  pop_progress:set({
    slider = { percentage = percent },
    click_script = HELPER .. " seek $PERCENTAGE " .. string.format("%.3f", duration),
  })
  pop_volume:set({ slider = { percentage = tonumber(f.volume) or 0 } })

  if f.track_id then set_artwork(f.track_id, f.art_url) end

  -- Only slide the bar detail out on an actual track change; otherwise every
  -- poll would retrigger the animation.
  if f.track_id ~= current_track then
    current_track = f.track_id
    if playing then
      animate_detail(true)
      interrupt = interrupt + 1
      sbar.delay(5, animate_detail)
    end
  end
end

local function poll()
  sbar.exec(HELPER .. " get", function(result)
    local lines = {}
    for line in string.gmatch(result or "", "[^\r\n]+") do
      lines[#lines + 1] = line
    end

    -- Field order is fixed by helpers/spotify.sh
    local f = {
      state = lines[1], title = lines[2], album = lines[3], artist = lines[4],
      track_id = lines[5], art_url = lines[6], position = lines[7],
      duration = lines[8], shuffling = lines[9], repeating = lines[10],
      volume = lines[11],
    }

    if f.state ~= "playing" and f.state ~= "paused" then
      hide()
      return
    end

    render(f)
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

local function set_popup(open)
  media_cover:set({
    popup = { drawing = open },
    update_freq = open and POLL_OPEN or POLL_IDLE,
  })
  if open then poll() end
end

media_cover:subscribe("mouse.clicked", function(env)
  set_popup(media_cover:query().popup.drawing == "off")
end)

media_title:subscribe("mouse.exited.global", function(env)
  set_popup(false)
end)
