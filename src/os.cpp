/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "os.hpp"
#include "util.hpp"
#include "error.hpp"

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

#include <windows.h>
#include <io.h>
#include <fcntl.h>

typedef SSIZE_T ssize_t;
#else
#define ZIG_OS_POSIX

#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <limits.h>

#endif


#if defined(__MACH__)
#include <mach/clock.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#endif

#if defined(ZIG_OS_WINDOWS)
static double win32_time_resolution;
#elif defined(__MACH__)
static clock_serv_t cclock;
#endif

#include <stdlib.h>
#include <errno.h>
#include <time.h>

// Ported from std/mem.zig.
// Coordinate struct fields with memSplit function
struct SplitIterator {
    size_t index;
    Slice<uint8_t> buffer;
    Slice<uint8_t> split_bytes;
};

// Ported from std/mem.zig.
static bool SplitIterator_isSplitByte(SplitIterator *self, uint8_t byte) {
    for (size_t i = 0; i < self->split_bytes.len; i += 1) {
        if (byte == self->split_bytes.ptr[i]) {
            return true;
        }
    }
    return false;
}

// Ported from std/mem.zig.
static Optional<Slice<uint8_t>> SplitIterator_next(SplitIterator *self) {
    // move to beginning of token
    while (self->index < self->buffer.len &&
        SplitIterator_isSplitByte(self, self->buffer.ptr[self->index]))
    {
        self->index += 1;
    }
    size_t start = self->index;
    if (start == self->buffer.len) {
        return {};
    }

    // move to end of token
    while (self->index < self->buffer.len &&
        !SplitIterator_isSplitByte(self, self->buffer.ptr[self->index]))
    {
        self->index += 1;
    }
    size_t end = self->index;

    return Optional<Slice<uint8_t>>::some(self->buffer.slice(start, end));
}

// Ported from std/mem.zig
static SplitIterator memSplit(Slice<uint8_t> buffer, Slice<uint8_t> split_bytes) {
    return SplitIterator{0, buffer, split_bytes};
}


#if defined(ZIG_OS_POSIX)
static void populate_termination(Termination *term, int status) {
    if (WIFEXITED(status)) {
        term->how = TerminationIdClean;
        term->code = WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        term->how = TerminationIdSignaled;
        term->code = WTERMSIG(status);
    } else if (WIFSTOPPED(status)) {
        term->how = TerminationIdStopped;
        term->code = WSTOPSIG(status);
    } else {
        term->how = TerminationIdUnknown;
        term->code = status;
    }
}

static void os_spawn_process_posix(const char *exe, ZigList<const char *> &args, Termination *term) {
    pid_t pid = fork();
    if (pid == -1)
        zig_panic("fork failed");
    if (pid == 0) {
        // child
        const char **argv = allocate<const char *>(args.length + 2);
        argv[0] = exe;
        argv[args.length + 1] = nullptr;
        for (size_t i = 0; i < args.length; i += 1) {
            argv[i + 1] = args.at(i);
        }
        execvp(exe, const_cast<char * const *>(argv));
        zig_panic("execvp failed: %s", strerror(errno));
    } else {
        // parent
        int status;
        waitpid(pid, &status, 0);
        populate_termination(term, status);
    }
}
#endif

#if defined(ZIG_OS_WINDOWS)
static void os_windows_create_command_line(Buf *command_line, const char *exe, ZigList<const char *> &args) {
    buf_resize(command_line, 0);

    buf_append_char(command_line, '\"');
    buf_append_str(command_line, exe);
    buf_append_char(command_line, '\"');

    for (size_t arg_i = 0; arg_i < args.length; arg_i += 1) {
        buf_append_str(command_line, " \"");
        const char *arg = args.at(arg_i);
        size_t arg_len = strlen(arg);
        for (size_t c_i = 0; c_i < arg_len; c_i += 1) {
            if (arg[c_i] == '\"') {
                zig_panic("TODO");
            }
            buf_append_char(command_line, arg[c_i]);
        }
        buf_append_char(command_line, '\"');
    }
}

