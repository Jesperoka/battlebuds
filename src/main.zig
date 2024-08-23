const std = @import("std");
const xcb = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xcb_image.h");
});
// const xcb_image = @cImport({});
const temp = @cImport({
    @cInclude("first_guy.h");
});
// const udev = @cImport({
//     @cInclude("libudev.h");
// });

const shapes = @import("shapes.zig");

fn print(arg: anytype) void {
    std.debug.print("\n{any}\n", .{arg});
}
fn printstr(arg: anytype) void {
    std.debug.print("\n{s}\n", .{arg});
}
const assert = std.debug.assert;
const dump_trace = std.debug.dumpCurrentStackTrace;

const Point = struct {
    x: i16 = undefined,
    y: i16 = undefined,
};
const line_start = Point{};
const line_end = Point{};

const gctx_id = u32; // Graphics context id
const window_id = u32;
const pixmap_id = u32;
const visual_id = u32;
const colormap_id = u32;

fn xcb_check_connection_error(conn: ?*xcb.struct_xcb_connection_t) u8 {
    switch (xcb.xcb_connection_has_error(conn)) {
        0 => return 0,
        xcb.XCB_CONN_ERROR => {
            std.debug.print("\n{s}\n", .{"XCB_CONN_ERROR, because of socket errors, pipe errors or other stream errors."});
            return xcb.XCB_CONN_ERROR;
        },
        xcb.XCB_CONN_CLOSED_EXT_NOTSUPPORTED => {
            std.debug.print("\n{s}\n", .{"XCB_CONN_CLOSED_EXT_NOTSUPPORTED, extension not supported"});
            return xcb.XCB_CONN_CLOSED_EXT_NOTSUPPORTED;
        },
        xcb.XCB_CONN_CLOSED_MEM_INSUFFICIENT => {
            std.debug.print("\n{s}\n", .{"XCB_CONN_CLOSED_MEM_INSUFFICIENT, insufficient memory."});
            return xcb.XCB_CONN_CLOSED_MEM_INSUFFICIENT;
        },
        xcb.XCB_CONN_CLOSED_REQ_LEN_EXCEED => {
            std.debug.print("\n{s}\n", .{"XCB_CONN_CLOSED_REQ_LEN_EXCEED, exceeding request length that server accepts."});
            return xcb.XCB_CONN_CLOSED_REQ_LEN_EXCEED;
        },
        xcb.XCB_CONN_CLOSED_PARSE_ERR => {
            std.debug.print("\n{s}\n", .{"XCB_CONN_CLOSED_PARSE_ERR, error during parsing display string."});
            return xcb.XCB_CONN_CLOSED_PARSE_ERR;
        },
        xcb.XCB_CONN_CLOSED_INVALID_SCREEN => {
            std.debug.print("\n{s}\n", .{"XCB_CONN_CLOSED_INVALID_SCREEN, server does not have a screen matching the display."});
            return xcb.XCB_CONN_CLOSED_INVALID_SCREEN;
        },
        else => unreachable,
    }
}

fn create_graphics_context(conn: ?*xcb.struct_xcb_connection_t, screen: *xcb.struct_xcb_screen_t, did: u32) struct { gctx_id, xcb.xcb_void_cookie_t } {
    const mask: u32 = xcb.XCB_GC_FOREGROUND | xcb.XCB_GC_BACKGROUND;
    const values = [_]u32{ screen.white_pixel, screen.black_pixel };
    const gid: gctx_id = xcb.xcb_generate_id(conn);
    const cookie: xcb.xcb_void_cookie_t = xcb.xcb_create_gc(conn, gid, did, mask, &values);

    return .{ gid, cookie };
}

fn create_window(conn: ?*xcb.struct_xcb_connection_t, screen: *xcb.struct_xcb_screen_t, x: i16, y: i16, width: u16, height: u16, border_width: u16) struct { window_id, xcb.xcb_void_cookie_t } {
    const mask: u32 = xcb.XCB_CW_EVENT_MASK;
    const values = [_]u32{xcb.XCB_EVENT_MASK_KEY_PRESS};
    const wid: window_id = xcb.xcb_generate_id(conn);
    const class: u16 = xcb.XCB_WINDOW_CLASS_INPUT_OUTPUT;
    const cookie: xcb.xcb_void_cookie_t = xcb.xcb_create_window(conn, screen.root_depth, wid, screen.root, x, y, width, height, border_width, class, screen.root_visual, mask, &values);

    return .{ wid, cookie };
}

