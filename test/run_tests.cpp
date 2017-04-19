/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "list.hpp"
#include "buffer.hpp"
#include "os.hpp"
#include "error.hpp"
#include "config.h"

#include <stdio.h>
#include <stdarg.h>

enum TestSpecial {
    TestSpecialNone,
    TestSpecialLinkStep,
};

struct TestSourceFile {
    const char *relative_path;
    const char *source_code;
};

enum AllowWarnings {
    AllowWarningsNo,
    AllowWarningsYes,
};

struct TestCase {
    const char *case_name;
    const char *output;
    ZigList<TestSourceFile> source_files;
    ZigList<const char *> compile_errors;
    ZigList<const char *> compiler_args;
    ZigList<const char *> linker_args;
    ZigList<const char *> program_args;
    bool is_parseh;
    TestSpecial special;
    bool is_release_mode;
    AllowWarnings allow_warnings;
};

static ZigList<TestCase*> test_cases = {0};
static const char *tmp_source_path = ".tmp_source.zig";
static const char *tmp_h_path = ".tmp_header.h";

#if defined(_WIN32)
static const char *tmp_exe_path = "./.tmp_exe.exe";
static const char *zig_exe = "./zig.exe";
#define NL "\r\n"
#else
static const char *tmp_exe_path = "./.tmp_exe";
static const char *zig_exe = "./zig";
#define NL "\n"
#endif

static TestCase *add_parseh_case(const char *case_name, AllowWarnings allow_warnings,
    const char *source, size_t count, ...)
{
    va_list ap;
    va_start(ap, count);

    TestCase *test_case = allocate<TestCase>(1);
    test_case->case_name = case_name;
    test_case->is_parseh = true;
    test_case->allow_warnings = allow_warnings;

    test_case->source_files.resize(1);
    test_case->source_files.at(0).relative_path = tmp_h_path;
    test_case->source_files.at(0).source_code = source;

    for (size_t i = 0; i < count; i += 1) {
        const char *arg = va_arg(ap, const char *);
        test_case->compile_errors.append(arg);
    }

    test_case->compiler_args.append("parseh");
    test_case->compiler_args.append(tmp_h_path);
    //test_case->compiler_args.append("--verbose");

    test_cases.append(test_case);

    va_end(ap);
    return test_case;
}

//////////////////////////////////////////////////////////////////////////////

