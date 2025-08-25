/*
 * gdiplusenums.h
 *
 * GDI+ enumerations
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

#ifndef __GDIPLUS_ENUMS_H
#define __GDIPLUS_ENUMS_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

typedef enum BrushType {
	BrushTypeSolidColor = 0,
	BrushTypeHatchFill = 1,
	BrushTypeTextureFill = 2,
	BrushTypePathGradient = 3,
	BrushTypeLinearGradient = 4
} BrushType;

typedef enum CombineMode {
	CombineModeReplace = 0,
	CombineModeIntersect = 1,
	CombineModeUnion = 2,
	CombineModeXor = 3,
	CombineModeExclude = 4,
	CombineModeComplement = 5
} CombineMode;

typedef enum CompositingMode {
	CompositingModeSourceOver = 0,
	CompositingModeSourceCopy = 1
} CompositingMode;

typedef enum CompositingQuality {
	CompositingQualityDefault = 0,
	CompositingQualityHighSpeed = 1,
	CompositingQualityHighQuality = 2,
	CompositingQualityGammaCorrected = 3,
	CompositingQualityAssumeLinear = 4
} CompositingQuality;

typedef enum CoordinateSpace {
	CoordinateSpaceWorld = 0,
	CoordinateSpacePage = 1,
	CoordinateSpaceDevice = 2
} CoordinateSpace;

typedef enum CustomLineCapType {
	CustomLineCapTypeDefault = 0,
	CustomLineCapTypeAdjustableArrow = 1
} CustomLineCapType;

typedef enum DashCap {
	DashCapFlat = 0,
	DashCapRound = 2,
	DashCapTriangle = 3
} DashCap;

typedef enum DashStyle {
	DashStyleSolid = 0,
	DashStyleDash = 1,
	DashStyleDot = 2,
	DashStyleDashDot = 3,
	DashStyleDashDotDot = 4,
	DashStyleCustom = 5
} DashStyle;

typedef enum DitherType {
	DitherTypeNone = 0,
	DitherTypeSolid = 1,
	DitherTypeOrdered4x4 = 2,
	DitherTypeOrdered8x8 = 3,
	DitherTypeOrdered16x16 = 4,
	DitherTypeOrdered91x91 = 5,
	DitherTypeSpiral4x4 = 6,
	DitherTypeSpiral8x8 = 7,
	DitherTypeDualSpiral4x4 = 8,
	DitherTypeDualSpiral8x8 = 9,
	DitherTypeErrorDiffusion = 10
} DitherType;

typedef enum DriverStringOptions {
	DriverStringOptionsCmapLookup = 1,
	DriverStringOptionsVertical = 2,
	DriverStringOptionsRealizedAdvance = 4,
	DriverStringOptionsLimitSubpixel = 8
} DriverStringOptions;

#define GDIP_WMF_RECORD_TO_EMFPLUS(meta) ((meta) | 0x10000)
#define GDIP_EMFPLUS_RECORD_BASE (0x4000)
typedef enum EmfPlusRecordType {
	WmfRecordTypeSetBkColor                    = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETBKCOLOR),
	WmfRecordTypeSetBkMode                     = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETBKMODE),
	WmfRecordTypeSetMapMode                    = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETMAPMODE),
	WmfRecordTypeSetROP2                       = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETROP2),
	WmfRecordTypeSetRelAbs                     = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETRELABS),
	WmfRecordTypeSetPolyFillMode               = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETPOLYFILLMODE),
	WmfRecordTypeSetStretchBltMode             = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETSTRETCHBLTMODE),
	WmfRecordTypeSetTextCharExtra              = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETTEXTCHAREXTRA),
	WmfRecordTypeSetTextColor                  = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETTEXTCOLOR),
	WmfRecordTypeSetTextJustification          = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETTEXTJUSTIFICATION),
	WmfRecordTypeSetWindowOrg                  = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETWINDOWORG),
	WmfRecordTypeSetWindowExt                  = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETWINDOWEXT),
	WmfRecordTypeSetViewportOrg                = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETVIEWPORTORG),
	WmfRecordTypeSetViewportExt                = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETVIEWPORTEXT),
	WmfRecordTypeOffsetWindowOrg               = GDIP_WMF_RECORD_TO_EMFPLUS(META_OFFSETWINDOWORG),
	WmfRecordTypeScaleWindowExt                = GDIP_WMF_RECORD_TO_EMFPLUS(META_SCALEWINDOWEXT),
	WmfRecordTypeOffsetViewportOrg             = GDIP_WMF_RECORD_TO_EMFPLUS(META_OFFSETVIEWPORTORG),
	WmfRecordTypeScaleViewportExt              = GDIP_WMF_RECORD_TO_EMFPLUS(META_SCALEVIEWPORTEXT),
	WmfRecordTypeLineTo                        = GDIP_WMF_RECORD_TO_EMFPLUS(META_LINETO),
	WmfRecordTypeMoveTo                        = GDIP_WMF_RECORD_TO_EMFPLUS(META_MOVETO),
	WmfRecordTypeExcludeClipRect               = GDIP_WMF_RECORD_TO_EMFPLUS(META_EXCLUDECLIPRECT),
	WmfRecordTypeIntersectClipRect             = GDIP_WMF_RECORD_TO_EMFPLUS(META_INTERSECTCLIPRECT),
	WmfRecordTypeArc                           = GDIP_WMF_RECORD_TO_EMFPLUS(META_ARC),
	WmfRecordTypeEllipse                       = GDIP_WMF_RECORD_TO_EMFPLUS(META_ELLIPSE),
	WmfRecordTypeFloodFill                     = GDIP_WMF_RECORD_TO_EMFPLUS(META_FLOODFILL),
	WmfRecordTypePie                           = GDIP_WMF_RECORD_TO_EMFPLUS(META_PIE),
	WmfRecordTypeRectangle                     = GDIP_WMF_RECORD_TO_EMFPLUS(META_RECTANGLE),
	WmfRecordTypeRoundRect                     = GDIP_WMF_RECORD_TO_EMFPLUS(META_ROUNDRECT),
	WmfRecordTypePatBlt                        = GDIP_WMF_RECORD_TO_EMFPLUS(META_PATBLT),
	WmfRecordTypeSaveDC                        = GDIP_WMF_RECORD_TO_EMFPLUS(META_SAVEDC),
	WmfRecordTypeSetPixel                      = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETPIXEL),
	WmfRecordTypeOffsetClipRgn                 = GDIP_WMF_RECORD_TO_EMFPLUS(META_OFFSETCLIPRGN),
	WmfRecordTypeTextOut                       = GDIP_WMF_RECORD_TO_EMFPLUS(META_TEXTOUT),
	WmfRecordTypeBitBlt                        = GDIP_WMF_RECORD_TO_EMFPLUS(META_BITBLT),
	WmfRecordTypeStretchBlt                    = GDIP_WMF_RECORD_TO_EMFPLUS(META_STRETCHBLT),
	WmfRecordTypePolygon                       = GDIP_WMF_RECORD_TO_EMFPLUS(META_POLYGON),
	WmfRecordTypePolyline                      = GDIP_WMF_RECORD_TO_EMFPLUS(META_POLYLINE),
	WmfRecordTypeEscape                        = GDIP_WMF_RECORD_TO_EMFPLUS(META_ESCAPE),
	WmfRecordTypeRestoreDC                     = GDIP_WMF_RECORD_TO_EMFPLUS(META_RESTOREDC),
	WmfRecordTypeFillRegion                    = GDIP_WMF_RECORD_TO_EMFPLUS(META_FILLREGION),
	WmfRecordTypeFrameRegion                   = GDIP_WMF_RECORD_TO_EMFPLUS(META_FRAMEREGION),
	WmfRecordTypeInvertRegion                  = GDIP_WMF_RECORD_TO_EMFPLUS(META_INVERTREGION),
	WmfRecordTypePaintRegion                   = GDIP_WMF_RECORD_TO_EMFPLUS(META_PAINTREGION),
	WmfRecordTypeSelectClipRegion              = GDIP_WMF_RECORD_TO_EMFPLUS(META_SELECTCLIPREGION),
	WmfRecordTypeSelectObject                  = GDIP_WMF_RECORD_TO_EMFPLUS(META_SELECTOBJECT),
	WmfRecordTypeSetTextAlign                  = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETTEXTALIGN),
	WmfRecordTypeDrawText                      = GDIP_WMF_RECORD_TO_EMFPLUS(0x062F),
	WmfRecordTypeChord                         = GDIP_WMF_RECORD_TO_EMFPLUS(META_CHORD),
	WmfRecordTypeSetMapperFlags                = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETMAPPERFLAGS),
	WmfRecordTypeExtTextOut                    = GDIP_WMF_RECORD_TO_EMFPLUS(META_EXTTEXTOUT),
	WmfRecordTypeSetDIBToDev                   = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETDIBTODEV),
	WmfRecordTypeSelectPalette                 = GDIP_WMF_RECORD_TO_EMFPLUS(META_SELECTPALETTE),
	WmfRecordTypeRealizePalette                = GDIP_WMF_RECORD_TO_EMFPLUS(META_REALIZEPALETTE),
	WmfRecordTypeAnimatePalette                = GDIP_WMF_RECORD_TO_EMFPLUS(META_ANIMATEPALETTE),
	WmfRecordTypeSetPalEntries                 = GDIP_WMF_RECORD_TO_EMFPLUS(META_SETPALENTRIES),
	WmfRecordTypePolyPolygon                   = GDIP_WMF_RECORD_TO_EMFPLUS(META_POLYPOLYGON),
	WmfRecordTypeResizePalette                 = GDIP_WMF_RECORD_TO_EMFPLUS(META_RESIZEPALETTE),
	WmfRecordTypeDIBBitBlt                     = GDIP_WMF_RECORD_TO_EMFPLUS(META_DIBBITBLT),
	WmfRecordTypeDIBStretchBlt                 = GDIP_WMF_RECORD_TO_EMFPLUS(META_DIBSTRETCHBLT),
	WmfRecordTypeDIBCreatePatternBrush         = GDIP_WMF_RECORD_TO_EMFPLUS(META_DIBCREATEPATTERNBRUSH),
	WmfRecordTypeStretchDIB                    = GDIP_WMF_RECORD_TO_EMFPLUS(META_STRETCHDIB),
	WmfRecordTypeExtFloodFill                  = GDIP_WMF_RECORD_TO_EMFPLUS(META_EXTFLOODFILL),
	WmfRecordTypeSetLayout                     = GDIP_WMF_RECORD_TO_EMFPLUS(0x0149),
	WmfRecordTypeResetDC                       = GDIP_WMF_RECORD_TO_EMFPLUS(0x014C),
	WmfRecordTypeStartDoc                      = GDIP_WMF_RECORD_TO_EMFPLUS(0x014D),
	WmfRecordTypeStartPage                     = GDIP_WMF_RECORD_TO_EMFPLUS(0x004F),
	WmfRecordTypeEndPage                       = GDIP_WMF_RECORD_TO_EMFPLUS(0x0050),
	WmfRecordTypeAbortDoc                      = GDIP_WMF_RECORD_TO_EMFPLUS(0x0052),
	WmfRecordTypeEndDoc                        = GDIP_WMF_RECORD_TO_EMFPLUS(0x005E),
	WmfRecordTypeDeleteObject                  = GDIP_WMF_RECORD_TO_EMFPLUS(META_DELETEOBJECT),
	WmfRecordTypeCreatePalette                 = GDIP_WMF_RECORD_TO_EMFPLUS(META_CREATEPALETTE),
	WmfRecordTypeCreateBrush                   = GDIP_WMF_RECORD_TO_EMFPLUS(0x00F8),
	WmfRecordTypeCreatePatternBrush            = GDIP_WMF_RECORD_TO_EMFPLUS(META_CREATEPATTERNBRUSH),
	WmfRecordTypeCreatePenIndirect             = GDIP_WMF_RECORD_TO_EMFPLUS(META_CREATEPENINDIRECT),
	WmfRecordTypeCreateFontIndirect            = GDIP_WMF_RECORD_TO_EMFPLUS(META_CREATEFONTINDIRECT),
	WmfRecordTypeCreateBrushIndirect           = GDIP_WMF_RECORD_TO_EMFPLUS(META_CREATEBRUSHINDIRECT),
	WmfRecordTypeCreateBitmapIndirect          = GDIP_WMF_RECORD_TO_EMFPLUS(0x02FD),
	WmfRecordTypeCreateBitmap                  = GDIP_WMF_RECORD_TO_EMFPLUS(0x06FE),
	WmfRecordTypeCreateRegion                  = GDIP_WMF_RECORD_TO_EMFPLUS(META_CREATEREGION),
	EmfRecordTypeHeader                        = EMR_HEADER,
	EmfRecordTypePolyBezier                    = EMR_POLYBEZIER,
	EmfRecordTypePolygon                       = EMR_POLYGON,
	EmfRecordTypePolyline                      = EMR_POLYLINE,
	EmfRecordTypePolyBezierTo                  = EMR_POLYBEZIERTO,
	EmfRecordTypePolyLineTo                    = EMR_POLYLINETO,
	EmfRecordTypePolyPolyline                  = EMR_POLYPOLYLINE,
	EmfRecordTypePolyPolygon                   = EMR_POLYPOLYGON,
	EmfRecordTypeSetWindowExtEx                = EMR_SETWINDOWEXTEX,
	EmfRecordTypeSetWindowOrgEx                = EMR_SETWINDOWORGEX,
	EmfRecordTypeSetViewportExtEx              = EMR_SETVIEWPORTEXTEX,
	EmfRecordTypeSetViewportOrgEx              = EMR_SETVIEWPORTORGEX,
	EmfRecordTypeSetBrushOrgEx                 = EMR_SETBRUSHORGEX,
	EmfRecordTypeEOF                           = EMR_EOF,
	EmfRecordTypeSetPixelV                     = EMR_SETPIXELV,
	EmfRecordTypeSetMapperFlags                = EMR_SETMAPPERFLAGS,
	EmfRecordTypeSetMapMode                    = EMR_SETMAPMODE,
	EmfRecordTypeSetBkMode                     = EMR_SETBKMODE,
	EmfRecordTypeSetPolyFillMode               = EMR_SETPOLYFILLMODE,
	EmfRecordTypeSetROP2                       = EMR_SETROP2,
	EmfRecordTypeSetStretchBltMode             = EMR_SETSTRETCHBLTMODE,
	EmfRecordTypeSetTextAlign                  = EMR_SETTEXTALIGN,
	EmfRecordTypeSetColorAdjustment            = EMR_SETCOLORADJUSTMENT,
	EmfRecordTypeSetTextColor                  = EMR_SETTEXTCOLOR,
	EmfRecordTypeSetBkColor                    = EMR_SETBKCOLOR,
	EmfRecordTypeOffsetClipRgn                 = EMR_OFFSETCLIPRGN,
	EmfRecordTypeMoveToEx                      = EMR_MOVETOEX,
	EmfRecordTypeSetMetaRgn                    = EMR_SETMETARGN,
	EmfRecordTypeExcludeClipRect               = EMR_EXCLUDECLIPRECT,
	EmfRecordTypeIntersectClipRect             = EMR_INTERSECTCLIPRECT,
	EmfRecordTypeScaleViewportExtEx            = EMR_SCALEVIEWPORTEXTEX,
	EmfRecordTypeScaleWindowExtEx              = EMR_SCALEWINDOWEXTEX,
	EmfRecordTypeSaveDC                        = EMR_SAVEDC,
	EmfRecordTypeRestoreDC                     = EMR_RESTOREDC,
	EmfRecordTypeSetWorldTransform             = EMR_SETWORLDTRANSFORM,
	EmfRecordTypeModifyWorldTransform          = EMR_MODIFYWORLDTRANSFORM,
	EmfRecordTypeSelectObject                  = EMR_SELECTOBJECT,
	EmfRecordTypeCreatePen                     = EMR_CREATEPEN,
	EmfRecordTypeCreateBrushIndirect           = EMR_CREATEBRUSHINDIRECT,
	EmfRecordTypeDeleteObject                  = EMR_DELETEOBJECT,
	EmfRecordTypeAngleArc                      = EMR_ANGLEARC,
	EmfRecordTypeEllipse                       = EMR_ELLIPSE,
	EmfRecordTypeRectangle                     = EMR_RECTANGLE,
	EmfRecordTypeRoundRect                     = EMR_ROUNDRECT,
	EmfRecordTypeArc                           = EMR_ARC,
	EmfRecordTypeChord                         = EMR_CHORD,
	EmfRecordTypePie                           = EMR_PIE,
	EmfRecordTypeSelectPalette                 = EMR_SELECTPALETTE,
	EmfRecordTypeCreatePalette                 = EMR_CREATEPALETTE,
	EmfRecordTypeSetPaletteEntries             = EMR_SETPALETTEENTRIES,
	EmfRecordTypeResizePalette                 = EMR_RESIZEPALETTE,
	EmfRecordTypeRealizePalette                = EMR_REALIZEPALETTE,
	EmfRecordTypeExtFloodFill                  = EMR_EXTFLOODFILL,
	EmfRecordTypeLineTo                        = EMR_LINETO,
	EmfRecordTypeArcTo                         = EMR_ARCTO,
	EmfRecordTypePolyDraw                      = EMR_POLYDRAW,
	EmfRecordTypeSetArcDirection               = EMR_SETARCDIRECTION,
	EmfRecordTypeSetMiterLimit                 = EMR_SETMITERLIMIT,
	EmfRecordTypeBeginPath                     = EMR_BEGINPATH,
	EmfRecordTypeEndPath                       = EMR_ENDPATH,
	EmfRecordTypeCloseFigure                   = EMR_CLOSEFIGURE,
	EmfRecordTypeFillPath                      = EMR_FILLPATH,
	EmfRecordTypeStrokeAndFillPath             = EMR_STROKEANDFILLPATH,
	EmfRecordTypeStrokePath                    = EMR_STROKEPATH,
	EmfRecordTypeFlattenPath                   = EMR_FLATTENPATH,
	EmfRecordTypeWidenPath                     = EMR_WIDENPATH,
	EmfRecordTypeSelectClipPath                = EMR_SELECTCLIPPATH,
	EmfRecordTypeAbortPath                     = EMR_ABORTPATH,
	EmfRecordTypeReserved_069                  = 69,
	EmfRecordTypeGdiComment                    = EMR_GDICOMMENT,
	EmfRecordTypeFillRgn                       = EMR_FILLRGN,
	EmfRecordTypeFrameRgn                      = EMR_FRAMERGN,
	EmfRecordTypeInvertRgn                     = EMR_INVERTRGN,
	EmfRecordTypePaintRgn                      = EMR_PAINTRGN,
	EmfRecordTypeExtSelectClipRgn              = EMR_EXTSELECTCLIPRGN,
	EmfRecordTypeBitBlt                        = EMR_BITBLT,
	EmfRecordTypeStretchBlt                    = EMR_STRETCHBLT,
	EmfRecordTypeMaskBlt                       = EMR_MASKBLT,
	EmfRecordTypePlgBlt                        = EMR_PLGBLT,
	EmfRecordTypeSetDIBitsToDevice             = EMR_SETDIBITSTODEVICE,
	EmfRecordTypeStretchDIBits                 = EMR_STRETCHDIBITS,
	EmfRecordTypeExtCreateFontIndirect         = EMR_EXTCREATEFONTINDIRECTW,
	EmfRecordTypeExtTextOutA                   = EMR_EXTTEXTOUTA,
	EmfRecordTypeExtTextOutW                   = EMR_EXTTEXTOUTW,
	EmfRecordTypePolyBezier16                  = EMR_POLYBEZIER16,
	EmfRecordTypePolygon16                     = EMR_POLYGON16,
	EmfRecordTypePolyline16                    = EMR_POLYLINE16,
	EmfRecordTypePolyBezierTo16                = EMR_POLYBEZIERTO16,
	EmfRecordTypePolylineTo16                  = EMR_POLYLINETO16,
	EmfRecordTypePolyPolyline16                = EMR_POLYPOLYLINE16,
	EmfRecordTypePolyPolygon16                 = EMR_POLYPOLYGON16,
	EmfRecordTypePolyDraw16                    = EMR_POLYDRAW16,
	EmfRecordTypeCreateMonoBrush               = EMR_CREATEMONOBRUSH,
	EmfRecordTypeCreateDIBPatternBrushPt       = EMR_CREATEDIBPATTERNBRUSHPT,
	EmfRecordTypeExtCreatePen                  = EMR_EXTCREATEPEN,
	EmfRecordTypePolyTextOutA                  = EMR_POLYTEXTOUTA,
	EmfRecordTypePolyTextOutW                  = EMR_POLYTEXTOUTW,
	EmfRecordTypeSetICMMode                    = 98,
	EmfRecordTypeCreateColorSpace              = 99,
	EmfRecordTypeSetColorSpace                 = 100,
	EmfRecordTypeDeleteColorSpace              = 101,
	EmfRecordTypeGLSRecord                     = 102,
	EmfRecordTypeGLSBoundedRecord              = 103,
	EmfRecordTypePixelFormat                   = 104,
	EmfRecordTypeDrawEscape                    = 105,
	EmfRecordTypeExtEscape                     = 106,
	EmfRecordTypeStartDoc                      = 107,
	EmfRecordTypeSmallTextOut                  = 108,
	EmfRecordTypeForceUFIMapping               = 109,
	EmfRecordTypeNamedEscape                   = 110,
	EmfRecordTypeColorCorrectPalette           = 111,
	EmfRecordTypeSetICMProfileA                = 112,
	EmfRecordTypeSetICMProfileW                = 113,
	EmfRecordTypeAlphaBlend                    = 114,
	EmfRecordTypeSetLayout                     = 115,
	EmfRecordTypeTransparentBlt                = 116,
	EmfRecordTypeReserved_117                  = 117,
	EmfRecordTypeGradientFill                  = 118,
	EmfRecordTypeSetLinkedUFIs                 = 119,
	EmfRecordTypeSetTextJustification          = 120,
	EmfRecordTypeColorMatchToTargetW           = 121,
	EmfRecordTypeCreateColorSpaceW             = 122,
	EmfRecordTypeMax                           = 122,
	EmfRecordTypeMin                           = 1,
	EmfPlusRecordTypeInvalid                   = GDIP_EMFPLUS_RECORD_BASE,
	EmfPlusRecordTypeHeader,
	EmfPlusRecordTypeEndOfFile,
	EmfPlusRecordTypeComment,
	EmfPlusRecordTypeGetDC,
	EmfPlusRecordTypeMultiFormatStart,
	EmfPlusRecordTypeMultiFormatSection,
	EmfPlusRecordTypeMultiFormatEnd,
	EmfPlusRecordTypeObject,
	EmfPlusRecordTypeClear,
	EmfPlusRecordTypeFillRects,
	EmfPlusRecordTypeDrawRects,
	EmfPlusRecordTypeFillPolygon,
	EmfPlusRecordTypeDrawLines,
	EmfPlusRecordTypeFillEllipse,
	EmfPlusRecordTypeDrawEllipse,
	EmfPlusRecordTypeFillPie,
	EmfPlusRecordTypeDrawPie,
	EmfPlusRecordTypeDrawArc,
	EmfPlusRecordTypeFillRegion,
	EmfPlusRecordTypeFillPath,
	EmfPlusRecordTypeDrawPath,
	EmfPlusRecordTypeFillClosedCurve,
	EmfPlusRecordTypeDrawClosedCurve,
	EmfPlusRecordTypeDrawCurve,
	EmfPlusRecordTypeDrawBeziers,
	EmfPlusRecordTypeDrawImage,
	EmfPlusRecordTypeDrawImagePoints,
	EmfPlusRecordTypeDrawString,
	EmfPlusRecordTypeSetRenderingOrigin,
	EmfPlusRecordTypeSetAntiAliasMode,
	EmfPlusRecordTypeSetTextRenderingHint,
	EmfPlusRecordTypeSetTextContrast,
	EmfPlusRecordTypeSetGammaValue,
	EmfPlusRecordTypeSetInterpolationMode,
	EmfPlusRecordTypeSetPixelOffsetMode,
	EmfPlusRecordTypeSetCompositingMode,
	EmfPlusRecordTypeSetCompositingQuality,
	EmfPlusRecordTypeSave,
	EmfPlusRecordTypeRestore,
	EmfPlusRecordTypeBeginContainer,
	EmfPlusRecordTypeBeginContainerNoParams,
	EmfPlusRecordTypeEndContainer,
	EmfPlusRecordTypeSetWorldTransform,
	EmfPlusRecordTypeResetWorldTransform,
	EmfPlusRecordTypeMultiplyWorldTransform,
	EmfPlusRecordTypeTranslateWorldTransform,
	EmfPlusRecordTypeScaleWorldTransform,
	EmfPlusRecordTypeRotateWorldTransform,
	EmfPlusRecordTypeSetPageTransform,
	EmfPlusRecordTypeResetClip,
	EmfPlusRecordTypeSetClipRect,
	EmfPlusRecordTypeSetClipPath,
	EmfPlusRecordTypeSetClipRegion,
	EmfPlusRecordTypeOffsetClip,
	EmfPlusRecordTypeDrawDriverString,
	EmfPlusRecordTypeStrokeFillPath,
	EmfPlusRecordTypeSerializableObject,
	EmfPlusRecordTypeSetTSGraphics,
	EmfPlusRecordTypeSetTSClip,
	EmfPlusRecordTotal,
	EmfPlusRecordTypeMax = EmfPlusRecordTotal-1,
	EmfPlusRecordTypeMin = EmfPlusRecordTypeHeader
} EmfPlusRecordType;

typedef enum EmfToWmfBitsFlags {
	EmfToWmfBitsFlagsDefault = 0,
	EmfToWmfBitsFlagsEmbedEmf = 1,
	EmfToWmfBitsFlagsIncludePlaceable = 2,
	EmfToWmfBitsFlagsNoXORClip = 4
} EmfToWmfBitsFlags;

typedef enum EmfType {
	EmfTypeEmfOnly = 3,
	EmfTypeEmfPlusOnly = 4,
	EmfTypeEmfPlusDual = 5
} EmfType;

typedef enum EncoderParameterValueType {
	EncoderParameterValueTypeByte = 1,
	EncoderParameterValueTypeASCII = 2,
	EncoderParameterValueTypeShort = 3,
	EncoderParameterValueTypeLong = 4,
	EncoderParameterValueTypeRational = 5,
	EncoderParameterValueTypeLongRange = 6,
	EncoderParameterValueTypeUndefined = 7,
	EncoderParameterValueTypeRationalRange = 8,
	EncoderParameterValueTypePointer = 9
} EncoderParameterValueType;

typedef enum EncoderValue {
	EncoderValueColorTypeCMYK = 0,
	EncoderValueColorTypeYCCK = 1,
	EncoderValueCompressionLZW = 2,
	EncoderValueCompressionCCITT3 = 3,
	EncoderValueCompressionCCITT4 = 4,
	EncoderValueCompressionRle = 5,
	EncoderValueCompressionNone = 6,
	EncoderValueScanMethodInterlaced = 7,
	EncoderValueScanMethodNonInterlaced = 8,
	EncoderValueVersionGif87 = 9,
	EncoderValueVersionGif89 = 10,
	EncoderValueRenderProgressive = 11,
	EncoderValueRenderNonProgressive = 12,
	EncoderValueTransformRotate90 = 13,
	EncoderValueTransformRotate180 = 14,
	EncoderValueTransformRotate270 = 15,
	EncoderValueTransformFlipHorizontal = 16,
	EncoderValueTransformFlipVertical = 17,
	EncoderValueMultiFrame = 18,
	EncoderValueLastFrame = 19,
	EncoderValueFlush = 20,
	EncoderValueFrameDimensionTime = 21,
	EncoderValueFrameDimensionResolution = 22,
	EncoderValueFrameDimensionPage = 23
} EncoderValue;

typedef enum FillMode {
	FillModeAlternate = 0,
	FillModeWinding = 1
} FillMode;

typedef enum FlushIntention {
	FlushIntentionFlush = 0,
	FlushIntentionSync = 1
} FlushIntention;

typedef enum FontStyle {
	FontStyleRegular = 0,
	FontStyleBold = 1,
	FontStyleItalic = 2,
	FontStyleBoldItalic = 3,
	FontStyleUnderline = 4,
	FontStyleStrikeout = 8
} FontStyle;

typedef enum HatchStyle {
	HatchStyleHorizontal = 0,
	HatchStyleVertical = 1,
	HatchStyleForwardDiagonal = 2,
	HatchStyleBackwardDiagonal = 3,
	HatchStyleCross = 4,
	HatchStyleLargeGrid = 4,
	HatchStyleDiagonalCross = 5,
	HatchStyle05Percent = 6,
	HatchStyle10Percent = 7,
	HatchStyle20Percent = 8,
	HatchStyle25Percent = 9,
	HatchStyle30Percent = 10,
	HatchStyle40Percent = 11,
	HatchStyle50Percent = 12,
	HatchStyle60Percent = 13,
	HatchStyle70Percent = 14,
	HatchStyle75Percent = 15,
	HatchStyle80Percent = 16,
	HatchStyle90Percent = 17,
	HatchStyleLightDownwardDiagonal = 18,
	HatchStyleLightUpwardDiagonal = 19,
	HatchStyleDarkDownwardDiagonal = 20,
	HatchStyleDarkUpwardDiagonal = 21,
	HatchStyleWideDownwardDiagonal = 22,
	HatchStyleWideUpwardDiagonal = 23,
	HatchStyleLightVertical = 24,
	HatchStyleLightHorizontal = 25,
	HatchStyleNarrowVertical = 26,
	HatchStyleNarrowHorizontal = 27,
	HatchStyleDarkVertical = 28,
	HatchStyleDarkHorizontal = 29,
	HatchStyleDashedDownwardDiagonal = 30,
	HatchStyleDashedUpwardDiagonal = 31,
	HatchStyleDashedHorizontal = 32,
	HatchStyleDashedVertical = 33,
	HatchStyleSmallConfetti = 34,
	HatchStyleLargeConfetti = 35,
	HatchStyleZigZag = 36,
	HatchStyleWave = 37,
	HatchStyleDiagonalBrick = 38,
	HatchStyleHorizontalBrick = 39,
	HatchStyleWeave = 40,
	HatchStylePlaid = 41,
	HatchStyleDivot = 42,
	HatchStyleDottedGrid = 43,
	HatchStyleDottedDiamond = 44,
	HatchStyleShingle = 45,
	HatchStyleTrellis = 46,
	HatchStyleSphere = 47,
	HatchStyleSmallGrid = 48,
	HatchStyleSmallCheckerBoard = 49,
	HatchStyleLargeCheckerBoard = 50,
	HatchStyleOutlinedDiamond = 51,
	HatchStyleSolidDiamond = 52,
	HatchStyleTotal = 53,
	HatchStyleMin = HatchStyleHorizontal,
	HatchStyleMax = HatchStyleTotal - 1
} HatchStyle;

typedef enum HotkeyPrefix {
	HotkeyPrefixNone = 0,
	HotkeyPrefixShow = 1,
	HotkeyPrefixHide = 2
} HotkeyPrefix;

typedef enum ImageType {
	ImageTypeUnknown = 0,
	ImageTypeBitmap = 1,
	ImageTypeMetafile = 2
} ImageType;

/* TODO: InterpolationMode */
typedef enum InterpolationMode {
	InterpolationModeInvalid = -1,
	InterpolationModeDefault = 0,
	InterpolationModeLowQuality = 1,
	InterpolationModeHighQuality = 2,
	InterpolationModeBilinear = 3,
	InterpolationModeBicubic = 4,
	InterpolationModeNearestNeighbor = 5,
	InterpolationModeHighQualityBilinear = 6,
	InterpolationModeHighQualityBicubic = 7
} InterpolationMode;

