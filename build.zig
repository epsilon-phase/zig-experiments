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
pub fn build(b: *Builder) !void {
    setup_nbody(b);
    setup_fftw(b);
}
