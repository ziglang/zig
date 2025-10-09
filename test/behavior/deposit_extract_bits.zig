const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const supports_pext_pdep = switch (builtin.zig_backend) {
    .stage2_llvm, .stage2_c => true,
    .stage2_x86_64 => builtin.target.os.tag != .windows,
    else => false,
};

test "@depositBits u64" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO

    const S = struct {
        pub fn doTheTest() !void {
            var a: u64 = 0;
            var b: u64 = 0xFFFF_FFFF_FFFF_FFFF;
            var c: u64 = 0x1234_5678_9012_3456;
            var d: u64 = 0x00F0_FF00_F00F_00FF;

            _ = &a;
            _ = &b;
            _ = &c;
            _ = &d;

            try expect(@depositBits(b, a) == 0);
            try expect(@depositBits(a, b) == 0);

            try expect(@depositBits(b, c) == c);
            try expect(@depositBits(b, d) == d);

            try expect(@depositBits(c, d) == 0x0000_1200_3004_0056);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@depositBits u128" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO #19991

    const S = struct {
        pub fn doTheTest() !void {
            var a: u64 = 0x1234_5678_9012_3456;
            var b: u128 = 0x00F0_FF00_F00F_00FF << 64;

            _ = &a;
            _ = &b;

            try expect(@depositBits(a, b) == 0x0000_1200_3004_0056 << 64);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@depositBits u256" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO #19991

    const S = struct {
        pub fn doTheTest() !void {
            var a: u64 = 0x1234_5678_9ABC_DEF0;
            var b: u256 = 0x0F00_0FF0_0F0F_FF00 << 174;

            _ = &a;
            _ = &b;

            try expect(@depositBits(a, b) == 0x0A00_0BC0_0D0E_F000 << 174);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@extractBits u64" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO

    const S = struct {
        pub fn doTheTest() !void {
            var a: u64 = 0;
            var b: u64 = 0xFFFF_FFFF_FFFF_FFFF;
            var c: u64 = 0x1234_5678_9012_3456;
            var d: u64 = 0x00F0_FF00_F00F_00FF;

            _ = &a;
            _ = &b;
            _ = &c;
            _ = &d;

            try expect(@extractBits(b, a) == 0);
            try expect(@extractBits(a, b) == 0);

            try expect(@extractBits(c, b) == c);
            try expect(@extractBits(d, b) == d);

            try expect(@extractBits(c, d) == 0x0356_9256);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@extractBits u128" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO #19991

    const S = struct {
        pub fn doTheTest() !void {
            var a: u128 = 0x1234_5678_9012_3456 << 64;
            var b: u128 = 0x00F0_FF00_F00F_00FF << 64;

            _ = &a;
            _ = &b;

            try expect(@extractBits(a, b) == 0x0356_9256);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@extractBits u256" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO #19991

    const S = struct {
        pub fn doTheTest() !void {
            var a: u256 = 0x1234_5678_9ABC_DEF0 << 96;
            var b: u256 = 0x0F00_0FF0_0F0F_FF00 << 96;

            _ = &a;
            _ = &b;

            try expect(@extractBits(a, b) == 0x0267_ACDE);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@depositBits" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO

    const S = struct {
        pub fn doTheTest() !void {
            try expectDepositBits(u5, 0xc, 0x0, 0x0);
            try expectDepositBits(u8, 0x34, 0x3e, 0x28);
            try expectDepositBits(u12, 0x8d1, 0x3ff, 0xd1);
            try expectDepositBits(u16, 0x71bf, 0x3af1, 0x32f1);
            try expectDepositBits(u32, 0x3bae5063, 0x7b17b132, 0x1200a012);
            try expectDepositBits(u48, 0x434aa15ff2fa, 0xce370a6c311, 0xce34086c210);
            try expectDepositBits(u64, 0x8361fc9b827793a6, 0xe67fcd567987eee6, 0x425c041639026a24);

            if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO #19991

            try expectDepositBits(u97, 0x171f755a01d485c4c34c18c81, 0xac06c853b200585f371570eb, 0x80044800a200084030142001);
            try expectDepositBits(u128, 0xb7be70a644ee77116f7265b2a4b95a8b, 0x6c3396ebe8de95f9eaf62d08b2c3cb56, 0x80292e38818856148442c0090c14046);
            try expectDepositBits(u185, 0x4a0774246e045222bb0ed34d184b1bbde1fc99c9ca0e89, 0x1b91d49bb592ec503cce5e517e87137fff828329d15be8f, 0x11811410a0104c0018ca5a510687104ce4828021001a809);
            try expectDepositBits(u256, 0x43837440edafe142bd5b2f022f8a05d596c98b3c4be1ba19f4df4f9cbaadbda2, 0x86942d4fa0882cfeea9b45ad11334e0877b81e6c3e9c8b01a38c673778c8a1d3, 0x8280214120800cc44a98018d0100480875180e640e908a008384223338888102);
            try expectDepositBits(u479, 0x4b9850b7dacb9a133557b25750455b9aead11be92175443d26db30bdd39a81e5a9a3a106d679f35067f76e832f15e13af81b56400bbe0ac9dff4cb06, 0x2c318fa22f8ae1373baa74eed5b70b1c7b7ab0bd6ea4804f88f87b21464ad5ee017cacd69a8c82bdcb68fe0b71e787eeda6d770d3c80f03a5b805dcc, 0x203084000f026024320a500805320a0c6370a0900c24804e88b0720002409584013c0086888c8200c320b200000585e8084c23093c80e02242804048);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@extractBits" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO

    const S = struct {
        pub fn doTheTest() !void {
            try expectExtractBits(u5, 0x1c, 0xe, 0x6);
            try expectExtractBits(u8, 0xc1, 0xbe, 0x20);
            try expectExtractBits(u12, 0x8fd, 0x910, 0x5);
            try expectExtractBits(u16, 0x694c, 0xaaea, 0xca);
            try expectExtractBits(u32, 0xa9f97bcf, 0x64f207c2, 0x179f);
            try expectExtractBits(u48, 0x32901c841c2a, 0x3721b7ff376d, 0x6832118c);
            try expectExtractBits(u64, 0xbc1ba402eaabd49b, 0x8324f9742e70d227, 0x21406ae3);

            if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO #19991

            try expectExtractBits(u97, 0x12c7ffc54e5772313dae0aa7a, 0x144e7728badaa0c5edee2f2ab, 0x15fe0da89f7aae);
            try expectExtractBits(u128, 0x18eb4eaa5e93441fa28d2860de22961b, 0x3b89eec7dd369bb8634b8da908272721, 0xcebc9e501b2a2699);
            try expectExtractBits(u185, 0x1fad06e744cee4f42aa80057dd1fb8b86a2281d124e389e, 0x1a5f25ae5516369fd211e040df64b5fb97ca12d189474b8, 0x1cd5ba75a083f4f2e084f16b);
            try expectExtractBits(u256, 0xb5db52469100b3796a6981ed441d685ede3c39e423d91ff5dc33d0ae3696067c, 0x2b03ad2a509cc14a8cfc71b9cfbadee93ab976d6335c3897d5188cec3c89081a, 0x4e0285c9a1da86514ee66af9f7d4bec6);
            try expectExtractBits(u479, 0x7c44ec50c139a0fb34d51fa28a9f63f9940e578df33e21792c25b4a4e931df79bcbe45eb5cce05b0e73b5d01d0bc9bd4677e2217285c390012de90cf, 0x3facb493aa8150da7350b5f7ef349addba0fc293a258319cb61c1b224f07f0e096cf117bdb0e2338a7eae3e88e8e392161be97b90e23b879c8c51333, 0x3c1d484fb33d294c7da739eeb28c593afae77739df3a4239cef88b0380743);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

fn expectDepositBits(comptime T: type, src: T, dst: T, exp: T) !void {
    return expectEqual(@depositBits(src, dst), exp);
}

fn expectExtractBits(comptime T: type, src: T, dst: T, exp: T) !void {
    return expectEqual(@extractBits(src, dst), exp);
}
