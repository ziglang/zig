// Deflate

// Biggest block size for uncompressed block.
pub const max_store_block_size = 65535;
// The special code used to mark the end of a block.
pub const end_block_marker = 256;

// LZ77

// The smallest match length per the RFC section 3.2.5
pub const base_match_length = 3;
// The smallest match offset.
pub const base_match_offset = 1;
// The largest match length.
pub const max_match_length = 258;
// The largest match offset.
pub const max_match_offset = 1 << 15;

// Huffman Codes

// The largest offset code.
pub const offset_code_count = 30;
// Max number of frequencies used for a Huffman Code
// Possible lengths are codegenCodeCount (19), offset_code_count (30) and max_num_lit (286).
// The largest of these is max_num_lit.
pub const max_num_frequencies = max_num_lit;
// Maximum number of literals.
pub const max_num_lit = 286;
