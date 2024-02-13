/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _D2D1_2HELPER_H_
#define _D2D1_2HELPER_H_

#if NTDDI_VERSION >= NTDDI_WINBLUE

#ifndef _D2D1_2_H_
#include <d2d1_2.h>
#endif

#ifndef D2D_USE_C_DEFINITIONS

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

namespace D2D1 {
  COM_DECLSPEC_NOTHROW D2D1FORCEINLINE FLOAT ComputeFlatteningTolerance(const D2D1_MATRIX_3X2_F &matrix, FLOAT dpi_x = 96.0f, FLOAT dpi_y = 96.0f, FLOAT max_zoom_factor = 1.0f) {
    D2D1_MATRIX_3X2_F transform = matrix * D2D1::Matrix3x2F::Scale(dpi_x / 96.0f, dpi_y / 96.0f);
    FLOAT abs_max_zoom_factor = (max_zoom_factor > 0) ? max_zoom_factor : -max_zoom_factor;
    return D2D1_DEFAULT_FLATTENING_TOLERANCE / (abs_max_zoom_factor * D2D1ComputeMaximumScaleFactor(&transform));
  }
}

#endif /* WINAPI_PARTITION_APP */

#endif /* D2D_USE_C_DEFINITIONS */

#endif /* NTDDI_VERSION >= NTDDI_WINBLUE */

#endif /* _D2D1_HELPER_H_ */
