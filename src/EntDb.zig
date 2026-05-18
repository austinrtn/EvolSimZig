const std = @import("std");
const SmartSoa = @import("SmartSoA").SmartSoA;
const Spec = @import("Spec.zig").Spec;

pub const EntType = enum {
   spec,
   food,
};

pub const EntElement = struct {
    index: u32,
    ent_type: EntType,
};

pub const EntDb = struct {
    const Self = @This();
    const EntData = struct{
        ents: SmartSoa(EntElement),
        specs: SmartSoa(Spec),
    };

    allocator: std.mem.Allocator,
    ent_data: EntData = undefined,

    pub fn init(allocator: std.mem.Allocator) Self{
        var self: Self = .{.allocator = allocator};
        inline for(std.meta.fields(EntData)) |field| {
            @field(self.ent_data, field.name) = .init();
        }
        return self;
    }

    pub fn deinit(self: *Self) void  {
        inline for(std.meta.fields(EntData)) |field| {
            const soa = &@field(self.ent_data, field.name);
            soa.deinit(self.allocator);
        }
    }
};
