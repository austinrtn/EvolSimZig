const std = @import("std");
const SmartSoa = @import("SmartSoA").SmartSoA;
const SlotQ = @import("SlotQueue.zig").SlotQueue;

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

    const SpawnEntQueue = getEntQueue(ent_types, false);
    const RemoveEntQueue = getEntQueue(ent_types, true);

    return struct {
        const Self = @This();
        const SlotQueue = SlotQ(EntLocation);
        pub const EntLocation = EntLoc;
        
        slot_queue: SlotQueue = undefined,
        allocator: std.mem.Allocator,
        ent_data: EntData = undefined,
        ent_append_queue: SpawnEntQueue = undefined,
        ent_remove_queue: RemoveEntQueue = undefined,
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

        ///Directly adds entity to EntDb.  Can cause pointer invalidation and infinite loops 
        /// if called while iterating through entities.
        pub fn spawnEnt(self: *Self, ent: anytype) !void {
            const EntType = @TypeOf(ent);
            const ent_db = self.getEntDb(@TypeOf(ent));
            const location = getLocationEnumByType(EntType);

            try self.addEntToDb(location, EntType, ent, ent_db);
        }

        /// Queues entity to be added into the db upon queue flush.
        pub fn appendEnt(self: *Self, ent: anytype) !void {
            const EntType = @TypeOf(ent);
            try @field(self.ent_append_queue, EntType.location).append(self.allocator, ent);
        }

        /// Flush append queues of all entity types within the data base,
        /// adding them to the db
        pub fn flushAppendQueueAll(self: *Self) !void {
            inline for(ent_types) |T| try self.flushAppendQueue(T);
        }

        /// Flush appened queue of all entities of the specified type
        pub fn flushAppendQueue(self: *Self, comptime EntType: type) !void {
            const ent_db = self.getEntDb(EntType);
            const location = getLocationEnumByType(EntType);
            const queue: *std.ArrayList(EntType) = &@field(self.ent_append_queue, EntType.location);
            defer queue.clearRetainingCapacity();

            for(queue.items) |ent| try self.addEntToDb(location, EntType, ent, ent_db);
        }

        fn flushQueue(self: *Self, comptime EntType: type, queue: anytype) !void {
            const ent_db = self.getEntDb(EntType);
            const location = getLocationEnumByType(EntType);
            defer queue.clearRetainingCapacity();

            for(queue.items) |ent| {
                if(@TypeOftry self.addEntToDb(location, EntType, ent, ent_db);
            }
        }

        fn addEntToDb(
            self: *Self, 
            location: EntLocation, 
            comptime ent_type: type, 
            ent: ent_type,
            ent_db: *SmartSoa(ent_type)
        ) !void {
            var ent_cpy = ent;
            const ent_idx: u32 = @intCast(ent_db.len);
            const new_id = try self.slot_queue.setNextSlot(ent_idx, location);
            ent_cpy.id = new_id;               
            
            try ent_db.append(self.allocator, ent_cpy);
            self.len += 1;
        }

        /// Directly deletes entity from DB.  Can cause errors if called
        /// while itterating through entities.
        pub fn deleteEnt(self: *Self, ent: anytype) !void {
            const EntType = @TypeOf(ent);
            const ent_db = self.getEntDb(ent);

            self.deleteEntFromDb(EntType, ent_db, ent.id);
        }

        pub fn queueEntForDeletion(self: *Self, ent: anytype) !void {
            const EntType = @TypeOf(ent);
            try @field(self.ent_remove_queue, EntType.location).append(self.allocator, ent);
        }


        fn deleteEntFromDb(
            self: *Self, 
            comptime EntType: type, 
            ent_db: *SmartSoa(EntType),
            ent_id: u32,
        ) !void {
            const removed_slot = try self.slot_queue.sendSlotToQueue(ent_id);
            const removed_idx: usize = removed_slot.ent_idx;
            const last_idx = ent_db.len - 1;
            const swapped_ent = if (removed_idx != last_idx) ent_db.get(last_idx) else null;

            _ = ent_db.swapAndPopIdx(removed_idx);
            if(swapped_ent) |ent| {
                const slot_of_swapped_ent = try self.slot_queue.getSlot(ent.id);
                slot_of_swapped_ent.ent_idx = @intCast(removed_idx);
            }

            self.len -= 1;
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

fn getEntQueue(comptime ent_types: []const type, comptime u32_only: bool) type {
    var names: [ent_types.len][]const u8 = undefined;
    var types: [ent_types.len]type = undefined;
    var attrs: [ent_types.len]std.builtin.Type.StructField.Attributes = undefined;
    
    for(ent_types, &names, &types, &attrs) |ent_type, *name, *t, *attr| {
        const T = if(u32_only) u32 else ent_type;
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
}