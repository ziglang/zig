#include <errno.h>
#include <unistd.h>
#ifdef __wasilibc_use_wasip2
#include <wasi/wasip2.h>
#include <sysexits.h>

int __wasilibc_random(void *buffer, size_t len) {

        // Set up a WASI byte list to receive the results
        wasip2_list_u8_t wasi_list;

        // Get random bytes
        random_get_random_bytes(len, &wasi_list);

        // The spec for get-random-bytes specifies that wasi_list.len
        // will be equal to len.
        if (wasi_list.len != len)
            _Exit(EX_OSERR);
        else {
            // Copy the result
            memcpy(buffer, wasi_list.ptr, len);
        }

        // Free the WASI byte list
        wasip2_list_u8_free(&wasi_list);

        return 0;
}
#endif
