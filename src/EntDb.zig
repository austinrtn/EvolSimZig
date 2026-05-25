const std = @import("std");
const SmartSoa = @import("SmartSoA").SmartSoA;
const SlotQueue = @import("SlotQueue.zig").SlotQueue;

pub fn EntDb(comptime ent_types: []const type) type {
    inline for(ent_types) |T| {
        if(@typeInfo(T) != .@"struct") @compileError(@typeName(T) ++ " must be a struct\n");
        if(!@hasDecl(T, "location")) @compileError(@typeName(T) ++ " must declare `pub const location: []const u8 = \"LocationName\";`\n");
        if(!@hasField(T, "id")) @compileError(@typeName(T) ++ " must contain field `id: u32`\n")
        else if(@FieldType(T, "id") != u32) @compileError(@typeName(T) ++ ": field `id` must be of type u32\n");
        // if(!@hasField(T, "colliding")) @compileError(@typeName(T) ++ " must contain field `colliding: bool`\n")
        // else if(@FieldType(T, "colliding") != bool) @compileError(@typeName(T) ++ ": field `colliding` must be of type bool. \n");
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

    const EntQueue = blk: {
        var names: [ent_types.len][]const u8 = undefined;
        var types: [ent_types.len]type = undefined;
        var attrs: [ent_types.len]std.builtin.Type.StructField.Attributes = undefined;
        
        for(ent_types, &names, &types, &attrs) |ent_type, *name, *t, *attr| {
            name.* = ent_type.location;
            t.* = std.ArrayList(ent_type);
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
        ent_append_queue: EntQueue = undefined,
        ent_remove_queue: EntQueue = undefined,
        len: usize = 0,

        pub fn init(allocator: std.mem.Allocator, ent_capacity: usize) !Self{
            var self: Self = .{.allocator = allocator};
            self.slot_queue = try .init(allocator, ent_capacity);

            inline for(std.meta.fields(EntData), ent_types) |field, ent_type| {
                const field_ptr = &@field(self.ent_data, field.name);
                field_ptr.* = try allocator.create(SmartSoa(ent_type));
                field_ptr.*.* = .init();
            }
            
            inline for(std.meta.fields(EntQueue)) |field| @field(self.ent_append_queue, field.name) = .empty;
            inline for(std.meta.fields(EntQueue)) |field| @field(self.ent_remove_queue, field.name) = .empty;
            
            return self;
        }

        pub fn deinit(self: *Self) void  {
            inline for(std.meta.fields(EntData)) |field| {
                const soa = @field(self.ent_data, field.name);
                soa.deinit(self.allocator);
                self.allocator.destroy(soa);
            }
            
            inline for(std.meta.fields(EntQueue)) |field| @field(self.ent_append_queue, field.name).deinit(self.allocator);
            inline for(std.meta.fields(EntQueue)) |field| @field(self.ent_remove_queue, field.name).deinit(self.allocator);
            self.slot_queue.deinit();
        }
        
        pub fn ensureTotalCapacity(self: *Self, comptime EntType: type, capacity: usize) !void {
            const ent_db = @field(self.ent_data, EntType.location);
            try ent_db.ensureTotalCapacity(self.allocator, capacity);
        }

        pub fn appendEnt(self: *Self, ent: anytype) !void {
            const EntType = @TypeOf(ent);
            try @field(self.ent_append_queue, EntType.location).append(self.allocator, ent);
        }

        pub fn flushAppendQueue(self: *Self) !void {
            inline for(ent_types) |T| {
                const ent_db = self.getEntDb(T);
                const location = getLocationEnumByType(T);
                const queue: *std.ArrayList(T) = &@field(self.ent_append_queue, T.location);
                defer queue.clearRetainingCapacity();

                for(queue.items) |*ent| {
                    const ent_idx: u32 = @intCast(ent_db.len);
                    const new_id = try self.slot_queue.setNextSlot(ent_idx, location);
                    ent.id = new_id;               
                    try ent_db.append(self.allocator, ent.*);
                    self.len += 1;
                }
            }
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

        pub fn getTypeByLocationEnum(comptime ent_location: EntLocation) type {
            inline for(ent_types) |T| {
                if(std.mem.eql(u8, T.location, @tagName(ent_location))) return T;
            }
            unreachable;
        }

        pub fn getLocationEnumByType(comptime EntType: type) EntLocation {
            return std.meta.stringToEnum(EntLocation, EntType.location) orelse unreachable;
        }
    };
}
