const std = @import("std");

pub const Gol = struct {
    width: usize,
    height: usize,
    words_per_row: usize,
    generation: usize,
    paused: bool,

    grid: []u64,
    next: []u64,

    allocator: std.mem.Allocator,

    // ------------------------------------------------------------
    // Constructors
    // ------------------------------------------------------------

    pub fn init(
        allocator: std.mem.Allocator,
        width: usize,
        height: usize,
    ) !Gol {
        const words_per_row = (width + 63) / 64;
        const total_words = words_per_row * height;

        const grid = try allocator.alignedAlloc(u64, .@"64", total_words);
        const next = try allocator.alignedAlloc(u64, .@"64", total_words);

        @memset(grid, 0);
        @memset(next, 0);

        return Gol{
            .width = width,
            .height = height,
            .words_per_row = words_per_row,
            .generation = 0,
            .paused = false,
            .grid = grid,
            .next = next,
            .allocator = allocator,
        };
    }

    pub fn initFromRLE(
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !Gol {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const data = try file.readToEndAlloc(allocator, 1 << 20);
        defer allocator.free(data);

        const dims = try parseRLEHeader(data);

        var gol = try Gol.init(allocator, dims.width, dims.height);
        try gol.parseRLEBody(data);

        return gol;
    }

    pub fn deinit(self: *Gol) void {
        self.allocator.free(self.grid);
        self.allocator.free(self.next);
    }

    // ------------------------------------------------------------
    // Core Step (scalar bitboard)
    // ------------------------------------------------------------

    pub fn update(self: *Gol) void {
        if (self.paused) return;

        @setRuntimeSafety(false);

        const h = self.height;
        const wpr = self.words_per_row;

        // ------------------------------------------------------------
        // Clear borders in next buffer
        // ------------------------------------------------------------

        // Clear top and bottom rows entirely
        for (0..wpr) |w| {
            self.next[w] = 0;
            self.next[(h - 1) * wpr + w] = 0;
        }

        // Clear only the leftmost and rightmost BITS
        for (1..h - 1) |y| {
            const row_base = y * wpr;

            // Clear bit 0 (leftmost cell)
            self.next[row_base] &= ~@as(u64, 1);

            // Clear last bit (rightmost cell)
            const last_bit_index = (self.width - 1) & 63;
            const last_word = (self.width - 1) >> 6;
            self.next[row_base + last_word] &=
                ~(@as(u64, 1) << @intCast(last_bit_index));
        }

        // ------------------------------------------------------------
        // Interior update
        // ------------------------------------------------------------

        for (1..h - 1) |y| {
            for (0..wpr) |w| {
                const north = self.grid[(y - 1) * wpr + w];
                const center = self.grid[y * wpr + w];
                const south = self.grid[(y + 1) * wpr + w];

                const west =
                    (center << 1) |
                    (self.grid[y * wpr + (w - 1)] >> 63);

                const east =
                    (center >> 1) |
                    (self.grid[y * wpr + (w + 1)] << 63);

                const nw =
                    (north << 1) |
                    (self.grid[(y - 1) * wpr + (w - 1)] >> 63);

                const ne =
                    (north >> 1) |
                    (self.grid[(y - 1) * wpr + (w + 1)] << 63);

                const sw =
                    (south << 1) |
                    (self.grid[(y + 1) * wpr + (w - 1)] >> 63);

                const se =
                    (south >> 1) |
                    (self.grid[(y + 1) * wpr + (w + 1)] << 63);

                // --- Correct full 3-bit population counter ---

                var c0: u64 = 0; // bit 0
                var c1: u64 = 0; // bit 1
                var c2: u64 = 0; // bit 2

                const planes = [_]u64{
                    north, south,
                    east,  west,
                    ne,    nw,
                    se,    sw,
                };

                for (planes) |p| {
                    const t0 = c0 ^ p;
                    const carry0 = c0 & p;

                    const t1 = c1 ^ carry0;
                    const carry1 = c1 & carry0;

                    c0 = t0;
                    c1 = t1;
                    c2 |= carry1;
                }

                const is3 = c0 & c1 & ~c2;
                const is2 = ~c0 & c1 & ~c2;

                var new_word = is3 | (center & is2);

                // Mask off invalid bits in the last word of each row
                if (w == wpr - 1) {
                    const valid_bits = self.width & 63;

                    if (valid_bits != 0) {
                        const mask = (@as(u64, 1) << @intCast(valid_bits)) - 1;
                        new_word &= mask;
                    }
                }

                self.next[y * wpr + w] = new_word;
            }
        }

        // ------------------------------------------------------------
        // Swap buffers
        // ------------------------------------------------------------

        std.mem.swap([]u64, &self.grid, &self.next);
        self.generation += 1;
    }

    // ------------------------------------------------------------
    // RLE Parsing
    // ------------------------------------------------------------

    const RLEDims = struct {
        width: usize,
        height: usize,
    };

    fn parseRLEHeader(data: []const u8) !RLEDims {
        var it = std.mem.tokenizeScalar(u8, data, '\n');

        while (it.next()) |line| {
            if (line.len == 0) continue;
            if (line[0] == '#') continue;

            // This should be the header line
            // Example:
            // x = 10284, y = 6796, rule = B3/S23

            const x_pos = std.mem.indexOf(u8, line, "x =") orelse
                return error.InvalidRLEHeader;

            const y_pos = std.mem.indexOf(u8, line, "y =") orelse
                return error.InvalidRLEHeader;

            const width_start = x_pos + 3;
            const height_start = y_pos + 3;

            const width_end = std.mem.indexOfScalarPos(u8, line, width_start, ',') orelse line.len;

            const height_end = std.mem.indexOfScalarPos(u8, line, height_start, ',') orelse line.len;

            const width_str = std.mem.trim(u8, line[width_start..width_end], " ");
            const height_str = std.mem.trim(u8, line[height_start..height_end], " ");

            const width = try std.fmt.parseInt(usize, width_str, 10);
            const height = try std.fmt.parseInt(usize, height_str, 10);

            return RLEDims{
                .width = width,
                .height = height,
            };
        }

        return error.MissingRLEHeader;
    }

    fn parseRLEBody(self: *Gol, data: []const u8) !void {
        var x: usize = 0;
        var y: usize = 0;
        var run_count: usize = 0;
        var i: usize = 0;

        // Skip header
        while (i < data.len and data[i] != '\n') : (i += 1) {}
        i += 1;

        while (i < data.len) : (i += 1) {
            const c = data[i];

            if (c >= '0' and c <= '9') {
                run_count = run_count * 10 + (c - '0');
                continue;
            }

            const count = if (run_count == 0) 1 else run_count;
            run_count = 0;

            switch (c) {
                'o' => {
                    for (0..count) |_| {
                        if (x < self.width and y < self.height) {
                            self.setCell(x, y);
                        }
                        x += 1;
                    }
                },
                'b' => x += count,
                '$' => {
                    y += count;
                    x = 0;
                },
                '!' => return,
                '\n', '\r', ' ' => {},
                else => {},
            }
        }
    }

    inline fn idx(self: *const Gol, y: usize, word: usize) usize {
        return y * self.words_per_row + word;
    }

    inline fn bitMask(x: usize) u64 {
        const bit: u6 = @intCast(x & 63);
        return (@as(u64, 1) << bit);
    }

    inline fn setCell(self: *Gol, x: usize, y: usize) void {
        const word = x >> 6;
        self.grid[self.idx(y, word)] |= bitMask(x);
    }

    pub inline fn getCell(self: *const Gol, x: usize, y: usize) bool {
        const word = x >> 6;
        const value = self.grid[self.idx(y, word)] & bitMask(x);
        return value != 0;
    }

    pub fn countAlive(self: *const Gol) usize {
        var total: usize = 0;
        for (self.grid) |word| {
            total += @popCount(word);
        }
        return total;
    }
};
