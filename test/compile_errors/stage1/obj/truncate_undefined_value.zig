export fn entry() void {
    var z = @truncate(u8, @as(u16, undefined));
    _ = z;
}

// @truncate undefined value
//
// tmp.zig:2:27: error: use of undefined value here causes undefined behavior
