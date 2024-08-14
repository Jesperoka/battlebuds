const std = @import("std");
const xcb = @cImport(@cInclude("xcb/xcb.h"));

const Point = struct {
    x: i16 = undefined,
    y: i16 = undefined,
};
const line_start = Point{};
const line_end = Point{};

const xcb_screen_t = extern struct {
    root: u32,
    default_colormap: u32,
    white_pixel: u32,
    black_pixel: u32,
    current_input_masks: u32,
    width_in_pixels: u16,
    height_in_pixels: u16,
    width_in_millimeters: u16,
    height_in_millimeters: u16,
    min_installed_maps: u16,
    max_installed_maps: u16,
    root_visual: u32,
    backing_stores: u8,
    save_unders: u8,
    root_depth: u8,
    allowed_depths_len: u8,
};

const xcb_void_cookie_t = extern struct {
    sequence: u32, // Sequence number
};

const xcb_rectangle_t = extern struct {
    x: i16,
    y: i16,
    width: u16,
    height: u16,
};

fn create_window(conn: anytype, screen: *xcb_screen_t) struct { u32, u32, u32, u32 } {
    var mask: u32 = xcb.XCB_GC_BACKGROUND | xcb.XCB_GC_GRAPHICS_EXPOSURES;

    var values: *[2]u32 = @constCast(&[2]u32{ screen.black_pixel, 0 });
    const foreground: u32 = xcb.xcb_generate_id(conn);
    var cookie: *const xcb_void_cookie_t = @ptrCast(&xcb.xcb_create_gc(conn, foreground, screen.root, mask, values));
    std.debug.print("\nGC context cookie: {any}\n", .{cookie.*});

    const pid: u32 = xcb.xcb_generate_id(conn);
    cookie = @ptrCast(&xcb.xcb_create_pixmap(conn, screen.root_depth, pid, screen.root, 500, 500));
    std.debug.print("\nPixmap cookie: {any}\n", .{cookie.*});

    const fill: u32 = xcb.xcb_generate_id(conn);
    mask = xcb.XCB_GC_FOREGROUND | xcb.XCB_GC_BACKGROUND;
    values = @constCast(&.{ screen.white_pixel, screen.white_pixel });
    cookie = @ptrCast(&xcb.xcb_create_gc(conn, fill, pid, mask, values));
    std.debug.print("\nGC context cookie: {any}\n", .{cookie.*});

    const win: u32 = xcb.xcb_generate_id(conn);
    mask = xcb.XCB_CW_BACK_PIXMAP | xcb.XCB_CW_EVENT_MASK;

    values = @constCast(&.{ pid, xcb.XCB_EVENT_MASK_EXPOSURE | xcb.XCB_EVENT_MASK_BUTTON_PRESS |
        xcb.XCB_EVENT_MASK_BUTTON_RELEASE | xcb.XCB_EVENT_MASK_BUTTON_MOTION |
        xcb.XCB_EVENT_MASK_KEY_PRESS | xcb.XCB_EVENT_MASK_KEY_RELEASE });

    cookie = @ptrCast(&xcb.xcb_create_window(conn, screen.root_depth, win, screen.root, 0, 0, 150, 150, 10, xcb.XCB_WINDOW_CLASS_INPUT_OUTPUT, screen.root_visual, mask, values));
    std.debug.print("\nCreate window cookie: {any}\n", .{cookie.*});

    cookie = @ptrCast(&xcb.xcb_map_window(conn, win));
    std.debug.print("\nMap window: {any}\n", .{cookie.*});

    const xcb_rect: *const xcb.xcb_rectangle_t = @ptrCast(&xcb_rectangle_t{ .x = 0, .y = 0, .width = 500, .height = 500 });
    cookie = @ptrCast(&xcb.xcb_poly_fill_rectangle(conn, pid, fill, 1, xcb_rect));

    return .{ win, pid, foreground, fill };
}

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

const xcb_generic_event_t = extern struct {
    response_type: u8, // Type of the response
    pad0: u8, // Padding
    sequence: u16, // Sequence number
    pad: [7]u32, // Padding
    full_sequence: u32, // Full sequence
};

fn parse_event(xcb_event: *const xcb_generic_event_t) i32 {
    return xcb_event.response_type & ~@as(i32, 0x80);
}

