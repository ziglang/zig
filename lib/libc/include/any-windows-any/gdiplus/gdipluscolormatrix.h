/*
 * gdipluscolormatrix.h
 *
 * GDI+ color mappings
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Markus Koenig <markus@stber-koenig.de>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef __GDIPLUS_COLORMATRIX_H
#define __GDIPLUS_COLORMATRIX_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

typedef enum ColorAdjustType {
	ColorAdjustTypeDefault = 0,
	ColorAdjustTypeBitmap = 1,
	ColorAdjustTypeBrush = 2,
	ColorAdjustTypePen = 3,
	ColorAdjustTypeText = 4,
	ColorAdjustTypeCount = 5,
	ColorAdjustTypeAny = 6
} ColorAdjustType;

typedef enum ColorMatrixFlags {
	ColorMatrixFlagsDefault = 0,
	ColorMatrixFlagsSkipGrays = 1,
	ColorMatrixFlagsAltGray = 2
} ColorMatrixFlags;

typedef enum HistogramFormat {
	HistogramFormatARGB = 0,
	HistogramFormatPARGB = 1,
	HistogramFormatRGB = 2,
	HistogramFormatGray = 3,
	HistogramFormatB = 4,
	HistogramFormatG = 5,
	HistogramFormatR = 6,
	HistogramFormatA = 7
} HistogramFormat;

typedef struct ColorMap {
	Color oldColor;
	Color newColor;
} ColorMap;

typedef struct ColorMatrix {
	REAL m[5][5];
} ColorMatrix;

typedef BYTE ColorChannelLUT[256];

#endif /* __GDIPLUS_COLORMATRIX_H */
