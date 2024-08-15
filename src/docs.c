// Pasted in from: https://xcb.freedesktop.org/tutorial/basicwindowsanddrawing/

#include <stdint.h>
#include <xcb/xcb.h>
// After we got some basic information about our screen, we can create our first
// window. In the X Window System, a window is characterized by an Id. So, in
// XCB, a window is of type:
typedef uint32_t xcb_window_t;

// We first ask for a new Id for our window, with this function:
xcb_window_t xcb_generate_id(xcb_connection_t *connection);

// Then, XCB supplies the following function to create new windows:
xcb_void_cookie_t xcb_create_window(
    xcb_connection_t
        *connection,     /* Pointer to the xcb_connection_t structure */
    uint8_t depth,       /* Depth of the screen */
    xcb_window_t wid,    /* Id of the window */
    xcb_window_t parent, /* Id of an existing window that should be the parent
                            of the new window */
    int16_t x, /* X position of the top-left corner of the window (in pixels) */
    int16_t y, /* Y position of the top-left corner of the window (in pixels) */
    uint16_t width,        /* Width of the window (in pixels) */
    uint16_t height,       /* Height of the window (in pixels) */
    uint16_t border_width, /* Width of the window's border (in pixels) */
    uint16_t _class, xcb_visualid_t visual, uint32_t value_mask,
    const uint32_t *value_list);

// The fact that we created the window does not mean that it will be drawn on
// screen. By default, newly created windows are not mapped on the screen (they
// are invisible). In order to make our window visible, we use the function
// xcb_map_window(), whose prototype is
xcb_void_cookie_t xcb_map_window(xcb_connection_t *connection,
                                 xcb_window_t window);

// Finally, here is a small program to create a window of size 150x150 pixels,
// positioned at the top-left corner of the screen:
#include <unistd.h> /* pause() */
#include <xcb/xcb.h>

int main() {
  /* Open the connection to the X server */
  xcb_connection_t *connection = xcb_connect(NULL, NULL);

  /* Get the first screen */
  const xcb_setup_t *setup = xcb_get_setup(connection);
  xcb_screen_iterator_t iter = xcb_setup_roots_iterator(setup);
  xcb_screen_t *screen = iter.data;

  /* Create the window */
  xcb_window_t window = xcb_generate_id(connection);
  xcb_create_window(connection,                    /* Connection          */
                    XCB_COPY_FROM_PARENT,          /* depth (same as root)*/
                    window,                        /* window Id           */
                    screen->root,                  /* parent window       */
                    0, 0,                          /* x, y                */
                    150, 150,                      /* width, height       */
                    10,                            /* border_width        */
                    XCB_WINDOW_CLASS_INPUT_OUTPUT, /* class               */
                    screen->root_visual,           /* visual              */
                    0, NULL);                      /* masks, not used yet */

  /* Map the window on the screen */
  xcb_map_window(connection, window);

  /* Make sure commands are sent before we pause so that the window gets shown
   */
  xcb_flush(connection);

  pause(); /* hold client until Ctrl-C */

  xcb_disconnect(connection);

  return 0;
}

// In this code, you see one more function - xcb_flush(), not explained yet. It
// is used to flush all the pending requests. More precisely, there are 2
// functions that do such things.
//
// The first one is xcb_flush():
int xcb_flush(xcb_connection_t *c);

// This function flushes all pending requests to the X server (much like the
// fflush() function is used to flush standard output).
//
// The second function is xcb_aux_sync():
int xcb_aux_sync(xcb_connection_t *c);

// This functions also flushes all pending requests to the X server, and then
// waits until the X server finishing processing these requests. In a normal
// program, this will not be necessary (we'll see why when we get to write a
// normal X program), but for now, we put it there. The window that is created
// by the above code has a non defined background. This one can be set to a
// specific color, thanks to the two last parameters of xcb_create_window(),
// which are not described yet. See the subsections Configuring a window or
// Registering for event types using event masks for examples on how to use
// these parameters. In addition, as no events are handled, you have to make a
// Ctrl-C to interrupt the program.
//
// TODO: one should tell what these functions
// return and about the generic error Comparison Xlib/XCB:

