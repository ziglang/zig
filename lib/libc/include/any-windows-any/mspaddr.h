#ifndef __MSPADDR_H_
#define __MSPADDR_H_

typedef struct {
  LIST_ENTRY Link;
  MSP_EVENT_INFO MSPEventInfo;
} MSPEVENTITEM,*PMSPEVENTITEM;

MSPEVENTITEM *AllocateEventItem(SIZE_T nExtraBytes = 0);
WINBOOL FreeEventItem(MSPEVENTITEM *pEventItemToFree);

typedef HRESULT (*PFNCREATETERM)(CComPtr<IMoniker> pMoniker,MSP_HANDLE htAddress,ITTerminal **pTerm);

typedef struct {
  DWORD dwMediaType;
  const CLSID *clsidClassManager;
  PFNCREATETERM pfnCreateTerm;
} STATIC_TERMINAL_TYPE;

class ATL_NO_VTABLE CPlugTerminalClassInfo : public IDispatchImpl<ITPluggableTerminalClassInfo,&IID_ITPluggableTerminalClassInfo,&LIBID_TAPI3Lib>,public CComObjectRootEx<CComMultiThreadModel>,public CMSPObjectSafetyImpl
{
public:
  DECLARE_GET_CONTROLLING_UNKNOWN()
  virtual HRESULT FinalConstruct(void);
  BEGIN_COM_MAP(CPlugTerminalClassInfo)
    COM_INTERFACE_ENTRY(ITPluggableTerminalClassInfo)
    COM_INTERFACE_ENTRY(IDispatch)
    COM_INTERFACE_ENTRY(IObjectSafety)
    COM_INTERFACE_ENTRY_AGGREGATE(IID_IMarshal,m_pFTM)
  END_COM_MAP()
public:
  CPlugTerminalClassInfo() : m_bstrName(NULL),m_bstrCompany(NULL),m_bstrVersion(NULL),m_bstrCLSID(NULL),m_bstrTerminalClass(NULL),m_lMediaType(1),m_Direction(TD_CAPTURE),m_pFTM(NULL)
  {
  }
  ~CPlugTerminalClassInfo() {
    if(m_bstrName) {
      SysFreeString(m_bstrName);
    }
    if(m_bstrCompany) {
      SysFreeString(m_bstrCompany);
    }
    if(m_bstrVersion) {
      SysFreeString(m_bstrVersion);
    }
    if(m_bstrCLSID) {
      SysFreeString(m_bstrCLSID);
    }
    if(m_bstrTerminalClass) {
      SysFreeString(m_bstrTerminalClass);
    }
    if(m_pFTM) {
      m_pFTM->Release();
    }
  }
public:
  STDMETHOD(get_Name)(BSTR *pName);
  STDMETHOD(get_Company)(BSTR *pCompany);
  STDMETHOD(get_Version)(BSTR *pVersion);
  STDMETHOD(get_TerminalClass)(BSTR *pTerminalClass);
  STDMETHOD(get_CLSID)(BSTR *pCLSID);
  STDMETHOD(get_Direction)(TERMINAL_DIRECTION *pDirection);
  STDMETHOD(get_MediaTypes)(__LONG32 *pMediaTypes);
private:
  CMSPCritSection m_CritSect;
  BSTR m_bstrName;
  BSTR m_bstrCompany;
  BSTR m_bstrVersion;
  BSTR m_bstrTerminalClass;
  BSTR m_bstrCLSID;
  __LONG32 m_lMediaType;
  TERMINAL_DIRECTION m_Direction;
  IUnknown *m_pFTM;
private:
  STDMETHOD(put_Name)(BSTR bstrName);
  STDMETHOD(put_Company)(BSTR bstrCompany);
  STDMETHOD(put_Version)(BSTR bstrVersion);
  STDMETHOD(put_TerminalClass)(BSTR bstrTerminalClass);
  STDMETHOD(put_CLSID)(BSTR bstrCLSID);
  STDMETHOD(put_Direction)(TERMINAL_DIRECTION nDirection);
  STDMETHOD(put_MediaTypes)(__LONG32 nMediaTypes);
  friend class CMSPAddress;
};

