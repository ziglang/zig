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

    cases.add("casting away const and volatile",
        \\void foo(int *a) {}
        \\void bar(const int *a) {
        \\    foo((int *)a);
        \\}
        \\void baz(volatile int *a) {
        \\    foo((int *)a);
        \\}
        \\int main(int argc, char **argv) {
        \\    int a = 0;
        \\    bar((const int *)&a);
        \\    baz((volatile int *)&a);
        \\    return 0;
        \\}
    , "");

    cases.add("anonymous struct & unions",
        \\#include <stdlib.h>
        \\#include <stdint.h>
        \\static struct { struct { uint16_t x, y; }; } x = { 1 };
        \\static struct { union { uint32_t x; uint8_t y; }; } y = { 0x55AA55AA };
        \\int main(int argc, char **argv) {
        \\    if (x.x != 1) abort();
        \\    if (x.y != 0) abort();
        \\    if (y.x != 0x55AA55AA) abort();
        \\    if (y.y != 0xAA) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("array to pointer decay",
        \\#include <stdlib.h>
        \\int main(int argc, char **argv) {
        \\    char data[3] = {'a','b','c'};
        \\    if (2[data] != data[2]) abort();
        \\    if ("abc"[1] != data[1]) abort();
        \\    char *as_ptr = data;
        \\    if (2[as_ptr] != as_ptr[2]) abort();
        \\    if ("abc"[1] != as_ptr[1]) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("struct initializer - packed",
        \\#define _NO_CRT_STDIO_INLINE 1
        \\#include <stdint.h>
        \\#include <stdlib.h>
        \\struct s {uint8_t x,y;
        \\          uint32_t z;} __attribute__((packed)) s0 = {1, 2};
        \\int main() {
        \\  /* sizeof nor offsetof currently supported */
        \\  if (((intptr_t)&s0.z - (intptr_t)&s0.x) != 2) abort();
        \\  return 0;
        \\}
    , "");
}
