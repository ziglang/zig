const std = @import("../std.zig");
const RingBuffer = std.RingBuffer;

const types = @import("zstandard/types.zig");

/// Recommended amount by the standard. Lower than this may result in inability
/// to decompress common streams.
pub const default_window_len = 8 * 1024 * 1024;

pub const frame = types.frame;
pub const compressed_block = types.compressed_block;

pub const decompress = @import("zstandard/decompress.zig");

pub const Decompressor = struct {
    const table_size_max = types.compressed_block.table_size_max;

    input: *std.io.BufferedReader,
    bytes_read: usize,
    state: enum { NewFrame, InFrame, LastBlock },
    decode_state: decompress.block.DecodeState,
    frame_context: decompress.FrameContext,
    buffer: WindowBuffer,
    literal_fse_buffer: [table_size_max.literal]types.compressed_block.Table.Fse,
    match_fse_buffer: [table_size_max.match]types.compressed_block.Table.Fse,
    offset_fse_buffer: [table_size_max.offset]types.compressed_block.Table.Fse,
    literals_buffer: [types.block_size_max]u8,
    sequence_buffer: [types.block_size_max]u8,
    verify_checksum: bool,
    checksum: ?u32,
    current_frame_decompressed_size: usize,
    err: ?Error = null,

    pub const Options = struct {
        verify_checksum: bool = true,
        /// See `default_window_len`.
        window_buffer: []u8,
    };

    const WindowBuffer = struct {
        data: []u8 = undefined,
        read_index: usize = 0,
        write_index: usize = 0,
    };

    pub const Error = std.io.Reader.Error || error{
        ChecksumFailure,
        DictionaryIdFlagUnsupported,
        MalformedBlock,
        MalformedFrame,
        OutOfMemory,
        EndOfStream,
    };

    pub fn init(input: *std.io.BufferedReader, options: Options) Decompressor {
        return .{
            .input = input,
            .bytes_read = 0,
            .state = .NewFrame,
            .decode_state = undefined,
            .frame_context = undefined,
            .buffer = .{ .data = options.window_buffer },
            .literal_fse_buffer = undefined,
            .match_fse_buffer = undefined,
            .offset_fse_buffer = undefined,
            .literals_buffer = undefined,
            .sequence_buffer = undefined,
            .verify_checksum = options.verify_checksum,
            .checksum = undefined,
            .current_frame_decompressed_size = undefined,
        };
    }

    fn frameInit(d: *Decompressor) !void {
        const in = d.input;
        switch (try decompress.decodeFrameHeader(in, &d.bytes_read)) {
            .skippable => |header| {
                try in.discardAll(header.frame_size);
                d.bytes_read += header.frame_size;
                d.state = .NewFrame;
            },
            .zstandard => |header| {
                const frame_context = try decompress.FrameContext.init(
                    header,
                    d.buffer.data.len,
                    d.verify_checksum,
                );

                const decode_state = decompress.block.DecodeState.init(
                    &d.literal_fse_buffer,
                    &d.match_fse_buffer,
                    &d.offset_fse_buffer,
                );

                d.decode_state = decode_state;
                d.frame_context = frame_context;

                d.checksum = null;
                d.current_frame_decompressed_size = 0;

                d.state = .InFrame;
            },
        }
    }

    pub fn reader(self: *Decompressor) std.io.Reader {
        return .{
            .context = self,
            .vtable = &.{
                .read = read,
                .readVec = readVec,
                .discard = discard,
            },
        };
    }

    fn read(context: ?*anyopaque, bw: *std.io.BufferedWriter, limit: std.io.Reader.Limit) std.io.Reader.RwError!usize {
        const buf = limit.slice(try bw.writableSliceGreedy(1));
        const n = try readVec(context, &.{buf});
        bw.advance(n);
        return n;
    }

    fn discard(context: ?*anyopaque, limit: std.io.Reader.Limit) std.io.Reader.Error!usize {
        var trash: [128]u8 = undefined;
        const buf = limit.slice(&trash);
        return readVec(context, &.{buf});
    }

    fn readVec(context: ?*anyopaque, data: []const []u8) std.io.Reader.Error!usize {
        const d: *Decompressor = @ptrCast(@alignCast(context));
        if (data.len == 0) return 0;
        const buffer = data[0];
        while (d.state == .NewFrame) {
            const initial_count = d.bytes_read;
            d.frameInit() catch |err| switch (err) {
                error.DictionaryIdFlagUnsupported => {
                    d.err = error.DictionaryIdFlagUnsupported;
                    return error.ReadFailed;
                },
                error.EndOfStream => {
                    if (d.bytes_read == initial_count) return error.EndOfStream;
                    d.err = error.MalformedFrame;
                    return error.ReadFailed;
                },
                else => {
                    d.err = error.MalformedFrame;
                    return error.ReadFailed;
                },
            };
        }
        return d.readInner(buffer) catch |err| {
            d.err = err;
            return error.ReadFailed;
        };
    }

    fn readInner(d: *Decompressor, buffer: []u8) Error!usize {
        std.debug.assert(d.state != .NewFrame);

        var ring_buffer = RingBuffer{
            .data = d.buffer.data,
            .read_index = d.buffer.read_index,
            .write_index = d.buffer.write_index,
        };
        defer {
            d.buffer.read_index = ring_buffer.read_index;
            d.buffer.write_index = ring_buffer.write_index;
        }

        const in = d.input;
        while (ring_buffer.isEmpty() and d.state != .LastBlock) {
            const header_bytes = try in.takeArray(3);
            d.bytes_read += header_bytes.len;
            const block_header = decompress.block.decodeBlockHeader(header_bytes);

            decompress.block.decodeBlockReader(
                &ring_buffer,
                in,
                &d.bytes_read,
                block_header,
                &d.decode_state,
                d.frame_context.block_size_max,
                &d.literals_buffer,
                &d.sequence_buffer,
            ) catch return error.MalformedBlock;

            if (d.frame_context.content_size) |size| {
                if (d.current_frame_decompressed_size > size) return error.MalformedFrame;
            }

            const size = ring_buffer.len();
            d.current_frame_decompressed_size += size;

            if (d.frame_context.hasher_opt) |*hasher| {
                if (size > 0) {
                    const written_slice = ring_buffer.sliceLast(size);
                    hasher.update(written_slice.first);
                    hasher.update(written_slice.second);
                }
            }
            if (block_header.last_block) {
                d.state = .LastBlock;
                if (d.frame_context.has_checksum) {
                    const checksum = in.readInt(u32, .little) catch return error.MalformedFrame;
                    d.bytes_read += 4;
                    if (d.verify_checksum) {
                        if (d.frame_context.hasher_opt) |*hasher| {
                            if (checksum != decompress.computeChecksum(hasher))
                                return error.ChecksumFailure;
                        }
                    }
                }
                if (d.frame_context.content_size) |content_size| {
                    if (content_size != d.current_frame_decompressed_size) {
                        return error.MalformedFrame;
                    }
                }
            }
        }

        const size = @min(ring_buffer.len(), buffer.len);
        if (size > 0) {
            ring_buffer.readFirstAssumeLength(buffer, size);
        }
        if (d.state == .LastBlock and ring_buffer.len() == 0) {
            d.state = .NewFrame;
        }
        return size;
    }
};

