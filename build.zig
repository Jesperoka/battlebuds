const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "battlebuds",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // link libraries
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("xcb-image");
    exe.linkSystemLibrary("xcb");

    // exe.addIncludePath(b.path("src/"));
    exe.addIncludePath(b.path("assets/"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
