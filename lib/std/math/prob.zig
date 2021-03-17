// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const testing = std.testing;
const math = std.math;

pub const ndtr = @import("prob/ndtr.zig").ndtr;
pub const erfc = @import("prob/ndtr.zig").erfc;
pub const erf = @import("prob/ndtr.zig").erf;
pub const j1 = @import("prob/j1.zig").j1;
pub const y1 = @import("prob/j1.zig").y1;
pub const j0 = @import("prob/j0.zig").j0;
pub const y0 = @import("prob/j0.zig").y0;
pub const jv = @import("prob/jv.zig").jv;
pub const hankel = @import("prob/jv.zig").hankel;
pub const jnx = @import("prob/jv.zig").jnx;
pub const jnt = @import("prob/jv.zig").jnt;
pub const airy = @import("prob/airy.zig").airy;
pub const igamc = @import("prob/igam.zig").igamc;
pub const igami = @import("prob/igami.zig").igami;
pub const igam = @import("prob/igam.zig").igam;
pub const gamma = @import("prob/gamma.zig").gamma;
pub const lgam = @import("prob/gamma.zig").lgam;
pub const ndtri = @import("prob/ndtri.zig").ndtri;
pub const incbet = @import("prob/incbet.zig").incbet;
pub const incbcf = @import("prob/incbet.zig").incbcf;
pub const incbd = @import("prob/incbet.zig").incbcd;
pub const pseries = @import("prob/incbet.zig").pseries;
pub const incbi = @import("prob/incbi.zig").incbi;
pub const polevl = @import("prob/polevl.zig").polevl;
pub const p1evl = @import("prob/polevl.zig").p1evl;

test "math.prob" {
    _ = @import("prob/airy.zig");
    _ = @import("prob/expx2.zig");
    _ = @import("prob/gamma.zig");
    _ = @import("prob/igami.zig");
    _ = @import("prob/igam.zig");
    _ = @import("prob/incbet.zig");
    _ = @import("prob/incbi.zig");
    _ = @import("prob/j0.zig");
    _ = @import("prob/j1.zig");
    _ = @import("prob/jv.zig");
    _ = @import("prob/ndtri.zig");
    _ = @import("prob/ndtr.zig");
    _ = @import("prob/polevl.zig");
}
