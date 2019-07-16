/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _DCOMPTYPES_H_
#define _DCOMPTYPES_H_

#include <dxgitype.h>
#include <dxgi1_2.h>
#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

enum DCOMPOSITION_BITMAP_INTERPOLATION_MODE {
    DCOMPOSITION_BITMAP_INTERPOLATION_MODE_NEAREST_NEIGHBOR = 0,
    DCOMPOSITION_BITMAP_INTERPOLATION_MODE_LINEAR = 1,
    DCOMPOSITION_BITMAP_INTERPOLATION_MODE_INHERIT = 0xffffffff
};

enum DCOMPOSITION_BORDER_MODE {
    DCOMPOSITION_BORDER_MODE_SOFT = 0,
    DCOMPOSITION_BORDER_MODE_HARD = 1,
    DCOMPOSITION_BORDER_MODE_INHERIT = 0xffffffff
};

enum DCOMPOSITION_COMPOSITE_MODE {
    DCOMPOSITION_COMPOSITE_MODE_SOURCE_OVER = 0,
    DCOMPOSITION_COMPOSITE_MODE_DESTINATION_INVERT = 1,
    DCOMPOSITION_COMPOSITE_MODE_MIN_BLEND = 2,
    DCOMPOSITION_COMPOSITE_MODE_INHERIT = 0xffffffff
};

typedef struct {
    LARGE_INTEGER lastFrameTime;
    DXGI_RATIONAL currentCompositionRate;
    LARGE_INTEGER currentTime;
    LARGE_INTEGER timeFrequency;
    LARGE_INTEGER nextEstimatedFrameTime;
} DCOMPOSITION_FRAME_STATISTICS;

#endif
#endif /* _DCOMPTYPES_H_ */
