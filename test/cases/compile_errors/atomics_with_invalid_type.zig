export fn floatCmpxchg() void {
    var x: f32 = 0;
    _ = @cmpxchgWeak(f32, &x, 1, 2, .seq_cst, .seq_cst);
}

const NormalStruct = struct { x: u32 };
export fn normalStructCmpxchg() void {
    var x: NormalStruct = .{ .x = 0 };
    _ = @cmpxchgWeak(NormalStruct, &x, .{ .x = 1 }, .{ .x = 2 }, .seq_cst, .seq_cst);
}

export fn normalStructLoad() void {
    var x: NormalStruct = .{ .x = 0 };
    _ = @atomicLoad(NormalStruct, &x, .seq_cst);
}

// error
//
// :3:22: error: expected bool, integer, enum, error set, packed struct, or pointer type; found 'f32'
// :3:22: note: floats are not supported for cmpxchg because float equality differs from bitwise equality
// :9:22: error: expected bool, integer, enum, error set, packed struct, or pointer type; found 'tmp.NormalStruct'
// :6:22: note: struct declared here
// :14:21: error: expected bool, integer, float, enum, error set, packed struct, or pointer type; found 'tmp.NormalStruct'
// :6:22: note: struct declared here
