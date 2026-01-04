const std = @import("std");
const zig_gol = @import("zig_gol");
const gol = @import("gol.zig");
const rl = @import("raylib");

pub fn main() !void {
    const sizeX: u16 = 3840;
    const sizeY: u16 = 2160;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var world = try gol.init(allocator, sizeX, sizeY, 18114);
    defer {
        world.deinit(allocator);
    }

    rl.initWindow(sizeX, sizeY, "Conway's Game of Life");
    defer rl.closeWindow();

    const renderTexture = try rl.loadRenderTexture(sizeX, sizeY);
    defer rl.unloadRenderTexture(renderTexture);

    while (!rl.windowShouldClose()) {
        rl.beginTextureMode(renderTexture);
        rl.clearBackground(rl.Color.dark_gray);
        for (0..sizeX) |x| {
            for (0..sizeY) |y| {
                const index = x * @abs(world.sizeY) + y;
                if (world.map[index].alive == 1) {
                    rl.drawPixel(@intCast(x), @intCast(y), rl.Color.green);
                }
            }
        }
        const statusText = rl.textFormat("FPS: %i\nLife: %i", .{ rl.getFPS(), world.life });
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
        rl.endTextureMode();

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.drawTextureRec(
            renderTexture.texture,
            rl.Rectangle.init(0, 0, @as(f32, sizeX), -@as(f32, sizeY)),
            rl.Vector2.init(0, 0),
            rl.Color.white,
        );

        world.update();
    }
}
