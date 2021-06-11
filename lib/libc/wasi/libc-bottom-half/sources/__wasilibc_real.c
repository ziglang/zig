/**
 * THIS FILE IS AUTO-GENERATED from the following files:
 *   wasi_snapshot_preview1.witx
 *
 * To regenerate this file execute:
 *
 *     cargo run --manifest-path tools/wasi-headers/Cargo.toml generate-libc
 *
 * Modifications to this file will cause CI to fail, the code generator tool
 * must be modified to change this file.
 */

#include <wasi/api.h>
#include <string.h>

int32_t __imported_wasi_snapshot_preview1_args_get(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("args_get")
));

__wasi_errno_t __wasi_args_get(
    uint8_t * * argv,
    uint8_t * argv_buf
){
    int32_t ret = __imported_wasi_snapshot_preview1_args_get((int32_t) argv, (int32_t) argv_buf);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_args_sizes_get(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("args_sizes_get")
));

__wasi_errno_t __wasi_args_sizes_get(
    __wasi_size_t *retptr0,
    __wasi_size_t *retptr1
){
    int32_t ret = __imported_wasi_snapshot_preview1_args_sizes_get((int32_t) retptr0, (int32_t) retptr1);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_environ_get(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("environ_get")
));

__wasi_errno_t __wasi_environ_get(
    uint8_t * * environ,
    uint8_t * environ_buf
){
    int32_t ret = __imported_wasi_snapshot_preview1_environ_get((int32_t) environ, (int32_t) environ_buf);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_environ_sizes_get(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("environ_sizes_get")
));

__wasi_errno_t __wasi_environ_sizes_get(
    __wasi_size_t *retptr0,
    __wasi_size_t *retptr1
){
    int32_t ret = __imported_wasi_snapshot_preview1_environ_sizes_get((int32_t) retptr0, (int32_t) retptr1);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_clock_res_get(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("clock_res_get")
));

__wasi_errno_t __wasi_clock_res_get(
    __wasi_clockid_t id,
    __wasi_timestamp_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_clock_res_get((int32_t) id, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_clock_time_get(int32_t arg0, int64_t arg1, int32_t arg2) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("clock_time_get")
));

__wasi_errno_t __wasi_clock_time_get(
    __wasi_clockid_t id,
    __wasi_timestamp_t precision,
    __wasi_timestamp_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_clock_time_get((int32_t) id, (int64_t) precision, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_advise(int32_t arg0, int64_t arg1, int64_t arg2, int32_t arg3) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_advise")
));

__wasi_errno_t __wasi_fd_advise(
    __wasi_fd_t fd,
    __wasi_filesize_t offset,
    __wasi_filesize_t len,
    __wasi_advice_t advice
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_advise((int32_t) fd, (int64_t) offset, (int64_t) len, (int32_t) advice);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_allocate(int32_t arg0, int64_t arg1, int64_t arg2) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_allocate")
));

__wasi_errno_t __wasi_fd_allocate(
    __wasi_fd_t fd,
    __wasi_filesize_t offset,
    __wasi_filesize_t len
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_allocate((int32_t) fd, (int64_t) offset, (int64_t) len);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_close(int32_t arg0) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_close")
));

__wasi_errno_t __wasi_fd_close(
    __wasi_fd_t fd
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_close((int32_t) fd);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_datasync(int32_t arg0) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_datasync")
));

__wasi_errno_t __wasi_fd_datasync(
    __wasi_fd_t fd
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_datasync((int32_t) fd);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_fdstat_get(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_fdstat_get")
));

__wasi_errno_t __wasi_fd_fdstat_get(
    __wasi_fd_t fd,
    __wasi_fdstat_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_fdstat_get((int32_t) fd, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_fdstat_set_flags(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_fdstat_set_flags")
));

__wasi_errno_t __wasi_fd_fdstat_set_flags(
    __wasi_fd_t fd,
    __wasi_fdflags_t flags
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_fdstat_set_flags((int32_t) fd, flags);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_fdstat_set_rights(int32_t arg0, int64_t arg1, int64_t arg2) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_fdstat_set_rights")
));

__wasi_errno_t __wasi_fd_fdstat_set_rights(
    __wasi_fd_t fd,
    __wasi_rights_t fs_rights_base,
    __wasi_rights_t fs_rights_inheriting
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_fdstat_set_rights((int32_t) fd, fs_rights_base, fs_rights_inheriting);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_filestat_get(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_filestat_get")
));

