pub export fn entry() void {
    const bitfield = struct {
        e: u8,
        e: u8,
    };
    var a = .{@sizeOf(bitfield)};
    _ = &a;
}

// error
//
// :3:9: error: duplicate struct member name 'e'
// :4:9: note: duplicate name here
// :2:22: note: struct declared here
