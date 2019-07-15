/*
 * gdiplusbase.h
 *
 * GDI+ base class
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

#ifndef __GDIPLUS_BASE_H
#define __GDIPLUS_BASE_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifndef __cplusplus
#error "A C++ compiler is required to include gdiplusbase.h."
#endif

class GdiplusBase
{
public:
	static void* operator new(size_t in_size)
	{
		return DllExports::GdipAlloc(in_size);
	}
	static void* operator new[](size_t in_size)
	{
		return DllExports::GdipAlloc(in_size);
	}
	static void operator delete(void *in_pVoid)
	{
		DllExports::GdipFree(in_pVoid);
	}
	static void operator delete[](void *in_pVoid)
	{
		DllExports::GdipFree(in_pVoid);
	}
};

#endif /* __GDIPLUS_BASE_H */
