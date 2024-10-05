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
