#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "panic.h"

#define LOG_TRACE 0

enum wasi_errno {
    wasi_errno_success        = 0,
    wasi_errno_2big           = 1,
    wasi_errno_acces          = 2,
    wasi_errno_addrinuse      = 3,
    wasi_errno_addrnotavail   = 4,
    wasi_errno_afnosupport    = 5,
    wasi_errno_again          = 6,
    wasi_errno_already        = 7,
    wasi_errno_badf           = 8,
    wasi_errno_badmsg         = 9,
    wasi_errno_busy           = 10,
    wasi_errno_canceled       = 11,
    wasi_errno_child          = 12,
    wasi_errno_connaborted    = 13,
    wasi_errno_connrefused    = 14,
    wasi_errno_connreset      = 15,
    wasi_errno_deadlk         = 16,
    wasi_errno_destaddrreq    = 17,
    wasi_errno_dom            = 18,
    wasi_errno_dquot          = 19,
    wasi_errno_exist          = 20,
    wasi_errno_fault          = 21,
    wasi_errno_fbig           = 22,
    wasi_errno_hostunreach    = 23,
    wasi_errno_idrm           = 24,
    wasi_errno_ilseq          = 25,
    wasi_errno_inprogress     = 26,
    wasi_errno_intr           = 27,
    wasi_errno_inval          = 28,
    wasi_errno_io             = 29,
    wasi_errno_isconn         = 30,
    wasi_errno_isdir          = 31,
    wasi_errno_loop           = 32,
    wasi_errno_mfile          = 33,
    wasi_errno_mlink          = 34,
    wasi_errno_msgsize        = 35,
    wasi_errno_multihop       = 36,
    wasi_errno_nametoolong    = 37,
    wasi_errno_netdown        = 38,
    wasi_errno_netreset       = 39,
    wasi_errno_netunreach     = 40,
    wasi_errno_nfile          = 41,
    wasi_errno_nobufs         = 42,
    wasi_errno_nodev          = 43,
    wasi_errno_noent          = 44,
    wasi_errno_noexec         = 45,
    wasi_errno_nolck          = 46,
    wasi_errno_nolink         = 47,
    wasi_errno_nomem          = 48,
    wasi_errno_nomsg          = 49,
    wasi_errno_noprotoopt     = 50,
    wasi_errno_nospc          = 51,
    wasi_errno_nosys          = 52,
    wasi_errno_notconn        = 53,
    wasi_errno_notdir         = 54,
    wasi_errno_notempty       = 55,
    wasi_errno_notrecoverable = 56,
    wasi_errno_notsock        = 57,
    wasi_errno_opnotsupp      = 58,
    wasi_errno_notty          = 59,
    wasi_errno_nxio           = 60,
    wasi_errno_overflow       = 61,
    wasi_errno_ownerdead      = 62,
    wasi_errno_perm           = 63,
    wasi_errno_pipe           = 64,
    wasi_errno_proto          = 65,
    wasi_errno_protonosupport = 66,
    wasi_errno_prototype      = 67,
    wasi_errno_range          = 68,
    wasi_errno_rofs           = 69,
    wasi_errno_spipe          = 70,
    wasi_errno_srch           = 71,
    wasi_errno_stale          = 72,
    wasi_errno_timedout       = 73,
    wasi_errno_txtbsy         = 74,
    wasi_errno_xdev           = 75,
    wasi_errno_notcapable     = 76,
};

enum wasi_oflags {
    wasi_oflags_creat     = 1 << 0,
    wasi_oflags_directory = 1 << 1,
    wasi_oflags_excl      = 1 << 2,
    wasi_oflags_trunc     = 1 << 3,
};

enum wasi_rights {
    wasi_rights_fd_datasync             = 1ull <<  0,
    wasi_rights_fd_read                 = 1ull <<  1,
    wasi_rights_fd_seek                 = 1ull <<  2,
    wasi_rights_fd_fdstat_set_flags     = 1ull <<  3,
    wasi_rights_fd_sync                 = 1ull <<  4,
    wasi_rights_fd_tell                 = 1ull <<  5,
    wasi_rights_fd_write                = 1ull <<  6,
    wasi_rights_fd_advise               = 1ull <<  7,
    wasi_rights_fd_allocate             = 1ull <<  8,
    wasi_rights_path_create_directory   = 1ull <<  9,
    wasi_rights_path_create_file        = 1ull << 10,
    wasi_rights_path_link_source        = 1ull << 11,
    wasi_rights_path_link_target        = 1ull << 12,
    wasi_rights_path_open               = 1ull << 13,
    wasi_rights_fd_readdir              = 1ull << 14,
    wasi_rights_path_readlink           = 1ull << 15,
    wasi_rights_path_rename_source      = 1ull << 16,
    wasi_rights_path_rename_target      = 1ull << 17,
    wasi_rights_path_filestat_get       = 1ull << 18,
    wasi_rights_path_filestat_set_size  = 1ull << 19,
    wasi_rights_path_filestat_set_times = 1ull << 20,
    wasi_rights_fd_filestat_get         = 1ull << 21,
    wasi_rights_fd_filestat_set_size    = 1ull << 22,
    wasi_rights_fd_filestat_set_times   = 1ull << 23,
    wasi_rights_path_symlink            = 1ull << 24,
    wasi_rights_path_remove_directory   = 1ull << 25,
    wasi_rights_path_unlink_file        = 1ull << 26,
    wasi_rights_poll_fd_readwrite       = 1ull << 27,
    wasi_rights_sock_shutdown           = 1ull << 28,
    wasi_rights_sock_accept             = 1ull << 29,
};

