export fn a() void {
    var x: [*c]u8 = undefined;
    var y: *align(4) u8 = x;
    _ = y;
}
export fn b() void {
    var x: [*c]const u8 = undefined;
    var y: *u8 = x;
    _ = y;
}
export fn c() void {
    var x: [*c]u8 = undefined;
    var y: *u32 = x;
    _ = y;
}
export fn d() void {
    var y: *align(1) u32 = undefined;
    var x: [*c]u32 = y;
    _ = x;
}
export fn e() void {
    var y: *const u8 = undefined;
    var x: [*c]u8 = y;
    _ = x;
}
export fn f() void {
    var y: *u8 = undefined;
    var x: [*c]u32 = y;
    _ = x;
}

// implicit cast between C pointer and Zig pointer - bad const/align/child
//
// tmp.zig:3:27: error: cast increases pointer alignment
// tmp.zig:8:18: error: cast discards const qualifier
// tmp.zig:13:19: error: expected type '*u32', found '[*c]u8'
// tmp.zig:13:19: note: pointer type child 'u8' cannot cast into pointer type child 'u32'
// tmp.zig:18:22: error: cast increases pointer alignment
// tmp.zig:23:21: error: cast discards const qualifier
// tmp.zig:28:22: error: expected type '[*c]u32', found '*u8'
