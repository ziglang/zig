/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSPCOLL_H_
#define _MSPCOLL_H_

template <class T> class CTapiIfCollection : public IDispatchImpl<ITCollection,&IID_ITCollection,&LIBID_TAPI3Lib>,public CComObjectRootEx<CComMultiThreadModelNoCS>
{
public:
  typedef CTapiIfCollection<T> _CTapiCollectionBase;
  BEGIN_COM_MAP(_CTapiCollectionBase)
    COM_INTERFACE_ENTRY(IDispatch)
    COM_INTERFACE_ENTRY(ITCollection)
  END_COM_MAP()
private:
  int m_nSize;
  CComVariant *m_Var;

public:
  CTapiIfCollection(void) : m_nSize(0),m_Var(NULL) { }
  HRESULT WINAPI Initialize(DWORD dwSize,T *pBegin,T *pEnd) {
    int i;
    HRESULT hr;
    T *iter;
    LOG((MSP_TRACE,"CTapiCollection::Initialize - enter"));
    m_nSize = dwSize;
    m_Var = new CComVariant[m_nSize];
    if(!m_Var) return E_OUTOFMEMORY;
    i = 0;
    for(iter = pBegin;iter!=pEnd;iter++) {
      IDispatch *pDisp = NULL;
      hr = (*iter)->QueryInterface(IID_IDispatch,(void**)&pDisp);
      if(hr!=S_OK) return hr;
      CComVariant& var = m_Var[i];
      VariantInit(&var);
      var.vt = VT_DISPATCH;
      var.pdispVal = pDisp;
      i++;
    }
    LOG((MSP_TRACE,"CTapiCollection::Initialize - exit"));
    return S_OK;
  }
  void FinalRelease() {
    LOG((MSP_TRACE,"CTapiCollection::FinalRelease - enter"));
    delete [] m_Var;
    LOG((MSP_TRACE,"CTapiCollection::FinalRelease - exit"));
  }
  STDMETHOD(get_Count)(__LONG32 *retval) {
    HRESULT hr = S_OK;
    LOG((MSP_TRACE,"CTapiCollection::get_Count - enter"));
    try {
      *retval = m_nSize;
    } catch(...) {
      hr = E_INVALIDARG;
    }
    LOG((MSP_TRACE,"CTapiCollection::get_Count - exit"));
    return hr;
  }
  STDMETHOD(get_Item)(__LONG32 Index,VARIANT *retval) {
    HRESULT hr = S_OK;
    LOG((MSP_TRACE,"CTapiCollection::get_Item - enter"));
    if(!retval) return E_POINTER;
    try {
      VariantInit(retval);
    } catch(...) {
      hr = E_INVALIDARG;
    }
    if(hr!=S_OK) return hr;
    retval->vt = VT_UNKNOWN;
    retval->punkVal = NULL;
    if((Index < 1) || (Index > m_nSize)) return E_INVALIDARG;
    hr = VariantCopy(retval,&m_Var[Index-1]);
    if(FAILED(hr)) {
      LOG((MSP_ERROR,"CTapiCollection::get_Item - VariantCopy failed. hr = %lx",hr));
      return hr;
    }
    LOG((MSP_TRACE,"CTapiCollection::get_Item - exit"));
    return S_OK;
  }
  HRESULT WINAPI get__NewEnum(IUnknown **retval) {
    HRESULT hr;
    LOG((MSP_TRACE,"CTapiCollection::new__Enum - enter"));
    if(!retval) return E_POINTER;
    *retval = NULL;
    typedef CComObject<CSafeComEnum<IEnumVARIANT,&IID_IEnumVARIANT,VARIANT,_Copy<VARIANT> > > enumvar;
    enumvar *p;
    hr = enumvar::CreateInstance(&p);
    if(FAILED(hr)) return hr;
    hr = p->Init(&m_Var[0],&m_Var[m_nSize],NULL,AtlFlagCopy);
    if(SUCCEEDED(hr)) hr = p->QueryInterface(IID_IEnumVARIANT,(void**)retval);
    if(FAILED(hr)) delete p;
    LOG((MSP_TRACE,"CTapiCollection::new__Enum - exit"));
    return hr;
  }
};

