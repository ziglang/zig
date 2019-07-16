/*
 * gdiplus.h
 *
 * GDI+ main header
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

#ifndef __GDIPLUS_H
#define __GDIPLUS_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifndef RC_INVOKED

#include <stddef.h>
#include <math.h>
#include <windef.h>
#include <wingdi.h>

#include <basetyps.h>

#ifndef _COM_interface
#define _COM_interface struct
#endif

typedef _COM_interface IStream IStream;
typedef _COM_interface IDirectDrawSurface7 IDirectDrawSurface7;

#ifdef __cplusplus
namespace Gdiplus {
#endif

typedef float REAL;
typedef SHORT INT16;
typedef WORD UINT16;

#include "gdiplusenums.h"
#include "gdiplustypes.h"
#include "gdiplusgpstubs.h"
#include "gdiplusimaging.h"
#include "gdiplusinit.h"
#include "gdiplusmem.h"
#include "gdiplusmetaheader.h"
#include "gdipluspixelformats.h"
#include "gdipluscolor.h"
#include "gdipluscolormatrix.h"
#include "gdiplusflat.h"
#include "gdipluseffects.h"
#include "gdiplusimagecodec.h"

#ifdef __cplusplus
#include "gdiplusbase.h"
#include "gdiplusheaders.h"
#include "gdiplusimageattributes.h"
#include "gdiplusmatrix.h"
#include "gdiplusbrush.h"
#include "gdiplusmetafile.h"
#include "gdipluspen.h"
#include "gdiplusstringformat.h"
#include "gdipluspath.h"
#include "gdiplusgraphics.h"
#include "gdipluslinecaps.h"
#include "gdiplusimpl.h"

}  /* namespace Gdiplus */
#endif /* __cplusplus */

#endif /* !RC_INVOKED */

#endif /* __GDIPLUS_H */
