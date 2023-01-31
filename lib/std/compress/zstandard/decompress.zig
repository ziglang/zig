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

fn isSkippableMagic(magic: u32) bool {
    return frame.Skippable.magic_number_min <= magic and magic <= frame.Skippable.magic_number_max;
}

/// Returns the decompressed size of the frame at the start of `src`. Returns 0
/// if the the frame is skippable, `null` for Zstanndard frames that do not
/// declare their content size. Returns `UnusedBitSet` and `ReservedBitSet`
/// errors if the respective bits of the the frame descriptor are set.
pub fn getFrameDecompressedSize(src: []const u8) (InvalidBit || error{BadMagic})!?u64 {
    switch (try frameType(src)) {
        .zstandard => {
            const header = try decodeZStandardHeader(src[4..], null);
            return header.content_size;
        },
        .skippable => return 0,
    }
}

/// Returns the kind of frame at the beginning of `src`. Returns `BadMagic` if
/// `src` begin with bytes not equal to the Zstandard frame magic number, or
/// outside the range of magic numbers for skippable frames.
pub fn frameType(src: []const u8) error{BadMagic}!frame.Kind {
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

/// Decodes the frame at the start of `src` into `dest`. Returns the number of
/// bytes read from `src` and written to `dest`.
pub fn decodeFrame(
    dest: []u8,
    src: []const u8,
    verify_checksum: bool,
) (error{ UnknownContentSizeUnsupported, ContentTooLarge, BadMagic } || FrameError)!ReadWriteCount {
    return switch (try frameType(src)) {
        .zstandard => decodeZStandardFrame(dest, src, verify_checksum),
        .skippable => ReadWriteCount{
            .read_count = skippableFrameSize(src[0..8]) + 8,
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
    literal_streams: LiteralsSection.Streams,
    literal_header: LiteralsSection.Header,
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

    /// Prepare the decoder to decode a compressed block. Loads the literals
    /// stream and Huffman tree from `literals` and reads the FSE tables from `src`.
    /// Returns `error.BitStreamHasNoStartBit` if the (reversed) literal bitstream's
    /// first byte does not have any bits set.
    pub fn prepare(
        self: *DecodeState,
        src: []const u8,
        literals: LiteralsSection,
        sequences_header: SequencesSection.Header,
    ) (error{ BitStreamHasNoStartBit, TreelessLiteralsFirst } || FseTableError)!usize {
        self.literal_written_count = 0;
        self.literal_header = literals.header;
        self.literal_streams = literals.streams;

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

    /// Read initial FSE states for sequence decoding. Returns `error.EndOfStream`
    /// if `bit_reader` does not contain enough bits.
    pub fn readInitialFseState(self: *DecodeState, bit_reader: *ReverseBitReader) error{EndOfStream}!void {
        self.literal.state = try bit_reader.readBitsNoEof(u9, self.literal.accuracy_log);
        self.offset.state = try bit_reader.readBitsNoEof(u8, self.offset.accuracy_log);
        self.match.state = try bit_reader.readBitsNoEof(u9, self.match.accuracy_log);
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

    fn updateState(
        self: *DecodeState,
        comptime choice: DataType,
        bit_reader: *ReverseBitReader,
    ) error{ MalformedFseBits, EndOfStream }!void {
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

    const FseTableError = error{
        MalformedFseTable,
        MalformedAccuracyLog,
        RepeatModeFirst,
        EndOfStream,
    };

    fn updateFseTable(
        self: *DecodeState,
        src: []const u8,
        comptime choice: DataType,
        mode: SequencesSection.Header.Mode,
    ) FseTableError!usize {
        const field_name = @tagName(choice);
        switch (mode) {
            .predefined => {
                @field(self, field_name).accuracy_log =
                    @field(types.compressed_block.default_accuracy_log, field_name);

                @field(self, field_name).table =
                    @field(types.compressed_block, "predefined_" ++ field_name ++ "_fse_table");
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
                @field(self, field_name).table = .{
                    .fse = @field(self, field_name ++ "_fse_buffer")[0..table_size],
                };
                @field(self, field_name).accuracy_log = std.math.log2_int_ceil(usize, table_size);
                return std.math.cast(usize, counting_reader.bytes_read) orelse error.MalformedFseTable;
            },
            .repeat => return if (self.fse_tables_undefined) error.RepeatModeFirst else 0,
        }
    }

    const Sequence = struct {
        literal_length: u32,
        match_length: u32,
        offset: u32,
    };

    fn nextSequence(
        self: *DecodeState,
        bit_reader: *ReverseBitReader,
    ) error{ OffsetCodeTooLarge, EndOfStream }!Sequence {
        const raw_code = self.getCode(.offset);
        const offset_code = std.math.cast(u5, raw_code) orelse {
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
        sequence: Sequence,
    ) (error{MalformedSequence} || DecodeLiteralsError)!void {
        if (sequence.offset > write_pos + sequence.literal_length) return error.MalformedSequence;

        try self.decodeLiteralsSlice(dest[write_pos..], sequence.literal_length);
        const copy_start = write_pos + sequence.literal_length - sequence.offset;
        const copy_end = copy_start + sequence.match_length;
        // NOTE: we ignore the usage message for std.mem.copy and copy with dest.ptr >= src.ptr
        //       to allow repeats
        std.mem.copy(u8, dest[write_pos + sequence.literal_length ..], dest[copy_start..copy_end]);
    }

    fn executeSequenceRingBuffer(
        self: *DecodeState,
        dest: *RingBuffer,
        sequence: Sequence,
    ) (error{MalformedSequence} || DecodeLiteralsError)!void {
        if (sequence.offset > dest.data.len) return error.MalformedSequence;

        try self.decodeLiteralsRingBuffer(dest, sequence.literal_length);
        const copy_start = dest.write_index + dest.data.len - sequence.offset;
        const copy_slice = dest.sliceAt(copy_start, sequence.match_length);
        // TODO: would std.mem.copy and figuring out dest slice be better/faster?
        for (copy_slice.first) |b| dest.writeAssumeCapacity(b);
        for (copy_slice.second) |b| dest.writeAssumeCapacity(b);
    }

    const DecodeSequenceError = error{
        OffsetCodeTooLarge,
        EndOfStream,
        MalformedSequence,
        MalformedFseBits,
    } || DecodeLiteralsError;

    /// Decode one sequence from `bit_reader` into `dest`, written starting at
    /// `write_pos` and update FSE states if `last_sequence` is `false`. Returns
    /// `error.MalformedSequence` error if the decompressed sequence would be longer
    /// than `sequence_size_limit` or the sequence's offset is too large; returns
    /// `error.EndOfStream` if `bit_reader` does not contain enough bits; returns
    /// `error.UnexpectedEndOfLiteralStream` if the decoder state's literal streams
    /// do not contain enough literals for the sequence (this may mean the literal
    /// stream or the sequence is malformed).
    pub fn decodeSequenceSlice(
        self: *DecodeState,
        dest: []u8,
        write_pos: usize,
        bit_reader: *ReverseBitReader,
        sequence_size_limit: usize,
        last_sequence: bool,
    ) DecodeSequenceError!usize {
        const sequence = try self.nextSequence(bit_reader);
        const sequence_length = @as(usize, sequence.literal_length) + sequence.match_length;
        if (sequence_length > sequence_size_limit) return error.MalformedSequence;

        try self.executeSequenceSlice(dest, write_pos, sequence);
        if (!last_sequence) {
            try self.updateState(.literal, bit_reader);
            try self.updateState(.match, bit_reader);
            try self.updateState(.offset, bit_reader);
        }
        return sequence_length;
    }

    /// Decode one sequence from `bit_reader` into `dest`; see `decodeSequenceSlice`.
    pub fn decodeSequenceRingBuffer(
        self: *DecodeState,
        dest: *RingBuffer,
        bit_reader: anytype,
        sequence_size_limit: usize,
        last_sequence: bool,
    ) DecodeSequenceError!usize {
        const sequence = try self.nextSequence(bit_reader);
        const sequence_length = @as(usize, sequence.literal_length) + sequence.match_length;
        if (sequence_length > sequence_size_limit) return error.MalformedSequence;

        try self.executeSequenceRingBuffer(dest, sequence);
        if (!last_sequence) {
            try self.updateState(.literal, bit_reader);
            try self.updateState(.match, bit_reader);
            try self.updateState(.offset, bit_reader);
        }
        return sequence_length;
    }

    fn nextLiteralMultiStream(
        self: *DecodeState,
    ) error{BitStreamHasNoStartBit}!void {
        self.literal_stream_index += 1;
        try self.initLiteralStream(self.literal_streams.four[self.literal_stream_index]);
    }

    pub fn initLiteralStream(self: *DecodeState, bytes: []const u8) error{BitStreamHasNoStartBit}!void {
        try self.literal_stream_reader.init(bytes);
    }

    const LiteralBitsError = error{
        BitStreamHasNoStartBit,
        UnexpectedEndOfLiteralStream,
    };
    fn readLiteralsBits(
        self: *DecodeState,
        comptime T: type,
        bit_count_to_read: usize,
    ) LiteralBitsError!T {
        return self.literal_stream_reader.readBitsNoEof(u16, bit_count_to_read) catch bits: {
            if (self.literal_streams == .four and self.literal_stream_index < 3) {
                try self.nextLiteralMultiStream();
                break :bits self.literal_stream_reader.readBitsNoEof(u16, bit_count_to_read) catch
                    return error.UnexpectedEndOfLiteralStream;
            } else {
                return error.UnexpectedEndOfLiteralStream;
            }
        };
    }

    const DecodeLiteralsError = error{
        MalformedLiteralsLength,
        PrefixNotFound,
    } || LiteralBitsError;

    /// Decode `len` bytes of literals into `dest`. `literals` should be the
    /// `LiteralsSection` that was passed to `prepare()`. Returns
    /// `error.MalformedLiteralsLength` if the number of literal bytes decoded by
    /// `self` plus `len` is greater than the regenerated size of `literals`.
    /// Returns `error.UnexpectedEndOfLiteralStream` and `error.PrefixNotFound` if
    /// there are problems decoding Huffman compressed literals.
    pub fn decodeLiteralsSlice(
        self: *DecodeState,
        dest: []u8,
        len: usize,
    ) DecodeLiteralsError!void {
        if (self.literal_written_count + len > self.literal_header.regenerated_size)
            return error.MalformedLiteralsLength;

        switch (self.literal_header.block_type) {
            .raw => {
                const literals_end = self.literal_written_count + len;
                const literal_data = self.literal_streams.one[self.literal_written_count..literals_end];
                std.mem.copy(u8, dest, literal_data);
                self.literal_written_count += len;
            },
            .rle => {
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    dest[i] = self.literal_streams.one[0];
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
                        const new_bits = try self.readLiteralsBits(u16, bit_count_to_read);
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

    /// Decode literals into `dest`; see `decodeLiteralsSlice()`.
    pub fn decodeLiteralsRingBuffer(
        self: *DecodeState,
        dest: *RingBuffer,
        len: usize,
    ) DecodeLiteralsError!void {
        if (self.literal_written_count + len > self.literal_header.regenerated_size)
            return error.MalformedLiteralsLength;

        switch (self.literal_header.block_type) {
            .raw => {
                const literals_end = self.literal_written_count + len;
                const literal_data = self.literal_streams.one[self.literal_written_count..literals_end];
                dest.writeSliceAssumeCapacity(literal_data);
                self.literal_written_count += len;
            },
            .rle => {
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    dest.writeAssumeCapacity(self.literal_streams.one[0]);
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
                        const new_bits = try self.readLiteralsBits(u16, bit_count_to_read);
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

pub fn computeChecksum(hasher: *std.hash.XxHash64) u32 {
    const hash = hasher.final();
    return @intCast(u32, hash & 0xFFFFFFFF);
}

const FrameError = error{
    DictionaryIdFlagUnsupported,
    ChecksumFailure,
} || InvalidBit || DecodeBlockError;

/// Decode a Zstandard frame from `src` into `dest`, returning the number of
/// bytes read from `src` and written to `dest`; if the frame does not declare
/// its decompressed content size `error.UnknownContentSizeUnsupported` is
/// returned. Returns `error.DictionaryIdFlagUnsupported` if the frame uses a
/// dictionary, and `error.ChecksumFailure` if `verify_checksum` is `true` and
/// the frame contains a checksum that does not match the checksum computed from
/// the decompressed frame.
pub fn decodeZStandardFrame(
    dest: []u8,
    src: []const u8,
    verify_checksum: bool,
) (error{ UnknownContentSizeUnsupported, ContentTooLarge } || FrameError)!ReadWriteCount {
    assert(readInt(u32, src[0..4]) == frame.ZStandard.magic_number);
    var consumed_count: usize = 4;

    const frame_header = try decodeZStandardHeader(src[consumed_count..], &consumed_count);

    if (frame_header.descriptor.dictionary_id_flag != 0) return error.DictionaryIdFlagUnsupported;

    const content_size = frame_header.content_size orelse return error.UnknownContentSizeUnsupported;
    if (dest.len < content_size) return error.ContentTooLarge;

    const should_compute_checksum = frame_header.descriptor.content_checksum_flag and verify_checksum;
    var hasher_opt = if (should_compute_checksum) std.hash.XxHash64.init(0) else null;

    const written_count = try decodeFrameBlocks(
        dest,
        src[consumed_count..],
        &consumed_count,
        if (hasher_opt) |*hasher| hasher else null,
    );

    if (frame_header.descriptor.content_checksum_flag) {
        const checksum = readIntSlice(u32, src[consumed_count .. consumed_count + 4]);
        consumed_count += 4;
        if (hasher_opt) |*hasher| {
            if (checksum != computeChecksum(hasher)) return error.ChecksumFailure;
        }
    }
    return ReadWriteCount{ .read_count = consumed_count, .write_count = written_count };
}

pub const FrameContext = struct {
    hasher_opt: ?std.hash.XxHash64,
    window_size: usize,
    has_checksum: bool,
    block_size_max: usize,

    pub fn init(frame_header: frame.ZStandard.Header, window_size_max: usize, verify_checksum: bool) !FrameContext {
        if (frame_header.descriptor.dictionary_id_flag != 0) return error.DictionaryIdFlagUnsupported;

        const window_size_raw = frameWindowSize(frame_header) orelse return error.WindowSizeUnknown;
        const window_size = if (window_size_raw > window_size_max)
            return error.WindowTooLarge
        else
            @intCast(usize, window_size_raw);

        const should_compute_checksum = frame_header.descriptor.content_checksum_flag and verify_checksum;
        return .{
            .hasher_opt = if (should_compute_checksum) std.hash.XxHash64.init(0) else null,
            .window_size = window_size,
            .has_checksum = frame_header.descriptor.content_checksum_flag,
            .block_size_max = @min(1 << 17, window_size),
        };
    }
};

/// Decode a Zstandard from from `src` and return the decompressed bytes; see
/// `decodeZStandardFrame()`. Returns `error.WindowSizeUnknown` if the frame
/// does not declare its content size or a window descriptor (this indicates a
/// malformed frame).
pub fn decodeZStandardFrameAlloc(
    allocator: std.mem.Allocator,
    src: []const u8,
    verify_checksum: bool,
    window_size_max: usize,
) (error{ WindowSizeUnknown, WindowTooLarge, OutOfMemory } || FrameError)![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    assert(readInt(u32, src[0..4]) == frame.ZStandard.magic_number);
    var consumed_count: usize = 4;

    var frame_context = context: {
        const frame_header = try decodeZStandardHeader(src[consumed_count..], &consumed_count);
        break :context try FrameContext.init(frame_header, window_size_max, verify_checksum);
    };

    var ring_buffer = try RingBuffer.init(allocator, frame_context.window_size);
    defer ring_buffer.deinit(allocator);

    // These tables take 7680 bytes
    var literal_fse_data: [types.compressed_block.table_size_max.literal]Table.Fse = undefined;
    var match_fse_data: [types.compressed_block.table_size_max.match]Table.Fse = undefined;
    var offset_fse_data: [types.compressed_block.table_size_max.offset]Table.Fse = undefined;

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
        .literal_header = undefined,
        .literal_streams = undefined,
        .literal_stream_reader = undefined,
        .literal_stream_index = undefined,
        .huffman_tree = null,
    };
    while (true) : ({
        block_header = decodeBlockHeader(src[consumed_count..][0..3]);
        consumed_count += 3;
    }) {
        if (block_header.block_size > frame_context.block_size_max) return error.BlockSizeOverMaximum;
        const written_size = try decodeBlockRingBuffer(
            &ring_buffer,
            src[consumed_count..],
            block_header,
            &decode_state,
            &consumed_count,
            frame_context.block_size_max,
        );
        const written_slice = ring_buffer.sliceLast(written_size);
        try result.appendSlice(written_slice.first);
        try result.appendSlice(written_slice.second);
        if (frame_context.hasher_opt) |*hasher| {
            hasher.update(written_slice.first);
            hasher.update(written_slice.second);
        }
        if (block_header.last_block) break;
    }

    if (frame_context.has_checksum) {
        const checksum = readIntSlice(u32, src[consumed_count .. consumed_count + 4]);
        consumed_count += 4;
        if (frame_context.hasher_opt) |*hasher| {
            if (checksum != computeChecksum(hasher)) return error.ChecksumFailure;
        }
    }
    return result.toOwnedSlice();
}

const DecodeBlockError = error{
    BlockSizeOverMaximum,
    MalformedBlockSize,
    ReservedBlock,
    MalformedRleBlock,
    MalformedCompressedBlock,
};

/// Convenience wrapper for decoding all blocks in a frame; see `decodeBlock()`.
pub fn decodeFrameBlocks(
    dest: []u8,
    src: []const u8,
    consumed_count: *usize,
    hash: ?*std.hash.XxHash64,
) DecodeBlockError!usize {
    // These tables take 7680 bytes
    var literal_fse_data: [types.compressed_block.table_size_max.literal]Table.Fse = undefined;
    var match_fse_data: [types.compressed_block.table_size_max.match]Table.Fse = undefined;
    var offset_fse_data: [types.compressed_block.table_size_max.offset]Table.Fse = undefined;

    var block_header = decodeBlockHeader(src[0..3]);
    var bytes_read: usize = 3;
    defer consumed_count.* += bytes_read;
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
        .literal_header = undefined,
        .literal_streams = undefined,
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
    return written_count;
}

fn decodeRawBlock(
    dest: []u8,
    src: []const u8,
    block_size: u21,
    consumed_count: *usize,
) error{MalformedBlockSize}!usize {
    if (src.len < block_size) return error.MalformedBlockSize;
    const data = src[0..block_size];
    std.mem.copy(u8, dest, data);
    consumed_count.* += block_size;
    return block_size;
}

fn decodeRawBlockRingBuffer(
    dest: *RingBuffer,
    src: []const u8,
    block_size: u21,
    consumed_count: *usize,
) error{MalformedBlockSize}!usize {
    if (src.len < block_size) return error.MalformedBlockSize;
    const data = src[0..block_size];
    dest.writeSliceAssumeCapacity(data);
    consumed_count.* += block_size;
    return block_size;
}

fn decodeRleBlock(
    dest: []u8,
    src: []const u8,
    block_size: u21,
    consumed_count: *usize,
) error{MalformedRleBlock}!usize {
    if (src.len < 1) return error.MalformedRleBlock;
    var write_pos: usize = 0;
    while (write_pos < block_size) : (write_pos += 1) {
        dest[write_pos] = src[0];
    }
    consumed_count.* += 1;
    return block_size;
}

fn decodeRleBlockRingBuffer(
    dest: *RingBuffer,
    src: []const u8,
    block_size: u21,
    consumed_count: *usize,
) error{MalformedRleBlock}!usize {
    if (src.len < 1) return error.MalformedRleBlock;
    var write_pos: usize = 0;
    while (write_pos < block_size) : (write_pos += 1) {
        dest.writeAssumeCapacity(src[0]);
    }
    consumed_count.* += 1;
    return block_size;
}

/// Decode a single block from `src` into `dest`. The beginning of `src` should
/// be the start of the block content (i.e. directly after the block header).
/// Increments `consumed_count` by the number of bytes read from `src` to decode
/// the block and returns the decompressed size of the block.
pub fn decodeBlock(
    dest: []u8,
    src: []const u8,
    block_header: frame.ZStandard.Block.Header,
    decode_state: *DecodeState,
    consumed_count: *usize,
    written_count: usize,
) DecodeBlockError!usize {
    const block_size_max = @min(1 << 17, dest[written_count..].len); // 128KiB
    const block_size = block_header.block_size;
    if (block_size_max < block_size) return error.BlockSizeOverMaximum;
    switch (block_header.block_type) {
        .raw => return decodeRawBlock(dest[written_count..], src, block_size, consumed_count),
        .rle => return decodeRleBlock(dest[written_count..], src, block_size, consumed_count),
        .compressed => {
            if (src.len < block_size) return error.MalformedBlockSize;
            var bytes_read: usize = 0;
            const literals = decodeLiteralsSection(src, &bytes_read) catch
                return error.MalformedCompressedBlock;
            const sequences_header = decodeSequencesHeader(src[bytes_read..], &bytes_read) catch
                return error.MalformedCompressedBlock;

            bytes_read += decode_state.prepare(src[bytes_read..], literals, sequences_header) catch
                return error.MalformedCompressedBlock;

            var bytes_written: usize = 0;
            if (sequences_header.sequence_count > 0) {
                const bit_stream_bytes = src[bytes_read..block_size];
                var bit_stream: ReverseBitReader = undefined;
                bit_stream.init(bit_stream_bytes) catch return error.MalformedCompressedBlock;

                decode_state.readInitialFseState(&bit_stream) catch return error.MalformedCompressedBlock;

                var sequence_size_limit = block_size_max;
                var i: usize = 0;
                while (i < sequences_header.sequence_count) : (i += 1) {
                    const write_pos = written_count + bytes_written;
                    const decompressed_size = decode_state.decodeSequenceSlice(
                        dest,
                        write_pos,
                        &bit_stream,
                        sequence_size_limit,
                        i == sequences_header.sequence_count - 1,
                    ) catch return error.MalformedCompressedBlock;
                    bytes_written += decompressed_size;
                    sequence_size_limit -= decompressed_size;
                }

                bytes_read += bit_stream_bytes.len;
            }

            if (decode_state.literal_written_count < literals.header.regenerated_size) {
                const len = literals.header.regenerated_size - decode_state.literal_written_count;
                decode_state.decodeLiteralsSlice(dest[written_count + bytes_written ..], len) catch
                    return error.MalformedCompressedBlock;
                bytes_written += len;
            }

            assert(bytes_read == block_header.block_size);
            consumed_count.* += bytes_read;
            return bytes_written;
        },
        .reserved => return error.ReservedBlock,
    }
}

/// Decode a single block from `src` into `dest`; see `decodeBlock()`. Returns
/// the size of the decompressed block, which can be used with `dest.sliceLast()`
/// to get the decompressed bytes.
pub fn decodeBlockRingBuffer(
    dest: *RingBuffer,
    src: []const u8,
    block_header: frame.ZStandard.Block.Header,
    decode_state: *DecodeState,
    consumed_count: *usize,
    block_size_max: usize,
) DecodeBlockError!usize {
    const block_size = block_header.block_size;
    if (block_size_max < block_size) return error.BlockSizeOverMaximum;
    switch (block_header.block_type) {
        .raw => return decodeRawBlockRingBuffer(dest, src, block_size, consumed_count),
        .rle => return decodeRleBlockRingBuffer(dest, src, block_size, consumed_count),
        .compressed => {
            if (src.len < block_size) return error.MalformedBlockSize;
            var bytes_read: usize = 0;
            const literals = decodeLiteralsSection(src, &bytes_read) catch
                return error.MalformedCompressedBlock;
            const sequences_header = decodeSequencesHeader(src[bytes_read..], &bytes_read) catch
                return error.MalformedCompressedBlock;

            bytes_read += decode_state.prepare(src[bytes_read..], literals, sequences_header) catch
                return error.MalformedCompressedBlock;

            var bytes_written: usize = 0;
            if (sequences_header.sequence_count > 0) {
                const bit_stream_bytes = src[bytes_read..block_size];
                var bit_stream: ReverseBitReader = undefined;
                bit_stream.init(bit_stream_bytes) catch return error.MalformedCompressedBlock;

                decode_state.readInitialFseState(&bit_stream) catch return error.MalformedCompressedBlock;

                var sequence_size_limit = block_size_max;
                var i: usize = 0;
                while (i < sequences_header.sequence_count) : (i += 1) {
                    const decompressed_size = decode_state.decodeSequenceRingBuffer(
                        dest,
                        &bit_stream,
                        sequence_size_limit,
                        i == sequences_header.sequence_count - 1,
                    ) catch return error.MalformedCompressedBlock;
                    bytes_written += decompressed_size;
                    sequence_size_limit -= decompressed_size;
                }

                bytes_read += bit_stream_bytes.len;
            }

            if (decode_state.literal_written_count < literals.header.regenerated_size) {
                const len = literals.header.regenerated_size - decode_state.literal_written_count;
                decode_state.decodeLiteralsRingBuffer(dest, len) catch
                    return error.MalformedCompressedBlock;
                bytes_written += len;
            }

            assert(bytes_read == block_header.block_size);
            consumed_count.* += bytes_read;
            if (bytes_written > block_size_max) return error.BlockSizeOverMaximum;
            return bytes_written;
        },
        .reserved => return error.ReservedBlock,
    }
}

/// Decode the header of a skippable frame.
pub fn decodeSkippableHeader(src: *const [8]u8) frame.Skippable.Header {
    const magic = readInt(u32, src[0..4]);
    assert(isSkippableMagic(magic));
    const frame_size = readInt(u32, src[4..8]);
    return .{
        .magic_number = magic,
        .frame_size = frame_size,
    };
}

/// Returns the content size of a skippable frame.
pub fn skippableFrameSize(src: *const [8]u8) usize {
    assert(isSkippableMagic(readInt(u32, src[0..4])));
    const frame_size = readInt(u32, src[4..8]);
    return frame_size;
}

/// Returns the window size required to decompress a frame, or `null` if it cannot be
/// determined, which indicates a malformed frame header.
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

const InvalidBit = error{ UnusedBitSet, ReservedBitSet };
/// Decode the header of a Zstandard frame. Returns `error.UnusedBitSet` or
/// `error.ReservedBitSet` if the corresponding bits are sets.
pub fn decodeZStandardHeader(src: []const u8, consumed_count: ?*usize) InvalidBit!frame.ZStandard.Header {
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
    return header;
}

/// Decode the header of a block.
pub fn decodeBlockHeader(src: *const [3]u8) frame.ZStandard.Block.Header {
    const last_block = src[0] & 1 == 1;
    const block_type = @intToEnum(frame.ZStandard.Block.Type, (src[0] & 0b110) >> 1);
    const block_size = ((src[0] & 0b11111000) >> 3) + (@as(u21, src[1]) << 5) + (@as(u21, src[2]) << 13);
    return .{
        .last_block = last_block,
        .block_type = block_type,
        .block_size = block_size,
    };
}

/// Decode a `LiteralsSection` from `src`, incrementing `consumed_count` by the
/// number of bytes the section uses.
pub fn decodeLiteralsSection(
    src: []const u8,
    consumed_count: *usize,
) (error{ MalformedLiteralsHeader, MalformedLiteralsSection } || DecodeHuffmanError)!LiteralsSection {
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

const DecodeHuffmanError = error{
    MalformedHuffmanTree,
    MalformedFseTable,
    MalformedAccuracyLog,
};

fn decodeHuffmanTree(src: []const u8, consumed_count: *usize) DecodeHuffmanError!LiteralsSection.HuffmanTree {
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
        const table_size = decodeFseTable(&bit_reader, 256, 6, &entries) catch |err| switch (err) {
            error.MalformedAccuracyLog, error.MalformedFseTable => |e| return e,
            error.EndOfStream => return error.MalformedFseTable,
        };
        const accuracy_log = std.math.log2_int_ceil(usize, table_size);

        const start_index = std.math.cast(usize, 1 + counting_reader.bytes_read) orelse return error.MalformedHuffmanTree;
        var huff_data = src[start_index .. compressed_size + 1];
        var huff_bits: ReverseBitReader = undefined;
        huff_bits.init(huff_data) catch return error.MalformedHuffmanTree;

        var i: usize = 0;
        var even_state: u32 = huff_bits.readBitsNoEof(u32, accuracy_log) catch return error.MalformedHuffmanTree;
        var odd_state: u32 = huff_bits.readBitsNoEof(u32, accuracy_log) catch return error.MalformedHuffmanTree;

        while (i < 255) {
            const even_data = entries[even_state];
            var read_bits: usize = 0;
            const even_bits = huff_bits.readBits(u32, even_data.bits, &read_bits) catch unreachable;
            weights[i] = std.math.cast(u4, even_data.symbol) orelse return error.MalformedHuffmanTree;
            i += 1;
            if (read_bits < even_data.bits) {
                weights[i] = std.math.cast(u4, entries[odd_state].symbol) orelse return error.MalformedHuffmanTree;
                i += 1;
                break;
            }
            even_state = even_data.baseline + even_bits;

            read_bits = 0;
            const odd_data = entries[odd_state];
            const odd_bits = huff_bits.readBits(u32, odd_data.bits, &read_bits) catch unreachable;
            weights[i] = std.math.cast(u4, odd_data.symbol) orelse return error.MalformedHuffmanTree;
            i += 1;
            if (read_bits < odd_data.bits) {
                if (i == 256) return error.MalformedHuffmanTree;
                weights[i] = std.math.cast(u4, entries[even_state].symbol) orelse return error.MalformedHuffmanTree;
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
        const weights_byte_count = (encoded_symbol_count + 1) / 2;
        if (src.len < weights_byte_count) return error.MalformedHuffmanTree;
        var i: usize = 0;
        while (i < weights_byte_count) : (i += 1) {
            weights[2 * i] = @intCast(u4, src[i + 1] >> 4);
            weights[2 * i + 1] = @intCast(u4, src[i + 1] & 0xF);
        }
        bytes_read += weights_byte_count;
    }
    var weight_power_sum: u16 = 0;
    for (weights[0 .. symbol_count - 1]) |value| {
        if (value > 0) {
            weight_power_sum += @as(u16, 1) << (value - 1);
        }
    }

    // advance to next power of two (even if weight_power_sum is a power of 2)
    max_number_of_bits = std.math.log2_int(u16, weight_power_sum) + 1;
    const next_power_of_two = @as(u16, 1) << max_number_of_bits;
    weights[symbol_count - 1] = std.math.log2_int(u16, next_power_of_two - weight_power_sum) + 1;

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

/// Decode a literals section header.
pub fn decodeLiteralsHeader(src: []const u8, consumed_count: *usize) error{MalformedLiteralsHeader}!LiteralsSection.Header {
    if (src.len == 0) return error.MalformedLiteralsHeader;
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
    return LiteralsSection.Header{
        .block_type = block_type,
        .size_format = size_format,
        .regenerated_size = regenerated_size,
        .compressed_size = compressed_size,
    };
}

/// Decode a sequences section header.
pub fn decodeSequencesHeader(
    src: []const u8,
    consumed_count: *usize,
) error{ MalformedSequencesHeader, ReservedBitSet }!SequencesSection.Header {
    if (src.len == 0) return error.MalformedSequencesHeader;
    var sequence_count: u24 = undefined;

    var bytes_read: usize = 0;
    const byte0 = src[0];
    if (byte0 == 0) {
        bytes_read += 1;
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
        if (src.len < 2) return error.MalformedSequencesHeader;
        sequence_count = (@as(u24, (byte0 - 128)) << 8) + src[1];
        bytes_read += 2;
    } else {
        if (src.len < 3) return error.MalformedSequencesHeader;
        sequence_count = src[1] + (@as(u24, src[2]) << 8) + 0x7F00;
        bytes_read += 3;
    }

    if (src.len < bytes_read + 1) return error.MalformedSequencesHeader;
    const compression_modes = src[bytes_read];
    bytes_read += 1;

    consumed_count.* += bytes_read;
    const matches_mode = @intToEnum(SequencesSection.Header.Mode, (compression_modes & 0b00001100) >> 2);
    const offsets_mode = @intToEnum(SequencesSection.Header.Mode, (compression_modes & 0b00110000) >> 4);
    const literal_mode = @intToEnum(SequencesSection.Header.Mode, (compression_modes & 0b11000000) >> 6);
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

        const state_share_dividend = std.math.ceilPowerOfTwo(u16, probability) catch
            return error.MalformedFseTable;
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
    const accuracy_log_biased = try bit_reader.readBitsNoEof(u4, 4);
    if (accuracy_log_biased > max_accuracy_log -| 5) return error.MalformedAccuracyLog;
    const accuracy_log = accuracy_log_biased + 5;

    var values: [256]u16 = undefined;
    var value_count: usize = 0;

    const total_probability = @as(u16, 1) << accuracy_log;
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

/// A bit reader for reading the reversed bit streams used to encode
/// FSE compressed data.
pub const ReverseBitReader = struct {
    byte_reader: ReversedByteReader,
    bit_reader: std.io.BitReader(.Big, ReversedByteReader.Reader),

    pub fn init(self: *ReverseBitReader, bytes: []const u8) error{BitStreamHasNoStartBit}!void {
        self.byte_reader = ReversedByteReader.init(bytes);
        self.bit_reader = std.io.bitReader(.Big, self.byte_reader.reader());
        while (0 == self.readBitsNoEof(u1, 1) catch return error.BitStreamHasNoStartBit) {}
    }

    pub fn readBitsNoEof(self: *@This(), comptime U: type, num_bits: usize) error{EndOfStream}!U {
        return self.bit_reader.readBitsNoEof(U, num_bits);
    }

    pub fn readBits(self: *@This(), comptime U: type, num_bits: usize, out_bits: *usize) error{}!U {
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
