#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

static const char *get_c_compiler(void) {
    const char *cc = getenv("CC");
    return (cc == NULL) ? "cc" : cc;
}

static void panic(const char *reason) {
    fprintf(stderr, "%s\n", reason);
    abort();
}

#if defined(__WIN32__)
#error TODO write the functionality for executing child process into this build script
#else

#include <unistd.h>
#include <errno.h>
#include <sys/wait.h>

static void run(char **argv) {
    pid_t pid = fork();
    if (pid == -1)
        panic("fork failed");
    if (pid == 0) {
        // child
        execvp(argv[0], argv);
        exit(1);
    }

    // parent

    int status;
    waitpid(pid, &status, 0);

    if (!WIFEXITED(status))
        panic("child process crashed");

    if (WEXITSTATUS(status) != 0)
        panic("child process failed");
}
#endif

static void print_and_run(const char **argv) {
    fprintf(stderr, "%s", argv[0]);
    for (const char **arg = argv + 1; *arg; arg += 1) {
        fprintf(stderr, " %s", *arg);
    }
    fprintf(stderr, "\n");
    run((char **)argv);
}

static const char *get_host_os(void) {
#if defined(__WIN32__)
    return "windows";
#elif defined(__APPLE__)
    return "macos";
#elif defined(__linux__)
    return "linux";
#else
#error TODO implement get_host_os in this build script for this target
#endif
}

static const char *get_host_arch(void) {
#if defined(__x86_64__ )
    return "x86_64";
#elif defined(__aarch64__)
    return "aarch64";
#else
#error TODO implement get_host_arch in this build script for this target
#endif
}

static const char *get_host_triple(void) {
    static char global_buffer[100];
    sprintf(global_buffer, "%s-%s", get_host_arch(), get_host_os());
    return global_buffer;
}

#if defined(__WIN32__)
#define HOST_PATHSEP '\\'
#else
#define HOST_PATHSEP '/'
#endif

static const char *get_parent_dir(const char *cwd) {
    // safe for our use case
    static char global_buffer[255];
    if (strlen(cwd) + 3 >= 255)
        panic("unable to get parent directory");

    sprintf(global_buffer, "%s%c..", cwd, HOST_PATHSEP);
    return global_buffer;
}

static const char *join(const char *dirpath, const char *path) {
    int size = strlen(dirpath) + strlen(path) + 1;
    if (size >= 4096)
        panic("unable to join dirpath and path");

    char *buffer = malloc(size);
    sprintf(buffer, "%s%c%s", dirpath, HOST_PATHSEP, path);

    // memory is leaked
    return buffer;
}

static const char *find_zig_root(void) {
    const char *cwd = ".";
    while (true) {
        FILE *f = fopen(join(cwd, "stage1/zig1.wasm"), "r");
        if (f != NULL) {
            fclose(f);
            return cwd;
        }

        cwd = get_parent_dir(cwd);
    }

    // unreachable
    return NULL;
}

static const char *mprintf(const char *format, ...) {
    va_list arg;
    int n;
    char *buf = malloc(255); // safe for our use case
    va_start(arg, format);
    n = vsprintf(buf, format, arg);
    va_end(arg);

    if (n < 0)
        panic("mprintf failed");

    // memory is leaked
    return buf;
}

int main(int argc, char **argv) {
    const char *cc = get_c_compiler();
    const char *host_triple = get_host_triple();
    const char *zig_root = find_zig_root();

    {
        const char *child_argv[] = {
            cc, "-o", "zig-wasm2c", join(zig_root, "stage1/wasm2c.c"), "-O2",
            "-std=c99", NULL,
        };
        print_and_run(child_argv);
    }
    {
        const char *child_argv[] = {
            "./zig-wasm2c", join(zig_root, "stage1/zig1.wasm"), "zig1.c", NULL
        };
        print_and_run(child_argv);
    }
    {
        const char *child_argv[] = {
            cc, "-o", "zig1", "zig1.c", join(zig_root, "stage1/wasi.c"), "-std=c99",
            "-Os", "-lm", NULL,
        };
        print_and_run(child_argv);
    }
    {
        FILE *f = fopen("config.zig", "wb");
        if (f == NULL)
            panic("unable to open config.zig for writing");

        const char *zig_version = "0.12.0-dev.bootstrap";

        int written = fprintf(f,
            "pub const have_llvm = false;\n"
            "pub const llvm_has_m68k = false;\n"
            "pub const llvm_has_csky = false;\n"
            "pub const llvm_has_arc = false;\n"
            "pub const llvm_has_xtensa = false;\n"
            "pub const version: [:0]const u8 = \"%s\";\n"
            "pub const semver = @import(\"std\").SemanticVersion.parse(version) catch unreachable;\n"
            "pub const enable_logging: bool = false;\n"
            "pub const enable_link_snapshots: bool = false;\n"
            "pub const enable_tracy = false;\n"
            "pub const value_tracing = false;\n"
            "pub const skip_non_native = false;\n"
            "pub const only_c = false;\n"
            "pub const force_gpa = false;\n"
            "pub const only_core_functionality = true;\n"
            "pub const only_reduce = false;\n"
        , zig_version);
        if (written < 100)
            panic("unable to write to config.zig file");
        if (fclose(f) != 0)
            panic("unable to finish writing to config.zig file");
    }

    {
        const char *child_argv[] = {
            "./zig1", join(zig_root, "lib"), "build-exe", join(zig_root, "src/main.zig"),
            "-ofmt=c", "-lc", "-OReleaseSmall",
            "--name", "zig2", "-femit-bin=zig2.c",
            "--mod", "build_options::config.zig",
            "--mod", mprintf("Builtins/Builtin.def::%s%csrc/stubs/aro_builtins.zig", zig_root, HOST_PATHSEP),
            "--mod", mprintf("Attribute/names.def::%s%csrc/stubs/aro_names.zig", zig_root, HOST_PATHSEP),
            "--mod", mprintf("aro:Builtins/Builtin.def,Attribute/names.def:%s%cdeps/aro/lib.zig", zig_root, HOST_PATHSEP),
            "--deps", "build_options,aro",
            "-target", host_triple,
            NULL,
        };
        print_and_run(child_argv);
    }

    {
        const char *child_argv[] = {
            "./zig1", join(zig_root, "lib"), "build-obj", join(zig_root, "lib/compiler_rt.zig"),
            "-ofmt=c", "-OReleaseSmall",
            "--name", "compiler_rt", "-femit-bin=compiler_rt.c",
            "--mod", "build_options::config.zig",
            "--deps", "build_options",
            "-target", host_triple,
            NULL,
        };
        print_and_run(child_argv);
    }

    {
        const char *child_argv[] = {
            cc, "-o", "zig2", "zig2.c", "compiler_rt.c",
            "-std=c99", "-O2", "-fno-stack-protector",
            "-I", join(zig_root, "stage1"),
#if defined(__APPLE__)
            "-Wl,-stack_size,0x10000000",
#else
            "-Wl,-z,stack-size=0x10000000",
#endif
#if defined(__GNUC__)
            "-pthread",
#endif
            NULL,
        };
        print_and_run(child_argv);
    }
}
