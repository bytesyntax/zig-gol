const std = @import("std");
const zig_gol = @import("zig_gol");
const Gol = @import("gol.zig").Gol;
const rl = @import("raylib");

const Pixel = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const aliveColor = Pixel{ .r = 255, .g = 255, .b = 255, .a = 255 };
const deadColor = Pixel{ .r = 16, .g = 0, .b = 0, .a = 255 };

pub fn main() !void {
    // Window size
    var windowSizeX: i32 = 3940;
    var windowSizeY: i32 = 2160;
    var paint = false;
    var interact = false;

    // Camera controls
    var cam_zoom: f32 = 1.0;
    var cam_offsetX: f32 = 0;
    var cam_offsetY: f32 = 0;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var world = try Gol.initFromRLE(allocator, "rle/clock.rle");
    // var world = try Gol.initFromRLE(allocator, "rle/test.rle");
    defer world.deinit();

    const simulationSizeX = world.width;
    const simulationSizeY = world.height;

    // Setup graphics
    // windowSizeX = rl.getScreenWidth();
    // windowSizeY = rl.getScreenHeight();

    rl.initWindow(windowSizeX, windowSizeY, "Conway's Game of Life");
    defer rl.closeWindow();

    rl.toggleFullscreen();

    const renderWidth_i32 = rl.getScreenWidth();
    const renderHeight_i32 = rl.getScreenHeight();

    const renderWidth: usize = @intCast(renderWidth_i32);
    const renderHeight: usize = @intCast(renderHeight_i32);

    const image = rl.genImageColor(
        renderWidth_i32,
        renderHeight_i32,
        rl.Color.black,
    );
    defer rl.unloadImage(image);

    const texture = try rl.loadTextureFromImage(image);
    defer rl.unloadTexture(texture);

    const pixels = try allocator.alloc(
        Pixel,
        renderWidth * renderHeight,
    );
    defer allocator.free(pixels);

    rl.setTargetFPS(0);

    // benchmark(&world);

    std.debug.print("Alive after load: {}\n", .{world.countAlive()});
    std.debug.print(
        "Render size: {} x {}\n",
        .{ rl.getScreenWidth(), rl.getScreenHeight() },
    );

    // Main loop
    while (!rl.windowShouldClose()) {
        // Update pixels
        // const offsetX = (world.width - renderWidth) / 2;
        // const offsetY = (world.height - renderHeight) / 2;

        for (0..renderHeight) |y| {
            for (0..renderWidth) |x| {
                const worldX = @as(usize, @intFromFloat((@as(f32, @floatFromInt(x)) / cam_zoom) + cam_offsetX));
                const worldY = @as(usize, @intFromFloat((@as(f32, @floatFromInt(y)) / cam_zoom) + cam_offsetY));

                var color = deadColor;

                if (worldX < world.width and worldY < world.height) {
                    if (world.getCell(worldX, worldY)) {
                        color = aliveColor;
                    }
                    // Draw simulation border
                    else if (worldX == 0 or
                        worldY == 0 or
                        worldX == world.width - 1 or
                        worldY == world.height - 1)
                    {
                        color = Pixel{ .r = 0, .g = 0, .b = 255, .a = 128 };
                    }
                }

                pixels[y * renderWidth + x] = color;
            }
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
        const statusText = rl.textFormat("FPS: %i\nLife: %i\nGeneration: %i", .{ rl.getFPS(), world.countAlive(), world.generation });

        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        // rl.drawRectangle(
        //     -5,
        //     -5,
        //     @intCast(world.width + 5),
        //     @intCast(world.height + 5),
        //     rl.Color.yellow,
        // );

        // Draw updated texture
        rl.drawTexture(
            texture,
            0,
            0,
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
            interact = true;
        }
        if (rl.isMouseButtonReleased(rl.MouseButton.right)) {
            interact = false;
        }
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            paint = true;
        }
        if (rl.isMouseButtonReleased(rl.MouseButton.left)) {
            paint = false;
        }

        // Handle mouse paint
        if (interact) {
            if (paint) {
                const mousePos = rl.getMousePosition();
                if (mousePos.x >= 0 and mousePos.y >= 0 and mousePos.x < drawWidth and mousePos.y < drawHeight) {
                    // Convert screen coordinates to simulation coordinates
                    const cellX = @as(i32, @intFromFloat(mousePos.x / scaleWidth));
                    _ = cellX; // autofix
                    const cellY = @as(i32, @intFromFloat(mousePos.y / scaleHeight));
                    _ = cellY; // autofix

                    // world.setAlive(cellX, cellY);
                }
            }

            const wheel = rl.getMouseWheelMove();
            if (wheel != 0) {
                cam_zoom *= 1.0 + wheel * 0.1;
                if (cam_zoom < 0.1) cam_zoom = 0.1;
                if (cam_zoom > 20.0) cam_zoom = 20.0;
            }

            if (rl.isMouseButtonDown(rl.MouseButton.middle)) {
                const delta = rl.getMouseDelta();
                cam_offsetX -= delta.x / cam_zoom;
                cam_offsetY -= delta.y / cam_zoom;
            }
        }

        // Update state
        world.update();
        std.debug.print("Alive after update: {}\n", .{world.countAlive()});
    }
}

fn benchmark(gol: *Gol) void {
    const iterations: usize = 20;

    const start = std.time.nanoTimestamp();

    for (0..iterations) |_| {
        gol.update();
    }

    const end = std.time.nanoTimestamp();

    const total_ns: i128 = end - start;
    const avg_ns: i128 = @divTrunc(total_ns, @as(i128, iterations));

    const avg_ms = @as(f64, @floatFromInt(avg_ns)) / 1_000_000.0;

    std.debug.print(
        "Average update time: {d:.3} ms\n",
        .{avg_ms},
    );
}