class ATL_NO_VTABLE CPlugTerminalSuperclassInfo : public IDispatchImpl<ITPluggableTerminalSuperclassInfo,&IID_ITPluggableTerminalSuperclassInfo,&LIBID_TAPI3Lib>,public CComObjectRootEx<CComMultiThreadModel>,public CMSPObjectSafetyImpl
{
public:
  DECLARE_GET_CONTROLLING_UNKNOWN()
  virtual HRESULT FinalConstruct(void);
  BEGIN_COM_MAP(CPlugTerminalSuperclassInfo)
    COM_INTERFACE_ENTRY(ITPluggableTerminalSuperclassInfo)
    COM_INTERFACE_ENTRY(IDispatch)
    COM_INTERFACE_ENTRY(IObjectSafety)
    COM_INTERFACE_ENTRY_AGGREGATE(IID_IMarshal,m_pFTM)
  END_COM_MAP()
public:
  CPlugTerminalSuperclassInfo() : m_bstrCLSID(NULL),m_bstrName(NULL),m_pFTM(NULL) {
  }
  ~CPlugTerminalSuperclassInfo() {
    if(m_bstrName) {
      SysFreeString(m_bstrName);
    }
    if(m_bstrCLSID) {
      SysFreeString(m_bstrCLSID);
    }
    if(m_pFTM) {
      m_pFTM->Release();
    }
  }
public:
  STDMETHOD(get_Name)(BSTR *pName);
  STDMETHOD(get_CLSID)(BSTR *pCLSID);
private:
  CMSPCritSection m_CritSect;
  BSTR m_bstrCLSID;
  BSTR m_bstrName;
  IUnknown *m_pFTM;
private:
  STDMETHOD(put_Name)(BSTR bstrName);
  STDMETHOD(put_CLSID)(BSTR bstrCLSID);
  friend class CMSPAddress;
};

