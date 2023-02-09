pub const frame = struct {
    pub const Kind = enum { zstandard, skippable };

    pub const Zstandard = struct {
        pub const magic_number = 0xFD2FB528;

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
        };

        pub const Block = struct {
            pub const Header = struct {
                last_block: bool,
                block_type: Block.Type,
                block_size: u21,
            };

            pub const Type = enum(u2) {
                raw,
                rle,
                compressed,
                reserved,
            };
        };
    };

    pub const Skippable = struct {
        pub const magic_number_min = 0x184D2A50;
        pub const magic_number_max = 0x184D2A5F;

        pub const Header = struct {
            magic_number: u32,
            frame_size: u32,
        };
    };
};

pub const compressed_block = struct {
    pub const LiteralsSection = struct {
        header: Header,
        huffman_tree: ?HuffmanTree,
        streams: Streams,

        pub const Streams = union(enum) {
            one: []const u8,
            four: [4][]const u8,
        };

        pub const Header = struct {
            block_type: BlockType,
            size_format: u2,
            regenerated_size: u20,
            compressed_size: ?u18,
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

            pub fn query(self: HuffmanTree, index: usize, prefix: u16) error{NotFound}!Result {
                var node = self.nodes[index];
                const weight = node.weight;
                var i: usize = index;
                while (node.weight == weight) {
                    if (node.prefix == prefix) return Result{ .symbol = node.symbol };
                    if (i == 0) return error.NotFound;
                    i -= 1;
                    node = self.nodes[i];
                }
                return Result{ .index = i };
            }

            pub fn weightToBitCount(weight: u4, max_bit_count: u4) u4 {
                return if (weight == 0) 0 else ((max_bit_count + 1) - weight);
            }
        };

        pub const StreamCount = enum { one, four };
        pub fn streamCount(size_format: u2, block_type: BlockType) StreamCount {
            return switch (block_type) {
                .raw, .rle => .one,
                .compressed, .treeless => if (size_format == 0) .one else .four,
            };
        }
    };

    pub const SequencesSection = struct {
        header: SequencesSection.Header,
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
    };

    pub const literals_length_code_table = [36]struct { u32, u5 }{
        .{ 0, 0 },     .{ 1, 0 },      .{ 2, 0 },      .{ 3, 0 },
        .{ 4, 0 },     .{ 5, 0 },      .{ 6, 0 },      .{ 7, 0 },
        .{ 8, 0 },     .{ 9, 0 },      .{ 10, 0 },     .{ 11, 0 },
        .{ 12, 0 },    .{ 13, 0 },     .{ 14, 0 },     .{ 15, 0 },
        .{ 16, 1 },    .{ 18, 1 },     .{ 20, 1 },     .{ 22, 1 },
        .{ 24, 2 },    .{ 28, 2 },     .{ 32, 3 },     .{ 40, 3 },
        .{ 48, 4 },    .{ 64, 6 },     .{ 128, 7 },    .{ 256, 8 },
        .{ 512, 9 },   .{ 1024, 10 },  .{ 2048, 11 },  .{ 4096, 12 },
        .{ 8192, 13 }, .{ 16384, 14 }, .{ 32768, 15 }, .{ 65536, 16 },
    };

    pub const match_length_code_table = [53]struct { u32, u5 }{
        .{ 3, 0 },     .{ 4, 0 },     .{ 5, 0 },      .{ 6, 0 },      .{ 7, 0 },      .{ 8, 0 },
        .{ 9, 0 },     .{ 10, 0 },    .{ 11, 0 },     .{ 12, 0 },     .{ 13, 0 },     .{ 14, 0 },
        .{ 15, 0 },    .{ 16, 0 },    .{ 17, 0 },     .{ 18, 0 },     .{ 19, 0 },     .{ 20, 0 },
        .{ 21, 0 },    .{ 22, 0 },    .{ 23, 0 },     .{ 24, 0 },     .{ 25, 0 },     .{ 26, 0 },
        .{ 27, 0 },    .{ 28, 0 },    .{ 29, 0 },     .{ 30, 0 },     .{ 31, 0 },     .{ 32, 0 },
        .{ 33, 0 },    .{ 34, 0 },    .{ 35, 1 },     .{ 37, 1 },     .{ 39, 1 },     .{ 41, 1 },
        .{ 43, 2 },    .{ 47, 2 },    .{ 51, 3 },     .{ 59, 3 },     .{ 67, 4 },     .{ 83, 4 },
        .{ 99, 5 },    .{ 131, 7 },   .{ 259, 8 },    .{ 515, 9 },    .{ 1027, 10 },  .{ 2051, 11 },
        .{ 4099, 12 }, .{ 8195, 13 }, .{ 16387, 14 }, .{ 32771, 15 }, .{ 65539, 16 },
    };

    pub const literals_length_default_distribution = [36]i16{
        4,  3,  2,  2,  2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1,
        2,  2,  2,  2,  2, 2, 2, 2, 2, 3, 2, 1, 1, 1, 1, 1,
        -1, -1, -1, -1,
    };

    pub const match_lengths_default_distribution = [53]i16{
        1,  4,  3,  2,  2,  2, 2, 2, 2, 1, 1, 1, 1, 1, 1,  1,
        1,  1,  1,  1,  1,  1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  1,
        1,  1,  1,  1,  1,  1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1,
        -1, -1, -1, -1, -1,
    };

    pub const offset_codes_default_distribution = [29]i16{
        1, 1, 1, 1, 1, 1, 2, 2, 2,  1,  1,  1,  1,  1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1,
    };

    pub const predefined_literal_fse_table = Table{
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

    pub const predefined_match_fse_table = Table{
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

    pub const predefined_offset_fse_table = Table{
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
    pub const start_repeated_offset_1 = 1;
    pub const start_repeated_offset_2 = 4;
    pub const start_repeated_offset_3 = 8;

    pub const table_accuracy_log_max = struct {
        pub const literal = 9;
        pub const match = 9;
        pub const offset = 8;
    };

    pub const table_symbol_count_max = struct {
        pub const literal = 36;
        pub const match = 53;
        pub const offset = 32;
    };

    pub const default_accuracy_log = struct {
        pub const literal = 6;
        pub const match = 6;
        pub const offset = 5;
    };
    pub const table_size_max = struct {
        pub const literal = 1 << table_accuracy_log_max.literal;
        pub const match = 1 << table_accuracy_log_max.match;
        pub const offset = 1 << table_accuracy_log_max.match;
    };
};

test {
    const testing = @import("std").testing;
    testing.refAllDeclsRecursive(@This());
}