// Drawing in a window can be done using various graphical functions (drawing
// pixels, lines, rectangles, etc). In order to draw in a window, we first need
// to define various general drawing parameters (what line width to use, which
// color to draw with, etc). This is done using a graphical context.

// As we said, a graphical context defines several attributes to be used with
// the various drawing functions. For this, we define a graphical context. We
// can use more than one graphical context with a single window, in order to
// draw in multiple styles (different colors, different line widths, etc). In
// XCB, a Graphics Context is, as a window, characterized by an Id:
typedef uint32_t xcb_gcontext_t;

// We first ask the X server to attribute an Id to our graphic context with this
// function:
xcb_gcontext_t xcb_generate_id(xcb_connection_t *c);

// Then, we set the attributes of the graphic context with this function:
xcb_void_cookie_t xcb_create_gc(xcb_connection_t *c, xcb_gcontext_t cid,
                                xcb_drawable_t drawable, uint32_t value_mask,
                                const uint32_t *value_list);

// We give now an example on how to allocate a graphic context that specifies
// that each drawing function that uses it will draw in foreground with a black
// color.
#include <xcb/xcb.h>

int main() {
  /* Open the connection to the X server and get the first screen */
  xcb_connection_t *connection = xcb_connect(NULL, NULL);
  xcb_screen_t *screen =
      xcb_setup_roots_iterator(xcb_get_setup(connection)).data;

  /* Create a black graphic context for drawing in the foreground */
  xcb_drawable_t window = screen->root;
  xcb_gcontext_t black = xcb_generate_id(connection);
  uint32_t mask = XCB_GC_FOREGROUND;
  uint32_t value[] = {screen->black_pixel};

  xcb_create_gc(connection, black, window, mask, value);

  return 0;
}

// Note should be taken regarding the role of "valuemask" and "valuelist" in the
// prototype of xcb_create_gc(). Since a graphic context has many attributes,
// and since we often just want to define a few of them, we need to be able to
// tell the xcb_create_gc() which attributes we want to set. This is what the
// "valuemask" parameter is for. We then use the "valuelist" parameter to
// specify actual values for the attribute we defined in "valuemask". Thus, for
// each constant used in "valuelist", we will use the matching constant in
// "value_mask". In this case, we define a graphic context with one attribute:
// when drawing (a point, a line, etc), the foreground color will be black. The
// rest of the attributes of this graphic context will be set to their default
// values.

// Once we have allocated a Graphic Context, we may need to change its
// attributes (for example, changing the foreground color we use to draw a line,
// or changing the attributes of the font we use to display strings. See
// Subsections Drawing with a color and Assigning a Font to a Graphic Context).
// This is done by using this function:
xcb_void_cookie_t xcb_change_gc(
    xcb_connection_t *c, /* The XCB Connection */
    xcb_gcontext_t gc,   /* The Graphic Context */
    uint32_t
        value_mask, /* Components of the Graphic Context that have to be set */
    const uint32_t *value_list); /* Value as specified by value_mask */

