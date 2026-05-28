local pad = 50;

local config = {
    window_width = 800,
    window_height = 800,
    window_monitor = 0,
    target_fps = 60,

    ent_count = 1,

    min_r = 26,
    max_r = 32,

    min_vel = 8,
    max_vel =  12,
    show_fps = true,
}

config.min_x = -pad
config.min_y = -pad
config.max_x = config.window_width + pad
config.max_y = config.window_height + pad

return config
