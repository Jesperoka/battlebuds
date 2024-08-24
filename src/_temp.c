typedef struct {
  int format;
  int height;
  int width;
} Image;

unsigned long image_size(Image image) {
    unsigned long size = (((((image).format) & 0x08U) ? 1 : (((((image).format) & 0x04U) >> 2) + 1)) * (image).height * ((((((image).format) & 0x08U) ? 1 : ((((image).format) & (0x02U | 0x01U)) + 1)) * (image).width)));

    return size;
}

int image_row_stride(Image image) {
    int stride = (((((image).format) & 0x08U) ? 1 : ((((image).format) & (0x02U | 0x01U)) + 1)) * (image).width);

    return stride;
}
