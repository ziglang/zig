#define TERNARY_CHECK(i) check(i)
#define TERNARY_CALL(i) (TERNARY_CHECK(i) ? (i+1) : (i-1))

static inline int check(int obj) {
    return obj % 2;
}
int target_func(int a) {
    return TERNARY_CALL(a);
}

// translate-c
// c_frontend=clang
//
// pub inline fn TERNARY_CHECK(i: anytype) @TypeOf(check(i)) {
//     _ = &i;
//     return check(i);
// }
// pub inline fn TERNARY_CALL(i: anytype) @TypeOf(if (TERNARY_CHECK(i) != 0) i + @as(c_int, 1) else i - @as(c_int, 1)) {
//     _ = &i;
//     return if (TERNARY_CHECK(i) != 0) i + @as(c_int, 1) else i - @as(c_int, 1);
// }