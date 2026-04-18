const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shlex_dep = b.dependency("shlex", .{
        .target = target,
        .optimize = optimize,
    });

    const shlex_mod = shlex_dep.module("shlex");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "simple-git-ssh",
        .root_module = exe_mod,
    });

    exe.root_module.addImport("shlex", shlex_mod);

    b.installArtifact(exe);
}
