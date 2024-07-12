export fn float() void {
    var x: f32 = 0;
    _ = @cmpxchgWeak(f32, &x, 1, 2, .seq_cst, .seq_cst);
}

const NormalStruct = struct { x: u32 };
export fn normalStruct() void {
    var x: NormalStruct = 0;
    _ = @cmpxchgWeak(NormalStruct, &x, .{ .x = 1 }, .{ .x = 2 }, .seq_cst, .seq_cst);
}

// error
// backend=stage2
// target=native
//
// :3:22: error: expected bool, integer, enum, packed struct, or pointer type; found 'f32'
// :8:27: error: expected type 'tmp.NormalStruct', found 'comptime_int'
// :6:22: note: struct declared here