// The valuemask parameter could take any combination of these masks from the
// xcb_gc_t enumeration:
typedef enum xcb_gc_t {
  XCB_GC_FUNCTION = 1,
  XCB_GC_PLANE_MASK = 2,
  /**< In graphics operations, given a source and destination pixel, the result
  is computed bitwise on corresponding bits of the pixels; that is, a Boolean
  operation is performed in each bit plane. The plane-mask restricts the
  operation to a subset of planes, so the result is:

          ((src FUNC dst) AND plane-mask) OR (dst AND (NOT plane-mask)) */

  XCB_GC_FOREGROUND = 4,
  /**< Foreground colorpixel. */

  XCB_GC_BACKGROUND = 8,
  /**< Background colorpixel. */

  XCB_GC_LINE_WIDTH = 16,
  /**< The line-width is measured in pixels and can be greater than or equal to
  one, a wide line, or the special value zero, a thin line. */

  XCB_GC_LINE_STYLE = 32,
  /**< The line-style defines which sections of a line are drawn:
  Solid                The full path of the line is drawn.
  DoubleDash           The full path of the line is drawn, but the even dashes
  are filled differently than the odd dashes (see fill-style), with Butt
  cap-style used where even and odd dashes meet. OnOffDash            Only the
  even dashes are drawn, and cap-style applies to all internal ends of the
  individual dashes (except NotLast is treated as Butt). */

  XCB_GC_CAP_STYLE = 64,
  /**< The cap-style defines how the endpoints of a path are drawn:
  NotLast    The result is equivalent to Butt, except that for a line-width of
  zero the final endpoint is not drawn. Butt       The result is square at the
  endpoint (perpendicular to the slope of the line) with no projection beyond.
  Round      The result is a circular arc with its diameter equal to the
  line-width, centered on the endpoint; it is equivalent to Butt for line-width
  zero. Projecting The result is square at the end, but the path continues
  beyond the endpoint for a distance equal to half the line-width; it is
  equivalent to Butt for line-width zero. */

  XCB_GC_JOIN_STYLE = 128,
  /**< The join-style defines how corners are drawn for wide lines:
  Miter               The outer edges of the two lines extend to meet at an
  angle. However, if the angle is less than 11 degrees, a Bevel join-style is
  used instead. Round               The result is a circular arc with a diameter
  equal to the line-width, centered on the joinpoint. Bevel               The
  result is Butt endpoint styles, and then the triangular notch is filled. */

  XCB_GC_FILL_STYLE = 256,
  /**< The fill-style defines the contents of the source for line, text, and
  fill requests. For all text and fill requests (for example, PolyText8,
  PolyText16, PolyFillRectangle, FillPoly, and PolyFillArc) as well as for line
  requests with line-style Solid, (for example, PolyLine, PolySegment,
  PolyRectangle, PolyArc) and for the even dashes for line requests with
  line-style OnOffDash or DoubleDash: Solid                     Foreground Tiled
  Tile OpaqueStippled            A tile with the same width and height as
  stipple but with background everywhere stipple has a zero and with foreground
  everywhere stipple has a one Stippled                  Foreground masked by
  stipple For the odd dashes for line requests with line-style DoubleDash: Solid
  Background Tiled                     Same as for even dashes OpaqueStippled
  Same as for even dashes Stippled                  Background masked by stipple
*/

  XCB_GC_FILL_RULE = 512,
  XCB_GC_TILE = 1024,
  /**< The tile/stipple represents an infinite two-dimensional plane with the
  tile/stipple replicated in all dimensions. When that plane is superimposed on
  the drawable for use in a graphics operation, the upper-left corner of some
  instance of the tile/stipple is at the coordinates within the drawable
  specified by the tile/stipple origin. The tile/stipple and clip origins are
  interpreted relative to the origin of whatever destination drawable is
  specified in a graphics request. The tile pixmap must have the same root and
  depth as the gcontext (or a Match error results). The stipple pixmap must have
  depth one and must have the same root as the gcontext (or a Match error
  results). For fill-style Stippled (but not fill-style OpaqueStippled), the
  stipple pattern is tiled in a single plane and acts as an additional clip mask
  to be ANDed with the clip-mask. Any size pixmap can be used for tiling or
  stippling, although some sizes may be faster to use than others. */

  XCB_GC_STIPPLE = 2048,
  /**< The tile/stipple represents an infinite two-dimensional plane with the
  tile/stipple replicated in all dimensions. When that plane is superimposed on
  the drawable for use in a graphics operation, the upper-left corner of some
  instance of the tile/stipple is at the coordinates within the drawable
  specified by the tile/stipple origin. The tile/stipple and clip origins are
  interpreted relative to the origin of whatever destination drawable is
  specified in a graphics request. The tile pixmap must have the same root and
  depth as the gcontext (or a Match error results). The stipple pixmap must have
  depth one and must have the same root as the gcontext (or a Match error
  results). For fill-style Stippled (but not fill-style OpaqueStippled), the
  stipple pattern is tiled in a single plane and acts as an additional clip mask
  to be ANDed with the clip-mask. Any size pixmap can be used for tiling or
  stippling, although some sizes may be faster to use than others. */

  XCB_GC_TILE_STIPPLE_ORIGIN_X = 4096,
  XCB_GC_TILE_STIPPLE_ORIGIN_Y = 8192,
  XCB_GC_FONT = 16384,
  /**< Which font to use for the `ImageText8` and `ImageText16` requests. */

  XCB_GC_SUBWINDOW_MODE = 32768,
  /**< For ClipByChildren, both source and destination windows are additionally
  clipped by all viewable InputOutput children. For IncludeInferiors, neither
  source nor destination window is
  clipped by inferiors. This will result in including subwindow contents in the
  source and drawing through subwindow boundaries of the destination. The use of
  IncludeInferiors with a source or destination window of one depth with mapped
  inferiors of differing depth is not illegal, but the semantics is undefined by
  the core protocol. */

  XCB_GC_GRAPHICS_EXPOSURES = 65536,
  /**< Whether ExposureEvents should be generated (1) or not (0).
  The default is 1. */

  XCB_GC_CLIP_ORIGIN_X = 131072,
  XCB_GC_CLIP_ORIGIN_Y = 262144,
  XCB_GC_CLIP_MASK = 524288,
  /**< The clip-mask restricts writes to the destination drawable. Only pixels
  where the clip-mask has bits set to 1 are drawn. Pixels are not drawn outside
  the area covered by the clip-mask or where the clip-mask has bits set to 0.
  The clip-mask affects all graphics requests, but it does not clip sources. The
  clip-mask origin is interpreted relative to the origin of whatever destination
  drawable is specified in a graphics request. If a pixmap is specified as the
  clip-mask, it must have depth 1 and have the same root as the gcontext (or a
  Match error results). If clip-mask is None, then pixels are always drawn,
  regardless of the clip origin. The clip-mask can also be set with the
  SetClipRectangles request. */

  XCB_GC_DASH_OFFSET = 1048576,
  XCB_GC_DASH_LIST = 2097152,
  XCB_GC_ARC_MODE = 4194304
} xcb_gc_t;