static void add_parseh_test_cases(void) {
    add_parseh_case("simple data types", AllowWarningsYes, R"SOURCE(
#include <stdint.h>
int foo(char a, unsigned char b, signed char c);
int foo(char a, unsigned char b, signed char c); // test a duplicate prototype
void bar(uint8_t a, uint16_t b, uint32_t c, uint64_t d);
void baz(int8_t a, int16_t b, int32_t c, int64_t d);
    )SOURCE", 3,
            "pub extern fn foo(a: u8, b: u8, c: i8) -> c_int;",
            "pub extern fn bar(a: u8, b: u16, c: u32, d: u64);",
            "pub extern fn baz(a: i8, b: i16, c: i32, d: i64);");

    add_parseh_case("noreturn attribute", AllowWarningsNo, R"SOURCE(
void foo(void) __attribute__((noreturn));
    )SOURCE", 1, R"OUTPUT(pub extern fn foo() -> noreturn;)OUTPUT");

    add_parseh_case("enums", AllowWarningsNo, R"SOURCE(
enum Foo {
    FooA,
    FooB,
    Foo1,
};
    )SOURCE", 5, R"(pub const enum_Foo = extern enum {
    A,
    B,
    @"1",
};)",
            R"(pub const FooA = 0;)",
            R"(pub const FooB = 1;)",
            R"(pub const Foo1 = 2;)",
            R"(pub const Foo = enum_Foo;)");

    add_parseh_case("restrict -> noalias", AllowWarningsNo, R"SOURCE(
void foo(void *restrict bar, void *restrict);
    )SOURCE", 1, R"OUTPUT(pub extern fn foo(noalias bar: ?&c_void, noalias arg1: ?&c_void);)OUTPUT");

    add_parseh_case("simple struct", AllowWarningsNo, R"SOURCE(
struct Foo {
    int x;
    char *y;
};
    )SOURCE", 2,
            R"OUTPUT(const struct_Foo = extern struct {
    x: c_int,
    y: ?&u8,
};)OUTPUT", R"OUTPUT(pub const Foo = struct_Foo;)OUTPUT");

    add_parseh_case("qualified struct and enum", AllowWarningsNo, R"SOURCE(
struct Foo {
    int x;
    int y;
};
enum Bar {
    BarA,
    BarB,
};
void func(struct Foo *a, enum Bar **b);
    )SOURCE", 7, R"OUTPUT(pub const struct_Foo = extern struct {
    x: c_int,
    y: c_int,
};)OUTPUT", R"OUTPUT(pub const enum_Bar = extern enum {
    A,
    B,
};)OUTPUT",
            R"OUTPUT(pub const BarA = 0;)OUTPUT",
            R"OUTPUT(pub const BarB = 1;)OUTPUT",
            "pub extern fn func(a: ?&struct_Foo, b: ?&?&enum_Bar);",
    R"OUTPUT(pub const Foo = struct_Foo;)OUTPUT",
    R"OUTPUT(pub const Bar = enum_Bar;)OUTPUT");

    add_parseh_case("constant size array", AllowWarningsNo, R"SOURCE(
void func(int array[20]);
    )SOURCE", 1, "pub extern fn func(array: ?&c_int);");


    add_parseh_case("self referential struct with function pointer",
        AllowWarningsNo, R"SOURCE(
struct Foo {
    void (*derp)(struct Foo *foo);
};
    )SOURCE", 2, R"OUTPUT(pub const struct_Foo = extern struct {
    derp: ?extern fn(?&struct_Foo),
};)OUTPUT", R"OUTPUT(pub const Foo = struct_Foo;)OUTPUT");


    add_parseh_case("struct prototype used in func", AllowWarningsNo, R"SOURCE(
struct Foo;
struct Foo *some_func(struct Foo *foo, int x);
    )SOURCE", 3, R"OUTPUT(pub const struct_Foo = @OpaqueType();)OUTPUT",
        R"OUTPUT(pub extern fn some_func(foo: ?&struct_Foo, x: c_int) -> ?&struct_Foo;)OUTPUT",
        R"OUTPUT(pub const Foo = struct_Foo;)OUTPUT");


    add_parseh_case("#define a char literal", AllowWarningsNo, R"SOURCE(
#define A_CHAR  'a'
    )SOURCE", 1, R"OUTPUT(pub const A_CHAR = 97;)OUTPUT");


    add_parseh_case("#define an unsigned integer literal", AllowWarningsNo,
        R"SOURCE(
#define CHANNEL_COUNT 24
    )SOURCE", 1, R"OUTPUT(pub const CHANNEL_COUNT = 24;)OUTPUT");


    add_parseh_case("#define referencing another #define", AllowWarningsNo,
        R"SOURCE(
#define THING2 THING1
#define THING1 1234
    )SOURCE", 2,
            "pub const THING1 = 1234;",
            "pub const THING2 = THING1;");


    add_parseh_case("variables", AllowWarningsNo, R"SOURCE(
extern int extern_var;
static const int int_var = 13;
    )SOURCE", 2,
            "pub extern var extern_var: c_int;",
            "pub const int_var: c_int = 13;");


    add_parseh_case("circular struct definitions", AllowWarningsNo, R"SOURCE(
struct Bar;

struct Foo {
    struct Bar *next;
};

struct Bar {
    struct Foo *next;
};
    )SOURCE", 2,
            R"SOURCE(pub const struct_Bar = extern struct {
    next: ?&struct_Foo,
};)SOURCE",
            R"SOURCE(pub const struct_Foo = extern struct {
    next: ?&struct_Bar,
};)SOURCE");


    add_parseh_case("typedef void", AllowWarningsNo, R"SOURCE(
typedef void Foo;
Foo fun(Foo *a);
    )SOURCE", 2,
            "pub const Foo = c_void;",
            "pub extern fn fun(a: ?&c_void);");

    add_parseh_case("generate inline func for #define global extern fn", AllowWarningsNo,
        R"SOURCE(
extern void (*fn_ptr)(void);
#define foo fn_ptr

extern char (*fn_ptr2)(int, float);
#define bar fn_ptr2
    )SOURCE", 4,
            "pub extern var fn_ptr: ?extern fn();",
            "pub fn foo();",
            "pub extern var fn_ptr2: ?extern fn(c_int, f32) -> u8;",
            "pub fn bar(arg0: c_int, arg1: f32) -> u8;");


    add_parseh_case("#define string", AllowWarningsNo, R"SOURCE(
#define  foo  "a string"
    )SOURCE", 1, "pub const foo: &const u8 = &(c str lit);");

    add_parseh_case("__cdecl doesn't mess up function pointers", AllowWarningsNo, R"SOURCE(
void foo(void (__cdecl *fn_ptr)(void));
    )SOURCE", 1, "pub extern fn foo(fn_ptr: ?extern fn());");

    add_parseh_case("comment after integer literal", AllowWarningsNo, R"SOURCE(
#define SDL_INIT_VIDEO 0x00000020  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    )SOURCE", 1, "pub const SDL_INIT_VIDEO = 32;");

    add_parseh_case("zig keywords in C code", AllowWarningsNo, R"SOURCE(
struct comptime {
    int defer;
};
    )SOURCE", 2, R"(pub const struct_comptime = extern struct {
    @"defer": c_int,
};)", R"(pub const @"comptime" = struct_comptime;)");

    add_parseh_case("macro defines string literal with octal", AllowWarningsNo, R"SOURCE(
#define FOO "aoeu\023 derp"
#define FOO2 "aoeu\0234 derp"
#define FOO_CHAR '\077'
    )SOURCE", 3,
            R"(pub const FOO: &const u8 = &(c str lit);)",
            R"(pub const FOO2: &const u8 = &(c str lit);)",
            R"(pub const FOO_CHAR = 63;)");
}

