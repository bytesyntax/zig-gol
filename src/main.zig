const std = @import("std");
const zig_gol = @import("zig_gol");
const gol = @import("gol.zig");

const TrackingAllocator = @import("trackingAllocator.zig").TrackingAllocator;

pub fn main() !void {
    const sizeX: usize = 3840;
    const sizeY: usize = 2160;

    std.debug.print("Creating a {}x{} world\n", .{ sizeX, sizeY });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var tracker = TrackingAllocator{
        .child = gpa.allocator(),
    };

    const allocator = tracker.allocator();

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // const alloc = gpa.allocator();

    const world = try gol.init(allocator, sizeX, sizeY);
    defer {
        world.deinit(allocator);
    }

    // world.print();
    std.debug.print("Get point {}x{} = {?}\n", .{ 1, 1, world.getPoint(1, 1) });
    std.debug.print("Get point {}x{} = {?}\n", .{ 2, 0, world.getPoint(2, 0) });

    std.debug.print("live bytes: {}\npeak bytes: {}\n", .{ tracker.live_bytes, tracker.peak_bytes });

    std.debug.print("The world will die...\n", .{});

    // std.debug.print("{any}\n", .{world.map});
}
