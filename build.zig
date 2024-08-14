const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "battlebuds",
        .root_source_file = b.path("src/_main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // link libraries
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("xcb");
    // exe.linkSystemLibrary("x11");
    // exe.addCSourceFile(.{ .file = b.path("src/xcb_example2.c"), .flags = &[_][]const u8{"-std=c11"} });
    exe.addIncludePath(b.path("src/"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    // // exe.addCSourceFile("src/libdrm_example.c");
    // exe.addCSourceFile(.{ .file = b.path("src/libdrm_example.c"), .flags = &[_][]const u8{"-std=c11"} });
    // // exe.addIncludePath(b.path("src/"));

    // exe.linkSystemLibrary("c");
    // exe.linkSystemLibrary("libdrm");
    // b.installArtifact(exe);

    // const run_cmd = b.addRunArtifact(exe);
    // run_cmd.step.dependOn(b.getInstallStep());
    // const run_step = b.step("run", "Run the app");
    // run_step.dependOn(&run_cmd.step);
}
