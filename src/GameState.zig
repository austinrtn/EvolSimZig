const std = @import("std");
const raylib = @import("raylib");
const lua = @import("lua");

const ZigGridLib = @import("ZigGridLib");
const SmartSoa = @import("SmartSoA").SmartSoA;
const Config = @import("config.zig").Config;
const EntDbType = @import("EntDb.zig").EntDb;

const Ent_Types = [_]type {
    @import("Spec.zig").Spec,
    @import("Food.zig").Food,
    @import("FpsBox.zig").FpsBox,
};

pub const GameStateT = GameState(
    .{},
    &Ent_Types,
);

pub fn GameState(
    comptime GridConfig: ZigGridLib.SetupConfig,
    comptime EntTypes: []const type,
) type {
    const collidables = getDeclTypes(EntTypes, "collidable", bool);
    const renderables_unsorted = getDeclTypes(EntTypes, "renderable", bool);
    inline for(renderables_unsorted) |T| {
        if(!@hasDecl(T, "draw")) @compileError(@typeName(T) ++ " must contain function `draw(state: *GameState)`\n");
        if(!@hasDecl(T, "render_layer")) @compileError(@typeName(T) ++ " must contain field `render_layer` of type int\n");
    }

    const renderables = comptime blk: {
        var sorted = renderables_unsorted;

        std.mem.sort(type, &sorted, {}, struct {
            fn lessThan(_: void, lhs:type, rhs: type) bool {
                return @field(lhs, "render_layer") < @field(rhs, "render_layer");
            }
        }.lessThan);
        break :blk sorted;
    };

    return struct {
        const Self = @This();

        pub const Ents = EntTypes;
        pub const Grid = ZigGridLib.ZigGridLib(GridConfig);
        pub const EntDb = EntDbType(EntTypes);
        pub const Collidables = collidables;
        pub const Renderables = renderables;

        allocator: std.mem.Allocator,
        io: std.Io,
        config: Config = undefined,
        L: *lua.struct_lua_State = undefined,
        db: EntDb = undefined,
        grid: *Grid.SpacialGrid = undefined,
        dt: f32 = 0,
        fps: i32 = 0,

        pub fn init(allocator: std.mem.Allocator, io: std.Io) !*Self {
            var self: Self = .{ .allocator = allocator, .io = io };
            self.L = try initLua(&self.config);

            self.db = try EntDb.init(allocator, self.config.ent_count);
            self.grid = try .init(.{
                .allocator = allocator,
                .io = io,
                .width = @floatFromInt(self.config.window_width),
                .height = @floatFromInt(self.config.window_height),
                .multi_threaded = true,
                .cell_size_multiplier = 2,
            });

            const self_ptr = try allocator.create(Self);
            self_ptr.* = self;
            return self_ptr;
        }

        pub fn deinit(self: *Self) void {
            const allocator = self.allocator;
            lua.lua_close(self.L);

            self.db.deinit();
            self.grid.deinit();
            allocator.destroy(self);
        }

        pub fn update(self: *Self) void {
            self.dt = raylib.getFrameTime();
            self.fps = raylib.getFPS();
        }

        pub fn insertAll(self: *Self) !void {
            const db = &self.db;
            const grid = self.grid;

            inline for(collidables) |EntT| {
                switch(EntT.shape) {
                    .Circle => {
                        const ents = db.getEntDb(EntT);
                        const s = ents.allItems();
                        try grid.insert.Circle.many(s.id, s.x, s.y, s.r);
                    },
                    .Rect => {
                        const ents = db.getEntDb(EntT);
                        const s = ents.allItems();
                        try grid.insert.Circle.many(s.id, s.x, s.y, s.w, s.h);
                    },
                    .Point => {
                        const ents = db.getEntDb(EntT);
                        const s = ents.allItems();
                        try grid.insert.Circle.many(s.id, s.x, s.y);
                    },
                }
            }
        }

        pub fn drawAll(self: *Self) !void {
            inline for(renderables) |T| try T.draw(self);
        }
    };
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

fn getDeclCount(comptime ent_types: []const type, comptime decl: []const u8) usize {
    var i: usize = 0;
    for(ent_types) |T| { if(@hasDecl(T, decl)) i += 1; }
    return i;
}

fn getDeclTypes(comptime ent_types: []const type, comptime decl: []const u8, comptime decl_type: type)
    [getDeclCount(ent_types, decl)]type {

    const count = getDeclCount(ent_types, decl);
    var col_ents: [count]type = undefined;
    var i: usize = 0;
    for(ent_types) |T| {
        if(@hasDecl(T, decl)) {
            const field = @field(T, decl);
            if(@TypeOf(field) != decl_type) @compileError(@typeName(T) ++ ": field `" ++ decl ++ "` must be of type " ++ @typeName(decl_type) ++ "\n");
            if(field == true) {
                col_ents[i] = T;
                i += 1;
            }
        }
    }

    return col_ents;
}
