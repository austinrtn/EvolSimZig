const std = @import("std");
const SmartSoa = @import("SmartSoA").SmartSoA;
const SlotQueue = @import("SlotQueue.zig").SlotQueue;

pub fn EntDb(comptime ent_types: []const type) type {
    inline for(ent_types) |T| {
        if(@typeInfo(T) != .@"struct") @compileError(@typeName(T) ++ " must be a struct\n");
        if(!@hasDecl(T, "location")) @compileError(@typeName(T) ++ " must declare `pub const location: \"LocationName\" = \n");
    }
    
    const EntLoc = blk: {
        var names: [ent_types.len][]const u8 = undefined;
        var values: [ent_types.len]u8 = undefined;

        for(ent_types, &names, &values, 0..) |ent_type, *name, *value, i| {
            name.* = ent_type.location;
            value.* = @intCast(i);
        }

        break :blk @Enum(u8, .exhaustive, &names, &values);
    };

    const EntData = blk: {
        var names: [ent_types.len][]const u8 = undefined;
        var types: [ent_types.len]type = undefined;
        var attrs: [ent_types.len]std.builtin.Type.StructField.Attributes = undefined;

        for(ent_types, &names, &types, &attrs) |ent_type, *name, *t, *attr| {
            name.* = ent_type.location;
            t.* = *SmartSoa(ent_type);
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

            inline for(std.meta.fields(EntData), ent_types) |field, ent_type| {
                const field_ptr = &@field(self.ent_data, field.name);
                field_ptr.* = try allocator.create(SmartSoa(ent_type));
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

        pub fn append(self: *Self, ent_idx: u32, comptime EntType: type, ent: anytype) !void {
            const ent_location = getLocationByType(EntType);
            const ent_db = @field(self.ent_data, EntType.location);
            var ent_cpy = ent;
            ent_cpy.id = try self.slot_queue.setNextSlot(ent_idx, ent_location);

            try ent_db.append(self.allocator, ent_cpy);
            self.len += 1;
        }

        pub fn ensureTotalCapacity(self: *Self, comptime EntType: type, capacity: usize) !void {
            const ent_db = @field(self.ent_data, EntType.location);
            try ent_db.ensureTotalCapacity(self.allocator, capacity);
        }

        pub fn removeEnt(self: *Self, id: u32) !void {
            const removed_slot = try self.slot_queue.sendSlotToQueue(id);
            switch(removed_slot.ent_location) {
                inline else => |loc| {
                    const db = @field(self.ent_data, @tagName(loc));
                    const removed_idx: usize = removed_slot.ent_idx;
                    const last_idx = db.len - 1;
                    const swapped_ent = if (removed_idx != last_idx) db.get(last_idx) else null;

                    _ = db.swapAndPopIdx(removed_idx);
                    if(swapped_ent) |ent| {
                        const slot_of_swapped_ent = try self.slot_queue.getSlot(ent.id);
                        slot_of_swapped_ent.ent_idx = @intCast(removed_idx);
                    }

                    self.len -= 1;
                }
            }
        }

        pub fn getEntLocation(self: *Self, id: u32) !EntLocation {
            const slot = try self.slot_queue.getSlot(id);
            return slot.ent_location;
        }

        pub fn getEnt(self: *Self, comptime EntType: type, id: u32) !EntType {
            const db = self.getEntDb(EntType);
            const ent_idx = try self.slot_queue.getSlotEntIdx(id);
            const ent = db.get(ent_idx);
            return ent;
        }

        pub fn setEnt(self: *Self, ent: anytype) !void {
            const EntType = @TypeOf(ent);
            const db = self.getEntDb(EntType);
            const ent_idx = try self.slot_queue.getSlotEntIdx(ent.id);
            db.set(ent, ent_idx);
        }

        pub fn getEntDb(self: *Self, comptime EntType: type) *SmartSoa(EntType) {
            const db = @field(self.ent_data, EntType.location);
            return db;
        }

        pub fn getEntIdx(self: *Self, id: u32) !u32 {
            return try self.slot_queue.getSlotEntIdx(id);
        }

        pub fn getTypeByLocation(comptime ent_location: EntLocation) type {
            inline for(ent_types) |T| {
                if(std.mem.eql(u8, T.location, @tagName(ent_location))) return T;
            }
            unreachable;
        }

        pub fn getLocationByType(comptime EntType: type) EntLocation {
            return std.meta.stringToEnum(EntLocation, EntType.location) orelse unreachable;
        }
    };
}
