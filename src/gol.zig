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
    neighbors: u5,
};

const XorShiftState = struct {
    state: u32,
};

/// Gol is the main object that contains information about the world dimensions
/// as well as a list of all the Points within this 2D universe.
const Gol = struct {
    sizeX: i32,
    sizeY: i32,
    map: []Point,
    life: usize,

    pub fn deinit(self: *const Gol, allocator: Allocator) void {
        allocator.free(self.map);
    }

    pub fn print(self: Gol) void {
        std.debug.print("World: size={} ({}x{}), life={}:\n", .{ self.sizeX * self.sizeY, self.sizeX, self.sizeY, self.life });
        for (0..self.map.len) |i| {
            std.debug.print("- {}: {}\n", .{ i, self.map[i] });
        }
    }

    /// Update the world for the next iteration.
    ///
    /// Checks each Point in the map and if it is alive it adds to neighbor count
    /// of all surrounding Points.
    ///
    /// Next it refreshes the map to alive or unalive Points accoring to given rules.
    /// Finally reset neighbor counts for next iteration.
    pub fn update(self: *Gol) void {
        // Index offset of surrounding neighbors
        const neighborOffsets = [_]i32{
            -self.sizeX - 1,
            -self.sizeX,
            -self.sizeX + 1,
            -1,
            1,
            self.sizeX - 1,
            self.sizeX,
            self.sizeX + 1,
        };

        // For each Point that is alive; add 1 to each surrounding points neighbor field
        for (0..@intCast(self.sizeY)) |y| {
            const rowOffset = @abs(self.sizeX) * y;
            for (0..@intCast(self.sizeX)) |x| {
                const index = rowOffset + x;
                // Only add to neighbors of alive Points
                if (self.map[index].alive == 1) {
                    for (neighborOffsets) |neighborOffset| {
                        const neighborIndex = @as(i32, @intCast(index)) + neighborOffset;
                        // Verify index within range
                        if (neighborIndex > 0 and neighborIndex < self.map.len) {
                            self.map[@as(usize, @intCast(neighborIndex))].neighbors += 1;
                        }
                    }
                }
            }
        }

        // Implement Game of Life rules
        self.life = 0;
        for (self.map) |*p| {
            // Die of under of over populated
            if (p.neighbors < 2 or p.neighbors > 3) {
                p.alive = 0;
            }
            // Born or still alive (implicit final else just leaves it as-is)
            else if (p.neighbors == 3) {
                p.alive = 1;
            }

            if (p.alive == 1) self.life += 1;
            p.neighbors = 0;
        }
    }

    // Seed generation for initial setup
    fn xorshift(state: *XorShiftState) u32 {
        var s = state.state;
        s ^= s << 13;
        s ^= s >> 17;
        s ^= s << 5;
        state.state = s;
        return s;
    }

    // Initialize alive before start
    pub fn generateState(self: *Gol, seed: u32) void {
        var state = XorShiftState{ .state = seed };
        for (self.map) |*p| {
            if ((xorshift(&state) & 1) != 0) {
                p.alive = 1;
                self.life += 1;
            } else {
                p.alive = 0;
            }
        }
    }
};

/// Init function to allocate memory and initialize the Points
pub fn init(allocator: Allocator, comptime x: usize, comptime y: usize, seed: u32) !Gol {
    const map = try allocator.alloc(Point, x * y);

    var gol = Gol{
        .sizeX = x,
        .sizeY = y,
        .map = map,
        .life = 0,
    };

    for (0..gol.map.len) |i| {
        gol.map[i].alive = 0;
        gol.map[i].neighbors = 0;
    }

    if (seed != 0) {
        gol.generateState(seed);
    }

    return gol;
}
