#include <stddef.h>
ptrdiff_t sub_ptr(void *a, void *b) {
    return a - b;
}

// translate-c
// c_frontend=clang
// target=x86_64-linux
//
// pub export fn sub_ptr(arg_a: ?*anyopaque, arg_b: ?*anyopaque) ptrdiff_t {
//     var a = arg_a;
//     _ = &a;
//     var b = arg_b;
//     _ = &b;
//     return @as(c_long, @bitCast(@intFromPtr(a) -% @intFromPtr(b)));
// }