typedef enum LinearGradientMode {
	LinearGradientModeHorizontal = 0,
	LinearGradientModeVertical = 1,
	LinearGradientModeForwardDiagonal = 2,
	LinearGradientModeBackwardDiagonal = 3 
} LinearGradientMode;

typedef enum LineCap {
	LineCapFlat = 0,
	LineCapSquare = 1,
	LineCapRound = 2,
	LineCapTriangle = 3,
	LineCapNoAnchor = 16,
	LineCapSquareAnchor = 17,
	LineCapRoundAnchor = 18,
	LineCapDiamondAnchor = 19,
	LineCapArrowAnchor = 20,
	LineCapCustom = 255
} LineCap;

typedef enum LineJoin {
	LineJoinMiter = 0,
	LineJoinBevel = 1,
	LineJoinRound = 2,
	LineJoinMiterClipped = 3
} LineJoin;

typedef enum MatrixOrder {
	MatrixOrderPrepend = 0,
	MatrixOrderAppend = 1
} MatrixOrder;

typedef enum MetafileFrameUnit {
	MetafileFrameUnitPixel = 2,
	MetafileFrameUnitPoint = 3,
	MetafileFrameUnitInch = 4,
	MetafileFrameUnitDocument = 5,
	MetafileFrameUnitMillimeter = 6,
	MetafileFrameUnitGdi = 7
} MetafileFrameUnit;

