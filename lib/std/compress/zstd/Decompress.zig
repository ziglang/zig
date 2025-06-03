const Decompress = @This();
const std = @import("std");
const assert = std.debug.assert;
const Reader = std.io.Reader;
const Limit = std.io.Limit;
const zstd = @import("../zstd.zig");
const Writer = std.io.Writer;

input: *Reader,
state: State,
verify_checksum: bool,
err: ?Error = null,

const State = union(enum) {
    new_frame,
    in_frame: InFrame,
    skipping_frame: usize,
    end,

    const InFrame = struct {
        frame: Frame,
        checksum: ?u32,
        decompressed_size: usize,
    };
};

pub const Options = struct {
    verify_checksum: bool = true,
};

pub const Error = error{
    BadMagic,
    BlockOversize,
    ChecksumFailure,
    ContentOversize,
    DictionaryIdFlagUnsupported,
    EndOfStream,
    HuffmanTreeIncomplete,
    InvalidBitStream,
    MalformedAccuracyLog,
    MalformedBlock,
    MalformedCompressedBlock,
    MalformedFrame,
    MalformedFseBits,
    MalformedFseTable,
    MalformedHuffmanTree,
    MalformedLiteralsHeader,
    MalformedLiteralsLength,
    MalformedLiteralsSection,
    MalformedSequence,
    MissingStartBit,
    OutputBufferUndersize,
    InputBufferUndersize,
    ReadFailed,
    RepeatModeFirst,
    ReservedBitSet,
    ReservedBlock,
    SequenceBufferUndersize,
    TreelessLiteralsFirst,
    UnexpectedEndOfLiteralStream,
    WindowOversize,
    WindowSizeUnknown,
};

pub fn init(input: *Reader, options: Options) Decompress {
    return .{
        .input = input,
        .state = .new_frame,
        .verify_checksum = options.verify_checksum,
    };
}

pub fn reader(self: *Decompress) Reader {
    return .{
        .context = self,
        .vtable = &.{ .read = read },
    };
}

fn read(context: ?*anyopaque, bw: *Writer, limit: Limit) Reader.StreamError!usize {
    const d: *Decompress = @ptrCast(@alignCast(context));
    const in = d.input;

    switch (d.state) {
        .new_frame => {
            // Allow error.EndOfStream only on the frame magic.
            const magic = try in.takeEnumNonexhaustive(Frame.Magic, .little);
            initFrame(d, bw.buffer.len, magic) catch |err| {
                d.err = err;
                return error.ReadFailed;
            };
            return readInFrame(d, bw, limit, &d.state.in_frame) catch |err| switch (err) {
                error.ReadFailed => return error.ReadFailed,
                error.WriteFailed => return error.WriteFailed,
                else => |e| {
                    d.err = e;
                    return error.ReadFailed;
                },
            };
        },
        .in_frame => |*in_frame| {
            return readInFrame(d, bw, limit, in_frame) catch |err| switch (err) {
                error.ReadFailed => return error.ReadFailed,
                error.WriteFailed => return error.WriteFailed,
                else => |e| {
                    d.err = e;
                    return error.ReadFailed;
                },
            };
        },
        .skipping_frame => |*remaining| {
            const n = in.discard(.limited(remaining.*)) catch |err| {
                d.err = err;
                return error.ReadFailed;
            };
            remaining.* -= n;
            if (remaining.* == 0) d.state = .new_frame;
            return 0;
        },
        .end => return error.EndOfStream,
    }
}

fn initFrame(d: *Decompress, window_size_max: usize, magic: Frame.Magic) !void {
    const in = d.input;
    switch (magic.kind() orelse return error.BadMagic) {
        .zstandard => {
            const header = try Frame.Zstandard.Header.decode(in);
            d.state = .{ .in_frame = .{
                .frame = try Frame.init(header, window_size_max, d.verify_checksum),
                .checksum = null,
                .decompressed_size = 0,
            } };
        },
        .skippable => {
            const frame_size = try in.takeInt(u32, .little);
            d.state = .{ .skipping_frame = frame_size };
        },
    }
}

fn readInFrame(d: *Decompress, bw: *Writer, limit: Limit, state: *State.InFrame) !usize {
    const in = d.input;

    const header_bytes = try in.takeArray(3);
    const block_header: Frame.Zstandard.Block.Header = @bitCast(header_bytes.*);
    const block_size = block_header.size;
    const frame_block_size_max = state.frame.block_size_max;
    if (frame_block_size_max < block_size) return error.BlockOversize;
    if (@intFromEnum(limit) < block_size) return error.OutputBufferUndersize;
    var bytes_written: usize = 0;
    switch (block_header.type) {
        .raw => {
            try in.readAll(bw, .limited(block_size));
            bytes_written = block_size;
        },
        .rle => {
            const byte = try in.takeByte();
            try bw.splatByteAll(byte, block_size);
            bytes_written = block_size;
        },
        .compressed => {
            var literal_fse_buffer: [zstd.table_size_max.literal]Table.Fse = undefined;
            var match_fse_buffer: [zstd.table_size_max.match]Table.Fse = undefined;
            var offset_fse_buffer: [zstd.table_size_max.offset]Table.Fse = undefined;
            var literals_buffer: [zstd.block_size_max]u8 = undefined;
            var sequence_buffer: [zstd.block_size_max]u8 = undefined;
            var decode: Frame.Zstandard.Decode = .init(&literal_fse_buffer, &match_fse_buffer, &offset_fse_buffer);
            var remaining: Limit = .limited(block_size);
            const literals = try LiteralsSection.decode(in, &remaining, &literals_buffer);
            const sequences_header = try SequencesSection.Header.decode(in, &remaining);

            try decode.prepare(in, &remaining, literals, sequences_header);

            {
                if (sequence_buffer.len < @intFromEnum(remaining))
                    return error.SequenceBufferUndersize;
                const seq_slice = remaining.slice(&sequence_buffer);
                try in.readSlice(seq_slice);
                var bit_stream = try ReverseBitReader.init(seq_slice);

                if (sequences_header.sequence_count > 0) {
                    try decode.readInitialFseState(&bit_stream);

                    // Ensures the following calls to `decodeSequence` will not flush.
                    if (frame_block_size_max > bw.buffer.len) return error.OutputBufferUndersize;
                    const dest = (try bw.writableSliceGreedy(frame_block_size_max))[0..frame_block_size_max];
                    for (0..sequences_header.sequence_count - 1) |_| {
                        bytes_written += try decode.decodeSequence(dest, bytes_written, &bit_stream);
                        try decode.updateState(.literal, &bit_stream);
                        try decode.updateState(.match, &bit_stream);
                        try decode.updateState(.offset, &bit_stream);
                    }
                    bytes_written += try decode.decodeSequence(dest, bytes_written, &bit_stream);
                    if (bytes_written > dest.len) return error.MalformedSequence;
                    bw.advance(bytes_written);
                }

                if (!bit_stream.isEmpty()) {
                    return error.MalformedCompressedBlock;
                }
            }

            if (decode.literal_written_count < literals.header.regenerated_size) {
                const len = literals.header.regenerated_size - decode.literal_written_count;
                try decode.decodeLiterals(bw, len);
                decode.literal_written_count += len;
                bytes_written += len;
            }

            switch (decode.literal_header.block_type) {
                .treeless, .compressed => {
                    if (!decode.isLiteralStreamEmpty()) return error.MalformedCompressedBlock;
                },
                .raw, .rle => {},
            }

            if (bytes_written > frame_block_size_max) return error.BlockOversize;

            state.decompressed_size += bytes_written;
            if (state.frame.content_size) |size| {
                if (state.decompressed_size > size) return error.MalformedFrame;
            }
        },
        .reserved => return error.ReservedBlock,
    }

    if (state.frame.hasher_opt) |*hasher| {
        if (bytes_written > 0) {
            _ = hasher;
            @panic("TODO all those bytes written needed to go through the hasher too");
        }
    }

    if (block_header.last) {
        if (state.frame.has_checksum) {
            const expected_checksum = try in.takeInt(u32, .little);
            if (state.frame.hasher_opt) |*hasher| {
                const actual_checksum: u32 = @truncate(hasher.final());
                if (expected_checksum != actual_checksum) return error.ChecksumFailure;
            }
        }
        if (state.frame.content_size) |content_size| {
            if (content_size != state.decompressed_size) {
                return error.MalformedFrame;
            }
        }
        d.state = .new_frame;
    }

    return bytes_written;
}

