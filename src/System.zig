const std = @import("std");
const Component = @import("Component.zig").Component;

pub fn System(comptime components: []const Component, comptime inner: anytype) type {
    return struct {
        pub const Components = components;
        pub const Inner = inner;
    };
}
