const CodeSignature = @This();

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;
const testing = std.testing;
const Allocator = mem.Allocator;

const Blob = struct {
    inner: macho.CodeDirectory,
    data: std.ArrayListUnmanaged(u8) = .{},

    fn size(self: Blob) u32 {
        return self.inner.length;
    }

    fn write(self: Blob, buffer: []u8) void {
        assert(buffer.len >= self.inner.length);
        mem.writeIntBig(u32, buffer[0..4], self.inner.magic);
        mem.writeIntBig(u32, buffer[4..8], self.inner.length);
        mem.writeIntBig(u32, buffer[8..12], self.inner.version);
        mem.writeIntBig(u32, buffer[12..16], self.inner.flags);
        mem.writeIntBig(u32, buffer[16..20], self.inner.hashOffset);
        mem.writeIntBig(u32, buffer[20..24], self.inner.identOffset);
        mem.writeIntBig(u32, buffer[24..28], self.inner.nSpecialSlots);
        mem.writeIntBig(u32, buffer[28..32], self.inner.nCodeSlots);
        mem.writeIntBig(u32, buffer[32..36], self.inner.codeLimit);
        mem.writeIntBig(u8, buffer[36..37], self.inner.hashSize);
        mem.writeIntBig(u8, buffer[37..38], self.inner.hashType);
        mem.writeIntBig(u8, buffer[38..39], self.inner.platform);
        mem.writeIntBig(u8, buffer[39..40], self.inner.pageSize);
        mem.writeIntBig(u32, buffer[40..44], self.inner.spare2);
        mem.writeIntBig(u32, buffer[44..48], self.inner.scatterOffset);
        mem.writeIntBig(u32, buffer[48..52], self.inner.teamOffset);
        mem.writeIntBig(u32, buffer[52..56], self.inner.spare3);
        mem.writeIntBig(u64, buffer[56..64], self.inner.codeLimit64);
        mem.writeIntBig(u64, buffer[64..72], self.inner.execSegBase);
        mem.writeIntBig(u64, buffer[72..80], self.inner.execSegLimit);
        mem.writeIntBig(u64, buffer[80..88], self.inner.execSegFlags);
    }
};

alloc: *Allocator,
inner: macho.SuperBlob = .{
    .magic = macho.CSMAGIC_EMBEDDED_SIGNATURE,
    .length = @sizeOf(macho.SuperBlob),
    .count = 0,
},
blob: ?Blob = null,

pub fn init(alloc: *Allocator) CodeSignature {
    return .{
        .alloc = alloc,
    };
}

pub fn calcAdhocSignature(self: *CodeSignature) !void {
    var blob = Blob{
        .inner = .{
            .magic = macho.CSMAGIC_CODEDIRECTORY,
            .length = @sizeOf(macho.CodeDirectory),
            .version = 0x20400,
            .flags = 0,
            .hashOffset = 0,
            .identOffset = 0,
            .nSpecialSlots = 0,
            .nCodeSlots = 0,
            .codeLimit = 0,
            .hashSize = 0,
            .hashType = 0,
            .platform = 0,
            .pageSize = 0,
            .spare2 = 0,
            .scatterOffset = 0,
            .teamOffset = 0,
            .spare3 = 0,
            .codeLimit64 = 0,
            .execSegBase = 0,
            .execSegLimit = 0,
            .execSegFlags = 0,
        },
    };
    self.inner.length += @sizeOf(macho.BlobIndex) + blob.size();
    self.inner.count = 1;
    self.blob = blob;
}

pub fn size(self: CodeSignature) u32 {
    return self.inner.length;
}

pub fn write(self: CodeSignature, buffer: []u8) void {
    assert(buffer.len >= self.inner.length);
    self.writeHeader(buffer);
    const offset: u32 = @sizeOf(macho.SuperBlob) + @sizeOf(macho.BlobIndex);
    writeBlobIndex(macho.CSSLOT_CODEDIRECTORY, offset, buffer[@sizeOf(macho.SuperBlob)..]);
    self.blob.?.write(buffer[offset..]);
}

pub fn deinit(self: *CodeSignature) void {
    if (self.blob) |*b| {
        b.data.deinit(self.alloc);
    }
}

fn writeHeader(self: CodeSignature, buffer: []u8) void {
    assert(buffer.len >= @sizeOf(macho.SuperBlob));
    mem.writeIntBig(u32, buffer[0..4], self.inner.magic);
    mem.writeIntBig(u32, buffer[4..8], self.inner.length);
    mem.writeIntBig(u32, buffer[8..12], self.inner.count);
}

fn writeBlobIndex(tt: u32, offset: u32, buffer: []u8) void {
    assert(buffer.len >= @sizeOf(macho.BlobIndex));
    mem.writeIntBig(u32, buffer[0..4], tt);
    mem.writeIntBig(u32, buffer[4..8], offset);
}

test "CodeSignature header" {
    var code_sig = CodeSignature.init(testing.allocator);
    defer code_sig.deinit();

    var buffer: [@sizeOf(macho.SuperBlob)]u8 = undefined;
    code_sig.writeHeader(buffer[0..]);

    const expected = &[_]u8{ 0xfa, 0xde, 0x0c, 0xc0, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0, 0x0 };
    testing.expect(mem.eql(u8, expected[0..], buffer[0..]));
}
