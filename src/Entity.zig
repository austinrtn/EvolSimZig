const std = @import("std");
const ComponentRegistry = @import("Component.zig").ComponentRegistry;
const Component = @import("Component.zig").Component;
const System = @import("System.zig").System;

pub fn GenerateFieldsFromComponents(comptime components: []const Component, comptime is_slice: bool) type {
    var names: [components.len][]const u8 = undefined;
    var types: [components.len]type = undefined;
    var attrs: [components.len]std.builtin.Type.StructField.Attributes = undefined;

    for(components, &names, &types, &attrs) |comp, *name, *T, *attr| {
        const CompT = @field(ComponentRegistry, tag_name);
        const T = if(is_slice) []CompT else ComptT;
        const tag_name = @tagName(comp);
        name.* = tag_name;
        T.* =
        attr.* = .{};
    }

    return @Struct(
        .auto,
        null,
        &names,
        &types,
        &attrs,
    );
}

pub fn Entity(comptime type_name: []const u8, comptime components: []const Component) type {
    const Fields = GenerateFieldsFromComponents(components);

    return struct {
        const Self = @This();
        pub const Name = type_name;
        pub const FieldsType = Fields;
        pub const Components = components;
        fields: Fields = undefined,

        pub fn init(fields: Fields) Self {
            return .{.fields = fields};
        }
    };
}


// pub fn Entity(comptime systems: []const type) type {
//     const component_count = blk: {
//         var count: usize = 0;
//         for(systems) |sys| count += sys.Components.len;
//         break :blk count;
//     };

//     const raw_components = blk: {
//         var comps: [component_count]Component = undefined;
//         var i: usize = 0;
//         for(systems) |sys| {
//             for(sys.Components) |comp| {
//                 comps[i] = comp;
//                 i += 1;
//             }
//         }
//         break :blk comps;
//     };

//     const sorted_components = blk: {
//         var comps = raw_components;
//         std.mem.sort(Component, &comps, {}, struct{
//             fn lessThan(_: void, comp1: Component, comp2: Component) bool {
//                 return std.mem.lessThan(u8, @tagName(comp1), @tagName(comp2));
//             }
//         }.lessThan);
//         break :blk comps;
//     };

//     const components = blk:{
//         var comps: [component_count]Component = undefined;
//         var count: usize = 0;

//         for(sorted_components, 0..) |comp, i| {
//             if(i + 1 < comps.len) {
//                 if(!std.mem.eql(u8, @tagName(comp), @tagName(sorted_components[i + 1]))) {
//                     comps[count] = comp;
//                     count += 1;
//                 }
//             }
//         }

//         break :blk comps;
//     };

//     var field_names: [components.len] []const u8 = undefined;
//     var field_types: [components.len] type = undefined;
//     var attrs: [components.len]std.builtin.Type.StructField.Attributes = undefined;

//     for(components, &field_names, &field_types, &attrs) |comp, *name, *T, *attr| {
//         const tag_name = @tagName(comp);
//         name.* = tag_name;
//         T.* = @field(ComponentRegistry, tag_name);
//         attr.* = .{};
//     }

//     return @Struct(
//         .auto,
//         null,
//         &field_names,
//         &field_types,
//         &attrs,
//     );
// }

// // pub const TestEnt = Entity(&.{})
