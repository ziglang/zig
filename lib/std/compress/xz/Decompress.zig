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
const assert = std.debug.assert;

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
    CompressedSizeMismatch,
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

    const computed_checksum = Crc32.hash(try input.peek(@sizeOf(StreamFlags)));
    const stream_flags = input.takeStruct(StreamFlags, .little) catch unreachable;
    const stored_hash = try input.takeInt(u32, .little);
    if (computed_checksum != stored_hash) return error.WrongChecksum;

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

    if (d.err != null) return error.ReadFailed;
    if (d.block_count == std.math.maxInt(usize)) return error.EndOfStream;

    readBlock(input, &allocating) catch |err| switch (err) {
        error.WriteFailed => {
            d.err = error.OutOfMemory;
            return error.ReadFailed;
        },
        error.SuccessfulEndOfStream => {
            finish(d) catch |finish_err| {
                d.err = finish_err;
                return error.ReadFailed;
            };
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

    const header_size = h: {
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
        const remaining_bytes = declared_header_size - actual_header_size;
        for (0..remaining_bytes) |_| {
            if (try input.takeByte() != 0) return error.CorruptInput;
        }

        const header_slice = input.buffer[header_seek_start..][0..declared_header_size];
        const computed_checksum = Crc32.hash(header_slice);
        const declared_checksum = try input.takeInt(u32, .little);
        if (computed_checksum != declared_checksum) return error.WrongChecksum;
        break :h declared_header_size;
    };

    // Compressed Data

    var lzma2_decode = try lzma2.Decode.init(allocating.allocator);
    defer lzma2_decode.deinit(allocating.allocator);
    const before_size = allocating.writer.end;
    const packed_bytes_read = try lzma2_decode.decompress(input, allocating);
    const unpacked_bytes = allocating.writer.end - before_size;

    if (packed_size) |s| {
        if (s != packed_bytes_read) return error.CorruptInput;
    }

    if (unpacked_size) |s| {
        if (s != unpacked_bytes) return error.CorruptInput;
    }

    // Block Padding
    const block_counter = header_size + packed_bytes_read;
    const padding = try input.take(@intCast((4 - (block_counter % 4)) % 4));
    for (padding) |byte| {
        if (byte != 0) return error.CorruptInput;
    }
}

fn finish(d: *Decompress) !void {
    const input = d.input;
    const index_size = blk: {
        // Assume that we already peeked a zero in readBlock().
        assert(input.buffered()[0] == 0);
        var input_counter: u64 = 1;
        var checksum: Crc32 = .init();
        checksum.update(&.{0});
        input.toss(1);

        const record_count = try countLeb128(input, u64, &input_counter, &checksum);
        if (record_count != d.block_count)
            return error.CorruptInput;

        for (0..@intCast(record_count)) |_| {
            // TODO: validate records
            _ = try countLeb128(input, u64, &input_counter, &checksum);
            _ = try countLeb128(input, u64, &input_counter, &checksum);
        }

        const padding = try input.take(@intCast((4 - (input_counter % 4)) % 4));
        for (padding) |byte| {
            if (byte != 0) return error.CorruptInput;
        }
        checksum.update(padding);

        const declared_checksum = try input.takeInt(u32, .little);
        const computed_checksum = checksum.final();
        if (computed_checksum != declared_checksum) return error.WrongChecksum;

        break :blk input_counter + padding.len + 4;
    };

    const declared_checksum = try input.takeInt(u32, .little);
    const computed_checksum = Crc32.hash(try input.peek(4 + @sizeOf(StreamFlags)));
    if (declared_checksum != computed_checksum) return error.WrongChecksum;
    const backward_size = (@as(u64, try input.takeInt(u32, .little)) + 1) * 4;
    if (backward_size != index_size) return error.CorruptInput;
    input.toss(@sizeOf(StreamFlags));
    if (!std.mem.eql(u8, try input.takeArray(2), &.{ 'Y', 'Z' }))
        return error.CorruptInput;
}

fn countLeb128(reader: *Reader, comptime T: type, counter: *u64, hasher: *Crc32) !T {
    try reader.fill(8);
    const start = reader.seek;
    const result = try reader.takeLeb128(T);
    const read_slice = reader.buffer[start..reader.seek];
    hasher.update(read_slice);
    counter.* += read_slice.len;
    return result;
}