fn testDecompress(data: []const u8) ![]u8 {
    const window_buffer = try std.testing.allocator.alloc(u8, 1 << 23);
    defer std.testing.allocator.free(window_buffer);

    var in_stream = std.io.fixedBufferStream(data);
    var zstd_stream: Decompressor = .init(in_stream.reader(), .{ .window_buffer = window_buffer });
    const result = zstd_stream.reader().readAllAlloc(std.testing.allocator, std.math.maxInt(usize));
    return result;
}

fn testReader(data: []const u8, comptime expected: []const u8) !void {
    const buf = try testDecompress(data);
    defer std.testing.allocator.free(buf);
    try std.testing.expectEqualSlices(u8, expected, buf);
}

test "decompression" {
    const uncompressed = @embedFile("testdata/rfc8478.txt");
    const compressed3 = @embedFile("testdata/rfc8478.txt.zst.3");
    const compressed19 = @embedFile("testdata/rfc8478.txt.zst.19");

    const buffer = try std.testing.allocator.alloc(u8, uncompressed.len);
    defer std.testing.allocator.free(buffer);

    const res3 = try decompress.decode(buffer, compressed3, true);
    try std.testing.expectEqual(uncompressed.len, res3);
    try std.testing.expectEqualSlices(u8, uncompressed, buffer);

    @memset(buffer, undefined);
    const res19 = try decompress.decode(buffer, compressed19, true);
    try std.testing.expectEqual(uncompressed.len, res19);
    try std.testing.expectEqualSlices(u8, uncompressed, buffer);

    try testReader(compressed3, uncompressed);
    try testReader(compressed19, uncompressed);
}

