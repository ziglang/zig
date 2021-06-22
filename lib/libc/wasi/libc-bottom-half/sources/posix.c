//! POSIX-like functions supporting absolute path arguments, implemented in
//! terms of `__wasilibc_find_relpath` and `*at`-style functions.

#include <errno.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <utime.h>
#include <wasi/libc.h>
#include <wasi/libc-find-relpath.h>
#include <wasi/libc-nocwd.h>

static int find_relpath2(
    const char *path,
    char **relative,
    size_t *relative_len
) {
    // See comments in `preopens.c` for what this trick is doing.
    const char *abs;
    if (__wasilibc_find_relpath_alloc)
        return __wasilibc_find_relpath_alloc(path, &abs, relative, relative_len, 1);
    return __wasilibc_find_relpath(path, &abs, relative, *relative_len);
}

// Helper to call `__wasilibc_find_relpath` and return an already-managed
// pointer for the `relative` path. This function is not reentrant since the
// `relative` pointer will point to static data that cannot be reused until
// `relative` is no longer used.
static int find_relpath(const char *path, char **relative) {
    static __thread char *relative_buf = NULL;
    static __thread size_t relative_buf_len = 0;
    *relative = relative_buf;
    return find_relpath2(path, relative, &relative_buf_len);
}

// same as `find_relpath`, but uses another set of static variables to cache
static int find_relpath_alt(const char *path, char **relative) {
    static __thread char *relative_buf = NULL;
    static __thread size_t relative_buf_len = 0;
    *relative = relative_buf;
    return find_relpath2(path, relative, &relative_buf_len);
}

int open(const char *path, int oflag, ...) {
    // WASI libc's `openat` ignores the mode argument, so call a special
    // entrypoint which avoids the varargs calling convention.
    return __wasilibc_open_nomode(path, oflag);
}

// See the documentation in libc.h
int __wasilibc_open_nomode(const char *path, int oflag) {
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_openat_nomode(dirfd, relative_path, oflag);
}

int access(const char *path, int amode) {
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_faccessat(dirfd, relative_path, amode, 0);
}

ssize_t readlink(
    const char *restrict path,
    char *restrict buf,
    size_t bufsize)
{
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_readlinkat(dirfd, relative_path, buf, bufsize);
}

int stat(const char *restrict path, struct stat *restrict buf) {
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_fstatat(dirfd, relative_path, buf, 0);
}

int lstat(const char *restrict path, struct stat *restrict buf) {
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_fstatat(dirfd, relative_path, buf, AT_SYMLINK_NOFOLLOW);
}

int utime(const char *path, const struct utimbuf *times) {
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_utimensat(
             dirfd, relative_path,
                     times ? ((struct timespec [2]) {
                                 { .tv_sec = times->actime },
                                 { .tv_sec = times->modtime }
                             })
                           : NULL,
                     0);
}

int unlink(const char *path) {
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    // `unlinkat` imports `__wasi_path_remove_directory` even when
    // `AT_REMOVEDIR` isn't passed. Instead, use a specialized function which
    // just imports `__wasi_path_unlink_file`.
    return __wasilibc_nocwd___wasilibc_unlinkat(dirfd, relative_path);
}

int rmdir(const char *path) {
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd___wasilibc_rmdirat(dirfd, relative_path);
}

int remove(const char *path) {
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    // First try to remove it as a file.
    int r = __wasilibc_nocwd___wasilibc_unlinkat(dirfd, relative_path);
    if (r != 0 && (errno == EISDIR || errno == ENOTCAPABLE)) {
        // That failed, but it might be a directory.
        r = __wasilibc_nocwd___wasilibc_rmdirat(dirfd, relative_path);

        // If it isn't a directory, we lack capabilities to remove it as a file.
        if (errno == ENOTDIR)
            errno = ENOTCAPABLE;
    }
    return r;
}

int mkdir(const char *path, mode_t mode) {
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_mkdirat_nomode(dirfd, relative_path);
}

DIR *opendir(const char *dirname) {
    char *relative_path;
    int dirfd = find_relpath(dirname, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return NULL;
    }

    return __wasilibc_nocwd_opendirat(dirfd, relative_path);
}

