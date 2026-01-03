const std = @import("std");
const zig_gol = @import("zig_gol");

const Allocator = std.mem.Allocator;

const Point = packed struct {
    alive: u1,
    neighbors: u3,
};

const Gol = struct {
    sizeX: usize,
    sizeY: usize,
    map: []Point,

    pub fn deinit(self: *const Gol, allocator: Allocator) void {
        allocator.free(self.map);
    }

    pub fn getPoint(self: *const Gol, x: usize, y: usize) ?Point {
        const index = x * self.sizeY + y;
        if (index >= self.map.len) return null;
        return self.map[index];
    }

    pub fn print(self: Gol) void {
        std.debug.print("World: size={} ({}x{}):\n", .{ self.sizeX * self.sizeY, self.sizeX, self.sizeY });
        for (self.map) |point| {
            std.debug.print("- {}\n", .{point});
        }
    }
};

pub fn init(allocator: Allocator, comptime x: usize, comptime y: usize) !Gol {
    const map = try allocator.alloc(Point, x * y);

    const gol = Gol{
        .sizeX = x,
        .sizeY = y,
        .map = map,
    };

    for (gol.map) |*point| {
        point.* = Point{
            .alive = 0,
            .neighbors = 0,
        };
    }

    return gol;
}
