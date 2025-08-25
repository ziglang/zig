/*  Copyright (c) 2014 Apple, Inc.  All rights reserved.
 *
 *  This header provides small vector (simd) and matrix types, and basic
 *  arithmetic and mathematical functions for them.  The vast majority of these
 *  operations are implemented as header inlines, as they can be performed
 *  using just a few instructions on most processors.
 *
 *  These functions are broken into two groups; vector and matrix.  This header
 *  includes all of them, but these may also be included separately.  Consult
 *  these two headers for detailed documentation of what types and operations
 *  are available.
 */

#ifndef __SIMD_HEADER__
#define __SIMD_HEADER__

#if __has_include(<realtime_safety/realtime_safety.h>)
#include <realtime_safety/realtime_safety.h>
REALTIME_SAFE_BEGIN
#endif

#include <simd/vector.h>
#include <simd/matrix.h>
#include <simd/quaternion.h>

#if __has_include(<realtime_safety/realtime_safety.h>)
REALTIME_SAFE_END
#endif

#endif