typedef enum MetafileType {
	MetafileTypeInvalid = 0,
	MetafileTypeWmf = 1,
	MetafileTypeWmfPlaceable = 2,
	MetafileTypeEmf = 3,
	MetafileTypeEmfPlusOnly = 4,
	MetafileTypeEmfPlusDual = 5
} MetafileType;

typedef enum ObjectType {
	ObjectTypeInvalid = 0,
	ObjectTypeBrush = 1,
	ObjectTypePen = 2,
	ObjectTypePath = 3,
	ObjectTypeRegion = 4,
	ObjectTypeFont = 5,
	ObjectTypeStringFormat = 6,
	ObjectTypeImageAttributes = 7,
	ObjectTypeCustomLineCap = 8,
	ObjectTypeGraphics = 9,
	ObjectTypeMin = ObjectTypeBrush,
	ObjectTypeMax = ObjectTypeGraphics
} ObjectType;

typedef enum PathPointType {
	PathPointTypeStart = 0x00,
	PathPointTypeLine = 0x01,
	PathPointTypeBezier = 0x03,
	PathPointTypeBezier3 = 0x03,
	PathPointTypePathTypeMask = 0x07,
	PathPointTypePathDashMode = 0x10,
	PathPointTypePathMarker = 0x20,
	PathPointTypeCloseSubpath = 0x80
} PathPointType;

