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

const CodeDirectory = struct {
    inner: macho.CodeDirectory,
    data: std.ArrayListUnmanaged(u8) = .{},

    fn size(self: CodeDirectory) u32 {
        return self.inner.length;
    }

    fn write(self: CodeDirectory, writer: anytype) !void {
        try writer.writeIntBig(u32, self.inner.magic);
        try writer.writeIntBig(u32, self.inner.length);
        try writer.writeIntBig(u32, self.inner.version);
        try writer.writeIntBig(u32, self.inner.flags);
        try writer.writeIntBig(u32, self.inner.hashOffset);
        try writer.writeIntBig(u32, self.inner.identOffset);
        try writer.writeIntBig(u32, self.inner.nSpecialSlots);
        try writer.writeIntBig(u32, self.inner.nCodeSlots);
        try writer.writeIntBig(u32, self.inner.codeLimit);
        try writer.writeByte(self.inner.hashSize);
        try writer.writeByte(self.inner.hashType);
        try writer.writeByte(self.inner.platform);
        try writer.writeByte(self.inner.pageSize);
        try writer.writeIntBig(u32, self.inner.spare2);
        try writer.writeIntBig(u32, self.inner.scatterOffset);
        try writer.writeIntBig(u32, self.inner.teamOffset);
        try writer.writeIntBig(u32, self.inner.spare3);
        try writer.writeIntBig(u64, self.inner.codeLimit64);
        try writer.writeIntBig(u64, self.inner.execSegBase);
        try writer.writeIntBig(u64, self.inner.execSegLimit);
        try writer.writeIntBig(u64, self.inner.execSegFlags);
        try writer.writeAll(self.data.items);
    }
};

allocator: *Allocator,

/// Code signature blob header.
inner: macho.SuperBlob = .{
    .magic = macho.CSMAGIC_EMBEDDED_SIGNATURE,
    .length = @sizeOf(macho.SuperBlob),
    .count = 0,
},

/// CodeDirectory header which holds the hash of the binary.
cdir: ?CodeDirectory = null,

/// Page size is dependent on the target cpu architecture.
/// For x86_64 that's 4KB, whereas for aarch64, that's 16KB.
page_size: u16,

pub fn init(allocator: *Allocator, page_size: u16) CodeSignature {
    return .{
        .allocator = allocator,
        .page_size = page_size,
    };
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
            .codeLimit = file_size,
            .hashSize = hash_size,
            .hashType = macho.CS_HASHTYPE_SHA256,
            .platform = 0,
            .pageSize = @truncate(u8, std.math.log2(self.page_size)),
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

    const total_pages = mem.alignForward(file_size, self.page_size) / self.page_size;

    var hash: [hash_size]u8 = undefined;
    var buffer = try self.allocator.alloc(u8, self.page_size);
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
        const fstart = i * self.page_size;
        const fsize = if (fstart + self.page_size > file_size) file_size - fstart else self.page_size;
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

pub fn write(self: CodeSignature, writer: anytype) !void {
    try self.writeHeader(writer);
    const offset: u32 = @sizeOf(macho.SuperBlob) + @sizeOf(macho.BlobIndex);
    try writeBlobIndex(macho.CSSLOT_CODEDIRECTORY, offset, writer);
    try self.cdir.?.write(writer);
}

pub fn deinit(self: *CodeSignature) void {
    if (self.cdir) |*cdir| {
        cdir.data.deinit(self.allocator);
    }
}

fn writeHeader(self: CodeSignature, writer: anytype) !void {
    try writer.writeIntBig(u32, self.inner.magic);
    try writer.writeIntBig(u32, self.inner.length);
    try writer.writeIntBig(u32, self.inner.count);
}

fn writeBlobIndex(tt: u32, offset: u32, writer: anytype) !void {
    try writer.writeIntBig(u32, tt);
    try writer.writeIntBig(u32, offset);
}

test "CodeSignature header" {
    var code_sig = CodeSignature.init(testing.allocator, 0x1000);
    defer code_sig.deinit();

    var buffer: [@sizeOf(macho.SuperBlob)]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);
    try code_sig.writeHeader(stream.writer());

    const expected = &[_]u8{ 0xfa, 0xde, 0x0c, 0xc0, 0x0, 0x0, 0x0, 0xc, 0x0, 0x0, 0x0, 0x0 };
    try testing.expect(mem.eql(u8, expected, &buffer));
}

pub fn calcCodeSignaturePaddingSize(id: []const u8, file_size: u64, page_size: u16) u32 {
    const ident_size = id.len + 1;
    const total_pages = mem.alignForwardGeneric(u64, file_size, page_size) / page_size;
    const hashed_size = total_pages * hash_size;
    const codesig_header = @sizeOf(macho.SuperBlob) + @sizeOf(macho.BlobIndex) + @sizeOf(macho.CodeDirectory);
    return @intCast(u32, mem.alignForwardGeneric(u64, codesig_header + ident_size + hashed_size, @sizeOf(u64)));
}
