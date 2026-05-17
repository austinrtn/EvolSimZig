const std = @import("std");
const raylib = @import("raylib");
const SpecSoa = @import("SmartSoA").SmartSoA(Spec);

pub const Spec = struct {
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
        const s = specs.manyItems(&.{.x, .y, .r, .color});
        for(s.x, s.y, s.r, s.color) |x, y, r, color| 
            raylib.drawCircleV(raylib.Vector2.init(x, y), r, color);
    }
};
