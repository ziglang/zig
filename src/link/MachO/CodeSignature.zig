const CodeSignature = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;
const testing = std.testing;
const trace = @import("../../tracy.zig").trace;
const Allocator = mem.Allocator;
const Hasher = @import("hasher.zig").ParallelHasher;
const MachO = @import("../MachO.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;

const hash_size = Sha256.digest_length;

const Blob = union(enum) {
    code_directory: *CodeDirectory,
    requirements: *Requirements,
    entitlements: *Entitlements,
    signature: *Signature,

    fn slotType(self: Blob) u32 {
        return switch (self) {
            .code_directory => |x| x.slotType(),
            .requirements => |x| x.slotType(),
            .entitlements => |x| x.slotType(),
            .signature => |x| x.slotType(),
        };
    }

    fn size(self: Blob) u32 {
        return switch (self) {
            .code_directory => |x| x.size(),
            .requirements => |x| x.size(),
            .entitlements => |x| x.size(),
            .signature => |x| x.size(),
        };
    }

    fn write(self: Blob, writer: anytype) !void {
        return switch (self) {
            .code_directory => |x| x.write(writer),
            .requirements => |x| x.write(writer),
            .entitlements => |x| x.write(writer),
            .signature => |x| x.write(writer),
        };
    }
};

const CodeDirectory = struct {
    inner: macho.CodeDirectory,
    ident: []const u8,
    special_slots: [n_special_slots][hash_size]u8,
    code_slots: std.ArrayListUnmanaged([hash_size]u8) = .empty,

    const n_special_slots: usize = 7;

    fn init(page_size: u16) CodeDirectory {
        var cdir: CodeDirectory = .{
            .inner = .{
                .magic = macho.CSMAGIC_CODEDIRECTORY,
                .length = @sizeOf(macho.CodeDirectory),
                .version = macho.CS_SUPPORTSEXECSEG,
                .flags = macho.CS_ADHOC | macho.CS_LINKER_SIGNED,
                .hashOffset = 0,
                .identOffset = @sizeOf(macho.CodeDirectory),
                .nSpecialSlots = 0,
                .nCodeSlots = 0,
                .codeLimit = 0,
                .hashSize = hash_size,
                .hashType = macho.CS_HASHTYPE_SHA256,
                .platform = 0,
                .pageSize = @as(u8, @truncate(std.math.log2(page_size))),
                .spare2 = 0,
                .scatterOffset = 0,
                .teamOffset = 0,
                .spare3 = 0,
                .codeLimit64 = 0,
                .execSegBase = 0,
                .execSegLimit = 0,
                .execSegFlags = 0,
            },
            .ident = undefined,
            .special_slots = undefined,
        };
        comptime var i = 0;
        inline while (i < n_special_slots) : (i += 1) {
            cdir.special_slots[i] = [_]u8{0} ** hash_size;
        }
        return cdir;
    }

    fn deinit(self: *CodeDirectory, allocator: Allocator) void {
        self.code_slots.deinit(allocator);
    }

    fn addSpecialHash(self: *CodeDirectory, index: u32, hash: [hash_size]u8) void {
        assert(index > 0);
        self.inner.nSpecialSlots = @max(self.inner.nSpecialSlots, index);
        @memcpy(&self.special_slots[index - 1], &hash);
    }

    fn slotType(self: CodeDirectory) u32 {
        _ = self;
        return macho.CSSLOT_CODEDIRECTORY;
    }

    fn size(self: CodeDirectory) u32 {
        const code_slots = self.inner.nCodeSlots * hash_size;
        const special_slots = self.inner.nSpecialSlots * hash_size;
        return @sizeOf(macho.CodeDirectory) + @as(u32, @intCast(self.ident.len + 1 + special_slots + code_slots));
    }

    fn write(self: CodeDirectory, writer: anytype) !void {
        try writer.writeInt(u32, self.inner.magic, .big);
        try writer.writeInt(u32, self.inner.length, .big);
        try writer.writeInt(u32, self.inner.version, .big);
        try writer.writeInt(u32, self.inner.flags, .big);
        try writer.writeInt(u32, self.inner.hashOffset, .big);
        try writer.writeInt(u32, self.inner.identOffset, .big);
        try writer.writeInt(u32, self.inner.nSpecialSlots, .big);
        try writer.writeInt(u32, self.inner.nCodeSlots, .big);
        try writer.writeInt(u32, self.inner.codeLimit, .big);
        try writer.writeByte(self.inner.hashSize);
        try writer.writeByte(self.inner.hashType);
        try writer.writeByte(self.inner.platform);
        try writer.writeByte(self.inner.pageSize);
        try writer.writeInt(u32, self.inner.spare2, .big);
        try writer.writeInt(u32, self.inner.scatterOffset, .big);
        try writer.writeInt(u32, self.inner.teamOffset, .big);
        try writer.writeInt(u32, self.inner.spare3, .big);
        try writer.writeInt(u64, self.inner.codeLimit64, .big);
        try writer.writeInt(u64, self.inner.execSegBase, .big);
        try writer.writeInt(u64, self.inner.execSegLimit, .big);
        try writer.writeInt(u64, self.inner.execSegFlags, .big);

        try writer.writeAll(self.ident);
        try writer.writeByte(0);

        var i: isize = @as(isize, @intCast(self.inner.nSpecialSlots));
        while (i > 0) : (i -= 1) {
            try writer.writeAll(&self.special_slots[@as(usize, @intCast(i - 1))]);
        }

        for (self.code_slots.items) |slot| {
            try writer.writeAll(&slot);
        }
    }
};

const Requirements = struct {
    fn deinit(self: *Requirements, allocator: Allocator) void {
        _ = self;
        _ = allocator;
    }

    fn slotType(self: Requirements) u32 {
        _ = self;
        return macho.CSSLOT_REQUIREMENTS;
    }

    fn size(self: Requirements) u32 {
        _ = self;
        return 3 * @sizeOf(u32);
    }

    fn write(self: Requirements, writer: anytype) !void {
        try writer.writeInt(u32, macho.CSMAGIC_REQUIREMENTS, .big);
        try writer.writeInt(u32, self.size(), .big);
        try writer.writeInt(u32, 0, .big);
    }
};

const Entitlements = struct {
    inner: []const u8,

    fn deinit(self: *Entitlements, allocator: Allocator) void {
        allocator.free(self.inner);
    }

    fn slotType(self: Entitlements) u32 {
        _ = self;
        return macho.CSSLOT_ENTITLEMENTS;
    }

    fn size(self: Entitlements) u32 {
        return @as(u32, @intCast(self.inner.len)) + 2 * @sizeOf(u32);
    }

    fn write(self: Entitlements, writer: anytype) !void {
        try writer.writeInt(u32, macho.CSMAGIC_EMBEDDED_ENTITLEMENTS, .big);
        try writer.writeInt(u32, self.size(), .big);
        try writer.writeAll(self.inner);
    }
};

const Signature = struct {
    fn deinit(self: *Signature, allocator: Allocator) void {
        _ = self;
        _ = allocator;
    }

    fn slotType(self: Signature) u32 {
        _ = self;
        return macho.CSSLOT_SIGNATURESLOT;
    }

    fn size(self: Signature) u32 {
        _ = self;
        return 2 * @sizeOf(u32);
    }

    fn write(self: Signature, writer: anytype) !void {
        try writer.writeInt(u32, macho.CSMAGIC_BLOBWRAPPER, .big);
        try writer.writeInt(u32, self.size(), .big);
    }
};

page_size: u16,
code_directory: CodeDirectory,
requirements: ?Requirements = null,
entitlements: ?Entitlements = null,
signature: ?Signature = null,

pub fn init(page_size: u16) CodeSignature {
    return .{
        .page_size = page_size,
        .code_directory = CodeDirectory.init(page_size),
    };
}

pub fn deinit(self: *CodeSignature, allocator: Allocator) void {
    self.code_directory.deinit(allocator);
    if (self.requirements) |*req| {
        req.deinit(allocator);
    }
    if (self.entitlements) |*ents| {
        ents.deinit(allocator);
    }
    if (self.signature) |*sig| {
        sig.deinit(allocator);
    }
}

pub fn addEntitlements(self: *CodeSignature, allocator: Allocator, path: []const u8) !void {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();
    const inner = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
    self.entitlements = .{ .inner = inner };
}

pub const WriteOpts = struct {
    file: fs.File,
    exec_seg_base: u64,
    exec_seg_limit: u64,
    file_size: u32,
    dylib: bool,
};

pub fn writeAdhocSignature(
    self: *CodeSignature,
    macho_file: *MachO,
    opts: WriteOpts,
    writer: anytype,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const allocator = macho_file.base.comp.gpa;

    var header: macho.SuperBlob = .{
        .magic = macho.CSMAGIC_EMBEDDED_SIGNATURE,
        .length = @sizeOf(macho.SuperBlob),
        .count = 0,
    };

    var blobs = std.ArrayList(Blob).init(allocator);
    defer blobs.deinit();

    self.code_directory.inner.execSegBase = opts.exec_seg_base;
    self.code_directory.inner.execSegLimit = opts.exec_seg_limit;
    self.code_directory.inner.execSegFlags = if (!opts.dylib) macho.CS_EXECSEG_MAIN_BINARY else 0;
    self.code_directory.inner.codeLimit = opts.file_size;

    const total_pages = @as(u32, @intCast(mem.alignForward(usize, opts.file_size, self.page_size) / self.page_size));

    try self.code_directory.code_slots.ensureTotalCapacityPrecise(allocator, total_pages);
    self.code_directory.code_slots.items.len = total_pages;
    self.code_directory.inner.nCodeSlots = total_pages;

    // Calculate hash for each page (in file) and write it to the buffer
    var hasher = Hasher(Sha256){ .allocator = allocator, .thread_pool = macho_file.base.comp.thread_pool };
    try hasher.hash(opts.file, self.code_directory.code_slots.items, .{
        .chunk_size = self.page_size,
        .max_file_size = opts.file_size,
    });

    try blobs.append(.{ .code_directory = &self.code_directory });
    header.length += @sizeOf(macho.BlobIndex);
    header.count += 1;

    var hash: [hash_size]u8 = undefined;

    if (self.requirements) |*req| {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        try req.write(buf.writer());
        Sha256.hash(buf.items, &hash, .{});
        self.code_directory.addSpecialHash(req.slotType(), hash);

        try blobs.append(.{ .requirements = req });
        header.count += 1;
        header.length += @sizeOf(macho.BlobIndex) + req.size();
    }

    if (self.entitlements) |*ents| {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        try ents.write(buf.writer());
        Sha256.hash(buf.items, &hash, .{});
        self.code_directory.addSpecialHash(ents.slotType(), hash);

        try blobs.append(.{ .entitlements = ents });
        header.count += 1;
        header.length += @sizeOf(macho.BlobIndex) + ents.size();
    }

    if (self.signature) |*sig| {
        try blobs.append(.{ .signature = sig });
        header.count += 1;
        header.length += @sizeOf(macho.BlobIndex) + sig.size();
    }

    self.code_directory.inner.hashOffset =
        @sizeOf(macho.CodeDirectory) + @as(u32, @intCast(self.code_directory.ident.len + 1 + self.code_directory.inner.nSpecialSlots * hash_size));
    self.code_directory.inner.length = self.code_directory.size();
    header.length += self.code_directory.size();

    try writer.writeInt(u32, header.magic, .big);
    try writer.writeInt(u32, header.length, .big);
    try writer.writeInt(u32, header.count, .big);

    var offset: u32 = @sizeOf(macho.SuperBlob) + @sizeOf(macho.BlobIndex) * @as(u32, @intCast(blobs.items.len));
    for (blobs.items) |blob| {
        try writer.writeInt(u32, blob.slotType(), .big);
        try writer.writeInt(u32, offset, .big);
        offset += blob.size();
    }

    for (blobs.items) |blob| {
        try blob.write(writer);
    }
}

pub fn size(self: CodeSignature) u32 {
    var ssize: u32 = @sizeOf(macho.SuperBlob) + @sizeOf(macho.BlobIndex) + self.code_directory.size();
    if (self.requirements) |req| {
        ssize += @sizeOf(macho.BlobIndex) + req.size();
    }
    if (self.entitlements) |ent| {
        ssize += @sizeOf(macho.BlobIndex) + ent.size();
    }
    if (self.signature) |sig| {
        ssize += @sizeOf(macho.BlobIndex) + sig.size();
    }
    return ssize;
}

pub fn estimateSize(self: CodeSignature, file_size: u64) u32 {
    var ssize: u64 = @sizeOf(macho.SuperBlob) + @sizeOf(macho.BlobIndex) + self.code_directory.size();
    // Approx code slots
    const total_pages = mem.alignForward(u64, file_size, self.page_size) / self.page_size;
    ssize += total_pages * hash_size;
    var n_special_slots: u32 = 0;
    if (self.requirements) |req| {
        ssize += @sizeOf(macho.BlobIndex) + req.size();
        n_special_slots = @max(n_special_slots, req.slotType());
    }
    if (self.entitlements) |ent| {
        ssize += @sizeOf(macho.BlobIndex) + ent.size() + hash_size;
        n_special_slots = @max(n_special_slots, ent.slotType());
    }
    if (self.signature) |sig| {
        ssize += @sizeOf(macho.BlobIndex) + sig.size();
    }
    ssize += n_special_slots * hash_size;
    return @as(u32, @intCast(mem.alignForward(u64, ssize, @sizeOf(u64))));
}

pub fn clear(self: *CodeSignature, allocator: Allocator) void {
    self.code_directory.deinit(allocator);
    self.code_directory = CodeDirectory.init(self.page_size);
}