// It is possible to set several attributes at the same time (for example
// setting the attributes of a font and the color which will be used to display
// a string), by OR'ing these values in valuemask. Then valuelist has to be an
// array which lists the value for the respective attributes. These values must
// be in the same order as masks listed above. See Subsection Drawing with a
// color to have an example.

// After we have created a Graphic Context, we can draw on a window using this
// Graphic Context, with a set of XCB functions, collectively called "drawing
// primitives". Let see how they are used.

// To draw a point, or several points, we use:
xcb_void_cookie_t xcb_poly_point(
    xcb_connection_t *c,     /* The connection to the X server */
    uint8_t coordinate_mode, /* Coordinate mode, usually set to
                                XCB_COORD_MODE_ORIGIN */
    xcb_drawable_t
        drawable,      /* The drawable on which we want to draw the point(s) */
    xcb_gcontext_t gc, /* The Graphic Context we use to draw the point(s) */
    uint32_t points_len,        /* The number of points */
    const xcb_point_t *points); /* An array of points */

// The coordinate_mode parameter specifies the coordinate mode. Available values
// are:
typedef enum xcb_coord_mode_t {
  XCB_COORD_MODE_ORIGIN = 0,
  /**< Treats all coordinates as relative to the origin. */

  XCB_COORD_MODE_PREVIOUS = 1
  /**< Treats all coordinates after the first as relative to the previous
     coordinate. */
} xcb_coord_mode_t;

// If XCB_COORD_MODE_PREVIOUS is used, then all points but the first one are
// relative to the immediately previous point. The xcb_point_t type is just a
// structure with two fields (the coordinates of the point):
typedef struct {
  int16_t x;
  int16_t y;
} xcb_point_t;
// You could see an example in xpoints.c

