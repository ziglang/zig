/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __ATLWMIPROV_H__
#define __ATLWMIPROV_H__

#ifndef __cplusplus
#error Requires C++ compilation (use a .cpp suffix)
#endif

#include <wbemprov.h>
#include <wmiutils.h>

namespace ATL {
  class ATL_NO_VTABLE IWbemInstProviderImpl : public IWbemServices,public IWbemProviderInit {
  public:
    HRESULT WINAPI OpenNamespace(const BSTR Namespace,__LONG32 lFlags,IWbemContext *pCtx,IWbemServices **ppWorkingNamespace,IWbemCallResult **ppResult) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI CancelAsyncCall(IWbemObjectSink *pSink) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI QueryObjectSink(__LONG32 lFlags,IWbemObjectSink **ppResponseHandler) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI GetObject(const BSTR ObjectPath,__LONG32 lFlags,IWbemContext *pCtx,IWbemClassObject **ppObject,IWbemCallResult **ppCallResult) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI PutClass(IWbemClassObject *pObject,__LONG32 lFlags,IWbemContext *pCtx,IWbemCallResult **ppCallResult) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI PutClassAsync(IWbemClassObject *pObject,__LONG32 lFlags,IWbemContext *pCtx,IWbemObjectSink *pResponseHandler) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI DeleteClass(const BSTR Class,__LONG32 lFlags,IWbemContext *pCtx,IWbemCallResult **ppCallResult) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI DeleteClassAsync(const BSTR Class,__LONG32 lFlags,IWbemContext *pCtx,IWbemObjectSink *pResponseHandler) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI CreateClassEnum(const BSTR Superclass,__LONG32 lFlags,IWbemContext *pCtx,IEnumWbemClassObject **ppEnum) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI CreateClassEnumAsync(const BSTR Superclass,__LONG32 lFlags,IWbemContext *pCtx,IWbemObjectSink *pResponseHandler) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI PutInstance(IWbemClassObject *pInst,__LONG32 lFlags,IWbemContext *pCtx,IWbemCallResult **ppCallResult) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI DeleteInstance(const BSTR ObjectPath,__LONG32 lFlags,IWbemContext *pCtx,IWbemCallResult **ppCallResult) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI CreateInstanceEnum(const BSTR Class,__LONG32 lFlags,IWbemContext *pCtx,IEnumWbemClassObject **ppEnum) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI ExecQuery(const BSTR QueryLanguage,const BSTR Query,__LONG32 lFlags,IWbemContext *pCtx,IEnumWbemClassObject **ppEnum) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI ExecNotificationQuery(const BSTR QueryLanguage,const BSTR Query,__LONG32 lFlags,IWbemContext *pCtx,IEnumWbemClassObject **ppEnum) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI ExecNotificationQueryAsync(const BSTR QueryLanguage,const BSTR Query,__LONG32 lFlags,IWbemContext *pCtx,IWbemObjectSink *pResponseHandler) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI ExecMethod(const BSTR strObjectPath,const BSTR strMethodName,__LONG32 lFlags,IWbemContext *pCtx,IWbemClassObject *pInParams,IWbemClassObject **ppOutParams,IWbemCallResult **ppCallResult) {return WBEM_E_NOT_SUPPORTED;};
    HRESULT WINAPI ExecMethodAsync(const BSTR strObjectPath,const BSTR strMethodName,__LONG32 lFlags,IWbemContext *pCtx,IWbemClassObject *pInParams,IWbemObjectSink *pResponseHandler) {return WBEM_E_NOT_SUPPORTED;};
  };

