const std = @import("std");
const assert = std.debug.assert;
const RingBuffer = std.RingBuffer;

const types = @import("../types.zig");
const frame = types.frame;
const Table = types.compressed_block.Table;
const LiteralsSection = types.compressed_block.LiteralsSection;
const SequencesSection = types.compressed_block.SequencesSection;

const huffman = @import("huffman.zig");
const readers = @import("../readers.zig");

const decodeFseTable = @import("fse.zig").decodeFseTable;

pub const Error = error{
    BlockSizeOverMaximum,
    MalformedBlockSize,
    ReservedBlock,
    MalformedRleBlock,
    MalformedCompressedBlock,
};

pub const DecodeState = struct {
    repeat_offsets: [3]u32,

    offset: StateData(8),
    match: StateData(9),
    literal: StateData(9),

    offset_fse_buffer: []Table.Fse,
    match_fse_buffer: []Table.Fse,
    literal_fse_buffer: []Table.Fse,

    fse_tables_undefined: bool,

    literal_stream_reader: readers.ReverseBitReader,
    literal_stream_index: usize,
    literal_streams: LiteralsSection.Streams,
    literal_header: LiteralsSection.Header,
    huffman_tree: ?LiteralsSection.HuffmanTree,

    literal_written_count: usize,
    written_count: usize = 0,

    fn StateData(comptime max_accuracy_log: comptime_int) type {
        return struct {
            state: State,
            table: Table,
            accuracy_log: u8,

            const State = std.meta.Int(.unsigned, max_accuracy_log);
        };
    }

    pub fn init(
        literal_fse_buffer: []Table.Fse,
        match_fse_buffer: []Table.Fse,
        offset_fse_buffer: []Table.Fse,
    ) DecodeState {
        return DecodeState{
            .repeat_offsets = .{
                types.compressed_block.start_repeated_offset_1,
                types.compressed_block.start_repeated_offset_2,
                types.compressed_block.start_repeated_offset_3,
            },

            .offset = undefined,
            .match = undefined,
            .literal = undefined,

            .literal_fse_buffer = literal_fse_buffer,
            .match_fse_buffer = match_fse_buffer,
            .offset_fse_buffer = offset_fse_buffer,

            .fse_tables_undefined = true,

            .literal_written_count = 0,
            .literal_header = undefined,
            .literal_streams = undefined,
            .literal_stream_reader = undefined,
            .literal_stream_index = undefined,
            .huffman_tree = null,

            .written_count = 0,
        };
    }

    /// Prepare the decoder to decode a compressed block. Loads the literals
    /// stream and Huffman tree from `literals` and reads the FSE tables from
    /// `source`.
    ///
    /// Errors returned:
    ///   - `error.BitStreamHasNoStartBit` if the (reversed) literal bitstream's
    ///     first byte does not have any bits set
    ///   - `error.TreelessLiteralsFirst` `literals` is a treeless literals
    ///     section and the decode state does not have a Huffman tree from a
    ///     previous block
    ///   - `error.RepeatModeFirst` on the first call if one of the sequence FSE
    ///     tables is set to repeat mode
    ///   - `error.MalformedAccuracyLog` if an FSE table has an invalid accuracy
    ///   - `error.MalformedFseTable` if there are errors decoding an FSE table
    ///   - `error.EndOfStream` if `source` ends before all FSE tables are read
    pub fn prepare(
        self: *DecodeState,
        source: anytype,
        literals: LiteralsSection,
        sequences_header: SequencesSection.Header,
    ) !void {
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
            try self.updateFseTable(source, .literal, sequences_header.literal_lengths);
            try self.updateFseTable(source, .offset, sequences_header.offsets);
            try self.updateFseTable(source, .match, sequences_header.match_lengths);
            self.fse_tables_undefined = false;
        }
    }

    /// Read initial FSE states for sequence decoding.
    ///
    /// Errors returned:
    ///   - `error.EndOfStream` if `bit_reader` does not contain enough bits.
    pub fn readInitialFseState(self: *DecodeState, bit_reader: *readers.ReverseBitReader) error{EndOfStream}!void {
        self.literal.state = try bit_reader.readBitsNoEof(u9, self.literal.accuracy_log);
        self.offset.state = try bit_reader.readBitsNoEof(u8, self.offset.accuracy_log);
        self.match.state = try bit_reader.readBitsNoEof(u9, self.match.accuracy_log);
    }

    fn updateRepeatOffset(self: *DecodeState, offset: u32) void {
        self.repeat_offsets[2] = self.repeat_offsets[1];
        self.repeat_offsets[1] = self.repeat_offsets[0];
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
        bit_reader: *readers.ReverseBitReader,
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
        source: anytype,
        comptime choice: DataType,
        mode: SequencesSection.Header.Mode,
    ) !void {
        const field_name = @tagName(choice);
        switch (mode) {
            .predefined => {
                @field(self, field_name).accuracy_log =
                    @field(types.compressed_block.default_accuracy_log, field_name);

                @field(self, field_name).table =
                    @field(types.compressed_block, "predefined_" ++ field_name ++ "_fse_table");
            },
            .rle => {
                @field(self, field_name).accuracy_log = 0;
                @field(self, field_name).table = .{ .rle = try source.readByte() };
            },
            .fse => {
                var bit_reader = readers.bitReader(source);

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
            },
            .repeat => if (self.fse_tables_undefined) return error.RepeatModeFirst,
        }
    }

    const Sequence = struct {
        literal_length: u32,
        match_length: u32,
        offset: u32,
    };

    fn nextSequence(
        self: *DecodeState,
        bit_reader: *readers.ReverseBitReader,
    ) error{ InvalidBitStream, EndOfStream }!Sequence {
        const raw_code = self.getCode(.offset);
        const offset_code = std.math.cast(u5, raw_code) orelse {
            return error.InvalidBitStream;
        };
        const offset_value = (@as(u32, 1) << offset_code) + try bit_reader.readBitsNoEof(u32, offset_code);

        const match_code = self.getCode(.match);
        if (match_code >= types.compressed_block.match_length_code_table.len)
            return error.InvalidBitStream;
        const match = types.compressed_block.match_length_code_table[match_code];
        const match_length = match[0] + try bit_reader.readBitsNoEof(u32, match[1]);

        const literal_code = self.getCode(.literal);
        if (literal_code >= types.compressed_block.literals_length_code_table.len)
            return error.InvalidBitStream;
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

        if (offset == 0) return error.InvalidBitStream;

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
        for (
            dest[write_pos + sequence.literal_length ..][0..sequence.match_length],
            dest[copy_start..][0..sequence.match_length],
        ) |*d, s| d.* = s;
        self.written_count += sequence.match_length;
    }

    fn executeSequenceRingBuffer(
        self: *DecodeState,
        dest: *RingBuffer,
        sequence: Sequence,
    ) (error{MalformedSequence} || DecodeLiteralsError)!void {
        if (sequence.offset > @min(dest.data.len, self.written_count + sequence.literal_length))
            return error.MalformedSequence;

        try self.decodeLiteralsRingBuffer(dest, sequence.literal_length);
        const copy_start = dest.write_index + dest.data.len - sequence.offset;
        const copy_slice = dest.sliceAt(copy_start, sequence.match_length);
        dest.writeSliceForwardsAssumeCapacity(copy_slice.first);
        dest.writeSliceForwardsAssumeCapacity(copy_slice.second);
        self.written_count += sequence.match_length;
    }

    const DecodeSequenceError = error{
        InvalidBitStream,
        EndOfStream,
        MalformedSequence,
        MalformedFseBits,
    } || DecodeLiteralsError;

    /// Decode one sequence from `bit_reader` into `dest`, written starting at
    /// `write_pos` and update FSE states if `last_sequence` is `false`.
    /// `prepare()` must be called for the block before attempting to decode
    /// sequences.
    ///
    /// Errors returned:
    ///   - `error.MalformedSequence` if the decompressed sequence would be
    ///     longer than `sequence_size_limit` or the sequence's offset is too
    ///     large
    ///   - `error.UnexpectedEndOfLiteralStream` if the decoder state's literal
    ///     streams do not contain enough literals for the sequence (this may
    ///     mean the literal stream or the sequence is malformed).
    ///   - `error.InvalidBitStream` if the FSE sequence bitstream is malformed
    ///   - `error.EndOfStream` if `bit_reader` does not contain enough bits
    ///   - `error.DestTooSmall` if `dest` is not large enough to holde the
    ///     decompressed sequence
    pub fn decodeSequenceSlice(
        self: *DecodeState,
        dest: []u8,
        write_pos: usize,
        bit_reader: *readers.ReverseBitReader,
        sequence_size_limit: usize,
        last_sequence: bool,
    ) (error{DestTooSmall} || DecodeSequenceError)!usize {
        const sequence = try self.nextSequence(bit_reader);
        const sequence_length = @as(usize, sequence.literal_length) + sequence.match_length;
        if (sequence_length > sequence_size_limit) return error.MalformedSequence;
        if (sequence_length > dest[write_pos..].len) return error.DestTooSmall;

        try self.executeSequenceSlice(dest, write_pos, sequence);
        if (!last_sequence) {
            try self.updateState(.literal, bit_reader);
            try self.updateState(.match, bit_reader);
            try self.updateState(.offset, bit_reader);
        }
        return sequence_length;
    }

    /// Decode one sequence from `bit_reader` into `dest`; see
    /// `decodeSequenceSlice`.
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

    fn initLiteralStream(self: *DecodeState, bytes: []const u8) error{BitStreamHasNoStartBit}!void {
        try self.literal_stream_reader.init(bytes);
    }

    fn isLiteralStreamEmpty(self: *DecodeState) bool {
        switch (self.literal_streams) {
            .one => return self.literal_stream_reader.isEmpty(),
            .four => return self.literal_stream_index == 3 and self.literal_stream_reader.isEmpty(),
        }
    }

    const LiteralBitsError = error{
        BitStreamHasNoStartBit,
        UnexpectedEndOfLiteralStream,
    };
    fn readLiteralsBits(
        self: *DecodeState,
        bit_count_to_read: usize,
    ) LiteralBitsError!u16 {
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
        NotFound,
    } || LiteralBitsError;

    /// Decode `len` bytes of literals into `dest`.
    ///
    /// Errors returned:
    ///   - `error.MalformedLiteralsLength` if the number of literal bytes
    ///     decoded by `self` plus `len` is greater than the regenerated size of
    ///     `literals`
    ///   - `error.UnexpectedEndOfLiteralStream` and `error.NotFound` if there
    ///     are problems decoding Huffman compressed literals
    pub fn decodeLiteralsSlice(
        self: *DecodeState,
        dest: []u8,
        len: usize,
    ) DecodeLiteralsError!void {
        if (self.literal_written_count + len > self.literal_header.regenerated_size)
            return error.MalformedLiteralsLength;

        switch (self.literal_header.block_type) {
            .raw => {
                const literal_data = self.literal_streams.one[self.literal_written_count..][0..len];
                @memcpy(dest[0..len], literal_data);
                self.literal_written_count += len;
                self.written_count += len;
            },
            .rle => {
                for (0..len) |i| {
                    dest[i] = self.literal_streams.one[0];
                }
                self.literal_written_count += len;
                self.written_count += len;
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
                for (0..len) |i| {
                    var prefix: u16 = 0;
                    while (true) {
                        const new_bits = self.readLiteralsBits(bit_count_to_read) catch |err| {
                            return err;
                        };
                        prefix <<= bit_count_to_read;
                        prefix |= new_bits;
                        bits_read += bit_count_to_read;
                        const result = huffman_tree.query(huffman_tree_index, prefix) catch |err| {
                            return err;
                        };

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
                self.written_count += len;
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
                self.written_count += len;
            },
            .rle => {
                for (0..len) |_| {
                    dest.writeAssumeCapacity(self.literal_streams.one[0]);
                }
                self.literal_written_count += len;
                self.written_count += len;
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
                for (0..len) |_| {
                    var prefix: u16 = 0;
                    while (true) {
                        const new_bits = try self.readLiteralsBits(bit_count_to_read);
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
                self.written_count += len;
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

/// Decode a single block from `src` into `dest`. The beginning of `src` must be
/// the start of the block content (i.e. directly after the block header).
/// Increments `consumed_count` by the number of bytes read from `src` to decode
/// the block and returns the decompressed size of the block.
///
/// Errors returned:
///
///   - `error.BlockSizeOverMaximum` if block's size is larger than 1 << 17 or
///     `dest[written_count..].len`
///   - `error.MalformedBlockSize` if `src.len` is smaller than the block size
///     and the block is a raw or compressed block
///   - `error.ReservedBlock` if the block is a reserved block
///   - `error.MalformedRleBlock` if the block is an RLE block and `src.len < 1`
///   - `error.MalformedCompressedBlock` if there are errors decoding a
///     compressed block
///   - `error.DestTooSmall` is `dest` is not large enough to hold the
///     decompressed block
pub fn decodeBlock(
    dest: []u8,
    src: []const u8,
    block_header: frame.Zstandard.Block.Header,
    decode_state: *DecodeState,
    consumed_count: *usize,
    block_size_max: usize,
    written_count: usize,
) (error{DestTooSmall} || Error)!usize {
    const block_size = block_header.block_size;
    if (block_size_max < block_size) return error.BlockSizeOverMaximum;
    switch (block_header.block_type) {
        .raw => {
            if (src.len < block_size) return error.MalformedBlockSize;
            if (dest[written_count..].len < block_size) return error.DestTooSmall;
            @memcpy(dest[written_count..][0..block_size], src[0..block_size]);
            consumed_count.* += block_size;
            decode_state.written_count += block_size;
            return block_size;
        },
        .rle => {
            if (src.len < 1) return error.MalformedRleBlock;
            if (dest[written_count..].len < block_size) return error.DestTooSmall;
            for (written_count..block_size + written_count) |write_pos| {
                dest[write_pos] = src[0];
            }
            consumed_count.* += 1;
            decode_state.written_count += block_size;
            return block_size;
        },
        .compressed => {
            if (src.len < block_size) return error.MalformedBlockSize;
            var bytes_read: usize = 0;
            const literals = decodeLiteralsSectionSlice(src[0..block_size], &bytes_read) catch
                return error.MalformedCompressedBlock;
            var fbs = std.io.fixedBufferStream(src[bytes_read..block_size]);
            const fbs_reader = fbs.reader();
            const sequences_header = decodeSequencesHeader(fbs_reader) catch
                return error.MalformedCompressedBlock;

            decode_state.prepare(fbs_reader, literals, sequences_header) catch
                return error.MalformedCompressedBlock;

            bytes_read += fbs.pos;

            var bytes_written: usize = 0;
            {
                const bit_stream_bytes = src[bytes_read..block_size];
                var bit_stream: readers.ReverseBitReader = undefined;
                bit_stream.init(bit_stream_bytes) catch return error.MalformedCompressedBlock;

                if (sequences_header.sequence_count > 0) {
                    decode_state.readInitialFseState(&bit_stream) catch
                        return error.MalformedCompressedBlock;

                    var sequence_size_limit = block_size_max;
                    for (0..sequences_header.sequence_count) |i| {
                        const write_pos = written_count + bytes_written;
                        const decompressed_size = decode_state.decodeSequenceSlice(
                            dest,
                            write_pos,
                            &bit_stream,
                            sequence_size_limit,
                            i == sequences_header.sequence_count - 1,
                        ) catch |err| switch (err) {
                            error.DestTooSmall => return error.DestTooSmall,
                            else => return error.MalformedCompressedBlock,
                        };
                        bytes_written += decompressed_size;
                        sequence_size_limit -= decompressed_size;
                    }
                }

                if (!bit_stream.isEmpty()) {
                    return error.MalformedCompressedBlock;
                }
            }

            if (decode_state.literal_written_count < literals.header.regenerated_size) {
                const len = literals.header.regenerated_size - decode_state.literal_written_count;
                if (len > dest[written_count + bytes_written ..].len) return error.DestTooSmall;
                decode_state.decodeLiteralsSlice(dest[written_count + bytes_written ..], len) catch
                    return error.MalformedCompressedBlock;
                bytes_written += len;
            }

            switch (decode_state.literal_header.block_type) {
                .treeless, .compressed => {
                    if (!decode_state.isLiteralStreamEmpty()) return error.MalformedCompressedBlock;
                },
                .raw, .rle => {},
            }

            consumed_count.* += block_size;
            return bytes_written;
        },
        .reserved => return error.ReservedBlock,
    }
}

/// Decode a single block from `src` into `dest`; see `decodeBlock()`. Returns
/// the size of the decompressed block, which can be used with `dest.sliceLast()`
/// to get the decompressed bytes. `error.BlockSizeOverMaximum` is returned if
/// the block's compressed or decompressed size is larger than `block_size_max`.
pub fn decodeBlockRingBuffer(
    dest: *RingBuffer,
    src: []const u8,
    block_header: frame.Zstandard.Block.Header,
    decode_state: *DecodeState,
    consumed_count: *usize,
    block_size_max: usize,
) Error!usize {
    const block_size = block_header.block_size;
    if (block_size_max < block_size) return error.BlockSizeOverMaximum;
    switch (block_header.block_type) {
        .raw => {
            if (src.len < block_size) return error.MalformedBlockSize;
            // dest may have length zero if block_size == 0, causing division by zero in
            // writeSliceAssumeCapacity()
            if (block_size > 0) {
                const data = src[0..block_size];
                dest.writeSliceAssumeCapacity(data);
                consumed_count.* += block_size;
                decode_state.written_count += block_size;
            }
            return block_size;
        },
        .rle => {
            if (src.len < 1) return error.MalformedRleBlock;
            for (0..block_size) |_| {
                dest.writeAssumeCapacity(src[0]);
            }
            consumed_count.* += 1;
            decode_state.written_count += block_size;
            return block_size;
        },
        .compressed => {
            if (src.len < block_size) return error.MalformedBlockSize;
            var bytes_read: usize = 0;
            const literals = decodeLiteralsSectionSlice(src[0..block_size], &bytes_read) catch
                return error.MalformedCompressedBlock;
            var fbs = std.io.fixedBufferStream(src[bytes_read..block_size]);
            const fbs_reader = fbs.reader();
            const sequences_header = decodeSequencesHeader(fbs_reader) catch
                return error.MalformedCompressedBlock;

            decode_state.prepare(fbs_reader, literals, sequences_header) catch
                return error.MalformedCompressedBlock;

            bytes_read += fbs.pos;

            var bytes_written: usize = 0;
            {
                const bit_stream_bytes = src[bytes_read..block_size];
                var bit_stream: readers.ReverseBitReader = undefined;
                bit_stream.init(bit_stream_bytes) catch return error.MalformedCompressedBlock;

                if (sequences_header.sequence_count > 0) {
                    decode_state.readInitialFseState(&bit_stream) catch
                        return error.MalformedCompressedBlock;

                    var sequence_size_limit = block_size_max;
                    for (0..sequences_header.sequence_count) |i| {
                        const decompressed_size = decode_state.decodeSequenceRingBuffer(
                            dest,
                            &bit_stream,
                            sequence_size_limit,
                            i == sequences_header.sequence_count - 1,
                        ) catch return error.MalformedCompressedBlock;
                        bytes_written += decompressed_size;
                        sequence_size_limit -= decompressed_size;
                    }
                }

                if (!bit_stream.isEmpty()) {
                    return error.MalformedCompressedBlock;
                }
            }

            if (decode_state.literal_written_count < literals.header.regenerated_size) {
                const len = literals.header.regenerated_size - decode_state.literal_written_count;
                decode_state.decodeLiteralsRingBuffer(dest, len) catch
                    return error.MalformedCompressedBlock;
                bytes_written += len;
            }

            switch (decode_state.literal_header.block_type) {
                .treeless, .compressed => {
                    if (!decode_state.isLiteralStreamEmpty()) return error.MalformedCompressedBlock;
                },
                .raw, .rle => {},
            }

            consumed_count.* += block_size;
            if (bytes_written > block_size_max) return error.BlockSizeOverMaximum;
            return bytes_written;
        },
        .reserved => return error.ReservedBlock,
    }
}

/// Decode a single block from `source` into `dest`. Literal and sequence data
/// from the block is copied into `literals_buffer` and `sequence_buffer`, which
/// must be large enough or `error.LiteralsBufferTooSmall` and
/// `error.SequenceBufferTooSmall` are returned (the maximum block size is an
/// upper bound for the size of both buffers). See `decodeBlock`
/// and `decodeBlockRingBuffer` for function that can decode a block without
/// these extra copies. `error.EndOfStream` is returned if `source` does not
/// contain enough bytes.
pub fn decodeBlockReader(
    dest: *RingBuffer,
    source: anytype,
    block_header: frame.Zstandard.Block.Header,
    decode_state: *DecodeState,
    block_size_max: usize,
    literals_buffer: []u8,
    sequence_buffer: []u8,
) !void {
    const block_size = block_header.block_size;
    var block_reader_limited = std.io.limitedReader(source, block_size);
    const block_reader = block_reader_limited.reader();
    if (block_size_max < block_size) return error.BlockSizeOverMaximum;
    switch (block_header.block_type) {
        .raw => {
            if (block_size == 0) return;
            const slice = dest.sliceAt(dest.write_index, block_size);
            try source.readNoEof(slice.first);
            try source.readNoEof(slice.second);
            dest.write_index = dest.mask2(dest.write_index + block_size);
            decode_state.written_count += block_size;
        },
        .rle => {
            const byte = try source.readByte();
            for (0..block_size) |_| {
                dest.writeAssumeCapacity(byte);
            }
            decode_state.written_count += block_size;
        },
        .compressed => {
            const literals = try decodeLiteralsSection(block_reader, literals_buffer);
            const sequences_header = try decodeSequencesHeader(block_reader);

            try decode_state.prepare(block_reader, literals, sequences_header);

            var bytes_written: usize = 0;
            {
                const size = try block_reader.readAll(sequence_buffer);
                var bit_stream: readers.ReverseBitReader = undefined;
                try bit_stream.init(sequence_buffer[0..size]);

                if (sequences_header.sequence_count > 0) {
                    if (sequence_buffer.len < block_reader_limited.bytes_left)
                        return error.SequenceBufferTooSmall;

                    decode_state.readInitialFseState(&bit_stream) catch
                        return error.MalformedCompressedBlock;

                    var sequence_size_limit = block_size_max;
                    for (0..sequences_header.sequence_count) |i| {
                        const decompressed_size = decode_state.decodeSequenceRingBuffer(
                            dest,
                            &bit_stream,
                            sequence_size_limit,
                            i == sequences_header.sequence_count - 1,
                        ) catch return error.MalformedCompressedBlock;
                        sequence_size_limit -= decompressed_size;
                        bytes_written += decompressed_size;
                    }
                }

                if (!bit_stream.isEmpty()) {
                    return error.MalformedCompressedBlock;
                }
            }

            if (decode_state.literal_written_count < literals.header.regenerated_size) {
                const len = literals.header.regenerated_size - decode_state.literal_written_count;
                decode_state.decodeLiteralsRingBuffer(dest, len) catch
                    return error.MalformedCompressedBlock;
                bytes_written += len;
            }

            switch (decode_state.literal_header.block_type) {
                .treeless, .compressed => {
                    if (!decode_state.isLiteralStreamEmpty()) return error.MalformedCompressedBlock;
                },
                .raw, .rle => {},
            }

            if (bytes_written > block_size_max) return error.BlockSizeOverMaximum;
            if (block_reader_limited.bytes_left != 0) return error.MalformedCompressedBlock;
            decode_state.literal_written_count = 0;
        },
        .reserved => return error.ReservedBlock,
    }
}

/// Decode the header of a block.
pub fn decodeBlockHeader(src: *const [3]u8) frame.Zstandard.Block.Header {
    const last_block = src[0] & 1 == 1;
    const block_type = @as(frame.Zstandard.Block.Type, @enumFromInt((src[0] & 0b110) >> 1));
    const block_size = ((src[0] & 0b11111000) >> 3) + (@as(u21, src[1]) << 5) + (@as(u21, src[2]) << 13);
    return .{
        .last_block = last_block,
        .block_type = block_type,
        .block_size = block_size,
    };
}

/// Decode the header of a block.
///
/// Errors returned:
///   - `error.EndOfStream` if `src.len < 3`
pub fn decodeBlockHeaderSlice(src: []const u8) error{EndOfStream}!frame.Zstandard.Block.Header {
    if (src.len < 3) return error.EndOfStream;
    return decodeBlockHeader(src[0..3]);
}

/// Decode a `LiteralsSection` from `src`, incrementing `consumed_count` by the
/// number of bytes the section uses.
///
/// Errors returned:
///   - `error.MalformedLiteralsHeader` if the header is invalid
///   - `error.MalformedLiteralsSection` if there are decoding errors
///   - `error.MalformedAccuracyLog` if compressed literals have invalid
///     accuracy
///   - `error.MalformedFseTable` if compressed literals have invalid FSE table
///   - `error.MalformedHuffmanTree` if there are errors decoding a Huffamn tree
///   - `error.EndOfStream` if there are not enough bytes in `src`
pub fn decodeLiteralsSectionSlice(
    src: []const u8,
    consumed_count: *usize,
) (error{ MalformedLiteralsHeader, MalformedLiteralsSection, EndOfStream } || huffman.Error)!LiteralsSection {
    var bytes_read: usize = 0;
    const header = header: {
        var fbs = std.io.fixedBufferStream(src);
        defer bytes_read = fbs.pos;
        break :header decodeLiteralsHeader(fbs.reader()) catch return error.MalformedLiteralsHeader;
    };
    switch (header.block_type) {
        .raw => {
            if (src.len < bytes_read + header.regenerated_size) return error.MalformedLiteralsSection;
            const stream = src[bytes_read..][0..header.regenerated_size];
            consumed_count.* += header.regenerated_size + bytes_read;
            return LiteralsSection{
                .header = header,
                .huffman_tree = null,
                .streams = .{ .one = stream },
            };
        },
        .rle => {
            if (src.len < bytes_read + 1) return error.MalformedLiteralsSection;
            const stream = src[bytes_read..][0..1];
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
                try huffman.decodeHuffmanTreeSlice(src[bytes_read..], &bytes_read)
            else
                null;
            const huffman_tree_size = bytes_read - huffman_tree_start;
            const total_streams_size = std.math.sub(usize, header.compressed_size.?, huffman_tree_size) catch
                return error.MalformedLiteralsSection;

            if (src.len < bytes_read + total_streams_size) return error.MalformedLiteralsSection;
            const stream_data = src[bytes_read .. bytes_read + total_streams_size];

            const streams = try decodeStreams(header.size_format, stream_data);
            consumed_count.* += bytes_read + total_streams_size;
            return LiteralsSection{
                .header = header,
                .huffman_tree = huffman_tree,
                .streams = streams,
            };
        },
    }
}

/// Decode a `LiteralsSection` from `src`, incrementing `consumed_count` by the
/// number of bytes the section uses. See `decodeLiterasSectionSlice()`.
pub fn decodeLiteralsSection(
    source: anytype,
    buffer: []u8,
) !LiteralsSection {
    const header = try decodeLiteralsHeader(source);
    switch (header.block_type) {
        .raw => {
            try source.readNoEof(buffer[0..header.regenerated_size]);
            return LiteralsSection{
                .header = header,
                .huffman_tree = null,
                .streams = .{ .one = buffer },
            };
        },
        .rle => {
            buffer[0] = try source.readByte();
            return LiteralsSection{
                .header = header,
                .huffman_tree = null,
                .streams = .{ .one = buffer[0..1] },
            };
        },
        .compressed, .treeless => {
            var counting_reader = std.io.countingReader(source);
            const huffman_tree = if (header.block_type == .compressed)
                try huffman.decodeHuffmanTree(counting_reader.reader(), buffer)
            else
                null;
            const huffman_tree_size = @as(usize, @intCast(counting_reader.bytes_read));
            const total_streams_size = std.math.sub(usize, header.compressed_size.?, huffman_tree_size) catch
                return error.MalformedLiteralsSection;

            if (total_streams_size > buffer.len) return error.LiteralsBufferTooSmall;
            try source.readNoEof(buffer[0..total_streams_size]);
            const stream_data = buffer[0..total_streams_size];

            const streams = try decodeStreams(header.size_format, stream_data);
            return LiteralsSection{
                .header = header,
                .huffman_tree = huffman_tree,
                .streams = streams,
            };
        },
    }
}

fn decodeStreams(size_format: u2, stream_data: []const u8) !LiteralsSection.Streams {
    if (size_format == 0) {
        return .{ .one = stream_data };
    }

    if (stream_data.len < 6) return error.MalformedLiteralsSection;

    const stream_1_length: usize = std.mem.readInt(u16, stream_data[0..2], .little);
    const stream_2_length: usize = std.mem.readInt(u16, stream_data[2..4], .little);
    const stream_3_length: usize = std.mem.readInt(u16, stream_data[4..6], .little);

    const stream_1_start = 6;
    const stream_2_start = stream_1_start + stream_1_length;
    const stream_3_start = stream_2_start + stream_2_length;
    const stream_4_start = stream_3_start + stream_3_length;

    if (stream_data.len < stream_4_start) return error.MalformedLiteralsSection;

    return .{ .four = .{
        stream_data[stream_1_start .. stream_1_start + stream_1_length],
        stream_data[stream_2_start .. stream_2_start + stream_2_length],
        stream_data[stream_3_start .. stream_3_start + stream_3_length],
        stream_data[stream_4_start..],
    } };
}

/// Decode a literals section header.
///
/// Errors returned:
///   - `error.EndOfStream` if there are not enough bytes in `source`
pub fn decodeLiteralsHeader(source: anytype) !LiteralsSection.Header {
    const byte0 = try source.readByte();
    const block_type = @as(LiteralsSection.BlockType, @enumFromInt(byte0 & 0b11));
    const size_format = @as(u2, @intCast((byte0 & 0b1100) >> 2));
    var regenerated_size: u20 = undefined;
    var compressed_size: ?u18 = null;
    switch (block_type) {
        .raw, .rle => {
            switch (size_format) {
                0, 2 => {
                    regenerated_size = byte0 >> 3;
                },
                1 => regenerated_size = (byte0 >> 4) + (@as(u20, try source.readByte()) << 4),
                3 => regenerated_size = (byte0 >> 4) +
                    (@as(u20, try source.readByte()) << 4) +
                    (@as(u20, try source.readByte()) << 12),
            }
        },
        .compressed, .treeless => {
            const byte1 = try source.readByte();
            const byte2 = try source.readByte();
            switch (size_format) {
                0, 1 => {
                    regenerated_size = (byte0 >> 4) + ((@as(u20, byte1) & 0b00111111) << 4);
                    compressed_size = ((byte1 & 0b11000000) >> 6) + (@as(u18, byte2) << 2);
                },
                2 => {
                    const byte3 = try source.readByte();
                    regenerated_size = (byte0 >> 4) + (@as(u20, byte1) << 4) + ((@as(u20, byte2) & 0b00000011) << 12);
                    compressed_size = ((byte2 & 0b11111100) >> 2) + (@as(u18, byte3) << 6);
                },
                3 => {
                    const byte3 = try source.readByte();
                    const byte4 = try source.readByte();
                    regenerated_size = (byte0 >> 4) + (@as(u20, byte1) << 4) + ((@as(u20, byte2) & 0b00111111) << 12);
                    compressed_size = ((byte2 & 0b11000000) >> 6) + (@as(u18, byte3) << 2) + (@as(u18, byte4) << 10);
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
///
/// Errors returned:
///   - `error.ReservedBitSet` if the reserved bit is set
///   - `error.EndOfStream` if there are not enough bytes in `source`
pub fn decodeSequencesHeader(
    source: anytype,
) !SequencesSection.Header {
    var sequence_count: u24 = undefined;

    const byte0 = try source.readByte();
    if (byte0 == 0) {
        return SequencesSection.Header{
            .sequence_count = 0,
            .offsets = undefined,
            .match_lengths = undefined,
            .literal_lengths = undefined,
        };
    } else if (byte0 < 128) {
        sequence_count = byte0;
    } else if (byte0 < 255) {
        sequence_count = (@as(u24, (byte0 - 128)) << 8) + try source.readByte();
    } else {
        sequence_count = (try source.readByte()) + (@as(u24, try source.readByte()) << 8) + 0x7F00;
    }

    const compression_modes = try source.readByte();

    const matches_mode = @as(SequencesSection.Header.Mode, @enumFromInt((compression_modes & 0b00001100) >> 2));
    const offsets_mode = @as(SequencesSection.Header.Mode, @enumFromInt((compression_modes & 0b00110000) >> 4));
    const literal_mode = @as(SequencesSection.Header.Mode, @enumFromInt((compression_modes & 0b11000000) >> 6));
    if (compression_modes & 0b11 != 0) return error.ReservedBitSet;

    return SequencesSection.Header{
        .sequence_count = sequence_count,
        .offsets = offsets_mode,
        .match_lengths = matches_mode,
        .literal_lengths = literal_mode,
    };
}
