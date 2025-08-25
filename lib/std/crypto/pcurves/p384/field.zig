const std = @import("std");
const common = @import("../common.zig");

const Field = common.Field;

pub const Fe = Field(.{
    .fiat = @import("p384_64.zig"),
    .field_order = 39402006196394479212279040100143613805079739270465446667948293404245721771496870329047266088258938001861606973112319,
    .field_bits = 384,
    .saturated_bits = 384,
    .encoded_length = 48,
});
