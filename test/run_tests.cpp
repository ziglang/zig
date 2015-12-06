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
    const char *source_code;
};

struct TestCase {
    const char *case_name;
    const char *output;
    ZigList<TestSourceFile> source_files;
    ZigList<const char *> compile_errors;
    ZigList<const char *> compiler_args;
    ZigList<const char *> program_args;
};

static ZigList<TestCase*> test_cases = {0};
static const char *tmp_source_path = ".tmp_source.zig";
static const char *tmp_exe_path = "./.tmp_exe";
static const char *zig_exe = "./zig";

static void add_source_file(TestCase *test_case, const char *path, const char *source) {
    test_case->source_files.add_one();
    test_case->source_files.last().relative_path = path;
    test_case->source_files.last().source_code = source;
}

static TestCase *add_simple_case(const char *case_name, const char *source, const char *output) {
    TestCase *test_case = allocate<TestCase>(1);
    test_case->case_name = case_name;
    test_case->output = output;

    test_case->source_files.resize(1);
    test_case->source_files.at(0).relative_path = tmp_source_path;
    test_case->source_files.at(0).source_code = source;

    test_case->compiler_args.append("build");
    test_case->compiler_args.append(tmp_source_path);
    test_case->compiler_args.append("--export");
    test_case->compiler_args.append("exe");
    test_case->compiler_args.append("--name");
    test_case->compiler_args.append("test");
    test_case->compiler_args.append("--output");
    test_case->compiler_args.append(tmp_exe_path);
    test_case->compiler_args.append("--release");
    test_case->compiler_args.append("--strip");
    test_case->compiler_args.append("--verbose");
    test_case->compiler_args.append("--color");
    test_case->compiler_args.append("on");

    test_cases.append(test_case);

    return test_case;
}

static TestCase *add_compile_fail_case(const char *case_name, const char *source, int count, ...) {
    va_list ap;
    va_start(ap, count);

    TestCase *test_case = allocate<TestCase>(1);
    test_case->case_name = case_name;
    test_case->source_files.resize(1);
    test_case->source_files.at(0).relative_path = tmp_source_path;
    test_case->source_files.at(0).source_code = source;

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
    test_case->compiler_args.append("--verbose");

    test_cases.append(test_case);

    va_end(ap);

    return test_case;
}

