const Decompress = @This();
const std = @import("../../std.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Crc32 = std.hash.Crc32;
const Crc64 = std.hash.crc.Crc64Xz;
const Sha256 = std.crypto.hash.sha2.Sha256;
const lzma2 = std.compress.lzma2;
const Writer = std.Io.Writer;
const Reader = std.Io.Reader;

/// Underlying compressed data stream to pull bytes from.
input: *Reader,
/// Uncompressed bytes output by this stream implementation.
reader: Reader,
gpa: Allocator,
check: Check,
block_count: usize,
err: ?Error,

pub const Error = error{
    ReadFailed,
    OutOfMemory,
    CorruptInput,
    EndOfStream,
    WrongChecksum,
    Unsupported,
    Overflow,
    InvalidRangeCode,
    DecompressedSizeMismatch,
};

pub const Check = enum(u4) {
    none = 0x00,
    crc32 = 0x01,
    crc64 = 0x04,
    sha256 = 0x0A,
    _,
};

pub const StreamFlags = packed struct(u16) {
    null: u8 = 0,
    check: Check,
    reserved: u4 = 0,
};

pub const InitError = error{
    NotXzStream,
    WrongChecksum,
};

/// XZ uses a series of LZMA2 blocks which each specify a dictionary size
/// anywhere from 4K to 4G. Thus, this API dynamically allocates the dictionary
/// as-needed.
pub fn init(
    input: *Reader,
    gpa: Allocator,
    /// Decompress takes ownership of this buffer and resizes it with `gpa`.
    buffer: []u8,
) !Decompress {
    const magic = try input.takeArray(6);
    if (!std.mem.eql(u8, magic, &.{ 0xFD, '7', 'z', 'X', 'Z', 0x00 }))
        return error.NotXzStream;

    const actual_hash = Crc32.hash(try input.peek(@sizeOf(StreamFlags)));
    const stream_flags = input.takeStruct(StreamFlags, .little) catch unreachable;
    const stored_hash = try input.takeInt(u32, .little);
    if (actual_hash != stored_hash) return error.WrongChecksum;

    return .{
        .input = input,
        .reader = .{
            .vtable = &.{
                .stream = stream,
                .readVec = readVec,
                .discard = discard,
            },
            .buffer = buffer,
            .seek = 0,
            .end = 0,
        },
        .gpa = gpa,
        .check = stream_flags.check,
        .block_count = 0,
        .err = null,
    };
}

/// Reclaim ownership of the buffer passed to `init`.
pub fn takeBuffer(d: *Decompress) []u8 {
    const buffer = d.reader.buffer;
    d.reader.buffer = &.{};
    return buffer;
}

pub fn deinit(d: *Decompress) void {
    const gpa = d.gpa;
    gpa.free(d.reader.buffer);
    d.* = undefined;
}

fn readVec(r: *Reader, data: [][]u8) Reader.Error!usize {
    _ = data;
    return readIndirect(r);
}

fn stream(r: *Reader, w: *Writer, limit: std.Io.Limit) Reader.StreamError!usize {
    _ = w;
    _ = limit;
    return readIndirect(r);
}

fn discard(r: *Reader, limit: std.Io.Limit) Reader.Error!usize {
    const d: *Decompress = @alignCast(@fieldParentPtr("reader", r));
    _ = d;
    _ = limit;
    @panic("TODO");
}

fn readIndirect(r: *Reader) Reader.Error!usize {
    const d: *Decompress = @alignCast(@fieldParentPtr("reader", r));
    const gpa = d.gpa;
    const input = d.input;

    var allocating = Writer.Allocating.initOwnedSlice(gpa, r.buffer);
    allocating.writer.end = r.end;
    defer {
        r.buffer = allocating.writer.buffer;
        r.end = allocating.writer.end;
    }

    if (d.block_count == std.math.maxInt(usize)) return error.EndOfStream;

    readBlock(input, &allocating) catch |err| switch (err) {
        error.WriteFailed => {
            d.err = error.OutOfMemory;
            return error.ReadFailed;
        },
        error.SuccessfulEndOfStream => {
            finish(d);
            d.block_count = std.math.maxInt(usize);
            return error.EndOfStream;
        },
        else => |e| {
            d.err = e;
            return error.ReadFailed;
        },
    };
    switch (d.check) {
        .none => {},
        .crc32 => {
            const declared_checksum = try input.takeInt(u32, .little);
            // TODO
            //const hash_a = Crc32.hash(unpacked_bytes);
            //if (hash_a != hash_b) return error.WrongChecksum;
            _ = declared_checksum;
        },
        .crc64 => {
            const declared_checksum = try input.takeInt(u64, .little);
            // TODO
            //const hash_a = Crc64.hash(unpacked_bytes);
            //if (hash_a != hash_b) return error.WrongChecksum;
            _ = declared_checksum;
        },
        .sha256 => {
            const declared_hash = try input.take(Sha256.digest_length);
            // TODO
            //var hash_a: [Sha256.digest_length]u8 = undefined;
            //Sha256.hash(unpacked_bytes, &hash_a, .{});
            //if (!std.mem.eql(u8, &hash_a, &hash_b))
            //    return error.WrongChecksum;
            _ = declared_hash;
        },
        else => {
            d.err = error.Unsupported;
            return error.ReadFailed;
        },
    }
    d.block_count += 1;
    return 0;
}

fn readBlock(input: *Reader, allocating: *Writer.Allocating) !void {
    var packed_size: ?u64 = null;
    var unpacked_size: ?u64 = null;

    {
        // Read the block header via peeking so that we can hash the whole thing too.
        const first_byte: usize = try input.peekByte();
        if (first_byte == 0) return error.SuccessfulEndOfStream;

        const declared_header_size = first_byte * 4;
        try input.fill(declared_header_size);
        const header_seek_start = input.seek;
        input.toss(1);

        const Flags = packed struct(u8) {
            last_filter_index: u2,
            reserved: u4,
            has_packed_size: bool,
            has_unpacked_size: bool,
        };
        const flags = try input.takeStruct(Flags, .little);

        const filter_count = @as(u3, flags.last_filter_index) + 1;
        if (filter_count > 1) return error.Unsupported;

        if (flags.has_packed_size) packed_size = try input.takeLeb128(u64);
        if (flags.has_unpacked_size) unpacked_size = try input.takeLeb128(u64);

        const FilterId = enum(u64) {
            lzma2 = 0x21,
            _,
        };

        const filter_id: FilterId = @enumFromInt(try input.takeLeb128(u64));
        if (filter_id != .lzma2) return error.Unsupported;

        const properties_size = try input.takeLeb128(u64);
        if (properties_size != 1) return error.CorruptInput;
        // TODO: use filter properties
        _ = try input.takeByte();

        const actual_header_size = input.seek - header_seek_start;
        if (actual_header_size > declared_header_size) return error.CorruptInput;
        var remaining_bytes = declared_header_size - actual_header_size;
        while (remaining_bytes != 0) {
            if (try input.takeByte() != 0) return error.CorruptInput;
            remaining_bytes -= 1;
        }

        const header_slice = input.buffer[header_seek_start..][0..declared_header_size];
        const actual_hash = Crc32.hash(header_slice);
        const declared_hash = try input.takeInt(u32, .little);
        if (actual_hash != declared_hash) return error.WrongChecksum;
    }

    // Compressed Data

    var lzma2_decode = try lzma2.Decode.init(allocating.allocator);
    const before_size = allocating.writer.end;
    try lzma2_decode.decompress(input, allocating);
    const unpacked_bytes = allocating.writer.end - before_size;

    // TODO restore this check
    //if (packed_size) |s| {
    //    if (s != packed_counter.bytes_read)
    //        return error.CorruptInput;
    //}

    if (unpacked_size) |s| {
        if (s != unpacked_bytes) return error.CorruptInput;
    }

    // Block Padding
    if (true) @panic("TODO account for block padding");
    //while (block_counter.bytes_read % 4 != 0) {
    //    if (try block_reader.takeByte() != 0)
    //        return error.CorruptInput;
    //}

}

fn finish(d: *Decompress) void {
    _ = d;
    @panic("TODO");
    //const input = d.input;
    //const index_size = blk: {
    //    const record_count = try input.takeLeb128(u64);
    //    if (record_count != d.block_decode.block_count)
    //        return error.CorruptInput;

    //    var i: usize = 0;
    //    while (i < record_count) : (i += 1) {
    //        // TODO: validate records
    //        _ = try std.leb.readUleb128(u64, counting_reader);
    //        _ = try std.leb.readUleb128(u64, counting_reader);
    //    }

    //    while (counter.bytes_read % 4 != 0) {
    //        if (try counting_reader.takeByte() != 0)
    //            return error.CorruptInput;
    //    }

    //    const hash_a = hasher.hasher.final();
    //    const hash_b = try counting_reader.takeInt(u32, .little);
    //    if (hash_a != hash_b)
    //        return error.WrongChecksum;

    //    break :blk counter.bytes_read;
    //};

    //const hash_a = try d.in_reader.takeInt(u32, .little);

    //const hash_b = blk: {
    //    var hasher = hashedReader(d.in_reader, Crc32.init());
    //    const hashed_reader = hasher.reader();

    //    const backward_size = (@as(u64, try hashed_reader.takeInt(u32, .little)) + 1) * 4;
    //    if (backward_size != index_size)
    //        return error.CorruptInput;

    //    var check: Check = undefined;
    //    try readStreamFlags(hashed_reader, &check);

    //    break :blk hasher.hasher.final();
    //};

    //if (hash_a != hash_b)
    //    return error.WrongChecksum;

    //const magic = try d.in_reader.takeBytesNoEof(2);
    //if (!std.mem.eql(u8, &magic, &.{ 'Y', 'Z' }))
    //    return error.CorruptInput;

    //return 0;
}