typedef enum PenAlignment {
	PenAlignmentCenter = 0,
	PenAlignmentInset = 1
} PenAlignment;

typedef enum PenType {
	PenTypeUnknown = -1, 
	PenTypeSolidColor = 0,
	PenTypeHatchFill = 1,
	PenTypeTextureFill = 2,
	PenTypePathGradient = 3,
	PenTypeLinearGradient = 4
} PenType;

/* TODO: PixelOffsetMode */
typedef enum PixelOffsetMode {
	PixelOffsetModeInvalid = -1,
	PixelOffsetModeDefault = 0,
	PixelOffsetModeHighSpeed = 1,
	PixelOffsetModeHighQuality = 2,
	PixelOffsetModeNone = 3,
	PixelOffsetModeHalf = 4
} PixelOffsetMode;

/* TODO: QualityMode */
typedef enum QualityMode {
	QualityModeInvalid = -1,
	QualityModeDefault = 0,
	QualityModeLow = 1,
	QualityModeHigh = 2
} QualityMode;

/* TODO: SmoothingMode */
typedef enum SmoothingMode {
	SmoothingModeInvalid = QualityModeInvalid,
	SmoothingModeDefault = 0,
	SmoothingModeHighSpeed = 1,
	SmoothingModeHighQuality = 2,
	SmoothingModeNone = 3,
	SmoothingModeAntiAlias8x4 = 4,
	SmoothingModeAntiAlias = 4,
	SmoothingModeAntiAlias8x8 = 5
} SmoothingMode;

