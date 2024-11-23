// Bootstrap the self-hosted Zig compiler using a C compiler.
//
// Some ways to run this program:
//
// $ tcc -run bootstrap.c
// $ cc bootstrap.c -o bootstrap && ./bootstrap
// $ clang bootstrap.c -o bootstrap && CC=clang ./bootstrap
// $ cl.exe bootstrap.c /link /out:bootstrap.exe && .\bootstrap.exe
//
// This program will try its best to invoke the same C compiler that it was
// built with. To override this behavior, set the CC environment variable.
//
// The following environment variables can be set to override the target
// triple detection for the system this program runs on (the host):
//
// * ZIG_HOST_TARGET_ARCH
// * ZIG_HOST_TARGET_OS
// * ZIG_HOST_TARGET_ABI
// * ZIG_HOST_TARGET_TRIPLE (overrides all of the above)

#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <process.h>
#else
#include <errno.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

static const char *get_c_compiler(void) {
    const char *cc = getenv("CC");
    if (cc != NULL) return cc;
#if defined(_MSC_VER)
    return "cl";
#else
    return "cc";
#endif
}

static void panic(const char *format, ...) {
    fputs("panic: ", stderr);
    va_list vargs;
    va_start(vargs, format);
    vfprintf(stderr, format, vargs);
    va_end(vargs);
    fputs("\n", stderr);
    abort();
}

static void error(const char *format, ...) {
    fputs("error: ", stderr);
    va_list vargs;
    va_start(vargs, format);
    vfprintf(stderr, format, vargs);
    va_end(vargs);
    fprintf(stderr, " = %d (%s)\n", errno, strerror(errno));
    exit(1);
}

static void fatal(const char *format, ...) {
    fputs("fatal: ", stderr);
    va_list vargs;
    va_start(vargs, format);
    vfprintf(stderr, format, vargs);
    va_end(vargs);
    fputs("\n", stderr);
    exit(1);
}

static void usage(const char *message) {
    fprintf(stderr, "%s\n", message);
    exit(2);
}

static void run(const char *const *argv) {
#if defined(_WIN32)
    intptr_t status = _spawnvp(_P_WAIT, argv[0], argv);
    switch (status) {
        case -1: error("_spawnvp(_P_WAIT, %s, ...)", argv[0]); break;
        case 0: break;
        default: fatal("child process failed: %d", status); break;
    }
#else
    pid_t pid = fork();
    switch (pid) {
        case -1: error("fork()"); break;
        case 0: {
            // child
            execvp(argv[0], (char *const *)argv);
            panic("execve(%s, ...) returned", argv[0]);

            break;
        }
        default: {
            // parent
            int wstatus;
            if (waitpid(pid, &wstatus, 0) == -1) error("waitpid(%d, ..., 0)", pid);
            if (!WIFEXITED(wstatus)) fatal("child process crashed");

            int status = WEXITSTATUS(wstatus);
            if (status != 0) fatal("child process failed: %d", status);

            break;
        }
    }
#endif
}

static void print_and_run(const char *const *argv) {
    fprintf(stderr, "%s", argv[0]);
    for (const char *const *arg = argv + 1; *arg; arg++) {
        fprintf(stderr, " %s", *arg);
    }
    fprintf(stderr, "\n");
    run(argv);
}

static const char *get_host_os(void) {
    const char *host_os = getenv("ZIG_HOST_TARGET_OS");
    if (host_os != NULL) return host_os;
#if defined(_WIN32)
    return "windows";
#elif defined(__APPLE__)
    return "macos";
#elif defined(__linux__)
    return "linux";
#elif defined(__FreeBSD__)
    return "freebsd";
#elif defined(__HAIKU__)
    return "haiku";
#else
    usage("unknown host OS; specify with environment variable ZIG_HOST_TARGET_OS");
#endif
}

static const char *get_host_arch(void) {
    const char *host_arch = getenv("ZIG_HOST_TARGET_ARCH");
    if (host_arch != NULL) return host_arch;
#if defined(__x86_64__) || defined(_M_X64)
    return "x86_64";
#elif defined(__aarch64__) || defined(_M_ARM64)
    return "aarch64";
#else
    usage("unknown host architecture; specify with environment variable ZIG_HOST_TARGET_ARCH");
#endif
}

static const char *get_host_abi(void) {
    const char *host_abi = getenv("ZIG_HOST_TARGET_ABI");
    if (host_abi != NULL) return host_abi;
#if defined(_MSC_VER)
    return "-msvc";
#else
    return "";
#endif
}

