pub export fn entry() void {
    const bitfield = struct {
        e: u8,
        e: u8,
    };
    var a = .{@sizeOf(bitfield)};
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :4:9: error: duplicate struct field: 'e'
// :3:9: note: other field here
// :2:22: note: struct declared here
