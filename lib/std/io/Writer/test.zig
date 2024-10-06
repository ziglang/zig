const std = @import("../../std.zig");
const testing = std.testing;
const native_endian = @import("builtin").target.cpu.arch.endian();

test "writeStruct writes packed structs without padding" {
    var buf: [3]u8 = undefined;
    var fis = std.io.fixedBufferStream(&buf);
    const writer = fis.writer();

    const PackedStruct = packed struct(u24) { a: u8, b: u8, c: u8 };

    try writer.writeStruct(PackedStruct{ .a = 11, .b = 12, .c = 13 });
    switch (native_endian) {
        .little => {
            try testing.expectEqualSlices(u8, &.{ 11, 12, 13 }, &buf);
        },
        .big => {
            try testing.expectEqualSlices(u8, &.{ 13, 12, 11 }, &buf);
        },
    }
}

test "writeStructEndian writes packed structs without padding and in correct field order" {
    var buf: [3]u8 = undefined;
    var fis = std.io.fixedBufferStream(&buf);
    const writer = fis.writer();

    const PackedStruct = packed struct(u24) { a: u8, b: u8, c: u8 };

    try writer.writeStructEndian(PackedStruct{ .a = 11, .b = 12, .c = 13 }, .little);
    try testing.expectEqualSlices(u8, &.{ 11, 12, 13 }, &buf);
    fis.reset();
    try writer.writeStructEndian(PackedStruct{ .a = 11, .b = 12, .c = 13 }, .big);
    try testing.expectEqualSlices(u8, &.{ 13, 12, 11 }, &buf);
}

test "writeStruct a packed struct with endianness-affected types" {
    var buf: [4]u8 = undefined;
    var fis = std.io.fixedBufferStream(&buf);
    const writer = fis.writer();

    const PackedStruct = packed struct(u32) { a: u16, b: u16 };

    try writer.writeStruct(PackedStruct{ .a = 0x1234, .b = 0x5678 });
    switch (native_endian) {
        .little => try testing.expectEqualSlices(u8, &.{ 0x34, 0x12, 0x78, 0x56 }, &buf),
        .big => try testing.expectEqualSlices(u8, &.{ 0x56, 0x78, 0x12, 0x34 }, &buf),
    }
}

test "writeStructEndian a packed struct with endianness-affected types" {
    var buf: [4]u8 = undefined;
    var fis = std.io.fixedBufferStream(&buf);
    const writer = fis.writer();

    const PackedStruct = packed struct(u32) { a: u16, b: u16 };

    try writer.writeStructEndian(PackedStruct{ .a = 0x1234, .b = 0x5678 }, .little);
    try testing.expectEqualSlices(u8, &.{ 0x34, 0x12, 0x78, 0x56 }, &buf);
    fis.reset();
    try writer.writeStructEndian(PackedStruct{ .a = 0x1234, .b = 0x5678 }, .big);
    try testing.expectEqualSlices(u8, &.{ 0x56, 0x78, 0x12, 0x34 }, &buf);
}
