/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "libc_installation.hpp"
#include "os.hpp"
#include "windows_sdk.h"
#include "target.hpp"

static const char *zig_libc_keys[] = {
    "include_dir",
    "sys_include_dir",
    "crt_dir",
    "lib_dir",
    "static_lib_dir",
    "msvc_lib_dir",
    "kernel32_lib_dir",
    "dynamic_linker_path",
};

static const size_t zig_libc_keys_len = array_length(zig_libc_keys);

static bool zig_libc_match_key(Slice<uint8_t> name, Slice<uint8_t> value, bool *found_keys,
        size_t index, Buf *field_ptr)
{
    if (!memEql(name, str(zig_libc_keys[index]))) return false;
    buf_init_from_mem(field_ptr, (const char*)value.ptr, value.len);
    found_keys[index] = true;
    return true;
}

static void zig_libc_init_empty(ZigLibCInstallation *libc) {
    *libc = {};
    buf_init_from_str(&libc->include_dir, "");
    buf_init_from_str(&libc->sys_include_dir, "");
    buf_init_from_str(&libc->crt_dir, "");
    buf_init_from_str(&libc->lib_dir, "");
    buf_init_from_str(&libc->static_lib_dir, "");
    buf_init_from_str(&libc->msvc_lib_dir, "");
    buf_init_from_str(&libc->kernel32_lib_dir, "");
    buf_init_from_str(&libc->dynamic_linker_path, "");
}

Error zig_libc_parse(ZigLibCInstallation *libc, Buf *libc_file, const ZigTarget *target, bool verbose) {
    Error err;
    zig_libc_init_empty(libc);

    bool found_keys[array_length(zig_libc_keys)] = {};

    Buf *contents = buf_alloc();
    if ((err = os_fetch_file_path(libc_file, contents, false))) {
        if (err != ErrorFileNotFound && verbose) {
            fprintf(stderr, "Unable to read '%s': %s\n", buf_ptr(libc_file), err_str(err));
        }
        return err;
    }

    SplitIterator it = memSplit(buf_to_slice(contents), str("\n"));
    for (;;) {
        Optional<Slice<uint8_t>> opt_line = SplitIterator_next(&it);
        if (!opt_line.is_some)
            break;

        if (opt_line.value.len == 0 || opt_line.value.ptr[0] == '#')
            continue;

        SplitIterator line_it = memSplit(opt_line.value, str("="));
        Slice<uint8_t> name;
        if (!SplitIterator_next(&line_it).unwrap(&name)) {
            if (verbose) {
                fprintf(stderr, "missing equal sign after field name\n");
            }
            return ErrorSemanticAnalyzeFail;
        }
        Slice<uint8_t> value = SplitIterator_rest(&line_it);
        bool match = false;
        match = match || zig_libc_match_key(name, value, found_keys, 0, &libc->include_dir);
        match = match || zig_libc_match_key(name, value, found_keys, 1, &libc->sys_include_dir);
        match = match || zig_libc_match_key(name, value, found_keys, 2, &libc->crt_dir);
        match = match || zig_libc_match_key(name, value, found_keys, 3, &libc->lib_dir);
        match = match || zig_libc_match_key(name, value, found_keys, 4, &libc->static_lib_dir);
        match = match || zig_libc_match_key(name, value, found_keys, 5, &libc->msvc_lib_dir);
        match = match || zig_libc_match_key(name, value, found_keys, 6, &libc->kernel32_lib_dir);
        match = match || zig_libc_match_key(name, value, found_keys, 7, &libc->dynamic_linker_path);
    }

    for (size_t i = 0; i < zig_libc_keys_len; i += 1) {
        if (!found_keys[i]) {
            if (verbose) {
                fprintf(stderr, "missing field: %s\n", zig_libc_keys[i]);
            }
            return ErrorSemanticAnalyzeFail;
        }
    }

    if (buf_len(&libc->include_dir) == 0) {
        if (verbose) {
            fprintf(stderr, "include_dir may not be empty\n");
        }
        return ErrorSemanticAnalyzeFail;
    }

    if (buf_len(&libc->sys_include_dir) == 0) {
        if (verbose) {
            fprintf(stderr, "sys_include_dir may not be empty\n");
        }
        return ErrorSemanticAnalyzeFail;
    }

    if (buf_len(&libc->crt_dir) == 0) {
        if (!target_is_darwin(target)) {
            if (verbose) {
                fprintf(stderr, "crt_dir may not be empty for %s\n", target_os_name(target->os));
            }
            return ErrorSemanticAnalyzeFail;
        }
    }

    if (buf_len(&libc->lib_dir) == 0) {
        if (!target_is_darwin(target) && target->os != OsWindows) {
            if (verbose) {
                fprintf(stderr, "lib_dir may not be empty for %s\n", target_os_name(target->os));
            }
            return ErrorSemanticAnalyzeFail;
        }
    }

    if (buf_len(&libc->static_lib_dir) == 0) {
        if (!target_is_darwin(target) && target->os != OsWindows) {
            if (verbose) {
                fprintf(stderr, "static_lib_dir may not be empty for %s\n", target_os_name(target->os));
            }
            return ErrorSemanticAnalyzeFail;
        }
    }

    if (buf_len(&libc->msvc_lib_dir) == 0) {
        if (target->os == OsWindows) {
            if (verbose) {
                fprintf(stderr, "msvc_lib_dir may not be empty for %s\n", target_os_name(target->os));
            }
            return ErrorSemanticAnalyzeFail;
        }
    }

    if (buf_len(&libc->kernel32_lib_dir) == 0) {
        if (target->os == OsWindows) {
            if (verbose) {
                fprintf(stderr, "kernel32_lib_dir may not be empty for %s\n", target_os_name(target->os));
            }
            return ErrorSemanticAnalyzeFail;
        }
    }

    if (buf_len(&libc->dynamic_linker_path) == 0) {
        if (!target_is_darwin(target) && target->os != OsWindows) {
            if (verbose) {
                fprintf(stderr, "dynamic_linker_path may not be empty for %s\n", target_os_name(target->os));
            }
            return ErrorSemanticAnalyzeFail;
        }
    }

    return ErrorNone;
}

