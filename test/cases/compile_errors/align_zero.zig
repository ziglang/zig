var global_var: i32 align(0) = undefined;

export fn a() void {
    _ = &global_var;
}

extern var extern_var: i32 align(0);

export fn b() void {
    _ = &extern_var;
}

export fn c() align(0) void {}

export fn d() void {
    _ = *align(0) fn () i32;
}

export fn e() void {
    var local_var: i32 align(0) = undefined;
    _ = &local_var;
}

export fn f() void {
    _ = *align(0) i32;
}

export fn g() void {
    _ = []align(0) i32;
}

export fn h() void {
    _ = struct { field: i32 align(0) };
}

export fn i() void {
    _ = union { field: i32 align(0) };
}

export fn j() void {
    _ = @Struct(.auto, null, &.{"test"}, &.{u32}, &.{.{ .@"align" = 0 }});
}

export fn k() void {
    _ = @Pointer(.one, .{ .@"align" = 0 }, u32, null);
}

// error
//
// :1:27: error: alignment must be >= 1
// :7:34: error: alignment must be >= 1
// :13:21: error: alignment must be >= 1
// :16:16: error: alignment must be >= 1
// :20:30: error: alignment must be >= 1
// :25:16: error: alignment must be >= 1
// :29:17: error: alignment must be >= 1
// :33:35: error: alignment must be >= 1
// :37:34: error: alignment must be >= 1
// :41:51: error: alignment must be >= 1
// :45:25: error: alignment must be >= 1
