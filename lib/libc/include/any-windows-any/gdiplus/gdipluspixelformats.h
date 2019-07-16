/*
 * gdipluspixelformats.h
 *
 * GDI+ pixel formats
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

#ifndef __GDIPLUS_PIXELFORMATS_H
#define __GDIPLUS_PIXELFORMATS_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

typedef DWORD ARGB;
typedef INT PixelFormat;

#define PixelFormatIndexed ((INT) 0x00010000)
#define PixelFormatGDI ((INT) 0x00020000)
#define PixelFormatAlpha ((INT) 0x00040000)
#define PixelFormatPAlpha ((INT) 0x00080000)
#define PixelFormatExtended ((INT) 0x00100000)
#define PixelFormatCanonical ((INT) 0x00200000)
#define PixelFormatUndefined ((INT) 0)
#define PixelFormatDontCare ((INT) 0)
#define PixelFormat1bppIndexed ((INT) \
	(1 | (1<<8) | PixelFormatIndexed | PixelFormatGDI))
#define PixelFormat4bppIndexed ((INT) \
	(2 | (4<<8) | PixelFormatIndexed | PixelFormatGDI))
#define PixelFormat8bppIndexed ((INT) \
	(3 | (8<<8) | PixelFormatIndexed | PixelFormatGDI))
#define PixelFormat16bppGrayScale ((INT) \
	(4 | (16<<8) | PixelFormatExtended))
#define PixelFormat16bppRGB555 ((INT) \
	(5 | (16<<8) | PixelFormatGDI))
#define PixelFormat16bppRGB565 ((INT) \
	(6 | (16<<8) | PixelFormatGDI))
#define PixelFormat16bppARGB1555 ((INT) \
	(7 | (16<<8) | PixelFormatAlpha | PixelFormatGDI))
#define PixelFormat24bppRGB ((INT) \
	(8 | (24<<8) | PixelFormatGDI))
#define PixelFormat32bppRGB ((INT) \
	(9 | (32<<8) | PixelFormatGDI))
#define PixelFormat32bppARGB ((INT) \
	(10 | (32<<8) | PixelFormatAlpha | PixelFormatGDI | PixelFormatCanonical))
#define PixelFormat32bppPARGB ((INT) \
	(11 | (32<<8) | PixelFormatAlpha | PixelFormatPAlpha | PixelFormatGDI))
#define PixelFormat48bppRGB ((INT) \
	(12 | (48<<8) | PixelFormatExtended))
#define PixelFormat64bppARGB ((INT) \
	(13 | (64<<8) | PixelFormatAlpha | PixelFormatCanonical | PixelFormatExtended))
#define PixelFormat64bppPARGB ((INT) \
	(14 | (64<<8) | PixelFormatAlpha | PixelFormatPAlpha | PixelFormatExtended))
#define PixelFormatMax ((INT) 15)

typedef enum PaletteFlags {
	PaletteFlagsHasAlpha = 1,
	PaletteFlagsGrayScale = 2,
	PaletteFlagsHalftone = 4
} PaletteFlags;

typedef enum PaletteType {
	PaletteTypeCustom = 0,
	PaletteTypeOptimal = 1,
	PaletteTypeFixedBW = 2,
	PaletteTypeFixedHalftone8 = 3,
	PaletteTypeFixedHalftone27 = 4,
	PaletteTypeFixedHalftone64 = 5,
	PaletteTypeFixedHalftone125 = 6,
	PaletteTypeFixedHalftone216 = 7,
	PaletteTypeFixedHalftone252 = 8,
	PaletteTypeFixedHalftone256 = 9 
} PaletteType;

typedef struct ColorPalette {
	UINT Flags;
	UINT Count;
	ARGB Entries[1];
} ColorPalette;

static __inline__ UINT GetPixelFormatSize(PixelFormat pixfmt)
{
	return (((UINT) pixfmt) & 0xff00U) >> 8;
}

static __inline__ BOOL IsAlphaPixelFormat(PixelFormat pixfmt)
{
	return (pixfmt & PixelFormatAlpha) != 0;
}

static __inline__ BOOL IsCanonicalPixelFormat(PixelFormat pixfmt)
{
	return (pixfmt & PixelFormatCanonical) != 0;
}

static __inline__ BOOL IsExtendedPixelFormat(PixelFormat pixfmt)
{
	return (pixfmt & PixelFormatExtended) != 0;
}

static __inline__ BOOL IsIndexedPixelFormat(PixelFormat pixfmt)
{
	return (pixfmt & PixelFormatIndexed) != 0;
}

#endif /* __GDIPLUS_PIXELFORMATS_H */
