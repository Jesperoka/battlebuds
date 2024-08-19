const std = @import("std");
const xcb = @cImport({
    @cInclude("xcb/xcb.h");
    // @cInclude("xcb/xproto.h");
    // @cInclude("xcb/xcb_image.h");
});
// const shm = @cImport({
//     @cInclude("xcb/shm.h");
// });
const temp = @cImport({
    @cInclude("temp.c");
});
// const xpm = @cImport({
//     @cInclude("libxpm.h");
// });
// const udev = @cImport({
//     @cInclude("libudev.h");
// });

const shapes = @import("shapes.zig");

fn print(arg: anytype) void {
    std.debug.print("\n{any}\n", .{arg});
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

fn xcb_check_connection_error(conn: anytype) u8 {
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

fn create_graphics_context(conn: anytype, screen: *xcb.struct_xcb_screen_t, did: u32) struct { gctx_id, xcb.xcb_void_cookie_t } {
    const mask: u32 = xcb.XCB_GC_FOREGROUND | xcb.XCB_GC_BACKGROUND;
    const values = [_]u32{ screen.white_pixel, screen.black_pixel };
    const gid: gctx_id = xcb.xcb_generate_id(conn);
    const cookie: xcb.xcb_void_cookie_t = xcb.xcb_create_gc(conn, gid, did, mask, &values);

    return .{ gid, cookie };
}

fn create_window(conn: anytype, screen: *xcb.struct_xcb_screen_t, x: i16, y: i16, width: u16, height: u16, border_width: u16) struct { window_id, xcb.xcb_void_cookie_t } {
    const mask: u32 = xcb.XCB_CW_EVENT_MASK;
    const values = [_]u32{xcb.XCB_EVENT_MASK_KEY_PRESS};
    const wid: window_id = xcb.xcb_generate_id(conn);
    const class: u16 = xcb.XCB_WINDOW_CLASS_INPUT_OUTPUT;
    const cookie: xcb.xcb_void_cookie_t = xcb.xcb_create_window(conn, screen.root_depth, wid, screen.root, x, y, width, height, border_width, class, screen.root_visual, mask, &values);

    return .{ wid, cookie };
}

fn create_pixmap(conn: anytype, wid: window_id, width: u16, height: u16) struct { pixmap_id, xcb.xcb_void_cookie_t } {
    const pid: pixmap_id = xcb.xcb_generate_id(conn);
    const cookie: xcb.xcb_void_cookie_t = xcb.xcb_create_pixmap(conn, xcb.XCB_COPY_FROM_PARENT, pid, wid, width, height);

    return .{ pid, cookie };
}

const xcb_generic_event_t = extern struct {
    response_type: u8, // Type of the response
    pad0: u8, // Padding
    sequence: u16, // Sequence number
    pad: [7]u32, // Padding
    full_sequence: u32, // Full sequence
};

const fmt = struct {
    const width = 20;
    const height = 20;
    const bits_per_pixel = 32;
    const scanline_pad = 32;
    const bytes_per_row = @divExact(round_to_multiple(bits_per_pixel * width, scanline_pad), 8); // a.k.a. stride
    const size = width * height * bits_per_pixel;
    const left_pad = 0;
    const data_length = height * bytes_per_row;
    const depth = 24; // taken from screen
};

fn round_to_multiple(num: u32, mul: u32) u32 {
    assert(mul != 0);
    const remainder = num % mul;

    return if (remainder == 0) num else num + mul - remainder;
}

// maximum request size:  16777212 bytes
// motion buffer size:  256
// bitmap unit, bit order, padding:    32, LSBFirst, 32
// image byte order:    LSBFirst
// number of supported pixmap formats:    7
// supported pixmap formats:
//     depth 1, bits_per_pixel 1, scanline_pad 32
//     depth 4, bits_per_pixel 8, scanline_pad 32
//     depth 8, bits_per_pixel 8, scanline_pad 32
//     depth 15, bits_per_pixel 16, scanline_pad 32
//     depth 16, bits_per_pixel 16, scanline_pad 32
//     depth 24, bits_per_pixel 32, scanline_pad 32
//     depth 32, bits_per_pixel 32, scanline_pad 32
// keycode range:    minimum 8, maximum 255

fn on_key_press(xcb_event: *xcb.xcb_generic_event_t, conn: anytype, wid: u32, gid: u32, pid: u32) bool {
    std.debug.print("\n{s}", .{"on_key_press"});
    // const x: i16, const y: i16, const width: u16, const height: u16 = .{ 50, 50, 250, 250 };
    const NUM_RECT = 1;
    // const xcb_rect = xcb.xcb_rectangle_t{ .x = x, .y = y, .width = width, .height = height };
    const xcb_rect = shapes.tiny_square(50, 50);

    // _ = xcb.xcb_clear_area(conn, 1, wid, 0, 0, 20, 20);
    _ = xcb.xcb_poly_fill_rectangle(conn, wid, gid, NUM_RECT, &xcb_rect);

    const img_ptr: [*]const u8 = @ptrCast(&shapes.first_guy);
    print(69);
    print(@TypeOf(img_ptr));
    print(69);

    const x = 0;
    const y = 0;

    _ = xcb.xcb_put_image(conn, xcb.XCB_IMAGE_FORMAT_Z_PIXMAP, pid, gid, fmt.width, fmt.height, x, y, fmt.left_pad, fmt.depth, fmt.data_length, img_ptr);
    _ = xcb.xcb_copy_area(conn, pid, wid, gid, 0, 0, x, y, fmt.width, fmt.height);

    // xcb_void_cookie_t
    // xcb_put_image (xcb_connection_t *c,
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
    //

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

fn event_loop(conn: anytype, wid: window_id, gid: gctx_id, pid: pixmap_id) void {
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
        if (xcb.xcb_flush(conn) == 0) {
            std.debug.panic("{s}", .{"Error when flushing."});
        }
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
    std.debug.print("{any}", .{shapes.first_guy});
    // std.debug.print("{s}", .{temp.first_guy});

    std.debug.print("\n\n{any}\n\n", .{xcb.XCB_KEY_PRESS});
    std.debug.print("\n\n{any}\n\n", .{xcb.XCB_EXPOSE});

    var cookie: xcb.xcb_void_cookie_t = undefined;

    const conn = xcb.xcb_connect(null, null);
    defer xcb.xcb_disconnect(conn);
    assert(xcb_check_connection_error(conn) == 0);

    const screen: *xcb.xcb_screen_t = xcb.xcb_setup_roots_iterator(xcb.xcb_get_setup(conn)).data;
    const wid: window_id, _ = create_window(conn, screen, 0, 0, 1920, 1080, 0);
    cookie = xcb.xcb_map_window(conn, wid);
    print(cookie);
    assert(xcb.xcb_flush(conn) > 0);

    const gid: gctx_id, _ = create_graphics_context(conn, screen, wid);
    defer print(xcb.xcb_free_gc(conn, gid));

    const pid: pixmap_id, _ = create_pixmap(conn, wid, fmt.width, fmt.height);

    _ = xcb.xcb_flush(conn);

    event_loop(conn, wid, gid, pid);

    std.debug.print("{s}", .{"\nProgram End\n"});
}
