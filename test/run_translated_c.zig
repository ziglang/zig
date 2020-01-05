const std = @import("std");
const tests = @import("tests.zig");
const nl = std.cstr.line_sep;

pub fn addCases(cases: *tests.RunTranslatedCContext) void {
    cases.add("boolean values and expressions",
        \\#include <stdlib.h>
        \\static const _Bool false_val = 0;
        \\static const _Bool true_val = 1;
        \\void foo(int x, int y) {
        \\    _Bool r = x < y;
        \\    if (!r) abort();
        \\    _Bool self = foo;
        \\    if (self == false_val) abort();
        \\}
        \\int main(int argc, char **argv) {
        \\    foo(2, 5);
        \\    if (false_val == true_val) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("hello world",
        \\#define _NO_CRT_STDIO_INLINE 1
        \\#include <stdio.h>
        \\int main(int argc, char **argv) {
        \\    printf("hello, world!\n");
        \\    return 0;
        \\}
    , "hello, world!" ++ nl);

    cases.add("anon struct init",
        \\#include <stdlib.h>
        \\struct {int a; int b;} x = {1, 2};
        \\int main(int argc, char **argv) {
        \\    x.a += 2;
        \\    x.b += 1;
        \\    if (x.a != 3) abort();
        \\    if (x.b != 3) abort();
        \\    return 0;
        \\}
    , "");
}
