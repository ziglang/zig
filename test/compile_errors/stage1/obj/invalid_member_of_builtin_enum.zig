const builtin = @import("std").builtin;
export fn entry() void {
    const foo = builtin.Mode.x86;
    _ = foo;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:29: error: container 'std.builtin.Mode' has no member called 'x86'
