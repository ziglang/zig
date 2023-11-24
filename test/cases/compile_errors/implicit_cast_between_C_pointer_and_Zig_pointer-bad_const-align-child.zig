export fn a() void {
    var x: [*c]u8 = undefined;
    var y: *align(4) u8 = x;
    _ = .{ &x, &y };
}
export fn b() void {
    var x: [*c]const u8 = undefined;
    var y: *u8 = x;
    _ = .{ &x, &y };
}
export fn c() void {
    var x: [*c]u8 = undefined;
    var y: *u32 = x;
    _ = .{ &x, &y };
}
export fn d() void {
    var y: *align(1) u32 = undefined;
    var x: [*c]u32 = y;
    _ = .{ &x, &y };
}
export fn e() void {
    var y: *const u8 = undefined;
    var x: [*c]u8 = y;
    _ = .{ &x, &y };
}
export fn f() void {
    var y: *u8 = undefined;
    var x: [*c]u32 = y;
    _ = .{ &x, &y };
}

// error
// backend=stage2
// target=native
//
// :3:27: error: expected type '*align(4) u8', found '[*c]u8'
// :3:27: note: pointer alignment '1' cannot cast into pointer alignment '4'
// :8:18: error: expected type '*u8', found '[*c]const u8'
// :8:18: note: cast discards const qualifier
// :13:19: error: expected type '*u32', found '[*c]u8'
// :13:19: note: pointer type child 'u8' cannot cast into pointer type child 'u32'
// :18:22: error: expected type '[*c]u32', found '*align(1) u32'
// :18:22: note: pointer alignment '1' cannot cast into pointer alignment '4'
// :23:21: error: expected type '[*c]u8', found '*const u8'
// :23:21: note: cast discards const qualifier
// :28:22: error: expected type '[*c]u32', found '*u8'
// :28:22: note: pointer type child 'u8' cannot cast into pointer type child 'u32'
