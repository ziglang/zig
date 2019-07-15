/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_FUNCTIONDISCOVERYNOTIFICATION
#define _INC_FUNCTIONDISCOVERYNOTIFICATION

#if (_WIN32_WINNT >= 0x0600)

#undef  INTERFACE
#define INTERFACE IFunctionDiscoveryNotification
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IFunctionDiscoveryNotification,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IFunctionDiscoveryNotification methods */
    STDMETHOD_(HRESULT,OnUpdate)(THIS_ QueryUpdateAction enumQueryUpdateAction,FDQUERYCONTEXT fdqcQueryContext,IFunctionInstance *pIFunctionInstance) PURE;
    STDMETHOD_(HRESULT,OnError)(THIS_ HRESULT hr,FDQUERYCONTEXT fdqcQueryContext,const WCHAR *pszProvider) PURE;
    STDMETHOD_(HRESULT,OnEvent)(THIS_ DWORD dwEventID,FDQUERYCONTEXT fdqcQueryContext,const WCHAR *pszProvider) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IFunctionDiscoveryNotification_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IFunctionDiscoveryNotification_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IFunctionDiscoveryNotification_Release(This) (This)->lpVtbl->Release(This)
#define IFunctionDiscoveryNotification_OnUpdate(This,enumQueryUpdateAction,fdqcQueryContext,pIFunctionInstance) (This)->lpVtbl->OnUpdate(This,enumQueryUpdateAction,fdqcQueryContext,pIFunctionInstance)
#define IFunctionDiscoveryNotification_OnError(This,hr,fdqcQueryContext,pszProvider) (This)->lpVtbl->OnError(This,hr,fdqcQueryContext,pszProvider)
#define IFunctionDiscoveryNotification_OnEvent(This,dwEventID,fdqcQueryContext,pszProvider) (This)->lpVtbl->OnEvent(This,dwEventID,fdqcQueryContext,pszProvider)
#endif /*COBJMACROS*/

#endif /*(_WIN32_WINNT >= 0x0600)*/

#endif /* _INC_FUNCTIONDISCOVERYNOTIFICATION */
