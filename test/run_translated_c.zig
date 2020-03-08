const std = @import("std");
const tests = @import("tests.zig");
const nl = std.cstr.line_sep;

pub fn addCases(cases: *tests.RunTranslatedCContext) void {
    cases.add("array initializer",
        \\#include <stdlib.h>
        \\int main(int argc, char **argv) {
        \\    int a0[4] = {1};
        \\    int a1[4] = {1,2,3,4};
        \\    int s0 = 0, s1 = 0;
        \\    for (int i = 0; i < 4; i++) {
        \\        s0 += a0[i];
        \\        s1 += a1[i];
        \\    }
        \\    if (s0 != 1) abort();
        \\    if (s1 != 10) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("forward declarations",
        \\#include <stdlib.h>
        \\int foo(int);
        \\int foo(int x) { return x + 1; }
        \\int main(int argc, char **argv) {
        \\    if (foo(2) != 3) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("typedef and function pointer",
        \\#include <stdlib.h>
        \\typedef struct _Foo Foo;
        \\typedef int Ret;
        \\typedef int Param;
        \\struct _Foo { Ret (*func)(Param p); };
        \\static Ret add1(Param p) {
        \\    return p + 1;
        \\}
        \\int main(int argc, char **argv) {
        \\    Foo strct = { .func = add1 };
        \\    if (strct.func(16) != 17) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("ternary operator",
        \\#include <stdlib.h>
        \\static int cnt = 0;
        \\int foo() { cnt++; return 42; }
        \\int main(int argc, char **argv) {
        \\  short q = 3;
        \\  signed char z0 = q?:1;
        \\  if (z0 != 3) abort();
        \\  int z1 = 3?:1;
        \\  if (z1 != 3) abort();
        \\  int z2 = foo()?:-1;
        \\  if (z2 != 42) abort();
        \\  if (cnt != 1) abort();
        \\  return 0;
        \\}
    , "");

    cases.add("switch case",
        \\#include <stdlib.h>
        \\int lottery(unsigned int x) {
        \\    switch (x) {
        \\        case 3: return 0;
        \\        case -1: return 3;
        \\        case 8 ... 10: return x;
        \\        default: return -1;
        \\    }
        \\}
        \\int main(int argc, char **argv) {
        \\    if (lottery(2) != -1) abort();
        \\    if (lottery(3) != 0) abort();
        \\    if (lottery(-1) != 3) abort();
        \\    if (lottery(9) != 9) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("boolean values and expressions",
        \\#include <stdlib.h>
        \\static const _Bool false_val = 0;
        \\static const _Bool true_val = 1;
        \\void foo(int x, int y) {
        \\    _Bool r = x < y;
        \\    if (!r) abort();
        \\    _Bool self = foo;
        \\    if (self == false_val) abort();
        \\    if (((r) ? 'a' : 'b') != 'a') abort();
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

    cases.add("cast signed array index to unsigned",
        \\#include <stdlib.h>
        \\int main(int argc, char **argv) {
        \\  int a[10], i = 0;
        \\  a[i] = 0;
        \\  if (a[i] != 0) abort();
        \\  return 0;
        \\}
    , "");

    cases.add("cast long long array index to unsigned",
        \\#include <stdlib.h>
        \\int main(int argc, char **argv) {
        \\  long long a[10], i = 0;
        \\  a[i] = 0;
        \\  if (a[i] != 0) abort();
        \\  return 0;
        \\}
    , "");
}
