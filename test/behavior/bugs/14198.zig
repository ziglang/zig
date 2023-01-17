const std = @import("std");
const math = std.math;
const mem = std.mem;
const testing = std.testing;

test "nan memory equality" {
    // signaled
    try testing.expect(mem.eql(u8, mem.asBytes(&math.nan_u16), mem.asBytes(&math.nan_f16)));
    try testing.expect(mem.eql(u8, mem.asBytes(&math.nan_u32), mem.asBytes(&math.nan_f32)));
    try testing.expect(mem.eql(u8, mem.asBytes(&math.nan_u64), mem.asBytes(&math.nan_f64)));
    try testing.expect(mem.eql(u8, mem.asBytes(&math.nan_u128), mem.asBytes(&math.nan_f128)));

    // quiet
    try testing.expect(mem.eql(u8, mem.asBytes(&math.qnan_u16), mem.asBytes(&math.qnan_f16)));
    try testing.expect(mem.eql(u8, mem.asBytes(&math.qnan_u32), mem.asBytes(&math.qnan_f32)));
    try testing.expect(mem.eql(u8, mem.asBytes(&math.qnan_u64), mem.asBytes(&math.qnan_f64)));
    try testing.expect(mem.eql(u8, mem.asBytes(&math.qnan_u128), mem.asBytes(&math.qnan_f128)));
}