static void add_compiling_test_cases(void) {
    add_simple_case("hello world with libc", R"SOURCE(
        #link("c")
        extern {
            fn puts(s: *const u8) -> i32;
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
            fn puts(s: *const u8) -> i32;
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
            fn puts(s: *const u8) -> i32;
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

    {
        TestCase *tc = add_simple_case("multiple files with private function", R"SOURCE(
            use "libc.zig";
            use "foo.zig";

            export fn _start() -> unreachable {
                private_function();
            }

            fn private_function() -> unreachable {
                print_text();
                exit(0);
            }
        )SOURCE", "OK\n");

        add_source_file(tc, "libc.zig", R"SOURCE(
            #link("c")
            extern {
                pub fn puts(s: *const u8) -> i32;
                pub fn exit(code: i32) -> unreachable;
            }
        )SOURCE");

        add_source_file(tc, "foo.zig", R"SOURCE(
            use "libc.zig";

            // purposefully conflicting function with main source file
            // but it's private so it should be OK
            fn private_function() {
                puts("OK");
            }

            pub fn print_text() {
                private_function();
            }
        )SOURCE");
    }

    add_simple_case("if statements", R"SOURCE(
        #link("c")
        extern {
            fn puts(s: *const u8) -> i32;
            fn exit(code: i32) -> unreachable;
        }

        export fn _start() -> unreachable {
            if 1 != 0 {
                puts("1 is true");
            } else {
                puts("1 is false");
            }
            if 0 != 0 {
                puts("0 is true");
            } else if 1 - 1 != 0 {
                puts("1 - 1 is true");
            }
            if !(0 != 0) {
                puts("!0 is true");
            }
            exit(0);
        }
    )SOURCE", "1 is true\n!0 is true\n");

    add_simple_case("params", R"SOURCE(
        #link("c")
        extern {
            fn puts(s: *const u8) -> i32;
            fn exit(code: i32) -> unreachable;
        }

        fn add(a: i32, b: i32) -> i32 {
            a + b
        }

        export fn _start() -> unreachable {
            if add(22, 11) == 33 {
                puts("pass");
            }
            exit(0);
        }
    )SOURCE", "pass\n");

    add_simple_case("goto", R"SOURCE(
        #link("c")
        extern {
            fn puts(s: *const u8) -> i32;
            fn exit(code: i32) -> unreachable;
        }

        fn loop(a : i32) {
            if a == 0 {
                goto done;
            }
            puts("loop");
            loop(a - 1);

        done:
            return;
        }

        export fn _start() -> unreachable {
            loop(3);
            exit(0);
        }
    )SOURCE", "loop\nloop\nloop\n");

    add_simple_case("local variables", R"SOURCE(
#link("c")
extern {
    fn puts(s: *const u8) -> i32;
    fn exit(code: i32) -> unreachable;
}

export fn _start() -> unreachable {
    let a : i32 = 1;
    let b = 2;
    if (a + b == 3) {
        puts("OK");
    }
    exit(0);
}
    )SOURCE", "OK\n");

    add_simple_case("bool literals", R"SOURCE(
#link("c")
extern {
    fn puts(s: *const u8) -> i32;
    fn exit(code: i32) -> unreachable;
}

export fn _start() -> unreachable {
    if (true)   { puts("OK 1"); }
    if (false)  { puts("BAD 1"); }
    if (!true)  { puts("BAD 2"); }
    if (!false) { puts("OK 2"); }
    exit(0);
}
    )SOURCE", "OK 1\nOK 2\n");

    add_simple_case("separate block scopes", R"SOURCE(
#link("c")
extern {
    fn puts(s: *const u8) -> i32;
    fn exit(code: i32) -> unreachable;
}

export fn _start() -> unreachable {
    if (true) {
        let no_conflict = 5;
        if (no_conflict == 5) { puts("OK 1"); }
    }

    let c = {
        let no_conflict = 10;
        no_conflict
    };
    if (c == 10) { puts("OK 2"); }
    exit(0);
}
    )SOURCE", "OK 1\nOK 2\n");

    add_simple_case("void parameters", R"SOURCE(
#link("c")
extern {
    fn puts(s: *const u8) -> i32;
    fn exit(code: i32) -> unreachable;
}

export fn _start() -> unreachable {
    void_fun(1, void, 2);
    exit(0);
}

fn void_fun(a : i32, b : void, c : i32) {
    let v = b;
    let vv : void = if (a == 1) {v} else {};
    if (a + c == 3) { puts("OK"); }
    return vv;
}
    )SOURCE", "OK\n");
}

static void add_compile_failure_test_cases(void) {
    add_compile_fail_case("multiple function definitions", R"SOURCE(
fn a() {}
fn a() {}
    )SOURCE", 1, ".tmp_source.zig:3:1: error: redefinition of 'a'");

    add_compile_fail_case("bad directive", R"SOURCE(
#bogus1("")
extern {
    fn b();
}
#bogus2("")
fn a() {}
    )SOURCE", 2, ".tmp_source.zig:2:1: error: invalid directive: 'bogus1'",
                 ".tmp_source.zig:6:1: error: invalid directive: 'bogus2'");

    add_compile_fail_case("unreachable with return", R"SOURCE(
fn a() -> unreachable {return;}
    )SOURCE", 1, ".tmp_source.zig:2:24: error: type mismatch. expected unreachable. got void");

    add_compile_fail_case("control reaches end of non-void function", R"SOURCE(
fn a() -> i32 {}
    )SOURCE", 1, ".tmp_source.zig:2:15: error: type mismatch. expected i32. got void");

    add_compile_fail_case("undefined function call", R"SOURCE(
fn a() {
    b();
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: undefined function: 'b'");

    add_compile_fail_case("wrong number of arguments", R"SOURCE(
fn a() {
    b(1);
}
fn b(a: i32, b: i32, c: i32) { }
    )SOURCE", 1, ".tmp_source.zig:3:5: error: wrong number of arguments. Expected 3, got 1.");

    add_compile_fail_case("invalid type", R"SOURCE(
fn a() -> bogus {}
    )SOURCE", 1, ".tmp_source.zig:2:11: error: invalid type name: 'bogus'");

    add_compile_fail_case("pointer to unreachable", R"SOURCE(
fn a() -> *mut unreachable {}
    )SOURCE", 1, ".tmp_source.zig:2:11: error: pointer to unreachable not allowed");

    add_compile_fail_case("unreachable code", R"SOURCE(
fn a() {
    return;
    b();
}

fn b() {}
    )SOURCE", 1, ".tmp_source.zig:4:5: error: unreachable code");

    add_compile_fail_case("bad version string", R"SOURCE(
#version("aoeu")
export executable "test";
    )SOURCE", 1, ".tmp_source.zig:2:1: error: invalid version string");

    add_compile_fail_case("bad import", R"SOURCE(
use "bogus-does-not-exist.zig";
    )SOURCE", 1, ".tmp_source.zig:2:1: error: unable to open './bogus-does-not-exist.zig': file not found");

    add_compile_fail_case("undeclared identifier", R"SOURCE(
fn a() {
    b +
    c
}
    )SOURCE", 2,
            ".tmp_source.zig:3:5: error: use of undeclared identifier 'b'",
            ".tmp_source.zig:4:5: error: use of undeclared identifier 'c'");

    add_compile_fail_case("goto cause unreachable code", R"SOURCE(
fn a() {
    goto done;
    b();
done:
    return;
}
fn b() {}
    )SOURCE", 1, ".tmp_source.zig:4:5: error: unreachable code");

    add_compile_fail_case("parameter redeclaration", R"SOURCE(
fn f(a : i32, a : i32) {
}
    )SOURCE", 1, ".tmp_source.zig:2:1: error: redeclaration of parameter 'a'");

    add_compile_fail_case("local variable redeclaration", R"SOURCE(
fn f() {
    let a : i32 = 0;
    let a = 0;
}
    )SOURCE", 1, ".tmp_source.zig:4:5: error: redeclaration of variable 'a'");

    add_compile_fail_case("local variable redeclares parameter", R"SOURCE(
fn f(a : i32) {
    let a = 0;
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: redeclaration of variable 'a'");

    add_compile_fail_case("variable has wrong type", R"SOURCE(
fn f() -> i32 {
    let a = "a";
    a
}
    )SOURCE", 1, ".tmp_source.zig:2:15: error: type mismatch. expected i32. got *const u8");

    add_compile_fail_case("if condition is bool, not int", R"SOURCE(
fn f() {
    if (0) {}
}
    )SOURCE", 1, ".tmp_source.zig:3:9: error: type mismatch. expected bool. got i32");

    add_compile_fail_case("assign unreachable", R"SOURCE(
fn f() {
    let a = return;
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: variable initialization is unreachable");

    add_compile_fail_case("unreachable variable", R"SOURCE(
fn f() {
    let a : unreachable = return;
}
    )SOURCE", 1, ".tmp_source.zig:3:13: error: variable of type 'unreachable' not allowed");

    add_compile_fail_case("unreachable parameter", R"SOURCE(
fn f(a : unreachable) {}
    )SOURCE", 1, ".tmp_source.zig:2:10: error: parameter of type 'unreachable' not allowed");

    add_compile_fail_case("exporting a void parameter", R"SOURCE(
export fn f(a : void) {}
    )SOURCE", 1, ".tmp_source.zig:2:17: error: parameter of type 'void' not allowed on exported functions");

    add_compile_fail_case("unused label", R"SOURCE(
export fn f() {
a_label:
}
    )SOURCE", 1, ".tmp_source.zig:3:1: error: label 'a_label' defined but not used");
}

static void print_compiler_invocation(TestCase *test_case, Buf *zig_stderr) {
    printf("%s", zig_exe);
    for (int i = 0; i < test_case->compiler_args.length; i += 1) {
        printf(" %s", test_case->compiler_args.at(i));
    }
    printf("\n");
    printf("%s\n", buf_ptr(zig_stderr));
}

static void run_test(TestCase *test_case) {
    for (int i = 0; i < test_case->source_files.length; i += 1) {
        TestSourceFile *test_source = &test_case->source_files.at(i);
        os_write_file(
                buf_create_from_str(test_source->relative_path),
                buf_create_from_str(test_source->source_code));
    }

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
                    print_compiler_invocation(test_case, &zig_stderr);
                    exit(1);
                }
            }
            return; // success
        } else {
            printf("\nCompile failed with return code 0 (Expected failure):\n");
            print_compiler_invocation(test_case, &zig_stderr);
            exit(1);
        }
    }

    if (return_code != 0) {
        printf("\nCompile failed with return code %d:\n", return_code);
        print_compiler_invocation(test_case, &zig_stderr);
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

    for (int i = 0; i < test_case->source_files.length; i += 1) {
        TestSourceFile *test_source = &test_case->source_files.at(i);
        remove(test_source->relative_path);
    }
}

static void run_all_tests(bool reverse) {
    if (reverse) {
        for (int i = test_cases.length - 1; i >= 0; i -= 1) {
            TestCase *test_case = test_cases.at(i);
            printf("Test %d/%d %s...", i + 1, test_cases.length, test_case->case_name);
            run_test(test_case);
            printf("OK\n");
        }
    } else {
        for (int i = 0; i < test_cases.length; i += 1) {
            TestCase *test_case = test_cases.at(i);
            printf("Test %d/%d %s...", i + 1, test_cases.length, test_case->case_name);
            run_test(test_case);
            printf("OK\n");
        }
    }
    printf("%d tests passed.\n", test_cases.length);
}

static void cleanup(void) {
    remove(tmp_source_path);
    remove(tmp_exe_path);
}

static int usage(const char *arg0) {
    fprintf(stderr, "Usage: %s [--reverse]\n", arg0);
    return 1;
}

int main(int argc, char **argv) {
    bool reverse = false;
    for (int i = 1; i < argc; i += 1) {
        if (strcmp(argv[i], "--reverse") == 0) {
            reverse = true;
        } else {
            return usage(argv[0]);
        }
    }
    add_compiling_test_cases();
    add_compile_failure_test_cases();
    run_all_tests(reverse);
    cleanup();
}
