#include <assert.h>
#include <string.h>
#include <stdint.h>

// TODO we would like to #include "base64.h" here but this feature has been disabled in
// the stage1 compiler. Users will have to wait until self-hosted is available for
// the "generate .h file" feature.
size_t decode_base_64(uint8_t *dest_ptr, size_t dest_len, const uint8_t *source_ptr, size_t source_len);

extern int *x_ptr;

int main(int argc, char **argv) {
    const char *encoded = "YWxsIHlvdXIgYmFzZSBhcmUgYmVsb25nIHRvIHVz";
    char buf[200];

    size_t len = decode_base_64((uint8_t *)buf, 200, (uint8_t *)encoded, strlen(encoded));
    buf[len] = 0;
    assert(strcmp(buf, "all your base are belong to us") == 0);

    assert(*x_ptr == 1234);

    return 0;
}