enum wasi_clockid {
    wasi_clockid_realtime           = 0,
    wasi_clockid_monotonic          = 1,
    wasi_clockid_process_cputime_id = 2,
    wasi_clockid_thread_cputime_id  = 3,
};

enum wasi_filetype {
    wasi_filetype_unknown          = 0,
    wasi_filetype_block_device     = 1,
    wasi_filetype_character_device = 2,
    wasi_filetype_directory        = 3,
    wasi_filetype_regular_file     = 4,
    wasi_filetype_socket_dgram     = 5,
    wasi_filetype_socket_stream    = 6,
    wasi_filetype_symbolic_link    = 7,
};

enum wasi_fdflags {
    wasi_fdflags_append   = 1 << 0,
    wasi_fdflags_dsync    = 1 << 1,
    wasi_fdflags_nonblock = 1 << 2,
    wasi_fdflags_rsync    = 1 << 3,
    wasi_fdflags_sync     = 1 << 4,
};

struct wasi_filestat {
    uint64_t dev;
    uint64_t ino;
    uint64_t filetype;
    uint64_t nlink;
    uint64_t size;
    uint64_t atim;
    uint64_t mtim;
    uint64_t ctim;
};

struct wasi_fdstat {
    uint16_t fs_filetype;
    uint16_t fs_flags;
    uint32_t padding;
    uint64_t fs_rights_inheriting;
};

struct wasi_ciovec {
    uint32_t ptr;
    uint32_t len;
};

enum wasi_whence {
    wasi_whence_set = 0,
    wasi_whence_cur = 1,
    wasi_whence_end = 2,
};

extern uint8_t **const wasm_memory;
extern void wasm__start(void);

static int global_argc;
static char **global_argv;

static uint32_t de_len;
struct DirEntry {
    enum wasi_filetype filetype;
    time_t atim;
    time_t mtim;
    time_t ctim;
    char *guest_path;
    char *host_path;
} *des;

static uint32_t fd_len;
static struct FileDescriptor {
    uint32_t de;
    enum wasi_fdflags fdflags;
    FILE *stream;
    uint64_t fs_rights_inheriting;
} *fds;

static void *dupe(const void *data, size_t len) {
    void *copy = malloc(len);
    if (copy == NULL) panic("out of memory");
    memcpy(copy, data, len);
    return copy;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <zig-lib-path> <args...>\n", argv[0]);
        return 1;
    }

    global_argc = argc;
    global_argv = argv;

    time_t now = time(NULL);
    srand((unsigned)now);

    de_len = 4;
    des = calloc(de_len, sizeof(struct DirEntry));
    if (des == NULL) panic("out of memory");

    des[0].filetype = wasi_filetype_character_device;

    des[1].filetype = wasi_filetype_directory;
    des[1].guest_path = dupe(".", sizeof("."));
    des[1].host_path = dupe(".", sizeof("."));

    des[2].filetype = wasi_filetype_directory;
    des[2].guest_path = dupe("/cache", sizeof("/cache"));
    des[2].atim = now;
    des[2].mtim = now;
    des[2].ctim = now;

    des[3].filetype = wasi_filetype_directory;
    des[3].guest_path = dupe("/lib", sizeof("/lib"));
    des[3].host_path = dupe(argv[1], strlen(argv[1]) + 1);

    fd_len = 6;
    fds = calloc(sizeof(struct FileDescriptor), fd_len);
    if (fds == NULL) panic("out of memory");
    fds[0].stream = stdin;
    fds[1].stream = stdout;
    fds[2].stream = stderr;
    fds[3].de = 1;
    fds[4].de = 2;
    fds[5].de = 3;

    wasm__start();
}

static bool isLetter(char c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}
static bool isPathSep(char c) {
    return c == '/' || c == '\\';
}
static bool isAbsPath(const char *path, uint32_t path_len) {
    if (path_len >= 1 && isPathSep(path[0])) return true;
    if (path_len >= 3 && isLetter(path[0]) && path[1] == ':' && isPathSep(path[2])) return true;
    return false;
}
static bool isSamePath(const char *a, const char *b, uint32_t len) {
    for (uint32_t i = 0; i < len; i += 1) {
        if (isPathSep(a[i]) && isPathSep(b[i])) continue;
        if (a[i] != b[i]) return false;
    }
    return true;
}

static enum wasi_errno DirEntry_create(uint32_t dir_fd, const char *path, uint32_t path_len, enum wasi_filetype filetype, time_t tim, uint32_t *res_de) {
    if (isAbsPath(path, path_len)) {
        if (dir_fd >= fd_len || fds[dir_fd].de >= de_len) return wasi_errno_badf;
        if (des[fds[dir_fd].de].filetype != wasi_filetype_directory) return wasi_errno_notdir;
    }

