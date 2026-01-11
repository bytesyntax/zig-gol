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
    var windowSizeX: i32 = rl.getScreenWidth();
    var windowSizeY: i32 = rl.getScreenHeight();
    var simulationSizeX: i32 = @divFloor(windowSizeX, 8);
    var simulationSizeY: i32 = @divFloor(windowSizeY, 8);
    var paint = false;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Reading RLE data from file
    std.debug.print("Reading RLE file...\n", .{});
    const rle_data = try std.fs.cwd().readFileAlloc(
        allocator,
        "rle/clock.rle",
        std.math.maxInt(usize),
    );
    errdefer allocator.free(rle_data);

    // Setup GoL world
    std.debug.print("Initializing world...\n", .{});
    var world = try gol.initFromRLE(allocator, rle_data);
    defer world.deinit(allocator);

    allocator.free(rle_data);

    simulationSizeX = world.sizeX;
    simulationSizeY = world.sizeY;

    // Setup graphics
    rl.initWindow(windowSizeX, windowSizeY, "Conway's Game of Life");
    defer rl.closeWindow();

    rl.toggleFullscreen();

    const pixels = try allocator.alloc(Pixel, @as(usize, @intCast(simulationSizeX * simulationSizeY)));
    defer allocator.free(pixels);

    const image = rl.genImageColor(simulationSizeX, simulationSizeY, rl.Color.dark_gray);
    defer rl.unloadImage(image);

    const texture = try rl.loadTextureFromImage(image);
    defer rl.unloadTexture(texture);

    rl.setTargetFPS(0);

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

        // Calculate scaling
        windowSizeX = rl.getScreenWidth();
        windowSizeY = rl.getScreenHeight();

        const scaleWidth = @as(f32, @floatFromInt(windowSizeX)) / @as(f32, @floatFromInt(simulationSizeX));
        const scaleHeight = @as(f32, @floatFromInt(windowSizeY)) / @as(f32, @floatFromInt(simulationSizeY));

        const drawWidth = @as(f32, @floatFromInt(simulationSizeX)) * scaleWidth;
        const drawHeight = @as(f32, @floatFromInt(simulationSizeY)) * scaleHeight;

        // Update text
        const statusText = rl.textFormat("FPS: %i\nLife: %i\nGeneration: %i", .{ rl.getFPS(), world.life, world.generation });

        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        // Draw pixels
        rl.drawTexturePro(
            texture,
            rl.Rectangle.init(0, 0, @floatFromInt(simulationSizeX), @floatFromInt(simulationSizeY)),
            rl.Rectangle.init(0, 0, drawWidth, drawHeight),
            rl.Vector2.init(0, 0),
            0.0,
            rl.Color.white,
        );

        // Draw shadow + text
        rl.drawText(
            statusText,
            7,
            6,
            22,
            rl.Color.black,
        );
        rl.drawText(
            statusText,
            4,
            4,
            22,
            rl.Color.magenta,
        );

        rl.endDrawing();

        // Handle mouse input
        if (rl.isMouseButtonPressed(rl.MouseButton.right)) {
            world.paused = true;
        }
        if (rl.isMouseButtonReleased(rl.MouseButton.right)) {
            world.paused = false;
        }
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            paint = true;
        }
        if (rl.isMouseButtonReleased(rl.MouseButton.left)) {
            paint = false;
        }

        // Handle mouse paint
        if (world.paused and paint) {
            const mousePos = rl.getMousePosition();
            if (mousePos.x >= 0 and mousePos.y >= 0 and mousePos.x < drawWidth and mousePos.y < drawHeight) {
                // Convert screen coordinates to simulation coordinates
                const cellX = @as(i32, @intFromFloat(mousePos.x / scaleWidth));
                const cellY = @as(i32, @intFromFloat(mousePos.y / scaleHeight));

                world.setAlive(cellX, cellY);
            }
        }
        // Update state
        world.update();
    }
}
