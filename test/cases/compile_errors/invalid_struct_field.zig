const A = struct { x: i32 };
export fn f() void {
    var a: A = undefined;
    a.foo = 1;
    const y = a.bar;
    _ = y;
}
export fn g() void {
    var a: A = undefined;
    const y = a.bar;
    _ = &a;
    _ = y;
}
export fn e() void {
    const B = struct {
        fn f() void {}
    };
    const b: B = undefined;
    @import("std").debug.print("{}{}", .{ b.f, b.f });
}

// error
// backend=stage2
// target=native
//
// :4:7: error: no field named 'foo' in struct 'tmp.A'
// :1:11: note: struct declared here
// :10:17: error: no field named 'bar' in struct 'tmp.A'
// :1:11: note: struct declared here
// :19:45: error: no field named 'f' in struct 'tmp.e.B'
// :15:15: note: struct declared here
