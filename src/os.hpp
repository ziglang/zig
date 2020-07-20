/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_OS_HPP
#define ZIG_OS_HPP

#include "list.hpp"
#include "buffer.hpp"
#include "error.hpp"
#include "zig_llvm.h"
#include "windows_sdk.h"

#include <stdio.h>
#include <inttypes.h>

#if defined(__APPLE__)
#define ZIG_OS_DARWIN
#elif defined(_WIN32)
#define ZIG_OS_WINDOWS
#elif defined(__linux__)
#define ZIG_OS_LINUX
#elif defined(__FreeBSD__)
#define ZIG_OS_FREEBSD
#elif defined(__NetBSD__)
#define ZIG_OS_NETBSD
#elif defined(__DragonFly__)
#define ZIG_OS_DRAGONFLY
#else
#define ZIG_OS_UNKNOWN
#endif

#if defined(__x86_64__)
#define ZIG_ARCH_X86_64
#elif defined(__aarch64__)
#define ZIG_ARCH_ARM64
#elif defined(__ARM_EABI__)
#define ZIG_ARCH_ARM
#else
#define ZIG_ARCH_UNKNOWN
#endif

#if defined(ZIG_OS_WINDOWS)
#define ZIG_PRI_usize "I64u"
#define ZIG_PRI_i64 "I64d"
#define ZIG_PRI_u64 "I64u"
#define ZIG_PRI_llu "I64u"
#define ZIG_PRI_x64 "I64x"
#define OS_SEP "\\"
#define ZIG_OS_SEP_CHAR '\\'
#else
#define ZIG_PRI_usize "zu"
#define ZIG_PRI_i64 PRId64
#define ZIG_PRI_u64 PRIu64
#define ZIG_PRI_llu "llu"
#define ZIG_PRI_x64 PRIx64
#define OS_SEP "/"
#define ZIG_OS_SEP_CHAR '/'
#endif

enum TermColor {
    TermColorRed,
    TermColorGreen,
    TermColorCyan,
    TermColorWhite,
    TermColorBold,
    TermColorReset,
};

enum TerminationId {
    TerminationIdClean,
    TerminationIdSignaled,
    TerminationIdStopped,
    TerminationIdUnknown,
};

struct Termination {
    TerminationId how;
    int code;
};

#if defined(ZIG_OS_WINDOWS)
#define OsFile void *
#else
#define OsFile int
#endif

struct OsTimeStamp {
    int64_t sec;
    int64_t nsec;
};

struct OsFileAttr {
    OsTimeStamp mtime;
    uint64_t size;
    uint64_t inode;
    uint32_t mode;
};

int os_init(void);

void os_spawn_process(ZigList<const char *> &args, Termination *term);
Error os_exec_process(ZigList<const char *> &args,
        Termination *term, Buf *out_stderr, Buf *out_stdout);
Error os_execv(const char *exe, const char **argv);

void os_path_dirname(Buf *full_path, Buf *out_dirname);
void os_path_split(Buf *full_path, Buf *out_dirname, Buf *out_basename);
void os_path_extname(Buf *full_path, Buf *out_basename, Buf *out_extname);
void os_path_join(Buf *dirname, Buf *basename, Buf *out_full_path);
Error os_path_real(Buf *rel_path, Buf *out_abs_path);
Buf os_path_resolve(Buf **paths_ptr, size_t paths_len);
bool os_path_is_absolute(Buf *path);

Error ATTRIBUTE_MUST_USE os_make_path(Buf *path);
Error ATTRIBUTE_MUST_USE os_make_dir(Buf *path);

Error ATTRIBUTE_MUST_USE os_file_open_r(Buf *full_path, OsFile *out_file, OsFileAttr *attr);
Error ATTRIBUTE_MUST_USE os_file_open_w(Buf *full_path, OsFile *out_file, OsFileAttr *attr, uint32_t mode);
Error ATTRIBUTE_MUST_USE os_file_open_lock_rw(Buf *full_path, OsFile *out_file);
Error ATTRIBUTE_MUST_USE os_file_read(OsFile file, void *ptr, size_t *len);
Error ATTRIBUTE_MUST_USE os_file_read_all(OsFile file, Buf *contents);
Error ATTRIBUTE_MUST_USE os_file_overwrite(OsFile file, Buf *contents);
void os_file_close(OsFile *file);

Error ATTRIBUTE_MUST_USE os_write_file(Buf *full_path, Buf *contents);
Error ATTRIBUTE_MUST_USE os_copy_file(Buf *src_path, Buf *dest_path);
Error ATTRIBUTE_MUST_USE os_update_file(Buf *src_path, Buf *dest_path);
Error ATTRIBUTE_MUST_USE os_dump_file(Buf *src_path, FILE *dest_file);

Error ATTRIBUTE_MUST_USE os_fetch_file(FILE *file, Buf *out_contents);
Error ATTRIBUTE_MUST_USE os_fetch_file_path(Buf *full_path, Buf *out_contents);

Error ATTRIBUTE_MUST_USE os_get_cwd(Buf *out_cwd);

bool os_stderr_tty(void);
void os_stderr_set_color(TermColor color);

Error os_delete_file(Buf *path);

Error ATTRIBUTE_MUST_USE os_file_exists(Buf *full_path, bool *result);

Error os_rename(Buf *src_path, Buf *dest_path);
OsTimeStamp os_timestamp_monotonic(void);
OsTimeStamp os_timestamp_calendar(void);

bool os_is_sep(uint8_t c);

Error ATTRIBUTE_MUST_USE os_self_exe_path(Buf *out_path);

Error ATTRIBUTE_MUST_USE os_get_app_data_dir(Buf *out_path, const char *appname);

Error ATTRIBUTE_MUST_USE os_self_exe_shared_libs(ZigList<Buf *> &paths);

const size_t PATH_MAX_WIDE = 32767;

struct PathSpace {
    Array<wchar_t, PATH_MAX_WIDE> data;
    size_t len;
};

PathSpace slice_to_prefixed_file_w(Slice<uint8_t> path);
#endif