typedef enum StringAlignment {
	StringAlignmentNear = 0,
	StringAlignmentCenter = 1,
	StringAlignmentFar = 2
} StringAlignment;

typedef enum StringDigitSubstitute {
	StringDigitSubstituteUser = 0,
	StringDigitSubstituteNone = 1,
	StringDigitSubstituteNational = 2,
	StringDigitSubstituteTraditional = 3
} StringDigitSubstitute;

typedef enum StringFormatFlags {
	StringFormatFlagsDirectionRightToLeft = 0x00000001,
	StringFormatFlagsDirectionVertical = 0x00000002,
	StringFormatFlagsNoFitBlackBox = 0x00000004,
	StringFormatFlagsDisplayFormatControl = 0x00000020,
	StringFormatFlagsNoFontFallback = 0x00000400,
	StringFormatFlagsMeasureTrailingSpaces = 0x00000800,
	StringFormatFlagsNoWrap = 0x00001000,
	StringFormatFlagsLineLimit = 0x00002000,
	StringFormatFlagsNoClip = 0x00004000
} StringFormatFlags;

typedef enum StringTrimming {
	StringTrimmingNone = 0,
	StringTrimmingCharacter = 1,
	StringTrimmingWord = 2,
	StringTrimmingEllipsisCharacter = 3,
	StringTrimmingEllipsisWord = 4,
	StringTrimmingEllipsisPath = 5
} StringTrimming;

