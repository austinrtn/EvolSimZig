const std = @import("std");
const SmartSoa = @import("SmartSoA").SmartSoA;
const Spec = @import("Spec.zig").Spec;

const EntDataEnumField = blk: {
    const names = std.meta.fieldNames(EntData);
    @Enum(
        u32, 
        .exhaustive, 
        comptime field_names: []const []const u8, comptime field_values: *const [field_names.len]TagInt)
};

pub const EntElement = struct {
    index: u32,
    ent_field: EntDataEnumField,
};

const EntData = struct {
    ents: *SmartSoa(EntElement),
    specs: *SmartSoa(Spec),
};

pub const EntDb = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    ent_data: EntData = undefined,

    pub fn init(allocator: std.mem.Allocator) Self{
        var self: Self = .{.allocator = allocator};
        inline for(std.meta.fields(EntData)) |field| {
            const T = @typeInfo(@FieldType(self.ent_data, field.name)).pointer.child;
            const field_ptr = &@field(self.ent_data, field.name);
            field_ptr.* = try allocator.create(T);
            field_ptr.*.* = .init();
        }
        return self;
    }

    pub fn deinit(self: *Self) void  {
        inline for(std.meta.fields(EntData)) |field| {
            const soa = &@field(self.ent_data, field.name);
            soa.deinit(self.allocator);
            self.allocator.destroy(soa.*);
        }
    }
    
    pub fn append(self: *Self, soa_idx: u32, comptime ent_field: EntDataEnumField, ent: anytype) !void {
        if(@typeInfo(ent) != .pointer) @compileError("Type of ent must be pointer!\n");
        
        const elem: EntElement = .{.index = soa_idx, .ent_field = ent_field};
        try self.ent_data.ents.append(elem);
        const ent_db = &@field(self.ent_data, @tagName(ent_field));
        try ent_db.append(self.allocator, ent);
    }
};
