const std = @import("std");
const zig_gol = @import("zig_gol");
const gol = @import("gol.zig");
const rl = @import("raylib");

const Pixel = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const aliveColor = Pixel{ .r = 0, .g = 255, .b = 0, .a = 255 };
const deadColor = Pixel{ .r = 40, .g = 40, .b = 40, .a = 255 };

pub fn main() !void {
    const sizeX: u32 = 3840;
    const sizeY: u32 = 2160;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Setup GoL world
    var world = try gol.init(allocator, sizeX, sizeY, 18114);
    defer {
        world.deinit(allocator);
    }

    // Setup graphics
    rl.initWindow(sizeX, sizeY, "Conway's Game of Life");
    defer rl.closeWindow();

    const pixels = try allocator.alloc(Pixel, sizeX * sizeY);
    defer allocator.free(pixels);

    const image = rl.genImageColor(sizeX, sizeY, rl.Color.dark_gray);
    defer rl.unloadImage(image);

    const texture = try rl.loadTextureFromImage(image);
    defer rl.unloadTexture(texture);

    // rl.setTargetFPS(40);

    // Main loop
    while (!rl.windowShouldClose()) {
        // Update pixels
        for (pixels, world.map) |*px, cell| {
            if (cell.alive == 1) {
                px.* = aliveColor;
            } else {
                px.* = deadColor;
            }
        }
        rl.updateTexture(texture, pixels.ptr);

        // Update text
        const statusText = rl.textFormat("FPS: %i\nLife: %i", .{ rl.getFPS(), world.life });

        // Draw everything
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);
        rl.drawTexture(texture, 0, 0, rl.Color.white);
        rl.drawText(
            statusText,
            5,
            5,
            20,
            rl.Color.black,
        );
        rl.drawText(
            statusText,
            4,
            4,
            20,
            rl.Color.red,
        );
        rl.drawText(statusText, 5, 5, 20, rl.Color.red);
        rl.endDrawing();

        // Update state
        world.update();
    }
}
