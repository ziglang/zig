const std = @import("std");
const tests = @import("tests.zig");
const nl = std.cstr.line_sep;

pub fn addCases(cases: *tests.RunTranslatedCContext) void {
    cases.add("parenthesized string literal",
        \\void foo(const char *s) {}
        \\int main(void) {
        \\	foo(("bar"));
        \\}
    , "");

    cases.add("variable shadowing type type",
        \\#include <stdlib.h>
        \\int main() {
        \\    int type = 1;
        \\    if (type != 1) abort();
        \\}
    , "");

    cases.add("assignment as expression",
        \\#include <stdlib.h>
        \\int main() {
        \\    int a, b, c, d = 5;
        \\    int e = a = b = c = d;
        \\    if (e != 5) abort();
        \\}
    , "");

    cases.add("static variable in block scope",
        \\#include <stdlib.h>
        \\int foo() {
        \\    static int bar;
        \\    bar += 1;
        \\    return bar;
        \\}
        \\int main() {
        \\    foo();
        \\    foo();
        \\    if (foo() != 3) abort();
        \\}
    , "");

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

    cases.add("case boolean expression converted to int",
        \\#include <stdlib.h>
        \\int main(int argc, char **argv) {
        \\  int value = 1 + 2 * 3 + 4 * 5 + 6 << 7 | 8 == 9;
        \\  if (value != 4224) abort();
        \\  return 0;
        \\}
    , "");

    cases.add("case boolean expression on left converted to int",
        \\#include <stdlib.h>
        \\int main(int argc, char **argv) {
        \\  int value = 8 == 9 | 1 + 2 * 3 + 4 * 5 + 6 << 7;
        \\  if (value != 4224) abort();
        \\  return 0;
        \\}
    , "");

    cases.add("case boolean and operator+ converts bool to int",
        \\#include <stdlib.h>
        \\int main(int argc, char **argv) {
        \\  int value = (8 == 9) + 3;
        \\  int value2 = 3 + (8 == 9);
        \\  if (value != value2) abort();
        \\  return 0;
        \\}
    , "");

    cases.add("case boolean and operator<",
        \\#include <stdlib.h>
        \\int main(int argc, char **argv) {
        \\  int value = (8 == 9) < 3;
        \\  if (value == 0) abort();
        \\  return 0;
        \\}
    , "");

    cases.add("case boolean and operator*",
        \\#include <stdlib.h>
        \\int main(int argc, char **argv) {
        \\  int value = (8 == 9) * 3;
        \\  int value2 = 3 * (9 == 9);
        \\  if (value != 0) abort();
        \\  if (value2 == 0) abort();
        \\  return 0;
        \\}
    , "");

    cases.add("scoped typedef",
        \\int main(int argc, char **argv) {
        \\  typedef int Foo;
        \\  typedef Foo Bar;
        \\  typedef void (*func)(int);
        \\  typedef int uint32_t;
        \\  uint32_t a;
        \\  Foo i;
        \\  Bar j;
        \\  return 0;
        \\}
    , "");

    cases.add("scoped for loops with shadowing",
        \\#include <stdlib.h>
        \\int main() {
        \\    int count = 0;
        \\    for (int x = 0; x < 2; x++)
        \\        for (int x = 0; x < 2; x++)
        \\            count++;
        \\
        \\    if (count != 4) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("array value type casts properly",
        \\#include <stdlib.h>
        \\unsigned int choose[53][10];
        \\static int hash_binary(int k)
        \\{
        \\    choose[0][k] = 3;
        \\    int sum = 0;
        \\    sum += choose[0][k];
        \\    return sum;
        \\}
        \\
        \\int main() {
        \\    int s = hash_binary(4);
        \\    if (s != 3) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("array value type casts properly use +=",
        \\#include <stdlib.h>
        \\static int hash_binary(int k)
        \\{
        \\    unsigned int choose[1][1] = {{3}};
        \\    int sum = -1;
        \\    int prev = 0;
        \\    prev = sum += choose[0][0];
        \\    if (sum != 2) abort();
        \\    return sum + prev;
        \\}
        \\
        \\int main() {
        \\    int x = hash_binary(4);
        \\    if (x != 4) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("ensure array casts outisde +=",
        \\#include <stdlib.h>
        \\static int hash_binary(int k)
        \\{
        \\    unsigned int choose[3] = {1, 2, 3};
        \\    int sum = -2;
        \\    int prev = sum + choose[k];
        \\    if (prev != 0) abort();
        \\    return sum + prev;
        \\}
        \\
        \\int main() {
        \\    int x = hash_binary(1);
        \\    if (x != -2) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("array cast int to uint",
        \\#include <stdlib.h>
        \\static unsigned int hash_binary(int k)
        \\{
        \\    int choose[3] = {-1, -2, 3};
        \\    unsigned int sum = 2;
        \\    sum += choose[k];
        \\    return sum;
        \\}
        \\
        \\int main() {
        \\    unsigned int x = hash_binary(1);
        \\    if (x != 0) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("assign enum to uint, no explicit cast",
        \\#include <stdlib.h>
        \\typedef enum {
        \\    ENUM_0 = 0,
        \\    ENUM_1 = 1,
        \\} my_enum_t;
        \\
        \\int main() {
        \\    my_enum_t val = ENUM_1;
        \\    unsigned int x = val;
        \\    if (x != 1) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("assign enum to int",
        \\#include <stdlib.h>
        \\typedef enum {
        \\    ENUM_0 = 0,
        \\    ENUM_1 = 1,
        \\} my_enum_t;
        \\
        \\int main() {
        \\    my_enum_t val = ENUM_1;
        \\    int x = val;
        \\    if (x != 1) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("cast enum to smaller uint",
        \\#include <stdlib.h>
        \\#include <stdint.h>
        \\typedef enum {
        \\    ENUM_0 = 0,
        \\    ENUM_257 = 257,
        \\} my_enum_t;
        \\
        \\int main() {
        \\    my_enum_t val = ENUM_257;
        \\    uint8_t x = (uint8_t)val;
        \\    if (x != (uint8_t)257) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("cast enum to smaller signed int",
        \\#include <stdlib.h>
        \\#include <stdint.h>
        \\typedef enum {
        \\    ENUM_0 = 0,
        \\    ENUM_384 = 384,
        \\} my_enum_t;
        \\
        \\int main() {
        \\    my_enum_t val = ENUM_384;
        \\    int8_t x = (int8_t)val;
        \\    if (x != (int8_t)384) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("cast negative enum to smaller signed int",
        \\#include <stdlib.h>
        \\#include <stdint.h>
        \\typedef enum {
        \\    ENUM_MINUS_1 = -1,
        \\    ENUM_384 = 384,
        \\} my_enum_t;
        \\
        \\int main() {
        \\    my_enum_t val = ENUM_MINUS_1;
        \\    int8_t x = (int8_t)val;
        \\    if (x != -1) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("cast negative enum to smaller unsigned int",
        \\#include <stdlib.h>
        \\#include <stdint.h>
        \\typedef enum {
        \\    ENUM_MINUS_1 = -1,
        \\    ENUM_384 = 384,
        \\} my_enum_t;
        \\
        \\int main() {
        \\    my_enum_t val = ENUM_MINUS_1;
        \\    uint8_t x = (uint8_t)val;
        \\    if (x != (uint8_t)-1) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("implicit enum cast in boolean expression",
        \\#include <stdlib.h>
        \\enum Foo {
        \\    FooA,
        \\    FooB,
        \\    FooC,
        \\};
        \\int main() {
        \\    int a = 0;
        \\    float b = 0;
        \\    void *c = 0;
        \\    enum Foo d = FooA;
        \\    if (a || d) abort();
        \\    if (d && b) abort();
        \\    if (c || d) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("issue #6707 cast builtin call result to opaque struct pointer",
        \\#include <stdlib.h>
        \\struct foo* make_foo(void)
        \\{
        \\    return (struct foo*)__builtin_strlen("0123456789ABCDEF");
        \\}
        \\int main(void) {
        \\    struct foo *foo_pointer = make_foo();
        \\    if (foo_pointer != (struct foo*)16) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("C built-ins",
        \\#include <stdlib.h>
        \\#include <limits.h>
        \\#include <stdbool.h>
        \\#define M_E    2.71828182845904523536
        \\#define M_PI_2 1.57079632679489661923
        \\bool check_clz(unsigned int pos) {
        \\    return (__builtin_clz(1 << pos) == (8 * sizeof(unsigned int) - pos - 1));
        \\}
        \\int main(void) {
        \\    if (__builtin_bswap16(0x0102) != 0x0201) abort();
        \\    if (__builtin_bswap32(0x01020304) != 0x04030201) abort();
        \\    if (__builtin_bswap64(0x0102030405060708) != 0x0807060504030201) abort();
        \\
        \\    if (__builtin_signbit(0.0) != 0) abort();
        \\    if (__builtin_signbitf(0.0f) != 0) abort();
        \\    if (__builtin_signbit(1.0) != 0) abort();
        \\    if (__builtin_signbitf(1.0f) != 0) abort();
        \\    if (__builtin_signbit(-1.0) != 1) abort();
        \\    if (__builtin_signbitf(-1.0f) != 1) abort();
        \\
        \\    if (__builtin_popcount(0) != 0) abort();
        \\    if (__builtin_popcount(0b1) != 1) abort();
        \\    if (__builtin_popcount(0b11) != 2) abort();
        \\    if (__builtin_popcount(0b1111) != 4) abort();
        \\    if (__builtin_popcount(0b11111111) != 8) abort();
        \\
        \\    if (__builtin_ctz(0b1) != 0) abort();
        \\    if (__builtin_ctz(0b10) != 1) abort();
        \\    if (__builtin_ctz(0b100) != 2) abort();
        \\    if (__builtin_ctz(0b10000) != 4) abort();
        \\    if (__builtin_ctz(0b100000000) != 8) abort();
        \\
        \\    if (!check_clz(0)) abort();
        \\    if (!check_clz(1)) abort();
        \\    if (!check_clz(2)) abort();
        \\    if (!check_clz(4)) abort();
        \\    if (!check_clz(8)) abort();
        \\
        \\    if (__builtin_sqrt(__builtin_sqrt(__builtin_sqrt(256))) != 2.0) abort();
        \\    if (__builtin_sqrt(__builtin_sqrt(__builtin_sqrt(256.0))) != 2.0) abort();
        \\    if (__builtin_sqrt(__builtin_sqrt(__builtin_sqrt(256.0f))) != 2.0) abort();
        \\    if (__builtin_sqrtf(__builtin_sqrtf(__builtin_sqrtf(256.0f))) != 2.0f) abort();
        \\
        \\    if (__builtin_sin(1.0) != -__builtin_sin(-1.0)) abort();
        \\    if (__builtin_sinf(1.0f) != -__builtin_sinf(-1.0f)) abort();
        \\    if (__builtin_sin(M_PI_2) != 1.0) abort();
        \\    if (__builtin_sinf(M_PI_2) != 1.0f) abort();
        \\
        \\    if (__builtin_cos(1.0) != __builtin_cos(-1.0)) abort();
        \\    if (__builtin_cosf(1.0f) != __builtin_cosf(-1.0f)) abort();
        \\    if (__builtin_cos(0.0) != 1.0) abort();
        \\    if (__builtin_cosf(0.0f) != 1.0f) abort();
        \\
        \\    if (__builtin_exp(0) != 1.0) abort();
        \\    if (__builtin_fabs(__builtin_exp(1.0) - M_E) > 0.00000001) abort();
        \\    if (__builtin_exp(0.0f) != 1.0f) abort();
        \\
        \\    if (__builtin_exp2(0) != 1.0) abort();
        \\    if (__builtin_exp2(4.0) != 16.0) abort();
        \\    if (__builtin_exp2f(0.0f) != 1.0f) abort();
        \\    if (__builtin_exp2f(4.0f) != 16.0f) abort();
        \\
        \\    if (__builtin_log(M_E) != 1.0) abort();
        \\    if (__builtin_log(1.0) != 0.0) abort();
        \\    if (__builtin_logf(1.0f) != 0.0f) abort();
        \\
        \\    if (__builtin_log2(8.0) != 3.0) abort();
        \\    if (__builtin_log2(1.0) != 0.0) abort();
        \\    if (__builtin_log2f(8.0f) != 3.0f) abort();
        \\    if (__builtin_log2f(1.0f) != 0.0f) abort();
        \\
        \\    if (__builtin_log10(1000.0) != 3.0) abort();
        \\    if (__builtin_log10(1.0) != 0.0) abort();
        \\    if (__builtin_log10f(1000.0f) != 3.0f) abort();
        \\    if (__builtin_log10f(1.0f) != 0.0f) abort();
        \\
        \\    if (__builtin_fabs(-42.0f) != 42.0) abort();
        \\    if (__builtin_fabs(-42.0) != 42.0) abort();
        \\    if (__builtin_fabs(-42) != 42.0) abort();
        \\    if (__builtin_fabsf(-42.0f) != 42.0f) abort();
        \\
        \\    if (__builtin_fabs(-42.0f) != 42.0) abort();
        \\    if (__builtin_fabs(-42.0) != 42.0) abort();
        \\    if (__builtin_fabs(-42) != 42.0) abort();
        \\    if (__builtin_fabsf(-42.0f) != 42.0f) abort();
        \\
        \\    if (__builtin_abs(42) != 42) abort();
        \\    if (__builtin_abs(-42) != 42) abort();
        \\    if (__builtin_abs(INT_MIN) != INT_MIN) abort();
        \\
        \\    if (__builtin_floor(42.9) != 42.0) abort();
        \\    if (__builtin_floor(-42.9) != -43.0) abort();
        \\    if (__builtin_floorf(42.9f) != 42.0f) abort();
        \\    if (__builtin_floorf(-42.9f) != -43.0f) abort();
        \\
        \\    if (__builtin_ceil(42.9) != 43.0) abort();
        \\    if (__builtin_ceil(-42.9) != -42) abort();
        \\    if (__builtin_ceilf(42.9f) != 43.0f) abort();
        \\    if (__builtin_ceilf(-42.9f) != -42.0f) abort();
        \\
        \\    if (__builtin_trunc(42.9) != 42.0) abort();
        \\    if (__builtin_truncf(42.9f) != 42.0f) abort();
        \\    if (__builtin_trunc(-42.9) != -42.0) abort();
        \\    if (__builtin_truncf(-42.9f) != -42.0f) abort();
        \\
        \\    if (__builtin_round(0.5) != 1.0) abort();
        \\    if (__builtin_round(-0.5) != -1.0) abort();
        \\    if (__builtin_roundf(0.5f) != 1.0f) abort();
        \\    if (__builtin_roundf(-0.5f) != -1.0f) abort();
        \\
        \\    if (__builtin_strcmp("abc", "abc") != 0) abort();
        \\    if (__builtin_strcmp("abc", "def") >= 0 ) abort();
        \\    if (__builtin_strcmp("def", "abc") <= 0) abort();
        \\
        \\    if (__builtin_strlen("this is a string") != 16) abort();
        \\
        \\    char *s = malloc(6);
        \\    __builtin_memcpy(s, "hello", 5);
        \\    s[5] = '\0';
        \\    if (__builtin_strlen(s) != 5) abort();
        \\
        \\    __builtin_memset(s, 42, __builtin_strlen(s));
        \\    if (s[0] != 42 || s[1] != 42 || s[2] != 42 || s[3] != 42 || s[4] != 42) abort();
        \\
        \\    free(s);
        \\
        \\    return 0;
        \\}
    , "");

    cases.add("function macro that uses builtin",
        \\#include <stdlib.h>
        \\#define FOO(x, y) (__builtin_popcount((x)) + __builtin_strlen((y)))
        \\int main() {
        \\    if (FOO(7, "hello!") != 9) abort();
        \\    return 0;
        \\}
    , "");

    cases.add("assign bool result to int or char",
        \\#include <stdlib.h>
        \\#include <stdbool.h>
        \\bool foo() { return true; }
        \\int main() {
        \\    int x = foo();
        \\    if (x != 1) abort();
        \\    signed char c = foo();
        \\    if (c != 1) abort();
        \\    return 0;
        \\}
    , "");
}
