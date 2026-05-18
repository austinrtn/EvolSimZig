local pad = 0

local config = {
    window_width = 800,
    window_height = 800,
    target_fps = 60,

    ent_count = 1000,

    min_r = 4,
    max_r = 12,

    min_vel = 8,
    max_vel=  12,
}

config.min_x = -pad
config.min_y = -pad
config.max_x = config.window_width + pad
config.max_y = config.window_height + pad

return config
