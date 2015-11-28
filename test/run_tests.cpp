/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "list.hpp"
#include "buffer.hpp"
#include "os.hpp"

#include <stdio.h>
#include <stdarg.h>

struct TestSourceFile {
    const char *relative_path;
    const char *text;
};

struct TestCase {
    const char *case_name;
    const char *output;
    const char *source;
    ZigList<const char *> compile_errors;
    ZigList<const char *> compiler_args;
    ZigList<const char *> program_args;
};

static ZigList<TestCase*> test_cases = {0};
static const char *tmp_source_path = ".tmp_source.zig";
static const char *tmp_exe_path = "./.tmp_exe";
static const char *zig_exe = "./zig";

static void add_simple_case(const char *case_name, const char *source, const char *output) {
    TestCase *test_case = allocate<TestCase>(1);
    test_case->case_name = case_name;
    test_case->output = output;
    test_case->source = source;

    test_case->compiler_args.append("build");
    test_case->compiler_args.append(tmp_source_path);
    test_case->compiler_args.append("--output");
    test_case->compiler_args.append(tmp_exe_path);
    test_case->compiler_args.append("--release");
    test_case->compiler_args.append("--strip");

    test_cases.append(test_case);
}

static void add_compile_fail_case(const char *case_name, const char *source, int count, ...) {
    va_list ap;
    va_start(ap, count);

    TestCase *test_case = allocate<TestCase>(1);
    test_case->case_name = case_name;
    test_case->source = source;

    for (int i = 0; i < count; i += 1) {
        const char *arg = va_arg(ap, const char *);
        test_case->compile_errors.append(arg);
    }

    test_case->compiler_args.append("build");
    test_case->compiler_args.append(tmp_source_path);
    test_case->compiler_args.append("--output");
    test_case->compiler_args.append(tmp_exe_path);
    test_case->compiler_args.append("--release");
    test_case->compiler_args.append("--strip");

    test_cases.append(test_case);

    va_end(ap);
}

static void add_compiling_test_cases(void) {
    add_simple_case("hello world with libc", R"SOURCE(
        #link("c")
        extern {
            fn puts(s: *mut u8) -> i32;
            fn exit(code: i32) -> unreachable;
        }

        export fn _start() -> unreachable {
            puts("Hello, world!");
            exit(0);
        }
    )SOURCE", "Hello, world!\n");

    add_simple_case("function call", R"SOURCE(
        #link("c")
        extern {
            fn puts(s: *mut u8) -> i32;
            fn exit(code: i32) -> unreachable;
        }

        fn empty_function_1() {}
        fn empty_function_2() { return; }

        export fn _start() -> unreachable {
            empty_function_1();
            empty_function_2();
            this_is_a_function();
        }

        fn this_is_a_function() -> unreachable {
            puts("OK");
            exit(0);
        }
    )SOURCE", "OK\n");

    add_simple_case("comments", R"SOURCE(
        #link("c")
        extern {
            fn puts(s: *mut u8) -> i32;
            fn exit(code: i32) -> unreachable;
        }

        /**
         * multi line doc comment
         */
        fn another_function() {}

        /// this is a documentation comment
        /// doc comment line 2
        export fn _start() -> unreachable {
            puts(/* mid-line comment /* nested */ */ "OK");
            exit(0);
        }
    )SOURCE", "OK\n");
}