fn expectEqualDecoded(expected: []const u8, input: []const u8) !void {
    {
        const result = try decompress.decodeAlloc(std.testing.allocator, input, false, 1 << 23);
        defer std.testing.allocator.free(result);
        try std.testing.expectEqualStrings(expected, result);
    }

    {
        var buffer = try std.testing.allocator.alloc(u8, 2 * expected.len);
        defer std.testing.allocator.free(buffer);

        const size = try decompress.decode(buffer, input, false);
        try std.testing.expectEqualStrings(expected, buffer[0..size]);
    }
}

fn expectEqualDecodedStreaming(expected: []const u8, input: []const u8) !void {
    const window_buffer = try std.testing.allocator.alloc(u8, 1 << 23);
    defer std.testing.allocator.free(window_buffer);

    var in_stream = std.io.fixedBufferStream(input);
    var stream: Decompressor = .init(in_stream.reader(), .{ .window_buffer = window_buffer });

    const result = try stream.reader().readAllAlloc(std.testing.allocator, std.math.maxInt(usize));
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}

test "zero sized block" {
    const input_raw =
        "\x28\xb5\x2f\xfd" ++ // zstandard frame magic number
        "\x20\x00" ++ // frame header: only single_segment_flag set, frame_content_size zero
        "\x01\x00\x00"; // block header with: last_block set, block_type raw, block_size zero

    const input_rle =
        "\x28\xb5\x2f\xfd" ++ // zstandard frame magic number
        "\x20\x00" ++ // frame header: only single_segment_flag set, frame_content_size zero
        "\x03\x00\x00" ++ // block header with: last_block set, block_type rle, block_size zero
        "\xaa"; // block_content

    try expectEqualDecoded("", input_raw);
    try expectEqualDecoded("", input_rle);
    try expectEqualDecodedStreaming("", input_raw);
    try expectEqualDecodedStreaming("", input_rle);
}

test "declared raw literals size too large" {
    const input_raw =
        "\x28\xb5\x2f\xfd" ++ // zstandard frame magic number
        "\x00\x00" ++ // frame header: everything unset, window descriptor zero
        "\x95\x00\x00" ++ // block header with: last_block set, block_type compressed, block_size 18
        "\xbc\xf3\xae" ++ // literals section header with: type raw, size_format 3, regenerated_size 716603
        "\xa5\x9f\xe3"; // some bytes of literal content - the content is shorter than regenerated_size

    // Note that the regenerated_size in the above input is larger than block maximum size, so the
    // block can't be valid as it is a raw literals block.

    var fbs = std.io.fixedBufferStream(input_raw);
    var window: [1024]u8 = undefined;
    var stream: Decompressor = .init(fbs.reader(), .{ .window_buffer = &window });

    var buf: [1024]u8 = undefined;
    try std.testing.expectError(error.MalformedBlock, stream.read(&buf));
}
