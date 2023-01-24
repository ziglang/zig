const std = @import("std");
const assert = std.debug.assert;

const types = @import("types.zig");
const frame = types.frame;
const LiteralsSection = types.compressed_block.LiteralsSection;
const SequencesSection = types.compressed_block.SequencesSection;
const Table = types.compressed_block.Table;
pub const RingBuffer = @import("RingBuffer.zig");

const readInt = std.mem.readIntLittle;
const readIntSlice = std.mem.readIntSliceLittle;
fn readVarInt(comptime T: type, bytes: []const u8) T {
    return std.mem.readVarInt(T, bytes, .Little);
}

const log = std.log.scoped(.Decompress);

fn isSkippableMagic(magic: u32) bool {
    return frame.Skippable.magic_number_min <= magic and magic <= frame.Skippable.magic_number_max;
}

pub fn getFrameDecompressedSize(src: []const u8) !?usize {
    switch (try frameType(src)) {
        .zstandard => {
            const header = try decodeZStandardHeader(src[4..], null);
            return header.content_size;
        },
        .skippable => return 0,
    }
}

pub fn frameType(src: []const u8) !frame.Kind {
    const magic = readInt(u32, src[0..4]);
    return if (magic == frame.ZStandard.magic_number)
        .zstandard
    else if (isSkippableMagic(magic))
        .skippable
    else
        error.BadMagic;
}

const ReadWriteCount = struct {
    read_count: usize,
    write_count: usize,
};

pub fn decodeFrame(dest: []u8, src: []const u8, verify_checksum: bool) !ReadWriteCount {
    return switch (try frameType(src)) {
        .zstandard => decodeZStandardFrame(dest, src, verify_checksum),
        .skippable => ReadWriteCount{
            .read_count = try skippableFrameSize(src[0..8]) + 8,
            .write_count = 0,
        },
    };
}

