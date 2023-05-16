const builtin = @import("std").builtin;
export fn entry() void {
    const foo = builtin.OptimizeMode.x86;
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :3:38: error: enum 'builtin.OptimizeMode' has no member named 'x86'
// : note: enum declared here
