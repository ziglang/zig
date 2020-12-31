/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "os.hpp"
#include "buffer.hpp"
#include "heap.hpp"
#include "util.hpp"
#include "error.hpp"
#include "util_base.hpp"
#include <stdint.h>
#include <stdio.h>

#if defined(_WIN32)

#if !defined(NOMINMAX)
#define NOMINMAX
#endif

#if !defined(VC_EXTRALEAN)
#define VC_EXTRALEAN
#endif

#if !defined(WIN32_LEAN_AND_MEAN)
#define WIN32_LEAN_AND_MEAN
#endif

#if !defined(_WIN32_WINNT)
#define _WIN32_WINNT 0x600
#endif

#if !defined(NTDDI_VERSION)
#define NTDDI_VERSION 0x06000000
#endif

#include <windows.h>
#include <shlobj.h>
#include <io.h>
#include <fcntl.h>
#include <ntsecapi.h>

// Workaround an upstream LLVM issue.
// See https://github.com/ziglang/zig/issues/7614#issuecomment-752939981
#if defined(_MSC_VER) && defined(_WIN64)
typedef SSIZE_T ssize_t;
#endif
#else
#define ZIG_OS_POSIX

#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/resource.h>
#include <fcntl.h>
#include <limits.h>
#include <spawn.h>

#endif

#if defined(ZIG_OS_LINUX) || defined(ZIG_OS_FREEBSD) || defined(ZIG_OS_NETBSD) || defined(ZIG_OS_DRAGONFLY) || defined(ZIG_OS_OPENBSD)
#include <link.h>
#endif

#if defined(ZIG_OS_LINUX)
#include <sys/auxv.h>
#endif

#if defined(ZIG_OS_FREEBSD) || defined(ZIG_OS_NETBSD) || defined(ZIG_OS_DRAGONFLY) || defined(ZIG_OS_OPENBSD)
#include <sys/sysctl.h>
#endif

#if defined(__MACH__)
#include <mach/clock.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#endif

#if defined(ZIG_OS_WINDOWS)
static void utf16le_ptr_to_utf8(Buf *out, WCHAR *utf16le);
static size_t utf8_to_utf16le(WCHAR *utf16_le, Slice<uint8_t> utf8);
static uint64_t windows_perf_freq;
#elif defined(__MACH__)
static clock_serv_t macos_calendar_clock;
static clock_serv_t macos_monotonic_clock;
#endif

#include <stdlib.h>
#include <errno.h>
#include <time.h>

#if !defined(environ)
extern char **environ;
#endif

void os_path_dirname(Buf *full_path, Buf *out_dirname) {
    return os_path_split(full_path, out_dirname, nullptr);
}

bool os_is_sep(uint8_t c) {
#if defined(ZIG_OS_WINDOWS)
    return c == '\\' || c == '/';
#else
    return c == '/';
#endif
}

void os_path_split(Buf *full_path, Buf *out_dirname, Buf *out_basename) {
    size_t len = buf_len(full_path);
    if (len != 0) {
        size_t last_index = len - 1;
        char last_char = buf_ptr(full_path)[last_index];
        if (os_is_sep(last_char)) {
            if (last_index == 0) {
                if (out_dirname) buf_init_from_mem(out_dirname, &last_char, 1);
                if (out_basename) buf_init_from_str(out_basename, "");
                return;
            }
            last_index -= 1;
        }
        for (size_t i = last_index;;) {
            uint8_t c = buf_ptr(full_path)[i];
            if (os_is_sep(c)) {
                if (out_dirname) {
                    buf_init_from_mem(out_dirname, buf_ptr(full_path), (i == 0) ? 1 : i);
                }
                if (out_basename) {
                    buf_init_from_mem(out_basename, buf_ptr(full_path) + i + 1, buf_len(full_path) - (i + 1));
                }
                return;
            }
            if (i == 0) break;
            i -= 1;
        }
    }
    if (out_dirname) buf_init_from_mem(out_dirname, ".", 1);
    if (out_basename) buf_init_from_buf(out_basename, full_path);
}

void os_path_extname(Buf *full_path, Buf *out_basename, Buf *out_extname) {
    if (buf_len(full_path) == 0) {
        if (out_basename) buf_init_from_str(out_basename, "");
        if (out_extname) buf_init_from_str(out_extname, "");
        return;
    }
    size_t i = buf_len(full_path) - 1;
    while (true) {
        if (buf_ptr(full_path)[i] == '.') {
            if (out_basename) {
                buf_resize(out_basename, 0);
                buf_append_mem(out_basename, buf_ptr(full_path), i);
            }

            if (out_extname) {
                buf_resize(out_extname, 0);
                buf_append_mem(out_extname, buf_ptr(full_path) + i, buf_len(full_path) - i);
            }
            return;
        }

        if (i == 0) {
            if (out_basename) buf_init_from_buf(out_basename, full_path);
            if (out_extname) buf_init_from_str(out_extname, "");
            return;
        }
        i -= 1;
    }
}

void os_path_join(Buf *dirname, Buf *basename, Buf *out_full_path) {
    if (buf_len(dirname) == 0) {
        buf_init_from_buf(out_full_path, basename);
        return;
    }

    buf_init_from_buf(out_full_path, dirname);
    uint8_t c = *(buf_ptr(out_full_path) + buf_len(out_full_path) - 1);
    if (!os_is_sep(c))
        buf_append_char(out_full_path, ZIG_OS_SEP_CHAR);
    buf_append_buf(out_full_path, basename);
}


