// Handle AT_FDCWD and absolute paths for the *at functions.
//
// In the case of an AT_FDCWD file descriptor or an absolute path, call the
// corresponding non-`at` function. This will send it through the libpreopen
// wrappers to convert the path into a directory file descriptor and relative
// path before translating it into the corresponding `__wasilibc_nocwd_*at`
// function, which then calls the appropriate WASI function.

#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <wasi/libc.h>
#include <wasi/libc-nocwd.h>

// If the platform doesn't define O_TMPFILE, we don't need to worry about it.
#ifndef O_TMPFILE
#define O_TMPFILE 0
#endif

int openat(int dirfd, const char *pathname, int flags, ...) {
    if (dirfd == AT_FDCWD || pathname[0] == '/') {
        return open(pathname, flags);
    }

    return __wasilibc_nocwd_openat_nomode(dirfd, pathname, flags);
}

int symlinkat(const char *target, int dirfd, const char *linkpath) {
    if (dirfd == AT_FDCWD || linkpath[0] == '/') {
        return symlink(target, linkpath);
    }

    return __wasilibc_nocwd_symlinkat(target, dirfd, linkpath);
}

ssize_t readlinkat(int dirfd, const char *__restrict pathname, char *__restrict buf, size_t bufsiz) {
    if (dirfd == AT_FDCWD || pathname[0] == '/') {
        return readlink(pathname, buf, bufsiz);
    }

    return __wasilibc_nocwd_readlinkat(dirfd, pathname, buf, bufsiz);
}

int mkdirat(int dirfd, const char *pathname, mode_t mode) {
    if (dirfd == AT_FDCWD || pathname[0] == '/') {
        return mkdir(pathname, mode);
    }

    return __wasilibc_nocwd_mkdirat_nomode(dirfd, pathname);
}

DIR *opendirat(int dirfd, const char *path) {
    if (dirfd == AT_FDCWD || path[0] == '/') {
        return opendir(path);
    }

    return __wasilibc_nocwd_opendirat(dirfd, path);
}

int scandirat(int dirfd, const char *dirp, struct dirent ***namelist,
              int (*filter)(const struct dirent *),
              int (*compar)(const struct dirent **, const struct dirent **)) {
    if (dirfd == AT_FDCWD || dirp[0] == '/') {
        return scandir(dirp, namelist, filter, compar);
    }

    return __wasilibc_nocwd_scandirat(dirfd, dirp, namelist, filter, compar);
}

int faccessat(int dirfd, const char *pathname, int mode, int flags) {
    if (dirfd == AT_FDCWD || pathname[0] == '/') {
        return __wasilibc_access(pathname, mode, flags);
    }

    return __wasilibc_nocwd_faccessat(dirfd, pathname, mode, flags);
}

int fstatat(int dirfd, const char *__restrict pathname, struct stat *__restrict statbuf, int flags) {
    if (dirfd == AT_FDCWD || pathname[0] == '/') {
        return __wasilibc_stat(pathname, statbuf, flags);
    }

    return __wasilibc_nocwd_fstatat(dirfd, pathname, statbuf, flags);
}

int utimensat(int dirfd, const char *pathname, const struct timespec times[2], int flags) {
    if (dirfd == AT_FDCWD || pathname[0] == '/') {
        return __wasilibc_utimens(pathname, times, flags);
    }

    return __wasilibc_nocwd_utimensat(dirfd, pathname, times, flags);
}

int linkat(int olddirfd, const char *oldpath, int newdirfd, const char *newpath, int flags) {
    if ((olddirfd == AT_FDCWD || oldpath[0] == '/') &&
        (newdirfd == AT_FDCWD || newpath[0] == '/')) {
        return __wasilibc_link(oldpath, newpath, flags);
    }
    if (olddirfd == AT_FDCWD || oldpath[0] == '/') {
        return __wasilibc_link_newat(oldpath, newdirfd, newpath, flags);
    }
    if (newdirfd == AT_FDCWD || newpath[0] == '/') {
        return __wasilibc_link_oldat(olddirfd, oldpath, newpath, flags);
    }

    return __wasilibc_nocwd_linkat(olddirfd, oldpath, newdirfd, newpath, flags);
}

int renameat(int olddirfd, const char *oldpath, int newdirfd, const char *newpath) {
    if ((olddirfd == AT_FDCWD || oldpath[0] == '/') &&
        (newdirfd == AT_FDCWD || newpath[0] == '/')) {
        return rename(oldpath, newpath);
    }
    if (olddirfd == AT_FDCWD || oldpath[0] == '/') {
        return __wasilibc_rename_newat(oldpath, newdirfd, newpath);
    }
    if (newdirfd == AT_FDCWD || newpath[0] == '/') {
        return __wasilibc_rename_oldat(olddirfd, oldpath, newpath);
    }

    return __wasilibc_nocwd_renameat(olddirfd, oldpath, newdirfd, newpath);
}

int __wasilibc_unlinkat(int dirfd, const char *path) {
    if (dirfd == AT_FDCWD || path[0] == '/') {
        return unlink(path);
    }

    return __wasilibc_nocwd___wasilibc_unlinkat(dirfd, path);
}

int __wasilibc_rmdirat(int dirfd, const char *path) {
    if (dirfd == AT_FDCWD || path[0] == '/') {
        return rmdir(path);
    }

    return __wasilibc_nocwd___wasilibc_rmdirat(dirfd, path);
}