__wasi_errno_t __wasi_fd_filestat_get(
    __wasi_fd_t fd,
    __wasi_filestat_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_filestat_get((int32_t) fd, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_filestat_set_size(int32_t arg0, int64_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_filestat_set_size")
));

__wasi_errno_t __wasi_fd_filestat_set_size(
    __wasi_fd_t fd,
    __wasi_filesize_t size
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_filestat_set_size((int32_t) fd, (int64_t) size);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_filestat_set_times(int32_t arg0, int64_t arg1, int64_t arg2, int32_t arg3) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_filestat_set_times")
));

__wasi_errno_t __wasi_fd_filestat_set_times(
    __wasi_fd_t fd,
    __wasi_timestamp_t atim,
    __wasi_timestamp_t mtim,
    __wasi_fstflags_t fst_flags
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_filestat_set_times((int32_t) fd, (int64_t) atim, (int64_t) mtim, fst_flags);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_pread(int32_t arg0, int32_t arg1, int32_t arg2, int64_t arg3, int32_t arg4) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_pread")
));

__wasi_errno_t __wasi_fd_pread(
    __wasi_fd_t fd,
    const __wasi_iovec_t *iovs,
    size_t iovs_len,
    __wasi_filesize_t offset,
    __wasi_size_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_pread((int32_t) fd, (int32_t) iovs, (int32_t) iovs_len, (int64_t) offset, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_prestat_get(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_prestat_get")
));

__wasi_errno_t __wasi_fd_prestat_get(
    __wasi_fd_t fd,
    __wasi_prestat_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_prestat_get((int32_t) fd, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_prestat_dir_name(int32_t arg0, int32_t arg1, int32_t arg2) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_prestat_dir_name")
));

__wasi_errno_t __wasi_fd_prestat_dir_name(
    __wasi_fd_t fd,
    uint8_t * path,
    __wasi_size_t path_len
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_prestat_dir_name((int32_t) fd, (int32_t) path, (int32_t) path_len);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_pwrite(int32_t arg0, int32_t arg1, int32_t arg2, int64_t arg3, int32_t arg4) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_pwrite")
));

__wasi_errno_t __wasi_fd_pwrite(
    __wasi_fd_t fd,
    const __wasi_ciovec_t *iovs,
    size_t iovs_len,
    __wasi_filesize_t offset,
    __wasi_size_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_pwrite((int32_t) fd, (int32_t) iovs, (int32_t) iovs_len, (int64_t) offset, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_read(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_read")
));

__wasi_errno_t __wasi_fd_read(
    __wasi_fd_t fd,
    const __wasi_iovec_t *iovs,
    size_t iovs_len,
    __wasi_size_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_read((int32_t) fd, (int32_t) iovs, (int32_t) iovs_len, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_readdir(int32_t arg0, int32_t arg1, int32_t arg2, int64_t arg3, int32_t arg4) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_readdir")
));

__wasi_errno_t __wasi_fd_readdir(
    __wasi_fd_t fd,
    uint8_t * buf,
    __wasi_size_t buf_len,
    __wasi_dircookie_t cookie,
    __wasi_size_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_readdir((int32_t) fd, (int32_t) buf, (int32_t) buf_len, (int64_t) cookie, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_renumber(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_renumber")
));

__wasi_errno_t __wasi_fd_renumber(
    __wasi_fd_t fd,
    __wasi_fd_t to
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_renumber((int32_t) fd, (int32_t) to);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_seek(int32_t arg0, int64_t arg1, int32_t arg2, int32_t arg3) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_seek")
));

__wasi_errno_t __wasi_fd_seek(
    __wasi_fd_t fd,
    __wasi_filedelta_t offset,
    __wasi_whence_t whence,
    __wasi_filesize_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_seek((int32_t) fd, offset, (int32_t) whence, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_sync(int32_t arg0) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_sync")
));

__wasi_errno_t __wasi_fd_sync(
    __wasi_fd_t fd
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_sync((int32_t) fd);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_tell(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_tell")
));

__wasi_errno_t __wasi_fd_tell(
    __wasi_fd_t fd,
    __wasi_filesize_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_tell((int32_t) fd, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_fd_write(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("fd_write")
));

__wasi_errno_t __wasi_fd_write(
    __wasi_fd_t fd,
    const __wasi_ciovec_t *iovs,
    size_t iovs_len,
    __wasi_size_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_fd_write((int32_t) fd, (int32_t) iovs, (int32_t) iovs_len, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_path_create_directory(int32_t arg0, int32_t arg1, int32_t arg2) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("path_create_directory")
));

__wasi_errno_t __wasi_path_create_directory(
    __wasi_fd_t fd,
    const char *path
){
    size_t path_len = strlen(path);
    int32_t ret = __imported_wasi_snapshot_preview1_path_create_directory((int32_t) fd, (int32_t) path, (int32_t) path_len);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_path_filestat_get(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3, int32_t arg4) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("path_filestat_get")
));

__wasi_errno_t __wasi_path_filestat_get(
    __wasi_fd_t fd,
    __wasi_lookupflags_t flags,
    const char *path,
    __wasi_filestat_t *retptr0
){
    size_t path_len = strlen(path);
    int32_t ret = __imported_wasi_snapshot_preview1_path_filestat_get((int32_t) fd, flags, (int32_t) path, (int32_t) path_len, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_path_filestat_set_times(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3, int64_t arg4, int64_t arg5, int32_t arg6) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("path_filestat_set_times")
));

__wasi_errno_t __wasi_path_filestat_set_times(
    __wasi_fd_t fd,
    __wasi_lookupflags_t flags,
    const char *path,
    __wasi_timestamp_t atim,
    __wasi_timestamp_t mtim,
    __wasi_fstflags_t fst_flags
){
    size_t path_len = strlen(path);
    int32_t ret = __imported_wasi_snapshot_preview1_path_filestat_set_times((int32_t) fd, flags, (int32_t) path, (int32_t) path_len, (int64_t) atim, (int64_t) mtim, fst_flags);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_path_link(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3, int32_t arg4, int32_t arg5, int32_t arg6) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("path_link")
));

