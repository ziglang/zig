// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __floatuntisf = @import("floatuntisf.zig").__floatuntisf;
const testing = @import("std").testing;

fn test__floatuntisf(a: u128, expected: f32) !void {
    const x = __floatuntisf(a);
    try testing.expect(x == expected);
}

test "floatuntisf" {
    try test__floatuntisf(0, 0.0);

    try test__floatuntisf(1, 1.0);
    try test__floatuntisf(2, 2.0);
    try test__floatuntisf(20, 20.0);

    try test__floatuntisf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floatuntisf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);

    try test__floatuntisf(make_ti(0x8000008000000000, 0), 0x1.000001p+127);
    try test__floatuntisf(make_ti(0x8000000000000800, 0), 0x1.0p+127);
    try test__floatuntisf(make_ti(0x8000010000000000, 0), 0x1.000002p+127);

    try test__floatuntisf(make_ti(0x8000000000000000, 0), 0x1.000000p+127);

    try test__floatuntisf(0x0007FB72E8000000, 0x1.FEDCBAp+50);

    try test__floatuntisf(0x0007FB72EA000000, 0x1.FEDCBA8p+50);
    try test__floatuntisf(0x0007FB72EB000000, 0x1.FEDCBACp+50);

    try test__floatuntisf(0x0007FB72EC000000, 0x1.FEDCBBp+50);

    try test__floatuntisf(0x0007FB72E6000000, 0x1.FEDCB98p+50);
    try test__floatuntisf(0x0007FB72E7000000, 0x1.FEDCB9Cp+50);
    try test__floatuntisf(0x0007FB72E4000000, 0x1.FEDCB9p+50);

    try test__floatuntisf(0xFFFFFFFFFFFFFFFE, 0x1p+64);
    try test__floatuntisf(0xFFFFFFFFFFFFFFFF, 0x1p+64);

    try test__floatuntisf(0x0007FB72E8000000, 0x1.FEDCBAp+50);

    try test__floatuntisf(0x0007FB72EA000000, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72EB000000, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72EBFFFFFF, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72EC000000, 0x1.FEDCBCp+50);
    try test__floatuntisf(0x0007FB72E8000001, 0x1.FEDCBAp+50);

    try test__floatuntisf(0x0007FB72E6000000, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72E7000000, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72E7FFFFFF, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72E4000001, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72E4000000, 0x1.FEDCB8p+50);

    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCB90000000000001), 0x1.FEDCBAp+76);
    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCBA0000000000000), 0x1.FEDCBAp+76);
    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCBAFFFFFFFFFFFFF), 0x1.FEDCBAp+76);
    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCBB0000000000000), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCBB0000000000001), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCBBFFFFFFFFFFFFF), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCBC0000000000000), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCBC0000000000001), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCBD0000000000000), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCBD0000000000001), 0x1.FEDCBEp+76);
    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCBDFFFFFFFFFFFFF), 0x1.FEDCBEp+76);
    try test__floatuntisf(make_ti(0x0000000000001FED, 0xCBE0000000000000), 0x1.FEDCBEp+76);
}

fn make_ti(high: u64, low: u64) u128 {
    var result: u128 = high;
    result <<= 64;
    result |= low;
    return result;
}
