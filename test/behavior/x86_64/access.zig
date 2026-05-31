const math = @import("math.zig");
const imax = math.imax;
const imin = math.imin;

fn accessSlice(comptime array: anytype) !void {
    var slice: []const @typeInfo(@TypeOf(array)).array.child = undefined;
    slice = &array;
    inline for (0.., &array) |ct_index, *elem| {
        var rt_index: usize = undefined;
        rt_index = ct_index;
        if (&(slice.ptr + ct_index)[0] != elem) return error.Unexpected;
        if (&(slice.ptr + rt_index)[0] != elem) return error.Unexpected;
        if (&slice.ptr[ct_index..][0] != elem) return error.Unexpected;
        if (&slice.ptr[rt_index..][0] != elem) return error.Unexpected;
        if (&slice.ptr[ct_index] != elem) return error.Unexpected;
        if (&slice.ptr[rt_index] != elem) return error.Unexpected;
        if (&slice[ct_index..].ptr[0] != elem) return error.Unexpected;
        if (&slice[rt_index..].ptr[0] != elem) return error.Unexpected;
        if (&slice[ct_index] != elem) return error.Unexpected;
        if (&slice[rt_index] != elem) return error.Unexpected;
        if (slice.ptr[ct_index] != elem.*) return error.Unexpected;
        if (slice.ptr[rt_index] != elem.*) return error.Unexpected;
        if (slice[ct_index] != elem.*) return error.Unexpected;
        if (slice[rt_index] != elem.*) return error.Unexpected;
    }
}
test accessSlice {
    try accessSlice([3]u8{ 0xdb, 0xef, 0xbd });
    try accessSlice([3]u16{ 0x340e, 0x3654, 0x88d7 });
    try accessSlice([3]u32{ 0xd424c2c0, 0x2d6ac466, 0x5a0cfaba });
    try accessSlice([3]u64{
        0x9327a4f5221666a6,
        0x5c34d3ddd84a8b12,
        0xbae087f39f649260,
    });
    try accessSlice([3]u128{
        0x601cf010065444d4d42d5536dd9b95db,
        0xa03f592fcaa22d40af23a0c735531e3c,
        0x5da44907b31602b95c2d93f0b582ceab,
    });
}

