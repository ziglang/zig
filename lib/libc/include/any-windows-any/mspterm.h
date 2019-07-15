/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSPTERM_H_
#define _MSPTERM_H_

template <class T> class ITTerminalVtblBase : public ITTerminal {
};

class CBaseTerminal : virtual public CComObjectRootEx<CComMultiThreadModelNoCS>,public IDispatchImpl<ITTerminalVtblBase<CBaseTerminal>,&IID_ITTerminal,&LIBID_TAPI3Lib>,public ITTerminalControl
{
  BEGIN_COM_MAP(CBaseTerminal)
    COM_INTERFACE_ENTRY(IDispatch)
    COM_INTERFACE_ENTRY(ITTerminal)
    COM_INTERFACE_ENTRY(ITTerminalControl)
    COM_INTERFACE_ENTRY_AGGREGATE(IID_IMarshal,m_pFTM)
  END_COM_MAP()
  DECLARE_VQI()
  DECLARE_GET_CONTROLLING_UNKNOWN()
public:
  CBaseTerminal();
  virtual ~CBaseTerminal();
public:
  STDMETHOD(get_TerminalClass)(BSTR *pVal);
  STDMETHOD(get_TerminalType)(TERMINAL_TYPE *pVal);
  STDMETHOD(get_State)(TERMINAL_STATE *pVal);
  STDMETHOD(get_Name)(BSTR *pVal);
  STDMETHOD(get_MediaType)(__LONG32 *plMediaType);
  STDMETHOD(get_Direction)(TERMINAL_DIRECTION *pDirection);
public:
  virtual HRESULT Initialize(IID iidTerminalClass,DWORD dwMediaType,TERMINAL_DIRECTION Direction,MSP_HANDLE htAddress);
public:
  STDMETHOD (get_AddressHandle)(MSP_HANDLE *phtAddress);
  STDMETHOD (ConnectTerminal)(IGraphBuilder *pGraph,DWORD dwTerminalDirection,DWORD *pdwNumPins,IPin **ppPins);
  STDMETHOD (CompleteConnectTerminal)(void);
  STDMETHOD (DisconnectTerminal)(IGraphBuilder *pGraph,DWORD dwReserved);
  STDMETHOD (RunRenderFilter)(void) = 0;
  STDMETHOD (StopRenderFilter)(void) = 0;
protected:
  CMSPCritSection m_CritSec;
public:
  TERMINAL_DIRECTION m_TerminalDirection;
  TERMINAL_TYPE m_TerminalType;
  TERMINAL_STATE m_TerminalState;
  TCHAR m_szName[MAX_PATH + 1];
  IID m_TerminalClassID;
  DWORD m_dwMediaType;
  MSP_HANDLE m_htAddress;
  IUnknown *m_pFTM;
  CComPtr<IGraphBuilder> m_pGraph;
  virtual HRESULT AddFiltersToGraph() = 0;
  virtual HRESULT ConnectFilters() { return S_OK; }
  virtual HRESULT GetNumExposedPins(IGraphBuilder *pGraph,DWORD *pdwNumPins) = 0;
  virtual HRESULT GetExposedPins(IPin **ppPins) = 0;
  virtual DWORD GetSupportedMediaTypes(void) = 0;
  virtual HRESULT RemoveFiltersFromGraph() = 0;
  WINBOOL MediaTypeSupported(__LONG32 lMediaType);
};

class CSingleFilterTerminal : public CBaseTerminal {
public:
  CComPtr<IPin> m_pIPin;
  CComPtr<IBaseFilter> m_pIFilter;
public:
  STDMETHOD(RunRenderFilter)(void);
  STDMETHOD(StopRenderFilter)(void);
  virtual HRESULT GetNumExposedPins(IGraphBuilder *pGraph,DWORD *pdwNumPins);
  virtual HRESULT GetExposedPins(IPin **ppPins);
  virtual HRESULT RemoveFiltersFromGraph();
};

class CSingleFilterStaticTerminal : public CSingleFilterTerminal {
public:
  CComPtr<IMoniker> m_pMoniker;
  WINBOOL m_bMark;
  virtual HRESULT CompareMoniker(IMoniker *pMoniker);
};
#endif
