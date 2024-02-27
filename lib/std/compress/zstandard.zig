const std = @import("std");
const RingBuffer = std.RingBuffer;

const types = @import("zstandard/types.zig");
pub const frame = types.frame;
pub const compressed_block = types.compressed_block;

pub const decompress = @import("zstandard/decompress.zig");

pub const DecompressorOptions = struct {
    verify_checksum: bool = true,
    window_buffer: []u8,

    /// Recommended amount by the standard. Lower than this may result
    /// in inability to decompress common streams.
    pub const default_window_buffer_len = 8 * 1024 * 1024;
};

pub fn Decompressor(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        const table_size_max = types.compressed_block.table_size_max;

        source: std.io.CountingReader(ReaderType),
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

        const WindowBuffer = struct {
            data: []u8 = undefined,
            read_index: usize = 0,
            write_index: usize = 0,
        };

        pub const Error = ReaderType.Error || error{
            ChecksumFailure,
            DictionaryIdFlagUnsupported,
            MalformedBlock,
            MalformedFrame,
            OutOfMemory,
        };

        pub const Reader = std.io.Reader(*Self, Error, read);

        pub fn init(source: ReaderType, options: DecompressorOptions) Self {
            return .{
                .source = std.io.countingReader(source),
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

        fn frameInit(self: *Self) !void {
            const source_reader = self.source.reader();
            switch (try decompress.decodeFrameHeader(source_reader)) {
                .skippable => |header| {
                    try source_reader.skipBytes(header.frame_size, .{});
                    self.state = .NewFrame;
                },
                .zstandard => |header| {
                    const frame_context = try decompress.FrameContext.init(
                        header,
                        self.buffer.data.len,
                        self.verify_checksum,
                    );

                    const decode_state = decompress.block.DecodeState.init(
                        &self.literal_fse_buffer,
                        &self.match_fse_buffer,
                        &self.offset_fse_buffer,
                    );

                    self.decode_state = decode_state;
                    self.frame_context = frame_context;

                    self.checksum = null;
                    self.current_frame_decompressed_size = 0;

                    self.state = .InFrame;
                },
            }
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn read(self: *Self, buffer: []u8) Error!usize {
            if (buffer.len == 0) return 0;

            var size: usize = 0;
            while (size == 0) {
                while (self.state == .NewFrame) {
                    const initial_count = self.source.bytes_read;
                    self.frameInit() catch |err| switch (err) {
                        error.DictionaryIdFlagUnsupported => return error.DictionaryIdFlagUnsupported,
                        error.EndOfStream => return if (self.source.bytes_read == initial_count)
                            0
                        else
                            error.MalformedFrame,
                        else => return error.MalformedFrame,
                    };
                }
                size = try self.readInner(buffer);
            }
            return size;
        }

        fn readInner(self: *Self, buffer: []u8) Error!usize {
            std.debug.assert(self.state != .NewFrame);

            var ring_buffer = RingBuffer{
                .data = self.buffer.data,
                .read_index = self.buffer.read_index,
                .write_index = self.buffer.write_index,
            };
            defer {
                self.buffer.read_index = ring_buffer.read_index;
                self.buffer.write_index = ring_buffer.write_index;
            }

            const source_reader = self.source.reader();
            while (ring_buffer.isEmpty() and self.state != .LastBlock) {
                const header_bytes = source_reader.readBytesNoEof(3) catch
                    return error.MalformedFrame;
                const block_header = decompress.block.decodeBlockHeader(&header_bytes);

                decompress.block.decodeBlockReader(
                    &ring_buffer,
                    source_reader,
                    block_header,
                    &self.decode_state,
                    self.frame_context.block_size_max,
                    &self.literals_buffer,
                    &self.sequence_buffer,
                ) catch
                    return error.MalformedBlock;

                if (self.frame_context.content_size) |size| {
                    if (self.current_frame_decompressed_size > size) return error.MalformedFrame;
                }

                const size = ring_buffer.len();
                self.current_frame_decompressed_size += size;

                if (self.frame_context.hasher_opt) |*hasher| {
                    if (size > 0) {
                        const written_slice = ring_buffer.sliceLast(size);
                        hasher.update(written_slice.first);
                        hasher.update(written_slice.second);
                    }
                }
                if (block_header.last_block) {
                    self.state = .LastBlock;
                    if (self.frame_context.has_checksum) {
                        const checksum = source_reader.readInt(u32, .little) catch
                            return error.MalformedFrame;
                        if (self.verify_checksum) {
                            if (self.frame_context.hasher_opt) |*hasher| {
                                if (checksum != decompress.computeChecksum(hasher))
                                    return error.ChecksumFailure;
                            }
                        }
                    }
                    if (self.frame_context.content_size) |content_size| {
                        if (content_size != self.current_frame_decompressed_size) {
                            return error.MalformedFrame;
                        }
                    }
                }
            }

            const size = @min(ring_buffer.len(), buffer.len);
            if (size > 0) {
                ring_buffer.readFirstAssumeLength(buffer, size);
            }
            if (self.state == .LastBlock and ring_buffer.len() == 0) {
                self.state = .NewFrame;
            }
            return size;
        }
    };
}

pub fn decompressor(reader: anytype, options: DecompressorOptions) Decompressor(@TypeOf(reader)) {
    return Decompressor(@TypeOf(reader)).init(reader, options);
}

fn testDecompress(data: []const u8) ![]u8 {
    const window_buffer = try std.testing.allocator.alloc(u8, 1 << 23);
    defer std.testing.allocator.free(window_buffer);

    var in_stream = std.io.fixedBufferStream(data);
    var zstd_stream = decompressor(in_stream.reader(), .{ .window_buffer = window_buffer });
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
    var stream = decompressor(in_stream.reader(), .{ .window_buffer = window_buffer });

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