  class CProviderHelper {
  private:
    CComPtr<IWbemClassObject> m_pErrorObject;
    HRESULT m_hr;
  public:
    CProviderHelper(IWbemServices *pNamespace,IWbemContext *pCtx) {
      m_hr = WBEM_E_FAILED;
      m_pErrorObject = NULL;
      if(!pNamespace) {
	m_hr = WBEM_E_INVALID_PARAMETER;
	ATLASSERT (0);
	return;
      }
      BSTR bstrString = SysAllocString(L"__ExtendedStatus");
      if(!bstrString) {
	m_hr = WBEM_E_OUT_OF_MEMORY;
	return;
      }
      m_hr = pNamespace->GetObject(bstrString,0,pCtx,&m_pErrorObject,NULL);
      SysFreeString(bstrString);
      return;
    }
    virtual ~CProviderHelper() { }
    HRESULT WINAPI ConstructErrorObject (const ULONG ulStatusCode,const BSTR bstrDescription,const BSTR bstrOperation,const BSTR bstrParameter,const BSTR bstrProviderName,IWbemClassObject **ppErrorObject) {
      static const LPWSTR lpwstrDescription = L"Description";
      static const LPWSTR lpwstrOperation = L"Operation";
      static const LPWSTR lpwstrStatusCode = L"StatusCode";
      static const LPWSTR lpwstrParameterInfo = L"ParameterInfo";
      static const LPWSTR lpwstrProviderName = L"ProviderName";

      if(FAILED (m_hr)) {
	ATLASSERT (0);
	return m_hr;
      }
      if(!ppErrorObject) {
	ATLASSERT (0);
	return WBEM_E_INVALID_PARAMETER;
      }
      HRESULT hr = m_pErrorObject->SpawnInstance(0,ppErrorObject);
      if(FAILED(hr)) return hr;
      VARIANT var;
      VariantInit(&var);
      var.vt = VT_I4;
      var.lVal = ulStatusCode;
      hr = (*ppErrorObject)->Put(lpwstrStatusCode,0,&var,0);
      if(FAILED(hr)) return hr;
      var.vt = VT_BSTR;
      if(bstrDescription!=NULL) {
	var.bstrVal = bstrDescription;
	hr = (*ppErrorObject)->Put(lpwstrDescription,0,&var,0);
	if(FAILED(hr)) return hr;
      }
      if(bstrOperation!=NULL) {
	var.bstrVal = bstrOperation;
	hr = (*ppErrorObject)->Put(lpwstrOperation,0,&var,0);
	if(FAILED(hr)) return hr;
      }
      if(bstrParameter!=NULL) {
	var.bstrVal = bstrParameter;
	hr = (*ppErrorObject)->Put(lpwstrParameterInfo,0,&var,0);
	if(FAILED(hr)) return hr;
      }
      if(bstrProviderName!=NULL) {
	var.bstrVal = bstrProviderName;
	hr = (*ppErrorObject)->Put(lpwstrProviderName,0,&var,0);
	if(FAILED(hr)) return hr;
      }
      return hr;
    }
  };

