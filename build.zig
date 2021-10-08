const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;
pub fn setup_nbody(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});
    var nbody = b.addExecutable("nbody", "nbody.zig");
    nbody.linkSystemLibrary("c");
    nbody.linkSystemLibrary("raylib");
    nbody.setBuildMode(mode);
    nbody.setTarget(target);
    nbody.install();
    const build_step = b.step("nbody", "Build nbody");
    build_step.dependOn(&nbody.step);
    const run_cmd = nbody.run();
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run-nbody", "run nbody");
    run_step.dependOn(&run_cmd.step);
}
fn setup_fftw(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    var fftw = b.addExecutable("fftw", "fftw.zig");
    fftw.linkSystemLibrary("c");
    fftw.linkSystemLibrary("pulse-simple");
    fftw.linkSystemLibrary("pulse");
    fftw.linkSystemLibrary("fftw3");
    fftw.setBuildMode(mode);
    fftw.install();
    const build_step = b.step("fftw", "build fftw");
    build_step.dependOn(&fftw.step);
    const run_cmd = fftw.run();
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run-fftw", "Run fftw");
    run_step.dependOn(&run_cmd.step);
}
pub fn setup_game(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    var game = b.addExecutable("game", "game.zig");
    game.linkSystemLibrary("c");
    game.linkSystemLibrary("raylib");
    game.setBuildMode(mode);
    game.install();
    const build_step = b.step("game", "Build game");
    build_step.dependOn(&game.step);
    const run_cmd = game.run();
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run-game", "Run the game");
    run_step.dependOn(&run_cmd.step);
}

pub fn setup_nbody3(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    var nbody3 = b.addExecutable("nbody3", "nbody3.zig");
    nbody3.linkSystemLibrary("c");
    nbody3.linkSystemLibrary("raylib");
    nbody3.setBuildMode(mode);
    nbody3.install();
    const build_step = b.step("nbody3", "Build nbody3");
    build_step.dependOn(&nbody3.step);
    const run_cmd = nbody3.run();
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run-nbody3", "Run nbody3");
    run_step.dependOn(&run_cmd.step);
}
pub fn build(b: *Builder) !void {
    setup_nbody(b);
    setup_fftw(b);
    setup_game(b);
    setup_nbody3(b);
}
