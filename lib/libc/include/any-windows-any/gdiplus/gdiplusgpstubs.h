/*
 * gdiplusgpstubs.h
 *
 * GDI+ Gp* type declarations
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

#ifndef __GDIPLUS_GPSTUBS_H
#define __GDIPLUS_GPSTUBS_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

typedef Point GpPoint;
typedef PointF GpPointF;
typedef Rect GpRect;
typedef RectF GpRectF;
typedef Size GpSize;
typedef SizeF GpSizeF;

typedef enum BrushType GpBrushType;
typedef enum CombineMode GpCombineMode;
typedef enum CompositingMode GpCompositingMode;
typedef enum CompositingQuality GpCompositingQuality;
typedef enum CoordinateSpace GpCoordinateSpace;
typedef enum CustomLineCapType GpCustomLineCapType;
typedef enum DashCap GpDashCap;
typedef enum DashStyle GpDashStyle;
typedef enum DitherType GpDitherType;
typedef enum DriverStringOptions GpDriverStringOptions;
typedef enum EmfPlusRecordType GpEmfPlusRecordType;
typedef enum EmfToWmfBitsFlags GpEmfToWmfBitsFlags;
typedef enum EmfType GpEmfType;
typedef enum EncoderParameterValueType GpEncoderParameterValueType;
typedef enum EncoderValue GpEncoderValue;
typedef enum FillMode GpFillMode;
typedef enum FlushIntention GpFlushIntention;
typedef enum FontStyle GpFontStyle;
typedef enum HatchStyle GpHatchStyle;
typedef enum HotkeyPrefix GpHotkeyPrefix;
typedef enum ImageType GpImageType;
typedef enum InterpolationMode GpInterpolationMode;
typedef enum LinearGradientMode GpLinearGradientMode;
typedef enum LineCap GpLineCap;
typedef enum LineJoin GpLineJoin;
typedef enum MatrixOrder GpMatrixOrder;
typedef enum MetafileFrameUnit GpMetafileFrameUnit;
typedef enum MetafileType GpMetafileType;
typedef enum ObjectType GpObjectType;
typedef enum PathPointType GpPathPointType;
typedef enum PenAlignment GpPenAlignment;
typedef enum PenType GpPenType;
typedef enum PixelOffsetMode GpPixelOffsetMode;
typedef enum QualityMode GpQualityMode;
typedef enum SmoothingMode GpSmoothingMode;
typedef enum StringAlignment GpStringAlignment;
typedef enum StringDigitSubstitute GpStringDigitSubstitute;
typedef enum StringFormatFlags GpStringFormatFlags;
typedef enum StringTrimming GpStringTrimming;
typedef enum TextRenderingHint GpTextRenderingHint;
typedef enum Unit GpUnit;
typedef enum WarpMode GpWarpMode;
typedef enum WrapMode GpWrapMode;

#ifdef __cplusplus

class CGpEffect {}; 
class GpCustomLineCap {};
class GpImage {};

class GpAdjustableArrowCap: public GpCustomLineCap {};
class GpBitmap: public GpImage {};
class GpBrush {};
class GpCachedBitmap {};
class GpFont {};
class GpFontCollection {};
class GpFontFamily {};
class GpGraphics {};
class GpHatch: public GpBrush {};         /* HatchBrush */
class GpImageAttributes {};
class GpLineGradient: public GpBrush {};  /* LinearGradientBrush */
class GpMatrix {};
class GpMetafile: public GpImage {};
class GpPath {};                          /* GraphicsPath */
class GpPathData {};
class GpPathGradient: public GpBrush {};  /* PathGradientBrush */
class GpPathIterator {};                  /* GraphicsPathIterator */
class GpPen {};
class GpRegion {};
class GpSolidFill: public GpBrush {};     /* SolidBrush */
class GpStringFormat {};
class GpTexture: public GpBrush {};       /* TextureBrush */

#else /* !__cplusplus */

typedef void CGpEffect;
typedef void GpAdjustableArrowCap;
typedef void GpBitmap;
typedef void GpBrush;
typedef void GpCachedBitmap;
typedef void GpCustomLineCap;
typedef void GpFont;
typedef void GpFontFamily;
typedef void GpFontCollection;
typedef void GpGraphics;
typedef void GpHatch;
typedef void GpImage;
typedef void GpImageAttributes;
typedef void GpLineGradient;
typedef void GpMatrix;
typedef void GpMetafile;
typedef void GpPath;
typedef void GpPathData;
typedef void GpPathGradient;
typedef void GpPathIterator;
typedef void GpPen;
typedef void GpRegion;
typedef void GpSolidFill;
typedef void GpStringFormat;
typedef void GpTexture;

#endif /* !__cplusplus */

#endif /* __GDIPLUS_GPSTUBS_H */