  class CIntrinsicEventProviderHelper : public CProviderHelper {
  private:
    CComPtr<IWbemClassObject> m_pCreationEventClass;
    CComPtr<IWbemClassObject> m_pDeletionEventClass;
    CComPtr<IWbemClassObject> m_pModificationEventClass;
    HRESULT m_hr;
  public:
    CIntrinsicEventProviderHelper(IWbemServices *pNamespace,IWbemContext *pCtx) : CProviderHelper (pNamespace,pCtx) {
      m_hr = WBEM_E_FAILED;
      if(!pNamespace || !pCtx) {
	m_hr = WBEM_E_INVALID_PARAMETER;
	ATLASSERT (0);
	return;
      }
      m_pCreationEventClass = NULL;
      m_pModificationEventClass = NULL;
      m_pDeletionEventClass = NULL;
      BSTR bstrString = SysAllocString(L"__InstanceCreationEvent");
      if(!bstrString) {
	m_hr = WBEM_E_OUT_OF_MEMORY;
	return;
      }
      m_hr = pNamespace->GetObject(bstrString,0,pCtx,&m_pCreationEventClass,NULL);
      SysFreeString(bstrString);
      bstrString=NULL;
      if(FAILED(m_hr)) return;
      bstrString = SysAllocString(L"__InstanceModificationEvent");
      if(!bstrString) {
	m_hr = WBEM_E_OUT_OF_MEMORY;
	return;
      }
      m_hr = pNamespace->GetObject(bstrString,0,pCtx,&m_pModificationEventClass,NULL);
      SysFreeString(bstrString);
      bstrString=NULL;
      if(FAILED(m_hr)) return;
      bstrString = SysAllocString(L"__InstanceDeletionEvent");
      if(!bstrString) {
	m_hr = WBEM_E_OUT_OF_MEMORY;
	return;
      }
      m_hr = pNamespace->GetObject(bstrString,0,pCtx,&m_pDeletionEventClass,NULL);
      SysFreeString(bstrString);
      bstrString=NULL;
      if(FAILED(m_hr)) return;
      return;
    }
    virtual ~CIntrinsicEventProviderHelper() { }
    HRESULT WINAPI FireCreationEvent(IWbemClassObject *pNewInstance,IWbemObjectSink *pSink) {
      if(FAILED(m_hr)) {
	ATLASSERT (0);
	return m_hr;
      }
      if(!pNewInstance || !pSink) {
	ATLASSERT (0);
	return WBEM_E_INVALID_PARAMETER;
      }
      CComPtr<IWbemClassObject> pEvtInstance;
      HRESULT hr = m_pCreationEventClass->SpawnInstance(0,&pEvtInstance);
      if(FAILED(hr)) return hr;
      VARIANT var;
      VariantInit(&var);
      var.vt = VT_UNKNOWN;
      CComQIPtr<IUnknown,&IID_IUnknown>pTemp(pNewInstance);
      var.punkVal = pTemp;
      hr = pEvtInstance->Put(L"TargetInstance",0,&var,0);
      if(FAILED(hr)) return hr;
      IWbemClassObject *_pEvtInstance = (IWbemClassObject*)pEvtInstance;
      return pSink->Indicate(1,&_pEvtInstance);
    }
    HRESULT WINAPI FireDeletionEvent(IWbemClassObject *pInstanceToDelete,IWbemObjectSink *pSink) {
      if(FAILED (m_hr)) {
	ATLASSERT (0);
	return m_hr;
      }
      if(!pInstanceToDelete || !pSink) {
	ATLASSERT (0);
	return WBEM_E_INVALID_PARAMETER;
      }
      CComPtr<IWbemClassObject> pEvtInstance;
      HRESULT hr = m_pDeletionEventClass->SpawnInstance(0,&pEvtInstance);
      if(FAILED(hr)) return hr;
      VARIANT var;
      VariantInit(&var);
      var.vt = VT_UNKNOWN;
      CComQIPtr<IUnknown,&IID_IUnknown>pTemp(pInstanceToDelete);
      var.punkVal = pTemp;
      hr = pEvtInstance->Put(L"TargetInstance",0,&var,0);
      if(FAILED(hr)) return hr;
      IWbemClassObject *_pEvtInstance = (IWbemClassObject*)pEvtInstance;
      return pSink->Indicate(1,&_pEvtInstance);
    }
    HRESULT WINAPI FireModificationEvent(IWbemClassObject *pOldInstance,IWbemClassObject *pNewInstance,IWbemObjectSink *pSink) {
      if(FAILED (m_hr)) {
	ATLASSERT (0);
	return m_hr;
      }
      if(!pOldInstance || !pNewInstance || !pSink) {
	ATLASSERT (0);
	return WBEM_E_INVALID_PARAMETER;
      }
      CComPtr<IWbemClassObject> pEvtInstance;
      HRESULT hr = m_pModificationEventClass->SpawnInstance(0,&pEvtInstance);
      if(FAILED(hr)) return hr;
      VARIANT var;
      VariantInit(&var);
      var.vt = VT_UNKNOWN;
      CComQIPtr<IUnknown,&IID_IUnknown>pTempNew(pNewInstance);
      var.punkVal = pTempNew;
      hr = pEvtInstance->Put(L"TargetInstance",0,&var,0);
      if(FAILED(hr)) return hr;
      CComQIPtr<IUnknown,&IID_IUnknown>pTempOld(pOldInstance);
      var.punkVal = pTempOld;
      hr = pEvtInstance->Put(L"PreviousInstance",0,&var,0);
      if(FAILED(hr)) return hr;
      IWbemClassObject *_pEvtInstance = (IWbemClassObject*)pEvtInstance;
      return pSink->Indicate(1,&_pEvtInstance);
    }
  };