pub const DecodeState = struct {
    repeat_offsets: [3]u32,

    offset: StateData(8),
    match: StateData(9),
    literal: StateData(9),

    offset_fse_buffer: []Table.Fse,
    match_fse_buffer: []Table.Fse,
    literal_fse_buffer: []Table.Fse,

    fse_tables_undefined: bool,

    literal_stream_reader: ReverseBitReader,
    literal_stream_index: usize,
    huffman_tree: ?LiteralsSection.HuffmanTree,

    literal_written_count: usize,

    fn StateData(comptime max_accuracy_log: comptime_int) type {
        return struct {
            state: State,
            table: Table,
            accuracy_log: u8,

            const State = std.meta.Int(.unsigned, max_accuracy_log);
        };
    }

    pub fn prepare(
        self: *DecodeState,
        src: []const u8,
        literals: LiteralsSection,
        sequences_header: SequencesSection.Header,
    ) !usize {
        if (literals.huffman_tree) |tree| {
            self.huffman_tree = tree;
        } else if (literals.header.block_type == .treeless and self.huffman_tree == null) {
            return error.TreelessLiteralsFirst;
        }

        switch (literals.header.block_type) {
            .raw, .rle => {},
            .compressed, .treeless => {
                self.literal_stream_index = 0;
                switch (literals.streams) {
                    .one => |slice| try self.initLiteralStream(slice),
                    .four => |streams| try self.initLiteralStream(streams[0]),
                }
            },
        }

        if (sequences_header.sequence_count > 0) {
            var bytes_read = try self.updateFseTable(
                src,
                .literal,
                sequences_header.literal_lengths,
            );

            bytes_read += try self.updateFseTable(
                src[bytes_read..],
                .offset,
                sequences_header.offsets,
            );

            bytes_read += try self.updateFseTable(
                src[bytes_read..],
                .match,
                sequences_header.match_lengths,
            );
            self.fse_tables_undefined = false;

            return bytes_read;
        }
        return 0;
    }

    pub fn readInitialFseState(self: *DecodeState, bit_reader: anytype) !void {
        self.literal.state = try bit_reader.readBitsNoEof(u9, self.literal.accuracy_log);
        self.offset.state = try bit_reader.readBitsNoEof(u8, self.offset.accuracy_log);
        self.match.state = try bit_reader.readBitsNoEof(u9, self.match.accuracy_log);
        log.debug("initial decoder state: literal = {d}, offset = {d} match = {d}", .{
            self.literal.state,
            self.offset.state,
            self.match.state,
        });
    }

    fn updateRepeatOffset(self: *DecodeState, offset: u32) void {
        std.mem.swap(u32, &self.repeat_offsets[0], &self.repeat_offsets[1]);
        std.mem.swap(u32, &self.repeat_offsets[0], &self.repeat_offsets[2]);
        self.repeat_offsets[0] = offset;
    }

    fn useRepeatOffset(self: *DecodeState, index: usize) u32 {
        if (index == 1)
            std.mem.swap(u32, &self.repeat_offsets[0], &self.repeat_offsets[1])
        else if (index == 2) {
            std.mem.swap(u32, &self.repeat_offsets[0], &self.repeat_offsets[2]);
            std.mem.swap(u32, &self.repeat_offsets[1], &self.repeat_offsets[2]);
        }
        return self.repeat_offsets[0];
    }

    const DataType = enum { offset, match, literal };

    fn updateState(self: *DecodeState, comptime choice: DataType, bit_reader: anytype) !void {
        switch (@field(self, @tagName(choice)).table) {
            .rle => {},
            .fse => |table| {
                const data = table[@field(self, @tagName(choice)).state];
                const T = @TypeOf(@field(self, @tagName(choice))).State;
                const bits_summand = try bit_reader.readBitsNoEof(T, data.bits);
                const next_state = std.math.cast(
                    @TypeOf(@field(self, @tagName(choice))).State,
                    data.baseline + bits_summand,
                ) orelse return error.MalformedFseBits;
                @field(self, @tagName(choice)).state = next_state;
            },
        }
    }

    fn updateFseTable(
        self: *DecodeState,
        src: []const u8,
        comptime choice: DataType,
        mode: SequencesSection.Header.Mode,
    ) !usize {
        const field_name = @tagName(choice);
        switch (mode) {
            .predefined => {
                @field(self, field_name).accuracy_log = @field(types.compressed_block.default_accuracy_log, field_name);
                @field(self, field_name).table = @field(types.compressed_block, "predefined_" ++ field_name ++ "_fse_table");
                return 0;
            },
            .rle => {
                @field(self, field_name).accuracy_log = 0;
                @field(self, field_name).table = .{ .rle = src[0] };
                return 1;
            },
            .fse => {
                var stream = std.io.fixedBufferStream(src);
                var counting_reader = std.io.countingReader(stream.reader());
                var bit_reader = bitReader(counting_reader.reader());

                const table_size = try decodeFseTable(
                    &bit_reader,
                    @field(types.compressed_block.table_symbol_count_max, field_name),
                    @field(types.compressed_block.table_accuracy_log_max, field_name),
                    @field(self, field_name ++ "_fse_buffer"),
                );
                @field(self, field_name).table = .{ .fse = @field(self, field_name ++ "_fse_buffer")[0..table_size] };
                @field(self, field_name).accuracy_log = std.math.log2_int_ceil(usize, table_size);
                log.debug("decoded fse " ++ field_name ++ " table '{}'", .{
                    std.fmt.fmtSliceHexUpper(src[0..counting_reader.bytes_read]),
                });
                dumpFseTable(field_name, @field(self, field_name).table.fse);
                return counting_reader.bytes_read;
            },
            .repeat => return if (self.fse_tables_undefined) error.RepeatModeFirst else 0,
        }
    }

    const Sequence = struct {
        literal_length: u32,
        match_length: u32,
        offset: u32,
    };

    fn nextSequence(self: *DecodeState, bit_reader: anytype) !Sequence {
        const raw_code = self.getCode(.offset);
        const offset_code = std.math.cast(u5, raw_code) orelse {
            log.err("got offset code of {d}", .{raw_code});
            return error.OffsetCodeTooLarge;
        };
        const offset_value = (@as(u32, 1) << offset_code) + try bit_reader.readBitsNoEof(u32, offset_code);

        const match_code = self.getCode(.match);
        const match = types.compressed_block.match_length_code_table[match_code];
        const match_length = match[0] + try bit_reader.readBitsNoEof(u32, match[1]);

        const literal_code = self.getCode(.literal);
        const literal = types.compressed_block.literals_length_code_table[literal_code];
        const literal_length = literal[0] + try bit_reader.readBitsNoEof(u32, literal[1]);

        const offset = if (offset_value > 3) offset: {
            const offset = offset_value - 3;
            self.updateRepeatOffset(offset);
            break :offset offset;
        } else offset: {
            if (literal_length == 0) {
                if (offset_value == 3) {
                    const offset = self.repeat_offsets[0] - 1;
                    self.updateRepeatOffset(offset);
                    break :offset offset;
                }
                break :offset self.useRepeatOffset(offset_value);
            }
            break :offset self.useRepeatOffset(offset_value - 1);
        };

        log.debug("sequence = ({d}, {d}, {d})", .{ literal_length, offset, match_length });
        return .{
            .literal_length = literal_length,
            .match_length = match_length,
            .offset = offset,
        };
    }

    fn executeSequenceSlice(
        self: *DecodeState,
        dest: []u8,
        write_pos: usize,
        literals: LiteralsSection,
        sequence: Sequence,
    ) !void {
        if (sequence.offset > write_pos + sequence.literal_length) return error.MalformedSequence;

        try self.decodeLiteralsSlice(dest[write_pos..], literals, sequence.literal_length);
        const copy_start = write_pos + sequence.literal_length - sequence.offset;
        const copy_end = copy_start + sequence.match_length;
        // NOTE: we ignore the usage message for std.mem.copy and copy with dest.ptr >= src.ptr
        //       to allow repeats
        std.mem.copy(u8, dest[write_pos + sequence.literal_length ..], dest[copy_start..copy_end]);
    }

    fn executeSequenceRingBuffer(
        self: *DecodeState,
        dest: *RingBuffer,
        literals: LiteralsSection,
        sequence: Sequence,
    ) !void {
        if (sequence.offset > dest.data.len) return error.MalformedSequence;

        try self.decodeLiteralsRingBuffer(dest, literals, sequence.literal_length);
        const copy_slice = dest.sliceAt(dest.write_index + dest.data.len - sequence.offset, sequence.match_length);
        // TODO: would std.mem.copy and figuring out dest slice be better/faster?
        for (copy_slice.first) |b| dest.writeAssumeCapacity(b);
        for (copy_slice.second) |b| dest.writeAssumeCapacity(b);
    }

    pub fn decodeSequenceSlice(
        self: *DecodeState,
        dest: []u8,
        write_pos: usize,
        literals: LiteralsSection,
        bit_reader: anytype,
        sequence_size_limit: usize,
        last_sequence: bool,
    ) !usize {
        const sequence = try self.nextSequence(bit_reader);
        const sequence_length = @as(usize, sequence.literal_length) + sequence.match_length;
        if (sequence_length > sequence_size_limit) return error.MalformedSequence;

        try self.executeSequenceSlice(dest, write_pos, literals, sequence);
        log.debug("sequence decompressed into '{x}'", .{
            std.fmt.fmtSliceHexUpper(dest[write_pos .. write_pos + sequence.literal_length + sequence.match_length]),
        });
        if (!last_sequence) {
            try self.updateState(.literal, bit_reader);
            try self.updateState(.match, bit_reader);
            try self.updateState(.offset, bit_reader);
        }
        return sequence_length;
    }

    pub fn decodeSequenceRingBuffer(
        self: *DecodeState,
        dest: *RingBuffer,
        literals: LiteralsSection,
        bit_reader: anytype,
        sequence_size_limit: usize,
        last_sequence: bool,
    ) !usize {
        const sequence = try self.nextSequence(bit_reader);
        const sequence_length = @as(usize, sequence.literal_length) + sequence.match_length;
        if (sequence_length > sequence_size_limit) return error.MalformedSequence;

        try self.executeSequenceRingBuffer(dest, literals, sequence);
        if (std.options.log_level == .debug) {
            const written_slice = dest.sliceLast(sequence_length);
            log.debug("sequence decompressed into '{x}{x}'", .{
                std.fmt.fmtSliceHexUpper(written_slice.first),
                std.fmt.fmtSliceHexUpper(written_slice.second),
            });
        }
        if (!last_sequence) {
            try self.updateState(.literal, bit_reader);
            try self.updateState(.match, bit_reader);
            try self.updateState(.offset, bit_reader);
        }
        return sequence_length;
    }

    fn nextLiteralMultiStream(self: *DecodeState, literals: LiteralsSection) !void {
        self.literal_stream_index += 1;
        try self.initLiteralStream(literals.streams.four[self.literal_stream_index]);
    }

    fn initLiteralStream(self: *DecodeState, bytes: []const u8) !void {
        log.debug("initing literal stream: {}", .{std.fmt.fmtSliceHexUpper(bytes)});
        try self.literal_stream_reader.init(bytes);
    }

    pub fn decodeLiteralsSlice(self: *DecodeState, dest: []u8, literals: LiteralsSection, len: usize) !void {
        if (self.literal_written_count + len > literals.header.regenerated_size) return error.MalformedLiteralsLength;
        switch (literals.header.block_type) {
            .raw => {
                const literal_data = literals.streams.one[self.literal_written_count .. self.literal_written_count + len];
                std.mem.copy(u8, dest, literal_data);
                self.literal_written_count += len;
            },
            .rle => {
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    dest[i] = literals.streams.one[0];
                }
                log.debug("rle: {}", .{std.fmt.fmtSliceHexUpper(dest[0..len])});
                self.literal_written_count += len;
            },
            .compressed, .treeless => {
                // const written_bytes_per_stream = (literals.header.regenerated_size + 3) / 4;
                const huffman_tree = self.huffman_tree orelse unreachable;
                const max_bit_count = huffman_tree.max_bit_count;
                const starting_bit_count = LiteralsSection.HuffmanTree.weightToBitCount(
                    huffman_tree.nodes[huffman_tree.symbol_count_minus_one].weight,
                    max_bit_count,
                );
                var bits_read: u4 = 0;
                var huffman_tree_index: usize = huffman_tree.symbol_count_minus_one;
                var bit_count_to_read: u4 = starting_bit_count;
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    var prefix: u16 = 0;
                    while (true) {
                        const new_bits = self.literal_stream_reader.readBitsNoEof(u16, bit_count_to_read) catch |err|
                            switch (err) {
                            error.EndOfStream => if (literals.streams == .four and self.literal_stream_index < 3) bits: {
                                try self.nextLiteralMultiStream(literals);
                                break :bits try self.literal_stream_reader.readBitsNoEof(u16, bit_count_to_read);
                            } else {
                                return error.UnexpectedEndOfLiteralStream;
                            },
                        };
                        prefix <<= bit_count_to_read;
                        prefix |= new_bits;
                        bits_read += bit_count_to_read;
                        const result = try huffman_tree.query(huffman_tree_index, prefix);

                        switch (result) {
                            .symbol => |sym| {
                                dest[i] = sym;
                                bit_count_to_read = starting_bit_count;
                                bits_read = 0;
                                huffman_tree_index = huffman_tree.symbol_count_minus_one;
                                break;
                            },
                            .index => |index| {
                                huffman_tree_index = index;
                                const bit_count = LiteralsSection.HuffmanTree.weightToBitCount(
                                    huffman_tree.nodes[index].weight,
                                    max_bit_count,
                                );
                                bit_count_to_read = bit_count - bits_read;
                            },
                        }
                    }
                }
                self.literal_written_count += len;
            },
        }
    }

    pub fn decodeLiteralsRingBuffer(self: *DecodeState, dest: *RingBuffer, literals: LiteralsSection, len: usize) !void {
        if (self.literal_written_count + len > literals.header.regenerated_size) return error.MalformedLiteralsLength;
        switch (literals.header.block_type) {
            .raw => {
                const literal_data = literals.streams.one[self.literal_written_count .. self.literal_written_count + len];
                dest.writeSliceAssumeCapacity(literal_data);
                self.literal_written_count += len;
            },
            .rle => {
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    dest.writeAssumeCapacity(literals.streams.one[0]);
                }
                self.literal_written_count += len;
            },
            .compressed, .treeless => {
                // const written_bytes_per_stream = (literals.header.regenerated_size + 3) / 4;
                const huffman_tree = self.huffman_tree orelse unreachable;
                const max_bit_count = huffman_tree.max_bit_count;
                const starting_bit_count = LiteralsSection.HuffmanTree.weightToBitCount(
                    huffman_tree.nodes[huffman_tree.symbol_count_minus_one].weight,
                    max_bit_count,
                );
                var bits_read: u4 = 0;
                var huffman_tree_index: usize = huffman_tree.symbol_count_minus_one;
                var bit_count_to_read: u4 = starting_bit_count;
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    var prefix: u16 = 0;
                    while (true) {
                        const new_bits = self.literal_stream_reader.readBitsNoEof(u16, bit_count_to_read) catch |err|
                            switch (err) {
                            error.EndOfStream => if (literals.streams == .four and self.literal_stream_index < 3) bits: {
                                try self.nextLiteralMultiStream(literals);
                                break :bits try self.literal_stream_reader.readBitsNoEof(u16, bit_count_to_read);
                            } else {
                                return error.UnexpectedEndOfLiteralStream;
                            },
                        };
                        prefix <<= bit_count_to_read;
                        prefix |= new_bits;
                        bits_read += bit_count_to_read;
                        const result = try huffman_tree.query(huffman_tree_index, prefix);

                        switch (result) {
                            .symbol => |sym| {
                                dest.writeAssumeCapacity(sym);
                                bit_count_to_read = starting_bit_count;
                                bits_read = 0;
                                huffman_tree_index = huffman_tree.symbol_count_minus_one;
                                break;
                            },
                            .index => |index| {
                                huffman_tree_index = index;
                                const bit_count = LiteralsSection.HuffmanTree.weightToBitCount(
                                    huffman_tree.nodes[index].weight,
                                    max_bit_count,
                                );
                                bit_count_to_read = bit_count - bits_read;
                            },
                        }
                    }
                }
                self.literal_written_count += len;
            },
        }
    }

    fn getCode(self: *DecodeState, comptime choice: DataType) u32 {
        return switch (@field(self, @tagName(choice)).table) {
            .rle => |value| value,
            .fse => |table| table[@field(self, @tagName(choice)).state].symbol,
        };
    }
};

