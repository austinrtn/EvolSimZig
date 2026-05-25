const std = @import("std");
const GameState = @import("GameState.zig").GameStateT;
const raylib = @import("raylib");

pub const FpsBox = struct {
    const Self = @This();
    pub const location = "boxes";
    pub const renderable = true;
    pub const render_layer = 100;
    
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 25,
    h: f32 = 25,
    id: u32 = 1_000_000,
    font: raylib.Font = undefined,
    
    box_color: raylib.Color = .white,
    outline_color: raylib.Color = .black,

    font_size: f32 = 16,
    font_color: raylib.Color = .black,

    pub fn init(state: *GameState) !Self {
        var self: Self = .{};
        self.font = try raylib.getFontDefault();
        try state.db.queueEntForSpawn(self);
        return self;
    }

    pub fn draw(state: *GameState) void {
        const db = state.db.getEntDb(Self);
        if(db.len == 0) return;
        if(!state.config.show_fps) return;
        
        const self: Self = db.get(0);
        const rect: raylib.Rectangle = .{.x = self.x, .y = self.y, .width = self.w, .height = self.h};
        
        raylib.drawRectangleRec(rect, self.box_color);
        raylib.drawRectangleLinesEx(rect, 1, self.outline_color);

        var buf: [256]u8 = undefined;
        const fps_text = std.fmt.bufPrintSentinel(&buf, "{d}", .{state.fps}, 0) catch unreachable;
        const text_size = raylib.measureTextEx(self.font, fps_text, self.font_size, 1);

        const text_x = self.x + (self.w - text_size.x) * 0.5;
        const text_y = self.y + (self.h - text_size.y) * 0.5;

        raylib.drawTextEx(self.font, fps_text, .{.x = text_x, .y = text_y}, self.font_size, 1, .black);
    }
};
