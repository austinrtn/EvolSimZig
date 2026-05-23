const std = @import("std");
const SmartSoa = @import("SmartSoA").SmartSoA;
const SlotQueue = @import("SlotQueue.zig").SlotQueue;

pub const EntDesc = struct {
    name: []const u8,
    T: type,
};

pub fn EntDb(comptime ent_descs: []const EntDesc) type {
    const EntLoc = blk: {
        var names: [ent_descs.len][]const u8 = undefined;
        var values: [ent_descs.len]u8 = undefined;

        for(ent_descs, &names, &values, 0..) |desc, *name, *value, i| {
            name.* = desc.name;
            value.* = @intCast(i);
        }

        break :blk @Enum(u8, .exhaustive, &names, &values);
    };

    const EntData = blk: {
        var names: [ent_descs.len][]const u8 = undefined;
        var types: [ent_descs.len]type = undefined;
        var attrs: [ent_descs.len]std.builtin.Type.StructField.Attributes = undefined;

        for(ent_descs, &names, &types, &attrs) |desc, *name, *t, *attr| {
            name.* = desc.name;
            t.* = *SmartSoa(desc.T);
            attr.* = .{};
        }

        break :blk @Struct(
            .auto,
            null,
            &names,
            &types,
            &attrs
        );
    };

    return struct {
        const Self = @This();
        pub const EntLocation = EntLoc;

        slot_queue: SlotQueue(EntLocation) = undefined,
        allocator: std.mem.Allocator,
        ent_data: EntData = undefined,
        len: usize = 0,

        pub fn init(allocator: std.mem.Allocator, ent_capacity: usize) !Self{
            var self: Self = .{.allocator = allocator};
            self.slot_queue = try .init(allocator, ent_capacity);

            inline for(std.meta.fields(EntData), ent_descs) |field, desc| {
                const field_ptr = &@field(self.ent_data, field.name);
                field_ptr.* = try allocator.create(SmartSoa(desc.T));
                field_ptr.*.* = .init();
            }
            return self;
        }

        pub fn deinit(self: *Self) void  {
            inline for(std.meta.fields(EntData)) |field| {
                const soa = @field(self.ent_data, field.name);
                soa.deinit(self.allocator);
                self.allocator.destroy(soa);
            }
            self.slot_queue.deinit();
        }

        pub fn append(self: *Self, ent_idx: u32, comptime ent_location: EntLocation, ent: anytype) !void {
            const ent_db = @field(self.ent_data, @tagName(ent_location));
            var ent_cpy = ent;
            ent_cpy.id = try self.slot_queue.setNextSlot(ent_idx, ent_location);

            try ent_db.append(self.allocator, ent_cpy);
            self.len += 1;
        }

        pub fn ensureTotalCapacity(self: *Self, comptime ent_type: EntLocation, capacity: usize) !void {
            try self.ent_data.ents.ensureTotalCapacity(self.allocator, capacity);
            const ent_db = @field(self.ent_data, @tagName(ent_type));
            try ent_db.ensureTotalCapacity(self.allocator, capacity);
        }

        pub fn removeEnt(self: *Self, id: u32) !void {
            const removed_slot = try self.slot_queue.sendSlotToQueue(id);

            // Go through each ent desc until ent_data field matches slot's ent location
            inline for(ent_descs) |desc| {
                const location_name = @tagName(removed_slot.ent_location);
                if(std.mem.eql(u8, desc.name, location_name)) {
                    const db = &@field(self.ent_data, desc.name);
                    const swapped_ent_idx: ?u32 = db.swapAndPopIdx(removed_slot.ent_idx);

                    if(swapped_ent_idx) |new_ent_idx| {
                        const ent = db.get(id);
                        const slot_of_swapped_ent = try self.slot_queue.getSlot(ent.id);
                        slot_of_swapped_ent.ent_idx = new_ent_idx;
                    }
                }
            }
        }

        pub fn getSubId(self: *Self, id: u32) u32 {
            return self.ent_data.ents[id].index;
        }
    };
}
