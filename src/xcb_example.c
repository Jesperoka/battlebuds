/* It's a good idea to paste this and other long code examples
   into a text editor for easier reading */

#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <xcb/xcb.h>
#define NUM_NAMES 500
/*
    NOTE: For concision, we're going to be cheesy and use arrays where real code
    would use points and memory allocation.s
*/
#ifndef __GNUC__
char *strdup(const char *s) {
  int n = strlen(s) + 1;

  char *dup = malloc(n);

  if (dup)
    strcpy(dup, s);

  return dup;
}
#endif

/*
    return interval of time (uses time.h)
*/
double get_time(void) {
  struct timeval timev;
  gettimeofday(&timev, NULL);
  return (double)timev.tv_sec + (((double)timev.tv_usec) / 1000000);
}

/*

*/
void useXlib(char **names, Display *display) {

  Atom atoms[NUM_NAMES];
  for (int i = 0; i < NUM_NAMES; ++i) {
    atoms[i] = XInternAtom(display, names[i], 0);
  }
}

/*
Request all atoms at once.
*/
void useXlibProperly(char **names, Display *display) {

  Atom atoms[NUM_NAMES];
  if (!XInternAtoms(display, names, NUM_NAMES, 0, atoms))
    fprintf(stderr, "XInternAtoms failed\n");
}

/*

*/
void useXCBPoorly(char **names, xcb_connection_t *connection) {
  xcb_atom_t atoms[NUM_NAMES];
  // in this bad use of xcb, we use the cookie immediately after posting the
  // request with xcb_intern_atom
  for (int i = 0; i < NUM_NAMES; ++i) {
    /* make request */
    xcb_intern_atom_cookie_t cookie =
        xcb_intern_atom(connection, 0, strlen(names[i]), names[i]);
    /* get response */
    xcb_intern_atom_reply_t *reply =
        xcb_intern_atom_reply(connection, cookie,
                              NULL); // normally a pointer to receive error, but
                                     // we'll just ignore error handling
    if (reply) {
      atoms[i] = reply->atom;
      free(reply);
    }
  }
  // now we have our atoms (replies), but this is just a demo, so we do nothing
  // with them
}

/*
 */
void useXCBProperly(char **names, xcb_connection_t *connection) {
  xcb_atom_t atoms[NUM_NAMES];
  xcb_intern_atom_cookie_t cookies[NUM_NAMES];
  // in this good example, we make all our requests before checking for
  // replies because it's best to queue requests when we have many at once
  /* make requests */
  for (int i = 0; i < NUM_NAMES; ++i) {
    cookies[i] = xcb_intern_atom(connection, 0, strlen(names[i]), names[i]);
  }
  /* get responses */
  for (int i = 0; i < NUM_NAMES; ++i) {
    xcb_intern_atom_reply_t *reply =
        xcb_intern_atom_reply(connection, cookies[i],
                              NULL); // normally a pointer to receive errors,
                                     // but we'll just ignore error handling
    if (reply) {
      atoms[i] = reply->atom;
      free(reply);
    }
  }
  // now we have our atoms (replies), but this is just a demo, so we do nothing
  // with them
}

int run() {
  /* setup names for tests */
  char(**names) = malloc(NUM_NAMES * sizeof(*names));
  // init names to "NAME0", "NAME1", "NAME2" ... and so on
  for (int i = 0; i < NUM_NAMES; ++i) {
    char buf[100];
    sprintf(buf, "NAME%d", i);
    names[i] = strdup(buf);
  }

  /* do tests */
  double start, XlibTime, XlibGoodTime, XCBBadTime, XCBGoodTime;

  /* test Xlib */
  Display *display = XOpenDisplay(NULL);
  start = get_time();
  useXlib(names, display);
  XlibTime = get_time() - start;
  start = get_time();
  useXlibProperly(names, display);
  XlibGoodTime = get_time() - start;
  XCloseDisplay(display);

  /* test XCB */
  xcb_connection_t *connection = xcb_connect(NULL, NULL);
  start = get_time();
  useXCBPoorly(names, connection);
  XCBBadTime = get_time() - start;
  start = get_time();
  useXCBProperly(names, connection);
  XCBGoodTime = get_time() - start;
  xcb_disconnect(connection);

  /* report times */
  printf("Bad Xlib time : %f\n", XlibTime);
  printf("Good Xlib time : %f\n", XlibGoodTime);
  printf("Bad xcb time : %f\n", XCBBadTime);
  printf("Good xcb time : %f\n", XCBGoodTime);
  printf("ratio of good xcb time to bad xcb time: %f\n",
         XCBGoodTime / XCBBadTime);
  printf("ratio of Xlib time to good xcb time: %f\n", XlibTime / XCBGoodTime);
  printf("ratio of good Xlib time to bad Xlib time: %f\n",
         XlibGoodTime / XlibTime);

  return 0;
}
