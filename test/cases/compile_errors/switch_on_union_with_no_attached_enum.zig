const Payload = union {
    A: i32,
    B: f64,
    C: bool,
};
export fn entry() void {
    const a = Payload{ .A = 1234 };
    foo(&a);
}
fn foo(a: *const Payload) void {
    switch (a.*) {
        .A => {},
        else => unreachable,
    }
}

// error
// backend=stage2
// target=native
//
// :11:14: error: switch on union with no attached enum
// :1:17: note: consider 'union(enum)' here
