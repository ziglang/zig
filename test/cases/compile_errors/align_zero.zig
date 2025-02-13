pub var global_var: i32 align(0) = undefined;

pub export fn a() void {
    _ = &global_var;
}

pub extern var extern_var: i32 align(0);

pub export fn b() void {
    _ = &extern_var;
}

pub export fn c() align(0) void {}

pub export fn d() void {
    _ = *align(0) fn () i32;
}

pub export fn e() void {
    var local_var: i32 align(0) = undefined;
    _ = &local_var;
}

pub export fn f() void {
    _ = *align(0) i32;
}

pub export fn g() void {
    _ = []align(0) i32;
}

pub export fn h() void {
    _ = struct { field: i32 align(0) };
}

pub export fn i() void {
    _ = union { field: i32 align(0) };
}

// error
// backend=stage2
// target=native
//
// :1:31: error: alignment must be >= 1
// :7:38: error: alignment must be >= 1
// :13:25: error: alignment must be >= 1
// :16:16: error: alignment must be >= 1
// :20:30: error: alignment must be >= 1
// :25:16: error: alignment must be >= 1
// :29:17: error: alignment must be >= 1
// :33:35: error: alignment must be >= 1
// :37:34: error: alignment must be >= 1
