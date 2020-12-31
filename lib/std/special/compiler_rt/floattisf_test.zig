// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __floattisf = @import("floatXisf.zig").__floattisf;
const testing = @import("std").testing;

fn test__floattisf(a: i128, expected: f32) void {
    const x = __floattisf(a);
    testing.expect(x == expected);
}

test "floattisf" {
    test__floattisf(0, 0.0);

    test__floattisf(1, 1.0);
    test__floattisf(2, 2.0);
    test__floattisf(-1, -1.0);
    test__floattisf(-2, -2.0);

    test__floattisf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    test__floattisf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);

    test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF, 0x8000008000000000), -0x1.FFFFFEp+62);
    test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF, 0x8000010000000000), -0x1.FFFFFCp+62);

    test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF, 0x8000000000000000), -0x1.000000p+63);
    test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF, 0x8000000000000001), -0x1.000000p+63);

    test__floattisf(0x0007FB72E8000000, 0x1.FEDCBAp+50);

    test__floattisf(0x0007FB72EA000000, 0x1.FEDCBAp+50);
    test__floattisf(0x0007FB72EB000000, 0x1.FEDCBAp+50);
    test__floattisf(0x0007FB72EBFFFFFF, 0x1.FEDCBAp+50);
    test__floattisf(0x0007FB72EC000000, 0x1.FEDCBCp+50);
    test__floattisf(0x0007FB72E8000001, 0x1.FEDCBAp+50);

    test__floattisf(0x0007FB72E6000000, 0x1.FEDCBAp+50);
    test__floattisf(0x0007FB72E7000000, 0x1.FEDCBAp+50);
    test__floattisf(0x0007FB72E7FFFFFF, 0x1.FEDCBAp+50);
    test__floattisf(0x0007FB72E4000001, 0x1.FEDCBAp+50);
    test__floattisf(0x0007FB72E4000000, 0x1.FEDCB8p+50);

    test__floattisf(make_ti(0x0007FB72E8000000, 0), 0x1.FEDCBAp+114);

    test__floattisf(make_ti(0x0007FB72EA000000, 0), 0x1.FEDCBAp+114);
    test__floattisf(make_ti(0x0007FB72EB000000, 0), 0x1.FEDCBAp+114);
    test__floattisf(make_ti(0x0007FB72EBFFFFFF, 0), 0x1.FEDCBAp+114);
    test__floattisf(make_ti(0x0007FB72EC000000, 0), 0x1.FEDCBCp+114);
    test__floattisf(make_ti(0x0007FB72E8000001, 0), 0x1.FEDCBAp+114);

    test__floattisf(make_ti(0x0007FB72E6000000, 0), 0x1.FEDCBAp+114);
    test__floattisf(make_ti(0x0007FB72E7000000, 0), 0x1.FEDCBAp+114);
    test__floattisf(make_ti(0x0007FB72E7FFFFFF, 0), 0x1.FEDCBAp+114);
    test__floattisf(make_ti(0x0007FB72E4000001, 0), 0x1.FEDCBAp+114);
    test__floattisf(make_ti(0x0007FB72E4000000, 0), 0x1.FEDCB8p+114);
}

fn make_ti(high: u64, low: u64) i128 {
    var result: u128 = high;
    result <<= 64;
    result |= low;
    return @bitCast(i128, result);
}