static const char *get_host_triple(void) {
    const char *host_triple = getenv("ZIG_HOST_TARGET_TRIPLE");
    if (host_triple != NULL) return host_triple;
    static char global_buffer[100];
    sprintf(global_buffer, "%s-%s%s", get_host_arch(), get_host_os(), get_host_abi());
    return global_buffer;
}

int main(int argc, char **argv) {
    const char *cc = get_c_compiler();
    const char *host_triple = get_host_triple();

    print_and_run((const char *[]) {
        cc,
#if defined(_MSC_VER)
        "/nologo",
        "stage1/wasm2c.c",
        "/O2",
        "/link",
        "/OUT:zig-wasm2c.exe",
#else
        "stage1/wasm2c.c",
        "-std=c99",
        "-O2",
        "-o", "zig-wasm2c",
#endif
        NULL,
    });

    print_and_run((const char *[]) {
        "./zig-wasm2c", "stage1/zig1.wasm", "zig1.c",
        NULL,
    });

    print_and_run((const char *[]) {
        cc,
#if defined(_MSC_VER)
        "/nologo",
        "zig1.c",
        "stage1/wasi.c",
        "/O1",
        "/link",
        "/STACK:0x4000000,0x4000000",
        "/OUT:zig1.exe",
#else
        "zig1.c",
        "stage1/wasi.c",
        "-std=c99",
        "-Os",
        "-lm",
#if defined(__APPLE__)
        "-Wl,-stack_size,0x1000000",
#else
        "-Wl,-z,stack-size=0x1000000",
#endif
        "-o", "zig1",
#endif
        NULL,
    });

    {
        FILE *f = fopen("config.zig", "wb");
        if (f == NULL)
            error("fopen(\"config.zig\", \"wb\")");

        const char *zig_version = "0.14.0-dev.bootstrap";

        int written = fprintf(f,
            "pub const have_llvm = false;\n"
            "pub const llvm_has_m68k = false;\n"
            "pub const llvm_has_csky = false;\n"
            "pub const llvm_has_arc = false;\n"
            "pub const llvm_has_xtensa = false;\n"
            "pub const version: [:0]const u8 = \"%s\";\n"
            "pub const semver = @import(\"std\").SemanticVersion.parse(version) catch unreachable;\n"
            "pub const enable_debug_extensions = false;\n"
            "pub const enable_logging = false;\n"
            "pub const enable_link_snapshots = false;\n"
            "pub const enable_tracy = false;\n"
            "pub const value_tracing = false;\n"
            "pub const skip_non_native = false;\n"
            "pub const force_gpa = false;\n"
            "pub const dev = .core;\n"
        , zig_version);
        if (written < 100)
            panic("unable to write to config.zig file");
        if (fclose(f) != 0)
            error("fclose(\"config.zig\")");
    }

    print_and_run((const char *[]) {
        "./zig1", "lib", "build-exe",
        "-OReleaseSmall",
        "-target", host_triple,
        "-lc",
        "-ofmt=c",
        "-femit-bin=zig2.c",
        "--name", "zig2",
        "--dep", "build_options",
        "--dep", "aro",
        "-Mroot=src/main.zig",
        "-Mbuild_options=config.zig",
        "-Maro=lib/compiler/aro/aro.zig",
        NULL,
    });

    print_and_run((const char *[]) {
        "./zig1", "lib", "build-obj",
        "-OReleaseSmall",
        "-target", host_triple,
        "-ofmt=c",
        "-femit-bin=compiler_rt.c",
        "--name", "compiler_rt",
        "-Mroot=lib/compiler_rt.zig",
        NULL,
    });

    print_and_run((const char *[]) {
        cc,
#if defined(_MSC_VER)
        "/nologo",
        "zig2.c",
        "compiler_rt.c",
        "/Istage1",
        "/O2",
        "/GS-",
        "/link",
        "/STACK:0x10000000,0x10000000",
        "/OUT:zig2.exe",
#else
        "zig2.c",
        "compiler_rt.c",
        "-Istage1",
        "-std=c99",
#if defined(__GNUC__)
        "-pthread",
#endif
        "-O2",
        "-fno-stack-protector",
#if defined(__APPLE__)
        "-Wl,-stack_size,0x10000000",
#else
        "-Wl,-z,stack-size=0x10000000",
#endif
        "-o", "zig2",
#endif
        NULL,
    });
}
