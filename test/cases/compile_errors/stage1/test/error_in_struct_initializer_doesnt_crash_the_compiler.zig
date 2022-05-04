pub export fn entry() void {
    const bitfield = struct {
        e: u8,
        e: u8,
    };
    var a = .{@sizeOf(bitfield)};
    _ = a;
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:4:9: error: duplicate struct field: 'e'