#if defined(ZIG_OS_WINDOWS)		
// Ported from std/os/path.zig		
static bool isAbsoluteWindows(Slice<uint8_t> path) {		
    if (path.ptr[0] == '/')		
        return true;		

    if (path.ptr[0] == '\\') {		
        return true;		
    }		
    if (path.len < 3) {		
        return false;		
    }		
    if (path.ptr[1] == ':') {		
        if (path.ptr[2] == '/')		
            return true;		
        if (path.ptr[2] == '\\')		
            return true;		
    }		
    return false;		
}		

enum WindowsPathKind {
    WindowsPathKindNone,
    WindowsPathKindDrive,
    WindowsPathKindNetworkShare,
};

struct WindowsPath {
    Slice<uint8_t> disk_designator;
    WindowsPathKind kind;
    bool is_abs;
};


// Ported from std/os/path.zig
static WindowsPath windowsParsePath(Slice<uint8_t> path) {
    if (path.len >= 2 && path.ptr[1] == ':') {
        return WindowsPath{
            path.slice(0, 2),
            WindowsPathKindDrive,
            isAbsoluteWindows(path),
        };
    }
    if (path.len >= 1 && (path.ptr[0] == '/' || path.ptr[0] == '\\') &&
        (path.len == 1 || (path.ptr[1] != '/' && path.ptr[1] != '\\')))
    {
        return WindowsPath{
            path.slice(0, 0),
            WindowsPathKindNone,
            true,
        };
    }
    WindowsPath relative_path = {
        str(""),
        WindowsPathKindNone,
        false,
    };
    if (path.len < strlen("//a/b")) {
        return relative_path;
    }

    {
        if (memStartsWith(path, str("//"))) {
            if (path.ptr[2] == '/') {
                return relative_path;
            }

            SplitIterator it = memSplit(path, str("/"));
            {
                Optional<Slice<uint8_t>> opt_component = SplitIterator_next(&it);
                if (!opt_component.is_some) return relative_path;
            }
            {
                Optional<Slice<uint8_t>> opt_component = SplitIterator_next(&it);
                if (!opt_component.is_some) return relative_path;
            }
            return WindowsPath{
                path.slice(0, it.index),
                WindowsPathKindNetworkShare,
                isAbsoluteWindows(path),
            };
        }
    }
    {
        if (memStartsWith(path, str("\\\\"))) {
            if (path.ptr[2] == '\\') {
                return relative_path;
            }

            SplitIterator it = memSplit(path, str("\\"));
            {
                Optional<Slice<uint8_t>> opt_component = SplitIterator_next(&it);
                if (!opt_component.is_some) return relative_path;
            }
            {
                Optional<Slice<uint8_t>> opt_component = SplitIterator_next(&it);
                if (!opt_component.is_some) return relative_path;
            }
            return WindowsPath{
                path.slice(0, it.index),
                WindowsPathKindNetworkShare,
                isAbsoluteWindows(path),
            };
        }
    }
    return relative_path;
}

// Ported from std/os/path.zig
static uint8_t asciiUpper(uint8_t byte) {
    if (byte >= 'a' && byte <= 'z') {
        return 'A' + (byte - 'a');
    }
    return byte;
}

// Ported from std/os/path.zig
static bool asciiEqlIgnoreCase(Slice<uint8_t> s1, Slice<uint8_t> s2) {
    if (s1.len != s2.len)
        return false;
    for (size_t i = 0; i < s1.len; i += 1) {
        if (asciiUpper(s1.ptr[i]) != asciiUpper(s2.ptr[i]))
            return false;
    }
    return true;
}

// Ported from std/os/path.zig
static bool compareDiskDesignators(WindowsPathKind kind, Slice<uint8_t> p1, Slice<uint8_t> p2) {
    switch (kind) {
        case WindowsPathKindNone:
            assert(p1.len == 0);
            assert(p2.len == 0);
            return true;
        case WindowsPathKindDrive:
            return asciiUpper(p1.ptr[0]) == asciiUpper(p2.ptr[0]);
        case WindowsPathKindNetworkShare:
            uint8_t sep1 = p1.ptr[0];
            uint8_t sep2 = p2.ptr[0];

            SplitIterator it1 = memSplit(p1, {&sep1, 1});
            SplitIterator it2 = memSplit(p2, {&sep2, 1});

            // TODO ASCII is wrong, we actually need full unicode support to compare paths.
            return asciiEqlIgnoreCase(SplitIterator_next(&it1).value, SplitIterator_next(&it2).value) &&
                asciiEqlIgnoreCase(SplitIterator_next(&it1).value, SplitIterator_next(&it2).value);
    }
    zig_unreachable();
}

