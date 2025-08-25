/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __IDENTITYSTORE_H__
#define __IDENTITYSTORE_H__

#include <objbase.h>

#if (_WIN32_WINNT >= 0x0601)

DEFINE_GUID(IID_IAssociatedIdentityProvider,0x2AF066B3,0x4CBB,0x4CBA,0xA7,0x98,0x20,0x4B,0x6A,0xF6,0x8C,0xC0);

#ifndef __IAssociatedIdentityProvider_FWD_DEFINED__
#define __IAssociatedIdentityProvider_FWD_DEFINED__
typedef struct IAssociatedIdentityProvider IAssociatedIdentityProvider;
#endif

#undef  INTERFACE
#define INTERFACE IAssociatedIdentityProvider
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IAssociatedIdentityProvider,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IAssociatedIdentityProvider methods */
    STDMETHOD_(HRESULT,AssociateIdentity)(THIS_ HWND hwndParent,IPropertyStore **ppPropertyStore) PURE;
    STDMETHOD_(HRESULT,ChangeCredential)(THIS_ HWND hwndParent,LPCWSTR lpszUniqueID) PURE;
    STDMETHOD_(HRESULT,DisassociateIdentity)(THIS_ HWND hwndParent,LPCWSTR lpszUniqueID) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IAssociatedIdentityProvider_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAssociatedIdentityProvider_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAssociatedIdentityProvider_Release(This) (This)->lpVtbl->Release(This)
#define IAssociatedIdentityProvider_AssociateIdentity(This,hwndParent,ppPropertyStore) (This)->lpVtbl->AssociateIdentity(This,hwndParent,ppPropertyStore)
#define IAssociatedIdentityProvider_ChangeCredential(This,hwndParent,lpszUniqueID) (This)->lpVtbl->ChangeCredential(This,hwndParent,lpszUniqueID)
#define IAssociatedIdentityProvider_DisassociateIdentity(This,hwndParent,lpszUniqueID) (This)->lpVtbl->DisassociateIdentity(This,hwndParent,lpszUniqueID)
#endif /*COBJMACROS*/

#endif /*(_WIN32_WINNT >= 0x0601)*/
#endif /* __IDENTITYSTORE_H__ */
