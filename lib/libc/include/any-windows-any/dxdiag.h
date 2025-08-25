#undef INTERFACE
/*
 * Copyright (C) 2004 Raphael Junqueira
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

#ifndef __WINE_DXDIAG_H
#define __WINE_DXDIAG_H

#include <ole2.h>

#ifdef __cplusplus
extern "C" {
#endif /* defined(__cplusplus) */

/*****************************************************************************
 * #defines and error codes
 */
#define DXDIAG_DX9_SDK_VERSION 111

#define _FACDXDIAG  0x007
#define MAKE_DXDIAGHRESULT( code )  MAKE_HRESULT( 1, _FACDXDIAG, code )

/*
 * DXDiag Errors
 */
#define DXDIAG_E_INSUFFICIENT_BUFFER       MAKE_DXDIAGHRESULT(0x007A)


/*****************************************************************************
 * DXDiag structures Typedefs
 */
typedef struct _DXDIAG_INIT_PARAMS {
  DWORD  dwSize;
  DWORD  dwDxDiagHeaderVersion;
  WINBOOL   bAllowWHQLChecks;
  VOID*  pReserved;
} DXDIAG_INIT_PARAMS;


/*****************************************************************************
 * Predeclare the interfaces
 */
/* CLSIDs */
DEFINE_GUID(CLSID_DxDiagProvider,   0xA65B8071, 0x3BFE, 0x4213, 0x9A, 0x5B, 0x49, 0x1D, 0xA4, 0x46, 0x1C, 0xA7);

/* IIDs */
DEFINE_GUID(IID_IDxDiagProvider,    0x9C6B4CB0, 0x23F8, 0x49CC, 0xA3, 0xED, 0x45, 0xA5, 0x50, 0x00, 0xA6, 0xD2);
DEFINE_GUID(IID_IDxDiagContainer,   0x7D0F462F, 0x4064, 0x4862, 0xBC, 0x7F, 0x93, 0x3E, 0x50, 0x58, 0xC1, 0x0F);

/* typedef definitions */
typedef struct IDxDiagProvider *LPDXDIAGPROVIDER,   *PDXDIAGPROVIDER;
typedef struct IDxDiagContainer *LPDXDIAGCONTAINER,  *PDXDIAGCONTAINER;

/*****************************************************************************
 * IDxDiagContainer interface
 */
#ifdef WINE_NO_UNICODE_MACROS
#undef GetProp
#endif

#define INTERFACE IDxDiagContainer
DECLARE_INTERFACE_(IDxDiagContainer,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDxDiagContainer methods ***/
    STDMETHOD(GetNumberOfChildContainers)(THIS_  DWORD* pdwCount) PURE;
    STDMETHOD(EnumChildContainerNames)(THIS_ DWORD dwIndex, LPWSTR pwszContainer, DWORD cchContainer) PURE;
    STDMETHOD(GetChildContainer)(THIS_ LPCWSTR pwszContainer, IDxDiagContainer** ppInstance) PURE;
    STDMETHOD(GetNumberOfProps)(THIS_ DWORD* pdwCount) PURE;
    STDMETHOD(EnumPropNames)(THIS_ DWORD dwIndex, LPWSTR pwszPropName, DWORD cchPropName) PURE;
    STDMETHOD(GetProp)(THIS_ LPCWSTR pwszPropName, VARIANT* pvarProp) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define	IDxDiagContainer_QueryInterface(p,a,b)               (p)->lpVtbl->QueryInterface(p,a,b)
#define	IDxDiagContainer_AddRef(p)                           (p)->lpVtbl->AddRef(p)
#define	IDxDiagContainer_Release(p)                          (p)->lpVtbl->Release(p)
/*** IDxDiagContainer methods ***/
#define IDxDiagContainer_GetNumberOfChildContainers(p,a)     (p)->lpVtbl->GetNumberOfChildContainers(p,a)
#define IDxDiagContainer_EnumChildContainerNames(p,a,b,c)    (p)->lpVtbl->EnumChildContainerNames(p,a,b,c)
#define IDxDiagContainer_GetChildContainer(p,a,b)            (p)->lpVtbl->GetChildContainer(p,a,b)
#define IDxDiagContainer_GetNumberOfProps(p,a)               (p)->lpVtbl->GetNumberOfProps(p,a)
#define IDxDiagContainer_EnumPropNames(p,a,b,c)              (p)->lpVtbl->EnumPropNames(p,a,b,c)
#define IDxDiagContainer_GetProp(p,a,b)                      (p)->lpVtbl->GetProp(p,a,b)
#else
/*** IUnknown methods ***/
#define	IDxDiagContainer_QueryInterface(p,a,b)               (p)->QueryInterface(a,b)
#define	IDxDiagContainer_AddRef(p)                           (p)->AddRef()
#define	IDxDiagContainer_Release(p)                          (p)->Release()
/*** IDxDiagContainer methods ***/
#define IDxDiagContainer_GetNumberOfChildContainers(p,a)     (p)->GetNumberOfChildContainers(a)
#define IDxDiagContainer_EnumChildContainerNames(p,a,b,c)    (p)->EnumChildContainerNames(a,b,c)
#define IDxDiagContainer_GetChildContainer(p,a,b)            (p)->GetChildContainer(a,b)
#define IDxDiagContainer_GetNumberOfProps(p,a)               (p)->GetNumberOfProps(a)
#define IDxDiagContainer_EnumPropNames(p,a,b,c)              (p)->EnumPropNames(a,b,c)
#define IDxDiagContainer_GetProp(p,a,b)                      (p)->GetProp(a,b)
#endif

/*****************************************************************************
 * IDxDiagProvider interface
 */
#define INTERFACE IDxDiagProvider
DECLARE_INTERFACE_(IDxDiagProvider,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDxDiagProvider methods ***/
    STDMETHOD(Initialize)(THIS_ DXDIAG_INIT_PARAMS* pParams) PURE;
    STDMETHOD(GetRootContainer)(THIS_ IDxDiagContainer** ppInstance) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define	IDxDiagProvider_QueryInterface(p,a,b)                (p)->lpVtbl->QueryInterface(p,a,b)
#define	IDxDiagProvider_AddRef(p)                            (p)->lpVtbl->AddRef(p)
#define	IDxDiagProvider_Release(p)                           (p)->lpVtbl->Release(p)
/*** IDxDiagProvider methods ***/
#define IDxDiagProvider_Initialize(p,a)                      (p)->lpVtbl->Initialize(p,a)
#define IDxDiagProvider_GetRootContainer(p,a)                (p)->lpVtbl->GetRootContainer(p,a)
#else
/*** IUnknown methods ***/
#define	IDxDiagProvider_QueryInterface(p,a,b)                (p)->QueryInterface(a,b)
#define	IDxDiagProvider_AddRef(p)                            (p)->AddRef()
#define	IDxDiagProvider_Release(p)                           (p)->Release()
/*** IDxDiagProvider methods ***/
#define IDxDiagProvider_Initialize(p,a)                      (p)->Initialize(a)
#define IDxDiagProvider_GetRootContainer(p,a)                (p)->GetRootContainer(a)
#endif

#ifdef __cplusplus
}
#endif

#endif