    struct DirEntry *new_des = realloc(des, (de_len + 1) * sizeof(struct DirEntry));
    if (new_des == NULL) return wasi_errno_nomem;
    des = new_des;

    struct DirEntry *de = &des[de_len];
    de->filetype = filetype;
    de->atim = tim;
    de->mtim = tim;
    de->ctim = tim;
    if (isAbsPath(path, path_len)) {
        de->guest_path = malloc(path_len + 1);
        if (de->guest_path == NULL) return wasi_errno_nomem;
        memcpy(&de->guest_path[0], path, path_len);
        de->guest_path[path_len] = '\0';

        de->host_path = malloc(path_len + 1);
        if (de->host_path == NULL) return wasi_errno_nomem;
        memcpy(&de->host_path[0], path, path_len);
        de->host_path[path_len] = '\0';
    } else {
        const struct DirEntry *dir_de = &des[fds[dir_fd].de];
        if (dir_de->guest_path != NULL) {
            size_t dir_guest_path_len = strlen(dir_de->guest_path);
            de->guest_path = malloc(dir_guest_path_len + 1 + path_len + 1);
            if (de->guest_path == NULL) return wasi_errno_nomem;
            memcpy(&de->guest_path[0], dir_de->guest_path, dir_guest_path_len);
            de->guest_path[dir_guest_path_len] = '/';
            memcpy(&de->guest_path[dir_guest_path_len + 1], path, path_len);
            de->guest_path[dir_guest_path_len + 1 + path_len] = '\0';
        } else de->guest_path = NULL;

        if (dir_de->host_path != NULL) {
            size_t dir_host_path_len = strlen(dir_de->host_path);
            de->host_path = malloc(dir_host_path_len + 1 + path_len + 1);
            if (de->host_path == NULL) { free(de->guest_path); return wasi_errno_nomem; }
            memcpy(&de->host_path[0], dir_de->host_path, dir_host_path_len);
            de->host_path[dir_host_path_len] = '/';
            memcpy(&de->host_path[dir_host_path_len + 1], path, path_len);
            de->host_path[dir_host_path_len + 1 + path_len] = '\0';
        } else de->host_path = NULL;
    }

    if (res_de != NULL) *res_de = de_len;
    de_len += 1;
    return wasi_errno_success;
}

static enum wasi_errno DirEntry_lookup(uint32_t dir_fd, uint32_t flags, const char *path, uint32_t path_len, uint32_t *res_de) {
    (void)flags;
    if (isAbsPath(path, path_len)) {
        for (uint32_t de = 0; de < de_len; de += 1) {
            if (des[de].guest_path == NULL) continue;
            if (!isSamePath(&des[de].guest_path[0], path, path_len)) continue;
            if (des[de].guest_path[path_len] != '\0') continue;
            if (res_de != NULL) *res_de = de;
            return wasi_errno_success;
        }
    } else {
        if (dir_fd >= fd_len || fds[dir_fd].de >= de_len) return wasi_errno_badf;
        const struct DirEntry *dir_de = &des[fds[dir_fd].de];
        if (dir_de->filetype != wasi_filetype_directory) return wasi_errno_notdir;

        size_t dir_guest_path_len = strlen(dir_de->guest_path);
        for (uint32_t de = 0; de < de_len; de += 1) {
            if (des[de].guest_path == NULL) continue;
            if (!isSamePath(&des[de].guest_path[0], dir_de->guest_path, dir_guest_path_len)) continue;
            if (!isPathSep(des[de].guest_path[dir_guest_path_len])) continue;
            if (!isSamePath(&des[de].guest_path[dir_guest_path_len + 1], path, path_len)) continue;
            if (des[de].guest_path[dir_guest_path_len + 1 + path_len] != '\0') continue;
            if (res_de != NULL) *res_de = de;
            return wasi_errno_success;
        }
    }
    return wasi_errno_noent;
}

static void DirEntry_filestat(uint32_t de, struct wasi_filestat *res_filestat) {
    res_filestat->dev = 0;
    res_filestat->ino = de;
    res_filestat->filetype = des[de].filetype;
    res_filestat->nlink = 1;
    res_filestat->size = 0;
    res_filestat->atim = des[de].atim * UINT64_C(1000000000);
    res_filestat->mtim = des[de].mtim * UINT64_C(1000000000);
    res_filestat->ctim = des[de].ctim * UINT64_C(1000000000);
}

static void DirEntry_unlink(uint32_t de) {
    free(des[de].guest_path);
    des[de].guest_path = NULL;
    free(des[de].host_path);
    des[de].host_path = NULL;
}

