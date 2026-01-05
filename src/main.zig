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
const deadColor = Pixel{ .r = 64, .g = 0, .b = 0, .a = 255 };

pub fn main() !void {
    const simulationSizeX: i32 = 480;
    const simulationSizeY: i32 = 270;
    var windowSizeX: i32 = 3840 - simulationSizeX;
    var windowSizeY: i32 = 2160 - simulationSizeY;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Setup GoL world
    var world = try gol.init(allocator, simulationSizeX, simulationSizeY, 11418);
    defer {
        world.deinit(allocator);
    }

    // Setup graphics
    rl.initWindow(windowSizeX, windowSizeY, "Conway's Game of Life");
    defer rl.closeWindow();

    const pixels = try allocator.alloc(Pixel, simulationSizeX * simulationSizeY);
    defer allocator.free(pixels);

    const image = rl.genImageColor(simulationSizeX, simulationSizeY, rl.Color.dark_gray);
    defer rl.unloadImage(image);

    const texture = try rl.loadTextureFromImage(image);
    defer rl.unloadTexture(texture);

    rl.setTargetFPS(15);

    // Main loop
    while (!rl.windowShouldClose()) {
        // Update pixels
        for (pixels, world.map) |*px, cell| {
            var color: Pixel = undefined;
            if (cell.alive == 1) {
                color = aliveColor;
                if (cell.state != 0) color.a -= @as(u8, cell.state) * 24;
            } else {
                color = deadColor;
                if (cell.state != 0) color.a -= @as(u8, cell.state) * 24;
            }

            px.* = color;
        }
        rl.updateTexture(texture, pixels.ptr);

        // Update text
        const statusText = rl.textFormat("FPS: %i\nLife: %i", .{ rl.getFPS(), world.life });

        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        // Calculate scaling
        windowSizeX = rl.getScreenWidth();
        windowSizeY = rl.getScreenHeight();

        const scaleWidth = @as(f32, @floatFromInt(windowSizeX)) / @as(f32, @floatFromInt(simulationSizeX));
        const scaleHeight = @as(f32, @floatFromInt(windowSizeY)) / @as(f32, @floatFromInt(simulationSizeY));
        const scale: f32 = @min(scaleWidth, scaleHeight);

        const drawWidth = @as(f32, simulationSizeX) * scale;
        const drawHeight = @as(f32, simulationSizeY) * scale;

        const offsetX = (@as(f32, @floatFromInt(windowSizeX)) - drawWidth) * 0.5;
        const offsetY = (@as(f32, @floatFromInt(windowSizeY)) - drawHeight) * 0.5;

        // Draw pixels
        rl.drawTexturePro(
            texture,
            rl.Rectangle.init(0, 0, @floatFromInt(simulationSizeX), @floatFromInt(simulationSizeY)),
            rl.Rectangle.init(offsetX, offsetY, drawWidth, drawHeight),
            rl.Vector2.init(0, 0),
            0.0,
            rl.Color.white,
        );

        // Draw text
        rl.drawText(
            statusText,
            7,
            7,
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
