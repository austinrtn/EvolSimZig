const std = @import("std");
const raylib = @import("raylib");
const GameState = @import("GameState.zig").GameStateT;

const FoodSoa = @import("SmartSoA").SmartSoA(Food);
const Config = @import("config.zig").Config;
const EntDb = @import("EntDb.zig").EntDb;

pub const Food = struct {
    const Self = @This();
    pub const location = "foods";
    pub const renderable = true;
    pub const render_layer = 0;
    pub const colliding = true;

    x: f32,
    y: f32,
    r: f32,
    color: raylib.Color = .red,
    id: u32 = undefined,

    pub fn init(x: f32, y: f32, r: f32) Food{
        return .{.x = x, .y = y, .r = r};
    }

    pub fn draw(state: *GameState) !void {
        const foods = state.db.getEntDb(Self);
        const fields = foods.allItems();
        for(fields.x, fields.y, fields.r, fields.color) |x, y, r, color|
            raylib.drawCircleV(.{.x = x, .y = y }, r, color);
    }
};