fn create_pixmap(conn: ?*xcb.struct_xcb_connection_t, wid: window_id, width: u16, height: u16) struct { pixmap_id, xcb.xcb_void_cookie_t } {
    const pid: pixmap_id = xcb.xcb_generate_id(conn);
    const cookie: xcb.xcb_void_cookie_t = xcb.xcb_create_pixmap(conn, xcb.XCB_COPY_FROM_PARENT, pid, wid, width, height);

    return .{ pid, cookie };
}

fn find_format_by_depth(setup: *const xcb.xcb_setup_t, depth: u8) ?*xcb.xcb_format_t {
    const format: *xcb.xcb_format_t = xcb.xcb_setup_pixmap_formats(setup);
    var format_int: usize = @intFromPtr(format);
    print(format_int);

    const format_length: usize = @intCast(xcb.xcb_setup_pixmap_formats_length(setup));
    print(format_length);

    const format_end: usize = format_int + format_length;
    print(format_end);

    while (format_int != format_end) {
        const format_ptr: *xcb.xcb_format_t = @ptrFromInt(format_int);
        print(format_int);
        print(format_ptr);
        if (format_ptr.depth == depth) {
            print(format_ptr.depth);
            return format_ptr;
        }

        format_int += 1;
    }
    return null;
}

fn create_image(conn: anytype, pid: pixmap_id, gid: gctx_id, x: i16, y: i16, width: u16, height: u16, data_ptr: [*]u8, size: u32) struct { *xcb.xcb_image_t, xcb.xcb_void_cookie_t } {
    // const setup: *const xcb.xcb_setup_t = xcb.xcb_get_setup(conn);
    // const format: *xcb.xcb_format_t = find_format_by_depth(setup, fmt.depth).?;
    // print(format);
    // const image: ?*xcb.xcb_image_t = xcb.xcb_image_create(width, height, xcb.XCB_IMAGE_FORMAT_Z_PIXMAP, format.scanline_pad, format.depth, format.bits_per_pixel, 0, setup.image_byte_order, xcb.XCB_IMAGE_ORDER_LSB_FIRST, data_ptr, size, data_ptr);

    _ = size;
    // _ = data_ptr;

    const plane_mask = 0;
    var image: ?*xcb.xcb_image_t = xcb.xcb_image_get(conn, pid, x, y, width, height, plane_mask, xcb.XCB_IMAGE_FORMAT_Z_PIXMAP);

    // const image: ?*xcb.xcb_image_t = xcb.xcb_image_create_native(conn, width, height, xcb.XCB_IMAGE_FORMAT_Z_PIXMAP, fmt.depth, data_ptr, size, data_ptr);
    printstr("HERE");
    print(image);
    printstr("HERE");

    image.?.data = data_ptr;
    image.?.base = xcb.NULL;

    printstr("HERE");
    print(image);
    printstr("HERE");

    const cookie: xcb.xcb_void_cookie_t = xcb.xcb_image_put(conn, pid, gid, image.?, x, y, 0);

    return .{ image.?, cookie };
}

const fmt = struct {
    const width = 20;
    const height = 20;
    const bits_per_pixel = 32;
    const scanline_pad = 32;
    const bytes_per_row = @divExact(round_to_multiple(bits_per_pixel * width, scanline_pad), 8); // a.k.a. stride
    const size = width * height * bits_per_pixel;
    const left_pad = 0;
    const data_length = height * bytes_per_row;
    const depth = 32; // taken from screen
};

fn round_to_multiple(num: u32, mul: u32) u32 {
    assert(mul != 0);
    const remainder = num % mul;

    return if (remainder == 0) num else num + mul - remainder;
}

