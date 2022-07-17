const builtin = @import("std").builtin;
export fn entry() void {
    const foo = builtin.Mode.x86;
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :3:30: error: enum 'builtin.Mode' has no member named 'x86'
// :?:18: note: enum declared here
