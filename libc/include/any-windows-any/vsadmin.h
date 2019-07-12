/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_VSADMIN
#define _INC_VSADMIN

#include <vss.h>
#if (_WIN32_WINNT >= 0x600)
#undef  INTERFACE
#define INTERFACE IVssAdmin
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssAdmin,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssAdmin methods */
    STDMETHOD_(HRESULT,RegisterProvider)(THIS_ VSS_ID pProviderId,CLSID ClassId,VSS_PWSZ pwszProviderName,VSS_PROVIDER_TYPE eProviderType,VSS_PWSZ pwszProviderVersion,VSS_ID ProviderVersionId) PURE;
    STDMETHOD_(HRESULT,UnregisterProvider)(THIS_ VSS_ID ProviderId) PURE;
    STDMETHOD_(HRESULT,QueryProviders)(THIS_ IVssEnumObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,AbortAllSnapshotsInProgress)(THIS) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssAdmin_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssAdmin_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssAdmin_Release(This) (This)->lpVtbl->Release(This)
#define IVssAdmin_RegisterProvider(This,pProviderId,ClassId,pwszProviderName,eProviderType,pwszProviderVersion,ProviderVersionId) (This)->lpVtbl->RegisterProvider(This,pProviderId,ClassId,pwszProviderName,eProviderType,pwszProviderVersion,ProviderVersionId)
#define IVssAdmin_UnregisterProvider(This,ProviderId) (This)->lpVtbl->UnregisterProvider(This,ProviderId)
#define IVssAdmin_QueryProviders(This,ppEnum) (This)->lpVtbl->QueryProviders(This,ppEnum)
#define IVssAdmin_AbortAllSnapshotsInProgress() (This)->lpVtbl->AbortAllSnapshotsInProgress(This)
#endif /*COBJMACROS*/
#endif /*(_WIN32_WINNT >= 0x600)*/
#endif /*_INC_VSWRITER*/
