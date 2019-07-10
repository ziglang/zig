#include <_mingw_unicode.h>
/*
 * Copyright (C) 2004 Robert Reif
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __WINE_DXERR8_H
#define __WINE_DXERR8_H

#ifdef __cplusplus
extern "C" {
#endif /* defined(__cplusplus) */

const char*     WINAPI DXGetErrorString8A(HRESULT hr);
const WCHAR*    WINAPI DXGetErrorString8W(HRESULT hr);
#define DXGetErrorString8 __MINGW_NAME_AW(DXGetErrorString8)

const char*    WINAPI DXGetErrorDescription8A(HRESULT hr);
const WCHAR*   WINAPI DXGetErrorDescription8W(HRESULT hr);
#define DXGetErrorDescription8 __MINGW_NAME_AW(DXGetErrorDescription8)

HRESULT WINAPI  DXTraceA(const char* strFile, DWORD dwLine, HRESULT hr, const char*  strMsg, WINBOOL bPopMsgBox);
HRESULT WINAPI  DXTraceW(const char* strFile, DWORD dwLine, HRESULT hr, const WCHAR* strMsg, WINBOOL bPopMsgBox);
#define DXTrace __MINGW_NAME_AW(DXTrace)

#if defined(DEBUG) || defined(_DEBUG)
#define DXTRACE_MSG(str)                DXTrace(__FILE__, (DWORD)__LINE__, 0,  str, FALSE)
#define DXTRACE_ERR(str,hr)             DXTrace(__FILE__, (DWORD)__LINE__, hr, str, TRUE)
#define DXTRACE_ERR_NOMSGBOX(str,hr)    DXTrace(__FILE__, (DWORD)__LINE__, hr, str, FALSE)
#else
#define DXTRACE_MSG(str)                __MSABI_LONG(0)
#define DXTRACE_ERR(str,hr)             (hr)
#define DXTRACE_ERR_NOMSGBOX(str,hr)    (hr)
#endif

#ifdef __cplusplus
} /* extern "C" */
#endif /* defined(__cplusplus) */

#endif /* __WINE_DXERR8_H */
