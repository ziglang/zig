/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_FUNCTIONDISCOVERYAPI
#define _INC_FUNCTIONDISCOVERYAPI
#include <propsys.h>
#include <functiondiscoveryconstraints.h>
#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

typedef DWORDLONG FDQUERYCONTEXT;
typedef struct IFunctionInstance IFunctionInstance;

typedef enum tagQueryUpdateAction {
  QUA_ADD      = 0,
  QUA_REMOVE   = 1,
  QUA_CHANGE   = 2 
} QueryUpdateAction;

typedef enum tagSystemVisibilityFlags {
  SVF_SYSTEM   = 0,
  SVF_USER     = 1 
} SystemVisibilityFlags;

#ifdef __cplusplus
}
#endif

#include <functiondiscoverynotification.h>

#define FD_EVENTID_SEARCHCOMPLETE 1000
#define FD_EVENTID_ASYNCTHREADEXIT 1001
#define FD_EVENTID_SEARCHSTART 1002
#define FD_EVENTID_IPADDRESSCHANGE 1003

#undef  INTERFACE
#define INTERFACE IFunctionInstance
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IFunctionInstance,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IFunctionInstance methods */
    STDMETHOD_(HRESULT,GetID)(THIS_ WCHAR **ppszCoMemIdentity) PURE;
    STDMETHOD_(HRESULT,GetProviderInstanceID)(THIS_ WCHAR **ppszCoMemProviderInstanceID) PURE;
    STDMETHOD_(HRESULT,OpenPropertyStore)(THIS_ DWORD dwStgAccess,IPropertyStore **ppIPropertyStore) PURE;
    STDMETHOD_(HRESULT,GetCategory)(THIS_ WCHAR **ppszCoMemCategory,WCHAR **ppszCoMemSubCategory) PURE;
    STDMETHOD_(HRESULT,QueryService)(THIS_ REFGUID guidService,REFGUID riid,void **ppv) PURE;
    /* FIXME: genidl doesn't show QueryService */

    END_INTERFACE
};
#ifdef COBJMACROS
#define IFunctionInstance_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IFunctionInstance_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IFunctionInstance_Release(This) (This)->lpVtbl->Release(This)
#define IFunctionInstance_GetID(This,ppszCoMemIdentity) (This)->lpVtbl->GetID(This,ppszCoMemIdentity)
#define IFunctionInstance_GetProviderInstanceID(This,ppszCoMemProviderInstanceID) (This)->lpVtbl->GetProviderInstanceID(This,ppszCoMemProviderInstanceID)
#define IFunctionInstance_OpenPropertyStore(This,dwStgAccess,ppIPropertyStore) (This)->lpVtbl->OpenPropertyStore(This,dwStgAccess,ppIPropertyStore)
#define IFunctionInstance_GetCategory(This,ppszCoMemCategory,ppszCoMemSubCategory) (This)->lpVtbl->GetCategory(This,ppszCoMemCategory,ppszCoMemSubCategory)
#define IFunctionInstance_QueryService(This,guidService,riid,ppv) (This)->lpVtbl->QueryService(This,guidService,riid,ppv)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IFunctionInstanceQuery
DECLARE_INTERFACE_(IFunctionInstanceQuery,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IFunctionInstanceQuery methods */
    STDMETHOD_(HRESULT,Execute)(THIS_ IFunctionInstance **ppIFunctionInstance) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IFunctionInstanceQuery_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IFunctionInstanceQuery_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IFunctionInstanceQuery_Release(This) (This)->lpVtbl->Release(This)
#define IFunctionInstanceQuery_Execute(This,ppIFunctionInstance) (This)->lpVtbl->Execute(This,ppIFunctionInstance)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IFunctionInstanceCollection
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IFunctionInstanceCollection,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IFunctionInstanceCollection methods */
    STDMETHOD_(HRESULT,GetCount)(THIS_ DWORD *pdwCount) PURE;
    STDMETHOD_(HRESULT,Get)(THIS_ const WCHAR *pszInstanceIdentity,DWORD *pdwIndex,IFunctionInstance **ppIFunctionInstance) PURE;
    STDMETHOD_(HRESULT,Item)(THIS_ DWORD dwIndex,IFunctionInstance **ppFunctionInstance) PURE;
    STDMETHOD_(HRESULT,Add)(THIS_ IFunctionInstance *pIFunctionInstance) PURE;
    STDMETHOD_(HRESULT,Remove)(THIS_ DWORD dwIndex,IFunctionInstance **ppIFunctionInstance) PURE;
    STDMETHOD_(HRESULT,Delete)(THIS_ DWORD dwIndex) PURE;
    STDMETHOD_(HRESULT,DeleteAll)(THIS) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IFunctionInstanceCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IFunctionInstanceCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IFunctionInstanceCollection_Release(This) (This)->lpVtbl->Release(This)
#define IFunctionInstanceCollection_GetCount(This,pdwCount) (This)->lpVtbl->GetCount(This,pdwCount)
#define IFunctionInstanceCollection_Get(This,pszInstanceIdentity,pdwIndex,ppIFunctionInstance) (This)->lpVtbl->Get(This,pszInstanceIdentity,pdwIndex,ppIFunctionInstance)
#define IFunctionInstanceCollection_Item(This,dwIndex,ppFunctionInstance) (This)->lpVtbl->Item(This,dwIndex,ppFunctionInstance)
#define IFunctionInstanceCollection_Add(This,pIFunctionInstance) (This)->lpVtbl->Add(This,pIFunctionInstance)
#define IFunctionInstanceCollection_Remove(This,dwIndex,ppIFunctionInstance) (This)->lpVtbl->Remove(This,dwIndex,ppIFunctionInstance)
#define IFunctionInstanceCollection_Delete(This,dwIndex) (This)->lpVtbl->Delete(This,dwIndex)
#define IFunctionInstanceCollection_DeleteAll() (This)->lpVtbl->DeleteAll(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IFunctionInstanceCollectionQuery
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IFunctionInstanceCollectionQuery,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IFunctionInstanceCollectionQuery methods */
    STDMETHOD_(HRESULT,AddQueryConstraint)(THIS_ const WCHAR *pszConstraintName,const WCHAR *pszConstraintValue) PURE;
    STDMETHOD_(HRESULT,AddPropertyConstraint)(THIS_ REFPROPERTYKEY Key,const PROPVARIANT *pv,PropertyConstraint enumPropertyConstraint) PURE;
    STDMETHOD_(HRESULT,Execute)(THIS_ IFunctionInstanceCollection **ppIFunctionInstanceCollection) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IFunctionInstanceCollectionQuery_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IFunctionInstanceCollectionQuery_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IFunctionInstanceCollectionQuery_Release(This) (This)->lpVtbl->Release(This)
#define IFunctionInstanceCollectionQuery_AddQueryConstraint(This,pszConstraintName,pszConstraintValue) (This)->lpVtbl->AddQueryConstraint(This,pszConstraintName,pszConstraintValue)
#define IFunctionInstanceCollectionQuery_AddPropertyConstraint(This,Key,pv,enumPropertyConstraint) (This)->lpVtbl->AddPropertyConstraint(This,Key,pv,enumPropertyConstraint)
#define IFunctionInstanceCollectionQuery_Execute(This,ppIFunctionInstanceCollection) (This)->lpVtbl->Execute(This,ppIFunctionInstanceCollection)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IFunctionDiscovery
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IFunctionDiscovery,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IFunctionDiscovery methods */
    STDMETHOD_(HRESULT,GetInstanceCollection)(THIS_ const WCHAR *pszCategory,const WCHAR *pszSubCategory,WINBOOL fIncludeAllSubCategories,IFunctionInstanceCollection **ppIFunctionInstanceCollection) PURE;
    STDMETHOD_(HRESULT,GetInstance)(THIS_ const WCHAR *pszFunctionInstanceIdentity,IFunctionInstance **ppIFunctionInstance) PURE;
    STDMETHOD_(HRESULT,CreateInstanceCollectionQuery)(THIS_ const WCHAR *pszCategory,const WCHAR *pszSubCategory,WINBOOL fIncludeAllSubCategories,IFunctionDiscoveryNotification *pIFunctionDiscoveryNotification,FDQUERYCONTEXT *pfdqcQueryContext,IFunctionInstanceCollectionQuery **ppIFunctionInstanceCollectionQuery) PURE;
    STDMETHOD_(HRESULT,CreateInstanceQuery)(THIS_ const WCHAR *pszFunctionInstanceIdentity,IFunctionDiscoveryNotification *pIFunctionDiscoveryNotification,FDQUERYCONTEXT *pfdqcQueryContext,IFunctionInstanceQuery **ppIFunctionInstanceQuery) PURE;
    STDMETHOD_(HRESULT,AddInstance)(THIS_ SystemVisibilityFlags enumSystemVisibility,const WCHAR *pszCategory,const WCHAR *pszSubCategory,const WCHAR *pszCategoryIdentity,IFunctionInstance **ppIFunctionInstance) PURE;
    STDMETHOD_(HRESULT,RemoveInstance)(THIS_ SystemVisibilityFlags enumSystemVisibility,const WCHAR *pszCategory,const WCHAR *pszSubCategory,const WCHAR *pszCategoryIdentity) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IFunctionDiscovery_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IFunctionDiscovery_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IFunctionDiscovery_Release(This) (This)->lpVtbl->Release(This)
#define IFunctionDiscovery_GetInstanceCollection(This,pszCategory,pszSubCategory,fIncludeAllSubCategories,ppIFunctionInstanceCollection) (This)->lpVtbl->GetInstanceCollection(This,pszCategory,pszSubCategory,fIncludeAllSubCategories,ppIFunctionInstanceCollection)
#define IFunctionDiscovery_GetInstance(This,pszFunctionInstanceIdentity,ppIFunctionInstance) (This)->lpVtbl->GetInstance(This,pszFunctionInstanceIdentity,ppIFunctionInstance)
#define IFunctionDiscovery_CreateInstanceCollectionQuery(This,pszCategory,pszSubCategory,fIncludeAllSubCategories,pIFunctionDiscoveryNotification,pfdqcQueryContext,ppIFunctionInstanceCollectionQuery) (This)->lpVtbl->CreateInstanceCollectionQuery(This,pszCategory,pszSubCategory,fIncludeAllSubCategories,pIFunctionDiscoveryNotification,pfdqcQueryContext,ppIFunctionInstanceCollectionQuery)
#define IFunctionDiscovery_CreateInstanceQuery(This,pszFunctionInstanceIdentity,pIFunctionDiscoveryNotification,pfdqcQueryContext,ppIFunctionInstanceQuery) (This)->lpVtbl->CreateInstanceQuery(This,pszFunctionInstanceIdentity,pIFunctionDiscoveryNotification,pfdqcQueryContext,ppIFunctionInstanceQuery)
#define IFunctionDiscovery_AddInstance(This,enumSystemVisibility,pszCategory,pszSubCategory,pszCategoryIdentity,ppIFunctionInstance) (This)->lpVtbl->AddInstance(This,enumSystemVisibility,pszCategory,pszSubCategory,pszCategoryIdentity,ppIFunctionInstance)
#define IFunctionDiscovery_RemoveInstance(This,enumSystemVisibility,pszCategory,pszSubCategory,pszCategoryIdentity) (This)->lpVtbl->RemoveInstance(This,enumSystemVisibility,pszCategory,pszSubCategory,pszCategoryIdentity)
#endif /*COBJMACROS*/

#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_FUNCTIONDISCOVERYAPI*/