fn accessVector(comptime init: anytype) !void {
    const Vector = @TypeOf(init);
    const Elem = @typeInfo(Vector).vector.child;
    const ct_vals: [2]Elem = switch (Elem) {
        bool => .{ false, true },
        else => .{ imin(Elem), imax(Elem) },
    };
    var rt_vals: [2]Elem = undefined;
    rt_vals = ct_vals;
    var vector: Vector = undefined;
    vector = init;
    inline for (0..@typeInfo(Vector).vector.len) |ct_index| {
        if (&vector[ct_index] != &vector[ct_index]) return error.Unexpected;
        if (vector[ct_index] != init[ct_index]) return error.Unexpected;
        vector[ct_index] = rt_vals[0];
        if (vector[ct_index] != ct_vals[0]) return error.Unexpected;
        vector[ct_index] = ct_vals[1];
        if (vector[ct_index] != ct_vals[1]) return error.Unexpected;
        vector[ct_index] = ct_vals[0];
        if (vector[ct_index] != ct_vals[0]) return error.Unexpected;
        vector[ct_index] = rt_vals[1];
        if (vector[ct_index] != ct_vals[1]) return error.Unexpected;
    }
}
test accessVector {
    try accessVector(@Vector(1, bool){
        false,
    });
    try accessVector(@Vector(2, bool){
        false, true,
    });
    try accessVector(@Vector(3, bool){
        true, true, false,
    });
    try accessVector(@Vector(5, bool){
        true, false, true, false, true,
    });
    try accessVector(@Vector(7, bool){
        true, false, true, true, true, false, true,
    });
    try accessVector(@Vector(8, bool){
        false, true, false, true, false, false, false, true,
    });
    try accessVector(@Vector(9, bool){
        true, true, false, true, false, false, false, false,
        true,
    });
    try accessVector(@Vector(15, bool){
        false, true, true,  true,  false, true,  false, false,
        true,  true, false, false, true,  false, false,
    });
    try accessVector(@Vector(16, bool){
        true,  true, false, true,  false, false, false, false,
        false, true, true,  false, false, false, true,  true,
    });
    try accessVector(@Vector(17, bool){
        true,  false, true, true,  false, true,  false, true,
        true,  true,  true, false, false, false, true,  true,
        false,
    });
    try accessVector(@Vector(31, bool){
        true,  false, true,  true,  false, true,  true,  true,
        false, true,  false, true,  false, true,  true,  true,
        false, false, true,  false, false, false, false, true,
        true,  true,  true,  false, false, false, false,
    });
    try accessVector(@Vector(32, bool){
        true,  true,  false, false, false, true, true,  true,
        false, true,  true,  true,  false, true, false, true,
        false, true,  false, true,  false, true, true,  false,
        false, false, false, false, false, true, true,  true,
    });
    try accessVector(@Vector(33, bool){
        true,  false, false, false, false, true,  true,  true,
        false, false, true,  false, true,  true,  false, true,
        true,  true,  false, true,  true,  false, false, false,
        false, true,  false, false, false, true,  true,  false,
        false,
    });
    try accessVector(@Vector(63, bool){
        false, false, true,  true,  true,  false, true,  true,
        true,  false, true,  true,  true,  false, true,  false,
        true,  true,  false, true,  false, true,  true,  true,
        false, false, true,  false, false, false, false, true,
        true,  true,  true,  true,  false, true,  false, true,
        true,  true,  false, false, true,  false, false, true,
        false, true,  false, false, false, false, true,  true,
        false, true,  false, false, true,  true,  true,
    });
    try accessVector(@Vector(64, bool){
        false, false, true,  true,  true,  false, true,  true,
        true,  false, true,  true,  false, true,  true,  false,
        false, false, false, false, true,  true,  false, true,
        true,  true,  true,  true,  false, false, false, true,
        true,  false, true,  true,  false, false, true,  false,
        false, true,  true,  false, true,  true,  false, false,
        true,  true,  false, true,  false, true,  true,  true,
        false, true,  true,  false, false, false, false, false,
    });
    try accessVector(@Vector(65, bool){
        false, false, true,  true,  true,  true,  true,  true,
        true,  false, false, false, false, true,  true,  false,
        true,  false, true,  true,  true,  false, false, false,
        true,  false, true,  true,  false, true,  true,  true,
        true,  true,  false, true,  true,  false, true,  false,
        false, true,  false, true,  false, false, true,  false,
        true,  false, true,  true,  true,  false, true,  true,
        false, false, true,  true,  true,  true,  false, false,
        true,
    });
    try accessVector(@Vector(8, u8){
        0x60, 0xf7, 0xf4, 0xb0, 0x05, 0xd3, 0x06, 0x78,
    });
    try accessVector(@Vector(8, u16){
        0x9c91, 0xfb8b, 0x7f80, 0x8304, 0x6e52, 0xd8ef, 0x37fc, 0x7851,
    });
    try accessVector(@Vector(8, u32){
        0x688b88e2, 0x68e2b7a2, 0x87574680, 0xab4f0769,
        0x75472bb5, 0xa791f2ae, 0xeb2ed416, 0x5f05ce82,
    });
    try accessVector(@Vector(8, u64){
        0xdefd1ddffaedf818, 0x91c78a29d3d59890,
        0x842aaf8fd3c7b785, 0x970a07b8f9f4a6b3,
        0x21b2425d1a428246, 0xea50e41174a7977b,
        0x08d0f1c4f5978b74, 0x8dc88a7fd85e0e67,
    });
    try accessVector(@Vector(8, u128){
        0x6f2cbde1fb219b1e73d7f774d10f0d94,
        0x7c1412616cda20436d7106691d8ba4cc,
        0x4ee940b50e97675b3b35d7872a35b5ad,
        0x6d994fb8caa1b2fac48acbb68fa2d2f1,
        0xdee698c7ec8de9b5940903e3fc665b63,
        0x0751491a509e4a1ce8cfa6d62fe9e74c,
        0x3d880f0a927ce3bfc2682b72070fcd50,
        0x82f0eec62881598699eeb93fbb456e95,
    });
    try accessVector(@Vector(8, u256){
        0x6ee4f35fe624d365952f73960791238ac781bfba782abc7866a691063e43ce48,
        0xb006491f54a9c9292458a5835b7d5f4cfa18136f175eef0a13bb8adf5c3dc061,
        0xd6e25ca1bc5685fc52609e261b9065bc05a8662e9291660033dd7f6d98e562b3,
        0x992c5e54e0e6331dac258996be7dae9b2a2eff323a39043ba8d2721420dc5f5c,
        0x257313f45fb3556d0fc323d5f38c953e9a093fe2278655312b6a5b64aab9d901,
        0x6c8ad2182b9a3b2b19c2c9b152956b383d0fee2e3fbd5b02ed72227446a7b221,
        0xd80cafc2252b289793799675e43f97ba4a5448c7b57e1544a464687b435efc7b,
        0xfcb480f2d70afd53c4689dd3f5db7638c24302f2a6a15f738167db090d91fb28,
    });
}
