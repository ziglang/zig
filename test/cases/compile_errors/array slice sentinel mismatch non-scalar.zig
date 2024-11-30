export fn foo() void {
    const S = struct { a: u32 };
    const sentinel: S = .{ .a = 1 };
    var arr = [_]S{ .{ .a = 1 }, .{ .a = 2 } };
    const s = arr[0..1 :sentinel];
    _ = s;
}

// error
// backend=stage2
// target=native
//
// :5:25: error: non-scalar sentinel type 'tmp.foo.S'
// :2:15: note: struct declared here
