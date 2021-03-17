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

/// 2**-53
pub const MACHEP = 1.11022302462515654042E-16;

/// 2**-1022
pub const UFLOWTHRESH = 2.22507385850720138309E-308;

/// log(MAXNUM)
pub const MAXLOG = 7.09782712893383996732E2;

/// log(2**-1075)
pub const MINLOG = -7.451332191019412076235E2;

/// 2**1024*(1-MACHEP)
pub const MAXNUM = 1.79769313486231570815E308;

/// pi
pub const PI = 3.14159265358979323846;

/// pi/2
pub const PIO2 = 1.57079632679489661923;

/// pi/4
pub const PIO4 = 7.85398163397448309616E-1;

/// sqrt(2)
pub const SQRT2 = 1.41421356237309504880;

/// sqrt(2)/2
pub const SQRTH = 7.07106781186547524401E-1;

/// 1/log(2)
pub const LOG2E = 1.4426950408889634073599;

/// sqrt( 2/pi )
pub const SQ2OPI = 7.9788456080286535587989E-1;

/// log(2)
pub const LOGE2 = 6.93147180559945309417E-1;

/// log(2)/2
pub const LOGSQ2 = 3.46573590279972654709E-1;

/// 3*pi/4
pub const THPIO4 = 2.35619449019234492885;

/// 2/pi
pub const TWOOPI = 6.36619772367581343075535E-1;