// To draw a line, or a polygonal line, we use:
xcb_void_cookie_t xcb_poly_line(
    xcb_connection_t *c,     /* The connection to the X server */
    uint8_t coordinate_mode, /* Coordinate mode, usually set to
                                XCB_COORD_MODE_ORIGIN */
    xcb_drawable_t
        drawable,        /* The drawable on which we want to draw the line(s) */
    xcb_gcontext_t gc,   /* The Graphic Context we use to draw the line(s) */
    uint32_t points_len, /* The number of points in the polygonal line */
    const xcb_point_t *points); /* An array of points */

// This function will draw the line between the first and the second points,
// then the line between the second and the third points, and so on.

// To draw a segment, or several segments, we use:
xcb_void_cookie_t xcb_poly_segment(
    xcb_connection_t *c, /* The connection to the X server */
    xcb_drawable_t
        drawable, /* The drawable on which we want to draw the segment(s) */
    xcb_gcontext_t gc, /* The Graphic Context we use to draw the segment(s) */
    uint32_t segments_len,          /* The number of segments */
    const xcb_segment_t *segments); /* An array of segments */

// The xcb_segment_t type is just a structure with four fields (the coordinates
// of the two points that define the segment):
typedef struct {
  int16_t x1;
  int16_t y1;
  int16_t x2;
  int16_t y2;
} xcb_segment_t;

// To draw a rectangle, or several rectangles, we use:
xcb_void_cookie_t xcb_poly_rectangle(
    xcb_connection_t *c, /* The connection to the X server */
    xcb_drawable_t
        drawable, /* The drawable on which we want to draw the rectangle(s) */
    xcb_gcontext_t gc, /* The Graphic Context we use to draw the rectangle(s) */
    uint32_t rectangles_len,            /* The number of rectangles */
    const xcb_rectangle_t *rectangles); /* An array of rectangles */

// The xcb_rectangle_t type is just a structure with four fields (the
// coordinates of the top-left corner of the rectangle, and its width and
// height):
typedef struct {
  int16_t x;
  int16_t y;
  uint16_t width;
  uint16_t height;
} xcb_rectangle_t;

// To draw an elliptical arc, or several elliptical arcs, we use:
xcb_void_cookie_t xcb_poly_arc(
    xcb_connection_t *c, /* The connection to the X server */
    xcb_drawable_t
        drawable,      /* The drawable on which we want to draw the arc(s) */
    xcb_gcontext_t gc, /* The Graphic Context we use to draw the arc(s) */
    uint32_t arcs_len, /* The number of arcs */
    const xcb_arc_t *arcs); /* An array of arcs */

// The xcb_arc_t type is a structure with six fields:
typedef struct {
  int16_t
      x; /* Top left x coordinate of the rectangle surrounding the ellipse */
  int16_t
      y; /* Top left y coordinate of the rectangle surrounding the ellipse */
  uint16_t width;  /* Width of the rectangle surrounding the ellipse */
  uint16_t height; /* Height of the rectangle surrounding the ellipse */
  int16_t angle1;  /* Angle at which the arc begins */
  int16_t angle2;  /* Angle at which the arc ends */
} xcb_arc_t;

// Note: the angles are expressed in units of 1/64 of a degree, so to have an
// angle of 90 degrees, starting at 0, angle1 = 0 and angle2 = 90 << 6. Positive
// angles indicate counterclockwise motion, while negative angles indicate
// clockwise motion.

// The corresponding function which fill inside the geometrical object are
// listed below, without further explanation, as they are used as the above
// functions. To Fill a polygon defined by the points given as arguments , we
// use:
xcb_void_cookie_t xcb_fill_poly(xcb_connection_t *c, xcb_drawable_t drawable,
                                xcb_gcontext_t gc, uint8_t shape,
                                uint8_t coordinate_mode, uint32_t points_len,
                                const xcb_point_t *points);

// The shape parameter specifies a shape that helps the server to improve
// performance. Available values are:
typedef enum xcb_poly_shape_t {
  XCB_POLY_SHAPE_COMPLEX = 0,
  XCB_POLY_SHAPE_NONCONVEX = 1,
  XCB_POLY_SHAPE_CONVEX = 2
} xcb_poly_shape_t;

