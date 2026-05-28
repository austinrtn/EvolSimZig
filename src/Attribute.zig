const std = @import("std");

pub const Decl = struct {
    name: []const u8,
    T: type,
};

pub const Field = struct {
    name: []const u8,
    T: type,
};

pub const Attribute = struct {
    name: []const u8,
    req_decls: []const Decl = &.{},
    req_fields: []const Field = &.{},

    fn eql(attr1: Attribute, attr2: Attribute) bool {
        return(std.mem.eql(u8, attr1.name, attr2.name));
    }
};

pub const Collidable = Attribute{
    .name = "collidable",
    .req_fields = &.{
        .{ .name = "colliding", .T = bool },
    },
};

pub const Renderable = Attribute{
    .name = "renderable",
    .req_decls = &.{
        .{.name = "draw", .T = fn(anytype) anyerror!void},
    },
};

pub const Attributes = [_]Attribute {Renderable, Collidable};

pub fn AttributeGenerator(comptime ent_types: []const type, comptime attributes: []const Attribute) type {
    const AttributeEnum = blk: {
        var names: [attributes.len][]const u8 = undefined;
        var vals: [attributes.len]u8 = undefined;

        for(attributes, 0..) |field, i| {
            names[i] = field;
            vals[i] = @intCast(i);
        }

        break :blk @Enum(
            u8,
            .exhaustive,
            &names,
            &vals,
        );
    };

    const CounterHelper = struct { attr: AttributeEnum, types: [ent_types.len]type = undefined, count: usize = 0 };
    const AttributeCounter = blk: {
        var helpers: [attributes.len]CounterHelper = undefined;

        for(attributes, &helpers) |attr, *helper| helper.attr = attr;

        for(&helpers) |*helper| {
            for(ent_types) |EntT| {
                for(EntT.Attributes) |ent_attr| {
                    if(Attribute.eql(helper.attr, ent_attr)) {
                        helper.types[helper.count] = EntT;
                        helper.count += 1;
                    }
                }
            }
        }

        break :blk helpers;
    };

    const AttributeGroups = blk: {
    };
}

pub const EntGroupContainer = blk: {
    var names: [Attributes.len][]const u8 = undefined;
    var types: [Attributes.len]type = undefined;
    var attrs: [Attributes.len]std.builtin.Type.StructField.Attributes = undefined;

    for(Attributes, names, types, attrs) |Attr, *name, *T, *attr| {
        name.* = Attr.name;
        T.* = []const type;
        attr.* = .{};
    }

    break :blk @Struct(
        .auto,
        null,
        &names,
        &types,
        &attrs,
    );
};

pub fn EntGroups(ent_types: []const type) type {
    var container: EntGroupContainer = undefined;
    inline for(ent_types) |T| {
        var attr_types: [ent_types.len]type = undefined;
        inline for(T.Attributes) |Attr| {
            const field = @field(container, @tagName(Attr));

        }
    }
}

// pub fn System(comptime attributes: []const Attribute) type {
//     return struct {

//     };
// }
