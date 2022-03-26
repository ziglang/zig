pub export fn entry() void {
    const bitfield = struct {
        e: u8,
        e: u8,
    };
    var a = .{@sizeOf(bitfield)};
    _ = a;
}

// error in struct initializer doesn't crash the compiler
//
// tmp.zig:4:9: error: duplicate struct field: 'e'