pub const Frame = struct {
    hasher_opt: ?std.hash.XxHash64,
    window_size: usize,
    has_checksum: bool,
    block_size_max: usize,
    content_size: ?usize,

    pub const Magic = enum(u32) {
        zstandard = 0xFD2FB528,
        _,

        pub fn kind(m: Magic) ?Kind {
            return switch (@intFromEnum(m)) {
                @intFromEnum(Magic.zstandard) => .zstandard,
                @intFromEnum(Skippable.magic_min)...@intFromEnum(Skippable.magic_max) => .skippable,
                else => null,
            };
        }

        pub fn isSkippable(m: Magic) bool {
            return switch (@intFromEnum(m)) {
                @intFromEnum(Skippable.magic_min)...@intFromEnum(Skippable.magic_max) => true,
                else => false,
            };
        }
    };

    pub const Kind = enum { zstandard, skippable };

    pub const Zstandard = struct {
        pub const magic: Magic = .zstandard;

        header: Header,
        data_blocks: []Block,
        checksum: ?u32,

        pub const Header = struct {
            descriptor: Descriptor,
            window_descriptor: ?u8,
            dictionary_id: ?u32,
            content_size: ?u64,

            pub const Descriptor = packed struct {
                dictionary_id_flag: u2,
                content_checksum_flag: bool,
                reserved: bool,
                unused: bool,
                single_segment_flag: bool,
                content_size_flag: u2,
            };

            pub const DecodeError = Reader.Error || error{ReservedBitSet};

            pub fn decode(in: *Reader) DecodeError!Header {
                const descriptor: Descriptor = @bitCast(try in.takeByte());

                if (descriptor.reserved) return error.ReservedBitSet;

                const window_descriptor: ?u8 = if (descriptor.single_segment_flag) null else try in.takeByte();

                const dictionary_id: ?u32 = if (descriptor.dictionary_id_flag > 0) d: {
                    // if flag is 3 then field_size = 4, else field_size = flag
                    const field_size = (@as(u4, 1) << descriptor.dictionary_id_flag) >> 1;
                    break :d try in.takeVarInt(u32, .little, field_size);
                } else null;

                const content_size: ?u64 = if (descriptor.single_segment_flag or descriptor.content_size_flag > 0) c: {
                    const field_size = @as(u4, 1) << descriptor.content_size_flag;
                    const content_size = try in.takeVarInt(u64, .little, field_size);
                    break :c if (field_size == 2) content_size + 256 else content_size;
                } else null;

                return .{
                    .descriptor = descriptor,
                    .window_descriptor = window_descriptor,
                    .dictionary_id = dictionary_id,
                    .content_size = content_size,
                };
            }

            /// Returns the window size required to decompress a frame, or `null` if it
            /// cannot be determined (which indicates a malformed frame header).
            pub fn windowSize(header: Header) ?u64 {
                if (header.window_descriptor) |descriptor| {
                    const exponent = (descriptor & 0b11111000) >> 3;
                    const mantissa = descriptor & 0b00000111;
                    const window_log = 10 + exponent;
                    const window_base = @as(u64, 1) << @as(u6, @intCast(window_log));
                    const window_add = (window_base / 8) * mantissa;
                    return window_base + window_add;
                } else return header.content_size;
            }
        };

        pub const Block = struct {
            pub const Header = packed struct(u24) {
                last: bool,
                type: Type,
                size: u21,
            };

            pub const Type = enum(u2) {
                raw,
                rle,
                compressed,
                reserved,
            };
        };

        pub const Decode = struct {
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
                    state: @This().State,
                    table: Table,
                    accuracy_log: u8,

                    const State = std.meta.Int(.unsigned, max_accuracy_log);
                };
            }

            pub fn init(
                literal_fse_buffer: []Table.Fse,
                match_fse_buffer: []Table.Fse,
                offset_fse_buffer: []Table.Fse,
            ) Decode {
                return .{
                    .repeat_offsets = .{
                        zstd.start_repeated_offset_1,
                        zstd.start_repeated_offset_2,
                        zstd.start_repeated_offset_3,
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
                };
            }

            pub const PrepareError = error{
                /// the (reversed) literal bitstream's first byte does not have any bits set
                MissingStartBit,
                /// `literals` is a treeless literals section and the decode state does not
                /// have a Huffman tree from a previous block
                TreelessLiteralsFirst,
                /// on the first call if one of the sequence FSE tables is set to repeat mode
                RepeatModeFirst,
                /// an FSE table has an invalid accuracy
                MalformedAccuracyLog,
                /// failed decoding an FSE table
                MalformedFseTable,
                /// input stream ends before all FSE tables are read
                EndOfStream,
                ReadFailed,
                InputBufferUndersize,
            };

            /// Prepare the decoder to decode a compressed block. Loads the
            /// literals stream and Huffman tree from `literals` and reads the
            /// FSE tables from `in`.
            pub fn prepare(
                self: *Decode,
                in: *Reader,
                remaining: *Limit,
                literals: LiteralsSection,
                sequences_header: SequencesSection.Header,
            ) PrepareError!void {
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
                    try self.updateFseTable(in, remaining, .literal, sequences_header.literal_lengths);
                    try self.updateFseTable(in, remaining, .offset, sequences_header.offsets);
                    try self.updateFseTable(in, remaining, .match, sequences_header.match_lengths);
                    self.fse_tables_undefined = false;
                }
            }

            /// Read initial FSE states for sequence decoding.
            pub fn readInitialFseState(self: *Decode, bit_reader: *ReverseBitReader) error{EndOfStream}!void {
                self.literal.state = try bit_reader.readBitsNoEof(u9, self.literal.accuracy_log);
                self.offset.state = try bit_reader.readBitsNoEof(u8, self.offset.accuracy_log);
                self.match.state = try bit_reader.readBitsNoEof(u9, self.match.accuracy_log);
            }

            fn updateRepeatOffset(self: *Decode, offset: u32) void {
                self.repeat_offsets[2] = self.repeat_offsets[1];
                self.repeat_offsets[1] = self.repeat_offsets[0];
                self.repeat_offsets[0] = offset;
            }

            fn useRepeatOffset(self: *Decode, index: usize) u32 {
                if (index == 1)
                    std.mem.swap(u32, &self.repeat_offsets[0], &self.repeat_offsets[1])
                else if (index == 2) {
                    std.mem.swap(u32, &self.repeat_offsets[0], &self.repeat_offsets[2]);
                    std.mem.swap(u32, &self.repeat_offsets[1], &self.repeat_offsets[2]);
                }
                return self.repeat_offsets[0];
            }

            const DataType = enum { offset, match, literal };

            /// TODO: don't use `@field`
            fn updateState(
                self: *Decode,
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

            /// TODO: don't use `@field`
            fn updateFseTable(
                self: *Decode,
                in: *Reader,
                remaining: *Limit,
                comptime choice: DataType,
                mode: SequencesSection.Header.Mode,
            ) !void {
                const field_name = @tagName(choice);
                switch (mode) {
                    .predefined => {
                        @field(self, field_name).accuracy_log =
                            @field(zstd.default_accuracy_log, field_name);

                        @field(self, field_name).table =
                            @field(Table, "predefined_" ++ field_name);
                    },
                    .rle => {
                        @field(self, field_name).accuracy_log = 0;
                        remaining.* = remaining.subtract(1) orelse return error.EndOfStream;
                        @field(self, field_name).table = .{ .rle = try in.takeByte() };
                    },
                    .fse => {
                        const max_table_size = 2048;
                        const peek_len: usize = remaining.minInt(max_table_size);
                        if (in.buffer.len < peek_len) return error.InputBufferUndersize;
                        const limited_buffer = try in.peek(peek_len);
                        var bit_reader: BitReader = .{ .bytes = limited_buffer };
                        const table_size = try Table.decode(
                            &bit_reader,
                            @field(zstd.table_symbol_count_max, field_name),
                            @field(zstd.table_accuracy_log_max, field_name),
                            @field(self, field_name ++ "_fse_buffer"),
                        );
                        @field(self, field_name).table = .{
                            .fse = @field(self, field_name ++ "_fse_buffer")[0..table_size],
                        };
                        @field(self, field_name).accuracy_log = std.math.log2_int_ceil(usize, table_size);
                        in.toss(bit_reader.index);
                        remaining.* = remaining.subtract(bit_reader.index).?;
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
                self: *Decode,
                bit_reader: *ReverseBitReader,
            ) error{ InvalidBitStream, EndOfStream }!Sequence {
                const raw_code = self.getCode(.offset);
                const offset_code = std.math.cast(u5, raw_code) orelse {
                    return error.InvalidBitStream;
                };
                const offset_value = (@as(u32, 1) << offset_code) + try bit_reader.readBitsNoEof(u32, offset_code);

                const match_code = self.getCode(.match);
                if (match_code >= zstd.match_length_code_table.len)
                    return error.InvalidBitStream;
                const match = zstd.match_length_code_table[match_code];
                const match_length = match[0] + try bit_reader.readBitsNoEof(u32, match[1]);

                const literal_code = self.getCode(.literal);
                if (literal_code >= zstd.literals_length_code_table.len)
                    return error.InvalidBitStream;
                const literal = zstd.literals_length_code_table[literal_code];
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

            /// Decode one sequence from `bit_reader` into `dest`. Updates FSE states
            /// if `last_sequence` is `false`. Assumes `prepare` called for the block
            /// before attempting to decode sequences.
            fn decodeSequence(
                decode: *Decode,
                dest: []u8,
                write_pos: usize,
                bit_reader: *ReverseBitReader,
            ) !usize {
                const sequence = try decode.nextSequence(bit_reader);
                const literal_length: usize = sequence.literal_length;
                const match_length: usize = sequence.match_length;
                const sequence_length = literal_length + match_length;

                const copy_start = std.math.sub(usize, write_pos + sequence.literal_length, sequence.offset) catch
                    return error.MalformedSequence;

                if (decode.literal_written_count + literal_length > decode.literal_header.regenerated_size)
                    return error.MalformedLiteralsLength;
                var sub_bw: Writer = .fixed(dest[write_pos..]);
                try decodeLiterals(decode, &sub_bw, literal_length);
                decode.literal_written_count += literal_length;
                // This is not a @memmove; it intentionally repeats patterns
                // caused by iterating one byte at a time.
                for (
                    dest[write_pos + literal_length ..][0..match_length],
                    dest[copy_start..][0..match_length],
                ) |*d, s| d.* = s;
                return sequence_length;
            }

            fn nextLiteralMultiStream(self: *Decode) error{MissingStartBit}!void {
                self.literal_stream_index += 1;
                try self.initLiteralStream(self.literal_streams.four[self.literal_stream_index]);
            }

            fn initLiteralStream(self: *Decode, bytes: []const u8) error{MissingStartBit}!void {
                self.literal_stream_reader = try ReverseBitReader.init(bytes);
            }

            fn isLiteralStreamEmpty(self: *Decode) bool {
                switch (self.literal_streams) {
                    .one => return self.literal_stream_reader.isEmpty(),
                    .four => return self.literal_stream_index == 3 and self.literal_stream_reader.isEmpty(),
                }
            }

            const LiteralBitsError = error{
                MissingStartBit,
                UnexpectedEndOfLiteralStream,
            };
            fn readLiteralsBits(
                self: *Decode,
                bit_count_to_read: u16,
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

            /// Decode `len` bytes of literals into `dest`.
            fn decodeLiterals(self: *Decode, dest: *Writer, len: usize) !void {
                switch (self.literal_header.block_type) {
                    .raw => {
                        try dest.writeAll(self.literal_streams.one[self.literal_written_count..][0..len]);
                    },
                    .rle => {
                        try dest.splatByteAll(self.literal_streams.one[0], len);
                    },
                    .compressed, .treeless => {
                        if (len > dest.buffer.len) return error.OutputBufferUndersize;
                        const buf = try dest.writableSlice(len);
                        const huffman_tree = self.huffman_tree.?;
                        const max_bit_count = huffman_tree.max_bit_count;
                        const starting_bit_count = LiteralsSection.HuffmanTree.weightToBitCount(
                            huffman_tree.nodes[huffman_tree.symbol_count_minus_one].weight,
                            max_bit_count,
                        );
                        var bits_read: u4 = 0;
                        var huffman_tree_index: usize = huffman_tree.symbol_count_minus_one;
                        var bit_count_to_read: u4 = starting_bit_count;
                        for (buf) |*out| {
                            var prefix: u16 = 0;
                            while (true) {
                                const new_bits = try self.readLiteralsBits(bit_count_to_read);
                                prefix <<= bit_count_to_read;
                                prefix |= new_bits;
                                bits_read += bit_count_to_read;
                                const result = try huffman_tree.query(huffman_tree_index, prefix);

                                switch (result) {
                                    .symbol => |sym| {
                                        out.* = sym;
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
                    },
                }
            }

            /// TODO: don't use `@field`
            fn getCode(self: *Decode, comptime choice: DataType) u32 {
                return switch (@field(self, @tagName(choice)).table) {
                    .rle => |value| value,
                    .fse => |table| table[@field(self, @tagName(choice)).state].symbol,
                };
            }
        };
    };

    pub const Skippable = struct {
        pub const magic_min: Magic = @enumFromInt(0x184D2A50);
        pub const magic_max: Magic = @enumFromInt(0x184D2A5F);

        pub const Header = struct {
            magic_number: u32,
            frame_size: u32,
        };
    };

    const InitError = error{
        /// Frame uses a dictionary.
        DictionaryIdFlagUnsupported,
        /// Frame does not have a valid window size.
        WindowSizeUnknown,
        /// Window size exceeds `window_size_max` or max `usize` value.
        WindowOversize,
        /// Frame header indicates a content size exceeding max `usize` value.
        ContentOversize,
    };

    /// Validates `frame_header` and returns the associated `Frame`.
    pub fn init(
        frame_header: Frame.Zstandard.Header,
        window_size_max: usize,
        verify_checksum: bool,
    ) InitError!Frame {
        if (frame_header.descriptor.dictionary_id_flag != 0)
            return error.DictionaryIdFlagUnsupported;

        const window_size_raw = frame_header.windowSize() orelse return error.WindowSizeUnknown;
        const window_size = if (window_size_raw > window_size_max)
            return error.WindowOversize
        else
            std.math.cast(usize, window_size_raw) orelse return error.WindowOversize;

        const should_compute_checksum =
            frame_header.descriptor.content_checksum_flag and verify_checksum;

        const content_size = if (frame_header.content_size) |size|
            std.math.cast(usize, size) orelse return error.ContentOversize
        else
            null;

        return .{
            .hasher_opt = if (should_compute_checksum) std.hash.XxHash64.init(0) else null,
            .window_size = window_size,
            .has_checksum = frame_header.descriptor.content_checksum_flag,
            .block_size_max = @min(zstd.block_size_max, window_size),
            .content_size = content_size,
        };
    }
};

pub const LiteralsSection = struct {
    header: Header,
    huffman_tree: ?HuffmanTree,
    streams: Streams,

    pub const Streams = union(enum) {
        one: []const u8,
        four: [4][]const u8,

        fn decode(size_format: u2, stream_data: []const u8) !Streams {
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
    };

    pub const Header = struct {
        block_type: BlockType,
        size_format: u2,
        regenerated_size: u20,
        compressed_size: ?u18,

        /// Decode a literals section header.
        pub fn decode(in: *Reader, remaining: *Limit) !Header {
            remaining.* = remaining.subtract(1) orelse return error.EndOfStream;
            const byte0 = try in.takeByte();
            const block_type: BlockType = @enumFromInt(byte0 & 0b11);
            const size_format: u2 = @intCast((byte0 & 0b1100) >> 2);
            var regenerated_size: u20 = undefined;
            var compressed_size: ?u18 = null;
            switch (block_type) {
                .raw, .rle => {
                    switch (size_format) {
                        0, 2 => {
                            regenerated_size = byte0 >> 3;
                        },
                        1 => {
                            remaining.* = remaining.subtract(1) orelse return error.EndOfStream;
                            regenerated_size = (byte0 >> 4) + (@as(u20, try in.takeByte()) << 4);
                        },
                        3 => {
                            remaining.* = remaining.subtract(2) orelse return error.EndOfStream;
                            regenerated_size = (byte0 >> 4) +
                                (@as(u20, try in.takeByte()) << 4) +
                                (@as(u20, try in.takeByte()) << 12);
                        },
                    }
                },
                .compressed, .treeless => {
                    remaining.* = remaining.subtract(2) orelse return error.EndOfStream;
                    const byte1 = try in.takeByte();
                    const byte2 = try in.takeByte();
                    switch (size_format) {
                        0, 1 => {
                            regenerated_size = (byte0 >> 4) + ((@as(u20, byte1) & 0b00111111) << 4);
                            compressed_size = ((byte1 & 0b11000000) >> 6) + (@as(u18, byte2) << 2);
                        },
                        2 => {
                            remaining.* = remaining.subtract(1) orelse return error.EndOfStream;
                            const byte3 = try in.takeByte();
                            regenerated_size = (byte0 >> 4) + (@as(u20, byte1) << 4) + ((@as(u20, byte2) & 0b00000011) << 12);
                            compressed_size = ((byte2 & 0b11111100) >> 2) + (@as(u18, byte3) << 6);
                        },
                        3 => {
                            remaining.* = remaining.subtract(2) orelse return error.EndOfStream;
                            const byte3 = try in.takeByte();
                            const byte4 = try in.takeByte();
                            regenerated_size = (byte0 >> 4) + (@as(u20, byte1) << 4) + ((@as(u20, byte2) & 0b00111111) << 12);
                            compressed_size = ((byte2 & 0b11000000) >> 6) + (@as(u18, byte3) << 2) + (@as(u18, byte4) << 10);
                        },
                    }
                },
            }
            return .{
                .block_type = block_type,
                .size_format = size_format,
                .regenerated_size = regenerated_size,
                .compressed_size = compressed_size,
            };
        }
    };

    pub const BlockType = enum(u2) {
        raw,
        rle,
        compressed,
        treeless,
    };

    pub const HuffmanTree = struct {
        max_bit_count: u4,
        symbol_count_minus_one: u8,
        nodes: [256]PrefixedSymbol,

        pub const PrefixedSymbol = struct {
            symbol: u8,
            prefix: u16,
            weight: u4,
        };

        pub const Result = union(enum) {
            symbol: u8,
            index: usize,
        };

        pub fn query(self: HuffmanTree, index: usize, prefix: u16) error{HuffmanTreeIncomplete}!Result {
            var node = self.nodes[index];
            const weight = node.weight;
            var i: usize = index;
            while (node.weight == weight) {
                if (node.prefix == prefix) return .{ .symbol = node.symbol };
                if (i == 0) return error.HuffmanTreeIncomplete;
                i -= 1;
                node = self.nodes[i];
            }
            return .{ .index = i };
        }

        pub fn weightToBitCount(weight: u4, max_bit_count: u4) u4 {
            return if (weight == 0) 0 else ((max_bit_count + 1) - weight);
        }

        pub const DecodeError = Reader.Error || error{
            MalformedHuffmanTree,
            MalformedFseTable,
            MalformedAccuracyLog,
            EndOfStream,
            MissingStartBit,
        };

        pub fn decode(in: *Reader, remaining: *Limit) HuffmanTree.DecodeError!HuffmanTree {
            remaining.* = remaining.subtract(1) orelse return error.EndOfStream;
            const header = try in.takeByte();
            if (header < 128) {
                return decodeFse(in, remaining, header);
            } else {
                return decodeDirect(in, remaining, header - 127);
            }
        }

        fn decodeDirect(
            in: *Reader,
            remaining: *Limit,
            encoded_symbol_count: usize,
        ) HuffmanTree.DecodeError!HuffmanTree {
            var weights: [256]u4 = undefined;
            const weights_byte_count = (encoded_symbol_count + 1) / 2;
            remaining.* = remaining.subtract(weights_byte_count) orelse return error.EndOfStream;
            for (0..weights_byte_count) |i| {
                const byte = try in.takeByte();
                weights[2 * i] = @as(u4, @intCast(byte >> 4));
                weights[2 * i + 1] = @as(u4, @intCast(byte & 0xF));
            }
            const symbol_count = encoded_symbol_count + 1;
            return build(&weights, symbol_count);
        }

        fn decodeFse(
            in: *Reader,
            remaining: *Limit,
            compressed_size: usize,
        ) HuffmanTree.DecodeError!HuffmanTree {
            var weights: [256]u4 = undefined;
            remaining.* = remaining.subtract(compressed_size) orelse return error.EndOfStream;
            const compressed_buffer = try in.take(compressed_size);
            var bit_reader: BitReader = .{ .bytes = compressed_buffer };
            var entries: [1 << 6]Table.Fse = undefined;
            const table_size = try Table.decode(&bit_reader, 256, 6, &entries);
            const accuracy_log = std.math.log2_int_ceil(usize, table_size);
            const remaining_buffer = bit_reader.bytes[bit_reader.index..];
            const symbol_count = try assignWeights(remaining_buffer, accuracy_log, &entries, &weights);
            return build(&weights, symbol_count);
        }

        fn assignWeights(
            huff_bits_buffer: []const u8,
            accuracy_log: u16,
            entries: *[1 << 6]Table.Fse,
            weights: *[256]u4,
        ) !usize {
            var huff_bits = try ReverseBitReader.init(huff_bits_buffer);

            var i: usize = 0;
            var even_state: u32 = try huff_bits.readBitsNoEof(u32, accuracy_log);
            var odd_state: u32 = try huff_bits.readBitsNoEof(u32, accuracy_log);

            while (i < 254) {
                const even_data = entries[even_state];
                var read_bits: u16 = 0;
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
                    if (i == 255) return error.MalformedHuffmanTree;
                    weights[i] = std.math.cast(u4, entries[even_state].symbol) orelse return error.MalformedHuffmanTree;
                    i += 1;
                    break;
                }
                odd_state = odd_data.baseline + odd_bits;
            } else return error.MalformedHuffmanTree;

            if (!huff_bits.isEmpty()) {
                return error.MalformedHuffmanTree;
            }

            return i + 1; // stream contains all but the last symbol
        }

        fn assignSymbols(weight_sorted_prefixed_symbols: []PrefixedSymbol, weights: [256]u4) usize {
            for (0..weight_sorted_prefixed_symbols.len) |i| {
                weight_sorted_prefixed_symbols[i] = .{
                    .symbol = @as(u8, @intCast(i)),
                    .weight = undefined,
                    .prefix = undefined,
                };
            }

            std.mem.sort(
                PrefixedSymbol,
                weight_sorted_prefixed_symbols,
                weights,
                lessThanByWeight,
            );

            var prefix: u16 = 0;
            var prefixed_symbol_count: usize = 0;
            var sorted_index: usize = 0;
            const symbol_count = weight_sorted_prefixed_symbols.len;
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
            return prefixed_symbol_count;
        }

        fn build(weights: *[256]u4, symbol_count: usize) error{MalformedHuffmanTree}!HuffmanTree {
            var weight_power_sum_big: u32 = 0;
            for (weights[0 .. symbol_count - 1]) |value| {
                weight_power_sum_big += (@as(u16, 1) << value) >> 1;
            }
            if (weight_power_sum_big >= 1 << 11) return error.MalformedHuffmanTree;
            const weight_power_sum = @as(u16, @intCast(weight_power_sum_big));

            // advance to next power of two (even if weight_power_sum is a power of 2)
            // TODO: is it valid to have weight_power_sum == 0?
            const max_number_of_bits = if (weight_power_sum == 0) 1 else std.math.log2_int(u16, weight_power_sum) + 1;
            const next_power_of_two = @as(u16, 1) << max_number_of_bits;
            weights[symbol_count - 1] = std.math.log2_int(u16, next_power_of_two - weight_power_sum) + 1;

            var weight_sorted_prefixed_symbols: [256]PrefixedSymbol = undefined;
            const prefixed_symbol_count = assignSymbols(weight_sorted_prefixed_symbols[0..symbol_count], weights.*);
            const tree: HuffmanTree = .{
                .max_bit_count = max_number_of_bits,
                .symbol_count_minus_one = @as(u8, @intCast(prefixed_symbol_count - 1)),
                .nodes = weight_sorted_prefixed_symbols,
            };
            return tree;
        }

        fn lessThanByWeight(
            weights: [256]u4,
            lhs: PrefixedSymbol,
            rhs: PrefixedSymbol,
        ) bool {
            // NOTE: this function relies on the use of a stable sorting algorithm,
            //       otherwise a special case of if (weights[lhs] == weights[rhs]) return lhs < rhs;
            //       should be added
            return weights[lhs.symbol] < weights[rhs.symbol];
        }
    };

    pub const StreamCount = enum { one, four };
    pub fn streamCount(size_format: u2, block_type: BlockType) StreamCount {
        return switch (block_type) {
            .raw, .rle => .one,
            .compressed, .treeless => if (size_format == 0) .one else .four,
        };
    }

    pub const DecodeError = error{
        /// Invalid header.
        MalformedLiteralsHeader,
        /// Decoding errors.
        MalformedLiteralsSection,
        /// Compressed literals have invalid accuracy.
        MalformedAccuracyLog,
        /// Compressed literals have invalid FSE table.
        MalformedFseTable,
        /// Failed decoding a Huffamn tree.
        MalformedHuffmanTree,
        /// Not enough bytes to complete the section.
        EndOfStream,
        ReadFailed,
        MissingStartBit,
    };

    pub fn decode(in: *Reader, remaining: *Limit, buffer: []u8) DecodeError!LiteralsSection {
        const header = try Header.decode(in, remaining);
        switch (header.block_type) {
            .raw => {
                if (buffer.len < header.regenerated_size) return error.MalformedLiteralsSection;
                remaining.* = remaining.subtract(header.regenerated_size) orelse return error.EndOfStream;
                try in.readSlice(buffer[0..header.regenerated_size]);
                return .{
                    .header = header,
                    .huffman_tree = null,
                    .streams = .{ .one = buffer },
                };
            },
            .rle => {
                remaining.* = remaining.subtract(1) orelse return error.EndOfStream;
                buffer[0] = try in.takeByte();
                return .{
                    .header = header,
                    .huffman_tree = null,
                    .streams = .{ .one = buffer[0..1] },
                };
            },
            .compressed, .treeless => {
                const before_remaining = remaining.*;
                const huffman_tree = if (header.block_type == .compressed)
                    try HuffmanTree.decode(in, remaining)
                else
                    null;
                const huffman_tree_size = @intFromEnum(before_remaining) - @intFromEnum(remaining.*);
                const total_streams_size = std.math.sub(usize, header.compressed_size.?, huffman_tree_size) catch
                    return error.MalformedLiteralsSection;
                if (total_streams_size > buffer.len) return error.MalformedLiteralsSection;
                remaining.* = remaining.subtract(total_streams_size) orelse return error.EndOfStream;
                try in.readSlice(buffer[0..total_streams_size]);
                const stream_data = buffer[0..total_streams_size];
                const streams = try Streams.decode(header.size_format, stream_data);
                return .{
                    .header = header,
                    .huffman_tree = huffman_tree,
                    .streams = streams,
                };
            },
        }
    }
};

pub const SequencesSection = struct {
    header: Header,
    literals_length_table: Table,
    offset_table: Table,
    match_length_table: Table,

    pub const Header = struct {
        sequence_count: u24,
        match_lengths: Mode,
        offsets: Mode,
        literal_lengths: Mode,

        pub const Mode = enum(u2) {
            predefined,
            rle,
            fse,
            repeat,
        };

        pub const DecodeError = error{
            ReservedBitSet,
            EndOfStream,
            ReadFailed,
        };

        pub fn decode(in: *Reader, remaining: *Limit) DecodeError!Header {
            var sequence_count: u24 = undefined;

            remaining.* = remaining.subtract(1) orelse return error.EndOfStream;
            const byte0 = try in.takeByte();
            if (byte0 == 0) {
                return .{
                    .sequence_count = 0,
                    .offsets = undefined,
                    .match_lengths = undefined,
                    .literal_lengths = undefined,
                };
            } else if (byte0 < 128) {
                remaining.* = remaining.subtract(1) orelse return error.EndOfStream;
                sequence_count = byte0;
            } else if (byte0 < 255) {
                remaining.* = remaining.subtract(2) orelse return error.EndOfStream;
                sequence_count = (@as(u24, (byte0 - 128)) << 8) + try in.takeByte();
            } else {
                remaining.* = remaining.subtract(3) orelse return error.EndOfStream;
                sequence_count = (try in.takeByte()) + (@as(u24, try in.takeByte()) << 8) + 0x7F00;
            }

            const compression_modes = try in.takeByte();

            const matches_mode: Header.Mode = @enumFromInt((compression_modes & 0b00001100) >> 2);
            const offsets_mode: Header.Mode = @enumFromInt((compression_modes & 0b00110000) >> 4);
            const literal_mode: Header.Mode = @enumFromInt((compression_modes & 0b11000000) >> 6);
            if (compression_modes & 0b11 != 0) return error.ReservedBitSet;

            return .{
                .sequence_count = sequence_count,
                .offsets = offsets_mode,
                .match_lengths = matches_mode,
                .literal_lengths = literal_mode,
            };
        }
    };
};

pub const Table = union(enum) {
    fse: []const Fse,
    rle: u8,

    pub const Fse = struct {
        symbol: u8,
        baseline: u16,
        bits: u8,
    };

    pub fn decode(
        bit_reader: *BitReader,
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
            // WARNING: The RFC is poorly worded, and would suggest std.math.log2_int_ceil is correct here,
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
                    if (repeat_flag + value_count > 256) return error.MalformedFseTable;
                    for (0..repeat_flag) |_| {
                        values[value_count] = 1;
                        value_count += 1;
                    }
                    if (repeat_flag < 3) break;
                }
            }
            if (value_count == 256) break;
        }
        bit_reader.alignToByte();

        if (value_count < 2) return error.MalformedFseTable;
        if (accumulated_probability != total_probability) return error.MalformedFseTable;
        if (value_count > expected_symbol_count) return error.MalformedFseTable;

        const table_size = total_probability;

        try build(values[0..value_count], entries[0..table_size]);
        return table_size;
    }

    pub fn build(values: []const u16, entries: []Table.Fse) !void {
        const total_probability = @as(u16, @intCast(entries.len));
        const accuracy_log = std.math.log2_int(u16, total_probability);
        assert(total_probability <= 1 << 9);

        var less_than_one_count: usize = 0;
        for (values, 0..) |value, i| {
            if (value == 0) {
                entries[entries.len - 1 - less_than_one_count] = Table.Fse{
                    .symbol = @as(u8, @intCast(i)),
                    .baseline = 0,
                    .bits = accuracy_log,
                };
                less_than_one_count += 1;
            }
        }

        var position: usize = 0;
        var temp_states: [1 << 9]u16 = undefined;
        for (values, 0..) |value, symbol| {
            if (value == 0 or value == 1) continue;
            const probability = value - 1;

            const state_share_dividend = std.math.ceilPowerOfTwo(u16, probability) catch
                return error.MalformedFseTable;
            const share_size = @divExact(total_probability, state_share_dividend);
            const double_state_count = state_share_dividend - probability;
            const single_state_count = probability - double_state_count;
            const share_size_log = std.math.log2_int(u16, share_size);

            for (0..probability) |i| {
                temp_states[i] = @as(u16, @intCast(position));
                position += (entries.len >> 1) + (entries.len >> 3) + 3;
                position &= entries.len - 1;
                while (position >= entries.len - less_than_one_count) {
                    position += (entries.len >> 1) + (entries.len >> 3) + 3;
                    position &= entries.len - 1;
                }
            }
            std.mem.sort(u16, temp_states[0..probability], {}, std.sort.asc(u16));
            for (0..probability) |i| {
                entries[temp_states[i]] = if (i < double_state_count) Table.Fse{
                    .symbol = @as(u8, @intCast(symbol)),
                    .bits = share_size_log + 1,
                    .baseline = single_state_count * share_size + @as(u16, @intCast(i)) * 2 * share_size,
                } else Table.Fse{
                    .symbol = @as(u8, @intCast(symbol)),
                    .bits = share_size_log,
                    .baseline = (@as(u16, @intCast(i)) - double_state_count) * share_size,
                };
            }
        }
    }

    test build {
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
        try build(&literals_length_default_values, &entries);
        try std.testing.expectEqualSlices(Table.Fse, Table.predefined_literal.fse, &entries);

        try build(&match_lengths_default_values, &entries);
        try std.testing.expectEqualSlices(Table.Fse, Table.predefined_match.fse, &entries);

        try build(&offset_codes_default_values, entries[0..32]);
        try std.testing.expectEqualSlices(Table.Fse, Table.predefined_offset.fse, entries[0..32]);
    }

    pub const predefined_literal: Table = .{
        .fse = &[64]Table.Fse{
            .{ .symbol = 0, .bits = 4, .baseline = 0 },
            .{ .symbol = 0, .bits = 4, .baseline = 16 },
            .{ .symbol = 1, .bits = 5, .baseline = 32 },
            .{ .symbol = 3, .bits = 5, .baseline = 0 },
            .{ .symbol = 4, .bits = 5, .baseline = 0 },
            .{ .symbol = 6, .bits = 5, .baseline = 0 },
            .{ .symbol = 7, .bits = 5, .baseline = 0 },
            .{ .symbol = 9, .bits = 5, .baseline = 0 },
            .{ .symbol = 10, .bits = 5, .baseline = 0 },
            .{ .symbol = 12, .bits = 5, .baseline = 0 },
            .{ .symbol = 14, .bits = 6, .baseline = 0 },
            .{ .symbol = 16, .bits = 5, .baseline = 0 },
            .{ .symbol = 18, .bits = 5, .baseline = 0 },
            .{ .symbol = 19, .bits = 5, .baseline = 0 },
            .{ .symbol = 21, .bits = 5, .baseline = 0 },
            .{ .symbol = 22, .bits = 5, .baseline = 0 },
            .{ .symbol = 24, .bits = 5, .baseline = 0 },
            .{ .symbol = 25, .bits = 5, .baseline = 32 },
            .{ .symbol = 26, .bits = 5, .baseline = 0 },
            .{ .symbol = 27, .bits = 6, .baseline = 0 },
            .{ .symbol = 29, .bits = 6, .baseline = 0 },
            .{ .symbol = 31, .bits = 6, .baseline = 0 },
            .{ .symbol = 0, .bits = 4, .baseline = 32 },
            .{ .symbol = 1, .bits = 4, .baseline = 0 },
            .{ .symbol = 2, .bits = 5, .baseline = 0 },
            .{ .symbol = 4, .bits = 5, .baseline = 32 },
            .{ .symbol = 5, .bits = 5, .baseline = 0 },
            .{ .symbol = 7, .bits = 5, .baseline = 32 },
            .{ .symbol = 8, .bits = 5, .baseline = 0 },
            .{ .symbol = 10, .bits = 5, .baseline = 32 },
            .{ .symbol = 11, .bits = 5, .baseline = 0 },
            .{ .symbol = 13, .bits = 6, .baseline = 0 },
            .{ .symbol = 16, .bits = 5, .baseline = 32 },
            .{ .symbol = 17, .bits = 5, .baseline = 0 },
            .{ .symbol = 19, .bits = 5, .baseline = 32 },
            .{ .symbol = 20, .bits = 5, .baseline = 0 },
            .{ .symbol = 22, .bits = 5, .baseline = 32 },
            .{ .symbol = 23, .bits = 5, .baseline = 0 },
            .{ .symbol = 25, .bits = 4, .baseline = 0 },
            .{ .symbol = 25, .bits = 4, .baseline = 16 },
            .{ .symbol = 26, .bits = 5, .baseline = 32 },
            .{ .symbol = 28, .bits = 6, .baseline = 0 },
            .{ .symbol = 30, .bits = 6, .baseline = 0 },
            .{ .symbol = 0, .bits = 4, .baseline = 48 },
            .{ .symbol = 1, .bits = 4, .baseline = 16 },
            .{ .symbol = 2, .bits = 5, .baseline = 32 },
            .{ .symbol = 3, .bits = 5, .baseline = 32 },
            .{ .symbol = 5, .bits = 5, .baseline = 32 },
            .{ .symbol = 6, .bits = 5, .baseline = 32 },
            .{ .symbol = 8, .bits = 5, .baseline = 32 },
            .{ .symbol = 9, .bits = 5, .baseline = 32 },
            .{ .symbol = 11, .bits = 5, .baseline = 32 },
            .{ .symbol = 12, .bits = 5, .baseline = 32 },
            .{ .symbol = 15, .bits = 6, .baseline = 0 },
            .{ .symbol = 17, .bits = 5, .baseline = 32 },
            .{ .symbol = 18, .bits = 5, .baseline = 32 },
            .{ .symbol = 20, .bits = 5, .baseline = 32 },
            .{ .symbol = 21, .bits = 5, .baseline = 32 },
            .{ .symbol = 23, .bits = 5, .baseline = 32 },
            .{ .symbol = 24, .bits = 5, .baseline = 32 },
            .{ .symbol = 35, .bits = 6, .baseline = 0 },
            .{ .symbol = 34, .bits = 6, .baseline = 0 },
            .{ .symbol = 33, .bits = 6, .baseline = 0 },
            .{ .symbol = 32, .bits = 6, .baseline = 0 },
        },
    };

    pub const predefined_match: Table = .{
        .fse = &[64]Table.Fse{
            .{ .symbol = 0, .bits = 6, .baseline = 0 },
            .{ .symbol = 1, .bits = 4, .baseline = 0 },
            .{ .symbol = 2, .bits = 5, .baseline = 32 },
            .{ .symbol = 3, .bits = 5, .baseline = 0 },
            .{ .symbol = 5, .bits = 5, .baseline = 0 },
            .{ .symbol = 6, .bits = 5, .baseline = 0 },
            .{ .symbol = 8, .bits = 5, .baseline = 0 },
            .{ .symbol = 10, .bits = 6, .baseline = 0 },
            .{ .symbol = 13, .bits = 6, .baseline = 0 },
            .{ .symbol = 16, .bits = 6, .baseline = 0 },
            .{ .symbol = 19, .bits = 6, .baseline = 0 },
            .{ .symbol = 22, .bits = 6, .baseline = 0 },
            .{ .symbol = 25, .bits = 6, .baseline = 0 },
            .{ .symbol = 28, .bits = 6, .baseline = 0 },
            .{ .symbol = 31, .bits = 6, .baseline = 0 },
            .{ .symbol = 33, .bits = 6, .baseline = 0 },
            .{ .symbol = 35, .bits = 6, .baseline = 0 },
            .{ .symbol = 37, .bits = 6, .baseline = 0 },
            .{ .symbol = 39, .bits = 6, .baseline = 0 },
            .{ .symbol = 41, .bits = 6, .baseline = 0 },
            .{ .symbol = 43, .bits = 6, .baseline = 0 },
            .{ .symbol = 45, .bits = 6, .baseline = 0 },
            .{ .symbol = 1, .bits = 4, .baseline = 16 },
            .{ .symbol = 2, .bits = 4, .baseline = 0 },
            .{ .symbol = 3, .bits = 5, .baseline = 32 },
            .{ .symbol = 4, .bits = 5, .baseline = 0 },
            .{ .symbol = 6, .bits = 5, .baseline = 32 },
            .{ .symbol = 7, .bits = 5, .baseline = 0 },
            .{ .symbol = 9, .bits = 6, .baseline = 0 },
            .{ .symbol = 12, .bits = 6, .baseline = 0 },
            .{ .symbol = 15, .bits = 6, .baseline = 0 },
            .{ .symbol = 18, .bits = 6, .baseline = 0 },
            .{ .symbol = 21, .bits = 6, .baseline = 0 },
            .{ .symbol = 24, .bits = 6, .baseline = 0 },
            .{ .symbol = 27, .bits = 6, .baseline = 0 },
            .{ .symbol = 30, .bits = 6, .baseline = 0 },
            .{ .symbol = 32, .bits = 6, .baseline = 0 },
            .{ .symbol = 34, .bits = 6, .baseline = 0 },
            .{ .symbol = 36, .bits = 6, .baseline = 0 },
            .{ .symbol = 38, .bits = 6, .baseline = 0 },
            .{ .symbol = 40, .bits = 6, .baseline = 0 },
            .{ .symbol = 42, .bits = 6, .baseline = 0 },
            .{ .symbol = 44, .bits = 6, .baseline = 0 },
            .{ .symbol = 1, .bits = 4, .baseline = 32 },
            .{ .symbol = 1, .bits = 4, .baseline = 48 },
            .{ .symbol = 2, .bits = 4, .baseline = 16 },
            .{ .symbol = 4, .bits = 5, .baseline = 32 },
            .{ .symbol = 5, .bits = 5, .baseline = 32 },
            .{ .symbol = 7, .bits = 5, .baseline = 32 },
            .{ .symbol = 8, .bits = 5, .baseline = 32 },
            .{ .symbol = 11, .bits = 6, .baseline = 0 },
            .{ .symbol = 14, .bits = 6, .baseline = 0 },
            .{ .symbol = 17, .bits = 6, .baseline = 0 },
            .{ .symbol = 20, .bits = 6, .baseline = 0 },
            .{ .symbol = 23, .bits = 6, .baseline = 0 },
            .{ .symbol = 26, .bits = 6, .baseline = 0 },
            .{ .symbol = 29, .bits = 6, .baseline = 0 },
            .{ .symbol = 52, .bits = 6, .baseline = 0 },
            .{ .symbol = 51, .bits = 6, .baseline = 0 },
            .{ .symbol = 50, .bits = 6, .baseline = 0 },
            .{ .symbol = 49, .bits = 6, .baseline = 0 },
            .{ .symbol = 48, .bits = 6, .baseline = 0 },
            .{ .symbol = 47, .bits = 6, .baseline = 0 },
            .{ .symbol = 46, .bits = 6, .baseline = 0 },
        },
    };

    pub const predefined_offset: Table = .{
        .fse = &[32]Table.Fse{
            .{ .symbol = 0, .bits = 5, .baseline = 0 },
            .{ .symbol = 6, .bits = 4, .baseline = 0 },
            .{ .symbol = 9, .bits = 5, .baseline = 0 },
            .{ .symbol = 15, .bits = 5, .baseline = 0 },
            .{ .symbol = 21, .bits = 5, .baseline = 0 },
            .{ .symbol = 3, .bits = 5, .baseline = 0 },
            .{ .symbol = 7, .bits = 4, .baseline = 0 },
            .{ .symbol = 12, .bits = 5, .baseline = 0 },
            .{ .symbol = 18, .bits = 5, .baseline = 0 },
            .{ .symbol = 23, .bits = 5, .baseline = 0 },
            .{ .symbol = 5, .bits = 5, .baseline = 0 },
            .{ .symbol = 8, .bits = 4, .baseline = 0 },
            .{ .symbol = 14, .bits = 5, .baseline = 0 },
            .{ .symbol = 20, .bits = 5, .baseline = 0 },
            .{ .symbol = 2, .bits = 5, .baseline = 0 },
            .{ .symbol = 7, .bits = 4, .baseline = 16 },
            .{ .symbol = 11, .bits = 5, .baseline = 0 },
            .{ .symbol = 17, .bits = 5, .baseline = 0 },
            .{ .symbol = 22, .bits = 5, .baseline = 0 },
            .{ .symbol = 4, .bits = 5, .baseline = 0 },
            .{ .symbol = 8, .bits = 4, .baseline = 16 },
            .{ .symbol = 13, .bits = 5, .baseline = 0 },
            .{ .symbol = 19, .bits = 5, .baseline = 0 },
            .{ .symbol = 1, .bits = 5, .baseline = 0 },
            .{ .symbol = 6, .bits = 4, .baseline = 16 },
            .{ .symbol = 10, .bits = 5, .baseline = 0 },
            .{ .symbol = 16, .bits = 5, .baseline = 0 },
            .{ .symbol = 28, .bits = 5, .baseline = 0 },
            .{ .symbol = 27, .bits = 5, .baseline = 0 },
            .{ .symbol = 26, .bits = 5, .baseline = 0 },
            .{ .symbol = 25, .bits = 5, .baseline = 0 },
            .{ .symbol = 24, .bits = 5, .baseline = 0 },
        },
    };
};

const low_bit_mask = [9]u8{
    0b00000000,
    0b00000001,
    0b00000011,
    0b00000111,
    0b00001111,
    0b00011111,
    0b00111111,
    0b01111111,
    0b11111111,
};

fn Bits(comptime T: type) type {
    return struct { T, u16 };
}

/// For reading the reversed bit streams used to encode FSE compressed data.
const ReverseBitReader = struct {
    bytes: []const u8,
    remaining: usize,
    bits: u8,
    count: u4,

    fn init(bytes: []const u8) error{MissingStartBit}!ReverseBitReader {
        var result: ReverseBitReader = .{
            .bytes = bytes,
            .remaining = bytes.len,
            .bits = 0,
            .count = 0,
        };
        if (bytes.len == 0) return result;
        for (0..8) |_| if (0 != (result.readBitsNoEof(u1, 1) catch unreachable)) return result;
        return error.MissingStartBit;
    }

    fn initBits(comptime T: type, out: anytype, num: u16) Bits(T) {
        const UT = std.meta.Int(.unsigned, @bitSizeOf(T));
        return .{
            @bitCast(@as(UT, @intCast(out))),
            num,
        };
    }

    fn readBitsNoEof(self: *ReverseBitReader, comptime T: type, num: u16) error{EndOfStream}!T {
        const b, const c = try self.readBitsTuple(T, num);
        if (c < num) return error.EndOfStream;
        return b;
    }

    fn readBits(self: *ReverseBitReader, comptime T: type, num: u16, out_bits: *u16) !T {
        const b, const c = try self.readBitsTuple(T, num);
        out_bits.* = c;
        return b;
    }

    fn readBitsTuple(self: *ReverseBitReader, comptime T: type, num: u16) !Bits(T) {
        const UT = std.meta.Int(.unsigned, @bitSizeOf(T));
        const U = if (@bitSizeOf(T) < 8) u8 else UT;

        if (num <= self.count) return initBits(T, self.removeBits(@intCast(num)), num);

        var out_count: u16 = self.count;
        var out: U = self.removeBits(self.count);

        const full_bytes_left = (num - out_count) / 8;

        for (0..full_bytes_left) |_| {
            const byte = takeByte(self) catch |err| switch (err) {
                error.EndOfStream => return initBits(T, out, out_count),
            };
            if (U == u8) out = 0 else out <<= 8;
            out |= byte;
            out_count += 8;
        }

        const bits_left = num - out_count;
        const keep = 8 - bits_left;

        if (bits_left == 0) return initBits(T, out, out_count);

        const final_byte = takeByte(self) catch |err| switch (err) {
            error.EndOfStream => return initBits(T, out, out_count),
        };

        out <<= @intCast(bits_left);
        out |= final_byte >> @intCast(keep);
        self.bits = final_byte & low_bit_mask[keep];

        self.count = @intCast(keep);
        return initBits(T, out, num);
    }

    fn takeByte(rbr: *ReverseBitReader) error{EndOfStream}!u8 {
        if (rbr.remaining == 0) return error.EndOfStream;
        rbr.remaining -= 1;
        return rbr.bytes[rbr.remaining];
    }

    fn isEmpty(self: *const ReverseBitReader) bool {
        return self.remaining == 0 and self.count == 0;
    }

    fn removeBits(self: *ReverseBitReader, num: u4) u8 {
        if (num == 8) {
            self.count = 0;
            return self.bits;
        }

        const keep = self.count - num;
        const bits = self.bits >> @intCast(keep);
        self.bits &= low_bit_mask[keep];

        self.count = keep;
        return bits;
    }
};

const BitReader = struct {
    bytes: []const u8,
    index: usize = 0,
    bits: u8 = 0,
    count: u4 = 0,

    fn initBits(comptime T: type, out: anytype, num: u16) Bits(T) {
        const UT = std.meta.Int(.unsigned, @bitSizeOf(T));
        return .{
            @bitCast(@as(UT, @intCast(out))),
            num,
        };
    }

    fn readBitsNoEof(self: *@This(), comptime T: type, num: u16) !T {
        const b, const c = try self.readBitsTuple(T, num);
        if (c < num) return error.EndOfStream;
        return b;
    }

    fn readBits(self: *@This(), comptime T: type, num: u16, out_bits: *u16) !T {
        const b, const c = try self.readBitsTuple(T, num);
        out_bits.* = c;
        return b;
    }

    fn readBitsTuple(self: *@This(), comptime T: type, num: u16) !Bits(T) {
        const UT = std.meta.Int(.unsigned, @bitSizeOf(T));
        const U = if (@bitSizeOf(T) < 8) u8 else UT;

        if (num <= self.count) return initBits(T, self.removeBits(@intCast(num)), num);

        var out_count: u16 = self.count;
        var out: U = self.removeBits(self.count);

        const full_bytes_left = (num - out_count) / 8;

        for (0..full_bytes_left) |_| {
            const byte = takeByte(self) catch |err| switch (err) {
                error.EndOfStream => return initBits(T, out, out_count),
            };

            const pos = @as(U, byte) << @intCast(out_count);
            out |= pos;
            out_count += 8;
        }

        const bits_left = num - out_count;
        const keep = 8 - bits_left;

        if (bits_left == 0) return initBits(T, out, out_count);

        const final_byte = takeByte(self) catch |err| switch (err) {
            error.EndOfStream => return initBits(T, out, out_count),
        };

        const pos = @as(U, final_byte & low_bit_mask[bits_left]) << @intCast(out_count);
        out |= pos;
        self.bits = final_byte >> @intCast(bits_left);

        self.count = @intCast(keep);
        return initBits(T, out, num);
    }

    fn takeByte(br: *BitReader) error{EndOfStream}!u8 {
        if (br.bytes.len - br.index == 0) return error.EndOfStream;
        const result = br.bytes[br.index];
        br.index += 1;
        return result;
    }

    fn removeBits(self: *@This(), num: u4) u8 {
        if (num == 8) {
            self.count = 0;
            return self.bits;
        }

        const keep = self.count - num;
        const bits = self.bits & low_bit_mask[num];
        self.bits >>= @intCast(num);
        self.count = keep;
        return bits;
    }

    fn alignToByte(self: *@This()) void {
        self.bits = 0;
        self.count = 0;
    }
};

test {
    _ = Table;
}
