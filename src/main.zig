const std = @import("std");

const ZigGrid = @import("ZigGridLib").ZigGridLib(.{});
const Raylib = @import("raylib");
const SmartSoa = @import("SmartSoA").SmartSoA;
const lua = @import("lua");

pub fn main(init: std.process.Init) !void {
    _ = init;
    _ = ZigGrid;
    _ = SmartSoa;

    const lua_state = lua.luaL_newstate() orelse return error.LuaInitFailed;
    defer lua.lua_close(lua_state);

    lua.luaL_openlibs(lua_state);

    if (lua.luaL_loadstring(lua_state, "message = 'hello from lua'") != lua.LUA_OK) {
        var len: usize = 0;
        const err = lua.lua_tolstring(lua_state, -1, &len);
        std.debug.print("lua load error: {s}\n", .{err});
        return error.LuaLoadFailed;
    }

    if (lua.lua_pcall(lua_state, 0, lua.LUA_MULTRET, 0) != lua.LUA_OK) {
        var len: usize = 0;
        const err = lua.lua_tolstring(lua_state, -1, &len);
        std.debug.print("lua runtime error: {s}\n", .{err});
        return error.LuaRuntimeFailed;
    }

    Raylib.initWindow(800, 800, "");
    defer Raylib.closeWindow();

    Raylib.setTargetFPS(60);

    while(!Raylib.windowShouldClose()) {
        Raylib.clearBackground(.ray_white);

        Raylib.beginDrawing();
        defer Raylib.endDrawing();

        Raylib.drawText("Hello world!", 500, 500, 12, .black);
    }
}
