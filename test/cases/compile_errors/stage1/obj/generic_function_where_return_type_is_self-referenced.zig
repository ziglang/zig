fn Foo(comptime T: type) Foo(T) {
    return struct { x: T };
}
export fn entry() void {
    const t = Foo(u32){ .x = 1 };
    _ = t;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:29: error: evaluation exceeded 1000 backwards branches
