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

int main(int argc, char **argv) {
    const char *cc = get_c_compiler();
    const char *host_triple = get_host_triple();

    {
        const char *child_argv[] = {
            cc, "-o", "zig-wasm2c", "stage1/wasm2c.c", "-O2", "-std=c99", NULL,
        };
        print_and_run(child_argv);
    }
    {
        const char *child_argv[] = {
            "./zig-wasm2c", "stage1/zig1.wasm", "zig1.c", NULL,
        };
        print_and_run(child_argv);
    }
    {
        const char *child_argv[] = {
            cc, "-o", "zig1", "zig1.c", "stage1/wasi.c", "-std=c99", "-Os", "-lm", NULL,
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
            "./zig1", "lib", "build-exe", "src/main.zig",
            "-ofmt=c", "-lc", "-OReleaseSmall",
            "--name", "zig2", "-femit-bin=zig2.c",
            "--mod", "build_options::config.zig",
            "--mod", "aro_options::src/stubs/aro_options.zig",
            "--mod", "Builtins/Builtin.def::src/stubs/aro_builtins.zig",
            "--mod", "Attribute/names.def::src/stubs/aro_names.zig",
            "--mod", "Diagnostics/messages.def::src/stubs/aro_messages.zig",
            "--mod", "aro_backend:build_options=aro_options:deps/aro/backend.zig",
            "--mod", "aro:Builtins/Builtin.def,Attribute/names.def,Diagnostics/messages.def,build_options=aro_options,backend=aro_backend:deps/aro/aro.zig",
            "--deps", "build_options,aro",
            "-target", host_triple,
            NULL,
        };
        print_and_run(child_argv);
    }

    {
        const char *child_argv[] = {
            "./zig1", "lib", "build-obj", "lib/compiler_rt.zig",
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
            "-Istage1",
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
