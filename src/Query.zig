const std = @import("std");
const EntityMod = @import("Entity.zig");
const FieldsT = EntityMod.GenerateFieldsFromComponents;
const EntDb = @import("EntDb.zig").EntDb;

const ComponentMod = @import("Component.zig");
const Component = @import("Component.zig").Component;

pub fn Query(comptime ent_types: []const type, comptime components: []const Component) type {
    const MatchingEnts = blk: {
        var matching: [ent_types.len]type = undefined;
        var count: usize = 0;

        for(ent_types) |EntT| {
            var type_matches = true;
            for(components) |comp| {
                if(std.mem.findScalar(Component, EntT.Components, comp) == null) {
                    type_matches = false;
                    break;
                }
            }

            if(type_matches) {
                matching[count] = EntT;
                count += 1;
            }
        }
        break :blk matching[0..count].*;
    };

    const Fields = FieldsT(components, true);

    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        ent_db: *EntDb(ent_types),

        query_idx: usize = 0,

        pub fn init(allocator: std.mem.Allocator, ent_db: *EntDb(ent_types)) Self {
            return .{.allocator = allocator, .ent_db = ent_db};
        }

        pub fn query(self: *Self) ?Fields {
            if(self.query_idx == MatchingEnts.len) return null;

            const T = MatchingEnts[self.query_idx];
            const db = self.ent_db.getEntDb(T);

            const fields: Fields = undefined;
            inline for(std.meta.fields(fields)) |field| {
                @field(fields, field.name) = db.items(std.meta.stringToEnum(comptime T: type, str: []const u8))
            }
        }

        pub fn reset(self: Self) void {
            self.query_idx = 0;
        }
    };
}
