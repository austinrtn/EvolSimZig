const std = @import("std");
const ZigGrid = @import("ZigGridLib").ZigGridLib(.{}).SpacialGrid;
const raylib = @import("raylib");
const SmartSoa = @import("SmartSoA").SmartSoA;
const lua = @import("lua");

const Config = @import("config.zig").Config;
const Spec = @import("Spec.zig").Spec;
const EntDbType = @import("EntDb.zig").EntDb;
const EntDb = EntDbType(&.{
    Spec
});

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    const fps_box: FpsBox = .{};
    var config: Config = undefined;
    const L = try initLua(&config);
    defer lua.lua_close(L);

    var grid = try ZigGrid.init(.{
        .allocator = allocator,
        .io = io,
        .width = @floatFromInt(config.window_width),
        .height = @floatFromInt(config.window_height),
        .multi_threaded = true,
        .cell_size_multiplier = 2,
    });
    defer grid.deinit();

    initRaylib(config);
    defer raylib.closeWindow();

    var db = try EntDb.init(allocator, config.ent_count);
    defer db.deinit();
    const specs: *SmartSoa(Spec) = db.ent_data.specs;

    try Spec.spawn(allocator, io, &db, config);
    try Spec.insert(specs, grid);

    try grid.updateCellSize(null);
    //loop
    while(!raylib.windowShouldClose()) {
        raylib.beginDrawing();
        defer raylib.endDrawing();

        raylib.clearBackground(.ray_white);
        const dt = raylib.getFrameTime();
        const fps = raylib.getFPS();

        Spec.reset(specs);
        Spec.move(specs, dt);
        try Spec.insert(specs, grid);
        const results = try grid.update();
        
        for(results.items) |pair| {
            inline for(std.meta.fields(@TypeOf(pair))) |field| {
                const id = @field(pair, field.name); 
                if(@TypeOf(id) == u32) {
                    switch (try db.getEntLocation(id)) {
                        inline else => |loc| {
                            const T = EntDb.getTypeByLocation(loc);
                            var ent = try db.getEnt(T, id);
                            ent.colliding = true;
                            try db.setEnt(ent);
                        }
                    }
                }
            }
        }

        Spec.draw(specs);
        if(config.show_fps) fps_box.draw(fps);
        try controller(config, .{.db = &db});
    }
}

fn controller(config: Config, data: anytype) !void {
    _ = config; 
    switch(raylib.getKeyPressed()) {
        .r => {
            try data.db.removeEnt(@as(u32, @intCast(data.db.len)) - 1);
        },
        else => {},
    }
}

fn initRaylib(config: Config) void {
    raylib.initWindow(config.window_width, config.window_height, "");

    raylib.setTraceLogLevel(.err);
    raylib.setTargetFPS(config.target_fps);
}

fn initLua(config: *Config) !*lua.struct_lua_State {
    const L = lua.luaL_newstate() orelse return error.LuaInitFailed;

    lua.luaL_openlibs(L);
    if(lua.luaL_loadfile(L, "src/config.lua") != lua.LUA_OK) {
        lua.lua_close(L);
        return error.FailedLoadingLuaFile;
    }

    if(lua.lua_pcall(L, 0, 1, 0) != lua.LUA_OK) {
        lua.lua_close(L);
        return error.FailedLuaPcall;
    }

    inline for(std.meta.fields(Config)) |field| {
        _ = lua.lua_getfield(L, -1, field.name);
        const T = @FieldType(Config, field.name);

        var val: T = undefined;
        if(T == []const u8) val = lua.lua_tostring(L, -1)
        else {
            val = switch(@typeInfo(T)) {
                .int => @intCast(lua.lua_tointeger(L, -1)),
                .float => @floatCast(lua.lua_tonumber(L, -1)),
                .bool => blk: {
                        if(lua.lua_toboolean(L, -1) == 0) break :blk false
                        else break :blk true;
                },
                else => {},
            };
        }

        lua.lua_pop(L, 1);
        @field(config, field.name) = val;
    }

    return L;
}

const FpsBox = struct {
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 25,
    h: f32 = 25,
    box_color: raylib.Color = .white,
    outline_color: raylib.Color = .black,

    font_size: f32 = 16,
    font_color: raylib.Color = .black,

    fn draw(self: @This(), fps: i32) void {
        const rect: raylib.Rectangle = .{.x = self.x, .y = self.y, .width = self.w, .height = self.h};
        raylib.drawRectangleRec(rect, self.box_color);
        raylib.drawRectangleLinesEx(rect, 1, self.outline_color);

        const font = raylib.getFontDefault() catch unreachable;
        var buf: [256]u8 = undefined;
        const fps_text = std.fmt.bufPrintSentinel(&buf, "{d}", .{fps}, 0) catch unreachable;
        const text_size = raylib.measureTextEx(font, fps_text, self.font_size, 1);

        const text_x = self.x + (self.w - text_size.x) * 0.5;
        const text_y = self.y + (self.h - text_size.y) * 0.5;

        raylib.drawTextEx(font, fps_text, .{.x = text_x, .y = text_y}, self.font_size, 1, .black);
    }
};