static void print_compiler_invocation(TestCase *test_case) {
    printf("%s", zig_exe);
    for (size_t i = 0; i < test_case->compiler_args.length; i += 1) {
        printf(" %s", test_case->compiler_args.at(i));
    }
    printf("\n");
}

static void print_linker_invocation(TestCase *test_case) {
    printf("%s", zig_exe);
    for (size_t i = 0; i < test_case->linker_args.length; i += 1) {
        printf(" %s", test_case->linker_args.at(i));
    }
    printf("\n");
}


static void print_exe_invocation(TestCase *test_case) {
    printf("%s", tmp_exe_path);
    for (size_t i = 0; i < test_case->program_args.length; i += 1) {
        printf(" %s", test_case->program_args.at(i));
    }
    printf("\n");
}

static void run_test(TestCase *test_case) {
    for (size_t i = 0; i < test_case->source_files.length; i += 1) {
        TestSourceFile *test_source = &test_case->source_files.at(i);
        os_write_file(
                buf_create_from_str(test_source->relative_path),
                buf_create_from_str(test_source->source_code));
    }

    Buf zig_stderr = BUF_INIT;
    Buf zig_stdout = BUF_INIT;
    int err;
    Termination term;
    if ((err = os_exec_process(zig_exe, test_case->compiler_args, &term, &zig_stderr, &zig_stdout))) {
        fprintf(stderr, "Unable to exec %s: %s\n", zig_exe, err_str(err));
    }

    if (!test_case->is_parseh && test_case->compile_errors.length) {
        if (term.how != TerminationIdClean || term.code != 0) {
            for (size_t i = 0; i < test_case->compile_errors.length; i += 1) {
                const char *err_text = test_case->compile_errors.at(i);
                if (!strstr(buf_ptr(&zig_stderr), err_text)) {
                    printf("\n");
                    printf("========= Expected this compile error: =========\n");
                    printf("%s\n", err_text);
                    printf("================================================\n");
                    print_compiler_invocation(test_case);
                    printf("%s\n", buf_ptr(&zig_stderr));
                    exit(1);
                }
            }
            return; // success
        } else {
            printf("\nCompile failed with return code 0 (Expected failure):\n");
            print_compiler_invocation(test_case);
            printf("%s\n", buf_ptr(&zig_stderr));
            exit(1);
        }
    }

    if (term.how != TerminationIdClean || term.code != 0) {
        printf("\nCompile failed:\n");
        print_compiler_invocation(test_case);
        printf("%s\n", buf_ptr(&zig_stderr));
        exit(1);
    }

    if (test_case->is_parseh) {
        if (buf_len(&zig_stderr) > 0) {
            printf("\nparseh emitted warnings:\n");
            printf("------------------------------\n");
            print_compiler_invocation(test_case);
            printf("%s\n", buf_ptr(&zig_stderr));
            printf("------------------------------\n");
            if (test_case->allow_warnings == AllowWarningsNo) {
                exit(1);
            }
        }

        for (size_t i = 0; i < test_case->compile_errors.length; i += 1) {
            const char *output = test_case->compile_errors.at(i);

            if (!strstr(buf_ptr(&zig_stdout), output)) {
                printf("\n");
                printf("========= Expected this output: =========\n");
                printf("%s\n", output);
                printf("================================================\n");
                print_compiler_invocation(test_case);
                printf("%s\n", buf_ptr(&zig_stdout));
                exit(1);
            }
        }
    } else {
        if (test_case->special == TestSpecialLinkStep) {
            Buf link_stderr = BUF_INIT;
            Buf link_stdout = BUF_INIT;
            int err;
            Termination term;
            if ((err = os_exec_process(zig_exe, test_case->linker_args, &term, &link_stderr, &link_stdout))) {
                fprintf(stderr, "Unable to exec %s: %s\n", zig_exe, err_str(err));
            }

            if (term.how != TerminationIdClean || term.code != 0) {
                printf("\nLink failed:\n");
                print_linker_invocation(test_case);
                printf("%s\n", buf_ptr(&zig_stderr));
                exit(1);
            }
        }

        Buf program_stderr = BUF_INIT;
        Buf program_stdout = BUF_INIT;
        os_exec_process(tmp_exe_path, test_case->program_args, &term, &program_stderr, &program_stdout);

        if (term.how != TerminationIdClean || term.code != 0) {
            printf("\nProgram exited with error\n");
            print_compiler_invocation(test_case);
            print_exe_invocation(test_case);
            printf("%s\n", buf_ptr(&program_stderr));
            exit(1);
        }

        if (test_case->output != nullptr && !buf_eql_str(&program_stdout, test_case->output)) {
            printf("\n");
            print_compiler_invocation(test_case);
            print_exe_invocation(test_case);
            printf("==== Test failed. Expected output: ====\n");
            printf("%s\n", test_case->output);
            printf("========= Actual output: ==============\n");
            printf("%s\n", buf_ptr(&program_stdout));
            printf("=======================================\n");
            exit(1);
        }
    }

    for (size_t i = 0; i < test_case->source_files.length; i += 1) {
        TestSourceFile *test_source = &test_case->source_files.at(i);
        remove(test_source->relative_path);
    }
}

