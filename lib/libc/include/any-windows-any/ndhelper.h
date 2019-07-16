/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_NDHELPER
#define _INC_NDHELPER
#include <ndattrib.h>

#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef struct tagDiagnosticsInfo {
  __LONG32  cost;
  ULONG flags;
} DiagnosticsInfo, *PDiagnosticsInfo;

typedef struct tagHYPOTHESIS {
  LPWSTR                  pwszClassName;
  LPWSTR                  pwszDescription;
  ULONG                   celt;
  PHELPER_ATTRIBUTE rgAttributes[ ];
} HYPOTHESIS, *PHYPOTHESIS;

typedef struct tagHelperAttributeInfo {
  LPWSTR pwszName;
  ATTRIBUTE_TYPE  type;
} HelperAttributeInfo, *PHelperAttributeInfo;

#ifdef __cplusplus
}
#endif

#undef  INTERFACE
#define INTERFACE INetDiagHelperInfo
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(INetDiagHelperInfo,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* INetDiagHelperInfo methods */
    STDMETHOD_(HRESULT,GetAttributeInfo)(THIS_ ULONG *pcelt,HelperAttributeInfo **pprgAttributeInfos) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define INetDiagHelperInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetDiagHelperInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetDiagHelperInfo_Release(This) (This)->lpVtbl->Release(This)
#define INetDiagHelperInfo_GetAttributeInfo(This,pcelt,pprgAttributeInfos) (This)->lpVtbl->GetAttributeInfo(This,pcelt,pprgAttributeInfos)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE INetDiagHelper
DECLARE_INTERFACE_(INetDiagHelper,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* INetDiagHelper methods */
    STDMETHOD_(HRESULT,Cancel)(THIS) PURE;
    STDMETHOD_(HRESULT,Cleanup)(THIS) PURE;
    STDMETHOD_(HRESULT,GetAttributes)(THIS_ ULONG *pcelt,HELPER_ATTRIBUTE **pprgAttributes) PURE;
    STDMETHOD_(HRESULT,GetCacheTime)(THIS_ FILETIME *pCacheTime) PURE;
    STDMETHOD_(HRESULT,GetDiagnosticsInfo)(THIS_ RETVAL DiagnosticsInfo **ppInfo) PURE;
    STDMETHOD_(HRESULT,GetDownStreamHypotheses)(THIS_ ULONG *pcelt,HYPOTHESIS **pprgHypotheses) PURE;
    STDMETHOD_(HRESULT,GetHigherHypotheses)(THIS_ ULONG *pcelt,HYPOTHESIS **pprgHypotheses) PURE;
    STDMETHOD_(HRESULT,GetKeyAttributes)(THIS_ ULONG *pcelt,HELPER_ATTRIBUTE **pprgAttributes) PURE;
    STDMETHOD_(HRESULT,GetLifeTime)(THIS_ LIFE_TIME *pLifeTime) PURE;
    STDMETHOD_(HRESULT,GetLowerHypotheses)(THIS_ ULONG *pcelt,HYPOTHESIS **pprgHypotheses) PURE;
    STDMETHOD_(HRESULT,GetRepairInfo)(THIS_ PROBLEM_TYPE problem,ULONG pcelt,RepairInfo **ppInfo) PURE;
    STDMETHOD_(HRESULT,GetUpStreamHypotheses)(THIS_ ULONG *pcelt,HYPOTHESIS **pprgHypotheses) PURE;
    STDMETHOD_(HRESULT,HighUtilization)(THIS_ STRING LPWSTR pwszInstanceDescription,STRING LPWSTR *ppwszDescription,LONG *pDeferredTime,DIAGNOSTICS_STATUS *pStatus) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ULONG celt,HELPER_ATTRIBUTE rgAttributes) PURE;
    STDMETHOD_(HRESULT,LowHealth)(THIS_ STRING LPWSTR pwszInstanceDescription,STRING LPWSTR *ppwszDescription,LONG *pDeferredTime,DIAGNOSTICS_STATUS *pStatus) PURE;
    STDMETHOD_(HRESULT,Repair)(THIS_ REPAIRINFO *pInfo,LONG *pDeferredTime,REPAIR_STATUS *pStatus) PURE;
    STDMETHOD_(HRESULT,SetLifeTime)(THIS_ LIFE_TIME lifeTime) PURE;
    STDMETHOD_(HRESULT,Validate)(THIS_ PROBLEM_TYPE problem,ULONG *pDeferredTime,REPAIR_STATUS *pStatus) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define INetDiagHelper_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetDiagHelper_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetDiagHelper_Release(This) (This)->lpVtbl->Release(This)
#define INetDiagHelper_Cancel() (This)->lpVtbl->Cancel(This)
#define INetDiagHelper_Cleanup() (This)->lpVtbl->Cleanup(This)
#define INetDiagHelper_GetAttributes(This,pcelt,pprgAttributes) (This)->lpVtbl->GetAttributes(This,pcelt,pprgAttributes)
#define INetDiagHelper_GetCacheTime(This,pCacheTime) (This)->lpVtbl->GetCacheTime(This,pCacheTime)
#define INetDiagHelper_GetDiagnosticsInfo(This,ppInfo) (This)->lpVtbl->GetDiagnosticsInfo(This,ppInfo)
#define INetDiagHelper_GetDownStreamHypotheses(This,pcelt,pprgHypotheses) (This)->lpVtbl->GetDownStreamHypotheses(This,pcelt,pprgHypotheses)
#define INetDiagHelper_GetHigherHypotheses(This,pcelt,pprgHypotheses) (This)->lpVtbl->GetHigherHypotheses(This,pcelt,pprgHypotheses)
#define INetDiagHelper_GetKeyAttributes(This,pcelt,pprgAttributes) (This)->lpVtbl->GetKeyAttributes(This,pcelt,pprgAttributes)
#define INetDiagHelper_GetLifeTime(This,pLifeTime) (This)->lpVtbl->GetLifeTime(This,pLifeTime)
#define INetDiagHelper_GetLowerHypotheses(This,pcelt,pprgHypotheses) (This)->lpVtbl->GetLowerHypotheses(This,pcelt,pprgHypotheses)
#define INetDiagHelper_GetRepairInfo(This,problem,pcelt,ppInfo) (This)->lpVtbl->GetRepairInfo(This,problem,pcelt,ppInfo)
#define INetDiagHelper_GetUpStreamHypotheses(This,pcelt,pprgHypotheses) (This)->lpVtbl->GetUpStreamHypotheses(This,pcelt,pprgHypotheses)
#define INetDiagHelper_HighUtilization(This,pwszInstanceDescription,ppwszDescription,pDeferredTime,pStatus) (This)->lpVtbl->HighUtilization(This,pwszInstanceDescription,ppwszDescription,pDeferredTime,pStatus)
#define INetDiagHelper_Initialize(This,celt,rgAttributes) (This)->lpVtbl->Initialize(This,celt,rgAttributes)
#define INetDiagHelper_LowHealth(This,pwszInstanceDescription,ppwszDescription,pDeferredTime,pStatus) (This)->lpVtbl->LowHealth(This,pwszInstanceDescription,ppwszDescription,pDeferredTime,pStatus)
#define INetDiagHelper_Repair(This,pInfo,pDeferredTime,pStatus) (This)->lpVtbl->Repair(This,pInfo,pDeferredTime,pStatus)
#define INetDiagHelper_SetLifeTime(This,lifeTime) (This)->lpVtbl->SetLifeTime(This,lifeTime)
#define INetDiagHelper_Validate(This,problem,pDeferredTime,pStatus) (This)->lpVtbl->Validate(This,problem,pDeferredTime,pStatus)
#endif /*COBJMACROS*/

#if (_WIN32_WINNT >= 0x0601)
typedef struct tagHypothesisResult {
  HYPOTHESIS       hypothesis;
  DIAGNOSIS_STATUS pathStatus;
} HypothesisResult;

#undef  INTERFACE
#define INTERFACE INetDiagHelperUtilFactory
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(INetDiagHelperUtilFactory,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* INetDiagHelperUtilFactory methods */
    STDMETHOD(CreateUtilityInstance)(THIS_ REFIID *riid,void **ppvObject) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define INetDiagHelperUtilFactory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetDiagHelperUtilFactory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetDiagHelperUtilFactory_Release(This) (This)->lpVtbl->Release(This)
#define INetDiagHelperUtilFactory_CreateUtilityInstance(This,riid,ppvObject) (This)->lpVtbl->CreateUtilityInstance(This,riid,ppvObject)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE INetDiagHelperEx
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(INetDiagHelperEx,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* INetDiagHelperEx methods */
    STDMETHOD_(HRESULT,ReconfirmLowHealth)(THIS_ ULONG celt,HypothesisResult *pResults,string LPWSTR *ppwszUpdatedDescription,DIAGNOSIS_STATUS *pUpdatedStatus) PURE;
    STDMETHOD(ReproduceFailure)(THIS) PURE;
    STDMETHOD(SetUtilities)(THIS_ INetDiagHelperUtilFactory *pUtilities) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define INetDiagHelperEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INetDiagHelperEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INetDiagHelperEx_Release(This) (This)->lpVtbl->Release(This)
#define INetDiagHelperEx_ReconfirmLowHealth(This,celt,pResults,ppwszUpdatedDescription,pUpdatedStatus) (This)->lpVtbl->ReconfirmLowHealth(This,celt,pResults,ppwszUpdatedDescription,pUpdatedStatus)
#define INetDiagHelperEx_ReproduceFailure() (This)->lpVtbl->ReproduceFailure(This)
#define INetDiagHelperEx_SetUtilities(This,pUtilities) (This)->lpVtbl->SetUtilities(This,pUtilities)
#endif /*COBJMACROS*/

#endif /*(_WIN32_WINNT >= 0x0601)*/

#endif /*(_WIN32_WINNT >= 0x0600)*/

#endif /*_INC_NDHELPER*/
