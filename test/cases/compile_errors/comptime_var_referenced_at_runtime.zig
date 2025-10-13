var runtime_int: u32 = 123;

export fn foo() void {
    comptime var x: u32 = 123;
    var runtime = &x;
    _ = &runtime;
}

export fn bar() void {
    const S = struct { u32, *const u32 };
    comptime var x: u32 = 123;
    const runtime: S = .{ runtime_int, &x };
    _ = runtime;
}

export fn qux() void {
    const S = struct { a: u32, b: *const u32 };
    comptime var x: u32 = 123;
    const runtime: S = .{ .a = runtime_int, .b = &x };
    _ = runtime;
}

export fn baz() void {
    const S = struct {
        fn f(_: *const u32) void {}
    };
    comptime var x: u32 = 123;
    S.f(&x);
}

export fn faz() void {
    const S = struct {
        fn f(_: anytype) void {}
    };
    comptime var x: u32 = 123;
    S.f(&x);
}

export fn boo() *const u32 {
    comptime var x: u32 = 123;
    return &x;
}

export fn qar() void {
    comptime var x: u32 = 123;
    const y = if (runtime_int == 123) &x else undefined;
    _ = y;
}

export fn bux() void {
    comptime var x: [2]u32 = undefined;
    x = .{ 1, 2 };

    var rt: [2]u32 = undefined;
    @memcpy(&rt, &x);
}

export fn far() void {
    comptime var x: u32 = 123;

    var rt: [2]*u32 = undefined;
    const elem: *u32 = &x;
    @memset(&rt, elem);
}

export fn bax() void {
    comptime var x: [2]u32 = undefined;
    x = .{ 1, 2 };

    var rt: [2]u32 = undefined;
    @memmove(&rt, &x);
}

// error
//
// :5:19: error: runtime value contains reference to comptime var
// :5:19: note: comptime var pointers are not available at runtime
// :4:14: note: 'runtime_value' points to comptime var declared here
// :12:40: error: runtime value contains reference to comptime var
// :12:40: note: comptime var pointers are not available at runtime
// :11:14: note: 'runtime_value' points to comptime var declared here
// :19:50: error: runtime value contains reference to comptime var
// :19:50: note: comptime var pointers are not available at runtime
// :18:14: note: 'runtime_value' points to comptime var declared here
// :28:9: error: runtime value contains reference to comptime var
// :28:9: note: comptime var pointers are not available at runtime
// :27:14: note: 'runtime_value' points to comptime var declared here
// :36:9: error: runtime value contains reference to comptime var
// :36:9: note: comptime var pointers are not available at runtime
// :35:14: note: 'runtime_value' points to comptime var declared here
// :41:12: error: runtime value contains reference to comptime var
// :41:12: note: comptime var pointers are not available at runtime
// :40:14: note: 'runtime_value' points to comptime var declared here
// :46:39: error: runtime value contains reference to comptime var
// :46:39: note: comptime var pointers are not available at runtime
// :45:14: note: 'runtime_value' points to comptime var declared here
// :55:18: error: runtime value contains reference to comptime var
// :55:18: note: comptime var pointers are not available at runtime
// :51:14: note: 'runtime_value' points to comptime var declared here
// :63:18: error: runtime value contains reference to comptime var
// :63:18: note: comptime var pointers are not available at runtime
// :59:14: note: 'runtime_value' points to comptime var declared here
// :71:19: error: runtime value contains reference to comptime var
// :71:19: note: comptime var pointers are not available at runtime
// :67:14: note: 'runtime_value' points to comptime var declared here