static void run_all_tests(const char *grep_text) {
    for (size_t i = 0; i < test_cases.length; i += 1) {
        TestCase *test_case = test_cases.at(i);
        if (grep_text != nullptr && strstr(test_case->case_name, grep_text) == nullptr) {
            continue;
        }

        printf("Test %zu/%zu %s...", i + 1, test_cases.length, test_case->case_name);
        fflush(stdout);
        run_test(test_case);
        printf("OK\n");
    }
    printf("%zu tests passed.\n", test_cases.length);
}

static void cleanup(void) {
    remove(tmp_source_path);
    remove(tmp_h_path);
    remove(tmp_exe_path);
}

static int usage(const char *arg0) {
    fprintf(stderr, "Usage: %s [--grep text]\n", arg0);
    return 1;
}

int main(int argc, char **argv) {
    const char *grep_text = nullptr;
    for (int i = 1; i < argc; i += 1) {
        const char *arg = argv[i];
        if (i + 1 >= argc) {
            return usage(argv[0]);
        } else {
            i += 1;
            if (strcmp(arg, "--grep") == 0) {
                grep_text = argv[i];
            } else {
                return usage(argv[0]);
            }
        }
    }
    add_parseh_test_cases();
    run_all_tests(grep_text);
    cleanup();
}
