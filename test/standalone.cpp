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

ZigList<TestCase*> test_cases = {0};
const char *tmp_source_path = ".tmp_source.zig";
const char *tmp_exe_path = "./.tmp_exe";

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

static void add_all_test_cases(void) {
    add_simple_case("hello world with libc", R"SOURCE(
        #link("c")
        extern {
            fn puts(s: *mut u8) -> i32;
            fn exit(code: i32) -> unreachable;
        }

        fn _start() -> unreachable {
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

        fn _start() -> unreachable {
            this_is_a_function();
        }

        fn this_is_a_function() -> unreachable {
            puts("OK");
            exit(0);
        }
    )SOURCE", "OK\n");
}

static void run_test(TestCase *test_case) {
    os_write_file(buf_create_from_str(tmp_source_path), buf_create_from_str(test_case->source));

    Buf zig_stderr = BUF_INIT;
    Buf zig_stdout = BUF_INIT;
    int return_code;
    os_exec_process("./zig", test_case->compiler_args, &return_code, &zig_stderr, &zig_stdout);

    if (return_code != 0) {
        printf("\nCompile failed with return code %d:\n", return_code);
        printf("zig");
        for (int i = 0; i < test_case->compiler_args.length; i += 1) {
            printf(" %s", test_case->compiler_args.at(i));
        }
        printf("\n");
        printf("%s\n", buf_ptr(&zig_stderr));
        exit(1);
    }

    Buf program_stderr = BUF_INIT;
    Buf program_stdout = BUF_INIT;
    os_exec_process(tmp_exe_path, test_case->program_args, &return_code, &program_stderr, &program_stdout);

    if (return_code != 0) {
        printf("\nProgram exited with return code %d:\n", return_code);
        printf("zig");
        for (int i = 0; i < test_case->compiler_args.length; i += 1) {
            printf(" %s", test_case->compiler_args.at(i));
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
    add_all_test_cases();
    run_all_tests();
    cleanup();
}
