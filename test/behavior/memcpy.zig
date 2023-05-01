const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "memcpy and memset intrinsics" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testMemcpyMemset();
    try comptime testMemcpyMemset();
}

fn testMemcpyMemset() !void {
    var foo: [20]u8 = undefined;
    var bar: [20]u8 = undefined;

    @memset(&foo, 'A');
    @memcpy(&bar, &foo);

    try expect(bar[0] == 'A');
    try expect(bar[11] == 'A');
    try expect(bar[19] == 'A');
}

test "@memcpy with both operands single-ptr-to-array, one is null-terminated" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;

    try testMemcpyBothSinglePtrArrayOneIsNullTerminated();
    try comptime testMemcpyBothSinglePtrArrayOneIsNullTerminated();
}

fn testMemcpyBothSinglePtrArrayOneIsNullTerminated() !void {
    var buf: [100]u8 = undefined;
    const suffix = "hello";
    @memcpy(buf[buf.len - suffix.len ..], suffix);
    try expect(buf[95] == 'h');
    try expect(buf[96] == 'e');
    try expect(buf[97] == 'l');
    try expect(buf[98] == 'l');
    try expect(buf[99] == 'o');
}

const LanguageCode = enum(u16) {
    ENG_US = 0x0409,
    _,
};
fn LanguageDescriptor(comptime value: LanguageCode) type {
    return extern struct {
        length: u8 = @sizeOf(@This()),
        descriptor_type: u8 = 0x03,
        string: [1]u16 align(1) = [1]u16{std.mem.nativeToLittle(u16, @enumToInt(value))},
    };
}
fn langDesc(comptime value: LanguageCode) LanguageDescriptor(value) {
    return comptime LanguageDescriptor(value){};
}
fn DescriptorTable(comptime values: anytype) !void {
    const default_data = comptime default_data: {
        var total_size: usize = 0;
        var value_offsets: [values.len]u8 = undefined;
        inline for (values, 0..) |v, i| {
            total_size += @sizeOf(@TypeOf(v));
            value_offsets[i] = total_size;
        }
        var default_data: [total_size]u8 = undefined;
        var i: usize = 0;
        inline for (values) |v| {
            const src = std.mem.asBytes(&v);
            @memcpy(default_data[i .. i + src.len], src);
            i += src.len;
        }
        break :default_data default_data;
    };
    try std.testing.expectEqualSlices(u8, &default_data, &.{ 0x04, 0x03, 0x09, 0x04 });
}
test "@memcpy at comptime in `inline for` with comptime `extern struct` value" {
    _ = try DescriptorTable(.{
        langDesc(.ENG_US),
    });
}
