// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __floatdisf = @import("floatXisf.zig").__floatdisf;
const testing = @import("std").testing;

fn test__floatdisf(a: i64, expected: f32) !void {
    const x = __floatdisf(a);
    try testing.expect(x == expected);
}

test "floatdisf" {
    try test__floatdisf(0, 0.0);
    try test__floatdisf(1, 1.0);
    try test__floatdisf(2, 2.0);
    try test__floatdisf(-1, -1.0);
    try test__floatdisf(-2, -2.0);
    try test__floatdisf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floatdisf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    try test__floatdisf(0x8000008000000000, -0x1.FFFFFEp+62);
    try test__floatdisf(0x8000010000000000, -0x1.FFFFFCp+62);
    try test__floatdisf(0x8000000000000000, -0x1.000000p+63);
    try test__floatdisf(0x8000000000000001, -0x1.000000p+63);
    try test__floatdisf(0x0007FB72E8000000, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72EA000000, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72EB000000, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72EBFFFFFF, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72EC000000, 0x1.FEDCBCp+50);
    try test__floatdisf(0x0007FB72E8000001, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72E6000000, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72E7000000, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72E7FFFFFF, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72E4000001, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72E4000000, 0x1.FEDCB8p+50);
}
