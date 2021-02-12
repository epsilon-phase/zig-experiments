const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;
pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});
    var nbody = b.addExecutable("nbody", "nbody.zig");
    nbody.linkSystemLibrary("c");
    nbody.linkSystemLibrary("raylib");
    nbody.setBuildMode(b.standardReleaseOptions());
    nbody.setTarget(target);
    nbody.install();
    const run_cmd = nbody.run();
    const run_step = b.step("Run", "Run Nbody");
    run_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_cmd.step);
    b.default_step.dependOn(&nbody.step);
}
