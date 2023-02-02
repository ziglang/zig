pub const lzbuffer = @import("decode/lzbuffer.zig");
pub const lzma = @import("decode/lzma.zig");
pub const lzma2 = @import("decode/lzma2.zig");
pub const rangecoder = @import("decode/rangecoder.zig");

pub const Options = struct {
    unpacked_size: UnpackedSize = .read_from_header,
    memlimit: ?usize = null,
    allow_incomplete: bool = false,
};

pub const UnpackedSize = union(enum) {
    read_from_header,
    read_header_but_use_provided: ?u64,
    use_provided: ?u64,
};