// Ported from std/os/path.zig
static Buf os_path_resolve_windows(Buf **paths_ptr, size_t paths_len) {
    if (paths_len == 0) {
        Buf cwd = BUF_INIT;
        int err;
        if ((err = os_get_cwd(&cwd))) {
            zig_panic("get cwd failed");
        }
        return cwd;
    }

    // determine which disk designator we will result with, if any
    char result_drive_buf[3] = {'_', ':', '\0'}; // 0 needed for strlen later
    Slice<uint8_t> result_disk_designator = str("");
    WindowsPathKind have_drive_kind = WindowsPathKindNone;
    bool have_abs_path = false;
    size_t first_index = 0;
    size_t max_size = 0;
    for (size_t i = 0; i < paths_len; i += 1) {
        Slice<uint8_t> p = buf_to_slice(paths_ptr[i]);
        WindowsPath parsed = windowsParsePath(p);
        if (parsed.is_abs) {
            have_abs_path = true;
            first_index = i;
            max_size = result_disk_designator.len;
        }
        switch (parsed.kind) {
            case WindowsPathKindDrive:
                result_drive_buf[0] = asciiUpper(parsed.disk_designator.ptr[0]);
                result_disk_designator = str(result_drive_buf);
                have_drive_kind = WindowsPathKindDrive;
                break;
            case WindowsPathKindNetworkShare:
                result_disk_designator = parsed.disk_designator;
                have_drive_kind = WindowsPathKindNetworkShare;
                break;
            case WindowsPathKindNone:
                break;
        }
        max_size += p.len + 1;
    }

    // if we will result with a disk designator, loop again to determine
    // which is the last time the disk designator is absolutely specified, if any
    // and count up the max bytes for paths related to this disk designator
    if (have_drive_kind != WindowsPathKindNone) {
        have_abs_path = false;
        first_index = 0;
        max_size = result_disk_designator.len;
        bool correct_disk_designator = false;

        for (size_t i = 0; i < paths_len; i += 1) {
            Slice<uint8_t> p = buf_to_slice(paths_ptr[i]);
            WindowsPath parsed = windowsParsePath(p);
            if (parsed.kind != WindowsPathKindNone) {
                if (parsed.kind == have_drive_kind) {
                    correct_disk_designator = compareDiskDesignators(have_drive_kind, result_disk_designator, parsed.disk_designator);
                } else {
                    continue;
                }
            }
            if (!correct_disk_designator) {
                continue;
            }
            if (parsed.is_abs) {
                first_index = i;
                max_size = result_disk_designator.len;
                have_abs_path = true;
            }
            max_size += p.len + 1;
        }
    }

    // Allocate result and fill in the disk designator, calling getCwd if we have to.
    Slice<uint8_t> result;
    size_t result_index = 0;

    if (have_abs_path) {
        switch (have_drive_kind) {
            case WindowsPathKindDrive: {
                result = Slice<uint8_t>::alloc(max_size);

                memCopy(result, result_disk_designator);
                result_index += result_disk_designator.len;
                break;
            }
            case WindowsPathKindNetworkShare: {
                result = Slice<uint8_t>::alloc(max_size);
                SplitIterator it = memSplit(buf_to_slice(paths_ptr[first_index]), str("/\\"));
                Slice<uint8_t> server_name = SplitIterator_next(&it).value;
                Slice<uint8_t> other_name = SplitIterator_next(&it).value;

                result.ptr[result_index] = '\\';
                result_index += 1;
                result.ptr[result_index] = '\\';
                result_index += 1;
                memCopy(result.sliceFrom(result_index), server_name);
                result_index += server_name.len;
                result.ptr[result_index] = '\\';
                result_index += 1;
                memCopy(result.sliceFrom(result_index), other_name);
                result_index += other_name.len;

                result_disk_designator = result.slice(0, result_index);
                break;
            }
            case WindowsPathKindNone: {
                Buf cwd = BUF_INIT;
                int err;
                if ((err = os_get_cwd(&cwd))) {
                    zig_panic("get cwd failed");
                }
                WindowsPath parsed_cwd = windowsParsePath(buf_to_slice(&cwd));
                result = Slice<uint8_t>::alloc(max_size + parsed_cwd.disk_designator.len + 1);
                memCopy(result, parsed_cwd.disk_designator);
                result_index += parsed_cwd.disk_designator.len;
                result_disk_designator = result.slice(0, parsed_cwd.disk_designator.len);
                if (parsed_cwd.kind == WindowsPathKindDrive) {
                    result.ptr[0] = asciiUpper(result.ptr[0]);
                }
                have_drive_kind = parsed_cwd.kind;
                break;
            }
        }
    } else {
        // TODO call get cwd for the result_disk_designator instead of the global one
        Buf cwd = BUF_INIT;
        int err;
        if ((err = os_get_cwd(&cwd))) {
            zig_panic("get cwd failed");
        }
        result = Slice<uint8_t>::alloc(max_size + buf_len(&cwd) + 1);

        memCopy(result, buf_to_slice(&cwd));
        result_index += buf_len(&cwd);
        WindowsPath parsed_cwd = windowsParsePath(result.slice(0, result_index));
        result_disk_designator = parsed_cwd.disk_designator;
        if (parsed_cwd.kind == WindowsPathKindDrive) {
            result.ptr[0] = asciiUpper(result.ptr[0]);
        }
        have_drive_kind = parsed_cwd.kind;
    }

    // Now we know the disk designator to use, if any, and what kind it is. And our result
    // is big enough to append all the paths to.
    bool correct_disk_designator = true;
    for (size_t i = 0; i < paths_len; i += 1) {
        Slice<uint8_t> p = buf_to_slice(paths_ptr[i]);
        WindowsPath parsed = windowsParsePath(p);

        if (parsed.kind != WindowsPathKindNone) {
            if (parsed.kind == have_drive_kind) {
                correct_disk_designator = compareDiskDesignators(have_drive_kind, result_disk_designator, parsed.disk_designator);
            } else {
                continue;
            }
        }
        if (!correct_disk_designator) {
            continue;
        }
        SplitIterator it = memSplit(p.sliceFrom(parsed.disk_designator.len), str("/\\"));
        while (true) {
            Optional<Slice<uint8_t>> opt_component = SplitIterator_next(&it);
            if (!opt_component.is_some) break;
            Slice<uint8_t> component = opt_component.value;
            if (memEql(component, str("."))) {
                continue;
            } else if (memEql(component, str(".."))) {
                while (true) {
                    if (result_index == 0 || result_index == result_disk_designator.len)
                        break;
                    result_index -= 1;
                    if (result.ptr[result_index] == '\\' || result.ptr[result_index] == '/')
                        break;
                }
            } else {
                result.ptr[result_index] = '\\';
                result_index += 1;
                memCopy(result.sliceFrom(result_index), component);
                result_index += component.len;
            }
        }
    }

    if (result_index == result_disk_designator.len) {
        result.ptr[result_index] = '\\';
        result_index += 1;
    }

    Buf return_value = BUF_INIT;
    buf_init_from_mem(&return_value, (char *)result.ptr, result_index);
    return return_value;
}
#endif

