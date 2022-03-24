const A = struct { x : i32, };
export fn f() void {
    var a : A = undefined;
    a.foo = 1;
    const y = a.bar;
    _ = y;
}
export fn g() void {
    var a : A = undefined;
    const y = a.bar;
    _ = y;
}

// invalid struct field
//
// tmp.zig:4:6: error: no member named 'foo' in struct 'A'
// tmp.zig:10:16: error: no member named 'bar' in struct 'A'
