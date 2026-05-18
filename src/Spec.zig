const std = @import("std");
const raylib = @import("raylib");
const SpecSoa = @import("SmartSoA").SmartSoA(Spec);
const lua = @import("lua");
const Config = @import("config.zig").Config;

pub const Spec = struct {
    const colors = [_]raylib.Color{.black, .red, .pink, .blue, .green, .purple,};

    x: f32,
    y: f32,
    r: f32,

    xvel: f32,
    yvel: f32,
    color: raylib.Color,

    pub fn move(specs: *SpecSoa, ft: f32) void {
        const s = specs.manyItems(&.{.x, .y, .xvel, .yvel});
        for(s.x, s.y, s.xvel, s.yvel) |*x, *y, xvel, yvel| {
            x.* += (xvel * ft);
            y.* += (yvel * ft);
        }
    }

    pub fn draw(specs: *SpecSoa) void {
        const s = specs.allItems();
        for(s.x, s.y, s.r, s.color) |x, y, r, color| {
            raylib.drawCircleV(raylib.Vector2.init(x, y), r, color);
        }
    }

    pub fn insert(specs: *SpecSoa, grid: anytype) !void {
        _ = specs; _ = grid;
    }

    pub fn spawn(allocator: std.mem.Allocator, io: std.Io, specs: *SpecSoa, config: Config) !void {
        try specs.ensureTotalCapacity(allocator, config.ent_count);
        const rand = std.Random.IoSource{.io = io};
        const rng = rand.interface();

        for(0..config.ent_count) |_| {
            const x = config.min_x + rng.float(f32) * (config.max_x - config.min_x);
            const y = config.min_y + rng.float(f32) * (config.max_y - config.min_y);
            const r = config.min_r + rng.float(f32) * (config.max_r - config.min_r);

            var xvel = config.min_vel + rng.float(f32) * (config.max_vel - config.min_vel);
            var yvel = config.min_vel + rng.float(f32) * (config.max_vel - config.min_vel);
            if(rng.intRangeAtMost(usize, 0, 1) == 1) xvel *= -1;
            if(rng.intRangeAtMost(usize, 0, 1) == 1) yvel *= -1;
            const color = colors[rng.intRangeAtMost(usize, 0, colors.len - 1)];

            const spec: Spec = .{
                .x = x,
                .y = y,
                .r = r,
                .xvel = xvel,
                .yvel = yvel,
                .color = color
            };

            try specs.append(allocator, spec);
        }
    }
};