uint32_t wasi_snapshot_preview1_args_sizes_get(uint32_t argv_size, uint32_t argv_buf_size) {
    uint8_t *const m = *wasm_memory;
    uint32_t *argv_size_ptr = (uint32_t *)&m[argv_size];
    uint32_t *argv_buf_size_ptr = (uint32_t *)&m[argv_buf_size];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_args_sizes_get()\n");
#endif

    int c_argc = global_argc;
    char **c_argv = global_argv;
    uint32_t size = 0;
    for (int i = 0; i < c_argc; i += 1) {
        if (i == 1) continue;
        size += strlen(c_argv[i]) + 1;
    }
    *argv_size_ptr = c_argc - 1;
    *argv_buf_size_ptr = size;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_args_get(uint32_t argv, uint32_t argv_buf) {
    uint8_t *const m = *wasm_memory;
    uint32_t *argv_ptr = (uint32_t *)&m[argv];
    char *argv_buf_ptr = (char *)&m[argv_buf];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_args_get()\n");
#endif

    int c_argc = global_argc;
    char **c_argv = global_argv;
    uint32_t dst_i = 0;
    uint32_t argv_buf_i = 0;
    for (int src_i = 0; src_i < c_argc; src_i += 1) {
        if (src_i == 1) continue;
        argv_ptr[dst_i] = argv_buf + argv_buf_i;
        dst_i += 1;
        strcpy(&argv_buf_ptr[argv_buf_i], c_argv[src_i]);
        argv_buf_i += strlen(c_argv[src_i]) + 1;
    }
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_fd_prestat_get(uint32_t fd, uint32_t res_prestat) {
    uint8_t *const m = *wasm_memory;
    uint32_t *res_prestat_ptr = (uint32_t *)&m[res_prestat];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_prestat_get(%u)\n", fd);
#endif

    if (fd >= fd_len || fds[fd].de >= de_len) return wasi_errno_badf;

    res_prestat_ptr[0] = 0;
    res_prestat_ptr[1] = strlen(des[fds[fd].de].guest_path);
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_fd_prestat_dir_name(uint32_t fd, uint32_t path, uint32_t path_len) {
    uint8_t *const m = *wasm_memory;
    char *path_ptr = (char *)&m[path];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_prestat_dir_name(%u, \"%.*s\")\n", fd, (int)path_len, path_ptr);
#endif

    if (fd >= fd_len || fds[fd].de >= de_len) return wasi_errno_badf;
    strncpy(path_ptr, des[fds[fd].de].guest_path, path_len);
    return wasi_errno_success;
}

void wasi_snapshot_preview1_proc_exit(uint32_t rval) {
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_proc_exit(%u)\n", rval);
#endif

    exit(rval);
}

uint32_t wasi_snapshot_preview1_fd_close(uint32_t fd) {
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_close(%u)\n", fd);
#endif

    if (fd >= fd_len || fds[fd].de >= de_len) return wasi_errno_badf;
    if (fds[fd].stream != NULL) fclose(fds[fd].stream);

    fds[fd].de = ~0;
    fds[fd].stream = NULL;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_path_create_directory(uint32_t fd, uint32_t path, uint32_t path_len) {
    uint8_t *const m = *wasm_memory;
    const char *path_ptr = (const char *)&m[path];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_path_create_directory(%u, \"%.*s\")\n", fd, (int)path_len, path_ptr);
#endif

    enum wasi_errno lookup_errno = DirEntry_lookup(fd, 0, path_ptr, path_len, NULL);
    switch (lookup_errno) {
        case wasi_errno_success: return wasi_errno_exist;
        case wasi_errno_noent: break;
        default: return lookup_errno;
    }
    return DirEntry_create(fd, path_ptr, path_len, wasi_filetype_directory, time(NULL), NULL);
}

uint32_t wasi_snapshot_preview1_fd_read(uint32_t fd, uint32_t iovs, uint32_t iovs_len, uint32_t res_size) {
    uint8_t *const m = *wasm_memory;
    struct wasi_ciovec *iovs_ptr = (struct wasi_ciovec *)&m[iovs];
    uint32_t *res_size_ptr = (uint32_t *)&m[res_size];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_read(%u, 0x%X, %u)\n", fd, iovs, iovs_len);
#endif

    if (fd >= fd_len || fds[fd].de >= de_len) return wasi_errno_badf;
    switch (des[fds[fd].de].filetype) {
        case wasi_filetype_character_device: break;
        case wasi_filetype_regular_file: break;
        case wasi_filetype_directory: return wasi_errno_inval;
        default: panic("unimplemented");
    }

    size_t size = 0;
    for (uint32_t i = 0; i < iovs_len; i += 1) {
        size_t read_size = 0;
        if (fds[fd].stream != NULL)
            read_size = fread(&m[iovs_ptr[i].ptr], 1, iovs_ptr[i].len, fds[fd].stream);
        size += read_size;
        if (read_size < iovs_ptr[i].len) break;
    }

    if (size > 0) des[fds[fd].de].atim = time(NULL);
    *res_size_ptr = size;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_fd_filestat_get(uint32_t fd, uint32_t res_filestat) {
    uint8_t *const m = *wasm_memory;
    struct wasi_filestat *res_filestat_ptr = (struct wasi_filestat *)&m[res_filestat];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_filestat_get(%u)\n", fd);
#endif

    if (fd >= fd_len || fds[fd].de >= de_len) return wasi_errno_badf;
    DirEntry_filestat(fds[fd].de, res_filestat_ptr);
    if (des[fds[fd].de].filetype != wasi_filetype_regular_file) return wasi_errno_success;
    if (fds[fd].stream == NULL) return wasi_errno_success;
    fpos_t pos;
    if (fgetpos(fds[fd].stream, &pos) < 0) return wasi_errno_io;
    if (fseek(fds[fd].stream, 0, SEEK_END) < 0) return wasi_errno_io;
    long size = ftell(fds[fd].stream);
    if (size < 0) return wasi_errno_io;
    res_filestat_ptr->size = size;
    if (fsetpos(fds[fd].stream, &pos) < 0) return wasi_errno_io;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_path_rename(uint32_t fd, uint32_t old_path, uint32_t old_path_len, uint32_t new_fd, uint32_t new_path, uint32_t new_path_len) {
    uint8_t *const m = *wasm_memory;
    const char *old_path_ptr = (const char *)&m[old_path];
    const char *new_path_ptr = (const char *)&m[new_path];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_path_rename(%u, \"%.*s\", %u, \"%.*s\")\n", fd, (int)old_path_len, old_path_ptr, new_fd, (int)new_path_len, new_path_ptr);
#endif

    uint32_t old_de;
    enum wasi_errno old_lookup_errno = DirEntry_lookup(fd, 0, old_path_ptr, old_path_len, &old_de);
    if (old_lookup_errno != wasi_errno_success) return old_lookup_errno;
    DirEntry_unlink(old_de);

    uint32_t de;
    enum wasi_errno new_lookup_errno = DirEntry_lookup(new_fd, 0, new_path_ptr, new_path_len, &de);
    switch (new_lookup_errno) {
        case wasi_errno_success: DirEntry_unlink(de); break;
        case wasi_errno_noent: break;
        default: return new_lookup_errno;
    }

    uint32_t new_de;
    enum wasi_errno create_errno =
        DirEntry_create(new_fd, new_path_ptr, new_path_len, des[old_de].filetype, 0, &new_de);
    if (create_errno != wasi_errno_success) return create_errno;
    des[new_de].atim = des[old_de].atim;
    des[new_de].mtim = des[old_de].mtim;
    des[new_de].ctim = time(NULL);
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_fd_filestat_set_size(uint32_t fd, uint64_t size) {
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_filestat_set_size(%u, %llu)\n", fd, (unsigned long long)size);
#endif

    if (fd >= fd_len || fds[fd].de >= de_len) return wasi_errno_badf;
    if (des[fds[fd].de].filetype != wasi_filetype_regular_file) return wasi_errno_inval;

    if (fds[fd].stream == NULL) return wasi_errno_success;
    fpos_t pos;
    if (fgetpos(fds[fd].stream, &pos) < 0) return wasi_errno_io;
    if (fseek(fds[fd].stream, 0, SEEK_END) < 0) return wasi_errno_io;
    long old_size = ftell(fds[fd].stream);
    if (old_size < 0) return wasi_errno_io;
    if (size != (unsigned long)old_size) {
        if (size > 0 && fseek(fds[fd].stream, size - 1, SEEK_SET) < 0) return wasi_errno_io;
        if (size < (unsigned long)old_size) {
            // Note that this destroys the contents on resize might have to save truncated
            // file in memory if this becomes an issue.
            FILE *trunc = fopen(des[fds[fd].de].host_path, "wb");
            if (trunc == NULL) return wasi_errno_io;
            fclose(trunc);
        }
        if (size > 0) fputc(0, fds[fd].stream);
    }
    if (fsetpos(fds[fd].stream, &pos) < 0) return wasi_errno_io;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_fd_pwrite(uint32_t fd, uint32_t iovs, uint32_t iovs_len, uint64_t offset, uint32_t res_size) {
    uint8_t *const m = *wasm_memory;
    struct wasi_ciovec *iovs_ptr = (struct wasi_ciovec *)&m[iovs];
    uint32_t *res_size_ptr = (uint32_t *)&m[res_size];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_pwrite(%u, 0x%X, %u)\n", fd, iovs, iovs_len);
#endif

    if (fd >= fd_len || fds[fd].de >= de_len) return wasi_errno_badf;
    switch (des[fds[fd].de].filetype) {
        case wasi_filetype_character_device: break;
        case wasi_filetype_regular_file: break;
        case wasi_filetype_directory: return wasi_errno_inval;
        default: panic("unimplemented");
    }

    fpos_t pos;
    if (fgetpos(fds[fd].stream, &pos) < 0) return wasi_errno_io;
    if (fseek(fds[fd].stream, offset, SEEK_SET) < 0) return wasi_errno_io;

    size_t size = 0;
    for (uint32_t i = 0; i < iovs_len; i += 1) {
        size_t written_size = 0;
        if (fds[fd].stream != NULL)
            written_size = fwrite(&m[iovs_ptr[i].ptr], 1, iovs_ptr[i].len, fds[fd].stream);
        else
            written_size = iovs_ptr[i].len;
        size += written_size;
        if (written_size < iovs_ptr[i].len) break;
    }

    if (fsetpos(fds[fd].stream, &pos) < 0) return wasi_errno_io;

    if (size > 0) {
        time_t now = time(NULL);
        des[fds[fd].de].atim = now;
        des[fds[fd].de].mtim = now;
    }
    *res_size_ptr = size;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_random_get(uint32_t buf, uint32_t buf_len) {
    uint8_t *const m = *wasm_memory;
    uint8_t *buf_ptr = (uint8_t *)&m[buf];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_random_get(%u)\n", buf_len);
#endif

    for (uint32_t i = 0; i < buf_len; i += 1) buf_ptr[i] = (uint8_t)rand();
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_fd_filestat_set_times(uint32_t fd, uint64_t atim, uint64_t mtim, uint32_t fst_flags) {
    (void)fd;
    (void)atim;
    (void)mtim;
    (void)fst_flags;
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_filestat_set_times(%u, %llu, %llu, 0x%X)\n", fd, (unsigned long long)atim, (unsigned long long)mtim, fst_flags);
#endif

    panic("unimplemented");
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_environ_sizes_get(uint32_t environ_size, uint32_t environ_buf_size) {
    uint8_t *const m = *wasm_memory;
    uint32_t *environ_size_ptr = (uint32_t *)&m[environ_size];
    uint32_t *environ_buf_size_ptr = (uint32_t *)&m[environ_buf_size];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_environ_sizes_get()\n");
#endif

    *environ_size_ptr = 0;
    *environ_buf_size_ptr = 0;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_environ_get(uint32_t environ, uint32_t environ_buf) {
    (void)environ;
    (void)environ_buf;
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_environ_get()\n");
#endif

    panic("unimplemented");
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_path_filestat_get(uint32_t fd, uint32_t flags, uint32_t path, uint32_t path_len, uint32_t res_filestat) {
    uint8_t *const m = *wasm_memory;
    const char *path_ptr = (const char *)&m[path];
    struct wasi_filestat *res_filestat_ptr = (struct wasi_filestat *)&m[res_filestat];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_path_filestat_get(%u, 0x%X, \"%.*s\")\n", fd, flags, (int)path_len, path_ptr);
#endif

    uint32_t de;
    enum wasi_errno lookup_errno = DirEntry_lookup(fd, flags, path_ptr, path_len, &de);
    if (lookup_errno != wasi_errno_success) return lookup_errno;
    DirEntry_filestat(de, res_filestat_ptr);
    if (des[de].filetype == wasi_filetype_regular_file && des[de].host_path != NULL) {
        FILE *stream = fopen(des[de].host_path, "rb");
        if (stream != NULL) {
            if (fseek(stream, 0, SEEK_END) >= 0) {
                long size = ftell(stream);
                if (size >= 0) res_filestat_ptr->size = size;
            }
            fclose(stream);
        }
    }
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_fd_fdstat_get(uint32_t fd, uint32_t res_fdstat) {
    uint8_t *const m = *wasm_memory;
    struct wasi_fdstat *res_fdstat_ptr = (struct wasi_fdstat *)&m[res_fdstat];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_fdstat_get(%u)\n", fd);
#endif

    if (fd >= fd_len || fds[fd].de >= de_len) return wasi_errno_badf;
    res_fdstat_ptr->fs_filetype = des[fds[fd].de].filetype;
    res_fdstat_ptr->fs_flags = fds[fd].fdflags;
    res_fdstat_ptr->padding = 0;
    res_fdstat_ptr->fs_rights_inheriting = fds[fd].fs_rights_inheriting;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_fd_readdir(uint32_t fd, uint32_t buf, uint32_t buf_len, uint64_t cookie, uint32_t res_size) {
    (void)fd;
    (void)buf;
    (void)buf_len;
    (void)cookie;
    (void)res_size;
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_readdir(%u, 0x%X, %u, %llu)\n", fd, buf, buf_len, (unsigned long long)cookie);
#endif

    panic("unimplemented");
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_fd_write(uint32_t fd, uint32_t iovs, uint32_t iovs_len, uint32_t res_size) {
    uint8_t *const m = *wasm_memory;
    struct wasi_ciovec *iovs_ptr = (struct wasi_ciovec *)&m[iovs];
    uint32_t *res_size_ptr = (uint32_t *)&m[res_size];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_write(%u, 0x%X, %u)\n", fd, iovs, iovs_len);
#endif

    if (fd >= fd_len || fds[fd].de >= de_len) return wasi_errno_badf;
    switch (des[fds[fd].de].filetype) {
        case wasi_filetype_character_device: break;
        case wasi_filetype_regular_file: break;
        case wasi_filetype_directory: return wasi_errno_inval;
        default: panic("unimplemented");
    }

    size_t size = 0;
    for (uint32_t i = 0; i < iovs_len; i += 1) {
        size_t written_size = 0;
        if (fds[fd].stream != NULL)
            written_size = fwrite(&m[iovs_ptr[i].ptr], 1, iovs_ptr[i].len, fds[fd].stream);
        else
            written_size = iovs_ptr[i].len;
        size += written_size;
        if (written_size < iovs_ptr[i].len) break;
    }

    if (size > 0) {
        time_t now = time(NULL);
        des[fds[fd].de].atim = now;
        des[fds[fd].de].mtim = now;
    }
    *res_size_ptr = size;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_path_open(uint32_t fd, uint32_t dirflags, uint32_t path, uint32_t path_len, uint32_t oflags, uint64_t fs_rights_base, uint64_t fs_rights_inheriting, uint32_t fdflags, uint32_t res_fd) {
    uint8_t *const m = *wasm_memory;
    const char *path_ptr = (const char *)&m[path];
    uint32_t *res_fd_ptr = (uint32_t *)&m[res_fd];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_path_open(%u, 0x%X, \"%.*s\", 0x%X, 0x%llX, 0x%llX, 0x%X)\n", fd, dirflags, (int)path_len, path_ptr, oflags, (unsigned long long)fs_rights_base, (unsigned long long)fs_rights_inheriting, fdflags);
#endif

    bool creat = (oflags & wasi_oflags_creat) != 0;
    bool directory = (oflags & wasi_oflags_directory) != 0;
    bool excl = (oflags & wasi_oflags_excl) != 0;
    bool trunc = (oflags & wasi_oflags_trunc) != 0;
    bool append = (fdflags & wasi_fdflags_append) != 0;

    uint32_t de;
    enum wasi_errno lookup_errno = DirEntry_lookup(fd, dirflags, path_ptr, path_len, &de);
    if (lookup_errno == wasi_errno_success) {
        if (directory && des[de].filetype != wasi_filetype_directory) return wasi_errno_notdir;

        struct FileDescriptor *new_fds = realloc(fds, (fd_len + 1) * sizeof(struct FileDescriptor));
        if (new_fds == NULL) return wasi_errno_nomem;
        fds = new_fds;

        fds[fd_len].de = de;
        fds[fd_len].fdflags = fdflags;
        switch (des[de].filetype) {
            case wasi_filetype_directory: fds[fd_len].stream = NULL; break;
            default: panic("unimplemented");
        }
        fds[fd_len].fs_rights_inheriting = fs_rights_inheriting;

#if LOG_TRACE
        fprintf(stderr, "fd = %u\n", fd_len);
#endif
        *res_fd_ptr = fd_len;
        fd_len += 1;
    }
    if (lookup_errno != wasi_errno_noent) return lookup_errno;

    struct FileDescriptor *new_fds = realloc(fds, (fd_len + 1) * sizeof(struct FileDescriptor));
    if (new_fds == NULL) return wasi_errno_nomem;
    fds = new_fds;

    enum wasi_filetype filetype = directory ? wasi_filetype_directory : wasi_filetype_regular_file;
    enum wasi_errno create_errno = DirEntry_create(fd, path_ptr, path_len, filetype, 0, &de);
    if (create_errno != wasi_errno_success) return create_errno;
    FILE *stream;
    if (!directory) {
        if (des[de].host_path == NULL) {
            if (!creat) { DirEntry_unlink(de); de_len -= 1; return wasi_errno_noent; }
            time_t now = time(NULL);
            des[de].atim = now;
            des[de].mtim = now;
            des[de].ctim = now;
            stream = NULL;
        } else {
            if (oflags != (append ? wasi_oflags_creat : wasi_oflags_creat | wasi_oflags_trunc)) {
                char mode[] = "rb+";
                if ((fs_rights_base & wasi_rights_fd_write) == 0) mode[2] = '\0';
                stream = fopen(des[de].host_path, mode);
                if (stream != NULL) {
                    if (append || excl || trunc) fclose(stream);
                    if (excl) {
                        DirEntry_unlink(de);
                        de_len -= 1;
                        return wasi_errno_exist;
                    }
                } else if (!creat) { DirEntry_unlink(de); de_len -= 1; return wasi_errno_noent; }
            }
            if (append || trunc || stream == NULL) {
                char mode[] = "wb+";
                if ((fs_rights_base & wasi_rights_fd_read) == 0) mode[2] = '\0';
                if (trunc || !append) {
                    stream = fopen(des[de].host_path, mode);
                    if (append && stream != NULL) fclose(stream);
                }
                if (append) {
                    mode[0] = 'a';
                    stream = fopen(des[de].host_path, mode);
                }
            }
            if (stream == NULL) { DirEntry_unlink(de); de_len -= 1; return wasi_errno_isdir; }
        }
    } else stream = NULL;

#if LOG_TRACE
    fprintf(stderr, "fd = %u\n", fd_len);
#endif
    fds[fd_len].de = de;
    fds[fd_len].fdflags = fdflags;
    fds[fd_len].stream = stream;
    fds[fd_len].fs_rights_inheriting = fs_rights_inheriting;
    *res_fd_ptr = fd_len;
    fd_len += 1;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_clock_time_get(uint32_t id, uint64_t precision, uint32_t res_timestamp) {
    uint8_t *const m = *wasm_memory;
    (void)precision;
    uint64_t *res_timestamp_ptr = (uint64_t *)&m[res_timestamp];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_clock_time_get(%u, %llu)\n", id, (unsigned long long)precision);
#endif

    switch (id) {
        case wasi_clockid_realtime:
            *res_timestamp_ptr = time(NULL) * UINT64_C(1000000000);
            break;
        case wasi_clockid_monotonic:
        case wasi_clockid_process_cputime_id:
        case wasi_clockid_thread_cputime_id:
            *res_timestamp_ptr = clock() * (UINT64_C(1000000000) / CLOCKS_PER_SEC);
            break;
        default: return wasi_errno_inval;
    }
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_path_remove_directory(uint32_t fd, uint32_t path, uint32_t path_len) {
    uint8_t *const m = *wasm_memory;
    const char *path_ptr = (const char *)&m[path];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_path_remove_directory(%u, \"%.*s\")\n", fd, (int)path_len, path_ptr);
#endif

    uint32_t de;
    enum wasi_errno lookup_errno = DirEntry_lookup(fd, 0, path_ptr, path_len, &de);
    if (lookup_errno != wasi_errno_success) return lookup_errno;
    if (des[de].filetype != wasi_filetype_directory) return wasi_errno_notdir;
    DirEntry_unlink(de);
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_path_unlink_file(uint32_t fd, uint32_t path, uint32_t path_len) {
    uint8_t *const m = *wasm_memory;
    const char *path_ptr = (const char *)&m[path];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_path_unlink_file(%u, \"%.*s\")\n", fd, (int)path_len, path_ptr);
#endif

    uint32_t de;
    enum wasi_errno lookup_errno = DirEntry_lookup(fd, 0, path_ptr, path_len, &de);
    if (lookup_errno != wasi_errno_success) return lookup_errno;
    if (des[de].filetype == wasi_filetype_directory) return wasi_errno_isdir;
    if (des[de].filetype != wasi_filetype_regular_file) panic("unimplemented");
    DirEntry_unlink(de);
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_fd_pread(uint32_t fd, uint32_t iovs, uint32_t iovs_len, uint64_t offset, uint32_t res_size) {
    uint8_t *const m = *wasm_memory;
    struct wasi_ciovec *iovs_ptr = (struct wasi_ciovec *)&m[iovs];
    uint32_t *res_size_ptr = (uint32_t *)&m[res_size];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_pread(%u, 0x%X, %u)\n", fd, iovs, iovs_len);
#endif

    if (fd >= fd_len || fds[fd].de >= de_len) return wasi_errno_badf;
    switch (des[fds[fd].de].filetype) {
        case wasi_filetype_character_device: break;
        case wasi_filetype_regular_file: break;
        case wasi_filetype_directory: return wasi_errno_inval;
        default: panic("unimplemented");
    }

    fpos_t pos;
    if (fgetpos(fds[fd].stream, &pos) < 0) return wasi_errno_io;
    if (fseek(fds[fd].stream, offset, SEEK_SET) < 0) return wasi_errno_io;

    size_t size = 0;
    for (uint32_t i = 0; i < iovs_len; i += 1) {
        size_t read_size = 0;
        if (fds[fd].stream != NULL)
            read_size = fread(&m[iovs_ptr[i].ptr], 1, iovs_ptr[i].len, fds[fd].stream);
        else
            panic("unimplemented");
        size += read_size;
        if (read_size < iovs_ptr[i].len) break;
    }

    if (fsetpos(fds[fd].stream, &pos) < 0) return wasi_errno_io;

    if (size > 0) des[fds[fd].de].atim = time(NULL);
    *res_size_ptr = size;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_fd_seek(uint32_t fd, uint64_t in_offset, uint32_t whence, uint32_t res_filesize) {
    uint8_t *const m = *wasm_memory;
    int64_t offset = (int64_t)in_offset;
    uint64_t *res_filesize_ptr = (uint64_t *)&m[res_filesize];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_fd_seek(%u, 0x%lld, %u)\n", fd, (long long)offset, whence);
#endif

    if (fd >= fd_len || fds[fd].de >= de_len) return wasi_errno_badf;
    switch (des[fds[fd].de].filetype) {
        case wasi_filetype_character_device: break;
        case wasi_filetype_regular_file: break;
        case wasi_filetype_directory: return wasi_errno_inval;
        default: panic("unimplemented");
    }

    int seek_whence;
    switch (whence) {
        case wasi_whence_set:
            seek_whence = SEEK_SET;
            break;
        case wasi_whence_cur:
            seek_whence = SEEK_CUR;
            break;
        case wasi_whence_end:
            seek_whence = SEEK_END;
            break;
        default:
            return wasi_errno_inval;
    }
    if (fseek(fds[fd].stream, offset, seek_whence) < 0) return wasi_errno_io;
    long res_offset = ftell(fds[fd].stream);
    if (res_offset < 0) return wasi_errno_io;
    *res_filesize_ptr = (uint64_t)res_offset;
    return wasi_errno_success;
}

uint32_t wasi_snapshot_preview1_poll_oneoff(uint32_t in, uint32_t out, uint32_t nsubscriptions, uint32_t res_nevents) {
    (void)in;
    (void)out;
    (void)nsubscriptions;
    (void)res_nevents;
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_poll_oneoff(%u)\n", nsubscriptions);
#endif

    panic("unimplemented");
    return wasi_errno_success;
}

void wasi_snapshot_preview1_debug(uint32_t string, uint64_t x) {
    uint8_t *const m = *wasm_memory;
    const char *string_ptr = (const char *)&m[string];
#if LOG_TRACE
    fprintf(stderr, "wasi_snapshot_preview1_debug(\"%s\", %llu, 0x%llX)\n", string_ptr, (unsigned long long)x, (unsigned long long)x);
#endif

    (void)string_ptr;
    (void)x;
}