int scandir(
    const char *restrict dir,
    struct dirent ***restrict namelist,
    int (*filter)(const struct dirent *),
    int (*compar)(const struct dirent **, const struct dirent **)
) {
    char *relative_path;
    int dirfd = find_relpath(dir, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_scandirat(dirfd, relative_path, namelist, filter, compar);
}

int symlink(const char *target, const char *linkpath) {
    char *relative_path;
    int dirfd = find_relpath(linkpath, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_symlinkat(target, dirfd, relative_path);
}

int link(const char *old, const char *new) {
    char *old_relative_path;
    int old_dirfd = find_relpath_alt(old, &old_relative_path);

    if (old_dirfd != -1) {
        char *new_relative_path;
        int new_dirfd = find_relpath(new, &new_relative_path);

        if (new_dirfd != -1)
            return __wasilibc_nocwd_linkat(old_dirfd, old_relative_path,
                                           new_dirfd, new_relative_path, 0);
    }

    // We couldn't find a preopen for it; indicate that we lack capabilities.
    errno = ENOTCAPABLE;
    return -1;
}

int rename(const char *old, const char *new) {
    char *old_relative_path;
    int old_dirfd = find_relpath_alt(old, &old_relative_path);

    if (old_dirfd != -1) {
        char *new_relative_path;
        int new_dirfd = find_relpath(new, &new_relative_path);

        if (new_dirfd != -1)
            return __wasilibc_nocwd_renameat(old_dirfd, old_relative_path,
                                             new_dirfd, new_relative_path);
    }

    // We couldn't find a preopen for it; indicate that we lack capabilities.
    errno = ENOTCAPABLE;
    return -1;
}

// Like `access`, but with `faccessat`'s flags argument.
int
__wasilibc_access(const char *path, int mode, int flags)
{
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_faccessat(dirfd, relative_path,
                                      mode, flags);
}

// Like `utimensat`, but without the `at` part.
int
__wasilibc_utimens(const char *path, const struct timespec times[2], int flags)
{
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_utimensat(dirfd, relative_path,
                                      times, flags);
}

// Like `stat`, but with `fstatat`'s flags argument.
int
__wasilibc_stat(const char *__restrict path, struct stat *__restrict st, int flags)
{
    char *relative_path;
    int dirfd = find_relpath(path, &relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_fstatat(dirfd, relative_path, st, flags);
}

// Like `link`, but with `linkat`'s flags argument.
int
__wasilibc_link(const char *oldpath, const char *newpath, int flags)
{
    char *old_relative_path;
    char *new_relative_path;
    int old_dirfd = find_relpath(oldpath, &old_relative_path);
    int new_dirfd = find_relpath(newpath, &new_relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (old_dirfd == -1 || new_dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_linkat(old_dirfd, old_relative_path,
                                   new_dirfd, new_relative_path,
                                   flags);
}

// Like `__wasilibc_link`, but oldpath is relative to olddirfd.
int
__wasilibc_link_oldat(int olddirfd, const char *oldpath, const char *newpath, int flags)
{
    char *new_relative_path;
    int new_dirfd = find_relpath(newpath, &new_relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (new_dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_linkat(olddirfd, oldpath,
                                   new_dirfd, new_relative_path,
                                   flags);
}

// Like `__wasilibc_link`, but newpath is relative to newdirfd.
int
__wasilibc_link_newat(const char *oldpath, int newdirfd, const char *newpath, int flags)
{
    char *old_relative_path;
    int old_dirfd = find_relpath(oldpath, &old_relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (old_dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_linkat(old_dirfd, old_relative_path,
                                   newdirfd, newpath,
                                   flags);
}

// Like `rename`, but from is relative to fromdirfd.
int
__wasilibc_rename_oldat(int fromdirfd, const char *from, const char *to)
{
    char *to_relative_path;
    int to_dirfd = find_relpath(to, &to_relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (to_dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_renameat(fromdirfd, from, to_dirfd, to_relative_path);
}

// Like `rename`, but to is relative to todirfd.
int
__wasilibc_rename_newat(const char *from, int todirfd, const char *to)
{
    char *from_relative_path;
    int from_dirfd = find_relpath(from, &from_relative_path);

    // If we can't find a preopen for it, indicate that we lack capabilities.
    if (from_dirfd == -1) {
        errno = ENOTCAPABLE;
        return -1;
    }

    return __wasilibc_nocwd_renameat(from_dirfd, from_relative_path, todirfd, to);
}
