/*
 * gdiplusimagecodec.h
 *
 * GDI+ image decoders and encoders
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

#ifndef __GDIPLUS_IMAGECODEC_H
#define __GDIPLUS_IMAGECODEC_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

static __inline__ GpStatus GetImageDecoders(UINT numDecoders, UINT size,
		ImageCodecInfo *decoders)
{
	#ifdef __cplusplus
	return DllExports::GdipGetImageDecoders(numDecoders, size, decoders);
	#else
	return GdipGetImageDecoders(numDecoders, size, decoders);
	#endif
}

static __inline__ GpStatus GetImageDecodersSize(UINT *numDecoders, UINT *size)
{
	#ifdef __cplusplus
	return DllExports::GdipGetImageDecodersSize(numDecoders, size);
	#else
	return GdipGetImageDecodersSize(numDecoders, size);
	#endif
}

static __inline__ GpStatus GetImageEncoders(UINT numEncoders, UINT size,
		ImageCodecInfo *encoders)
{
	#ifdef __cplusplus
	return DllExports::GdipGetImageEncoders(numEncoders, size, encoders);
	#else
	return GdipGetImageEncoders(numEncoders, size, encoders);
	#endif
}

static __inline__ GpStatus GetImageEncodersSize(UINT *numEncoders, UINT *size)
{
	#ifdef __cplusplus
	return DllExports::GdipGetImageEncodersSize(numEncoders, size);
	#else
	return GdipGetImageEncodersSize(numEncoders, size);
	#endif
}

#endif /* __GDIPLUS_IMAGECODEC_H */
