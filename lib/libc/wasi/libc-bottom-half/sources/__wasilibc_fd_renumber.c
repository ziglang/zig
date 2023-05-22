#include <wasi/api.h>
#include <wasi/libc.h>
#include <errno.h>
#include <unistd.h>

int __wasilibc_fd_renumber(int fd, int newfd) {
    // Scan the preopen fds before making any changes.
    __wasilibc_populate_preopens();

    __wasi_errno_t error = __wasi_fd_renumber(fd, newfd);
    if (error != 0) {
        errno = error;
        return -1;
    }
    return 0;
}

int close(int fd) {
    // Scan the preopen fds before making any changes.
    __wasilibc_populate_preopens();

    __wasi_errno_t error = __wasi_fd_close(fd);
    if (error != 0) {
        errno = error;
        return -1;
    }

    return 0;
}

weak void __wasilibc_populate_preopens(void) {
    // This version does nothing. It may be overridden by a version which does
    // something if `__wasilibc_find_abspath` or `__wasilibc_find_relpath` are
    // used.
}
