/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __INC_PORTABLEDEVICECONNECTAPI__
#define __INC_PORTABLEDEVICECONNECTAPI__

#include <objbase.h>

#if (_WIN32_WINNT >= 0x0601)

#ifndef __IConnectionRequestCallback_FWD_DEFINED__
#define __IConnectionRequestCallback_FWD_DEFINED__
typedef struct IConnectionRequestCallback ILocationReport;
#endif

#undef  INTERFACE
#define INTERFACE IConnectionRequestCallback
DECLARE_INTERFACE_(IConnectionRequestCallback,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IConnectionRequestCallback methods */
    STDMETHOD_(HRESULT,OnComplete)(THIS_ HRESULT hrStatus) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IConnectionRequestCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IConnectionRequestCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IConnectionRequestCallback_Release(This) (This)->lpVtbl->Release(This)
#define IConnectionRequestCallback_OnComplete(This,hrStatus) (This)->lpVtbl->OnComplete(This,hrStatus)
#endif /*COBJMACROS*/


#endif /*(_WIN32_WINNT >= 0x0601)*/
#endif /*__INC_PORTABLEDEVICECONNECTAPI__*/