#if defined(ZIG_OS_POSIX)
// Ported from std/os/path.zig
static Buf os_path_resolve_posix(Buf **paths_ptr, size_t paths_len) {
    if (paths_len == 0) {
        Buf cwd = BUF_INIT;
        int err;
        if ((err = os_get_cwd(&cwd))) {
            zig_panic("get cwd failed");
        }
        return cwd;
    }

    size_t first_index = 0;
    bool have_abs = false;
    size_t max_size = 0;
    for (size_t i = 0; i < paths_len; i += 1) {
        Buf *p = paths_ptr[i];
        if (buf_ptr(p)[0] == '/') {
            first_index = i;
            have_abs = true;
            max_size = 0;
        }
        max_size += buf_len(p) + 1;
    }

    uint8_t *result_ptr;
    size_t result_len;
    size_t result_index = 0;

    if (have_abs) {
        result_len = max_size;
        result_ptr = heap::c_allocator.allocate_nonzero<uint8_t>(result_len);
    } else {
        Buf cwd = BUF_INIT;
        int err;
        if ((err = os_get_cwd(&cwd))) {
            zig_panic("get cwd failed");
        }
        result_len = max_size + buf_len(&cwd) + 1;
        result_ptr = heap::c_allocator.allocate_nonzero<uint8_t>(result_len);
        memcpy(result_ptr, buf_ptr(&cwd), buf_len(&cwd));
        result_index += buf_len(&cwd);
    }

    for (size_t i = first_index; i < paths_len; i += 1) {
        Buf *p = paths_ptr[i];
        SplitIterator it = memSplit(buf_to_slice(p), str("/"));
        while (true) {
            Optional<Slice<uint8_t>> opt_component = SplitIterator_next(&it);
            if (!opt_component.is_some) break;
            Slice<uint8_t> component = opt_component.value;

            if (memEql<uint8_t>(component, str("."))) {
                continue;
            } else if (memEql<uint8_t>(component, str(".."))) {
                while (true) {
                    if (result_index == 0)
                        break;
                    result_index -= 1;
                    if (result_ptr[result_index] == '/')
                        break;
                }
            } else {
                result_ptr[result_index] = '/';
                result_index += 1;
                memcpy(result_ptr + result_index, component.ptr, component.len);
                result_index += component.len;
            }
        }
    }

    if (result_index == 0) {
        result_ptr[0] = '/';
        result_index += 1;
    }

    Buf return_value = BUF_INIT;
    buf_init_from_mem(&return_value, (char *)result_ptr, result_index);
    heap::c_allocator.deallocate(result_ptr, result_len);
    return return_value;
}
#endif

// Ported from std/os/path.zig
Buf os_path_resolve(Buf **paths_ptr, size_t paths_len) {
#if defined(ZIG_OS_WINDOWS)
    return os_path_resolve_windows(paths_ptr, paths_len);
#elif defined(ZIG_OS_POSIX)
    return os_path_resolve_posix(paths_ptr, paths_len);
#else
#error "missing os_path_resolve implementation"
#endif
}

Error os_fetch_file(FILE *f, Buf *out_buf) {
    static const ssize_t buf_size = 0x2000;
    buf_resize(out_buf, buf_size);
    ssize_t actual_buf_len = 0;

    for (;;) {
        size_t amt_read = fread(buf_ptr(out_buf) + actual_buf_len, 1, buf_size, f);
        actual_buf_len += amt_read;

        if (amt_read != buf_size) {
            if (feof(f)) {
                buf_resize(out_buf, actual_buf_len);
                return ErrorNone;
            } else {
                return ErrorFileSystem;
            }
        }

        buf_resize(out_buf, actual_buf_len + buf_size);
    }
    zig_unreachable();
}

Error os_write_file(Buf *full_path, Buf *contents) {
#if defined(ZIG_OS_WINDOWS)
    PathSpace path_space = slice_to_prefixed_file_w(buf_to_slice(full_path));
    FILE *f = _wfopen(&path_space.data.items[0], L"wb");
#else
    FILE *f = fopen(buf_ptr(full_path), "wb");
#endif
    if (!f) {
        zig_panic("os_write_file failed for %s", buf_ptr(full_path));
    }
    size_t amt_written = fwrite(buf_ptr(contents), 1, buf_len(contents), f);
    if (amt_written != (size_t)buf_len(contents))
        zig_panic("write failed: %s", strerror(errno));
    if (fclose(f))
        zig_panic("close failed");
    return ErrorNone;
}

static Error copy_open_files(FILE *src_f, FILE *dest_f) {
    static const size_t buf_size = 2048;
    char buf[buf_size];
    for (;;) {
        size_t amt_read = fread(buf, 1, buf_size, src_f);
        if (amt_read != buf_size) {
            if (ferror(src_f)) {
                return ErrorFileSystem;
            }
        }
        size_t amt_written = fwrite(buf, 1, amt_read, dest_f);
        if (amt_written != amt_read) {
            return ErrorFileSystem;
        }
        if (feof(src_f)) {
            return ErrorNone;
        }
    }
}

