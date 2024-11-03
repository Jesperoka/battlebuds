const std = @import("std");
const sdl = @import("sdl");

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
    exe.linkSystemLibrary("png");
    exe.linkSystemLibrary("hidapi-libusb");

    // exe.addIncludePath(b.path("src/"));

    // Create a new instance of the SDL2 Sdk. Specifiy dependency name explicitly if necessary (use sdl by default) /
    const sdk = sdl.init(b, .{});

    // link SDL2 as a shared library
    sdk.link(exe, .dynamic, sdl.Library.SDL2);

    // Add "sdl2" package that exposes the SDL2 api (like SDL_Init or SDL_CreateWindow)
    exe.root_module.addImport("sdl2", sdk.getNativeModule());

    b.installArtifact(exe);

    // Make install step depend on running python script
    const run_python_script = b.addSystemCommand(&[_][]const u8{ "python3", "src/assets.py" });
    // b.getInstallStep().dependOn(&run_python_script.step);

    // Make run command step depend on install step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(&run_python_script.step);
    run_cmd.step.dependOn(b.getInstallStep());

    // Make run step depend on run command
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // const waf = b.addWriteFiles();
    // waf.addCopyFile(exe.getEmittedAsm(), "main.asm");
    // waf.step.dependOn(&exe.step);
    // b.getInstallStep().dependOn(&waf.step);
}
