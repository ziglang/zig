export fn entry1() void {
    const S = extern struct { x: u32 };
    _ = *align(1:2:8) S;
}

export fn entry2() void {
    const S = struct { x: u32 };
    _ = *align(1:2:@sizeOf(S) * 2) S;
}

export fn entry3() void {
    const E = enum { implicit, backing, type };
    _ = *align(1:2:8) E;
}

// error
//
// :3:23: error: bit-pointer cannot refer to value of type 'tmp.entry1.S'
// :3:23: note: only packed structs layout are allowed in packed types
// :8:36: error: bit-pointer cannot refer to value of type 'tmp.entry2.S'
// :8:36: note: only packed structs layout are allowed in packed types
// :13:23: error: bit-pointer cannot refer to value of type 'tmp.entry3.E'
