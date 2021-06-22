// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std");
const common = @import("../common.zig");

const Field = common.Field;

pub const Fe = Field(.{
    .fiat = @import("p256_64.zig"),
    .field_order = 115792089210356248762697446949407573530086143415290314195533631308867097853951,
    .field_bits = 256,
    .saturated_bits = 255,
    .encoded_length = 32,
});