const literal_table_size_max = 1 << types.compressed_block.table_accuracy_log_max.literal;
const match_table_size_max = 1 << types.compressed_block.table_accuracy_log_max.match;
const offset_table_size_max = 1 << types.compressed_block.table_accuracy_log_max.match;

pub fn decodeZStandardFrame(dest: []u8, src: []const u8, verify_checksum: bool) !ReadWriteCount {
    assert(readInt(u32, src[0..4]) == frame.ZStandard.magic_number);
    var consumed_count: usize = 4;

    const frame_header = try decodeZStandardHeader(src[consumed_count..], &consumed_count);

    if (frame_header.descriptor.dictionary_id_flag != 0) return error.DictionaryIdFlagUnsupported;

    const content_size = frame_header.content_size orelse return error.UnknownContentSizeUnsupported;
    // const window_size = frameWindowSize(header) orelse return error.WindowSizeUnknown;
    if (dest.len < content_size) return error.ContentTooLarge;

    const should_compute_checksum = frame_header.descriptor.content_checksum_flag and verify_checksum;
    var hash_state = if (should_compute_checksum) std.hash.XxHash64.init(0) else undefined;

    // TODO: block_maximum_size should be @min(1 << 17, window_size);
    const written_count = try decodeFrameBlocks(
        dest,
        src[consumed_count..],
        &consumed_count,
        if (should_compute_checksum) &hash_state else null,
    );

    if (frame_header.descriptor.content_checksum_flag) {
        const checksum = readIntSlice(u32, src[consumed_count .. consumed_count + 4]);
        consumed_count += 4;
        if (verify_checksum) {
            const hash = hash_state.final();
            const hash_low_bytes = hash & 0xFFFFFFFF;
            if (checksum != hash_low_bytes) {
                std.log.err("expected checksum {x}, got {x} (full hash {x})", .{ checksum, hash_low_bytes, hash });
                return error.ChecksumFailure;
            }
        }
    }
    return ReadWriteCount{ .read_count = consumed_count, .write_count = written_count };
}

pub fn decodeZStandardFrameAlloc(allocator: std.mem.Allocator, src: []const u8, verify_checksum: bool) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    assert(readInt(u32, src[0..4]) == frame.ZStandard.magic_number);
    var consumed_count: usize = 4;

    const frame_header = try decodeZStandardHeader(src[consumed_count..], &consumed_count);

    if (frame_header.descriptor.dictionary_id_flag != 0) return error.DictionaryIdFlagUnsupported;

    const window_size = frameWindowSize(frame_header) orelse return error.WindowSizeUnknown;
    log.debug("window size = {d}", .{window_size});

    const should_compute_checksum = frame_header.descriptor.content_checksum_flag and verify_checksum;
    var hash = if (should_compute_checksum) std.hash.XxHash64.init(0) else null;

    const block_size_maximum = @min(1 << 17, window_size);
    log.debug("block size maximum = {d}", .{block_size_maximum});

    var window_data = try allocator.alloc(u8, window_size);
    defer allocator.free(window_data);
    var ring_buffer = RingBuffer{
        .data = window_data,
        .write_index = 0,
        .read_index = 0,
    };

    // These tables take 7680 bytes
    var literal_fse_data: [literal_table_size_max]Table.Fse = undefined;
    var match_fse_data: [match_table_size_max]Table.Fse = undefined;
    var offset_fse_data: [offset_table_size_max]Table.Fse = undefined;

    var block_header = decodeBlockHeader(src[consumed_count..][0..3]);
    consumed_count += 3;
    var decode_state = DecodeState{
        .repeat_offsets = .{
            types.compressed_block.start_repeated_offset_1,
            types.compressed_block.start_repeated_offset_2,
            types.compressed_block.start_repeated_offset_3,
        },

        .offset = undefined,
        .match = undefined,
        .literal = undefined,

        .literal_fse_buffer = &literal_fse_data,
        .match_fse_buffer = &match_fse_data,
        .offset_fse_buffer = &offset_fse_data,

        .fse_tables_undefined = true,

        .literal_written_count = 0,
        .literal_stream_reader = undefined,
        .literal_stream_index = undefined,
        .huffman_tree = null,
    };
    var written_count: usize = 0;
    while (true) : ({
        block_header = decodeBlockHeader(src[consumed_count..][0..3]);
        consumed_count += 3;
    }) {
        if (block_header.block_size > block_size_maximum) return error.CompressedBlockSizeOverMaximum;
        const written_size = try decodeBlockRingBuffer(
            &ring_buffer,
            src[consumed_count..],
            block_header,
            &decode_state,
            &consumed_count,
            block_size_maximum,
        );
        if (written_size > block_size_maximum) return error.DecompressedBlockSizeOverMaximum;
        const written_slice = ring_buffer.sliceLast(written_size);
        try result.appendSlice(written_slice.first);
        try result.appendSlice(written_slice.second);
        if (hash) |*hash_state| {
            hash_state.update(written_slice.first);
            hash_state.update(written_slice.second);
        }
        written_count += written_size;
        if (block_header.last_block) break;
    }
    return result.toOwnedSlice();
}

