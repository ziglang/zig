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
#define ZIG_OS_WINDOWS

#if !defined(NOMINMAX)
#define NOMINMAX
#endif

#if !defined(VC_EXTRALEAN)
#define VC_EXTRALEAN
#endif

#if !defined(WIN32_LEAN_AND_MEAN)
#define WIN32_LEAN_AND_MEAN
#endif

#if !defined(UNICODE)
#define UNICODE
#endif

#include <windows.h>
#include <io.h>
#else
#define ZIG_OS_POSIX

#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <limits.h>

#endif


static void os_spawn_process_posix(const char *exe, ZigList<const char *> &args, int *return_code) {
    pid_t pid = fork();
    if (pid == -1)
        zig_panic("fork failed");
    if (pid == 0) {
        // child
        const char **argv = allocate<const char *>(args.length + 2);
        argv[0] = exe;
        argv[args.length + 1] = nullptr;
        for (int i = 0; i < args.length; i += 1) {
            argv[i + 1] = args.at(i);
        }
        execvp(exe, const_cast<char * const *>(argv));
        zig_panic("execvp failed: %s", strerror(errno));
    } else {
        // parent
        waitpid(pid, return_code, 0);
    }
}

#if defined(ZIG_OS_WINDOWS)
static void os_spawn_process_windows(const char *exe, ZigList<const char *> &args, int *return_code) {
    zig_panic("TODO os_spawn_process_windows");
}
#endif

void os_spawn_process(const char *exe, ZigList<const char *> &args, int *return_code) {
#if defined(ZIG_OS_WINDOWS)
    os_spawn_process_windows(exe, args, return_code);
#elif defined(ZIG_OS_POSIX)
    os_spawn_process_posix(exe, args, return_code);
#else
#error "missing os_spawn_process implementation"
#endif
}

void os_path_split(Buf *full_path, Buf *out_dirname, Buf *out_basename) {
    int last_index = buf_len(full_path) - 1;
    if (last_index >= 0 && buf_ptr(full_path)[last_index] == '/') {
        last_index -= 1;
    }
    for (int i = last_index; i >= 0; i -= 1) {
        uint8_t c = buf_ptr(full_path)[i];
        if (c == '/') {
            buf_init_from_mem(out_dirname, buf_ptr(full_path), i);
            buf_init_from_mem(out_basename, buf_ptr(full_path) + i + 1, buf_len(full_path) - (i + 1));
            return;
        }
    }
    buf_init_from_mem(out_dirname, ".", 1);
    buf_init_from_buf(out_basename, full_path);
}

void os_path_join(Buf *dirname, Buf *basename, Buf *out_full_path) {
    buf_init_from_buf(out_full_path, dirname);
    uint8_t c = *(buf_ptr(out_full_path) + buf_len(out_full_path) - 1);
    if (c != '/')
        buf_append_char(out_full_path, '/');
    buf_append_buf(out_full_path, basename);
}

int os_path_real(Buf *rel_path, Buf *out_abs_path) {
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
}

int os_fetch_file(FILE *f, Buf *out_buf) {
    static const ssize_t buf_size = 0x2000;
    buf_resize(out_buf, buf_size);
    ssize_t actual_buf_len = 0;
    for (;;) {
        size_t amt_read = fread(buf_ptr(out_buf) + actual_buf_len, 1, buf_size, f);
        actual_buf_len += amt_read;
        if (amt_read != buf_size) {
            if (feof(f)) {
                buf_resize(out_buf, actual_buf_len);
                return 0;
            } else {
                return ErrorFileSystem;
            }
        }

        buf_resize(out_buf, actual_buf_len + buf_size);
    }
    zig_unreachable();
}


#if defined(ZIG_OS_POSIX)
static void os_exec_process_posix(const char *exe, ZigList<const char *> &args,
        int *return_code, Buf *out_stderr, Buf *out_stdout)
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
        for (int i = 0; i < args.length; i += 1) {
            argv[i + 1] = args.at(i);
        }
        execvp(exe, const_cast<char * const *>(argv));
        zig_panic("execvp failed: %s", strerror(errno));
    } else {
        // parent
        close(stdin_pipe[0]);
        close(stdout_pipe[1]);
        close(stderr_pipe[1]);

        waitpid(pid, return_code, 0);

        os_fetch_file(fdopen(stdout_pipe[0], "rb"), out_stdout);
        os_fetch_file(fdopen(stderr_pipe[0], "rb"), out_stderr);

    }
}
#endif

void os_exec_process(const char *exe, ZigList<const char *> &args,
        int *return_code, Buf *out_stderr, Buf *out_stdout)
{
#if defined(ZIG_OS_WINDOWS)
    return os_exec_process_windows(exe, args, return_code, out_stderr, out_stdout);
#elif defined(ZIG_OS_POSIX)
    return os_exec_process_posix(exe, args, return_code, out_stderr, out_stdout);
#else
#error "missing os_exec_process implementation"
#endif
}

void os_write_file(Buf *full_path, Buf *contents) {
    FILE *f = fopen(buf_ptr(full_path), "wb");
    if (!f) {
        zig_panic("open failed");
    }
    size_t amt_written = fwrite(buf_ptr(contents), 1, buf_len(contents), f);
    if (amt_written != buf_len(contents))
        zig_panic("write failed: %s", strerror(errno));
    if (fclose(f))
        zig_panic("close failed");
}

int os_fetch_file_path(Buf *full_path, Buf *out_contents) {
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
    int result = os_fetch_file(f, out_contents);
    fclose(f);
    return result;
}

int os_get_cwd(Buf *out_cwd) {
#if defined(ZIG_OS_WINDOWS)
    zig_panic("TODO os_get_cwd for windows");
#elif defined(ZIG_OS_POSIX)
    int err = ERANGE;
    buf_resize(out_cwd, 512);
    while (err == ERANGE) {
        buf_resize(out_cwd, buf_len(out_cwd) * 2);
        err = getcwd(buf_ptr(out_cwd), buf_len(out_cwd)) ? 0 : errno;
    }
    if (err)
        zig_panic("unable to get cwd: %s", strerror(err));

    return 0;
#else
#error "missing os_get_cwd implementation"
#endif
}

bool os_stderr_tty(void) {
#if defined(ZIG_OS_WINDOWS)
    return _isatty(STDERR_FILENO) != 0;
#elif defined(ZIG_OS_POSIX)
    return isatty(STDERR_FILENO) != 0;
#else
#error "missing os_stderr_tty implementation"
#endif
}

int os_buf_to_tmp_file(Buf *contents, Buf *suffix, Buf *out_tmp_path) {
    buf_resize(out_tmp_path, 0);
    buf_appendf(out_tmp_path, "/tmp/XXXXXX%s", buf_ptr(suffix));

    int fd = mkstemps(buf_ptr(out_tmp_path), buf_len(suffix));
    if (fd < 0) {
        return ErrorFileSystem;
    }

    FILE *f = fdopen(fd, "wb");
    if (!f) {
        zig_panic("fdopen failed");
    }

    size_t amt_written = fwrite(buf_ptr(contents), 1, buf_len(contents), f);
    if (amt_written != buf_len(contents))
        zig_panic("write failed: %s", strerror(errno));
    if (fclose(f))
        zig_panic("close failed");

    return 0;
}

int os_delete_file(Buf *path) {
    if (remove(buf_ptr(path))) {
        return ErrorFileSystem;
    } else {
        return 0;
    }
}
