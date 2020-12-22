const CodeSignature = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;
const testing = std.testing;
const Allocator = mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;

const hash_size: u8 = 32;
const page_size: u16 = 0x1000;

const CodeDirectory = struct {
    inner: macho.CodeDirectory,
    data: std.ArrayListUnmanaged(u8) = .{},

    fn size(self: CodeDirectory) u32 {
        return self.inner.length;
    }

    fn write(self: CodeDirectory, buffer: []u8) void {
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
        buffer[36] = self.inner.hashSize;
        buffer[37] = self.inner.hashType;
        buffer[38] = self.inner.platform;
        buffer[39] = self.inner.pageSize;
        mem.writeIntBig(u32, buffer[40..44], self.inner.spare2);
        mem.writeIntBig(u32, buffer[44..48], self.inner.scatterOffset);
        mem.writeIntBig(u32, buffer[48..52], self.inner.teamOffset);
        mem.writeIntBig(u32, buffer[52..56], self.inner.spare3);
        mem.writeIntBig(u64, buffer[56..64], self.inner.codeLimit64);
        mem.writeIntBig(u64, buffer[64..72], self.inner.execSegBase);
        mem.writeIntBig(u64, buffer[72..80], self.inner.execSegLimit);
        mem.writeIntBig(u64, buffer[80..88], self.inner.execSegFlags);

        mem.copy(u8, buffer[88..], self.data.items);
    }
};

allocator: *Allocator,
inner: macho.SuperBlob = .{
    .magic = macho.CSMAGIC_EMBEDDED_SIGNATURE,
    .length = @sizeOf(macho.SuperBlob),
    .count = 0,
},
cdir: ?CodeDirectory = null,

pub fn init(allocator: *Allocator) CodeSignature {
    return .{ .allocator = allocator };
}

pub fn calcAdhocSignature(
    self: *CodeSignature,
    file: fs.File,
    id: []const u8,
    text_segment: macho.segment_command_64,
    code_sig_cmd: macho.linkedit_data_command,
    output_mode: std.builtin.OutputMode,
) !void {
    const execSegBase: u64 = text_segment.fileoff;
    const execSegLimit: u64 = text_segment.filesize;
    const execSegFlags: u64 = if (output_mode == .Exe) macho.CS_EXECSEG_MAIN_BINARY else 0;
    const file_size = code_sig_cmd.dataoff;
    var cdir = CodeDirectory{
        .inner = .{
            .magic = macho.CSMAGIC_CODEDIRECTORY,
            .length = @sizeOf(macho.CodeDirectory),
            .version = macho.CS_SUPPORTSEXECSEG,
            .flags = macho.CS_ADHOC,
            .hashOffset = 0,
            .identOffset = 0,
            .nSpecialSlots = 0,
            .nCodeSlots = 0,
            .codeLimit = @intCast(u32, file_size),
            .hashSize = hash_size,
            .hashType = macho.CS_HASHTYPE_SHA256,
            .platform = 0,
            .pageSize = @truncate(u8, std.math.log2(page_size)),
            .spare2 = 0,
            .scatterOffset = 0,
            .teamOffset = 0,
            .spare3 = 0,
            .codeLimit64 = 0,
            .execSegBase = execSegBase,
            .execSegLimit = execSegLimit,
            .execSegFlags = execSegFlags,
        },
    };

    const total_pages = mem.alignForward(file_size, page_size) / page_size;

    var hash: [hash_size]u8 = undefined;
    var buffer = try self.allocator.alloc(u8, page_size);
    defer self.allocator.free(buffer);

    try cdir.data.ensureCapacity(self.allocator, total_pages * hash_size + id.len + 1);

    // 1. Save the identifier and update offsets
    cdir.inner.identOffset = cdir.inner.length;
    cdir.data.appendSliceAssumeCapacity(id);
    cdir.data.appendAssumeCapacity(0);

    // 2. Calculate hash for each page (in file) and write it to the buffer
    // TODO figure out how we can cache several hashes since we won't update
    // every page during incremental linking
    cdir.inner.hashOffset = cdir.inner.identOffset + @intCast(u32, id.len) + 1;
    var i: usize = 0;
    while (i < total_pages) : (i += 1) {
        const fstart = i * page_size;
        const fsize = if (fstart + page_size > file_size) file_size - fstart else page_size;
        const len = try file.preadAll(buffer, fstart);
        assert(fsize <= len);

        Sha256.hash(buffer[0..fsize], &hash, .{});

        cdir.data.appendSliceAssumeCapacity(&hash);
        cdir.inner.nCodeSlots += 1;
    }

    // 3. Update CodeDirectory length
    cdir.inner.length += @intCast(u32, cdir.data.items.len);

    self.inner.length += @sizeOf(macho.BlobIndex) + cdir.size();
    self.inner.count = 1;
    self.cdir = cdir;
}

pub fn size(self: CodeSignature) u32 {
    return self.inner.length;
}

pub fn write(self: CodeSignature, buffer: []u8) void {
    assert(buffer.len >= self.inner.length);
    self.writeHeader(buffer);
    const offset: u32 = @sizeOf(macho.SuperBlob) + @sizeOf(macho.BlobIndex);
    writeBlobIndex(macho.CSSLOT_CODEDIRECTORY, offset, buffer[@sizeOf(macho.SuperBlob)..]);
    self.cdir.?.write(buffer[offset..]);
}

pub fn deinit(self: *CodeSignature) void {
    if (self.cdir) |*cdir| {
        cdir.data.deinit(self.allocator);
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
    code_sig.writeHeader(&buffer);

    const expected = &[_]u8{ 0xfa, 0xde, 0x0c, 0xc0, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0, 0x0 };
    testing.expect(mem.eql(u8, expected, &buffer));
}

pub fn calcCodeSignaturePadding(id: []const u8, file_size: u64) u32 {
    const ident_size = id.len + 1;
    const total_pages = mem.alignForwardGeneric(u64, file_size, page_size) / page_size;
    const hashed_size = total_pages * hash_size;
    const codesig_header = @sizeOf(macho.SuperBlob) + @sizeOf(macho.BlobIndex) + @sizeOf(macho.CodeDirectory);
    return @intCast(u32, mem.alignForwardGeneric(u64, codesig_header + ident_size + hashed_size, @sizeOf(u64)));
}
