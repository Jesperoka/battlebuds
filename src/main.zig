// Keeping everything in main until it becomes too big.
const std = @import("std");
const c_libdrm = @cImport(@cInclude("xf86drm.h"));
const c_drmmode = @cImport(@cInclude("xf86drmMode.h"));
// const c_math = @cImport(@cInclude("math.h"));
const c_fcntl = @cImport(@cInclude("fcntl.h"));
const c_inttypes = @cImport(@cInclude("inttypes.h"));
const c_stdio = @cImport(@cInclude("stdio.h"));
const c_unistd = @cImport(@cInclude("unistd.h"));

// Convenience print
fn print(arg: anytype) void {
    switch (@typeInfo(@TypeOf(arg))) {
        .Float, .ComptimeFloat, .Int, .ComptimeInt => std.debug.print("\n{d}\n", .{arg}),
        else => std.debug.print("\n{any}\n", .{arg}),
    }
}

// Some resources for drm:
// - https://github.com/ascent12/drm_doc
// - https://github.com/dvdhrm/docs/tree/master/drm-howto
// - https://github.com/rdkcentral/rdk-halif-libdrm
// - https://manpages.debian.org/unstable/libdrm-dev/drm.7.en.html
// - https://manpages.debian.org/unstable/libdrm-dev/drm-memory.7.en.html
// - https://www.youtube.com/watch?v=haes4_Xnc5Q
// - https://www.baeldung.com/linux/gui#drm-and-dri
// - https://gist.github.com/uobikiemukot/c2be4d7515e977fd9e85
// - https://williamaadams.wordpress.com/2015/09/26/spelunking-linux-drawing-on-libdrm/
// - https://sources.debian.org/src/libdrm/2.4.97-1/xf86drmMode.h/
// - https://medium.com/@lei.wang.sg/render-graphics-with-drm-on-linux-5ce35a932f83
// - https://ignitarium.com/3d-graphics-driver-for-linux-drm-implementation/
// - https://dri.freedesktop.org/docs/drm/gpu/drm-uapi.html
//
// NVIDIA and libdrm:
// - https://download.nvidia.com/XFree86/Linux-x86_64/396.51/README/kms.html

const gpu_path = "/dev/dri/card0"; // hardcoded for now

fn conn_str(conn_type: u32) []const u8 {
    switch (conn_type) {
        c_libdrm.DRM_MODE_CONNECTOR_Unknown => return "Unknown",
        c_libdrm.DRM_MODE_CONNECTOR_VGA => return "VGA",
        c_libdrm.DRM_MODE_CONNECTOR_DVII => return "DVI-I",
        c_libdrm.DRM_MODE_CONNECTOR_DVID => return "DVI-D",
        c_libdrm.DRM_MODE_CONNECTOR_DVIA => return "DVI-A",
        c_libdrm.DRM_MODE_CONNECTOR_Composite => return "Composite",
        c_libdrm.DRM_MODE_CONNECTOR_SVIDEO => return "SVIDEO",
        c_libdrm.DRM_MODE_CONNECTOR_LVDS => return "LVDS",
        c_libdrm.DRM_MODE_CONNECTOR_Component => return "Component",
        c_libdrm.DRM_MODE_CONNECTOR_9PinDIN => return "DIN",
        c_libdrm.DRM_MODE_CONNECTOR_DisplayPort => return "DP",
        c_libdrm.DRM_MODE_CONNECTOR_HDMIA => return "HDMI-A",
        c_libdrm.DRM_MODE_CONNECTOR_HDMIB => return "HDMI-B",
        c_libdrm.DRM_MODE_CONNECTOR_TV => return "TV",
        c_libdrm.DRM_MODE_CONNECTOR_eDP => return "eDP",
        c_libdrm.DRM_MODE_CONNECTOR_VIRTUAL => return "Virtual",
        c_libdrm.DRM_MODE_CONNECTOR_DSI => return "DSI",
        else => return "Unknown",
    }
}

fn refresh_rate(mode: *c_drmmode.drmModeModeInfo) u32 {

    // int res = (mode->clock * 1000000LL / mode->htotal + mode->vtotal / 2) / mode->vtotal;
    //
    // print(@TypeOf(mode.vtotal));

    var res: u32 = (@divTrunc(mode.clock * 1000000, mode.htotal) + @divTrunc(mode.vtotal, 2)) / mode.vtotal;

    if (mode.flags & c_libdrm.DRM_MODE_FLAG_INTERLACE != 0) {
        res *= 2;
    }
    if (mode.flags & c_libdrm.DRM_MODE_FLAG_DBLSCAN != 0) {
        res /= 2;
    }
    if (mode.vscan > 1) {
        res /= mode.vscan;
    }

    return res;
}

pub fn main() !void {
    const drm_file_descriptor: c_int = c_fcntl.open(gpu_path, c_fcntl.O_RDWR | c_fcntl.O_NONBLOCK);
    const errno: c_int = c_unistd.close(drm_file_descriptor);
    print(errno);
    print(drm_file_descriptor);
    // const drm_file_descriptor: c_int = 0;

    const resource: c_drmmode.drmModeResPtr = c_drmmode.drmModeGetResources(drm_file_descriptor) orelse std.debug.panic("{s}", .{"\nERROR: drmModeGetResources() returned NULL \n"});

    defer c_drmmode.drmModeFreeResources(resource);

    print(resource.*.count_connectors);
    for (0..@intCast(resource.*.count_connectors)) |conn_idx| {
        const connector: c_drmmode.drmModeConnectorPtr = c_drmmode.drmModeGetConnector(drm_file_descriptor, resource.*.connectors[conn_idx]).?;
        defer c_drmmode.drmModeFreeConnector(connector);

        std.debug.print("{d}:{s}", .{ conn_idx, conn_str(connector.*.connector_type) });

        for (0..@intCast(connector.*.count_modes)) |mode_idx| {
            const mode: c_drmmode.drmModeModeInfoPtr = &(connector.*.modes[mode_idx]);
            std.debug.print("{d}:{d}", .{ mode_idx, refresh_rate(mode.?) });
        }
    }
}
