const std = @import("std");
const Allocator = std.mem.Allocator;
const RingBuffer = std.RingBuffer;

const types = @import("zstandard/types.zig");
pub const frame = types.frame;
pub const compressed_block = types.compressed_block;

pub const decompress = @import("zstandard/decompress.zig");

pub const DecompressStreamOptions = struct {
    verify_checksum: bool = true,
    window_size_max: usize = 1 << 23, // 8MiB default maximum window size
};

pub fn DecompressStream(
    comptime ReaderType: type,
    comptime options: DecompressStreamOptions,
) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        source: std.io.CountingReader(ReaderType),
        state: enum { NewFrame, InFrame, LastBlock },
        decode_state: decompress.block.DecodeState,
        frame_context: decompress.FrameContext,
        buffer: RingBuffer,
        literal_fse_buffer: []types.compressed_block.Table.Fse,
        match_fse_buffer: []types.compressed_block.Table.Fse,
        offset_fse_buffer: []types.compressed_block.Table.Fse,
        literals_buffer: []u8,
        sequence_buffer: []u8,
        checksum: if (options.verify_checksum) ?u32 else void,
        current_frame_decompressed_size: usize,

        pub const Error = ReaderType.Error || error{
            ChecksumFailure,
            DictionaryIdFlagUnsupported,
            MalformedBlock,
            MalformedFrame,
            OutOfMemory,
        };

        pub const Reader = std.io.Reader(*Self, Error, read);

        pub fn init(allocator: Allocator, source: ReaderType) Self {
            return Self{
                .allocator = allocator,
                .source = std.io.countingReader(source),
                .state = .NewFrame,
                .decode_state = undefined,
                .frame_context = undefined,
                .buffer = undefined,
                .literal_fse_buffer = undefined,
                .match_fse_buffer = undefined,
                .offset_fse_buffer = undefined,
                .literals_buffer = undefined,
                .sequence_buffer = undefined,
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
                    const frame_context = context: {
                        break :context try decompress.FrameContext.init(
                            header,
                            options.window_size_max,
                            options.verify_checksum,
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

                    const literals_data = try self.allocator.alloc(u8, options.window_size_max);
                    errdefer self.allocator.free(literals_data);

                    const sequence_data = try self.allocator.alloc(u8, options.window_size_max);
                    errdefer self.allocator.free(sequence_data);

                    self.literal_fse_buffer = literal_fse_buffer;
                    self.match_fse_buffer = match_fse_buffer;
                    self.offset_fse_buffer = offset_fse_buffer;
                    self.literals_buffer = literals_data;
                    self.sequence_buffer = sequence_data;

                    self.buffer = buffer;

                    self.decode_state = decode_state;
                    self.frame_context = frame_context;

                    self.checksum = if (options.verify_checksum) null else {};
                    self.current_frame_decompressed_size = 0;

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
                        error.OutOfMemory => return error.OutOfMemory,
                        else => return error.MalformedFrame,
                    };
                }
                size = try self.readInner(buffer);
            }
            return size;
        }

        fn readInner(self: *Self, buffer: []u8) Error!usize {
            std.debug.assert(self.state != .NewFrame);

            const source_reader = self.source.reader();
            while (self.buffer.isEmpty() and self.state != .LastBlock) {
                const header_bytes = source_reader.readBytesNoEof(3) catch
                    return error.MalformedFrame;
                const block_header = decompress.block.decodeBlockHeader(&header_bytes);

                decompress.block.decodeBlockReader(
                    &self.buffer,
                    source_reader,
                    block_header,
                    &self.decode_state,
                    self.frame_context.block_size_max,
                    self.literals_buffer,
                    self.sequence_buffer,
                ) catch
                    return error.MalformedBlock;

                if (self.frame_context.content_size) |size| {
                    if (self.current_frame_decompressed_size > size) return error.MalformedFrame;
                }

                const size = self.buffer.len();
                self.current_frame_decompressed_size += size;

                if (self.frame_context.hasher_opt) |*hasher| {
                    if (size > 0) {
                        const written_slice = self.buffer.sliceLast(size);
                        hasher.update(written_slice.first);
                        hasher.update(written_slice.second);
                    }
                }
                if (block_header.last_block) {
                    self.state = .LastBlock;
                    if (self.frame_context.has_checksum) {
                        const checksum = source_reader.readIntLittle(u32) catch
                            return error.MalformedFrame;
                        if (comptime options.verify_checksum) {
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

            const size = @min(self.buffer.len(), buffer.len);
            for (0..size) |i| {
                buffer[i] = self.buffer.read().?;
            }
            if (self.state == .LastBlock and self.buffer.len() == 0) {
                self.state = .NewFrame;
                self.allocator.free(self.literal_fse_buffer);
                self.allocator.free(self.match_fse_buffer);
                self.allocator.free(self.offset_fse_buffer);
                self.allocator.free(self.literals_buffer);
                self.allocator.free(self.sequence_buffer);
                self.buffer.deinit(self.allocator);
            }
            return size;
        }
    };
}

pub fn decompressStreamOptions(
    allocator: Allocator,
    reader: anytype,
    comptime options: DecompressStreamOptions,
) DecompressStream(@TypeOf(reader, options)) {
    return DecompressStream(@TypeOf(reader), options).init(allocator, reader);
}

pub fn decompressStream(
    allocator: Allocator,
    reader: anytype,
) DecompressStream(@TypeOf(reader), .{}) {
    return DecompressStream(@TypeOf(reader), .{}).init(allocator, reader);
}

fn testDecompress(data: []const u8) ![]u8 {
    var in_stream = std.io.fixedBufferStream(data);
    var zstd_stream = decompressStream(std.testing.allocator, in_stream.reader());
    defer zstd_stream.deinit();
    const result = zstd_stream.reader().readAllAlloc(std.testing.allocator, std.math.maxInt(usize));
    return result;
}

fn testReader(data: []const u8, comptime expected: []const u8) !void {
    const buf = try testDecompress(data);
    defer std.testing.allocator.free(buf);
    try std.testing.expectEqualSlices(u8, expected, buf);
}

test "zstandard decompression" {
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
