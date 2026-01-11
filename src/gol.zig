//! Conway's Game of Life implemented in Zig
//!
//! This module provides a way to setup a new Game of Life in a world
//! of given dimensions, as well as functions to update the world according
//! to the ruleset.
const std = @import("std");
const zig_gol = @import("zig_gol");
const Allocator = std.mem.Allocator;
const Regex = @import("regex").Regex;

/// Point is one potential "life" entity in Conway's Game of Life
///
/// Has a field to indicate if it is alive or not and has a field
/// used when counting neighbors to determine how next iteration
/// will end up.
const Point = packed struct {
    alive: u1,
    neighbors: u4,
    state: u3,
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
    paused: bool,
    generation: usize = 0,

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
        const width: usize = @intCast(self.sizeX);
        const height: usize = @intCast(self.sizeY);

        if (self.paused) return;
        const offsets = [_]isize{ -1, 0, 1 };

        for (0..height) |y| {
            for (0..width) |x| {
                const idx = y * width + x;
                // Skip dead
                if (self.map[idx].alive == 0) continue;

                // Find all neighbors
                for (offsets) |dy| {
                    for (offsets) |dx| {
                        // Skip self
                        if (dx == 0 and dy == 0) continue;
                        // Add offset
                        const neighborX = @as(isize, @intCast(x)) + dx;
                        const neighborY = @as(isize, @intCast(y)) + dy;
                        // Validate within range
                        if (neighborX < 0 or neighborY < 0) continue;
                        if (neighborX >= width or neighborY >= height) continue;
                        // Calculate index as usize
                        const neighborIndex = @as(usize, @intCast(neighborY)) * width + @as(usize, @intCast(neighborX));
                        // Update
                        self.map[neighborIndex].neighbors += 1;
                    }
                }
            }
        }

        // Implement Game of Life rules
        self.life = 0;
        for (self.map) |*p| {
            if (p.alive == 0) {
                // Newly born
                if (p.neighbors == 3) {
                    p.alive = 1;
                    p.state = 0;
                }
            } else {
                // Newly died
                if (p.neighbors < 2 or p.neighbors > 3) {
                    p.alive = 0;
                    p.state = 0;
                }
            }

            // Update live points
            if (p.alive == 1) {
                self.life += 1;
            }

            if (p.state < std.math.maxInt(@TypeOf(p.state))) {
                p.state += 1;
            }

            // Reset neighbors!!!!
            p.neighbors = 0;
        }
        self.generation += 1;
    }

    // Set the giveen Point alive
    pub fn setAlive(self: Gol, x: i32, y: i32) void {
        const idx = @as(usize, @intCast(y * self.sizeX + x));
        if (idx > 0 and idx < self.map.len) {
            self.map[idx].alive = 1;
            self.map[idx].state = 0;
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
    pub fn generateStateFromSeed(self: *Gol, seed: u32) void {
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

    // Initialize alive from RLE data
    pub fn generateStateFromRLE(self: *Gol, srle: []const u8) void {
        var idx: usize = 0;
        var repeat: usize = 0;

        for (srle) |c| {
            if (idx >= self.map.len) {
                break;
            }
            switch (c) {
                '0'...'9' => {
                    repeat = repeat * 10 + (c - '0');
                },

                'b', 'o' => {
                    const count = if (repeat == 0) 1 else repeat;
                    repeat = 0;

                    const alive: u1 = if (c == 'o') 1 else 0;
                    for (0..count) |_| {
                        self.map[idx].alive = alive;
                        idx += 1;
                    }
                },

                '$' => {
                    const count = if (repeat == 0) 1 else repeat;
                    repeat = 0;

                    // advance rows WITHOUT looping per cell
                    const row = idx / @as(usize, @intCast(self.sizeX));
                    idx = (row + count) * @as(usize, @intCast(self.sizeX));
                },

                '!' => break,

                else => {}, // ignore whitespace / comments if present
            }
        }
    }
};

/// Init function to allocate memory and initialize the Points
pub fn init(allocator: Allocator, x: usize, y: usize) !Gol {
    const map = try allocator.alloc(Point, x * y);

    var gol = Gol{
        .sizeX = @as(i32, @intCast(x)),
        .sizeY = @as(i32, @intCast(y)),
        .map = map,
        .life = 0,
        .paused = false,
    };

    for (0..gol.map.len) |i| {
        gol.map[i].alive = 0;
        gol.map[i].neighbors = 0;
        gol.map[i].state = 0;
    }

    return gol;
}

/// Init function from seed
pub fn initFromSeed(allocator: Allocator, x: usize, y: usize, seed: u32) !Gol {
    var gol = try init(allocator, x, y);

    gol.generateStateFromSeed(seed);

    return gol;
}

/// Init function to allocate memory and initialize from RLE string
pub fn initFromRLE(allocator: Allocator, rle: []u8) !Gol {
    const rle_data = try parseRleData(rle);

    var gol = try init(allocator, rle_data.sizeX, rle_data.sizeY);

    gol.generateStateFromRLE(rle_data.body);

    return gol;
}

/// Parse RLE format data to extract size information and body data
fn parseRleData(rle: []const u8) !struct {
    sizeX: usize,
    sizeY: usize,
    body: []const u8,
} {
    var lines = std.mem.splitScalar(u8, rle, '\n');

    while (lines.next()) |line| {
        // Skip comments
        if (line.len == 0 or line[0] == '#') continue;

        // Found header line
        if (std.mem.startsWith(u8, std.mem.trimLeft(u8, line, " "), "x")) {
            const dims = try parseXYLine(line);
            const body = lines.rest();
            return .{
                .sizeX = dims.x,
                .sizeY = dims.y,
                .body = body,
            };
        }
    }

    return error.InvalidRLEFormat;
}

/// Helper function to extract x/y values
fn parseXYLine(line: []const u8) !struct { x: usize, y: usize } {
    const trimmed = std.mem.trim(u8, line, " ");

    // Split by comma: "x = 10" , " y = 20"
    var parts = std.mem.splitScalar(u8, trimmed, ',');

    const x_part = parts.next() orelse return error.InvalidRLEFormat;
    const y_part = parts.next() orelse return error.InvalidRLEFormat;

    return .{
        .x = try parseKeyValue(x_part, 'x'),
        .y = try parseKeyValue(y_part, 'y'),
    };
}

/// Helper function to parse int values
fn parseKeyValue(part: []const u8, key: u8) !usize {
    const trimmed = std.mem.trim(u8, part, " ");

    if (trimmed.len < 3 or trimmed[0] != key)
        return error.InvalidRLEFormat;

    const eq = std.mem.indexOfScalar(u8, trimmed, '=') orelse
        return error.InvalidRLEFormat;

    const value_str = std.mem.trim(u8, trimmed[eq + 1 ..], " ");

    return std.fmt.parseInt(usize, value_str, 10);
}
