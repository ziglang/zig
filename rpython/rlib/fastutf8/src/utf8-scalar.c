#include "utf8.h"

int _check_continuation(const uint8_t ** encoded, const uint8_t * endptr, int count) {
    ssize_t size = endptr - *encoded;

    if (size < count) {
        // not enough bytes to be a valid 2 byte utf8 code point
        return -1;
    }
    for (int i = 0; i < count; i++) {
        uint8_t byte = *(*encoded)++;
        if ((byte & 0xc0) != 0x80) { 
            // continuation byte does NOT match 0x10xxxxxx
            return -1;
        }
    }
    return 0;
}

ssize_t fu8_count_utf8_codepoints_seq(const char * utf8, size_t len) {
    size_t num_codepoints = 0;
    uint8_t byte = 0;
    const uint8_t * encoded = (const uint8_t*)utf8;
    const uint8_t * endptr = encoded + len;

    while (encoded < endptr) {
        byte = *encoded++;
        if (byte < 0x80) {
            num_codepoints += 1;
            continue;
        } else {
                //asm("int $3");
            if ((byte & 0xe0) == 0xc0) {
                // one continuation byte
                if (byte < 0xc2) {
                    return -1;
                }
                if (_check_continuation(&encoded, endptr, 1) != 0) {
                    return -1;
                }
            } else if ((byte & 0xf0) == 0xe0) {
                // two continuation byte
                if (_check_continuation(&encoded, endptr, 2) != 0) {
                    return -1;
                }
                uint8_t byte1 = encoded[-2];
                //surrogates shouldn't be valid UTF-8!
                if ((byte == 0xe0 && byte1 < 0xa0) ||
                    (byte == 0xed && byte1 > 0x9f && !ALLOW_SURROGATES)) {
                    return -1;
                }
            } else if ((byte & 0xf8) == 0xf0) {
                // three continuation byte
                if (_check_continuation(&encoded, endptr, 3) != 0) {
                    return -1;
                }
                uint8_t byte1 = encoded[-3];
                if ((byte == 0xf0 && byte1 < 0x90) ||
                    (byte == 0xf4 && byte1 > 0x8f) ||
                    (byte >= 0xf5)) {
                    return -1;
                }
            } else {
                // TODO
                return -1;
            }
            num_codepoints += 1;
        }
    }
    return num_codepoints;
}
