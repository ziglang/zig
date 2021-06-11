#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <wasi/libc.h>

int truncate(const char *path, off_t length)
{
    int fd = __wasilibc_open_nomode(path, O_WRONLY | O_CLOEXEC | O_NOCTTY);
    if (fd < 0)
        return -1;

    int result = ftruncate(fd, length);
    if (result != 0) {
        int save_errno = errno;
        (void)close(fd);
        errno = save_errno;
        return -1;
    }

    return close(fd);
}