#if defined(ZIG_OS_WINDOWS)
static Error zig_libc_find_native_include_dir_windows(ZigLibCInstallation *self, ZigWindowsSDK *sdk, bool verbose) {
    Error err;
    if ((err = os_get_win32_ucrt_include_path(sdk, &self->include_dir))) {
        if (verbose) {
            fprintf(stderr, "Unable to determine libc include path: %s\n", err_str(err));
        }
        return err;
    }
    return ErrorNone;
}
static Error zig_libc_find_crt_dir_windows(ZigLibCInstallation *self, ZigWindowsSDK *sdk, ZigTarget *target,
        bool verbose)
{
    Error err;
    if ((err = os_get_win32_ucrt_lib_path(sdk, &self->crt_dir, target->arch))) {
        if (verbose) {
            fprintf(stderr, "Unable to determine ucrt path: %s\n", err_str(err));
        }
        return err;
    }
    return ErrorNone;
}
static Error zig_libc_find_kernel32_lib_dir(ZigLibCInstallation *self, ZigWindowsSDK *sdk, ZigTarget *target,
        bool verbose)
{
    Error err;
    if ((err = os_get_win32_kern32_path(sdk, &self->kernel32_lib_dir, target->arch))) {
        if (verbose) {
            fprintf(stderr, "Unable to determine kernel32 path: %s\n", err_str(err));
        }
        return err;
    }
    return ErrorNone;
}
static Error zig_libc_find_native_msvc_lib_dir(ZigLibCInstallation *self, ZigWindowsSDK *sdk, bool verbose) {
    if (sdk->msvc_lib_dir_ptr == nullptr) {
        if (verbose) {
            fprintf(stderr, "Unable to determine vcruntime.lib path\n");
        }
        return ErrorFileNotFound;
    }
    buf_init_from_mem(&self->msvc_lib_dir, sdk->msvc_lib_dir_ptr, sdk->msvc_lib_dir_len);
    return ErrorNone;
}
static Error zig_libc_find_native_msvc_include_dir(ZigLibCInstallation *self, ZigWindowsSDK *sdk, bool verbose) {
    Error err;
    if (sdk->msvc_lib_dir_ptr == nullptr) {
        if (verbose) {
            fprintf(stderr, "Unable to determine vcruntime.h path\n");
        }
        return ErrorFileNotFound;
    }
    Buf search_path = BUF_INIT;
    buf_init_from_mem(&search_path, sdk->msvc_lib_dir_ptr, sdk->msvc_lib_dir_len);
    buf_append_str(&search_path, "\\..\\..\\include");

    Buf *vcruntime_path = buf_sprintf("%s\\vcruntime.h", buf_ptr(&search_path));
    bool exists;
    if ((err = os_file_exists(vcruntime_path, &exists))) {
        exists = false;
    }
    if (exists) {
        self->sys_include_dir = search_path;
        return ErrorNone;
    }

    if (verbose) {
        fprintf(stderr, "Unable to determine vcruntime.h path\n");
    }
    return ErrorFileNotFound;
}
#else
static Error zig_libc_find_native_include_dir_posix(ZigLibCInstallation *self, bool verbose) {
    const char *cc_exe = getenv("CC");
    cc_exe = (cc_exe == nullptr) ? "cc" : cc_exe;
    ZigList<const char *> args = {};
    args.append("-E");
    args.append("-Wp,-v");
    args.append("-xc");
    args.append("/dev/null");
    Termination term;
    Buf *out_stderr = buf_alloc();
    Buf *out_stdout = buf_alloc();
    Error err;
    if ((err = os_exec_process(cc_exe, args, &term, out_stderr, out_stdout))) {
        if (verbose) {
            fprintf(stderr, "unable to determine libc include path: executing '%s': %s\n", cc_exe, err_str(err));
        }
        return err;
    }
    if (term.how != TerminationIdClean || term.code != 0) {
        if (verbose) {
            fprintf(stderr, "unable to determine libc include path: executing '%s' failed\n", cc_exe);
        }
        return ErrorCCompileErrors;
    }
    char *prev_newline = buf_ptr(out_stderr);
    ZigList<const char *> search_paths = {};
    for (;;) {
        char *newline = strchr(prev_newline, '\n');
        if (newline == nullptr) {
            break;
        }
        *newline = 0;
        if (prev_newline[0] == ' ') {
            search_paths.append(prev_newline);
        }
        prev_newline = newline + 1;
    }
    if (search_paths.length == 0) {
        if (verbose) {
            fprintf(stderr, "unable to determine libc include path: '%s' cannot find libc headers\n", cc_exe);
        }
        return ErrorCCompileErrors;
    }
    for (size_t i = 0; i < search_paths.length; i += 1) {
        // search in reverse order
        const char *search_path = search_paths.items[search_paths.length - i - 1];
        // cut off spaces
        while (*search_path == ' ') {
            search_path += 1;
        }

        if (buf_len(&self->include_dir) == 0) {
            Buf *stdlib_path = buf_sprintf("%s/stdlib.h", search_path);
            bool exists;
            if ((err = os_file_exists(stdlib_path, &exists))) {
                exists = false;
            }
            if (exists) {
                buf_init_from_str(&self->include_dir, search_path);
            }
        }
        if (buf_len(&self->sys_include_dir) == 0) {
            Buf *stdlib_path = buf_sprintf("%s/sys/errno.h", search_path);
            bool exists;
            if ((err = os_file_exists(stdlib_path, &exists))) {
                exists = false;
            }
            if (exists) {
                buf_init_from_str(&self->sys_include_dir, search_path);
            }
        }
        if (buf_len(&self->include_dir) != 0 && buf_len(&self->sys_include_dir) != 0) {
            return ErrorNone;
        }
    }
    if (verbose) {
        if (buf_len(&self->include_dir) == 0) {
            fprintf(stderr, "unable to determine libc include path: stdlib.h not found in '%s' search paths\n", cc_exe);
        }
        if (buf_len(&self->sys_include_dir) == 0) {
            fprintf(stderr, "unable to determine libc include path: sys/errno.h not found in '%s' search paths\n", cc_exe);
        }
    }
    return ErrorFileNotFound;
}
#if !defined(ZIG_OS_DARWIN) && !defined(ZIG_OS_FREEBSD) && !defined(ZIG_OS_NETBSD)
static Error zig_libc_cc_print_file_name(const char *o_file, Buf *out, bool want_dirname, bool verbose) {
    const char *cc_exe = getenv("CC");
    cc_exe = (cc_exe == nullptr) ? "cc" : cc_exe;
    ZigList<const char *> args = {};
    args.append(buf_ptr(buf_sprintf("-print-file-name=%s", o_file)));
    Termination term;
    Buf *out_stderr = buf_alloc();
    Buf *out_stdout = buf_alloc();
    Error err;
    if ((err = os_exec_process(cc_exe, args, &term, out_stderr, out_stdout))) {
        if (verbose) {
            fprintf(stderr, "unable to determine libc include path: executing '%s': %s\n", cc_exe, err_str(err));
        }
        return err;
    }
    if (term.how != TerminationIdClean || term.code != 0) {
        if (verbose) {
            fprintf(stderr, "unable to determine libc include path: executing '%s' failed\n", cc_exe);
        }
        return ErrorCCompileErrors;
    }
    if (buf_ends_with_str(out_stdout, "\n")) {
        buf_resize(out_stdout, buf_len(out_stdout) - 1);
    }
    if (buf_len(out_stdout) == 0 || buf_eql_str(out_stdout, o_file)) {
        return ErrorCCompilerCannotFindFile;
    }
    if (want_dirname) {
        os_path_dirname(out_stdout, out);
    } else {
        buf_init_from_buf(out, out_stdout);
    }
    return ErrorNone;
}
static Error zig_libc_find_native_crt_dir_posix(ZigLibCInstallation *self, bool verbose) {
    return zig_libc_cc_print_file_name("crt1.o", &self->crt_dir, true, verbose);
}
static Error zig_libc_find_native_lib_dir_posix(ZigLibCInstallation *self, bool verbose) {
    return zig_libc_cc_print_file_name("libgcc_s.so", &self->lib_dir, true, verbose);
}

