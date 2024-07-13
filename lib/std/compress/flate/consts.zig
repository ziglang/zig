pub const deflate = struct {
    // Number of tokens to accumulate in deflate before starting block encoding.
    //
    // In zlib this depends on memlevel: 6 + memlevel, where default memlevel is
    // 8 and max 9 that gives 14 or 15 bits.
    pub const tokens = 1 << 15;
};

pub const match = struct {
    pub const base_length = 3; // smallest match length per the RFC section 3.2.5
    pub const min_length = 4; // min length used in this algorithm
    pub const max_length = 258;

    pub const min_distance = 1;
    pub const max_distance = 32768;
};

pub const history = struct {
    pub const len = match.max_distance;
};

pub const lookup = struct {
    pub const bits = 15;
    pub const len = 1 << bits;
    pub const shift = 32 - bits;
};

pub const huffman = struct {
    // The odd order in which the codegen code sizes are written.
    pub const codegen_order = [_]u32{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
    // The number of codegen codes.
    pub const codegen_code_count = 19;

    // The largest distance code.
    pub const distance_code_count = 30;

    // Maximum number of literals.
    pub const max_num_lit = 286;

    // Max number of frequencies used for a Huffman Code
    // Possible lengths are codegen_code_count (19), distance_code_count (30) and max_num_lit (286).
    // The largest of these is max_num_lit.
    pub const max_num_frequencies = max_num_lit;

    // Biggest block size for uncompressed block.
    pub const max_store_block_size = 65535;
    // The special code used to mark the end of a block.
    pub const end_block_marker = 256;
};
