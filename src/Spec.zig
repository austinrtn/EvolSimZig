const std = @import("std");
const raylib = @import("raylib");
const GameState = @import("GameState.zig").GameStateT;
const SpecSoa = @import("SmartSoA").SmartSoA(Spec);
const Config = @import("config.zig").Config;
const EntDb = @import("EntDb.zig").EntDb;

pub const Spec = struct {
    const Self = @This();
    pub const location = "specs";
    pub const collidable = true;
    pub const renderable = true;
    pub const render_layer = 1;
    
    pub const shape: GameState.Grid.ShapeType = .Circle;
    const colors = [_]raylib.Color{.black, .red, .pink, .blue, .green, .purple,};

    x: f32,
    y: f32,
    r: f32,
    id: u32,

    xvel: f32,
    yvel: f32,
    color: raylib.Color,
    colliding: bool = false,

    pub fn reset(state: *GameState) void {
        const specs_db = state.db.getEntDb(Self);
        const s = specs_db.items(.colliding);
        
        for(s) |*colliding| colliding.* = false;
    }

    pub fn move(state: *GameState) void {
        const specs = state.db.getEntDb(Self);
        const s = specs.manyItems(&.{.x, .y, .xvel, .yvel});
        for(s.x, s.y, s.xvel, s.yvel) |*x, *y, xvel, yvel| {
            x.* += (xvel * @as(@TypeOf(x.*), state.dt));
            y.* += (yvel * @as(@TypeOf(y.*), state.dt));
        }
    }

    pub fn draw(state: *GameState) void {
        const specs = state.db.getEntDb(Self);
        const s = specs.allItems();
        for(s.x, s.y, s.r, s.color, s.colliding) |x, y, r, color, c| {
            if(c) raylib.drawCircleV(raylib.Vector2.init(x, y), r, color)
            else raylib.drawCircleV(raylib.Vector2.init(x, y), r, raylib.Color.gray);
        }
    }

    pub fn spawn(state: *GameState) !void {
        const db = &state.db;
        
        for(0..state.config.ent_count) |_| {
            const spec = getRandom(state);
            try db.appendEnt(spec);
        }
        
        try db.flushAppendQueue();
    }

    pub fn getRandom(state: *GameState) Self {
        const config = state.config;
        const rand = std.Random.IoSource{.io = state.io};
        const rng = rand.interface();
        
        const x = config.min_x + rng.float(f32) * (config.max_x - config.min_x);
        const y = config.min_y + rng.float(f32) * (config.max_y - config.min_y);
        const r = config.min_r + rng.float(f32) * (config.max_r - config.min_r);

        var xvel = config.min_vel + rng.float(f32) * (config.max_vel - config.min_vel);
        var yvel = config.min_vel + rng.float(f32) * (config.max_vel - config.min_vel);
        if(rng.intRangeAtMost(usize, 0, 1) == 1) xvel *= -1;
        if(rng.intRangeAtMost(usize, 0, 1) == 1) yvel *= -1;
        const color = colors[rng.intRangeAtMost(usize, 0, colors.len - 1)];

        return .{
            .x = x,
            .y = y,
            .r = r,
            .xvel = xvel,
            .yvel = yvel,
            .color = color,
            .id = 0,
        };
    }

    pub fn insert(state: *GameState) !void {
        const specs = state.db.getEntDb(@This());
        const s = specs.allItems();
        try state.grid.insert.Circle.many(s.id, s.x, s.y, s.r);
    }
};
