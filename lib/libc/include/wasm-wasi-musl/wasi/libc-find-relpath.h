#ifndef __wasi_libc_find_relpath_h
#define __wasi_libc_find_relpath_h

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Look up the given `path`, relative to the cwd, in the preopened directory
 * map. If a suitable entry is found, then the file descriptor for that entry
 * is returned. Additionally the absolute path of the directory's file
 * descriptor is returned in `abs_prefix` and the relative portion that needs
 * to be opened is stored in `*relative_path`.
 *
 * The `relative_path` argument must be a pointer to a buffer valid  for
 * `relative_path_len` bytes, and this may be used as storage for the relative
 * portion of the path being returned through `*relative_path`.
 *
 * See documentation on `__wasilibc_find_abspath` for more info about what the
 * paths look like.
 *
 * Returns -1 on failure. Errno is set to either:
 *
 *  * ENOMEM - failed to allocate memory for internal routines.
 *  * ENOENT - the `path` could not be found relative to any preopened dir.
 *  * ERANGE - the `relative_path` buffer is too small to hold the relative path.
 */
int __wasilibc_find_relpath(const char *path,
                            const char **__restrict__ abs_prefix,
                            char **relative_path,
                            size_t relative_path_len);

/**
 * Look up the given `path`, which is interpreted as absolute, in the preopened
 * directory map. If a suitable entry is found, then the file descriptor for
 * that entry is returned. Additionally the relative portion of the path to
 * where the fd is opened is returned through `relative_path`, the absolute
 * prefix which was matched is stored to `abs_prefix`, and `relative_path` may
 * be an interior pointer to the `abspath` string.
 *
 * The `abs_prefix` returned string will not contain a leading `/`. Note that
 * this may be the empty string. Additionally the returned `relative_path` will
 * not contain a leading `/`. The `relative_path` return will not return an
 * empty string, it will return `"."` instead if it would otherwise do so.
 *
 * Returns -1 on failure. Errno is set to either:
 *
 *  * ENOMEM - failed to allocate memory for internal routines.
 *  * ENOENT - the `path` could not be found relative to any preopened dir.
 */
int __wasilibc_find_abspath(const char *abspath,
                            const char **__restrict__ abs_prefix,
                            const char **__restrict__ relative_path);

/**
 * Same as `__wasilibc_find_relpath`, except that this function will interpret
 * `relative` as a malloc'd buffer that will be `realloc`'d to the appropriate
 * size to contain the relative path.
 *
 * Note that this is a weak symbol and if it's not defined you can use
 * `__wasilibc_find_relpath`. The weak-nature of this symbols means that if it's
 * not otherwise included in the compilation then `chdir` wasn't used an there's
 * no need for this symbol.
 *
 * See documentation on `__wasilibc_find_relpath` for more information.
 */
int __wasilibc_find_relpath_alloc(
    const char *path,
    const char **abs,
    char **relative,
    size_t *relative_len,
    int can_realloc
) __attribute__((__weak__));

#ifdef __cplusplus
}
#endif

#endif
