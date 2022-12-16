const std = @import("../std.zig");
const assert = std.debug.assert;

pub const Rational = @import("big/rational.zig").Rational;
pub const int = @import("big/int.zig");
pub const Limb = usize;
const limb_info = @typeInfo(Limb).Int;
pub const SignedLimb = @Int(.signed, limb_info.bits);
pub const DoubleLimb = @Int(.unsigned, 2 * limb_info.bits);
pub const HalfLimb = @Int(.unsigned, limb_info.bits / 2);
pub const SignedDoubleLimb = @Int(.signed, 2 * limb_info.bits);
pub const Log2Limb = std.math.Log2Int(Limb);

comptime {
    assert(std.math.floorPowerOfTwo(usize, limb_info.bits) == limb_info.bits);
    assert(limb_info.bits <= 64); // u128 set is unsupported
    assert(limb_info.signedness == .unsigned);
}

test {
    _ = int;
    _ = Rational;
    _ = Limb;
    _ = SignedLimb;
    _ = DoubleLimb;
    _ = SignedDoubleLimb;
    _ = Log2Limb;
}