  class CInstanceProviderHelper : public CProviderHelper {
  public:
    CInstanceProviderHelper (IWbemServices *pNamespace,IWbemContext *pCtx) : CProviderHelper (pNamespace,pCtx) { }
    virtual ~CInstanceProviderHelper() { }
    HRESULT WINAPI CheckInstancePath(IClassFactory *pParserFactory,const BSTR ObjectPath,const BSTR ClassName,ULONGLONG ullTest) {
      if(!pParserFactory) {
	ATLASSERT (0);
	return WBEM_E_INVALID_PARAMETER;
      }
      CComPtr<IWbemPath>pPath;
      HRESULT hr = pParserFactory->CreateInstance(NULL,IID_IWbemPath,(void **) &pPath);
      if(FAILED(hr)) return WBEM_E_INVALID_PARAMETER;
      hr = pPath->SetText(WBEMPATH_CREATE_ACCEPT_ALL,ObjectPath);
      if(FAILED(hr)) return hr;
      unsigned int nPathLen = SysStringLen(ObjectPath);
      if(nPathLen >= (unsigned __LONG32)(-1)) return HRESULT_FROM_WIN32(ERROR_ARITHMETIC_OVERFLOW);
      unsigned __LONG32 ulBufLen = (unsigned __LONG32)(nPathLen + 1);
      WCHAR *wClass = new WCHAR[ulBufLen];
      if(!wClass) return WBEM_E_OUT_OF_MEMORY;
      hr = pPath->GetClassName(&ulBufLen,wClass);
      if(FAILED(hr)) {
	delete[] wClass;
	return hr;
      }
      DWORD lcid = MAKELCID(MAKELANGID(LANG_ENGLISH,SUBLANG_ENGLISH_US),SORT_DEFAULT);
      if(CSTR_EQUAL!=CompareStringW(lcid,NORM_IGNORECASE,ClassName,-1,wClass,-1)) {
	delete[] wClass;
	return WBEM_E_NOT_FOUND;
      }
      delete[] wClass;
      __MINGW_EXTENSION unsigned __int64 ullPathInfo;
      hr = pPath->GetInfo((ULONG)0,&ullPathInfo);
      if(FAILED(hr)) return hr;
      if(!(ullPathInfo & ullTest)) return WBEM_E_INVALID_OBJECT_PATH;
      return WBEM_S_NO_ERROR;
    }
  };

