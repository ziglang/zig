/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSPTRMAR_H_
#define _MSPTRMAR_H_

#define WAVEOUT_NAME L"WaveOut Terminal"
#define MIXER_NAME L"PCM Mixer"

class CAudioRenderTerminal : public IDispatchImpl<ITBasicAudioTerminal,&IID_ITBasicAudioTerminal,&LIBID_TAPI3Lib>,public IDispatchImpl<ITStaticAudioTerminal,&IID_ITStaticAudioTerminal,&LIBID_TAPI3Lib>,public CSingleFilterStaticTerminal,public CMSPObjectSafetyImpl
{
public:
  CAudioRenderTerminal();
  virtual ~CAudioRenderTerminal();
  HRESULT InitializeDefaultTerminal();
  static HRESULT CreateTerminal(CComPtr<IMoniker> pMoniker,MSP_HANDLE htAddress,ITTerminal **ppTerm);
  HRESULT FindTerminalPin();
  BEGIN_COM_MAP(CAudioRenderTerminal)
    COM_INTERFACE_ENTRY(IObjectSafety)
    COM_INTERFACE_ENTRY(ITBasicAudioTerminal)
    COM_INTERFACE_ENTRY(ITStaticAudioTerminal)
    COM_INTERFACE_ENTRY_CHAIN(CSingleFilterStaticTerminal)
  END_COM_MAP()
  DECLARE_VQI()
  DECLARE_LOG_ADDREF_RELEASE(CAudioRenderTerminal)
public:
  STDMETHOD(get_Balance)(__LONG32 *pVal);
  STDMETHOD(put_Balance)(__LONG32 newVal);
  STDMETHOD(get_Volume)(__LONG32 *pVal);
  STDMETHOD(put_Volume)(__LONG32 newVal);
  STDMETHOD(get_WaveId) (__LONG32 *plWaveId);
public:
  STDMETHODIMP CompleteConnectTerminal(void);
  STDMETHODIMP DisconnectTerminal(IGraphBuilder *pGraph,DWORD dwReserved);
  virtual HRESULT AddFiltersToGraph();
  virtual DWORD GetSupportedMediaTypes(void) { return (DWORD) TAPIMEDIATYPE_AUDIO; }
  HRESULT CreateFilters();
private:
  bool m_bResourceReserved;
  CComPtr<IBasicAudio> m_pIBasicAudio;
};

#endif
