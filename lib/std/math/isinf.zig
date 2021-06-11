// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

/// Returns whether x is an infinity, ignoring sign.
pub fn isInf(x: anytype) bool {
    const T = @TypeOf(x);
    switch (T) {
        f16 => {
            const bits = @bitCast(u16, x);
            return bits & 0x7FFF == 0x7C00;
        },
        f32 => {
            const bits = @bitCast(u32, x);
            return bits & 0x7FFFFFFF == 0x7F800000;
        },
        f64 => {
            const bits = @bitCast(u64, x);
            return bits & (maxInt(u64) >> 1) == (0x7FF << 52);
        },
        f128 => {
            const bits = @bitCast(u128, x);
            return bits & (maxInt(u128) >> 1) == (0x7FFF << 112);
        },
        else => {
            @compileError("isInf not implemented for " ++ @typeName(T));
        },
    }
}

/// Returns whether x is an infinity with a positive sign.
pub fn isPositiveInf(x: anytype) bool {
    const T = @TypeOf(x);
    switch (T) {
        f16 => {
            return @bitCast(u16, x) == 0x7C00;
        },
        f32 => {
            return @bitCast(u32, x) == 0x7F800000;
        },
        f64 => {
            return @bitCast(u64, x) == 0x7FF << 52;
        },
        f128 => {
            return @bitCast(u128, x) == 0x7FFF << 112;
        },
        else => {
            @compileError("isPositiveInf not implemented for " ++ @typeName(T));
        },
    }
}

/// Returns whether x is an infinity with a negative sign.
pub fn isNegativeInf(x: anytype) bool {
    const T = @TypeOf(x);
    switch (T) {
        f16 => {
            return @bitCast(u16, x) == 0xFC00;
        },
        f32 => {
            return @bitCast(u32, x) == 0xFF800000;
        },
        f64 => {
            return @bitCast(u64, x) == 0xFFF << 52;
        },
        f128 => {
            return @bitCast(u128, x) == 0xFFFF << 112;
        },
        else => {
            @compileError("isNegativeInf not implemented for " ++ @typeName(T));
        },
    }
}

test "math.isInf" {
    try expect(!isInf(@as(f16, 0.0)));
    try expect(!isInf(@as(f16, -0.0)));
    try expect(!isInf(@as(f32, 0.0)));
    try expect(!isInf(@as(f32, -0.0)));
    try expect(!isInf(@as(f64, 0.0)));
    try expect(!isInf(@as(f64, -0.0)));
    try expect(!isInf(@as(f128, 0.0)));
    try expect(!isInf(@as(f128, -0.0)));
    try expect(isInf(math.inf(f16)));
    try expect(isInf(-math.inf(f16)));
    try expect(isInf(math.inf(f32)));
    try expect(isInf(-math.inf(f32)));
    try expect(isInf(math.inf(f64)));
    try expect(isInf(-math.inf(f64)));
    try expect(isInf(math.inf(f128)));
    try expect(isInf(-math.inf(f128)));
}

test "math.isPositiveInf" {
    try expect(!isPositiveInf(@as(f16, 0.0)));
    try expect(!isPositiveInf(@as(f16, -0.0)));
    try expect(!isPositiveInf(@as(f32, 0.0)));
    try expect(!isPositiveInf(@as(f32, -0.0)));
    try expect(!isPositiveInf(@as(f64, 0.0)));
    try expect(!isPositiveInf(@as(f64, -0.0)));
    try expect(!isPositiveInf(@as(f128, 0.0)));
    try expect(!isPositiveInf(@as(f128, -0.0)));
    try expect(isPositiveInf(math.inf(f16)));
    try expect(!isPositiveInf(-math.inf(f16)));
    try expect(isPositiveInf(math.inf(f32)));
    try expect(!isPositiveInf(-math.inf(f32)));
    try expect(isPositiveInf(math.inf(f64)));
    try expect(!isPositiveInf(-math.inf(f64)));
    try expect(isPositiveInf(math.inf(f128)));
    try expect(!isPositiveInf(-math.inf(f128)));
}

test "math.isNegativeInf" {
    try expect(!isNegativeInf(@as(f16, 0.0)));
    try expect(!isNegativeInf(@as(f16, -0.0)));
    try expect(!isNegativeInf(@as(f32, 0.0)));
    try expect(!isNegativeInf(@as(f32, -0.0)));
    try expect(!isNegativeInf(@as(f64, 0.0)));
    try expect(!isNegativeInf(@as(f64, -0.0)));
    try expect(!isNegativeInf(@as(f128, 0.0)));
    try expect(!isNegativeInf(@as(f128, -0.0)));
    try expect(!isNegativeInf(math.inf(f16)));
    try expect(isNegativeInf(-math.inf(f16)));
    try expect(!isNegativeInf(math.inf(f32)));
    try expect(isNegativeInf(-math.inf(f32)));
    try expect(!isNegativeInf(math.inf(f64)));
    try expect(isNegativeInf(-math.inf(f64)));
    try expect(!isNegativeInf(math.inf(f128)));
    try expect(isNegativeInf(-math.inf(f128)));
}
