const std = @import("../std.zig");
const assert = std.debug.assert;

pub const Rational = @import("big/rational.zig").Rational;
pub const int = @import("big/int.zig");
pub const Limb = usize;
pub const DoubleLimb = std.meta.IntType(false, 2 * Limb.bit_count);
pub const SignedDoubleLimb = std.meta.IntType(true, DoubleLimb.bit_count);
pub const Log2Limb = std.math.Log2Int(Limb);

comptime {
    assert(std.math.floorPowerOfTwo(usize, Limb.bit_count) == Limb.bit_count);
    assert(Limb.bit_count <= 64); // u128 set is unsupported
    assert(Limb.is_signed == false);
}

test "" {
    _ = int;
    _ = Rational;
    _ = Limb;
    _ = DoubleLimb;
    _ = SignedDoubleLimb;
    _ = Log2Limb;
}