fn on_key_press(xcb_event: *xcb.xcb_generic_event_t, conn: ?*xcb.struct_xcb_connection_t, wid: u32, gid: u32, pid: u32) bool {
    std.debug.print("\n{s}", .{"on_key_press"});
    const xcb_rect = shapes.tiny_square(50, 50);
    _ = xcb_rect;

    // const img_ptr: [*]const u8 = @ptrCast(shapes.first_guy);
    const img_ptr = @constCast(temp.first_guy[0]);
    print(@TypeOf(img_ptr));

    const y = 0;
    const x = 0;
    _, _ = create_image(conn, pid, gid, x, y, fmt.width, fmt.height, img_ptr.?, fmt.size);

    print(xcb.xcb_copy_area(conn, pid, wid, gid, 0, 0, x, y, fmt.width, fmt.height));
    // _ = pid;

    switch (parse_key_press_event(xcb_event)) {
        24, 9 => |val| {
            print(val);
            return true;
        },
        else => |val| print(val),
    }
    return false;
}

fn parse_key_press_event(xcb_event: *xcb.xcb_generic_event_t) u32 {
    const casted_xcb_event: *xcb.xcb_key_press_event_t = @ptrCast(xcb_event);

    return casted_xcb_event.detail;
}

fn parse_generic_event(xcb_event: *xcb.xcb_generic_event_t) i32 {
    return xcb_event.response_type & ~@as(c_int, 0x80);
}

fn event_loop(conn: ?*xcb.struct_xcb_connection_t, wid: window_id, gid: gctx_id, pid: pixmap_id) void {
    var xcb_event_type: i32 = undefined;
    var xcb_event: *xcb.xcb_generic_event_t = undefined;

    loop: while (true) {
        const xcb_packet: ?*xcb.xcb_generic_event_t = xcb.xcb_poll_for_event(conn);
        defer if (xcb_packet) |event| std.heap.raw_c_allocator.destroy(event);

        if (xcb_packet) |event| {
            xcb_event_type = parse_generic_event(event);
            xcb_event = event;
        } else {
            continue;
        }

        switch (xcb_event_type) {
            xcb.XCB_KEY_PRESS => {
                if (on_key_press(xcb_event, conn, wid, gid, pid)) break :loop;
            },
            else => {},
        }
        assert(xcb.xcb_flush(conn) > 0);
    }
}

// xcb_void_cookie_t xcb_put_image (
//                xcb_connection_t *c,
//                uint8_t           format,
//                xcb_drawable_t    drawable,
//                xcb_gcontext_t    gc,
//                uint16_t          width,
//                uint16_t          height,
//                int16_t           dst_x,
//                int16_t           dst_y,
//                uint8_t           left_pad,
//                uint8_t           depth,
//                uint32_t          data_len,
//                const uint8_t    *data);

pub fn main() !void {
    std.debug.print("{s}", .{"Program Start\n"});
    std.debug.print("{s}", .{temp.first_guy});

    std.debug.print("\n\n{any}\n\n", .{xcb.XCB_KEY_PRESS});
    std.debug.print("\n\n{any}\n\n", .{xcb.XCB_EXPOSE});

    var cookie: xcb.xcb_void_cookie_t = undefined;

    const conn = xcb.xcb_connect(null, null);
    defer xcb.xcb_disconnect(conn);
    assert(xcb_check_connection_error(conn) == 0);
    const setup = xcb.xcb_get_setup(conn);
    print(setup);

    const screen: *xcb.xcb_screen_t = xcb.xcb_setup_roots_iterator(xcb.xcb_get_setup(conn)).data;
    const wid: window_id, cookie = create_window(conn, screen, 0, 0, 1920, 1080, 0);
    print(cookie);

    cookie = xcb.xcb_map_window(conn, wid);
    print(cookie);

    assert(xcb.xcb_flush(conn) > 0);

    const gid: gctx_id, cookie = create_graphics_context(conn, screen, wid);
    print(cookie);
    defer print(xcb.xcb_free_gc(conn, gid));

    const pid: pixmap_id, cookie = create_pixmap(conn, wid, fmt.width, fmt.height);
    print(cookie);
    defer print(xcb.xcb_free_pixmap(conn, pid));

    assert(xcb.xcb_flush(conn) > 0);

    event_loop(conn, wid, gid, pid);

    std.debug.print("{s}", .{"\nProgram End\n"});
}