class ATL_NO_VTABLE CMSPAddress : public CComObjectRootEx<CComMultiThreadModelNoCS>,public ITMSPAddress,public IDispatchImpl<ITTerminalSupport2,&IID_ITTerminalSupport2,&LIBID_TAPI3Lib>
{
public:
  BEGIN_COM_MAP(CMSPAddress)
    COM_INTERFACE_ENTRY(ITMSPAddress)
    COM_INTERFACE_ENTRY(IDispatch)
    COM_INTERFACE_ENTRY(ITTerminalSupport)
    COM_INTERFACE_ENTRY(ITTerminalSupport2)
  END_COM_MAP()
  DECLARE_GET_CONTROLLING_UNKNOWN()
  DECLARE_VQI()
  CMSPAddress();
  virtual ~CMSPAddress();
  virtual ULONG MSPAddressAddRef(void) = 0;
  virtual ULONG MSPAddressRelease(void) = 0;
  STDMETHOD (Initialize) (MSP_HANDLE htEvent);
  STDMETHOD (Shutdown) ();
  STDMETHOD (CreateMSPCall) (MSP_HANDLE htCall,DWORD dwReserved,DWORD dwMediaType,IUnknown *pOuterUnknown,IUnknown **ppMSPCall) = 0;
  STDMETHOD (ShutdownMSPCall) (IUnknown *pMSPCall) = 0;
  STDMETHOD (ReceiveTSPData) (IUnknown *pMSPCall,LPBYTE pBuffer,DWORD dwBufferSize);
  STDMETHOD (GetEvent) (DWORD *pdwSize,BYTE *pBuffer);
  STDMETHOD (get_StaticTerminals) (VARIANT *pVariant);
  STDMETHOD (EnumerateStaticTerminals) (IEnumTerminal **ppTerminalEnumerator);
  STDMETHOD (get_DynamicTerminalClasses) (VARIANT *pVariant);
  STDMETHOD (EnumerateDynamicTerminalClasses) (IEnumTerminalClass **ppTerminalClassEnumerator);
  STDMETHOD (CreateTerminal) (BSTR pTerminalClass,__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal);
  STDMETHOD (GetDefaultStaticTerminal) (__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal);
  STDMETHOD (get_PluggableSuperclasses)(VARIANT *pVariant);
  STDMETHOD (EnumeratePluggableSuperclasses)(IEnumPluggableSuperclassInfo **ppSuperclassEnumerator);
  STDMETHOD (get_PluggableTerminalClasses)(BSTR bstrTerminalSuperclass,__LONG32 lMediaType,VARIANT *pVariant);
  STDMETHOD (EnumeratePluggableTerminalClasses)(CLSID iidTerminalSuperclass,__LONG32 lMediaType,IEnumPluggableTerminalClassInfo **ppClassEnumerator);
protected:
  virtual HRESULT GetStaticTerminals (DWORD *pdwNumTerminals,ITTerminal **ppTerminals);
  virtual HRESULT GetDynamicTerminalClasses (DWORD *pdwNumClasses,IID *pTerminalClasses);
public:
  virtual WINBOOL IsValidSetOfMediaTypes(DWORD dwMediaType,DWORD dwMask);
  virtual HRESULT PostEvent(MSPEVENTITEM *EventItem);
  virtual DWORD GetCallMediaTypes(void) = 0;
protected:
  virtual HRESULT IsMonikerInTerminalList(IMoniker *pMoniker);
  virtual HRESULT UpdateTerminalListForPnp(WINBOOL bDeviceArrival);
  virtual HRESULT UpdateTerminalList(void);
  virtual HRESULT ReceiveTSPAddressData(PBYTE pBuffer,DWORD dwSize);
public:
  virtual HRESULT PnpNotifHandler(WINBOOL bDeviceArrival);
protected:
  HANDLE m_htEvent;
  LIST_ENTRY m_EventList;
  CMSPCritSection m_EventDataLock;
  ITTerminalManager *m_pITTerminalManager;
  CMSPArray <ITTerminal *> m_Terminals;
  WINBOOL m_fTerminalsUpToDate;
  CMSPCritSection m_TerminalDataLock;
private:
  static const STATIC_TERMINAL_TYPE m_saTerminalTypes[];
  static const DWORD m_sdwTerminalTypesCount;
};

