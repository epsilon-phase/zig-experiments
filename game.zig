const std = @import("std");
const vectors = @import("vector");
const raylib = @cImport({
    @cInclude("raylib.h");
});
const v2 = vectors.Vector(f32);
pub fn main() !void {
    const rl = raylib;
    const width = 800;
    const height = 450;
    rl.InitWindow(width, height, "\"Game\"");
    rl.SetTargetFPS(60);
    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.BLACK);
    }
}
