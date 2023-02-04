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
        state: enum { NewFrame, InFrame },
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

        pub const Error = ReaderType.Error || error{ ChecksumFailure, MalformedBlock, MalformedFrame, OutOfMemory };

        pub const Reader = std.io.Reader(*Self, Error, read);

        pub fn init(allocator: Allocator, source: ReaderType) !Self {
            return Self{
                .allocator = allocator,
                .in_reader = source,
                .state = .NewFrame,
                .decode_state = undefined,
                .frame_context = undefined,
                .buffer = undefined,
                .last_block = undefined,
                .literal_fse_buffer = undefined,
                .match_fse_buffer = undefined,
                .offset_fse_buffer = undefined,
                .literals_buffer = undefined,
                .sequence_buffer = undefined,
                .checksum = undefined,
            };
        }

        fn frameInit(self: *Self) !void {
            var bytes: [4]u8 = undefined;
            const bytes_read = try self.in_reader.readAll(&bytes);
            if (bytes_read == 0) return error.NoBytes;
            if (bytes_read < 4) return error.EndOfStream;
            const frame_type = try decompress.frameType(std.mem.readIntLittle(u32, &bytes));
            switch (frame_type) {
                .skippable => {
                    const size = try self.in_reader.readIntLittle(u32);
                    try self.in_reader.skipBytes(size, .{});
                    self.state = .NewFrame;
                },
                .zstandard => {
                    const frame_context = context: {
                        const frame_header = try decompress.decodeZstandardHeader(self.in_reader);
                        break :context try decompress.FrameContext.init(
                            frame_header,
                            window_size_max,
                            verify_checksum,
                        );
                    };

                    const literal_fse_buffer = try self.allocator.alloc(
                        types.compressed_block.Table.Fse,
                        types.compressed_block.table_size_max.literal,
                    );
                    errdefer self.allocator.free(literal_fse_buffer);

                    const match_fse_buffer = try self.allocator.alloc(
                        types.compressed_block.Table.Fse,
                        types.compressed_block.table_size_max.match,
                    );
                    errdefer self.allocator.free(match_fse_buffer);

                    const offset_fse_buffer = try self.allocator.alloc(
                        types.compressed_block.Table.Fse,
                        types.compressed_block.table_size_max.offset,
                    );
                    errdefer self.allocator.free(offset_fse_buffer);

                    const decode_state = decompress.block.DecodeState.init(
                        literal_fse_buffer,
                        match_fse_buffer,
                        offset_fse_buffer,
                    );
                    const buffer = try RingBuffer.init(self.allocator, frame_context.window_size);

                    const literals_data = try self.allocator.alloc(u8, window_size_max);
                    errdefer self.allocator.free(literals_data);

                    const sequence_data = try self.allocator.alloc(u8, window_size_max);
                    errdefer self.allocator.free(sequence_data);

                    self.literal_fse_buffer = literal_fse_buffer;
                    self.match_fse_buffer = match_fse_buffer;
                    self.offset_fse_buffer = offset_fse_buffer;
                    self.literals_buffer = literals_data;
                    self.sequence_buffer = sequence_data;

                    self.buffer = buffer;

                    self.decode_state = decode_state;
                    self.frame_context = frame_context;

                    self.checksum = if (verify_checksum) null else {};
                    self.last_block = false;

                    self.state = .InFrame;
                },
            }
        }

        pub fn deinit(self: *Self) void {
            if (self.state == .NewFrame) return;
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
            while (self.state == .NewFrame) {
                self.frameInit() catch |err| switch (err) {
                    error.NoBytes => return 0,
                    error.OutOfMemory => return error.OutOfMemory,
                    else => return error.MalformedFrame,
                };
            }

            return self.readInner(buffer);
        }

        fn readInner(self: *Self, buffer: []u8) Error!usize {
            std.debug.assert(self.state == .InFrame);

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
                if (block_header.last_block) {
                    if (self.frame_context.has_checksum) {
                        const checksum = self.in_reader.readIntLittle(u32) catch return error.MalformedFrame;
                        if (comptime verify_checksum) {
                            if (self.frame_context.hasher_opt) |*hasher| {
                                if (checksum != decompress.computeChecksum(hasher)) return error.ChecksumFailure;
                            }
                        }
                    }
                }
            }

            const decoded_data_len = self.buffer.len();
            var written_count: usize = 0;
            while (written_count < decoded_data_len and written_count < buffer.len) : (written_count += 1) {
                buffer[written_count] = self.buffer.read().?;
            }
            if (self.buffer.len() == 0) {
                self.state = .NewFrame;
                self.allocator.free(self.literal_fse_buffer);
                self.allocator.free(self.match_fse_buffer);
                self.allocator.free(self.offset_fse_buffer);
                self.allocator.free(self.literals_buffer);
                self.allocator.free(self.sequence_buffer);
                self.buffer.deinit(self.allocator);
            }
            return written_count;
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

    const res3 = try decompress.decode(buffer, compressed3, true);
    try std.testing.expectEqual(uncompressed.len, res3);
    try std.testing.expectEqualSlices(u8, uncompressed, buffer);

    const res19 = try decompress.decode(buffer, compressed19, true);
    try std.testing.expectEqual(uncompressed.len, res19);
    try std.testing.expectEqualSlices(u8, uncompressed, buffer);

    try testReader(compressed3, uncompressed);
    try testReader(compressed19, uncompressed);
}