static void add_compile_failure_test_cases(void) {
    add_compile_fail_case("multiple function definitions", R"SOURCE(
fn a() {}
fn a() {}
    )SOURCE", 1, "Line 3, column 1: redefinition of 'a'");

    add_compile_fail_case("bad directive", R"SOURCE(
#bogus1("")
extern {
    fn b();
}
#bogus2("")
fn a() {}
    )SOURCE", 2, "Line 2, column 1: invalid directive: 'bogus1'",
                 "Line 6, column 1: invalid directive: 'bogus2'");

    add_compile_fail_case("unreachable with return", R"SOURCE(
fn a() -> unreachable {return;}
    )SOURCE", 1, "Line 2, column 24: return statement in function with unreachable return type");

    add_compile_fail_case("control reaches end of non-void function", R"SOURCE(
fn a() -> i32 {}
    )SOURCE", 1, "Line 2, column 1: control reaches end of non-void function");

    add_compile_fail_case("undefined function call", R"SOURCE(
fn a() {
    b();
}
    )SOURCE", 1, "Line 3, column 5: undefined function: 'b'");

    add_compile_fail_case("wrong number of arguments", R"SOURCE(
fn a() {
    b(1);
}
fn b(a: i32, b: i32, c: i32) { }
    )SOURCE", 1, "Line 3, column 5: wrong number of arguments. Expected 3, got 1.");

    add_compile_fail_case("invalid type", R"SOURCE(
fn a() -> bogus {}
    )SOURCE", 1, "Line 2, column 11: invalid type name: 'bogus'");

    add_compile_fail_case("pointer to unreachable", R"SOURCE(
fn a() -> *mut unreachable {}
    )SOURCE", 1, "Line 2, column 11: pointer to unreachable not allowed");

    add_compile_fail_case("unreachable code", R"SOURCE(
fn a() {
    return;
    b();
}

fn b() {}
    )SOURCE", 1, "Line 4, column 5: unreachable code");
}

static void print_compiler_invokation(TestCase *test_case, Buf *zig_stderr) {
    printf("%s", zig_exe);
    for (int i = 0; i < test_case->compiler_args.length; i += 1) {
        printf(" %s", test_case->compiler_args.at(i));
    }
    printf("\n");
    printf("%s\n", buf_ptr(zig_stderr));
}

static void run_test(TestCase *test_case) {
    os_write_file(buf_create_from_str(tmp_source_path), buf_create_from_str(test_case->source));

    Buf zig_stderr = BUF_INIT;
    Buf zig_stdout = BUF_INIT;
    int return_code;
    os_exec_process(zig_exe, test_case->compiler_args, &return_code, &zig_stderr, &zig_stdout);

    if (test_case->compile_errors.length) {
        if (return_code) {
            for (int i = 0; i < test_case->compile_errors.length; i += 1) {
                const char *err_text = test_case->compile_errors.at(i);
                if (!strstr(buf_ptr(&zig_stderr), err_text)) {
                    printf("\n");
                    printf("========= Expected this compile error: =========\n");
                    printf("%s\n", err_text);
                    printf("================================================\n");
                    print_compiler_invokation(test_case, &zig_stderr);
                    exit(1);
                }
            }
            return; // success
        } else {
            printf("\nCompile failed with return code 0 (Expected failure):\n");
            print_compiler_invokation(test_case, &zig_stderr);
            exit(1);
        }
    }

    if (return_code != 0) {
        printf("\nCompile failed with return code %d:\n", return_code);
        print_compiler_invokation(test_case, &zig_stderr);
        exit(1);
    }

    Buf program_stderr = BUF_INIT;
    Buf program_stdout = BUF_INIT;
    os_exec_process(tmp_exe_path, test_case->program_args, &return_code, &program_stderr, &program_stdout);

    if (return_code != 0) {
        printf("\nProgram exited with return code %d:\n", return_code);
        printf("%s", tmp_exe_path);
        for (int i = 0; i < test_case->program_args.length; i += 1) {
            printf(" %s", test_case->program_args.at(i));
        }
        printf("\n");
        printf("%s\n", buf_ptr(&program_stderr));
        exit(1);
    }

    if (!buf_eql_str(&program_stdout, test_case->output)) {
        printf("\n");
        printf("==== Test failed. Expected output: ====\n");
        printf("%s\n", test_case->output);
        printf("========= Actual output: ==============\n");
        printf("%s\n", buf_ptr(&program_stdout));
        printf("=======================================\n");
        exit(1);
    }
}

static void run_all_tests(void) {
    for (int i = 0; i < test_cases.length; i += 1) {
        TestCase *test_case = test_cases.at(i);
        printf("Test %d/%d %s...", i + 1, test_cases.length, test_case->case_name);
        run_test(test_case);
        printf("OK\n");
    }
    printf("%d tests passed.\n", test_cases.length);
}

static void cleanup(void) {
    remove(tmp_source_path);
    remove(tmp_exe_path);
}

int main(int argc, char **argv) {
    add_compiling_test_cases();
    add_compile_failure_test_cases();
    run_all_tests();
    cleanup();
}
