#include <png.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, const char **argv) {
  if (argc == 3) {
    png_image image; /* The control structure used by libpng */

    /* Initialize the 'png_image' structure. */
    memset(&image, 0, (sizeof image));
    image.version = PNG_IMAGE_VERSION;

    /* The first argument is the file to read: */
    if (png_image_begin_read_from_file(&image, argv[1]) != 0) {
      png_bytep buffer;
      image.format = PNG_FORMAT_RGBA;
      buffer = malloc(PNG_IMAGE_SIZE(image));

      if (buffer != NULL &&
          png_image_finish_read(&image, NULL, buffer, 0, NULL) != 0) {
        if (png_image_write_to_file(&image, argv[2], 0, buffer, 0, NULL) != 0) {
          /* The image has been written successfully. */
          exit(0);
        }
      } else {
        /* Calling png_image_free is optional unless the simplified API was
         * not run to completion.  In this case, if there wasn't enough
         * memory for 'buffer', we didn't complete the read, so we must
         * free the image:
         */
        if (buffer == NULL)
          png_image_free(&image);
        else
          free(buffer);
      }
    }

    /* Something went wrong reading or writing the image.  libpng stores a
     * textual message in the 'png_image' structure:
     */
    fprintf(stderr, "pngtopng: error: %s\n", image.message);
    exit(1);
  }

  fprintf(stderr, "pngtopng: usage: pngtopng input-file output-file\n");
  exit(2);
}

/* That's it ;-)  Of course you probably want to do more with PNG files than
 * just converting them all to 32-bit RGBA PNG files; you can do that between
 * the call to png_image_finish_read and png_image_write_to_file.  You can also
 * ask for the image data to be presented in a number of different formats.
 * You do this by simply changing the 'format' parameter set before allocating
 * the buffer.
 *
 * The format parameter consists of five flags that define various aspects of
 * the image.  You can simply add these together to get the format, or you can
 * use one of the predefined macros from png.h (as above):
 *
 * PNG_FORMAT_FLAG_COLOR: if set, the image will have three color components
 *    per pixel (red, green and blue); if not set, the image will just have one
 *    luminance (grayscale) component.
 *
 * PNG_FORMAT_FLAG_ALPHA: if set, each pixel in the image will have an
 *    additional alpha value; a linear value that describes the degree the
 *    image pixel covers (overwrites) the contents of the existing pixel on the
 *    display.
 *
 * PNG_FORMAT_FLAG_LINEAR: if set, the components of each pixel will be
 *    returned as a series of 16-bit linear values; if not set, the components
 *    will be returned as a series of 8-bit values encoded according to the
 *    sRGB standard.  The 8-bit format is the normal format for images intended
 *    for direct display, because almost all display devices do the inverse of
 *    the sRGB transformation to the data they receive.  The 16-bit format is
 *    more common for scientific data and image data that must be further
 *    processed; because it is linear, simple math can be done on the component
 *    values.  Regardless of the setting of this flag, the alpha channel is
 *    always linear, although it will be 8 bits or 16 bits wide as specified by
 *    the flag.
 *
 * PNG_FORMAT_FLAG_BGR: if set, the components of a color pixel will be
 *    returned in the order blue, then green, then red.  If not set, the pixel
 *    components are in the order red, then green, then blue.
 *
 * PNG_FORMAT_FLAG_AFIRST: if set, the alpha channel (if present) precedes the
 *    color or grayscale components.  If not set, the alpha channel follows the
 *    components.
 *
 * You do not have to read directly from a file.  You can read from memory or,
 * on systems that support it, from a <stdio.h> FILE*.  This is controlled by
 * the particular png_image_read_from_ function you call at the start.
 * Likewise, on write, you can write to a FILE* if your system supports it.
 * Check the macro PNG_STDIO_SUPPORTED to see if stdio support has been
 * included in your libpng build.
 *
 * If you read 16-bit (PNG_FORMAT_FLAG_LINEAR) data, you may need to write it
 * in the 8-bit format for display.  You do this by setting the convert_to_8bit
 * flag to 'true'.
 *
 * Don't repeatedly convert between the 8-bit and 16-bit forms.  There is
 * significant data loss when 16-bit data is converted to the 8-bit encoding,
 * and the current libpng implementation of conversion to 16-bit is also
 * significantly lossy.  The latter will be fixed in the future, but the former
 * is unavoidable - the 8-bit format just doesn't have enough resolution.
 */

/* If your program needs more information from the PNG data it reads, or if you
 * need to do more complex transformations, or minimize transformations, on the
 * data you read, then you must use one of the several lower level libpng
 * interfaces.
 *
 * All these interfaces require that you do your own error handling - your
 * program must be able to arrange for control to return to your own code, any
 * time libpng encounters a problem.  There are several ways to do this, but
 * the standard way is to use the <setjmp.h> interface to establish a return
 * point within your own code.  You must do this if you do not use the
 * simplified interface (above).
 */
