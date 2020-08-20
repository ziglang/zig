// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __floatdidf = @import("floatdidf.zig").__floatdidf;
const testing = @import("std").testing;

fn test__floatdidf(a: i64, expected: f64) void {
    const r = __floatdidf(a);
    testing.expect(r == expected);
}

test "floatdidf" {
    test__floatdidf(0, 0.0);
    test__floatdidf(1, 1.0);
    test__floatdidf(2, 2.0);
    test__floatdidf(20, 20.0);
    test__floatdidf(-1, -1.0);
    test__floatdidf(-2, -2.0);
    test__floatdidf(-20, -20.0);
    test__floatdidf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    test__floatdidf(0x7FFFFFFFFFFFF800, 0x1.FFFFFFFFFFFFEp+62);
    test__floatdidf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    test__floatdidf(0x7FFFFFFFFFFFF000, 0x1.FFFFFFFFFFFFCp+62);
    test__floatdidf(@bitCast(i64, @intCast(u64, 0x8000008000000000)), -0x1.FFFFFEp+62);
    test__floatdidf(@bitCast(i64, @intCast(u64, 0x8000000000000800)), -0x1.FFFFFFFFFFFFEp+62);
    test__floatdidf(@bitCast(i64, @intCast(u64, 0x8000010000000000)), -0x1.FFFFFCp+62);
    test__floatdidf(@bitCast(i64, @intCast(u64, 0x8000000000001000)), -0x1.FFFFFFFFFFFFCp+62);
    test__floatdidf(@bitCast(i64, @intCast(u64, 0x8000000000000000)), -0x1.000000p+63);
    test__floatdidf(@bitCast(i64, @intCast(u64, 0x8000000000000001)), -0x1.000000p+63);
    test__floatdidf(0x0007FB72E8000000, 0x1.FEDCBAp+50);
    test__floatdidf(0x0007FB72EA000000, 0x1.FEDCBA8p+50);
    test__floatdidf(0x0007FB72EB000000, 0x1.FEDCBACp+50);
    test__floatdidf(0x0007FB72EBFFFFFF, 0x1.FEDCBAFFFFFFCp+50);
    test__floatdidf(0x0007FB72EC000000, 0x1.FEDCBBp+50);
    test__floatdidf(0x0007FB72E8000001, 0x1.FEDCBA0000004p+50);
    test__floatdidf(0x0007FB72E6000000, 0x1.FEDCB98p+50);
    test__floatdidf(0x0007FB72E7000000, 0x1.FEDCB9Cp+50);
    test__floatdidf(0x0007FB72E7FFFFFF, 0x1.FEDCB9FFFFFFCp+50);
    test__floatdidf(0x0007FB72E4000001, 0x1.FEDCB90000004p+50);
    test__floatdidf(0x0007FB72E4000000, 0x1.FEDCB9p+50);
    test__floatdidf(0x023479FD0E092DC0, 0x1.1A3CFE870496Ep+57);
    test__floatdidf(0x023479FD0E092DA1, 0x1.1A3CFE870496Dp+57);
    test__floatdidf(0x023479FD0E092DB0, 0x1.1A3CFE870496Ep+57);
    test__floatdidf(0x023479FD0E092DB8, 0x1.1A3CFE870496Ep+57);
    test__floatdidf(0x023479FD0E092DB6, 0x1.1A3CFE870496Ep+57);
    test__floatdidf(0x023479FD0E092DBF, 0x1.1A3CFE870496Ep+57);
    test__floatdidf(0x023479FD0E092DC1, 0x1.1A3CFE870496Ep+57);
    test__floatdidf(0x023479FD0E092DC7, 0x1.1A3CFE870496Ep+57);
    test__floatdidf(0x023479FD0E092DC8, 0x1.1A3CFE870496Ep+57);
    test__floatdidf(0x023479FD0E092DCF, 0x1.1A3CFE870496Ep+57);
    test__floatdidf(0x023479FD0E092DD0, 0x1.1A3CFE870496Ep+57);
    test__floatdidf(0x023479FD0E092DD1, 0x1.1A3CFE870496Fp+57);
    test__floatdidf(0x023479FD0E092DD8, 0x1.1A3CFE870496Fp+57);
    test__floatdidf(0x023479FD0E092DDF, 0x1.1A3CFE870496Fp+57);
    test__floatdidf(0x023479FD0E092DE0, 0x1.1A3CFE870496Fp+57);
}