__wasi_errno_t __wasi_path_link(
    __wasi_fd_t old_fd,
    __wasi_lookupflags_t old_flags,
    const char *old_path,
    __wasi_fd_t new_fd,
    const char *new_path
){
    size_t old_path_len = strlen(old_path);
    size_t new_path_len = strlen(new_path);
    int32_t ret = __imported_wasi_snapshot_preview1_path_link((int32_t) old_fd, old_flags, (int32_t) old_path, (int32_t) old_path_len, (int32_t) new_fd, (int32_t) new_path, (int32_t) new_path_len);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_path_open(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3, int32_t arg4, int64_t arg5, int64_t arg6, int32_t arg7, int32_t arg8) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("path_open")
));

__wasi_errno_t __wasi_path_open(
    __wasi_fd_t fd,
    __wasi_lookupflags_t dirflags,
    const char *path,
    __wasi_oflags_t oflags,
    __wasi_rights_t fs_rights_base,
    __wasi_rights_t fs_rights_inheriting,
    __wasi_fdflags_t fdflags,
    __wasi_fd_t *retptr0
){
    size_t path_len = strlen(path);
    int32_t ret = __imported_wasi_snapshot_preview1_path_open((int32_t) fd, dirflags, (int32_t) path, (int32_t) path_len, oflags, fs_rights_base, fs_rights_inheriting, fdflags, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_path_readlink(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3, int32_t arg4, int32_t arg5) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("path_readlink")
));

__wasi_errno_t __wasi_path_readlink(
    __wasi_fd_t fd,
    const char *path,
    uint8_t * buf,
    __wasi_size_t buf_len,
    __wasi_size_t *retptr0
){
    size_t path_len = strlen(path);
    int32_t ret = __imported_wasi_snapshot_preview1_path_readlink((int32_t) fd, (int32_t) path, (int32_t) path_len, (int32_t) buf, (int32_t) buf_len, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_path_remove_directory(int32_t arg0, int32_t arg1, int32_t arg2) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("path_remove_directory")
));

__wasi_errno_t __wasi_path_remove_directory(
    __wasi_fd_t fd,
    const char *path
){
    size_t path_len = strlen(path);
    int32_t ret = __imported_wasi_snapshot_preview1_path_remove_directory((int32_t) fd, (int32_t) path, (int32_t) path_len);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_path_rename(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3, int32_t arg4, int32_t arg5) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("path_rename")
));