template <class T> HRESULT CreateMSPCallHelper(CMSPAddress *pCMSPAddress,MSP_HANDLE htCall,DWORD dwReserved,DWORD dwMediaType,IUnknown *pOuterUnknown,IUnknown **ppMSPCall,T **ppCMSPCall)
{
  LOG((MSP_TRACE,"CreateMSPCallHelper - enter"));
  HRESULT hr;
  T *pMSPCall;
  IUnknown *pUnknown = NULL;
  if(IsBadReadPtr(pCMSPAddress,sizeof(CMSPAddress))) {
    LOG((MSP_ERROR,"CreateMSPCallHelper - bad address pointer - exit E_POINTER"));
    return E_POINTER;
  }
  if(IsBadReadPtr(pOuterUnknown,sizeof(IUnknown))) {
    LOG((MSP_ERROR,"CreateMSPCallHelper - bad outer unknown - we require aggregation - exit E_POINTER"));
    return E_POINTER;
  }
  if(IsBadReadPtr(ppMSPCall,sizeof(IUnknown *))) {
    LOG((MSP_ERROR,"CreateMSPCallHelper - bad iunknown return ptr - exit E_POINTER"));
    return E_POINTER;
  }
  if(IsBadReadPtr(ppCMSPCall,sizeof(T *))) {
    LOG((MSP_ERROR,"CreateMSPCallHelper - bad class return ptr - exit E_POINTER"));
    return E_POINTER;
  }
  if(! pCMSPAddress->IsValidSetOfMediaTypes(dwMediaType,pCMSPAddress->GetCallMediaTypes())) {
    LOG((MSP_ERROR,"CreateMSPCallHelper - unsupported media types - exit TAPI_E_INVALIDMEDIATYPE"));
    return TAPI_E_INVALIDMEDIATYPE;
  }
  CComAggObject<T> *pCall;
  pCall = new CComAggObject<T>(pOuterUnknown);
  if(!pCall) {
    LOG((MSP_ERROR,"CreateMSPCallHelper - could not create agg call instance - exit E_OUTOFMEMORY"));
    return E_OUTOFMEMORY;
  }
  hr = pCall->QueryInterface(IID_IUnknown,(void **)&pUnknown);
  if(FAILED(hr)) {
    LOG((MSP_ERROR,"CreateMSPCallHelper - QueryInterface failed: %x",hr));
    delete pCall;
    return hr;
  }
  hr = pCall->FinalConstruct();
  if(FAILED(hr)) {
    LOG((MSP_ERROR,"CreateMSPCallHelper - FinalConstruct failed: %x.",hr));
    pUnknown->Release();
    return hr;
  }
  pMSPCall = dynamic_cast<T *>(&(pCall->m_contained));
  if(!pMSPCall) {
    LOG((MSP_ERROR,"CreateMSPCallHelper - can not cast to agg object to class pointer - exit E_UNEXPECTED"));
    pUnknown->Release();
    return E_UNEXPECTED;
  }
  hr = pMSPCall->Init(pCMSPAddress,htCall,dwReserved,dwMediaType);
  if(FAILED(hr)) {
    LOG((MSP_ERROR,"CreateMSPCallHelper - call init failed: %x",hr));
    pUnknown->Release();
    return hr;
  }
  *ppMSPCall = pUnknown;
  *ppCMSPCall = pMSPCall;
  LOG((MSP_TRACE,"CreateMSPCallHelper - exit S_OK"));
  return hr;
}

template <class T> HRESULT ShutdownMSPCallHelper(IUnknown *pUnknown,T **ppCMSPCall)
{
  LOG((MSP_TRACE,"ShutdownMSPCallHelper - enter"));
  if(IsBadReadPtr(pUnknown,sizeof(IUnknown))) {
    LOG((MSP_ERROR,"ShutdownMSPCallHelper - bad IUnknown pointer - exit E_POINTER"));
    return E_POINTER;
  }
  if(IsBadWritePtr(ppCMSPCall,sizeof(T *))) {
    LOG((MSP_ERROR,"ShutdownMSPCallHelper - bad return pointer - exit E_POINTER"));
    return E_POINTER;
  }
  T *pMSPCall;
  CComAggObject<T> *pCall = dynamic_cast<CComAggObject<T> *> (pUnknown);
  if(!pCall) {
    LOG((MSP_ERROR,"ShutdownMSPCallHelper - can't cast unknown to agg object pointer - exit E_UNEXPECTED"));
    return E_UNEXPECTED;
  }
  pMSPCall = dynamic_cast<T *> (&(pCall->m_contained));
  if(!pMSPCall) {
    LOG((MSP_ERROR,"ShutdownMSPCallHelper - can't cast contained unknown to class pointer - exit E_UNEXPECTED"));
    return E_UNEXPECTED;
  }
  HRESULT hr = pMSPCall->ShutDown();
  if(FAILED(hr)) {
    LOG((MSP_ERROR,"ShutdownMSPCallHelper - ShutDownMSPCall failed: %x",hr));
    return hr;
  }
  *ppCMSPCall = pMSPCall;
  LOG((MSP_TRACE,"ShutdownMSPCallHelper - exit S_OK"));
  return S_OK;
}
#endif
