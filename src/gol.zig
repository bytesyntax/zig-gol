//! Conway's Game of Life implemented in Zig
//!
//! This module provides a way to setup a new Game of Life in a world
//! of given dimensions, as well as functions to update the world according
//! to the ruleset.
const std = @import("std");
const zig_gol = @import("zig_gol");

const Allocator = std.mem.Allocator;

/// Point is one potential "life" entity in Conway's Game of Life
///
/// Has a field to indicate if it is alive or not and has a field
/// used when counting neighbors to determine how next iteration
/// will end up.
const Point = packed struct {
    alive: u1,
    neighbors: u3,
};

/// NeighborOffset is used as to iterate over all potential neighbours
const NeighborOffset = packed struct {
    xOffset: i4,
    yOffset: i4,
};

/// neighborOffsets contains all potential neighbour offsets for a given
/// point in a 2D coordinate system, i.e. all 8 surrounding point offsets.
const neighborOffsets = [_]NeighborOffset{
    NeighborOffset{ .xOffset = -1, .yOffset = -1 },
    NeighborOffset{ .xOffset = -1, .yOffset = 0 },
    NeighborOffset{ .xOffset = -1, .yOffset = 1 },
    NeighborOffset{ .xOffset = 0, .yOffset = -1 },
    NeighborOffset{ .xOffset = 0, .yOffset = 1 },
    NeighborOffset{ .xOffset = 1, .yOffset = -1 },
    NeighborOffset{ .xOffset = 1, .yOffset = 0 },
    NeighborOffset{ .xOffset = 1, .yOffset = 1 },
};

/// Gol is the main object that contains information about the world dimensions
/// as well as a list of all the Points within this 2D universe.
const Gol = struct {
    sizeX: isize,
    sizeY: isize,
    map: []Point,
    life: usize,

    pub fn deinit(self: *const Gol, allocator: Allocator) void {
        allocator.free(self.map);
    }

    /// Get the point index in the world map for a given x-y coordinate, or null
    /// if it is outside the world.
    ///
    /// Needs to accept negative coordinate values as these might be the result
    /// of calcuating neighbor offsets. If an invalid coordinate is provided the
    /// function will return null.
    fn getPointIndex(self: *const Gol, x: isize, y: isize) ?usize {
        if (x < 0 or y < 0 or x >= self.sizeX or y >= self.sizeY) return null;
        const index = x * self.sizeY + y;
        if (index >= self.map.len or index < 0) return null;
        return @intCast(index);
    }

    pub fn print(self: Gol) void {
        std.debug.print("World: size={} ({}x{}), life={}:\n", .{ self.sizeX * self.sizeY, self.sizeX, self.sizeY, self.life });
        for (0..self.map.len) |i| {
            std.debug.print("- {}: {}\n", .{ i, self.map[i] });
        }
    }

    /// Update the world for the next iteration.
    ///
    /// Checks each Point in the map and if that is alive it adds to neighbor count
    /// of all surrounding Points.
    ///
    /// Next it refreshes the map to alive or unalive Points accoring to given rules.
    /// Finally reset neighbor counts for next iteration.
    pub fn update(self: *Gol) usize {
        var i: isize = -1;

        for (self.map) |p| {
            i += 1;
            if (p.alive == 1) {
                for (neighborOffsets) |offset| {
                    const neighborIndex = self.getPointIndex(
                        @divTrunc(i, self.sizeY) + offset.xOffset,
                        @rem(i, self.sizeY) + offset.yOffset,
                    );
                    if (neighborIndex != null) {
                        self.map[neighborIndex.?].neighbors += 1;
                    }
                }
            }
        }

        self.life = 0;
        for (self.map) |*p| {
            if (p.neighbors < 2 or p.neighbors > 3) {
                p.alive = 0;
            } else if (p.neighbors == 3) {
                p.alive = 1;
            }
            if (p.alive == 1) self.life += 1;
            p.neighbors = 0;
        }

        return self.life;
    }
};

/// Init function to allocate memory and initialize the Points
pub fn init(allocator: Allocator, comptime x: usize, comptime y: usize) !Gol {
    const map = try allocator.alloc(Point, x * y);

    const gol = Gol{
        .sizeX = x,
        .sizeY = y,
        .map = map,
        .life = 0,
    };

    for (0..gol.map.len) |i| {
        gol.map[i].alive = 0;
        gol.map[i].neighbors = 0;
    }

    gol.map[gol.getPointIndex(1, 0).?].alive = 1;
    gol.map[gol.getPointIndex(1, 1).?].alive = 1;
    gol.map[gol.getPointIndex(1, 2).?].alive = 1;

    return gol;
}
