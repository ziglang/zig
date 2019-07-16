/*
 * gdiplusmem.h
 *
 * GDI+ memory allocation
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

#ifndef __GDIPLUS_MEM_H
#define __GDIPLUS_MEM_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifdef __cplusplus
namespace DllExports {
extern "C" {
#endif

VOID* WINGDIPAPI GdipAlloc(size_t);
VOID WINGDIPAPI GdipFree(VOID*);

#ifdef __cplusplus
}  /* extern "C" */
}  /* namespace DllExports */
#endif

#endif /* __GDIPLUS_MEM_H */
