const std = @import("std");

pub const ComponentRegistry = struct {
    pub const x = f32;
    pub const y = f32;
    pub const xvel = f32;
    pub const yvel = f32;
    pub const id = u32;
};

pub const Component = blk: {
    const decls = std.meta.declarations(ComponentRegistry);
    var names: [decls.len][]const u8 = undefined;
    var vals: [decls.len]u8 = undefined;

    for(decls, &names, &vals, 0..) |field, *name, *val, i| {
        name.* = field.name;
        val.* = @intCast(i);
    }

    break :blk @Enum(
        u8,
        .exhaustive,
        &names,
        &vals,
    );
};
