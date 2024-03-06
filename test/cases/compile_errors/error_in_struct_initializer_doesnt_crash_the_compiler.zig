pub export fn entry() void {
    const bitfield = struct {
        e: u8,
        e: u8,
    };
    var a = .{@sizeOf(bitfield)};
    _ = &a;
}

// error
// backend=stage2
// target=native
//
// :3:9: error: duplicate struct field name
// :4:9: note: duplicate field here
// :2:22: note: struct declared here
