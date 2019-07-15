/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_MAGNIFIER
#define _INC_MAGNIFIER

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#include <wincodec.h>

#define MW_FILTERMODE_EXCLUDE 0
#define MW_FILTERMODE_INCLUDE 1

typedef struct tagMAGTRANSFORM {
    float v[3][3];
} MAGTRANSFORM, *PMAGTRANSFORM;

typedef struct tagMAGIMAGEHEADER {
    UINT width;
    UINT height;
    WICPixelFormatGUID format;
    UINT stride;
    UINT offset;
    SIZE_T cbSize;
} MAGIMAGEHEADER, *PMAGIMAGEHEADER;

typedef struct tagMAGCOLOREFFECT {
    float transform[5][5];
} MAGCOLOREFFECT, *PMAGCOLOREFFECT;

#endif
#endif
