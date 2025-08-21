// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
//
// Cephes Math Library Release 2.3:  March, 1995
// Copyright 1984, 1995 by Stephen L. Moshier

const std = @import("std");
const math = std.math;

/// f64 machine epsilon, 2**-53 ≈ 1.11022302462515654042E-16
pub const MACHEP = math.floatEps(f64); 

/// f64 smallest normal number, 2**-1022 ≈ 2.22507385850720138309E-308
pub const UFLOWTHRESH = math.floatMin(f64);

/// f64 largest normal number, 2**1024*(1-MACHEP) ≈ 1.79769313486231570815E308
pub const MAXNUM = math.floatMax(f64);

/// ln(MAXNUM)
pub const MAXLOG = 7.09782712893383996732E2;

/// ln(2**-1075)
pub const MINLOG = -7.451332191019412076235E2;
// Not sure where 2^-1075 comes from… 
// 2^-1074 is the smallest possible subnormal number

/// pi (in math.zig)
pub const PI = math.pi;

/// pi/2
pub const PIO2 = math.pi_2;

/// pi/4
pub const PIO4 = math.pi_4;

/// sqrt(2) (in math.zig)
pub const SQRT2 = math.sqrt2;

/// sqrt(2)/2 (in math.zig)
pub const SQRTH = math.sqrt1_2;

/// 1/log(2) (in math.zig)
pub const LOG2E = math.log2e;

/// sqrt( 2/pi ) (in math.zig, off by factor of sqrt(2))
pub const SQ2OPI = math.sqrt2_pi;

/// log(2) (in math.zig)
pub const LOGE2 = math.ln2;

/// log(2)/2
pub const LOGSQ2 = math.lnsqrt2;

/// 3*pi/4
pub const THPIO4 = math.threepi_4;

/// 2/pi
pub const TWOOPI = math.two_pi;
