const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("zstandard/types.zig");

const RingBuffer = @import("zstandard/RingBuffer.zig");
pub const decompress = @import("zstandard/decompress.zig");
pub usingnamespace @import("zstandard/types.zig");

pub fn ZstandardStream(comptime ReaderType: type, comptime verify_checksum: bool, comptime window_size_max: usize) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        in_reader: ReaderType,
        decode_state: decompress.block.DecodeState,
        frame_context: decompress.FrameContext,
        buffer: RingBuffer,
        last_block: bool,
        literal_fse_buffer: []types.compressed_block.Table.Fse,
        match_fse_buffer: []types.compressed_block.Table.Fse,
        offset_fse_buffer: []types.compressed_block.Table.Fse,
        literals_buffer: []u8,
        sequence_buffer: []u8,
        checksum: if (verify_checksum) ?u32 else void,

        pub const Error = ReaderType.Error || error{ MalformedBlock, MalformedFrame };

        pub const Reader = std.io.Reader(*Self, Error, read);

        pub fn init(allocator: Allocator, source: ReaderType) !Self {
            switch (try decompress.decodeFrameType(source)) {
                .skippable => return error.SkippableFrame,
                .zstandard => {
                    const frame_context = context: {
                        const frame_header = try decompress.decodeZstandardHeader(source);
                        break :context try decompress.FrameContext.init(
                            frame_header,
                            window_size_max,
                            verify_checksum,
                        );
                    };

                    const literal_fse_buffer = try allocator.alloc(
                        types.compressed_block.Table.Fse,
                        types.compressed_block.table_size_max.literal,
                    );
                    errdefer allocator.free(literal_fse_buffer);

                    const match_fse_buffer = try allocator.alloc(
                        types.compressed_block.Table.Fse,
                        types.compressed_block.table_size_max.match,
                    );
                    errdefer allocator.free(match_fse_buffer);

                    const offset_fse_buffer = try allocator.alloc(
                        types.compressed_block.Table.Fse,
                        types.compressed_block.table_size_max.offset,
                    );
                    errdefer allocator.free(offset_fse_buffer);

                    const decode_state = decompress.block.DecodeState.init(
                        literal_fse_buffer,
                        match_fse_buffer,
                        offset_fse_buffer,
                    );
                    const buffer = try RingBuffer.init(allocator, frame_context.window_size);

                    const literals_data = try allocator.alloc(u8, window_size_max);
                    errdefer allocator.free(literals_data);

                    const sequence_data = try allocator.alloc(u8, window_size_max);
                    errdefer allocator.free(sequence_data);

                    return Self{
                        .allocator = allocator,
                        .in_reader = source,
                        .decode_state = decode_state,
                        .frame_context = frame_context,
                        .buffer = buffer,
                        .checksum = if (verify_checksum) null else {},
                        .last_block = false,
                        .literal_fse_buffer = literal_fse_buffer,
                        .match_fse_buffer = match_fse_buffer,
                        .offset_fse_buffer = offset_fse_buffer,
                        .literals_buffer = literals_data,
                        .sequence_buffer = sequence_data,
                    };
                },
            }
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.decode_state.literal_fse_buffer);
            self.allocator.free(self.decode_state.match_fse_buffer);
            self.allocator.free(self.decode_state.offset_fse_buffer);
            self.allocator.free(self.literals_buffer);
            self.allocator.free(self.sequence_buffer);
            self.buffer.deinit(self.allocator);
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn read(self: *Self, buffer: []u8) Error!usize {
            if (buffer.len == 0) return 0;

            if (self.buffer.isEmpty() and !self.last_block) {
                const header_bytes = self.in_reader.readBytesNoEof(3) catch return error.MalformedFrame;
                const block_header = decompress.block.decodeBlockHeader(&header_bytes);

                decompress.block.decodeBlockReader(
                    &self.buffer,
                    self.in_reader,
                    block_header,
                    &self.decode_state,
                    self.frame_context.block_size_max,
                    self.literals_buffer,
                    self.sequence_buffer,
                ) catch
                    return error.MalformedBlock;

                self.last_block = block_header.last_block;
                if (self.frame_context.hasher_opt) |*hasher| {
                    const written_slice = self.buffer.sliceLast(self.buffer.len());
                    hasher.update(written_slice.first);
                    hasher.update(written_slice.second);
                }
                if (block_header.last_block and self.frame_context.has_checksum) {
                    const checksum = self.in_reader.readIntLittle(u32) catch return error.MalformedFrame;
                    if (verify_checksum) self.checksum = checksum;
                }
            }

            const decoded_data_len = self.buffer.len();
            var written_count: usize = 0;
            while (written_count < decoded_data_len and written_count < buffer.len) : (written_count += 1) {
                buffer[written_count] = self.buffer.read().?;
            }
            return written_count;
        }

        pub fn verifyChecksum(self: *Self) !bool {
            if (verify_checksum) {
                if (self.checksum) |checksum| {
                    if (self.frame_context.hasher_opt) |*hasher| {
                        return checksum == decompress.computeChecksum(hasher);
                    }
                }
            }
            return true;
        }
    };
}

pub fn zstandardStream(allocator: Allocator, reader: anytype) !ZstandardStream(@TypeOf(reader), true, 8 * (1 << 20)) {
    return ZstandardStream(@TypeOf(reader), true, 8 * (1 << 20)).init(allocator, reader);
}

fn testDecompress(data: []const u8) ![]u8 {
    var in_stream = std.io.fixedBufferStream(data);
    var stream = try zstandardStream(std.testing.allocator, in_stream.reader());
    defer stream.deinit();
    const result = stream.reader().readAllAlloc(std.testing.allocator, std.math.maxInt(usize));
    try std.testing.expect(try stream.verifyChecksum());
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

    var buffer = try std.testing.allocator.alloc(u8, uncompressed.len);
    defer std.testing.allocator.free(buffer);

    const res3 = try decompress.decodeFrame(buffer, compressed3, true);
    try std.testing.expectEqual(compressed3.len, res3.read_count);
    try std.testing.expectEqual(uncompressed.len, res3.write_count);
    try std.testing.expectEqualSlices(u8, uncompressed, buffer);

    const res19 = try decompress.decodeFrame(buffer, compressed19, true);
    try std.testing.expectEqual(compressed19.len, res19.read_count);
    try std.testing.expectEqual(uncompressed.len, res19.write_count);
    try std.testing.expectEqualSlices(u8, uncompressed, buffer);

    try testReader(compressed3, uncompressed);
    try testReader(compressed19, uncompressed);
}
