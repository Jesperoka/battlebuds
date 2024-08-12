// Keeping everything in main until it becomes too big.
const std = @import("std");
const c_libdrm = @cImport({
    @cInclude("xf86drm.h");
    @cInclude("xf86drmMode.h");
});
const c_math = @cImport(@cInclude("math.h"));

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
//

pub fn main() !void {
    std.debug.print("{d}", .{c_math.sin(0.57)});
    std.debug.print("{s}", .{"\n\n\n"});
    std.debug.print("{d}", .{c_libdrm.DRM_MODE_CONNECTOR_TV});

    std.debug.print("{s}", .{"\n"});
}