  template <class T> class ATL_NO_VTABLE IWbemPullClassProviderImpl : public IWbemServices,public IWbemProviderInit {
  public:
    virtual HRESULT WINAPI OpenNamespace(const BSTR strNamespace,__LONG32 lFlags,IWbemContext *pCtx,IWbemServices **ppWorkingNamespace,IWbemCallResult **ppResult){return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI CancelAsyncCall(IWbemObjectSink *pSink){return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI QueryObjectSink(__LONG32 lFlags,IWbemObjectSink **ppResponseHandler) {return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI GetObject(const BSTR strObjectPath,__LONG32 lFlags,IWbemContext *pCtx,IWbemClassObject **ppObject,IWbemCallResult **ppCallResult) {return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI PutClass(IWbemClassObject *pObject,__LONG32 lFlags,IWbemContext *pCtx,IWbemCallResult **ppCallResult){return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI DeleteClass(const BSTR strClass,__LONG32 lFlags,IWbemContext *pCtx,IWbemCallResult **ppCallResult){return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI CreateClassEnum(const BSTR strSuperclass,__LONG32 lFlags,IWbemContext *pCtx,IEnumWbemClassObject **ppEnum) {return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI PutInstance(IWbemClassObject *pInst,__LONG32 lFlags,IWbemContext *pCtx,IWbemCallResult **ppCallResult){return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI PutInstanceAsync(IWbemClassObject *pInst,__LONG32 lFlags,IWbemContext *pCtx,IWbemObjectSink *pResponseHandler) {return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI DeleteInstance(const BSTR strObjectPath,__LONG32 lFlags,IWbemContext *pCtx,IWbemCallResult **ppCallResult){return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI DeleteInstanceAsync(const BSTR strObjectPath,__LONG32 lFlags,IWbemContext *pCtx,IWbemObjectSink *pResponseHandler){return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI CreateInstanceEnum(const BSTR strClass,__LONG32 lFlags,IWbemContext *pCtx,IEnumWbemClassObject **ppEnum) {return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI CreateInstanceEnumAsync(const BSTR strClass,__LONG32 lFlags,IWbemContext *pCtx,IWbemObjectSink *pResponseHandler) {return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI ExecQuery(const BSTR strQueryLanguage,const BSTR strQuery,__LONG32 lFlags,IWbemContext *pCtx,IEnumWbemClassObject **ppEnum) {return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI ExecNotificationQuery(const BSTR strQueryLanguage,const BSTR strQuery,__LONG32 lFlags,IWbemContext *pCtx,IEnumWbemClassObject **ppEnum) {return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI ExecNotificationQueryAsync(const BSTR strQueryLanguage,const BSTR strQuery,__LONG32 lFlags,IWbemContext *pCtx,IWbemObjectSink *pResponseHandler) {return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI ExecMethod(const BSTR strObjectPath,const BSTR strMethodName,__LONG32 lFlags,IWbemContext *pCtx,IWbemClassObject *pInParams,IWbemClassObject **ppOutParams,IWbemCallResult **ppCallResult) {return WBEM_E_NOT_SUPPORTED;};
    virtual HRESULT WINAPI ExecMethodAsync(const BSTR strObjectPath,const BSTR strMethodName,__LONG32 lFlags,IWbemContext *pCtx,IWbemClassObject *pInParams,IWbemObjectSink *pResponseHandler) {return WBEM_E_NOT_SUPPORTED;};
  };

  class CImpersonateClientHelper {
  private:
    WINBOOL m_bImpersonate;
  public:
    CImpersonateClientHelper() { m_bImpersonate = FALSE; }
    ~CImpersonateClientHelper() {
      if(m_bImpersonate)
	CoRevertToSelf();
    }
    HRESULT ImpersonateClient() {
      HRESULT hr = S_OK;
      if(SUCCEEDED(hr = CoImpersonateClient())) m_bImpersonate = TRUE;
      return hr;
    }
    HRESULT GetCurrentImpersonationLevel (DWORD & a_Level) {
      DWORD t_ImpersonationLevel = RPC_C_IMP_LEVEL_ANONYMOUS;
      HANDLE t_ThreadToken = NULL;
      HRESULT t_Result = S_OK;
      if(SUCCEEDED(t_Result = CoImpersonateClient())) {
	WINBOOL t_Status = OpenThreadToken (GetCurrentThread() ,TOKEN_QUERY,TRUE,&t_ThreadToken);
	if(t_Status) {
	  SECURITY_IMPERSONATION_LEVEL t_Level = SecurityAnonymous;
	  DWORD t_Returned = 0;
	  t_Status = GetTokenInformation (t_ThreadToken ,TokenImpersonationLevel ,&t_Level ,sizeof(SECURITY_IMPERSONATION_LEVEL),&t_Returned);
	  CloseHandle (t_ThreadToken);
	  if(t_Status==FALSE) {
	    t_Result = MAKE_HRESULT(SEVERITY_ERROR,FACILITY_WIN32,GetLastError());
	  } else {
	    switch(t_Level) {
	    case SecurityAnonymous:
	      {
		t_ImpersonationLevel = RPC_C_IMP_LEVEL_ANONYMOUS;
	      }
	      break;
	    case SecurityIdentification:
	      {
		t_ImpersonationLevel = RPC_C_IMP_LEVEL_IDENTIFY;
	      }
	      break;
	    case SecurityImpersonation:
	      {
		t_ImpersonationLevel = RPC_C_IMP_LEVEL_IMPERSONATE;
	      }
	      break;
	    case SecurityDelegation:
	      {
		t_ImpersonationLevel = RPC_C_IMP_LEVEL_DELEGATE;
	      }
	      break;
	    default:
	      {
		t_Result = MAKE_HRESULT(SEVERITY_ERROR,FACILITY_WIN32,E_UNEXPECTED);
	      }
	      break;
	    }
	  }
	} else {
	  t_Result = MAKE_HRESULT(SEVERITY_ERROR,FACILITY_WIN32,GetLastError());
	}
	CoRevertToSelf();
      }
      a_Level = t_ImpersonationLevel;
      return t_Result;
    }
  };
}
#endif
