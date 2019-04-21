#ifndef __wasi_libc_find_relpath_h
#define __wasi_libc_find_relpath_h

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Look up the given path in the preopened directory map. If a suitable
 * entry is found, return its directory file descriptor, and store the
 * computed relative path in *relative_path. Ignore preopened directories
 * which don't provide the specified rights.
 *
 * Returns -1 if no directories were suitable.
 */
int __wasilibc_find_relpath(const char *path,
                            __wasi_rights_t rights_base,
                            __wasi_rights_t rights_inheriting,
                            const char **relative_path);

#ifdef __cplusplus
}
#endif

#endif