static Error zig_libc_find_native_static_lib_dir_posix(ZigLibCInstallation *self, bool verbose) {
    return zig_libc_cc_print_file_name("crtbegin.o", &self->static_lib_dir, true, verbose);
}
#endif

static Error zig_libc_find_native_dynamic_linker_posix(ZigLibCInstallation *self, bool verbose) {
#if defined(ZIG_OS_LINUX)
    Error err;
    static const char *dyn_tests[] = {
        "ld-linux-x86-64.so.2",
        "ld-musl-x86_64.so.1",
    };
    for (size_t i = 0; i < array_length(dyn_tests); i += 1) {
        const char *lib_name = dyn_tests[i];
        if ((err = zig_libc_cc_print_file_name(lib_name, &self->dynamic_linker_path, false, true))) {
            if (err != ErrorCCompilerCannotFindFile)
                return err;
            continue;
        }
        return ErrorNone;
    }
#endif
    ZigTarget native_target;
    get_native_target(&native_target);
    const char *dynamic_linker_path = target_dynamic_linker(&native_target);
    if (dynamic_linker_path != nullptr) {
        buf_init_from_str(&self->dynamic_linker_path, dynamic_linker_path);
    }
    return ErrorNone;
}
#endif

void zig_libc_render(ZigLibCInstallation *self, FILE *file) {
    fprintf(file,
        "# The directory that contains `stdlib.h`.\n"
        "# On POSIX, include directories be found with: `cc -E -Wp,-v -xc /dev/null`\n"
        "include_dir=%s\n"
        "# The system-specific include directory. May be the same as `include_dir`.\n"
        "# On Windows it's the directory that includes `vcruntime.h`.\n"
        "# On POSIX it's the directory that includes `sys/errno.h`.\n"
        "sys_include_dir=%s\n"
        "\n"
        "# The directory that contains `crt1.o`.\n"
        "# On POSIX, can be found with `cc -print-file-name=crt1.o`.\n"
        "# Not needed when targeting MacOS.\n"
        "crt_dir=%s\n"
        "\n"
        "# The directory that contains `libgcc_s.so`.\n"
        "# On POSIX, can be found with `cc -print-file-name=libgcc_s.so`.\n"
        "# Not needed when targeting MacOS or Windows.\n"
        "lib_dir=%s\n"
        "\n"
        "# The directory that contains `crtbegin.o`.\n"
        "# On POSIX, can be found with `cc -print-file-name=crtbegin.o`.\n"
        "# Not needed when targeting MacOS or Windows.\n"
        "static_lib_dir=%s\n"
        "\n"
        "# The directory that contains `vcruntime.lib`.\n"
        "# Only needed when targeting Windows.\n"
        "msvc_lib_dir=%s\n"
        "\n"
        "# The directory that contains `kernel32.lib`.\n"
        "# Only needed when targeting Windows.\n"
        "kernel32_lib_dir=%s\n"
        "\n"
        "# The full path to the dynamic linker, on the target system.\n"
        "# Not needed when targeting MacOS or Windows.\n"
        "dynamic_linker_path=%s\n"
        "\n"
    ,
        buf_ptr(&self->include_dir),
        buf_ptr(&self->sys_include_dir),
        buf_ptr(&self->crt_dir),
        buf_ptr(&self->lib_dir),
        buf_ptr(&self->static_lib_dir),
        buf_ptr(&self->msvc_lib_dir),
        buf_ptr(&self->kernel32_lib_dir),
        buf_ptr(&self->dynamic_linker_path)
    );
}