pub fn decodeFrameBlocks(dest: []u8, src: []const u8, consumed_count: *usize, hash: ?*std.hash.XxHash64) !usize {
    // These tables take 7680 bytes
    var literal_fse_data: [literal_table_size_max]Table.Fse = undefined;
    var match_fse_data: [match_table_size_max]Table.Fse = undefined;
    var offset_fse_data: [offset_table_size_max]Table.Fse = undefined;

    var block_header = decodeBlockHeader(src[0..3]);
    var bytes_read: usize = 3;
    var decode_state = DecodeState{
        .repeat_offsets = .{
            types.compressed_block.start_repeated_offset_1,
            types.compressed_block.start_repeated_offset_2,
            types.compressed_block.start_repeated_offset_3,
        },

        .offset = undefined,
        .match = undefined,
        .literal = undefined,

        .literal_fse_buffer = &literal_fse_data,
        .match_fse_buffer = &match_fse_data,
        .offset_fse_buffer = &offset_fse_data,

        .fse_tables_undefined = true,

        .literal_written_count = 0,
        .literal_stream_reader = undefined,
        .literal_stream_index = undefined,
        .huffman_tree = null,
    };
    var written_count: usize = 0;
    while (true) : ({
        block_header = decodeBlockHeader(src[bytes_read..][0..3]);
        bytes_read += 3;
    }) {
        const written_size = try decodeBlock(
            dest,
            src[bytes_read..],
            block_header,
            &decode_state,
            &bytes_read,
            written_count,
        );
        if (hash) |hash_state| hash_state.update(dest[written_count .. written_count + written_size]);
        written_count += written_size;
        if (block_header.last_block) break;
    }
    consumed_count.* += bytes_read;
    return written_count;
}

fn decodeRawBlock(dest: []u8, src: []const u8, block_size: u21, consumed_count: *usize) !usize {
    if (src.len < block_size) return error.MalformedBlockSize;
    log.debug("writing raw block - size {d}", .{block_size});
    const data = src[0..block_size];
    std.mem.copy(u8, dest, data);
    consumed_count.* += block_size;
    return block_size;
}

fn decodeRawBlockRingBuffer(dest: *RingBuffer, src: []const u8, block_size: u21, consumed_count: *usize) !usize {
    if (src.len < block_size) return error.MalformedBlockSize;
    log.debug("writing raw block - size {d}", .{block_size});
    const data = src[0..block_size];
    dest.writeSliceAssumeCapacity(data);
    consumed_count.* += block_size;
    return block_size;
}

fn decodeRleBlock(dest: []u8, src: []const u8, block_size: u21, consumed_count: *usize) !usize {
    if (src.len < 1) return error.MalformedRleBlock;
    log.debug("writing rle block - '{x}'x{d}", .{ src[0], block_size });
    var write_pos: usize = 0;
    while (write_pos < block_size) : (write_pos += 1) {
        dest[write_pos] = src[0];
    }
    consumed_count.* += 1;
    return block_size;
}

fn decodeRleBlockRingBuffer(dest: *RingBuffer, src: []const u8, block_size: u21, consumed_count: *usize) !usize {
    if (src.len < 1) return error.MalformedRleBlock;
    log.debug("writing rle block - '{x}'x{d}", .{ src[0], block_size });
    var write_pos: usize = 0;
    while (write_pos < block_size) : (write_pos += 1) {
        dest.writeAssumeCapacity(src[0]);
    }
    consumed_count.* += 1;
    return block_size;
}

pub fn decodeBlock(
    dest: []u8,
    src: []const u8,
    block_header: frame.ZStandard.Block.Header,
    decode_state: *DecodeState,
    consumed_count: *usize,
    written_count: usize,
) !usize {
    const block_size_max = @min(1 << 17, dest[written_count..].len); // 128KiB
    const block_size = block_header.block_size;
    if (block_size_max < block_size) return error.BlockSizeOverMaximum;
    switch (block_header.block_type) {
        .raw => return decodeRawBlock(dest[written_count..], src, block_size, consumed_count),
        .rle => return decodeRleBlock(dest[written_count..], src, block_size, consumed_count),
        .compressed => {
            if (src.len < block_size) return error.MalformedBlockSize;
            var bytes_read: usize = 0;
            const literals = try decodeLiteralsSection(src, &bytes_read);
            const sequences_header = try decodeSequencesHeader(src[bytes_read..], &bytes_read);

            bytes_read += try decode_state.prepare(src[bytes_read..], literals, sequences_header);

            var bytes_written: usize = 0;
            if (sequences_header.sequence_count > 0) {
                const bit_stream_bytes = src[bytes_read..block_size];
                var bit_stream: ReverseBitReader = undefined;
                try bit_stream.init(bit_stream_bytes);

                try decode_state.readInitialFseState(&bit_stream);

                var sequence_size_limit = block_size_max;
                var i: usize = 0;
                while (i < sequences_header.sequence_count) : (i += 1) {
                    log.debug("decoding sequence {d}", .{i});
                    const write_pos = written_count + bytes_written;
                    const decompressed_size = try decode_state.decodeSequenceSlice(
                        dest,
                        write_pos,
                        literals,
                        &bit_stream,
                        sequence_size_limit,
                        i == sequences_header.sequence_count - 1,
                    );
                    bytes_written += decompressed_size;
                    sequence_size_limit -= decompressed_size;
                }

                bytes_read += bit_stream_bytes.len;
            }

            if (decode_state.literal_written_count < literals.header.regenerated_size) {
                log.debug("decoding remaining literals", .{});
                const len = literals.header.regenerated_size - decode_state.literal_written_count;
                try decode_state.decodeLiteralsSlice(dest[written_count + bytes_written ..], literals, len);
                log.debug("remaining decoded literals at {d}: {}", .{
                    written_count,
                    std.fmt.fmtSliceHexUpper(dest[written_count .. written_count + len]),
                });
                bytes_written += len;
            }

            decode_state.literal_written_count = 0;
            assert(bytes_read == block_header.block_size);
            consumed_count.* += bytes_read;
            return bytes_written;
        },
        .reserved => return error.FrameContainsReservedBlock,
    }
}

