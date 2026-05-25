const std = @import("std");
const raylib = @import("raylib");
const FoodSoa = @import("SmartSoA").SmartSoA(Food);
const Config = @import("config.zig").Config;
const EntDb = @import("EntDb.zig").EntDb;

pub const Food = struct {
    pub const location = "foods";
    const color = raylib.Color.red;
    
    x: f32, 
    y: f32, 
    r: f32,
    id: u32, 
    colliding: bool = false,
};