Error os_copy_file(Buf *src_path, Buf *dest_path) {
#if defined(ZIG_OS_WINDOWS)
    PathSpace src_path_space = slice_to_prefixed_file_w(buf_to_slice(src_path));
    FILE *src_f = _wfopen(&src_path_space.data.items[0], L"rb");
#else
    FILE *src_f = fopen(buf_ptr(src_path), "rb");
#endif
    if (!src_f) {
        int err = errno;
        if (err == ENOENT) {
            return ErrorFileNotFound;
        } else if (err == EACCES || err == EPERM) {
            return ErrorAccess;
        } else {
            return ErrorFileSystem;
        }
    }
#if defined(ZIG_OS_WINDOWS)
    PathSpace dest_path_space = slice_to_prefixed_file_w(buf_to_slice(dest_path));
    FILE *dest_f = _wfopen(&dest_path_space.data.items[0], L"wb");
#else
    FILE *dest_f = fopen(buf_ptr(dest_path), "wb");
#endif
    if (!dest_f) {
        int err = errno;
        if (err == ENOENT) {
            fclose(src_f);
            return ErrorFileNotFound;
        } else if (err == EACCES || err == EPERM) {
            fclose(src_f);
            return ErrorAccess;
        } else {
            fclose(src_f);
            return ErrorFileSystem;
        }
    }
    Error err = copy_open_files(src_f, dest_f);
    fclose(src_f);
    fclose(dest_f);
    return err;
}

Error os_fetch_file_path(Buf *full_path, Buf *out_contents) {
#if defined(ZIG_OS_WINDOWS)
    PathSpace path_space = slice_to_prefixed_file_w(buf_to_slice(full_path));
    FILE *f = _wfopen(&path_space.data.items[0], L"rb");
#else
    FILE *f = fopen(buf_ptr(full_path), "rb");
#endif
    if (!f) {
        switch (errno) {
            case EACCES:
                return ErrorAccess;
            case EINTR:
                return ErrorInterrupted;
            case EINVAL:
                return ErrorInvalidFilename;
            case ENFILE:
            case ENOMEM:
                return ErrorSystemResources;
            case ENOENT:
                return ErrorFileNotFound;
            default:
                return ErrorFileSystem;
        }
    }
    Error result = os_fetch_file(f, out_contents);
    fclose(f);
    return result;
}

Error os_get_cwd(Buf *out_cwd) {
#if defined(ZIG_OS_WINDOWS)
    PathSpace path_space;
    if (GetCurrentDirectoryW(PATH_MAX_WIDE, &path_space.data.items[0]) == 0) {
        zig_panic("GetCurrentDirectory failed");
    }
    utf16le_ptr_to_utf8(out_cwd, &path_space.data.items[0]);
    return ErrorNone;
#elif defined(ZIG_OS_POSIX)
    char buf[PATH_MAX];
    char *res = getcwd(buf, PATH_MAX);
    if (res == nullptr) {
        zig_panic("unable to get cwd: %s", strerror(errno));
    }
    buf_init_from_str(out_cwd, res);
    return ErrorNone;
#else
#error "missing os_get_cwd implementation"
#endif
}

#if defined(ZIG_OS_WINDOWS)
#define is_wprefix(s, prefix) \
    (wcsncmp((s), (prefix), sizeof(prefix) / sizeof(WCHAR) - 1) == 0)
static bool is_stderr_cyg_pty(void) {
    HANDLE stderr_handle = GetStdHandle(STD_ERROR_HANDLE);
    if (stderr_handle == INVALID_HANDLE_VALUE)
        return false;

    const int size = sizeof(FILE_NAME_INFO) + sizeof(WCHAR) * MAX_PATH;
    FILE_NAME_INFO *nameinfo;
    WCHAR *p = NULL;

    // Cygwin/msys's pty is a pipe.
    if (GetFileType(stderr_handle) != FILE_TYPE_PIPE) {
        return 0;
    }
    nameinfo = reinterpret_cast<FILE_NAME_INFO *>(heap::c_allocator.allocate<char>(size));
    if (nameinfo == NULL) {
        return 0;
    }
    // Check the name of the pipe:
    // '\{cygwin,msys}-XXXXXXXXXXXXXXXX-ptyN-{from,to}-master'
    if (GetFileInformationByHandleEx(stderr_handle, FileNameInfo, nameinfo, size)) {
        nameinfo->FileName[nameinfo->FileNameLength / sizeof(WCHAR)] = L'\0';
        p = nameinfo->FileName;
        if (is_wprefix(p, L"\\cygwin-")) {      /* Cygwin */
            p += 8;
        } else if (is_wprefix(p, L"\\msys-")) { /* MSYS and MSYS2 */
            p += 6;
        } else {
            p = NULL;
        }
        if (p != NULL) {
            while (*p && isxdigit(*p))  /* Skip 16-digit hexadecimal. */
                ++p;
            if (is_wprefix(p, L"-pty")) {
                p += 4;
            } else {
                p = NULL;
            }
        }
        if (p != NULL) {
            while (*p && isdigit(*p))   /* Skip pty number. */
                ++p;
            if (is_wprefix(p, L"-from-master")) {
                //p += 12;
            } else if (is_wprefix(p, L"-to-master")) {
                //p += 10;
            } else {
                p = NULL;
            }
        }
    }
    heap::c_allocator.deallocate(reinterpret_cast<char *>(nameinfo), size);
    return (p != NULL);
}
#endif