pub fn decodeBlockRingBuffer(
    dest: *RingBuffer,
    src: []const u8,
    block_header: frame.ZStandard.Block.Header,
    decode_state: *DecodeState,
    consumed_count: *usize,
    block_size_max: usize,
) !usize {
    const block_size = block_header.block_size;
    if (block_size_max < block_size) return error.BlockSizeOverMaximum;
    switch (block_header.block_type) {
        .raw => return decodeRawBlockRingBuffer(dest, src, block_size, consumed_count),
        .rle => return decodeRleBlockRingBuffer(dest, src, block_size, consumed_count),
        .compressed => {
            if (src.len < block_size) return error.MalformedBlockSize;
            var bytes_read: usize = 0;
            const literals = try decodeLiteralsSection(src, &bytes_read);
            const sequences_header = try decodeSequencesHeader(src[bytes_read..], &bytes_read);

            bytes_read += try decode_state.prepare(src[bytes_read..], literals, sequences_header);

            var bytes_written: usize = 0;
            if (sequences_header.sequence_count > 0) {
                const bit_stream_bytes = src[bytes_read..block_size];
                var bit_stream: ReverseBitReader = undefined;
                try bit_stream.init(bit_stream_bytes);

                try decode_state.readInitialFseState(&bit_stream);

                var sequence_size_limit = block_size_max;
                var i: usize = 0;
                while (i < sequences_header.sequence_count) : (i += 1) {
                    log.debug("decoding sequence {d}", .{i});
                    const decompressed_size = try decode_state.decodeSequenceRingBuffer(
                        dest,
                        literals,
                        &bit_stream,
                        sequence_size_limit,
                        i == sequences_header.sequence_count - 1,
                    );
                    bytes_written += decompressed_size;
                    sequence_size_limit -= decompressed_size;
                }

                bytes_read += bit_stream_bytes.len;
            }

            if (decode_state.literal_written_count < literals.header.regenerated_size) {
                log.debug("decoding remaining literals", .{});
                const len = literals.header.regenerated_size - decode_state.literal_written_count;
                try decode_state.decodeLiteralsRingBuffer(dest, literals, len);
                const written_slice = dest.sliceLast(len);
                log.debug("remaining decoded literals at {d}: {}{}", .{
                    bytes_written,
                    std.fmt.fmtSliceHexUpper(written_slice.first),
                    std.fmt.fmtSliceHexUpper(written_slice.second),
                });
                bytes_written += len;
            }

            decode_state.literal_written_count = 0;
            assert(bytes_read == block_header.block_size);
            consumed_count.* += bytes_read;
            return bytes_written;
        },
        .reserved => return error.FrameContainsReservedBlock,
    }
}

pub fn decodeSkippableHeader(src: *const [8]u8) frame.Skippable.Header {
    const magic = readInt(u32, src[0..4]);
    assert(isSkippableMagic(magic));
    const frame_size = readInt(u32, src[4..8]);
    return .{
        .magic_number = magic,
        .frame_size = frame_size,
    };
}

pub fn skippableFrameSize(src: *const [8]u8) !usize {
    assert(isSkippableMagic(readInt(u32, src[0..4])));
    const frame_size = readInt(u32, src[4..8]);
    return frame_size;
}

pub fn frameWindowSize(header: frame.ZStandard.Header) ?u64 {
    if (header.window_descriptor) |descriptor| {
        const exponent = (descriptor & 0b11111000) >> 3;
        const mantissa = descriptor & 0b00000111;
        const window_log = 10 + exponent;
        const window_base = @as(u64, 1) << @intCast(u6, window_log);
        const window_add = (window_base / 8) * mantissa;
        return window_base + window_add;
    } else return header.content_size;
}

pub fn decodeZStandardHeader(src: []const u8, consumed_count: ?*usize) !frame.ZStandard.Header {
    const descriptor = @bitCast(frame.ZStandard.Header.Descriptor, src[0]);

    if (descriptor.unused) return error.UnusedBitSet;
    if (descriptor.reserved) return error.ReservedBitSet;

    var bytes_read_count: usize = 1;

    var window_descriptor: ?u8 = null;
    if (!descriptor.single_segment_flag) {
        window_descriptor = src[bytes_read_count];
        bytes_read_count += 1;
    }

    var dictionary_id: ?u32 = null;
    if (descriptor.dictionary_id_flag > 0) {
        // if flag is 3 then field_size = 4, else field_size = flag
        const field_size = (@as(u4, 1) << descriptor.dictionary_id_flag) >> 1;
        dictionary_id = readVarInt(u32, src[bytes_read_count .. bytes_read_count + field_size]);
        bytes_read_count += field_size;
    }

    var content_size: ?u64 = null;
    if (descriptor.single_segment_flag or descriptor.content_size_flag > 0) {
        const field_size = @as(u4, 1) << descriptor.content_size_flag;
        content_size = readVarInt(u64, src[bytes_read_count .. bytes_read_count + field_size]);
        if (field_size == 2) content_size.? += 256;
        bytes_read_count += field_size;
    }

    if (consumed_count) |p| p.* += bytes_read_count;

    const header = frame.ZStandard.Header{
        .descriptor = descriptor,
        .window_descriptor = window_descriptor,
        .dictionary_id = dictionary_id,
        .content_size = content_size,
    };
    log.debug(
        "decoded ZStandard frame header {x}: " ++
            "desc = (d={d},c={},r={},u={},s={},cs={d}), win_desc = {?x}, dict_id = {?x}, content_size = {?d}",
        .{
            std.fmt.fmtSliceHexUpper(src[0..bytes_read_count]),
            header.descriptor.dictionary_id_flag,
            header.descriptor.content_checksum_flag,
            header.descriptor.reserved,
            header.descriptor.unused,
            header.descriptor.single_segment_flag,
            header.descriptor.content_size_flag,
            header.window_descriptor,
            header.dictionary_id,
            header.content_size,
        },
    );
    return header;
}

pub fn decodeBlockHeader(src: *const [3]u8) frame.ZStandard.Block.Header {
    const last_block = src[0] & 1 == 1;
    const block_type = @intToEnum(frame.ZStandard.Block.Type, (src[0] & 0b110) >> 1);
    const block_size = ((src[0] & 0b11111000) >> 3) + (@as(u21, src[1]) << 5) + (@as(u21, src[2]) << 13);
    log.debug("decoded block header {}: last = {}, type = {s}, size = {d}", .{
        std.fmt.fmtSliceHexUpper(src),
        last_block,
        @tagName(block_type),
        block_size,
    });
    return .{
        .last_block = last_block,
        .block_type = block_type,
        .block_size = block_size,
    };
}

pub fn decodeLiteralsSection(src: []const u8, consumed_count: *usize) !LiteralsSection {
    var bytes_read: usize = 0;
    const header = try decodeLiteralsHeader(src, &bytes_read);
    switch (header.block_type) {
        .raw => {
            if (src.len < bytes_read + header.regenerated_size) return error.MalformedLiteralsSection;
            const stream = src[bytes_read .. bytes_read + header.regenerated_size];
            consumed_count.* += header.regenerated_size + bytes_read;
            return LiteralsSection{
                .header = header,
                .huffman_tree = null,
                .streams = .{ .one = stream },
            };
        },
        .rle => {
            if (src.len < bytes_read + 1) return error.MalformedLiteralsSection;
            const stream = src[bytes_read .. bytes_read + 1];
            consumed_count.* += 1 + bytes_read;
            return LiteralsSection{
                .header = header,
                .huffman_tree = null,
                .streams = .{ .one = stream },
            };
        },
        .compressed, .treeless => {
            const huffman_tree_start = bytes_read;
            const huffman_tree = if (header.block_type == .compressed)
                try decodeHuffmanTree(src[bytes_read..], &bytes_read)
            else
                null;
            const huffman_tree_size = bytes_read - huffman_tree_start;
            const total_streams_size = @as(usize, header.compressed_size.?) - huffman_tree_size;
            log.debug("huffman tree size = {}, total streams size = {}", .{ huffman_tree_size, total_streams_size });
            if (huffman_tree) |tree| dumpHuffmanTree(tree);

            if (src.len < bytes_read + total_streams_size) return error.MalformedLiteralsSection;
            const stream_data = src[bytes_read .. bytes_read + total_streams_size];

            if (header.size_format == 0) {
                consumed_count.* += total_streams_size + bytes_read;
                return LiteralsSection{
                    .header = header,
                    .huffman_tree = huffman_tree,
                    .streams = .{ .one = stream_data },
                };
            }

            if (stream_data.len < 6) return error.MalformedLiteralsSection;

            log.debug("jump table: {}", .{std.fmt.fmtSliceHexUpper(stream_data[0..6])});
            const stream_1_length = @as(usize, readInt(u16, stream_data[0..2]));
            const stream_2_length = @as(usize, readInt(u16, stream_data[2..4]));
            const stream_3_length = @as(usize, readInt(u16, stream_data[4..6]));
            const stream_4_length = (total_streams_size - 6) - (stream_1_length + stream_2_length + stream_3_length);

            const stream_1_start = 6;
            const stream_2_start = stream_1_start + stream_1_length;
            const stream_3_start = stream_2_start + stream_2_length;
            const stream_4_start = stream_3_start + stream_3_length;

            if (stream_data.len < stream_4_start + stream_4_length) return error.MalformedLiteralsSection;
            consumed_count.* += total_streams_size + bytes_read;

            return LiteralsSection{
                .header = header,
                .huffman_tree = huffman_tree,
                .streams = .{ .four = .{
                    stream_data[stream_1_start .. stream_1_start + stream_1_length],
                    stream_data[stream_2_start .. stream_2_start + stream_2_length],
                    stream_data[stream_3_start .. stream_3_start + stream_3_length],
                    stream_data[stream_4_start .. stream_4_start + stream_4_length],
                } },
            };
        },
    }
}