fn on_key_press(conn: anytype, win: u32, pid: u32, fill: u32) void {
    const x, const y, const width, const height = .{ 0, 0, 500, 500 };
    const xcb_rect: *const xcb.xcb_rectangle_t = @ptrCast(&xcb_rectangle_t{ .x = x, .y = y, .width = width, .height = height });
    _ = xcb.xcb_poly_fill_rectangle_checked(conn, pid, fill, 1, xcb_rect);
    _ = xcb.xcb_clear_area(conn, 1, win, x, y, width, height);
}

fn event_loop(conn: anytype, win: u32, pid: u32, _: u32, fill: u32) void {
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const xcb_event: *const xcb_generic_event_t = @ptrCast(&xcb.xcb_wait_for_event(conn));
        std.debug.print("\nevent type: {any}", .{parse_event(xcb_event)});

        switch (parse_event(xcb_event)) {
            xcb.XCB_KEY_PRESS => on_key_press(conn, win, pid, fill),
            else => {},
        }
        _ = xcb.xcb_flush(conn);
    }
}

// void event_loop() {
//   xcb_generic_event_t *e;
//   while ((e = xcb_wait_for_event(c))) {
//     switch (e->response_type & ~0x80) {

//     case XCB_KEY_PRESS: {
//       /* fill pixmap with white */
//       /* why isn't this happening */
//       xcb_poly_fill_rectangle_checked(c, pid, fill, 1,
//                                       (xcb_rectangle_t[]){{0, 0, 500, 500}});

//       /* clear win to reveal pixmap */
//       xcb_clear_area(c, 1, win, 0, 0, 500, 500);

//       xcb_flush(c);
//       break;
//     }

//     case XCB_MOTION_NOTIFY: {
//       xcb_motion_notify_event_t *ev = (xcb_motion_notify_event_t *)e;

//       /*
//         1. clear the area on the win between line_start and mouse_pos (or whole
//         win)
//         2. update mouse_pos
//         3. draw line from line_start to mouse_pos
//       */
//       xcb_clear_area(c, 1, win, 0, 0, 500, 500);
//       xcb_point_t mouse_pos = {(ev->event_x - line_start.x),
//                                (ev->event_y - line_start.y)};
//       xcb_point_t points[] = {line_start, mouse_pos};
//       xcb_poly_line(c, XCB_COORD_MODE_PREVIOUS, win, foreground, 2, points);

//       xcb_flush(c);
//       break;
//     }

//     case XCB_BUTTON_PRESS: {
//       xcb_button_press_event_t *ev = (xcb_button_press_event_t *)e;
//       line_start = (xcb_point_t){ev->event_x, ev->event_y};
//       xcb_flush(c);
//       break;
//     }

//     case XCB_BUTTON_RELEASE: {
//       xcb_button_release_event_t *ev = (xcb_button_release_event_t *)e;

//       line_end = (xcb_point_t){(ev->event_x - line_start.x),
//                                (ev->event_y - line_start.y)};

//       xcb_point_t points[] = {line_start, line_end};
//       xcb_poly_line(c, XCB_COORD_MODE_PREVIOUS, pid, foreground, 2, points);
//       xcb_poly_line(c, XCB_COORD_MODE_PREVIOUS, win, foreground, 2, points);

//       xcb_flush(c);
//       break;
//     }
//     case XCB_EXPOSE: {

//       xcb_flush(c);
//       break;
//     }
//     default: {
//       break;
//     }
//     }
//     free(e);
//   }
// }

pub fn main() !void {
    std.debug.print("{s}", .{"Program Start\n"});

    const conn = xcb.xcb_connect(null, null);
    defer xcb.xcb_disconnect(conn);
    _ = xcb_check_connection_error(conn);

    const screen: *xcb_screen_t = @ptrCast(xcb.xcb_setup_roots_iterator(xcb.xcb_get_setup(conn)).data);
    const win: u32, const pid: u32, const foreground: u32, const fill: u32 = create_window(conn, screen);
    _ = xcb.xcb_flush(conn);
    event_loop(conn, win, pid, foreground, fill);

    // const c_screen = xcb.xcb_setup_roots_iterator(xcb.xcb_get_setup(conn)).data;
    // std.debug.print("{any}", .{c_screen[0]});

    // std.debug.print("{any}", .{screen.root_visual});

    std.debug.print("\n{any}", .{conn});
    std.debug.print("\n{any}", .{@TypeOf(screen)});

    std.debug.print("{s}", .{"\nProgram End\n"});
}
