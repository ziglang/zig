const std = @import("std");
const builtin = @import("builtin");

// bswap - byteswap
// - bswapXi2_generic for unoptimized big and little endian
// ie for u32
// DE AD BE EF   <- little|big endian
// FE BE AD DE   <- big|little endian
// ff 00 00 00 >> 3*8 (leftmost  byte)
// 00 ff 00 00 >> 1*8 (2nd left  byte)
// 00 00 ff 00 << 1*8 (2n right  byte)
// 00 00 00 ff << 3*8 (rightmost byte)

fn bswapXi2_generic(comptime T: type) fn (a: T) callconv(.C) T {
    return struct {
        fn f(a: T) callconv(.C) T {
            @setRuntimeSafety(builtin.is_test);
            switch (@bitSizeOf(T)) {
                32 => {
                    // zig fmt: off
                    return (((a & 0xff000000) >> 24)
                         |  ((a & 0x00ff0000) >> 8 )
                         |  ((a & 0x0000ff00) << 8 )
                         |  ((a & 0x000000ff) << 24));
                    // zig fmt: on
                },
                64 => {
                    // zig fmt: off
                    return (((a & 0xff00000000000000) >> 56)
                         |  ((a & 0x00ff000000000000) >> 40 )
                         |  ((a & 0x0000ff0000000000) >> 24 )
                         |  ((a & 0x000000ff00000000) >> 8 )
                         |  ((a & 0x00000000ff000000) << 8 )
                         |  ((a & 0x0000000000ff0000) << 24 )
                         |  ((a & 0x000000000000ff00) << 40 )
                         |  ((a & 0x00000000000000ff) << 56));
                    // zig fmt: on
                },
                128 => {
                    // zig fmt: off
                    return (((a & 0xff000000000000000000000000000000) >> 120)
                         |  ((a & 0x00ff0000000000000000000000000000) >> 104)
                         |  ((a & 0x0000ff00000000000000000000000000) >> 88 )
                         |  ((a & 0x000000ff000000000000000000000000) >> 72 )
                         |  ((a & 0x00000000ff0000000000000000000000) >> 56 )
                         |  ((a & 0x0000000000ff00000000000000000000) >> 40 )
                         |  ((a & 0x000000000000ff000000000000000000) >> 24 )
                         |  ((a & 0x00000000000000ff0000000000000000) >> 8  )
                         |  ((a & 0x0000000000000000ff00000000000000) << 8  )
                         |  ((a & 0x000000000000000000ff000000000000) << 24 )
                         |  ((a & 0x00000000000000000000ff0000000000) << 40 )
                         |  ((a & 0x0000000000000000000000ff00000000) << 56 )
                         |  ((a & 0x000000000000000000000000ff000000) << 72 )
                         |  ((a & 0x00000000000000000000000000ff0000) << 88 )
                         |  ((a & 0x0000000000000000000000000000ff00) << 104)
                         |  ((a & 0x000000000000000000000000000000ff) << 120));
                    // zig fmt: on
                },
                else => {
                    unreachable;
                },
            }
        }
    }.f;
}

pub const __bswapsi2 = bswapXi2_generic(u32);

pub const __bswapdi2 = bswapXi2_generic(u64);

pub const __bswapti2 = bswapXi2_generic(u128);

test {
    _ = @import("bswapsi2_test.zig");
    _ = @import("bswapdi2_test.zig");
    _ = @import("bswapti2_test.zig");
}