class CTapiBstrCollection : public CComObjectRootEx<CComMultiThreadModelNoCS>,public IDispatchImpl<ITCollection,&IID_ITCollection,&LIBID_TAPI3Lib>,public CMSPObjectSafetyImpl
{
public:
  BEGIN_COM_MAP(CTapiBstrCollection)
    COM_INTERFACE_ENTRY(IDispatch)
    COM_INTERFACE_ENTRY(ITCollection)
    COM_INTERFACE_ENTRY(IObjectSafety)
  END_COM_MAP()
private:
  DWORD m_dwSize;
  CComVariant *m_Var;
public:
  CTapiBstrCollection(void) : m_dwSize(0),m_Var(NULL) { }
  HRESULT WINAPI Initialize(DWORD dwSize,BSTR *pBegin,BSTR *pEnd) {
    BSTR *i;
    DWORD dw = 0;
    LOG((MSP_TRACE,"CTapiBstrCollection::Initialize - enter"));
    m_dwSize = dwSize;
    m_Var = new CComVariant[m_dwSize];
    if(!m_Var) return E_OUTOFMEMORY;
    for(i = pBegin;i!=pEnd;i++) {
      CComVariant& var = m_Var[dw];
      var.vt = VT_BSTR;
      var.bstrVal = *i;
      dw++;
    }
    LOG((MSP_TRACE,"CTapiBstrCollection::Initialize - exit"));
    return S_OK;
  }
  STDMETHOD(get_Count)(__LONG32 *retval) {
    HRESULT hr = S_OK;
    LOG((MSP_TRACE,"CTapiBstrCollection::get_Count - enter"));
    try {
      *retval = m_dwSize;
    } catch(...) {
      hr = E_INVALIDARG;
    }
    LOG((MSP_TRACE,"CTapiBstrCollection::get_Count - exit"));
    return hr;
  }
  STDMETHOD(get_Item)(__LONG32 Index,VARIANT *retval) {
    HRESULT hr = S_OK;
    LOG((MSP_TRACE,"CTapiBstrCollection::get_Item - enter"));
    if(!retval) return E_POINTER;
    try {
      VariantInit(retval);
    } catch(...) {
      hr = E_INVALIDARG;
    }
    if(hr!=S_OK) return hr;
    retval->vt = VT_BSTR;
    retval->bstrVal = NULL;
    if((Index < 1) || ((DWORD) Index > m_dwSize)) return E_INVALIDARG;
    hr = VariantCopy(retval,&m_Var[Index-1]);
    if(FAILED(hr)) {
      LOG((MSP_ERROR,"CTapiBstrCollection::get_Item - VariantCopy failed. hr = %lx",hr));
      return hr;
    }
    LOG((MSP_TRACE,"CTapiBstrCollection::get_Item - exit"));
    return S_OK;
  }
  HRESULT WINAPI get__NewEnum(IUnknown **retval) {
    HRESULT hr;
    LOG((MSP_TRACE,"CTapiBstrCollection::get__NumEnum - enter"));
    if(!retval) return E_POINTER;
    *retval = NULL;
    typedef CComObject<CSafeComEnum<IEnumVARIANT,&IID_IEnumVARIANT,VARIANT,_Copy<VARIANT> > > enumvar;
    enumvar *p = new enumvar;
    if(!p) return E_OUTOFMEMORY;
    hr = p->Init(&m_Var[0],&m_Var[m_dwSize],NULL,AtlFlagCopy);
    if(SUCCEEDED(hr)) {
      hr = p->QueryInterface(IID_IEnumVARIANT,(void**)retval);
    }
    if(FAILED(hr)) delete p;
    LOG((MSP_TRACE,"CTapiBstrCollection::get__NewEnum - exit"));
    return hr;
  }
  void FinalRelease() {
    LOG((MSP_TRACE,"CTapiBstrCollection::FinalRelease() - enter"));
    delete [] m_Var;
    LOG((MSP_TRACE,"CTapiBstrCollection::FinalRelease() - exit"));
  }
};
#endif
