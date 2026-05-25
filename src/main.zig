const std = @import("std");
const GameState = @import("GameState.zig").GameStateT;
const ZigGridLib = @import("ZigGridLib").ZigGridLib(.{});
const ZigGrid = ZigGridLib.SpacialGrid;
const raylib = @import("raylib");
const SmartSoa = @import("SmartSoA").SmartSoA;
const lua = @import("lua");

const Config = @import("config.zig").Config;
const Spec = @import("Spec.zig").Spec;
const Food = @import("Food.zig").Food;
const FpsBox = @import("FpsBox.zig").FpsBox;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    
    const state: *GameState = try .init(allocator, io);
    defer state.deinit();

    const config = state.config;
    const grid = state.grid;

    initRaylib(config);
    defer raylib.closeWindow();
    
    _ = try FpsBox.init(state);

    const spec: Spec = .{
        .x = 100,
        .y = 100,
        .r = 5,
    };
    try state.db.spawnEnt(spec);
    try state.insertAll();

    try grid.updateCellSize(null);
    //loop
    while(!raylib.windowShouldClose()) {
        raylib.beginDrawing();
        defer raylib.endDrawing();

        raylib.clearBackground(.ray_white);
        state.update();

        Spec.reset(state);
        Spec.move(state);
        try state.insertAll();
        
        const results = try grid.update();
        for(results.items) |pair| {
            for([_]u32{pair.a, pair.b}) |id| {
                inline for(GameState.Collidables) |T| {
                    var ent = try state.db.getEnt(T, id);
                    ent.colliding = true;
                    try state.db.setEnt(ent);
                }
            }
        }

        state.drawAll();
        try state.db.flushAll();
        try controller(state);
    }
}

fn controller(state: *GameState) !void {
    const db = &state.db;
    switch(raylib.getKeyPressed()) {
        .r => {
            try db.deleteEnt(db.ent_data.specs.get(0));
        },
        .t => {
            const spec: Spec = .getRandom(state);
            try db.queueEntForSpawn(spec);
        },
        else => {},
    }
}

fn initRaylib(config: Config) void {
    raylib.initWindow(config.window_width, config.window_height, "");
    
    const monitor_count = raylib.getMonitorCount();
    if (config.window_monitor < 0 or config.window_monitor >= monitor_count) return;

    raylib.setWindowMonitor(config.window_monitor);

    const monitor_pos = raylib.getMonitorPosition(config.window_monitor);
    const monitor_width = raylib.getMonitorWidth(config.window_monitor);
    const monitor_height = raylib.getMonitorHeight(config.window_monitor);

    const x = @as(i32, @intFromFloat(monitor_pos.x)) + @divTrunc(monitor_width - config.window_width, 2);
    const y = @as(i32, @intFromFloat(monitor_pos.y)) + @divTrunc(monitor_height - config.window_height, 2);
    raylib.setWindowPosition(x, y);

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
