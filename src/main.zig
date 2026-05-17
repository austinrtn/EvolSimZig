const std = @import("std");
const ZigGrid = @import("ZigGridLib").ZigGridLib(.{}).SpacialGrid;
const raylib = @import("raylib");
const SmartSoa = @import("SmartSoA").SmartSoA;
const lua = @import("lua");

const Config = @import("config.zig").Config;
const Spec = @import("Spec.zig").Spec;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    
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

    var specs = SmartSoa(Spec).init();
    defer specs.deinit(allocator);
    
    _ = try specs.append(allocator, .{
       .x = 25,  
       .y = 25,
       .xvel = 4,
       .yvel = 4, 
       .color = .red,
       .r = 32,
    });
    
    while(!raylib.windowShouldClose()) {
        raylib.clearBackground(.ray_white);

        raylib.beginDrawing();
        defer raylib.endDrawing();

        Spec.move(&specs, raylib.getFrameTime());
        Spec.draw(&specs);

        raylib.drawText("Hello world!", 500, 500, 12, .black);
    }
}

fn initRaylib(config: Config) void {
    raylib.initWindow(config.window_width, config.window_height, "");

    raylib.setTraceLogLevel(.none);
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
                .bool => lua.lua_toboolean(L, -1),
                else => {},
            };
        }
        
        lua.lua_pop(L, 1);
        @field(config, field.name) = val;
    }

    return L;
}
