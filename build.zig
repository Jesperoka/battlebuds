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
    // const target_architecture = b.option(
    //     []const u8,
    //     "for_arch",
    //     "The target architecture string.",
    // ) orelse "x86_64";
    //
    // const target_operating_system = b.option(
    //     []const u8,
    //     "for_os",
    //     "The target operating system string.",
    // ) orelse "linux";
    //
    //
    // const target = b.resolveTargetQuery(.{
    //     .cpu_arch = try cpu_arch_from_string(target_architecture),
    //     .os_tag = try os_from_string(target_operating_system),
    // });

    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{.preferred_optimize_mode = .ReleaseSafe });

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

    //
    // const libpng_include_path = std.Build.LazyPath{.cwd_relative = "/usr/include/libpng16" };
    // exe.addIncludePath(libpng_include_path);
    //
    // const libpng_obj_path = std.Build.LazyPath{.cwd_relative = "/usr/lib/x86_64-linux-gnu/libpng16.a" };
    // exe.addObjectFile(libpng_obj_path);

    // Create a new instance of the SDL2 Sdk. Specifiy dependency name explicitly if necessary (use sdl by default) /
    const sdk = sdl.init(b, .{});

    // link SDL2
    sdk.link(exe, .static, sdl.Library.SDL2);

    // Add "sdl2" package that exposes the SDL2 api (like SDL_Init or SDL_CreateWindow)
    exe.root_module.addImport("sdl2", sdk.getNativeModule());

    // Make building excutable depend on running python script.
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
