-- Tokyo Night
-- `blue` below is the same value ~/.config/borders/bordersrc uses for the
-- focused-window outline, so the bar and the window borders agree. If you
-- retune one, retune the other.
return {
  black = 0xff16161e,
  white = 0xffc0caf5,
  red = 0xfff7768e,
  green = 0xff9ece6a,
  blue = 0xff7aa2f7,
  cyan = 0xff7dcfff,
  yellow = 0xffe0af68,
  orange = 0xffff9e64,
  magenta = 0xffbb9af7,
  grey = 0xff565f89,
  transparent = 0x00000000,

  -- Spotify brand green, used only for the media item's playing state
  spotify = 0xff1db954,

  bar = {
    bg = 0xf01a1b26,
    border = 0xff1a1b26,
  },
  popup = {
    bg = 0xd024283b,
    border = 0xff565f89,
  },
  bg1 = 0xff24283b,
  bg2 = 0xff414868,

  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then return color end
    return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
  end,
}
