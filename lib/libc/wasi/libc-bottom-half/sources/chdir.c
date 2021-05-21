#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <wasi/libc-find-relpath.h>
#include <wasi/libc.h>

#ifdef _REENTRANT
#error "chdir doesn't yet support multiple threads"
#endif

extern char *__wasilibc_cwd;
static int __wasilibc_cwd_mallocd = 0;

int chdir(const char *path)
{
    static char *relative_buf = NULL;
    static size_t relative_buf_len = 0;

    // Find a preopen'd directory as well as a relative path we're anchored
    // from which we're changing directories to.
    const char *abs;
    int parent_fd = __wasilibc_find_relpath_alloc(path, &abs, &relative_buf, &relative_buf_len, 1);
    if (parent_fd == -1)
        return -1;

    // Make sure that this directory we're accessing is indeed a directory.
    struct stat dirinfo;
    int ret = fstatat(parent_fd, relative_buf, &dirinfo, 0);
    if (ret == -1)
        return -1;
    if (!S_ISDIR(dirinfo.st_mode)) {
        errno = ENOTDIR;
        return -1;
    }

    // Create a string that looks like:
    //
    //    __wasilibc_cwd = "/" + abs + "/" + relative_buf
    //
    // If `relative_buf` is equal to "." or `abs` is equal to the empty string,
    // however, we skip that part and the middle slash.
    size_t len = strlen(abs) + 1;
    int copy_relative = strcmp(relative_buf, ".") != 0;
    int mid = copy_relative && abs[0] != 0;
    char *new_cwd = malloc(len + (copy_relative ? strlen(relative_buf) + mid: 0));
    if (new_cwd == NULL) {
        errno = ENOMEM;
        return -1;
    }
    new_cwd[0] = '/';
    strcpy(new_cwd + 1, abs);
    if (mid)
        new_cwd[strlen(abs) + 1] = '/';
    if (copy_relative)
        strcpy(new_cwd + 1 + mid + strlen(abs), relative_buf);

    // And set our new malloc'd buffer into the global cwd, freeing the
    // previous one if necessary.
    char *prev_cwd = __wasilibc_cwd;
    __wasilibc_cwd = new_cwd;
    if (__wasilibc_cwd_mallocd)
        free(prev_cwd);
    __wasilibc_cwd_mallocd = 1;
    return 0;
}

static const char *make_absolute(const char *path) {
    static char *make_absolute_buf = NULL;
    static size_t make_absolute_len = 0;

    // If this path is absolute, then we return it as-is.
    if (path[0] == '/') {
        return path;
    }

    // If the path is empty, or points to the current directory, then return
    // the current directory.
    if (path[0] == 0 || !strcmp(path, ".") || !strcmp(path, "./")) {
        return __wasilibc_cwd;
    }

    // If the path starts with `./` then we won't be appending that to the cwd.
    if (path[0] == '.' && path[1] == '/')
        path += 2;

    // Otherwise we'll take the current directory, add a `/`, and then add the
    // input `path`. Note that this doesn't do any normalization (like removing
    // `/./`).
    size_t cwd_len = strlen(__wasilibc_cwd);
    size_t path_len = strlen(path);
    int need_slash = __wasilibc_cwd[cwd_len - 1] == '/' ? 0 : 1;
    size_t alloc_len = cwd_len + path_len + 1 + need_slash;
    if (alloc_len > make_absolute_len) {
        make_absolute_buf = realloc(make_absolute_buf, alloc_len);
        if (make_absolute_buf == NULL)
            return NULL;
        make_absolute_len = alloc_len;
    }
    strcpy(make_absolute_buf, __wasilibc_cwd);
    if (need_slash)
        strcpy(make_absolute_buf + cwd_len, "/");
    strcpy(make_absolute_buf + cwd_len + need_slash, path);
    return make_absolute_buf;
}

// Helper function defined only in this object file and weakly referenced from
// `preopens.c` and `posix.c` This function isn't necessary unless `chdir` is
// pulled in because all paths are otherwise absolute or relative to the root.
int __wasilibc_find_relpath_alloc(
    const char *path,
    const char **abs_prefix,
    char **relative_buf,
    size_t *relative_buf_len,
    int can_realloc
) {
    // First, make our path absolute taking the cwd into account.
    const char *abspath = make_absolute(path);
    if (abspath == NULL) {
        errno = ENOMEM;
        return -1;
    }

    // Next use our absolute path and split it. Find the preopened `fd` parent
    // directory and set `abs_prefix`. Next up we'll be trying to fit `rel`
    // into `relative_buf`.
    const char *rel;
    int fd = __wasilibc_find_abspath(abspath, abs_prefix, &rel);
    if (fd == -1)
        return -1;

    size_t rel_len = strlen(rel);
    if (*relative_buf_len < rel_len + 1) {
        if (!can_realloc) {
            errno = ERANGE;
            return -1;
        }
        char *tmp = realloc(*relative_buf, rel_len + 1);
        if (tmp == NULL) {
            errno = ENOMEM;
            return -1;
        }
        *relative_buf = tmp;
        *relative_buf_len = rel_len + 1;
    }
    strcpy(*relative_buf, rel);
    return fd;
}
