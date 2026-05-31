export fn entry() void {
    const x = [_]u8;
    _ = x;
}
export fn entry2() void {
    const S = struct { a: *const [_]u8 };
    var a = .{S{}};
    _ = a;
}

// error
//
// :2:16: error: unable to infer array size
// :6:35: error: unable to infer array size