fn decodeHuffmanTree(src: []const u8, consumed_count: *usize) !LiteralsSection.HuffmanTree {
    var bytes_read: usize = 0;
    bytes_read += 1;
    if (src.len == 0) return error.MalformedHuffmanTree;
    const header = src[0];
    var symbol_count: usize = undefined;
    var weights: [256]u4 = undefined;
    var max_number_of_bits: u4 = undefined;
    if (header < 128) {
        // FSE compressed weights
        const compressed_size = header;
        if (src.len < 1 + compressed_size) return error.MalformedHuffmanTree;
        var stream = std.io.fixedBufferStream(src[1 .. compressed_size + 1]);
        var counting_reader = std.io.countingReader(stream.reader());
        var bit_reader = bitReader(counting_reader.reader());

        var entries: [1 << 6]Table.Fse = undefined;
        const table_size = try decodeFseTable(&bit_reader, 256, 6, &entries);
        const accuracy_log = std.math.log2_int_ceil(usize, table_size);

        var huff_data = src[1 + counting_reader.bytes_read .. compressed_size + 1];
        var huff_bits: ReverseBitReader = undefined;
        try huff_bits.init(huff_data);

        dumpFseTable("huffman", entries[0..table_size]);

        var i: usize = 0;
        var even_state: u32 = try huff_bits.readBitsNoEof(u32, accuracy_log);
        var odd_state: u32 = try huff_bits.readBitsNoEof(u32, accuracy_log);

        while (i < 255) {
            const even_data = entries[even_state];
            var read_bits: usize = 0;
            const even_bits = try huff_bits.readBits(u32, even_data.bits, &read_bits);
            weights[i] = std.math.cast(u4, even_data.symbol) orelse return error.MalformedHuffmanTree;
            i += 1;
            if (read_bits < even_data.bits) {
                weights[i] = std.math.cast(u4, entries[odd_state].symbol) orelse return error.MalformedHuffmanTree;
                log.debug("overflow condition: setting weights[{d}] = {d}", .{ i, weights[i] });
                i += 1;
                break;
            }
            even_state = even_data.baseline + even_bits;

            read_bits = 0;
            const odd_data = entries[odd_state];
            const odd_bits = try huff_bits.readBits(u32, odd_data.bits, &read_bits);
            weights[i] = std.math.cast(u4, odd_data.symbol) orelse return error.MalformedHuffmanTree;
            i += 1;
            if (read_bits < odd_data.bits) {
                if (i == 256) return error.MalformedHuffmanTree;
                weights[i] = std.math.cast(u4, entries[even_state].symbol) orelse return error.MalformedHuffmanTree;
                log.debug("overflow condition: setting weights[{d}] = {d}", .{ i, weights[i] });
                i += 1;
                break;
            }
            odd_state = odd_data.baseline + odd_bits;
        } else return error.MalformedHuffmanTree;

        symbol_count = i + 1; // stream contains all but the last symbol
        bytes_read += compressed_size;
    } else {
        const encoded_symbol_count = header - 127;
        symbol_count = encoded_symbol_count + 1;
        log.debug("huffman tree symbol count = {d}", .{symbol_count});
        const weights_byte_count = (encoded_symbol_count + 1) / 2;
        log.debug("decoding direct huffman tree: {}|{}", .{
            std.fmt.fmtSliceHexUpper(src[0..1]),
            std.fmt.fmtSliceHexUpper(src[1 .. weights_byte_count + 1]),
        });
        if (src.len < weights_byte_count) return error.MalformedHuffmanTree;
        var i: usize = 0;
        while (i < weights_byte_count) : (i += 1) {
            weights[2 * i] = @intCast(u4, src[i + 1] >> 4);
            weights[2 * i + 1] = @intCast(u4, src[i + 1] & 0xF);
            log.debug("weights[{d}] = {d}", .{ 2 * i, weights[2 * i] });
            log.debug("weights[{d}] = {d}", .{ 2 * i + 1, weights[2 * i + 1] });
        }
        bytes_read += weights_byte_count;
    }
    var weight_power_sum: u16 = 0;
    for (weights[0 .. symbol_count - 1]) |value| {
        if (value > 0) {
            weight_power_sum += @as(u16, 1) << (value - 1);
        }
    }
    log.debug("weight power sum = {d}", .{weight_power_sum});

    // advance to next power of two (even if weight_power_sum is a power of 2)
    max_number_of_bits = std.math.log2_int(u16, weight_power_sum) + 1;
    const next_power_of_two = @as(u16, 1) << max_number_of_bits;
    weights[symbol_count - 1] = std.math.log2_int(u16, next_power_of_two - weight_power_sum) + 1;
    log.debug("weights[{d}] = {d}", .{ symbol_count - 1, weights[symbol_count - 1] });

    var weight_sorted_prefixed_symbols: [256]LiteralsSection.HuffmanTree.PrefixedSymbol = undefined;
    for (weight_sorted_prefixed_symbols[0..symbol_count]) |_, i| {
        weight_sorted_prefixed_symbols[i] = .{
            .symbol = @intCast(u8, i),
            .weight = undefined,
            .prefix = undefined,
        };
    }

    std.sort.sort(
        LiteralsSection.HuffmanTree.PrefixedSymbol,
        weight_sorted_prefixed_symbols[0..symbol_count],
        weights,
        lessThanByWeight,
    );

    var prefix: u16 = 0;
    var prefixed_symbol_count: usize = 0;
    var sorted_index: usize = 0;
    while (sorted_index < symbol_count) {
        var symbol = weight_sorted_prefixed_symbols[sorted_index].symbol;
        const weight = weights[symbol];
        if (weight == 0) {
            sorted_index += 1;
            continue;
        }

        while (sorted_index < symbol_count) : ({
            sorted_index += 1;
            prefixed_symbol_count += 1;
            prefix += 1;
        }) {
            symbol = weight_sorted_prefixed_symbols[sorted_index].symbol;
            if (weights[symbol] != weight) {
                prefix = ((prefix - 1) >> (weights[symbol] - weight)) + 1;
                break;
            }
            weight_sorted_prefixed_symbols[prefixed_symbol_count].symbol = symbol;
            weight_sorted_prefixed_symbols[prefixed_symbol_count].prefix = prefix;
            weight_sorted_prefixed_symbols[prefixed_symbol_count].weight = weight;
        }
    }
    consumed_count.* += bytes_read;
    const tree = LiteralsSection.HuffmanTree{
        .max_bit_count = max_number_of_bits,
        .symbol_count_minus_one = @intCast(u8, prefixed_symbol_count - 1),
        .nodes = weight_sorted_prefixed_symbols,
    };
    log.debug("decoded huffman tree {}:", .{std.fmt.fmtSliceHexUpper(src[0..bytes_read])});
    return tree;
}

