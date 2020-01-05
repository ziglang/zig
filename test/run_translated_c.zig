const std = @import("std");
const tests = @import("tests.zig");
const nl = std.cstr.line_sep;

pub fn addCases(cases: *tests.RunTranslatedCContext) void {
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
