pub const Config = struct {
    window_width: i32,
    window_height: i32,
    window_monitor: i32,
    target_fps: i32,

    ent_count: usize,
    min_x: f32,
    max_x: f32,

    min_y: f32,
    max_y: f32,

    min_r: f32,
    max_r: f32,

    min_vel: f32,
    max_vel: f32,
    show_fps: bool,
};