fn lessThanByWeight(
    weights: [256]u4,
    lhs: LiteralsSection.HuffmanTree.PrefixedSymbol,
    rhs: LiteralsSection.HuffmanTree.PrefixedSymbol,
) bool {
    // NOTE: this function relies on the use of a stable sorting algorithm,
    //       otherwise a special case of if (weights[lhs] == weights[rhs]) return lhs < rhs;
    //       should be added
    return weights[lhs.symbol] < weights[rhs.symbol];
}

pub fn decodeLiteralsHeader(src: []const u8, consumed_count: *usize) !LiteralsSection.Header {
    if (src.len == 0) return error.MalformedLiteralsSection;
    const start = consumed_count.*;
    const byte0 = src[0];
    const block_type = @intToEnum(LiteralsSection.BlockType, byte0 & 0b11);
    const size_format = @intCast(u2, (byte0 & 0b1100) >> 2);
    var regenerated_size: u20 = undefined;
    var compressed_size: ?u18 = null;
    switch (block_type) {
        .raw, .rle => {
            switch (size_format) {
                0, 2 => {
                    regenerated_size = byte0 >> 3;
                    consumed_count.* += 1;
                },
                1 => {
                    if (src.len < 2) return error.MalformedLiteralsHeader;
                    regenerated_size = (byte0 >> 4) +
                        (@as(u20, src[1]) << 4);
                    consumed_count.* += 2;
                },
                3 => {
                    if (src.len < 3) return error.MalformedLiteralsHeader;
                    regenerated_size = (byte0 >> 4) +
                        (@as(u20, src[1]) << 4) +
                        (@as(u20, src[2]) << 12);
                    consumed_count.* += 3;
                },
            }
        },
        .compressed, .treeless => {
            const byte1 = src[1];
            const byte2 = src[2];
            switch (size_format) {
                0, 1 => {
                    if (src.len < 3) return error.MalformedLiteralsHeader;
                    regenerated_size = (byte0 >> 4) + ((@as(u20, byte1) & 0b00111111) << 4);
                    compressed_size = ((byte1 & 0b11000000) >> 6) + (@as(u18, byte2) << 2);
                    consumed_count.* += 3;
                },
                2 => {
                    if (src.len < 4) return error.MalformedLiteralsHeader;
                    const byte3 = src[3];
                    regenerated_size = (byte0 >> 4) + (@as(u20, byte1) << 4) + ((@as(u20, byte2) & 0b00000011) << 12);
                    compressed_size = ((byte2 & 0b11111100) >> 2) + (@as(u18, byte3) << 6);
                    consumed_count.* += 4;
                },
                3 => {
                    if (src.len < 5) return error.MalformedLiteralsHeader;
                    const byte3 = src[3];
                    const byte4 = src[4];
                    regenerated_size = (byte0 >> 4) + (@as(u20, byte1) << 4) + ((@as(u20, byte2) & 0b00111111) << 12);
                    compressed_size = ((byte2 & 0b11000000) >> 6) + (@as(u18, byte3) << 2) + (@as(u18, byte4) << 10);
                    consumed_count.* += 5;
                },
            }
        },
    }
    log.debug(
        "decoded literals section header '{}': type = {s}, size_format = {}, regen_size = {d}, compressed size = {?d}",
        .{
            std.fmt.fmtSliceHexUpper(src[0 .. consumed_count.* - start]),
            @tagName(block_type),
            size_format,
            regenerated_size,
            compressed_size,
        },
    );
    return LiteralsSection.Header{
        .block_type = block_type,
        .size_format = size_format,
        .regenerated_size = regenerated_size,
        .compressed_size = compressed_size,
    };
}

pub fn decodeSequencesHeader(src: []const u8, consumed_count: *usize) !SequencesSection.Header {
    if (src.len == 0) return error.MalformedSequencesSection;
    var sequence_count: u24 = undefined;

    var bytes_read: usize = 0;
    const byte0 = src[0];
    if (byte0 == 0) {
        bytes_read += 1;
        log.debug("decoded sequences header '{}': sequence count = 0", .{std.fmt.fmtSliceHexUpper(src[0..bytes_read])});
        consumed_count.* += bytes_read;
        return SequencesSection.Header{
            .sequence_count = 0,
            .offsets = undefined,
            .match_lengths = undefined,
            .literal_lengths = undefined,
        };
    } else if (byte0 < 128) {
        sequence_count = byte0;
        bytes_read += 1;
    } else if (byte0 < 255) {
        if (src.len < 2) return error.MalformedSequencesSection;
        sequence_count = (@as(u24, (byte0 - 128)) << 8) + src[1];
        bytes_read += 2;
    } else {
        if (src.len < 3) return error.MalformedSequencesSection;
        sequence_count = src[1] + (@as(u24, src[2]) << 8) + 0x7F00;
        bytes_read += 3;
    }

    if (src.len < bytes_read + 1) return error.MalformedSequencesSection;
    const compression_modes = src[bytes_read];
    bytes_read += 1;

    consumed_count.* += bytes_read;
    const matches_mode = @intToEnum(SequencesSection.Header.Mode, (compression_modes & 0b00001100) >> 2);
    const offsets_mode = @intToEnum(SequencesSection.Header.Mode, (compression_modes & 0b00110000) >> 4);
    const literal_mode = @intToEnum(SequencesSection.Header.Mode, (compression_modes & 0b11000000) >> 6);
    log.debug("decoded sequences header '{}': (sc={d},o={s},m={s},l={s})", .{
        std.fmt.fmtSliceHexUpper(src[0..bytes_read]),
        sequence_count,
        @tagName(offsets_mode),
        @tagName(matches_mode),
        @tagName(literal_mode),
    });
    if (compression_modes & 0b11 != 0) return error.ReservedBitSet;

    return SequencesSection.Header{
        .sequence_count = sequence_count,
        .offsets = offsets_mode,
        .match_lengths = matches_mode,
        .literal_lengths = literal_mode,
    };
}

fn buildFseTable(values: []const u16, entries: []Table.Fse) !void {
    const total_probability = @intCast(u16, entries.len);
    const accuracy_log = std.math.log2_int(u16, total_probability);
    assert(total_probability <= 1 << 9);

    var less_than_one_count: usize = 0;
    for (values) |value, i| {
        if (value == 0) {
            entries[entries.len - 1 - less_than_one_count] = Table.Fse{
                .symbol = @intCast(u8, i),
                .baseline = 0,
                .bits = accuracy_log,
            };
            less_than_one_count += 1;
        }
    }

    var position: usize = 0;
    var temp_states: [1 << 9]u16 = undefined;
    for (values) |value, symbol| {
        if (value == 0 or value == 1) continue;
        const probability = value - 1;

        const state_share_dividend = try std.math.ceilPowerOfTwo(u16, probability);
        const share_size = @divExact(total_probability, state_share_dividend);
        const double_state_count = state_share_dividend - probability;
        const single_state_count = probability - double_state_count;
        const share_size_log = std.math.log2_int(u16, share_size);

        var i: u16 = 0;
        while (i < probability) : (i += 1) {
            temp_states[i] = @intCast(u16, position);
            position += (entries.len >> 1) + (entries.len >> 3) + 3;
            position &= entries.len - 1;
            while (position >= entries.len - less_than_one_count) {
                position += (entries.len >> 1) + (entries.len >> 3) + 3;
                position &= entries.len - 1;
            }
        }
        std.sort.sort(u16, temp_states[0..probability], {}, std.sort.asc(u16));
        i = 0;
        while (i < probability) : (i += 1) {
            entries[temp_states[i]] = if (i < double_state_count) Table.Fse{
                .symbol = @intCast(u8, symbol),
                .bits = share_size_log + 1,
                .baseline = single_state_count * share_size + i * 2 * share_size,
            } else Table.Fse{
                .symbol = @intCast(u8, symbol),
                .bits = share_size_log,
                .baseline = (i - double_state_count) * share_size,
            };
        }
    }
}

