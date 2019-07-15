/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSPSTRM_H_
#define _MSPSTRM_H_

#define STRM_INITIAL 0x00000000
#define STRM_TERMINALSELECTED 0x00000001
#define STRM_CONFIGURED 0x00000002
#define STRM_RUNNING 0x00000004
#define STRM_PAUSED 0x00000008
#define STRM_STOPPED 0x00000010

class CMSPStream;

class ATL_NO_VTABLE CPTEventSink : public CComObjectRootEx<CComMultiThreadModel>,public ITPluggableTerminalEventSink {
public:
  CPTEventSink();
  ~CPTEventSink();
  BEGIN_COM_MAP(CPTEventSink)
    COM_INTERFACE_ENTRY(ITPluggableTerminalEventSink)
  END_COM_MAP()
public:
  STDMETHOD(FireEvent)(const MSP_EVENT_INFO *pMspEventInfo);
public:
  HRESULT SetSinkStream(CMSPStream *pStream);
private:
  struct AsyncEventStruct {
    CMSPStream *pMSPStream;
    MSPEVENTITEM *pEventItem;
    AsyncEventStruct() : pMSPStream(NULL),pEventItem(NULL) {
      LOG((MSP_TRACE,"AsyncEventStruct::AsyncEventStruct[%p]",this));
    }
    ~AsyncEventStruct() {
      pMSPStream = NULL;
      pEventItem = NULL;
      LOG((MSP_TRACE,"AsyncEventStruct::~AsyncEventStruct[%p]",this));
    }
  };
  static DWORD WINAPI FireEventCallBack(LPVOID pEventStructure);
private:
  CMSPStream *m_pMSPStream;
};

class ATL_NO_VTABLE CMSPStream : public CComObjectRootEx<CComMultiThreadModelNoCS>,public IDispatchImpl<ITStream,&IID_ITStream,&LIBID_TAPI3Lib> {
public:
  BEGIN_COM_MAP(CMSPStream)
    COM_INTERFACE_ENTRY(IDispatch)
    COM_INTERFACE_ENTRY(ITStream)
    COM_INTERFACE_ENTRY_AGGREGATE(IID_IMarshal,m_pFTM)
  END_COM_MAP()
  DECLARE_GET_CONTROLLING_UNKNOWN()
  CMSPStream();
  ~CMSPStream();
  virtual void FinalRelease();
  STDMETHOD (get_MediaType) (__LONG32 *plMediaType);
  STDMETHOD (get_Direction) (TERMINAL_DIRECTION *pTerminalDirection);
  STDMETHOD (get_Name) (BSTR *ppName) = 0;
  STDMETHOD (SelectTerminal) (ITTerminal *pTerminal);
  STDMETHOD (UnselectTerminal) (ITTerminal *pTerminal);
  STDMETHOD (EnumerateTerminals) (IEnumTerminal **ppEnumTerminal);
  STDMETHOD (get_Terminals) (VARIANT *pTerminals);
  STDMETHOD (StartStream) ();
  STDMETHOD (PauseStream) ();
  STDMETHOD (StopStream) ();
  virtual HRESULT Init(HANDLE hAddress,CMSPCallBase *pMSPCall,IMediaEvent *pGraph,DWORD dwMediaType,TERMINAL_DIRECTION Direction);
  virtual HRESULT ShutDown();
  virtual HRESULT GetState(DWORD *pdwStatus) { return E_NOTIMPL; }
  virtual HRESULT HandleTSPData(BYTE *pData,DWORD dwSize);
  virtual HRESULT ProcessGraphEvent(__LONG32 lEventCode,LONG_PTR lParam1,LONG_PTR lParam2);
protected:
  HRESULT RegisterPluggableTerminalEventSink(ITTerminal *pTerminal);
  HRESULT UnregisterPluggableTerminalEventSink(ITTerminal *pTerminal);
  HRESULT ReleaseSink();
  ULONG InternalAddRef();
  ULONG InternalRelease();
public:
  HRESULT HandleSinkEvent(MSPEVENTITEM *pEventItem);
protected:
  IUnknown *m_pFTM;
  DWORD m_dwState;
  DWORD m_dwMediaType;
  TERMINAL_DIRECTION m_Direction;
  HANDLE m_hAddress;
  CMSPCallBase *m_pMSPCall;
  IGraphBuilder *m_pIGraphBuilder;
  IMediaControl *m_pIMediaControl;
  CMSPArray <ITTerminal *> m_Terminals;
  CMSPCritSection m_lock;
  CMSPCritSection m_lockRefCount;
  ITPluggableTerminalEventSink *m_pPTEventSink;
  __LONG32 m_lMyPersonalRefcount;
  WINBOOL m_bFirstAddRef;
};

#endif
