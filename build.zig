const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;
pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});
    var nbody = b.addExecutable("nbody", "nbody.zig");
    nbody.linkSystemLibrary("c");
    nbody.linkSystemLibrary("raylib");
    b.default_step.dependOn(&nbody.step);
}