// To fill one or several rectangles, we use:
xcb_void_cookie_t xcb_poly_fill_rectangle(xcb_connection_t *c,
                                          xcb_drawable_t drawable,
                                          xcb_gcontext_t gc,
                                          uint32_t rectangles_len,
                                          const xcb_rectangle_t *rectangles);

// To fill one or several arcs, we use:
xcb_void_cookie_t xcb_poly_fill_arc(xcb_connection_t *c,
                                    xcb_drawable_t drawable, xcb_gcontext_t gc,
                                    uint32_t arcs_len, const xcb_arc_t *arcs);

// To illustrate these functions, here is an example that draws four points, a
// polygonal line, two segments, two rectangles and two arcs. Remark that we use
// events for the first time, as an introduction to the next section.
#include <stdio.h>
#include <stdlib.h>

#include <xcb/xcb.h>

int main() {
  /* geometric objects */
  xcb_point_t points[] = {{10, 10}, {10, 20}, {20, 10}, {20, 20}};

  xcb_point_t polyline[] = {{50, 10},
                            {5, 20}, /* rest of points are relative */
                            {25, -20},
                            {10, 10}};

  xcb_segment_t segments[] = {{100, 10, 140, 30}, {110, 25, 130, 60}};

  xcb_rectangle_t rectangles[] = {{10, 50, 40, 20}, {80, 50, 10, 40}};

  xcb_arc_t arcs[] = {{10, 100, 60, 40, 0, 90 << 6},
                      {90, 100, 55, 40, 0, 270 << 6}};

  /* Open the connection to the X server */
  xcb_connection_t *connection = xcb_connect(NULL, NULL);

  /* Get the first screen */
  xcb_screen_t *screen =
      xcb_setup_roots_iterator(xcb_get_setup(connection)).data;

  /* Create black (foreground) graphic context */
  xcb_drawable_t window = screen->root;
  xcb_gcontext_t foreground = xcb_generate_id(connection);
  uint32_t mask = XCB_GC_FOREGROUND | XCB_GC_GRAPHICS_EXPOSURES;
  uint32_t values[2] = {screen->black_pixel, 0};

  xcb_create_gc(connection, foreground, window, mask, values);

  /* Create a window */
  window = xcb_generate_id(connection);

  mask = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK;
  values[0] = screen->white_pixel;
  values[1] = XCB_EVENT_MASK_EXPOSURE;

  xcb_create_window(connection,                    /* connection          */
                    XCB_COPY_FROM_PARENT,          /* depth               */
                    window,                        /* window Id           */
                    screen->root,                  /* parent window       */
                    0, 0,                          /* x, y                */
                    150, 150,                      /* width, height       */
                    10,                            /* border_width        */
                    XCB_WINDOW_CLASS_INPUT_OUTPUT, /* class               */
                    screen->root_visual,           /* visual              */
                    mask, values);                 /* masks */

  /* Map the window on the screen and flush*/
  xcb_map_window(connection, window);
  xcb_flush(connection);

  /* draw primitives */
  xcb_generic_event_t *event;
  while ((event = xcb_wait_for_event(connection))) {
    switch (event->response_type & ~0x80) {
    case XCB_EXPOSE:
      /* We draw the points */
      xcb_poly_point(connection, XCB_COORD_MODE_ORIGIN, window, foreground, 4,
                     points);

      /* We draw the polygonal line */
      xcb_poly_line(connection, XCB_COORD_MODE_PREVIOUS, window, foreground, 4,
                    polyline);

      /* We draw the segments */
      xcb_poly_segment(connection, window, foreground, 2, segments);

      /* draw the rectangles */
      xcb_poly_rectangle(connection, window, foreground, 2, rectangles);

      /* draw the arcs */
      xcb_poly_arc(connection, window, foreground, 2, arcs);

      /* flush the request */
      xcb_flush(connection);

      break;
    default:
      /* Unknown event type, ignore it */
      break;
    }

    free(event);
  }

  return 0;
}
