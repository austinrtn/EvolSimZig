const std = @import("std");

pub fn SlotQueue(comptime EntLocation: type) type {
    const Slot = struct {
        id: u32,
        ent_idx: u32 = 0,
        ent_location: EntLocation = undefined,
        active: bool = false,
    };

    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        slots: std.ArrayList(Slot) = .empty,
        queue: std.ArrayList(u32) = .empty,

        pub fn init(allocator: std.mem.Allocator, slot_capacity: usize) !Self {
            var self: Self = .{.allocator = allocator};
            try self.slots.ensureTotalCapacity(allocator, slot_capacity);
            try self.queue.ensureTotalCapacity(allocator, slot_capacity);

            for(0..slot_capacity) |i| {
                try self.slots.append(allocator, .{ .id = @intCast(i) });
                try self.queue.append(allocator, @intCast(i));
            }

            return self;
        }

        pub fn deinit(self: *Self) void {
            const allocator = self.allocator;
            self.slots.deinit(allocator);
            self.queue.deinit(allocator);
        }

        pub fn setNextSlot(self: *Self, ent_idx: u32, ent_location: EntLocation) !u32{
            const next_queued_slot = self.queue.pop();
            if(next_queued_slot) |idx| {
                var slot: *Slot = &self.slots.items[idx];
                slot.ent_idx = ent_idx;
                slot.ent_location = ent_location;
                slot.active = true;

                return idx;
            }

            const new_slot: Slot = .{
                .id = @intCast(self.slots.items.len),
                .ent_idx = ent_idx,
                .ent_location = ent_location,
                .active = true,
            };
            return new_slot.id;
        }

        pub fn getSlot(self: *Self, idx: u32) !*Slot {
            const slot = &self.slots.items[idx];
            if(!slot.active) return error.InactiveSlot;

            return slot;
        }

        pub fn sendSlotToQueue(self: *Self, idx: u32) !Slot {
            var slot = self.slots.items[idx];
            if(!slot.active) return error.InactiveSlot;

            slot.active = false;
            try self.queue.append(self.allocator, idx);
            return slot;
        }
    };
}