fn decodeFseTable(
    bit_reader: anytype,
    expected_symbol_count: usize,
    max_accuracy_log: u4,
    entries: []Table.Fse,
) !usize {
    log.debug("decoding fse table {d} {d}", .{ max_accuracy_log, expected_symbol_count });

    const accuracy_log_biased = try bit_reader.readBitsNoEof(u4, 4);
    log.debug("accuracy_log_biased = {d}", .{accuracy_log_biased});
    if (accuracy_log_biased > max_accuracy_log -| 5) return error.MalformedAccuracyLog;
    const accuracy_log = accuracy_log_biased + 5;

    var values: [256]u16 = undefined;
    var value_count: usize = 0;

    const total_probability = @as(u16, 1) << accuracy_log;
    log.debug("total probability = {d}", .{total_probability});
    var accumulated_probability: u16 = 0;

    while (accumulated_probability < total_probability) {
        // WARNING: The RFC in poorly worded, and would suggest std.math.log2_int_ceil is correct here,
        //          but power of two (remaining probabilities + 1) need max bits set to 1 more.
        const max_bits = std.math.log2_int(u16, total_probability - accumulated_probability + 1) + 1;
        const small = try bit_reader.readBitsNoEof(u16, max_bits - 1);

        const cutoff = (@as(u16, 1) << max_bits) - 1 - (total_probability - accumulated_probability + 1);

        const value = if (small < cutoff)
            small
        else value: {
            const value_read = small + (try bit_reader.readBitsNoEof(u16, 1) << (max_bits - 1));
            break :value if (value_read < @as(u16, 1) << (max_bits - 1))
                value_read
            else
                value_read - cutoff;
        };

        accumulated_probability += if (value != 0) value - 1 else 1;

        values[value_count] = value;
        value_count += 1;

        if (value == 1) {
            while (true) {
                const repeat_flag = try bit_reader.readBitsNoEof(u2, 2);
                var i: usize = 0;
                while (i < repeat_flag) : (i += 1) {
                    values[value_count] = 1;
                    value_count += 1;
                }
                if (repeat_flag < 3) break;
            }
        }
    }
    bit_reader.alignToByte();

    if (value_count < 2) return error.MalformedFseTable;
    if (accumulated_probability != total_probability) return error.MalformedFseTable;
    if (value_count > expected_symbol_count) return error.MalformedFseTable;

    const table_size = total_probability;

    try buildFseTable(values[0..value_count], entries[0..table_size]);
    return table_size;
}

const ReversedByteReader = struct {
    remaining_bytes: usize,
    bytes: []const u8,

    const Reader = std.io.Reader(*ReversedByteReader, error{}, readFn);

    fn init(bytes: []const u8) ReversedByteReader {
        return .{
            .bytes = bytes,
            .remaining_bytes = bytes.len,
        };
    }

    fn reader(self: *ReversedByteReader) Reader {
        return .{ .context = self };
    }

    fn readFn(ctx: *ReversedByteReader, buffer: []u8) !usize {
        if (ctx.remaining_bytes == 0) return 0;
        const byte_index = ctx.remaining_bytes - 1;
        buffer[0] = ctx.bytes[byte_index];
        // buffer[0] = @bitReverse(ctx.bytes[byte_index]);
        ctx.remaining_bytes = byte_index;
        return 1;
    }
};

pub const ReverseBitReader = struct {
    byte_reader: ReversedByteReader,
    bit_reader: std.io.BitReader(.Big, ReversedByteReader.Reader),

    pub fn init(self: *ReverseBitReader, bytes: []const u8) !void {
        self.byte_reader = ReversedByteReader.init(bytes);
        self.bit_reader = std.io.bitReader(.Big, self.byte_reader.reader());
        while (0 == self.readBitsNoEof(u1, 1) catch return error.BitStreamHasNoStartBit) {}
    }

    pub fn readBitsNoEof(self: *@This(), comptime U: type, num_bits: usize) !U {
        return self.bit_reader.readBitsNoEof(U, num_bits);
    }

    pub fn readBits(self: *@This(), comptime U: type, num_bits: usize, out_bits: *usize) !U {
        return try self.bit_reader.readBits(U, num_bits, out_bits);
    }

    pub fn alignToByte(self: *@This()) void {
        self.bit_reader.alignToByte();
    }
};

fn BitReader(comptime Reader: type) type {
    return struct {
        underlying: std.io.BitReader(.Little, Reader),

        fn readBitsNoEof(self: *@This(), comptime U: type, num_bits: usize) !U {
            return self.underlying.readBitsNoEof(U, num_bits);
        }

        fn readBits(self: *@This(), comptime U: type, num_bits: usize, out_bits: *usize) !U {
            return self.underlying.readBits(U, num_bits, out_bits);
        }

        fn alignToByte(self: *@This()) void {
            self.underlying.alignToByte();
        }
    };
}

fn bitReader(reader: anytype) BitReader(@TypeOf(reader)) {
    return .{ .underlying = std.io.bitReader(.Little, reader) };
}

test {
    std.testing.refAllDecls(@This());
}

test buildFseTable {
    const literals_length_default_values = [36]u16{
        5, 4, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 2,
        3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 3, 2, 2, 2, 2, 2,
        0, 0, 0, 0,
    };

    const match_lengths_default_values = [53]u16{
        2, 5, 4, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0,
        0, 0, 0, 0, 0,
    };

    const offset_codes_default_values = [29]u16{
        2, 2, 2, 2, 2, 2, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0,
    };

    var entries: [64]Table.Fse = undefined;
    try buildFseTable(&literals_length_default_values, &entries);
    try std.testing.expectEqualSlices(Table.Fse, types.compressed_block.predefined_literal_fse_table.fse, &entries);

    try buildFseTable(&match_lengths_default_values, &entries);
    try std.testing.expectEqualSlices(Table.Fse, types.compressed_block.predefined_match_fse_table.fse, &entries);

    try buildFseTable(&offset_codes_default_values, entries[0..32]);
    try std.testing.expectEqualSlices(Table.Fse, types.compressed_block.predefined_offset_fse_table.fse, entries[0..32]);
}

fn dumpFseTable(prefix: []const u8, table: []const Table.Fse) void {
    log.debug("{s} fse table:", .{prefix});
    for (table) |entry, i| {
        log.debug("state = {d} symbol = {d} bl = {d}, bits = {d}", .{ i, entry.symbol, entry.baseline, entry.bits });
    }
}

fn dumpHuffmanTree(tree: LiteralsSection.HuffmanTree) void {
    log.debug("Huffman tree: max bit count = {}, symbol count = {}", .{ tree.max_bit_count, tree.symbol_count_minus_one + 1 });
    for (tree.nodes[0 .. tree.symbol_count_minus_one + 1]) |node| {
        log.debug("symbol = {[symbol]d}, prefix = {[prefix]d}, weight = {[weight]d}", node);
    }
}