static void os_spawn_process_windows(const char *exe, ZigList<const char *> &args, Termination *term) {
    Buf command_line = BUF_INIT;
    os_windows_create_command_line(&command_line, exe, args);

    PROCESS_INFORMATION piProcInfo = {0};
    STARTUPINFO siStartInfo = {0};
    siStartInfo.cb = sizeof(STARTUPINFO);

    BOOL success = CreateProcessA(exe, buf_ptr(&command_line), nullptr, nullptr, TRUE, 0, nullptr, nullptr,
            &siStartInfo, &piProcInfo);

    if (!success) {
        zig_panic("CreateProcess failed. exe: %s command_line: %s", exe, buf_ptr(&command_line));
    }

    WaitForSingleObject(piProcInfo.hProcess, INFINITE);

    DWORD exit_code;
    if (!GetExitCodeProcess(piProcInfo.hProcess, &exit_code)) {
        zig_panic("GetExitCodeProcess failed");
    }
    term->how = TerminationIdClean;
    term->code = exit_code;
}
#endif

void os_spawn_process(const char *exe, ZigList<const char *> &args, Termination *term) {
#if defined(ZIG_OS_WINDOWS)
    os_spawn_process_windows(exe, args, term);
#elif defined(ZIG_OS_POSIX)
    os_spawn_process_posix(exe, args, term);
#else
#error "missing os_spawn_process implementation"
#endif
}

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
        if (os_is_sep(buf_ptr(full_path)[last_index])) {
            last_index -= 1;
        }
        for (size_t i = last_index;;) {
            uint8_t c = buf_ptr(full_path)[i];
            if (os_is_sep(c)) {
                if (out_dirname) {
                    buf_init_from_mem(out_dirname, buf_ptr(full_path), i);
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

int os_path_real(Buf *rel_path, Buf *out_abs_path) {
#if defined(ZIG_OS_WINDOWS)
    buf_resize(out_abs_path, 4096);
    if (_fullpath(buf_ptr(out_abs_path), buf_ptr(rel_path), buf_len(out_abs_path)) == nullptr) {
        zig_panic("_fullpath failed");
    }
    buf_resize(out_abs_path, strlen(buf_ptr(out_abs_path)));
    return ErrorNone;
#elif defined(ZIG_OS_POSIX)
    buf_resize(out_abs_path, PATH_MAX + 1);
    char *result = realpath(buf_ptr(rel_path), buf_ptr(out_abs_path));
    if (!result) {
        int err = errno;
        if (err == EACCES) {
            return ErrorAccess;
        } else if (err == ENOENT) {
            return ErrorFileNotFound;
        } else if (err == ENOMEM) {
            return ErrorNoMem;
        } else {
            return ErrorFileSystem;
        }
    }
    buf_resize(out_abs_path, strlen(buf_ptr(out_abs_path)));
    return ErrorNone;
#else
#error "missing os_path_real implementation"
#endif
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
#endif

bool os_path_is_absolute(Buf *path) {
#if defined(ZIG_OS_WINDOWS)
    return isAbsoluteWindows(buf_to_slice(path));
#elif defined(ZIG_OS_POSIX)
    return buf_ptr(path)[0] == '/';
#else
#error "missing os_path_is_absolute implementation"
#endif
}

#if defined(ZIG_OS_WINDOWS)

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
        if (os_path_is_absolute(p)) {
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
        result_ptr = allocate_nonzero<uint8_t>(result_len);
    } else {
        Buf cwd = BUF_INIT;
        int err;
        if ((err = os_get_cwd(&cwd))) {
            zig_panic("get cwd failed");
        }
        result_len = max_size + buf_len(&cwd) + 1;
        result_ptr = allocate_nonzero<uint8_t>(result_len);
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

int os_fetch_file(FILE *f, Buf *out_buf, bool skip_shebang) {
    static const ssize_t buf_size = 0x2000;
    buf_resize(out_buf, buf_size);
    ssize_t actual_buf_len = 0;

    bool first_read = true;

    for (;;) {
        size_t amt_read = fread(buf_ptr(out_buf) + actual_buf_len, 1, buf_size, f);
        actual_buf_len += amt_read;

        if (skip_shebang && first_read && buf_starts_with_str(out_buf, "#!")) {
            size_t i = 0;
            while (true) {
                if (i > buf_len(out_buf)) {
                    zig_panic("shebang line exceeded %zd characters", buf_size);
                }

                size_t current_pos = i;
                i += 1;

                if (out_buf->list.at(current_pos) == '\n') {
                    break;
                }
            }

            ZigList<char> *list = &out_buf->list;
            memmove(list->items, list->items + i, list->length - i);
            list->length -= i;

            actual_buf_len -= i;
        }

        if (amt_read != buf_size) {
            if (feof(f)) {
                buf_resize(out_buf, actual_buf_len);
                return 0;
            } else {
                return ErrorFileSystem;
            }
        }

        buf_resize(out_buf, actual_buf_len + buf_size);
        first_read = false;
    }
    zig_unreachable();
}

int os_file_exists(Buf *full_path, bool *result) {
#if defined(ZIG_OS_WINDOWS)
    *result = GetFileAttributes(buf_ptr(full_path)) != INVALID_FILE_ATTRIBUTES;
    return 0;
#else
    *result = access(buf_ptr(full_path), F_OK) != -1;
    return 0;
#endif
}

#if defined(ZIG_OS_POSIX)
static int os_exec_process_posix(const char *exe, ZigList<const char *> &args,
        Termination *term, Buf *out_stderr, Buf *out_stdout)
{
    int stdin_pipe[2];
    int stdout_pipe[2];
    int stderr_pipe[2];

    int err;
    if ((err = pipe(stdin_pipe)))
        zig_panic("pipe failed");
    if ((err = pipe(stdout_pipe)))
        zig_panic("pipe failed");
    if ((err = pipe(stderr_pipe)))
        zig_panic("pipe failed");

    pid_t pid = fork();
    if (pid == -1)
        zig_panic("fork failed");
    if (pid == 0) {
        // child
        if (dup2(stdin_pipe[0], STDIN_FILENO) == -1)
            zig_panic("dup2 failed");

        if (dup2(stdout_pipe[1], STDOUT_FILENO) == -1)
            zig_panic("dup2 failed");

        if (dup2(stderr_pipe[1], STDERR_FILENO) == -1)
            zig_panic("dup2 failed");

        const char **argv = allocate<const char *>(args.length + 2);
        argv[0] = exe;
        argv[args.length + 1] = nullptr;
        for (size_t i = 0; i < args.length; i += 1) {
            argv[i + 1] = args.at(i);
        }
        execvp(exe, const_cast<char * const *>(argv));
        if (errno == ENOENT) {
            return ErrorFileNotFound;
        } else {
            zig_panic("execvp failed: %s", strerror(errno));
        }
    } else {
        // parent
        close(stdin_pipe[0]);
        close(stdin_pipe[1]);
        close(stdout_pipe[1]);
        close(stderr_pipe[1]);

        int status;
        waitpid(pid, &status, 0);
        populate_termination(term, status);

        FILE *stdout_f = fdopen(stdout_pipe[0], "rb");
        FILE *stderr_f = fdopen(stderr_pipe[0], "rb");
        os_fetch_file(stdout_f, out_stdout, false);
        os_fetch_file(stderr_f, out_stderr, false);

        fclose(stdout_f);
        fclose(stderr_f);

        return 0;
    }
}
#endif

#if defined(ZIG_OS_WINDOWS)

//static void win32_panic(const char *str) {
//    DWORD err = GetLastError();
//    LPSTR messageBuffer = nullptr;
//    FormatMessageA(
//        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
//        NULL, err, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPSTR)&messageBuffer, 0, NULL);
//    zig_panic(str, messageBuffer);
//    LocalFree(messageBuffer);
//}

static int os_exec_process_windows(const char *exe, ZigList<const char *> &args,
        Termination *term, Buf *out_stderr, Buf *out_stdout)
{
    Buf command_line = BUF_INIT;
    os_windows_create_command_line(&command_line, exe, args);

    HANDLE g_hChildStd_IN_Rd = NULL;
    HANDLE g_hChildStd_IN_Wr = NULL;
    HANDLE g_hChildStd_OUT_Rd = NULL;
    HANDLE g_hChildStd_OUT_Wr = NULL;
    HANDLE g_hChildStd_ERR_Rd = NULL;
    HANDLE g_hChildStd_ERR_Wr = NULL;

    SECURITY_ATTRIBUTES saAttr;
    saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
    saAttr.bInheritHandle = TRUE;
    saAttr.lpSecurityDescriptor = NULL;

    if (!CreatePipe(&g_hChildStd_OUT_Rd, &g_hChildStd_OUT_Wr, &saAttr, 0)) {
        zig_panic("StdoutRd CreatePipe");
    }

    if (!SetHandleInformation(g_hChildStd_OUT_Rd, HANDLE_FLAG_INHERIT, 0)) {
        zig_panic("Stdout SetHandleInformation");
    }

    if (!CreatePipe(&g_hChildStd_ERR_Rd, &g_hChildStd_ERR_Wr, &saAttr, 0)) {
        zig_panic("stderr CreatePipe");
    }

    if (!SetHandleInformation(g_hChildStd_ERR_Rd, HANDLE_FLAG_INHERIT, 0)) {
        zig_panic("stderr SetHandleInformation");
    }

    if (!CreatePipe(&g_hChildStd_IN_Rd, &g_hChildStd_IN_Wr, &saAttr, 0)) {
        zig_panic("Stdin CreatePipe");
    }

    if (!SetHandleInformation(g_hChildStd_IN_Wr, HANDLE_FLAG_INHERIT, 0)) {
        zig_panic("Stdin SetHandleInformation");
    }


    PROCESS_INFORMATION piProcInfo = {0};
    STARTUPINFO siStartInfo = {0};
    siStartInfo.cb = sizeof(STARTUPINFO);
    siStartInfo.hStdError = g_hChildStd_ERR_Wr;
    siStartInfo.hStdOutput = g_hChildStd_OUT_Wr;
    siStartInfo.hStdInput = g_hChildStd_IN_Rd;
    siStartInfo.dwFlags |= STARTF_USESTDHANDLES;

    BOOL success = CreateProcess(exe, buf_ptr(&command_line), nullptr, nullptr, TRUE, 0, nullptr, nullptr,
            &siStartInfo, &piProcInfo);

    if (!success) {
        if (GetLastError() == ERROR_FILE_NOT_FOUND) {
            CloseHandle(piProcInfo.hProcess);
            CloseHandle(piProcInfo.hThread);
            return ErrorFileNotFound;
        }
        zig_panic("CreateProcess failed. exe: %s command_line: %s", exe, buf_ptr(&command_line));
    }

    if (!CloseHandle(g_hChildStd_IN_Wr)) {
        zig_panic("stdinwr closehandle");
    }

    CloseHandle(g_hChildStd_IN_Rd);
    CloseHandle(g_hChildStd_ERR_Wr);
    CloseHandle(g_hChildStd_OUT_Wr);

    static const size_t BUF_SIZE = 4 * 1024;
    {
        DWORD dwRead;
        char chBuf[BUF_SIZE];

        buf_resize(out_stdout, 0);
        for (;;) {
            success = ReadFile( g_hChildStd_OUT_Rd, chBuf, BUF_SIZE, &dwRead, NULL);
            if (!success || dwRead == 0) break;

            buf_append_mem(out_stdout, chBuf, dwRead);
        }
        CloseHandle(g_hChildStd_OUT_Rd);
    }
    {
        DWORD dwRead;
        char chBuf[BUF_SIZE];

        buf_resize(out_stderr, 0);
        for (;;) {
            success = ReadFile( g_hChildStd_ERR_Rd, chBuf, BUF_SIZE, &dwRead, NULL);
            if (!success || dwRead == 0) break;

            buf_append_mem(out_stderr, chBuf, dwRead);
        }
        CloseHandle(g_hChildStd_ERR_Rd);
    }

    WaitForSingleObject(piProcInfo.hProcess, INFINITE);

    DWORD exit_code;
    if (!GetExitCodeProcess(piProcInfo.hProcess, &exit_code)) {
        zig_panic("GetExitCodeProcess failed");
    }
    term->how = TerminationIdClean;
    term->code = exit_code;

    CloseHandle(piProcInfo.hProcess);
    CloseHandle(piProcInfo.hThread);

    return 0;
}
#endif

int os_exec_process(const char *exe, ZigList<const char *> &args,
        Termination *term, Buf *out_stderr, Buf *out_stdout)
{
#if defined(ZIG_OS_WINDOWS)
    return os_exec_process_windows(exe, args, term, out_stderr, out_stdout);
#elif defined(ZIG_OS_POSIX)
    return os_exec_process_posix(exe, args, term, out_stderr, out_stdout);
#else
#error "missing os_exec_process implementation"
#endif
}

void os_write_file(Buf *full_path, Buf *contents) {
    FILE *f = fopen(buf_ptr(full_path), "wb");
    if (!f) {
        zig_panic("os_write_file failed for %s", buf_ptr(full_path));
    }
    size_t amt_written = fwrite(buf_ptr(contents), 1, buf_len(contents), f);
    if (amt_written != (size_t)buf_len(contents))
        zig_panic("write failed: %s", strerror(errno));
    if (fclose(f))
        zig_panic("close failed");
}

int os_copy_file(Buf *src_path, Buf *dest_path) {
    FILE *src_f = fopen(buf_ptr(src_path), "rb");
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
    FILE *dest_f = fopen(buf_ptr(dest_path), "wb");
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

    static const size_t buf_size = 2048;
    char buf[buf_size];
    for (;;) {
        size_t amt_read = fread(buf, 1, buf_size, src_f);
        if (amt_read != buf_size) {
            if (ferror(src_f)) {
                fclose(src_f);
                fclose(dest_f);
                return ErrorFileSystem;
            }
        }
        size_t amt_written = fwrite(buf, 1, amt_read, dest_f);
        if (amt_written != amt_read) {
            fclose(src_f);
            fclose(dest_f);
            return ErrorFileSystem;
        }
        if (feof(src_f)) {
            fclose(src_f);
            fclose(dest_f);
            return 0;
        }
    }
}

int os_fetch_file_path(Buf *full_path, Buf *out_contents, bool skip_shebang) {
    FILE *f = fopen(buf_ptr(full_path), "rb");
    if (!f) {
        switch (errno) {
            case EACCES:
                return ErrorAccess;
            case EINTR:
                return ErrorInterrupted;
            case EINVAL:
                zig_unreachable();
            case ENFILE:
            case ENOMEM:
                return ErrorSystemResources;
            case ENOENT:
                return ErrorFileNotFound;
            default:
                return ErrorFileSystem;
        }
    }
    int result = os_fetch_file(f, out_contents, skip_shebang);
    fclose(f);
    return result;
}

int os_get_cwd(Buf *out_cwd) {
#if defined(ZIG_OS_WINDOWS)
    char buf[4096];
    if (GetCurrentDirectory(4096, buf) == 0) {
        zig_panic("GetCurrentDirectory failed");
    }
    buf_init_from_str(out_cwd, buf);
    return 0;
#elif defined(ZIG_OS_POSIX)
    char buf[PATH_MAX];
    char *res = getcwd(buf, PATH_MAX);
    if (res == nullptr) {
        zig_panic("unable to get cwd: %s", strerror(errno));
    }
    buf_init_from_str(out_cwd, res);
    return 0;
#else
#error "missing os_get_cwd implementation"
#endif
}

#if defined(ZIG_OS_WINDOWS)
#define is_wprefix(s, prefix) \
    (wcsncmp((s), (prefix), sizeof(prefix) / sizeof(WCHAR) - 1) == 0)
static bool is_stderr_cyg_pty(void) {
#if defined(__MINGW32__)
    return false;
#else
    HANDLE stderr_handle = GetStdHandle(STD_ERROR_HANDLE);
    if (stderr_handle == INVALID_HANDLE_VALUE)
        return false;

    int size = sizeof(FILE_NAME_INFO) + sizeof(WCHAR) * MAX_PATH;
    FILE_NAME_INFO *nameinfo;
    WCHAR *p = NULL;

    // Cygwin/msys's pty is a pipe.
    if (GetFileType(stderr_handle) != FILE_TYPE_PIPE) {
        return 0;
    }
    nameinfo = (FILE_NAME_INFO *)allocate<char>(size);
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
    free(nameinfo);
    return (p != NULL);
#endif
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

#if defined(ZIG_OS_POSIX)
static int os_buf_to_tmp_file_posix(Buf *contents, Buf *suffix, Buf *out_tmp_path) {
    const char *tmp_dir = getenv("TMPDIR");
    if (!tmp_dir) {
        tmp_dir = P_tmpdir;
    }
    buf_resize(out_tmp_path, 0);
    buf_appendf(out_tmp_path, "%s/XXXXXX%s", tmp_dir, buf_ptr(suffix));

    int fd = mkstemps(buf_ptr(out_tmp_path), (int)buf_len(suffix));
    if (fd < 0) {
        return ErrorFileSystem;
    }

    FILE *f = fdopen(fd, "wb");
    if (!f) {
        zig_panic("fdopen failed");
    }

    size_t amt_written = fwrite(buf_ptr(contents), 1, buf_len(contents), f);
    if (amt_written != (size_t)buf_len(contents))
        zig_panic("write failed: %s", strerror(errno));
    if (fclose(f))
        zig_panic("close failed");

    return 0;
}
#endif

#if defined(ZIG_OS_WINDOWS)
static int os_buf_to_tmp_file_windows(Buf *contents, Buf *suffix, Buf *out_tmp_path) {
    char tmp_dir[MAX_PATH + 1];
    if (GetTempPath(MAX_PATH, tmp_dir) == 0) {
        zig_panic("GetTempPath failed");
    }
    buf_init_from_str(out_tmp_path, tmp_dir);

    const char base64[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_";
    assert(array_length(base64) == 64 + 1);
    for (size_t i = 0; i < 8; i += 1) {
        buf_append_char(out_tmp_path, base64[rand() % 64]);
    }

    buf_append_buf(out_tmp_path, suffix);

    FILE *f = fopen(buf_ptr(out_tmp_path), "wb");

    if (!f) {
        zig_panic("unable to open %s: %s", buf_ptr(out_tmp_path), strerror(errno));
    }

    size_t amt_written = fwrite(buf_ptr(contents), 1, buf_len(contents), f);
    if (amt_written != (size_t)buf_len(contents)) {
        zig_panic("write failed: %s", strerror(errno));
    }

    if (fclose(f)) {
        zig_panic("fclose failed");
    }
    return 0;
}
#endif

int os_buf_to_tmp_file(Buf *contents, Buf *suffix, Buf *out_tmp_path) {
#if defined(ZIG_OS_WINDOWS)
    return os_buf_to_tmp_file_windows(contents, suffix, out_tmp_path);
#elif defined(ZIG_OS_POSIX)
    return os_buf_to_tmp_file_posix(contents, suffix, out_tmp_path);
#else
#error "missing os_buf_to_tmp_file implementation"
#endif
}

#if defined(ZIG_OS_POSIX)
int os_get_global_cache_directory(Buf *out_tmp_path) {
    const char *tmp_dir = getenv("TMPDIR");
    if (!tmp_dir) {
        tmp_dir = P_tmpdir;
    }

    Buf *tmp_dir_buf = buf_create_from_str(tmp_dir);
    Buf *cache_dirname_buf = buf_create_from_str("zig-cache");

    buf_resize(out_tmp_path, 0);
    os_path_join(tmp_dir_buf, cache_dirname_buf, out_tmp_path);

    buf_deinit(tmp_dir_buf);
    buf_deinit(cache_dirname_buf);
    return 0;
}
#endif

#if defined(ZIG_OS_WINDOWS)
int os_get_global_cache_directory(Buf *out_tmp_path) {
    char tmp_dir[MAX_PATH + 1];
    if (GetTempPath(MAX_PATH, tmp_dir) == 0) {
        zig_panic("GetTempPath failed");
    }

    Buf *tmp_dir_buf = buf_create_from_str(tmp_dir);
    Buf *cache_dirname_buf = buf_create_from_str("zig-cache");

    buf_resize(out_tmp_path, 0);
    os_path_join(tmp_dir_buf, cache_dirname_buf, out_tmp_path);

    buf_deinit(tmp_dir_buf);
    buf_deinit(cache_dirname_buf);
    return 0;
}
#endif

int os_delete_file(Buf *path) {
    if (remove(buf_ptr(path))) {
        return ErrorFileSystem;
    } else {
        return 0;
    }
}

int os_rename(Buf *src_path, Buf *dest_path) {
    if (buf_eql_buf(src_path, dest_path)) {
        return 0;
    }
#if defined(ZIG_OS_WINDOWS)
    if (!MoveFileExA(buf_ptr(src_path), buf_ptr(dest_path), MOVEFILE_REPLACE_EXISTING)) {
        return ErrorFileSystem;
    }
#else
    if (rename(buf_ptr(src_path), buf_ptr(dest_path)) == -1) {
        return ErrorFileSystem;
    }
#endif
    return 0;
}

double os_get_time(void) {
#if defined(ZIG_OS_WINDOWS)
    unsigned __int64 time;
    QueryPerformanceCounter((LARGE_INTEGER*) &time);
    return time * win32_time_resolution;
#elif defined(__MACH__)
    mach_timespec_t mts;

    kern_return_t err = clock_get_time(cclock, &mts);
    assert(!err);

    double seconds = (double)mts.tv_sec;
    seconds += ((double)mts.tv_nsec) / 1000000000.0;

    return seconds;
#else
    struct timespec tms;
    clock_gettime(CLOCK_MONOTONIC, &tms);
    double seconds = (double)tms.tv_sec;
    seconds += ((double)tms.tv_nsec) / 1000000000.0;
    return seconds;
#endif
}

int os_make_path(Buf *path) {
    Buf resolved_path = os_path_resolve(&path, 1);

    size_t end_index = buf_len(&resolved_path);
    int err;
    while (true) {
        if ((err = os_make_dir(buf_slice(&resolved_path, 0, end_index)))) {
            if (err == ErrorPathAlreadyExists) {
                if (end_index == buf_len(&resolved_path))
                    return 0;
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
            return 0;
        // march end_index forward until next path component
        while (true) {
            end_index += 1;
            if (end_index == buf_len(&resolved_path) || os_is_sep(buf_ptr(&resolved_path)[end_index]))
                break;
        }
    }
    return 0;
}

int os_make_dir(Buf *path) {
#if defined(ZIG_OS_WINDOWS)
    if (!CreateDirectory(buf_ptr(path), NULL)) {
        if (GetLastError() == ERROR_ALREADY_EXISTS)
            return ErrorPathAlreadyExists;
        if (GetLastError() == ERROR_PATH_NOT_FOUND)
            return ErrorFileNotFound;
        if (GetLastError() == ERROR_ACCESS_DENIED)
            return ErrorAccess;
        return ErrorUnexpected;
    }
    return 0;
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
    return 0;
#endif
}

int os_init(void) {
    srand((unsigned)time(NULL));
#if defined(ZIG_OS_WINDOWS)
    _setmode(fileno(stdout), _O_BINARY);
    _setmode(fileno(stderr), _O_BINARY);
#endif
#if defined(ZIG_OS_WINDOWS)
    unsigned __int64 frequency;
    if (QueryPerformanceFrequency((LARGE_INTEGER*) &frequency)) {
        win32_time_resolution = 1.0 / (double) frequency;
    } else {
        return ErrorSystemResources;
    }
#elif defined(__MACH__)
    host_get_clock_service(mach_host_self(), SYSTEM_CLOCK, &cclock);
#endif
    return 0;
}

int os_self_exe_path(Buf *out_path) {
#if defined(ZIG_OS_WINDOWS)
    buf_resize(out_path, 256);
    for (;;) {
        DWORD copied_amt = GetModuleFileName(nullptr, buf_ptr(out_path), buf_len(out_path));
        if (copied_amt <= 0) {
            return ErrorFileNotFound;
        }
        if (copied_amt < buf_len(out_path)) {
            buf_resize(out_path, copied_amt);
            return 0;
        }
        buf_resize(out_path, buf_len(out_path) * 2);
    }

#elif defined(ZIG_OS_DARWIN)
    // How long is the executable's path?
    uint32_t u32_len = 0;
    int ret1 = _NSGetExecutablePath(nullptr, &u32_len);
    assert(ret1 != 0);

    Buf *tmp = buf_alloc_fixed(u32_len);

    // Fill the executable path.
    int ret2 = _NSGetExecutablePath(buf_ptr(tmp), &u32_len);
    assert(ret2 == 0);

    // According to libuv project, PATH_MAX*2 works around a libc bug where
    // the resolved path is sometimes bigger than PATH_MAX.
    buf_resize(out_path, PATH_MAX*2);
    char *real_path = realpath(buf_ptr(tmp), buf_ptr(out_path));
    if (!real_path) {
        buf_init_from_buf(out_path, tmp);
        return 0;
    }

    // Resize out_path for the correct length.
    buf_resize(out_path, strlen(buf_ptr(out_path)));

    return 0;
#elif defined(ZIG_OS_LINUX)
    buf_resize(out_path, 256);
    for (;;) {
        ssize_t amt = readlink("/proc/self/exe", buf_ptr(out_path), buf_len(out_path));
        if (amt == -1) {
            return ErrorUnexpected;
        }
        if (amt == (ssize_t)buf_len(out_path)) {
            buf_resize(out_path, buf_len(out_path) * 2);
            continue;
        }
        buf_resize(out_path, amt);
        return 0;
    }
#endif
    return ErrorFileNotFound;
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

int os_get_win32_ucrt_lib_path(ZigWindowsSDK *sdk, Buf* output_buf, ZigLLVM_ArchType platform_type) {
#if defined(ZIG_OS_WINDOWS)
    buf_resize(output_buf, 0);
    buf_appendf(output_buf, "%s\\Lib\\%s\\ucrt\\", sdk->path10_ptr, sdk->version10_ptr);
    switch (platform_type) {
    case ZigLLVM_x86:
        buf_append_str(output_buf, "x86\\");
        break;
    case ZigLLVM_x86_64:
        buf_append_str(output_buf, "x64\\");
        break;
    case ZigLLVM_arm:
        buf_append_str(output_buf, "arm\\");
        break;
    default:
        zig_panic("Attemped to use vcruntime for non-supported platform.");
    }
    Buf* tmp_buf = buf_alloc();
    buf_init_from_buf(tmp_buf, output_buf);
    buf_append_str(tmp_buf, "ucrt.lib");
    if (GetFileAttributesA(buf_ptr(tmp_buf)) != INVALID_FILE_ATTRIBUTES) {
        return 0;
    }
    else {
        buf_resize(output_buf, 0);
        return ErrorFileNotFound;
    }
#else
    return ErrorFileNotFound;
#endif
}

int os_get_win32_ucrt_include_path(ZigWindowsSDK *sdk, Buf* output_buf) {
#if defined(ZIG_OS_WINDOWS)
    buf_resize(output_buf, 0);
    buf_appendf(output_buf, "%s\\Include\\%s\\ucrt", sdk->path10_ptr, sdk->version10_ptr);
    if (GetFileAttributesA(buf_ptr(output_buf)) != INVALID_FILE_ATTRIBUTES) {
        return 0;
    }
    else {
        buf_resize(output_buf, 0);
        return ErrorFileNotFound;
    }
#else
    return ErrorFileNotFound;
#endif
}

int os_get_win32_kern32_path(ZigWindowsSDK *sdk, Buf* output_buf, ZigLLVM_ArchType platform_type) {
#if defined(ZIG_OS_WINDOWS)
    {
        buf_resize(output_buf, 0);
        buf_appendf(output_buf, "%s\\Lib\\%s\\um\\", sdk->path10_ptr, sdk->version10_ptr);
        switch (platform_type) {
        case ZigLLVM_x86:
            buf_append_str(output_buf, "x86\\");
            break;
        case ZigLLVM_x86_64:
            buf_append_str(output_buf, "x64\\");
            break;
        case ZigLLVM_arm:
            buf_append_str(output_buf, "arm\\");
            break;
        default:
            zig_panic("Attemped to use vcruntime for non-supported platform.");
        }
        Buf* tmp_buf = buf_alloc();
        buf_init_from_buf(tmp_buf, output_buf);
        buf_append_str(tmp_buf, "kernel32.lib");
        if (GetFileAttributesA(buf_ptr(tmp_buf)) != INVALID_FILE_ATTRIBUTES) {
            return 0;
        }
    }
    {
        buf_resize(output_buf, 0);
        buf_appendf(output_buf, "%s\\Lib\\%s\\um\\", sdk->path81_ptr, sdk->version81_ptr);
        switch (platform_type) {
        case ZigLLVM_x86:
            buf_append_str(output_buf, "x86\\");
            break;
        case ZigLLVM_x86_64:
            buf_append_str(output_buf, "x64\\");
            break;
        case ZigLLVM_arm:
            buf_append_str(output_buf, "arm\\");
            break;
        default:
            zig_panic("Attemped to use vcruntime for non-supported platform.");
        }
        Buf* tmp_buf = buf_alloc();
        buf_init_from_buf(tmp_buf, output_buf);
        buf_append_str(tmp_buf, "kernel32.lib");
        if (GetFileAttributesA(buf_ptr(tmp_buf)) != INVALID_FILE_ATTRIBUTES) {
            return 0;
        }
    }
    return ErrorFileNotFound;
#else
    return ErrorFileNotFound;
#endif
}
