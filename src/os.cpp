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
#include "windows_com.hpp"

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
#endif

#if defined(ZIG_OS_WINDOWS)
static double win32_time_resolution;
#elif defined(__MACH__)
static clock_serv_t cclock;
#endif

#include <stdlib.h>
#include <errno.h>
#include <time.h>

// these implementations are lazy. But who cares, we'll make a robust
// implementation in the zig standard library and then this code all gets
// deleted when we self-host. it works for now.

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

bool os_path_is_absolute(Buf *path) {
#if defined(ZIG_OS_WINDOWS)
    if (buf_starts_with_str(path, "/") || buf_starts_with_str(path, "\\"))
        return true;

    if (buf_len(path) >= 3 && buf_ptr(path)[1] == ':')
        return true;

    return false;
#elif defined(ZIG_OS_POSIX)
    return buf_ptr(path)[0] == '/';
#else
#error "missing os_path_is_absolute implementation"
#endif
}

void os_path_resolve(Buf *ref_path, Buf *target_path, Buf *out_abs_path) {
    if (os_path_is_absolute(target_path)) {
        buf_init_from_buf(out_abs_path, target_path);
        return;
    }

    os_path_join(ref_path, target_path, out_abs_path);
    return;
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
        os_fetch_file(stdout_f, out_stdout);
        os_fetch_file(stderr_f, out_stderr);

        fclose(stdout_f);
        fclose(stderr_f);

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
        zig_panic("open failed");
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

int os_delete_file(Buf *path) {
    if (remove(buf_ptr(path))) {
        return ErrorFileSystem;
    } else {
        return 0;
    }
}

int os_rename(Buf *src_path, Buf *dest_path) {
    if (rename(buf_ptr(src_path), buf_ptr(dest_path)) == -1) {
        return ErrorFileSystem;
    }
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
    Buf *resolved_path = buf_alloc();
    os_path_resolve(buf_create_from_str("."), path, resolved_path);

    size_t end_index = buf_len(resolved_path);
    int err;
    while (true) {
        if ((err = os_make_dir(buf_slice(resolved_path, 0, end_index)))) {
            if (err == ErrorPathAlreadyExists) {
                if (end_index == buf_len(resolved_path))
                    return 0;
            } else if (err == ErrorFileNotFound) {
                // march end_index backward until next path component
                while (true) {
                    end_index -= 1;
                    if (os_is_sep(buf_ptr(resolved_path)[end_index]))
                        break;
                }
                continue;
            } else {
                return err;
            }
        }
        if (end_index == buf_len(resolved_path))
            return 0;
        // march end_index forward until next path component
        while (true) {
            end_index += 1;
            if (end_index == buf_len(resolved_path) || os_is_sep(buf_ptr(resolved_path)[end_index]))
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
    return ErrorFileNotFound;
#elif defined(ZIG_OS_LINUX)
    return ErrorFileNotFound;
#endif
    return ErrorFileNotFound;
}

#define VT_RED "\x1b[31;1m"
#define VT_GREEN "\x1b[32;1m"
#define VT_CYAN "\x1b[36;1m"
#define VT_WHITE "\x1b[37;1m"
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

static Buf* WindowsSDKPath = buf_alloc();
static Buf* WindowsSDKVersion = buf_alloc();
static int set_windows_sdk_path_and_version()
{
	if (WindowsSDKPath == NULL) {
		return 1;
	}
	else if (buf_len(WindowsSDKPath)) {
		return 0;
	}

	HKEY key;
	HRESULT rc;
	rc = RegOpenKeyEx(HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Windows Kits\\Installed Roots", 0, KEY_QUERY_VALUE | KEY_WOW64_32KEY | KEY_ENUMERATE_SUB_KEYS, &key);
	if (rc != ERROR_SUCCESS) {
		WindowsSDKPath = NULL;
		return 1;
	}

	Buf* tmp_buf = buf_alloc();
	DWORD buf_len = MAX_PATH;
	tmp_buf->list.ensure_capacity(buf_len);
	rc = RegQueryValueEx(key, "KitsRoot10", NULL, NULL, (LPBYTE)buf_ptr(tmp_buf), &buf_len);
	if (rc == ERROR_FILE_NOT_FOUND) {
		WindowsSDKPath = NULL;
		return 1;
	}
	tmp_buf->list.length = buf_len;
	buf_append_buf(WindowsSDKPath, tmp_buf);

	int i = 0;
	buf_len = MAX_PATH;
	WindowsSDKVersion->list.ensure_capacity(buf_len);
	tmp_buf->list.ensure_capacity(buf_len);
	int v0 = 0, v1 = 0, v2 = 0, v3 = 0;
	while ((rc = RegEnumKeyEx(key, i, buf_ptr(tmp_buf), &buf_len, NULL, NULL, NULL, NULL)) == ERROR_SUCCESS) {
		//RegEnumKeyEx does not included the terminaing null, while RegQueryValueEx does.........awesome
		tmp_buf->list.length = buf_len + 1;
		int c0 = 0, c1 = 0, c2 = 0, c3 = 0;
		sscanf(buf_ptr(tmp_buf), "%d.%d.%d.%d", &c0, &c1, &c2, &c3);
		if ((c0 > v0) || (c1 > v1) || (c2 > v2) || (c3 > v3)) {
			v0 = c0, v1 = c1, v2 = c2, v3 = c3;
			buf_init_from_buf(WindowsSDKVersion, tmp_buf);
		}
		++i;
		buf_len = MAX_PATH;
	}

	return 0;
}

int os_get_win32_vcruntime_path(Buf* output_buf, ZigLLVM_ArchType platform_type)
{
	buf_resize(output_buf, 0);
	//COM Smart Pointerse requires explicit scope
	{
		HRESULT rc;
		rc = CoInitializeEx(NULL, COINIT_MULTITHREADED);
		if (rc != S_OK) {
			goto com_done;
		}

		//This COM class is installed when a VS2017
		ISetupConfigurationPtr setup_config;
		rc = setup_config.CreateInstance(__uuidof(SetupConfiguration));
		if (rc != S_OK) {
			goto com_done;
		}

		IEnumSetupInstancesPtr all_instances;
		rc = setup_config->EnumInstances(&all_instances);
		if (rc != S_OK) {
			goto com_done;
		}

		ISetupInstance* curr_instance;
		ULONG found_inst;
		while ((rc = all_instances->Next(1, &curr_instance, &found_inst) == S_OK)) {
			BSTR bstr_inst_path;
			rc = curr_instance->GetInstallationPath(&bstr_inst_path);
			if (rc != S_OK) {
				goto com_done;
			}
			//BSTRs are UTF-16 encoded, so we need to convert the string & adjust the length
			UINT bstr_path_len = *((UINT*)bstr_inst_path - 1);
			ULONG tmp_path_len = bstr_path_len / 2 + 1;
			char* conv_path = (char*)bstr_inst_path;
			char *tmp_path = (char*)alloca(tmp_path_len);
			memset(tmp_path, 0, tmp_path_len);
			uint32_t c = 0;
			for (uint32_t i = 0; i < bstr_path_len; i += 2) {
				tmp_path[c] = conv_path[i];
				++c;
				assert(c != tmp_path_len);
			}

			buf_append_str(output_buf, tmp_path);
			buf_append_char(output_buf, '\\');

			Buf* tmp_buf = buf_alloc();
			buf_append_buf(tmp_buf, output_buf);
			buf_append_str(tmp_buf, "VC\\Auxiliary\\Build\\Microsoft.VCToolsVersion.default.txt");
			FILE* tools_file = fopen(buf_ptr(tmp_buf), "r");
			if (!tools_file) {
				goto com_done;
			}
			memset(tmp_path, 0, tmp_path_len);
			fgets(tmp_path, tmp_path_len, tools_file);
			strtok(tmp_path, " \r\n");
			fclose(tools_file);
			buf_appendf(output_buf, "VC\\Tools\\MSVC\\%s\\lib\\", tmp_path);
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
			buf_resize(tmp_buf, 0);
			buf_append_buf(tmp_buf, output_buf);
			buf_append_str(tmp_buf, "vcruntime.lib");

			if (GetFileAttributesA(buf_ptr(tmp_buf)) != INVALID_FILE_ATTRIBUTES) {
				return 0;
			}
		}
	}

com_done:;
	HKEY key;
	HRESULT rc;
	rc = RegOpenKeyEx(HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\VisualStudio\\SxS\\VS7", 0, KEY_QUERY_VALUE | KEY_WOW64_32KEY, &key);
	if (rc != ERROR_SUCCESS) {
		return 1;
	}

	DWORD dw_type = 0;
	DWORD cb_data = 0;
	rc = RegQueryValueEx(key, "14.0", NULL, &dw_type, NULL, &cb_data);
	if ((rc == ERROR_FILE_NOT_FOUND) || (REG_SZ != dw_type)) {
		return 1;
	}

	Buf* tmp_buf = buf_alloc();
	tmp_buf->list.ensure_capacity(MAX_PATH);
	RegQueryValueExA(key, "14.0", NULL, NULL, (LPBYTE)buf_ptr(tmp_buf), &cb_data);
	tmp_buf->list.length = cb_data;
	buf_append_str(tmp_buf, "VC\\Lib\\");
	switch (platform_type) {
	case ZigLLVM_x86:
		//x86 is in the root of the Lib folder
		break;
	case ZigLLVM_x86_64:
		buf_append_str(tmp_buf, "amd64\\");
		break;
	case ZigLLVM_arm:
		buf_append_str(tmp_buf, "arm\\");
		break;
	default:
		zig_panic("Attemped to use vcruntime for non-supported platform.");
	}

	buf_append_buf(output_buf, tmp_buf);
	buf_append_str(tmp_buf, "vcruntime.lib");

	if (GetFileAttributesA(buf_ptr(tmp_buf)) != INVALID_FILE_ATTRIBUTES) {
		return 0;
	}
	else {
		buf_resize(output_buf, 0);
		return 1;
	}
}

int os_get_win32_ucrt_lib_path(Buf* output_buf, ZigLLVM_ArchType platform_type)
{
	if (set_windows_sdk_path_and_version()) {
		return 1;
	}

	buf_resize(output_buf, 0);
	buf_appendf(output_buf, "%s\\Lib\\%s\\ucrt\\", buf_ptr(WindowsSDKPath), buf_ptr(WindowsSDKVersion));
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
		return 1;
	}
}

int os_get_win32_ucrt_include_path(Buf* output_buf) 
{
	if (set_windows_sdk_path_and_version()) {
		return 1;
	}

	buf_resize(output_buf, 0);
	buf_appendf(output_buf, "%s\\Include\\%s\\ucrt", buf_ptr(WindowsSDKPath), buf_ptr(WindowsSDKVersion));
	if (GetFileAttributesA(buf_ptr(output_buf)) != INVALID_FILE_ATTRIBUTES) {
		return 0;
	}
	else {
		buf_resize(output_buf, 0);
		return 1;
	}
}

int os_get_win32_kern32_path(Buf* output_buf, ZigLLVM_ArchType platform_type)
{
	if (set_windows_sdk_path_and_version()) {
		return 1;
	}

	buf_resize(output_buf, 0);
	buf_appendf(output_buf, "%s\\Lib\\%s\\um\\", buf_ptr(WindowsSDKPath), buf_ptr(WindowsSDKVersion));
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
	else {
		buf_resize(output_buf, 0);
		return 1;
	}
}