const Payload = union {
    A: i32,
    B: f64,
    C: bool,
};
export fn entry() void {
    const a = Payload { .A = 1234 };
    foo(a);
}
fn foo(a: *const Payload) void {
    switch (a.*) {
        Payload.A => {},
        else => unreachable,
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:11:14: error: switch on union which has no attached enum
// tmp.zig:1:17: note: consider 'union(enum)' here
