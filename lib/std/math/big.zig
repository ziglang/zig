// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const assert = std.debug.assert;

pub const Rational = @import("big/rational.zig").Rational;
pub const int = @import("big/int.zig");
pub const Limb = usize;
const limb_info = @typeInfo(Limb).Int;
pub const DoubleLimb = std.meta.Int(.unsigned, 2 * limb_info.bits);
pub const SignedDoubleLimb = std.meta.Int(.signed, 2 * limb_info.bits);
pub const Log2Limb = std.math.Log2Int(Limb);

comptime {
    assert(std.math.floorPowerOfTwo(usize, limb_info.bits) == limb_info.bits);
    assert(limb_info.bits <= 64); // u128 set is unsupported
    assert(limb_info.is_signed == false);
}

test "" {
    _ = int;
    _ = Rational;
    _ = Limb;
    _ = DoubleLimb;
    _ = SignedDoubleLimb;
    _ = Log2Limb;
}