bool os_stderr_tty(void) {
#if defined(ZIG_OS_WINDOWS)
    return _isatty(_fileno(stderr)) != 0 || is_stderr_cyg_pty();
#elif defined(ZIG_OS_POSIX)
    return isatty(STDERR_FILENO) != 0;
#else
#error "missing os_stderr_tty implementation"
#endif
}

Error os_rename(Buf *src_path, Buf *dest_path) {
    if (buf_eql_buf(src_path, dest_path)) {
        return ErrorNone;
    }
#if defined(ZIG_OS_WINDOWS)
    PathSpace src_path_space = slice_to_prefixed_file_w(buf_to_slice(src_path));
    PathSpace dest_path_space = slice_to_prefixed_file_w(buf_to_slice(dest_path));
    if (!MoveFileExW(&src_path_space.data.items[0], &dest_path_space.data.items[0], MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
        return ErrorFileSystem;
    }
#else
    if (rename(buf_ptr(src_path), buf_ptr(dest_path)) == -1) {
        return ErrorFileSystem;
    }
#endif
    return ErrorNone;
}

OsTimeStamp os_timestamp_monotonic(void) {
    OsTimeStamp result;
#if defined(ZIG_OS_WINDOWS)
    uint64_t counts;
    QueryPerformanceCounter((LARGE_INTEGER*)&counts);
    result.sec = counts / windows_perf_freq;
    result.nsec = (counts % windows_perf_freq) * 1000000000u / windows_perf_freq;
#elif defined(__MACH__)
    mach_timespec_t mts;

    kern_return_t err = clock_get_time(macos_monotonic_clock, &mts);
    assert(!err);

    result.sec = mts.tv_sec;
    result.nsec = mts.tv_nsec;
#else
    struct timespec tms;
    clock_gettime(CLOCK_MONOTONIC, &tms);

    result.sec = tms.tv_sec;
    result.nsec = tms.tv_nsec;
#endif
    return result;
}

Error os_make_path(Buf *path) {
    Buf resolved_path = os_path_resolve(&path, 1);

    size_t end_index = buf_len(&resolved_path);
    Error err;
    while (true) {
        if ((err = os_make_dir(buf_slice(&resolved_path, 0, end_index)))) {
            if (err == ErrorPathAlreadyExists) {
                if (end_index == buf_len(&resolved_path))
                    return ErrorNone;
            } else if (err == ErrorFileNotFound) {
                // march end_index backward until next path component
                while (true) {
                    end_index -= 1;
                    if (os_is_sep(buf_ptr(&resolved_path)[end_index]))
                        break;
                }
                continue;
            } else {
                return err;
            }
        }
        if (end_index == buf_len(&resolved_path))
            return ErrorNone;
        // march end_index forward until next path component
        while (true) {
            end_index += 1;
            if (end_index == buf_len(&resolved_path) || os_is_sep(buf_ptr(&resolved_path)[end_index]))
                break;
        }
    }
    return ErrorNone;
}

Error os_make_dir(Buf *path) {
#if defined(ZIG_OS_WINDOWS)
    PathSpace path_space = slice_to_prefixed_file_w(buf_to_slice(path));
    if (memEql(buf_to_slice(path), str("C:\\dev\\tést"))) {
        for (size_t i = 0; i < path_space.len; i++) {
            fprintf(stderr, "%d ", path_space.data.items[i]);
        }
        fprintf(stderr, "\n");
    }
    
    if (!CreateDirectoryW(&path_space.data.items[0], NULL)) {
        if (GetLastError() == ERROR_ALREADY_EXISTS)
            return ErrorPathAlreadyExists;
        if (GetLastError() == ERROR_PATH_NOT_FOUND)
            return ErrorFileNotFound;
        if (GetLastError() == ERROR_ACCESS_DENIED)
            return ErrorAccess;
        return ErrorUnexpected;
    }
    return ErrorNone;
#else
    if (mkdir(buf_ptr(path), 0755) == -1) {
        if (errno == EEXIST)
            return ErrorPathAlreadyExists;
        if (errno == ENOENT)
            return ErrorFileNotFound;
        if (errno == EACCES)
            return ErrorAccess;
        return ErrorUnexpected;
    }
    return ErrorNone;
#endif
}


int os_init(void) {
#if defined(ZIG_OS_WINDOWS)
    _setmode(fileno(stdout), _O_BINARY);
    _setmode(fileno(stderr), _O_BINARY);
    if (!QueryPerformanceFrequency((LARGE_INTEGER*)&windows_perf_freq)) {
        return ErrorSystemResources;
    }
#elif defined(__MACH__)
    host_get_clock_service(mach_host_self(), SYSTEM_CLOCK, &macos_monotonic_clock);
    host_get_clock_service(mach_host_self(), CALENDAR_CLOCK, &macos_calendar_clock);
#endif
    return 0;
}

#define VT_RED "\x1b[31;1m"
#define VT_GREEN "\x1b[32;1m"
#define VT_CYAN "\x1b[36;1m"
#define VT_WHITE "\x1b[37;1m"
#define VT_BOLD "\x1b[0;1m"
#define VT_RESET "\x1b[0m"

static void set_color_posix(TermColor color) {
    switch (color) {
        case TermColorRed:
            fprintf(stderr, VT_RED);
            break;
        case TermColorGreen:
            fprintf(stderr, VT_GREEN);
            break;
        case TermColorCyan:
            fprintf(stderr, VT_CYAN);
            break;
        case TermColorWhite:
            fprintf(stderr, VT_WHITE);
            break;
        case TermColorBold:
            fprintf(stderr, VT_BOLD);
            break;
        case TermColorReset:
            fprintf(stderr, VT_RESET);
            break;
    }
}


#if defined(ZIG_OS_WINDOWS)
bool got_orig_console_attrs = false;
WORD original_console_attributes = FOREGROUND_RED|FOREGROUND_GREEN|FOREGROUND_BLUE;
#endif

void os_stderr_set_color(TermColor color) {
#if defined(ZIG_OS_WINDOWS)
    if (is_stderr_cyg_pty()) {
        set_color_posix(color);
        return;
    }
    HANDLE stderr_handle = GetStdHandle(STD_ERROR_HANDLE);
    if (stderr_handle == INVALID_HANDLE_VALUE)
        zig_panic("unable to get stderr handle");
    fflush(stderr);

    if (!got_orig_console_attrs) {
        got_orig_console_attrs = true;
        CONSOLE_SCREEN_BUFFER_INFO info;
        if (GetConsoleScreenBufferInfo(stderr_handle, &info)) {
            original_console_attributes = info.wAttributes;
        }
    }

    switch (color) {
        case TermColorRed:
            SetConsoleTextAttribute(stderr_handle, FOREGROUND_RED|FOREGROUND_INTENSITY);
            break;
        case TermColorGreen:
            SetConsoleTextAttribute(stderr_handle, FOREGROUND_GREEN|FOREGROUND_INTENSITY);
            break;
        case TermColorCyan:
            SetConsoleTextAttribute(stderr_handle, FOREGROUND_GREEN|FOREGROUND_BLUE|FOREGROUND_INTENSITY);
            break;
        case TermColorWhite:
        case TermColorBold:
            SetConsoleTextAttribute(stderr_handle,
                FOREGROUND_RED|FOREGROUND_GREEN|FOREGROUND_BLUE|FOREGROUND_INTENSITY);
            break;
        case TermColorReset:
            SetConsoleTextAttribute(stderr_handle, original_console_attributes);
            break;
    }
#else
    set_color_posix(color);
#endif
}

#if defined(ZIG_OS_WINDOWS)
// Ported from std/unicode.zig
struct Utf16LeIterator {
    uint8_t *bytes;
    size_t i;
};

// Ported from std/unicode.zig
static Utf16LeIterator Utf16LeIterator_init(WCHAR *ptr) {
    return {(uint8_t*)ptr, 0};
}

// Ported from std/unicode.zig
static Optional<uint32_t> Utf16LeIterator_nextCodepoint(Utf16LeIterator *it) {
    if (it->bytes[it->i] == 0 && it->bytes[it->i + 1] == 0)
        return {};
    uint32_t c0 = ((uint32_t)it->bytes[it->i]) | (((uint32_t)it->bytes[it->i + 1]) << 8);
    if ((c0 & ~((uint32_t)0x03ff)) == 0xd800) {
        // surrogate pair
        it->i += 2;
        assert(it->bytes[it->i] != 0 || it->bytes[it->i + 1] != 0);
        uint32_t c1 = ((uint32_t)it->bytes[it->i]) | (((uint32_t)it->bytes[it->i + 1]) << 8);
        assert((c1 & ~((uint32_t)0x03ff)) == 0xdc00);
        it->i += 2;
        return Optional<uint32_t>::some(0x10000 + (((c0 & 0x03ff) << 10) | (c1 & 0x03ff)));
    } else {
        assert((c0 & ~((uint32_t)0x03ff)) != 0xdc00);
        it->i += 2;
        return Optional<uint32_t>::some(c0);
    }
}

// Ported from std/unicode.zig
static uint8_t utf8CodepointSequenceLength(uint32_t c) {
    if (c < 0x80) return 1;
    if (c < 0x800) return 2;
    if (c < 0x10000) return 3;
    if (c < 0x110000) return 4;
    zig_unreachable();
}

// Ported from std.unicode.utf8ByteSequenceLength
static uint8_t utf8ByteSequenceLength(uint8_t first_byte) {
    if (first_byte < 0b10000000) return 1;
    if ((first_byte & 0b11100000) == 0b11000000) return 2;
    if ((first_byte & 0b11110000) == 0b11100000) return 3;
    if ((first_byte & 0b11111000) == 0b11110000) return 4;
    zig_unreachable();
}

// Ported from std/unicode.zig
static size_t utf8Encode(uint32_t c, Slice<uint8_t> out) {
    size_t length = utf8CodepointSequenceLength(c);
    assert(out.len >= length);
    switch (length) {
        // The pattern for each is the same
        // - Increasing the initial shift by 6 each time
        // - Each time after the first shorten the shifted
        //   value to a max of 0b111111 (63)
        case 1:
            out.ptr[0] = c; // Can just do 0 + codepoint for initial range
            break;
        case 2:
            out.ptr[0] = 0b11000000 | (c >> 6);
            out.ptr[1] = 0b10000000 | (c & 0b111111);
            break;
        case 3:
            assert(!(0xd800 <= c && c <= 0xdfff));
            out.ptr[0] = 0b11100000 | (c >> 12);
            out.ptr[1] = 0b10000000 | ((c >> 6) & 0b111111);
            out.ptr[2] = 0b10000000 | (c & 0b111111);
            break;
        case 4:
            out.ptr[0] = 0b11110000 | (c >> 18);
            out.ptr[1] = 0b10000000 | ((c >> 12) & 0b111111);
            out.ptr[2] = 0b10000000 | ((c >> 6) & 0b111111);
            out.ptr[3] = 0b10000000 | (c & 0b111111);
            break;
        default:
            zig_unreachable();
    }
    return length;
}

// Ported from std.unicode.utf8Decode2
static uint32_t utf8Decode2(Slice<uint8_t> bytes) {
    assert(bytes.len == 2);
    assert((bytes.at(0) & 0b11100000) == 0b11000000);

    uint32_t value = bytes.at(0) & 0b00011111;
    assert((bytes.at(1) & 0b11000000) == 0b10000000);
    value <<= 6;
    value |= bytes.at(1) & 0b00111111;

    assert(value >= 0x80);
    return value;
}

// Ported from std.unicode.utf8Decode3
static uint32_t utf8Decode3(Slice<uint8_t> bytes) {
    assert(bytes.len == 3);
    assert((bytes.at(0) & 0b11110000) == 0b11100000);

    uint32_t value = bytes.at(0) & 0b00001111;
    assert((bytes.at(1) & 0b11000000) == 0b10000000);
    value <<= 6;
    value |= bytes.at(1) & 0b00111111;

    assert((bytes.at(2) & 0b11000000) == 0b10000000);
    value <<= 6;
    value |= bytes.at(2) & 0b00111111;

    assert(value >= 0x80);
    assert(value < 0xd800 || value > 0xdfff);
    return value;
}

// Ported from std.unicode.utf8Decode4
static uint32_t utf8Decode4(Slice<uint8_t> bytes) {
    assert(bytes.len == 4);
    assert((bytes.at(0) & 0b11111000) == 0b11110000);

    uint32_t value = bytes.at(0) & 0b00000111;
    assert((bytes.at(1) & 0b11000000) == 0b10000000);
    value <<= 6;
    value |= bytes.at(1) & 0b00111111;

    assert((bytes.at(2) & 0b11000000) == 0b10000000);
    value <<= 6;
    value |= bytes.at(2) & 0b00111111;

    assert((bytes.at(3) & 0b11000000) == 0b10000000);
    value <<= 6;
    value |= bytes.at(3) & 0b00111111;

    assert(value >= 0x10000 && value <= 0x10FFFF);
    return value;
}

// Ported from std.unicode.utf8Decode
static uint32_t utf8Decode(Slice<uint8_t> bytes) {
    switch (bytes.len) {
        case 1:
            return bytes.at(0);
            break;
        case 2:
            return utf8Decode2(bytes);
            break;
        case 3:
            return utf8Decode3(bytes);
            break;
        case 4:
            return utf8Decode4(bytes);
            break;
        default:
            zig_unreachable();
    }
}
// Ported from std.unicode.utf16leToUtf8Alloc
static void utf16le_ptr_to_utf8(Buf *out, WCHAR *utf16le) {
    // optimistically guess that it will all be ascii.
    buf_resize(out, 0);
    size_t out_index = 0;
    Utf16LeIterator it = Utf16LeIterator_init(utf16le);
    for (;;) {
        Optional<uint32_t> opt_codepoint = Utf16LeIterator_nextCodepoint(&it);
        if (!opt_codepoint.is_some) break;
        uint32_t codepoint = opt_codepoint.value;

        size_t utf8_len = utf8CodepointSequenceLength(codepoint);
        buf_resize(out, buf_len(out) + utf8_len);
        utf8Encode(codepoint, {(uint8_t*)buf_ptr(out)+out_index, buf_len(out)-out_index});
        out_index += utf8_len;
    }
}

// Ported from std.unicode.utf8ToUtf16Le
static size_t utf8_to_utf16le(WCHAR *utf16_le, Slice<uint8_t> utf8) {
    size_t dest_i = 0;
    size_t src_i = 0;
    while (src_i < utf8.len) {
        uint8_t n = utf8ByteSequenceLength(utf8.at(src_i));
        size_t next_src_i = src_i + n;
        uint32_t codepoint = utf8Decode(utf8.slice(src_i, next_src_i));
        if (codepoint < 0x10000) {
            utf16_le[dest_i] = codepoint;
            dest_i += 1;
        } else {
            WCHAR high = ((codepoint - 0x10000) >> 10) + 0xD800;
            WCHAR low = (codepoint & 0x3FF) + 0xDC00;
            utf16_le[dest_i] = high;
            utf16_le[dest_i + 1] = low;
            dest_i += 2;
        }
        src_i = next_src_i;
    }
    return dest_i;
}

// Ported from std.os.windows.sliceToPrefixedFileW
PathSpace slice_to_prefixed_file_w(Slice<uint8_t> path) {
    PathSpace path_space;
    for (size_t idx = 0; idx < path.len; idx++) {
        assert(path.ptr[idx] != '*' && path.ptr[idx] != '?' && path.ptr[idx] != '"' &&
               path.ptr[idx] != '<' && path.ptr[idx] != '>' && path.ptr[idx] != '|');
    }

    size_t start_index;
    if (memStartsWith(path, str("\\?")) || !isAbsoluteWindows(path)) {
        start_index = 0;
    } else {
        static WCHAR prefix[4] = { u'\\', u'?', u'?', u'\\' };
        memCopy(path_space.data.slice(), Slice<WCHAR> { prefix, 4 });
        start_index = 4;
    }

    path_space.len = start_index + utf8_to_utf16le(path_space.data.slice().sliceFrom(start_index).ptr, path);
    assert(path_space.len <= path_space.data.len);

    Slice<WCHAR> path_slice = path_space.data.slice().slice(0, path_space.len);
    for (size_t elem_idx = 0; elem_idx < path_slice.len; elem_idx += 1) {
        if (path_slice.at(elem_idx) == '/') {
            path_slice.at(elem_idx) = '\\';
        }
    }

    path_space.data.items[path_space.len] = 0;
    return path_space;
}
#endif
