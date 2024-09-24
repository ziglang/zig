export fn foo() void {
    const S = struct { a: u32 };
    var arr = [_]S{ .{ .a = 1 }, .{ .a = 2 } };
    const s = arr[0..1 :.{ .a = 1 }];
    _ = s;
}

// error
// backend=stage2
// target=native
//
// :4:26: error: non-scalar sentinel type 'tmp.foo.S'
// :2:15: note: struct declared here