__wasi_errno_t __wasi_path_rename(
    __wasi_fd_t fd,
    const char *old_path,
    __wasi_fd_t new_fd,
    const char *new_path
){
    size_t old_path_len = strlen(old_path);
    size_t new_path_len = strlen(new_path);
    int32_t ret = __imported_wasi_snapshot_preview1_path_rename((int32_t) fd, (int32_t) old_path, (int32_t) old_path_len, (int32_t) new_fd, (int32_t) new_path, (int32_t) new_path_len);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_path_symlink(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3, int32_t arg4) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("path_symlink")
));

__wasi_errno_t __wasi_path_symlink(
    const char *old_path,
    __wasi_fd_t fd,
    const char *new_path
){
    size_t old_path_len = strlen(old_path);
    size_t new_path_len = strlen(new_path);
    int32_t ret = __imported_wasi_snapshot_preview1_path_symlink((int32_t) old_path, (int32_t) old_path_len, (int32_t) fd, (int32_t) new_path, (int32_t) new_path_len);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_path_unlink_file(int32_t arg0, int32_t arg1, int32_t arg2) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("path_unlink_file")
));

__wasi_errno_t __wasi_path_unlink_file(
    __wasi_fd_t fd,
    const char *path
){
    size_t path_len = strlen(path);
    int32_t ret = __imported_wasi_snapshot_preview1_path_unlink_file((int32_t) fd, (int32_t) path, (int32_t) path_len);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_poll_oneoff(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("poll_oneoff")
));

__wasi_errno_t __wasi_poll_oneoff(
    const __wasi_subscription_t * in,
    __wasi_event_t * out,
    __wasi_size_t nsubscriptions,
    __wasi_size_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_poll_oneoff((int32_t) in, (int32_t) out, (int32_t) nsubscriptions, (int32_t) retptr0);
    return (uint16_t) ret;
}

_Noreturn void __imported_wasi_snapshot_preview1_proc_exit(int32_t arg0) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("proc_exit")
));

_Noreturn void __wasi_proc_exit(
    __wasi_exitcode_t rval
){
    __imported_wasi_snapshot_preview1_proc_exit((int32_t) rval);
}

int32_t __imported_wasi_snapshot_preview1_proc_raise(int32_t arg0) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("proc_raise")
));

__wasi_errno_t __wasi_proc_raise(
    __wasi_signal_t sig
){
    int32_t ret = __imported_wasi_snapshot_preview1_proc_raise((int32_t) sig);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_sched_yield() __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("sched_yield")
));

__wasi_errno_t __wasi_sched_yield(
    void
){
    int32_t ret = __imported_wasi_snapshot_preview1_sched_yield();
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_random_get(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("random_get")
));

__wasi_errno_t __wasi_random_get(
    uint8_t * buf,
    __wasi_size_t buf_len
){
    int32_t ret = __imported_wasi_snapshot_preview1_random_get((int32_t) buf, (int32_t) buf_len);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_sock_recv(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3, int32_t arg4, int32_t arg5) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("sock_recv")
));

__wasi_errno_t __wasi_sock_recv(
    __wasi_fd_t fd,
    const __wasi_iovec_t *ri_data,
    size_t ri_data_len,
    __wasi_riflags_t ri_flags,
    __wasi_size_t *retptr0,
    __wasi_roflags_t *retptr1
){
    int32_t ret = __imported_wasi_snapshot_preview1_sock_recv((int32_t) fd, (int32_t) ri_data, (int32_t) ri_data_len, ri_flags, (int32_t) retptr0, (int32_t) retptr1);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_sock_send(int32_t arg0, int32_t arg1, int32_t arg2, int32_t arg3, int32_t arg4) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("sock_send")
));

__wasi_errno_t __wasi_sock_send(
    __wasi_fd_t fd,
    const __wasi_ciovec_t *si_data,
    size_t si_data_len,
    __wasi_siflags_t si_flags,
    __wasi_size_t *retptr0
){
    int32_t ret = __imported_wasi_snapshot_preview1_sock_send((int32_t) fd, (int32_t) si_data, (int32_t) si_data_len, (int32_t) si_flags, (int32_t) retptr0);
    return (uint16_t) ret;
}

int32_t __imported_wasi_snapshot_preview1_sock_shutdown(int32_t arg0, int32_t arg1) __attribute__((
    __import_module__("wasi_snapshot_preview1"),
    __import_name__("sock_shutdown")
));

__wasi_errno_t __wasi_sock_shutdown(
    __wasi_fd_t fd,
    __wasi_sdflags_t how
){
    int32_t ret = __imported_wasi_snapshot_preview1_sock_shutdown((int32_t) fd, how);
    return (uint16_t) ret;
}

