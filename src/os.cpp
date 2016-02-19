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

#include <windows.h>
#include <io.h>
#else
#define ZIG_OS_POSIX

#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <limits.h>

#endif

#include <stdlib.h>
#include <errno.h>
#include <time.h>

// these implementations are lazy. But who cares, we'll make a robust
// implementation in the zig standard library and then this code all gets
// deleted when we self-host. it works for now.


#if defined(ZIG_OS_POSIX)
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
#endif

#if defined(ZIG_OS_WINDOWS)
static void os_spawn_process_windows(const char *exe, ZigList<const char *> &args, int *return_code) {
    Buf stderr_buf = BUF_INIT;
    Buf stdout_buf = BUF_INIT;

    // TODO this is supposed to inherit stdout/stderr instead of capturing it
    os_exec_process(exe, args, return_code, &stderr_buf, &stdout_buf);
    fwrite(buf_ptr(&stderr_buf), 1, buf_len(&stderr_buf), stderr);
    fwrite(buf_ptr(&stdout_buf), 1, buf_len(&stdout_buf), stdout);
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
static int os_exec_process_posix(const char *exe, ZigList<const char *> &args,
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
        if (errno == ENOENT) {
            return ErrorFileNotFound;
        } else {
            zig_panic("execvp failed: %s", strerror(errno));
        }
    } else {
        // parent
        close(stdin_pipe[0]);
        close(stdout_pipe[1]);
        close(stderr_pipe[1]);

        waitpid(pid, return_code, 0);

        os_fetch_file(fdopen(stdout_pipe[0], "rb"), out_stdout);
        os_fetch_file(fdopen(stderr_pipe[0], "rb"), out_stderr);

        return 0;
    }
}
#endif

#if defined(ZIG_OS_WINDOWS)

/*
static void win32_panic(const char *str) {
    DWORD err = GetLastError();
    LPSTR messageBuffer = nullptr;
    FormatMessageA(
        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL, err, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPSTR)&messageBuffer, 0, NULL);
    zig_panic(str, messageBuffer);
    LocalFree(messageBuffer);
}
*/

static int os_exec_process_windows(const char *exe, ZigList<const char *> &args,
        int *return_code, Buf *out_stderr, Buf *out_stdout)
{
    Buf command_line = BUF_INIT;
    buf_resize(&command_line, 0);

    buf_append_char(&command_line, '\"');
    buf_append_str(&command_line, exe);
    buf_append_char(&command_line, '\"');

    for (int arg_i = 0; arg_i < args.length; arg_i += 1) {
        buf_append_str(&command_line, " \"");
        const char *arg = args.at(arg_i);
        int arg_len = strlen(arg);
        for (int c_i = 0; c_i < arg_len; c_i += 1) {
            if (arg[c_i] == '\"') {
                zig_panic("TODO");
            }
            buf_append_char(&command_line, arg[c_i]);
        }
        buf_append_char(&command_line, '\"');
    }


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

    static const int BUF_SIZE = 4 * 1024;
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
    *return_code = exit_code;

    CloseHandle(piProcInfo.hProcess);
    CloseHandle(piProcInfo.hThread);

    return 0;
}
#endif

int os_exec_process(const char *exe, ZigList<const char *> &args,
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
    if (amt_written != (size_t)buf_len(contents))
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
    buf_resize(out_cwd, 4096);
    if (GetCurrentDirectory(buf_len(out_cwd), buf_ptr(out_cwd)) == 0) {
        zig_panic("GetCurrentDirectory failed");
    }
    return 0;
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

#if defined(ZIG_OS_POSIX)
static int os_buf_to_tmp_file_posix(Buf *contents, Buf *suffix, Buf *out_tmp_path) {
    const char *tmp_dir = getenv("TMPDIR");
    if (!tmp_dir) {
        tmp_dir = P_tmpdir;
    }
    buf_resize(out_tmp_path, 0);
    buf_appendf(out_tmp_path, "%s/XXXXXX%s", tmp_dir, buf_ptr(suffix));

    int fd = mkstemps(buf_ptr(out_tmp_path), buf_len(suffix));
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
    for (int i = 0; i < 8; i += 1) {
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

int os_delete_file(Buf *path) {
    if (remove(buf_ptr(path))) {
        return ErrorFileSystem;
    } else {
        return 0;
    }
}

void os_init(void) {
    srand(time(NULL));
}