Error zig_libc_find_native(ZigLibCInstallation *self, bool verbose) {
    Error err;
    zig_libc_init_empty(self);
#if defined(ZIG_OS_WINDOWS)
    ZigTarget native_target;
    get_native_target(&native_target);
    ZigWindowsSDK *sdk;
    switch (zig_find_windows_sdk(&sdk)) {
        case ZigFindWindowsSdkErrorNone:
            if ((err = zig_libc_find_native_msvc_include_dir(self, sdk, verbose)))
                return err;
            if ((err = zig_libc_find_native_msvc_lib_dir(self, sdk, verbose)))
                return err;
            if ((err = zig_libc_find_kernel32_lib_dir(self, sdk, &native_target, verbose)))
                return err;
            if ((err = zig_libc_find_native_include_dir_windows(self, sdk, verbose)))
                return err;
            if ((err = zig_libc_find_crt_dir_windows(self, sdk, &native_target, verbose)))
                return err;
            return ErrorNone;
        case ZigFindWindowsSdkErrorOutOfMemory:
            return ErrorNoMem;
        case ZigFindWindowsSdkErrorNotFound:
            return ErrorFileNotFound;
        case ZigFindWindowsSdkErrorPathTooLong:
            return ErrorPathTooLong;
    }
    zig_unreachable();
#else
    if ((err = zig_libc_find_native_include_dir_posix(self, verbose)))
        return err;
#if defined(ZIG_OS_FREEBSD) || defined(ZIG_OS_NETBSD)
    buf_init_from_str(&self->crt_dir, "/usr/lib");
    buf_init_from_str(&self->lib_dir, "/usr/lib");
    buf_init_from_str(&self->static_lib_dir, "/usr/lib");
#elif !defined(ZIG_OS_DARWIN)
    if ((err = zig_libc_find_native_crt_dir_posix(self, verbose)))
        return err;
    if ((err = zig_libc_find_native_lib_dir_posix(self, verbose)))
        return err;
    if ((err = zig_libc_find_native_static_lib_dir_posix(self, verbose)))
        return err;
#endif
    if ((err = zig_libc_find_native_dynamic_linker_posix(self, verbose)))
        return err;
    return ErrorNone;
#endif
}