typedef enum TextRenderingHint {
	TextRenderingHintSystemDefault = 0,
	TextRenderingHintSingleBitPerPixelGridFit = 1,
	TextRenderingHintSingleBitPerPixel = 2,
	TextRenderingHintAntiAliasGridFit = 3,
	TextRenderingHintAntiAlias = 4,
	TextRenderingHintClearTypeGridFit = 5
} TextRenderingHint;

typedef enum Unit {
	UnitWorld = 0,
	UnitDisplay = 1,
	UnitPixel = 2,
	UnitPoint = 3,
	UnitInch = 4,
	UnitDocument = 5,
	UnitMillimeter = 6
} Unit;

typedef enum WarpMode {
	WarpModePerspective = 0,
	WarpModeBilinear = 1
} WarpMode;

typedef enum WrapMode {
	WrapModeTile = 0,
	WrapModeTileFlipX = 1,
	WrapModeTileFlipY = 2,
	WrapModeTileFlipXY = 3,
	WrapModeClamp = 4
} WrapMode;

typedef enum GpTestControlEnum {
	TestControlForceBilinear = 0,
	TestControlForceNoICM = 1,
	TestControlGetBuildNumber = 2
} GpTestControlEnum;

/* Opaque handles to information blocks on an internal GDI+ stack. */
typedef DWORD GraphicsContainer;
typedef DWORD GraphicsState;

/* Default flatness for GraphicsPath methods Flatten, Outline, Warp, Widen */
/* FIXME: Is FlatnessDefault = 0.25f correct? */
#ifdef __cplusplus
const REAL FlatnessDefault = 0.25f;
#else
#define FlatnessDefault ((REAL) 0.25f)
#endif

static __inline__ BOOL ObjectTypeIsValid(ObjectType type)
{
	switch (type) {
		case ObjectTypeBrush:
		case ObjectTypePen:
		case ObjectTypePath:
		case ObjectTypeRegion:
		case ObjectTypeFont:
		case ObjectTypeStringFormat:
		case ObjectTypeImageAttributes:
		case ObjectTypeCustomLineCap:
		case ObjectTypeGraphics:
			return TRUE;
		default:
			return FALSE;
	}
}

#endif /* __GDIPLUS_ENUMS_H */
