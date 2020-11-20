const CodeSignature = @This();

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;
const testing = std.testing;
const Allocator = mem.Allocator;

// pub const Blob = union(enum) {
//     Signature: struct{
//         inner:
//     }
// };

alloc: *Allocator,
inner: macho.SuperBlob = .{
    .magic = macho.CSMAGIC_EMBEDDED_SIGNATURE,
    .length = @sizeOf(macho.SuperBlob),
    .count = 0,
},
// blobs: std.ArrayList(Blob),

pub fn init(alloc: *Allocator) CodeSignature {
    return .{
        .alloc = alloc,
        // .indices = std.ArrayList(Blob).init(alloc),
    };
}

pub fn calcAdhocSignature(self: *CodeSignature) !void {}

pub fn size(self: CodeSignature) u32 {
    return self.inner.length;
}

pub fn write(self: CodeSignature, buffer: []u8) void {
    assert(buffer.len >= self.inner.length);
    self.writeHeader(buffer);
}

pub fn deinit(self: *CodeSignature) void {}

fn writeHeader(self: CodeSignature, buffer: []u8) void {
    assert(buffer.len >= @sizeOf(macho.SuperBlob));
    mem.writeIntBig(u32, buffer[0..4], self.inner.magic);
    mem.writeIntBig(u32, buffer[4..8], self.inner.length);
    mem.writeIntBig(u32, buffer[8..12], self.inner.count);
}

test "CodeSignature header" {
    var code_sig = CodeSignature.init(testing.allocator);
    defer code_sig.deinit();
    var buffer: [@sizeOf(macho.SuperBlob)]u8 = undefined;
    code_sig.writeHeader(buffer[0..]);
    const expected = &[_]u8{ 0xfa, 0xde, 0x0c, 0xc0, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0, 0x0 };
    testing.expect(mem.eql(u8, expected[0..], buffer[0..]));
}
