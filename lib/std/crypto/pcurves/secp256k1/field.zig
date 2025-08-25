const std = @import("std");
const common = @import("../common.zig");

const Field = common.Field;

pub const Fe = Field(.{
    .fiat = @import("secp256k1_64.zig"),
    .field_order = 115792089237316195423570985008687907853269984665640564039457584007908834671663,
    .field_bits = 256,
    .saturated_bits = 256,
    .encoded_length = 32,
});
