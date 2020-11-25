// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __floatuntitf = @import("floatuntitf.zig").__floatuntitf;
const testing = @import("std").testing;

fn test__floatuntitf(a: u128, expected: f128) void {
    const x = __floatuntitf(a);
    testing.expect(x == expected);
}

test "floatuntitf" {
    test__floatuntitf(0, 0.0);

    test__floatuntitf(1, 1.0);
    test__floatuntitf(2, 2.0);
    test__floatuntitf(20, 20.0);

    test__floatuntitf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    test__floatuntitf(0x7FFFFFFFFFFFF800, 0x1.FFFFFFFFFFFFEp+62);
    test__floatuntitf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    test__floatuntitf(0x7FFFFFFFFFFFF000, 0x1.FFFFFFFFFFFFCp+62);
    test__floatuntitf(0x7FFFFFFFFFFFFFFF, 0xF.FFFFFFFFFFFFFFEp+59);
    test__floatuntitf(0xFFFFFFFFFFFFFFFE, 0xF.FFFFFFFFFFFFFFEp+60);
    test__floatuntitf(0xFFFFFFFFFFFFFFFF, 0xF.FFFFFFFFFFFFFFFp+60);

    test__floatuntitf(0x8000008000000000, 0x8.000008p+60);
    test__floatuntitf(0x8000000000000800, 0x8.0000000000008p+60);
    test__floatuntitf(0x8000010000000000, 0x8.00001p+60);
    test__floatuntitf(0x8000000000001000, 0x8.000000000001p+60);

    test__floatuntitf(0x8000000000000000, 0x8p+60);
    test__floatuntitf(0x8000000000000001, 0x8.000000000000001p+60);

    test__floatuntitf(0x0007FB72E8000000, 0x1.FEDCBAp+50);

    test__floatuntitf(0x0007FB72EA000000, 0x1.FEDCBA8p+50);
    test__floatuntitf(0x0007FB72EB000000, 0x1.FEDCBACp+50);
    test__floatuntitf(0x0007FB72EBFFFFFF, 0x1.FEDCBAFFFFFFCp+50);
    test__floatuntitf(0x0007FB72EC000000, 0x1.FEDCBBp+50);
    test__floatuntitf(0x0007FB72E8000001, 0x1.FEDCBA0000004p+50);

    test__floatuntitf(0x0007FB72E6000000, 0x1.FEDCB98p+50);
    test__floatuntitf(0x0007FB72E7000000, 0x1.FEDCB9Cp+50);
    test__floatuntitf(0x0007FB72E7FFFFFF, 0x1.FEDCB9FFFFFFCp+50);
    test__floatuntitf(0x0007FB72E4000001, 0x1.FEDCB90000004p+50);
    test__floatuntitf(0x0007FB72E4000000, 0x1.FEDCB9p+50);

    test__floatuntitf(0x023479FD0E092DC0, 0x1.1A3CFE870496Ep+57);
    test__floatuntitf(0x023479FD0E092DA1, 0x1.1A3CFE870496D08p+57);
    test__floatuntitf(0x023479FD0E092DB0, 0x1.1A3CFE870496D8p+57);
    test__floatuntitf(0x023479FD0E092DB8, 0x1.1A3CFE870496DCp+57);
    test__floatuntitf(0x023479FD0E092DB6, 0x1.1A3CFE870496DBp+57);
    test__floatuntitf(0x023479FD0E092DBF, 0x1.1A3CFE870496DF8p+57);
    test__floatuntitf(0x023479FD0E092DC1, 0x1.1A3CFE870496E08p+57);
    test__floatuntitf(0x023479FD0E092DC7, 0x1.1A3CFE870496E38p+57);
    test__floatuntitf(0x023479FD0E092DC8, 0x1.1A3CFE870496E4p+57);
    test__floatuntitf(0x023479FD0E092DCF, 0x1.1A3CFE870496E78p+57);
    test__floatuntitf(0x023479FD0E092DD0, 0x1.1A3CFE870496E8p+57);
    test__floatuntitf(0x023479FD0E092DD1, 0x1.1A3CFE870496E88p+57);
    test__floatuntitf(0x023479FD0E092DD8, 0x1.1A3CFE870496ECp+57);
    test__floatuntitf(0x023479FD0E092DDF, 0x1.1A3CFE870496EF8p+57);
    test__floatuntitf(0x023479FD0E092DE0, 0x1.1A3CFE870496Fp+57);

    test__floatuntitf(make_ti(0x023479FD0E092DC0, 0), 0x1.1A3CFE870496Ep+121);
    test__floatuntitf(make_ti(0x023479FD0E092DA1, 1), 0x1.1A3CFE870496D08p+121);
    test__floatuntitf(make_ti(0x023479FD0E092DB0, 2), 0x1.1A3CFE870496D8p+121);
    test__floatuntitf(make_ti(0x023479FD0E092DB8, 3), 0x1.1A3CFE870496DCp+121);
    test__floatuntitf(make_ti(0x023479FD0E092DB6, 4), 0x1.1A3CFE870496DBp+121);
    test__floatuntitf(make_ti(0x023479FD0E092DBF, 5), 0x1.1A3CFE870496DF8p+121);
    test__floatuntitf(make_ti(0x023479FD0E092DC1, 6), 0x1.1A3CFE870496E08p+121);
    test__floatuntitf(make_ti(0x023479FD0E092DC7, 7), 0x1.1A3CFE870496E38p+121);
    test__floatuntitf(make_ti(0x023479FD0E092DC8, 8), 0x1.1A3CFE870496E4p+121);
    test__floatuntitf(make_ti(0x023479FD0E092DCF, 9), 0x1.1A3CFE870496E78p+121);
    test__floatuntitf(make_ti(0x023479FD0E092DD0, 0), 0x1.1A3CFE870496E8p+121);
    test__floatuntitf(make_ti(0x023479FD0E092DD1, 11), 0x1.1A3CFE870496E88p+121);
    test__floatuntitf(make_ti(0x023479FD0E092DD8, 12), 0x1.1A3CFE870496ECp+121);
    test__floatuntitf(make_ti(0x023479FD0E092DDF, 13), 0x1.1A3CFE870496EF8p+121);
    test__floatuntitf(make_ti(0x023479FD0E092DE0, 14), 0x1.1A3CFE870496Fp+121);

    test__floatuntitf(make_ti(0, 0xFFFFFFFFFFFFFFFF), 0x1.FFFFFFFFFFFFFFFEp+63);

    test__floatuntitf(make_ti(0xFFFFFFFFFFFFFFFF, 0x0000000000000000), 0x1.FFFFFFFFFFFFFFFEp+127);
    test__floatuntitf(make_ti(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF), 0x1.0000000000000000p+128);

    test__floatuntitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC2801), 0x1.23456789ABCDEF0123456789ABC3p+124);
    test__floatuntitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC3000), 0x1.23456789ABCDEF0123456789ABC3p+124);
    test__floatuntitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC37FF), 0x1.23456789ABCDEF0123456789ABC3p+124);
    test__floatuntitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC3800), 0x1.23456789ABCDEF0123456789ABC4p+124);
    test__floatuntitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC4000), 0x1.23456789ABCDEF0123456789ABC4p+124);
    test__floatuntitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC47FF), 0x1.23456789ABCDEF0123456789ABC4p+124);
    test__floatuntitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC4800), 0x1.23456789ABCDEF0123456789ABC4p+124);
    test__floatuntitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC4801), 0x1.23456789ABCDEF0123456789ABC5p+124);
    test__floatuntitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC57FF), 0x1.23456789ABCDEF0123456789ABC5p+124);
}

fn make_ti(high: u64, low: u64) u128 {
    var result: u128 = high;
    result <<= 64;
    result |= low;
    return result;
}
