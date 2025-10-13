const std = @import("std");
const sdl = @import("sdl");

fn cpu_arch_from_string(arch_string: []const u8) !std.Target.Cpu.Arch {
    inline for (std.meta.fields(std.Target.Cpu.Arch)) |arch_field| {
        const arch: std.Target.Cpu.Arch = @enumFromInt(arch_field.value);
        const valid_arch_string: []const u8 = arch_field.name;

        if (std.mem.eql(u8, arch_string, valid_arch_string)) return arch;
    }
    unreachable;
}

fn os_from_string(os_string: []const u8) !std.Target.Os.Tag {
    inline for (std.meta.fields(std.Target.Os.Tag)) |os_field| {
        const os: std.Target.Os.Tag = @enumFromInt(os_field.value);
        const valid_os_string: []const u8 = os_field.name;

        if (std.mem.eql(u8, os_string, valid_os_string)) return os;
    }
    unreachable;
}

pub fn build(b: *std.Build) !void {
    // NOTE:
    //      Trying to use the `b.resolveTargetQuery` function to manually resolve the target architecture and operating system.
    //      I'm doing this so I can cross-compile later.

    const target_architecture = b.option(
        []const u8,
        "for_arch",
        "The target architecture string.",
    ) orelse "x86_64";

    const target_operating_system = b.option(
        []const u8,
        "for_os",
        "The target operating system string.",
    ) orelse "linux";

    _ = b.resolveTargetQuery(.{
        .cpu_arch = try cpu_arch_from_string(target_architecture),
        .os_tag = try os_from_string(target_operating_system),
        .abi = .gnu,
    });

    const target = b.standardTargetOptions(.{});

    // target.result = default_target.result;

    // std.debug.print("\nstandardTargetOptions: {any}\n", .{default_target.result});
    std.debug.print("\n\n\nresolveTargetQuery: {any}\n", .{target.result});

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const exe = b.addExecutable(.{
        .name = "battlebuds",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkSystemLibrary("hidapi-libusb");
    // exe.addLibraryPath(std.Build.LazyPath{ .cwd_relative = "/usr/lib/x86_64-linux-gnu" });

    const sdk = sdl.init(b, .{}); // Create a new instance of the SDL2 Sdk. Specifiy dependency name explicitly if necessary (use sdl by default).
    sdk.link(exe, .static, sdl.Library.SDL2); // link SDL2.
    exe.root_module.addImport("sdl2", sdk.getNativeModule()); // Add "sdl2" package that exposes the SDL2 api (like SDL_Init or SDL_CreateWindow).

    exe.root_module.addImport(
        "rgbapng",
        b.dependency("rgbapng", .{
            .target = target,
            .optimize = optimize,
        }).module("rgbapng"),
    );

    // Make building excutable depend on running python scripts.
    const generate_visual_assets = b.addSystemCommand(&[_][]const u8{ "python3", "src/visual_assets.py" });
    const generate_audio_assets = b.addSystemCommand(&[_][]const u8{ "python3", "src/audio_assets.py" });

    exe.step.dependOn(&generate_visual_assets.step);
    exe.step.dependOn(&generate_audio_assets.step);

    b.installArtifact(exe);

    // Make run command step depend on install step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Make run step depend on run command
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
