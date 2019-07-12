/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSPTRMAC_H_
#define _MSPTRMAC_H_

#define WAVEIN_NAME L"WaveIn Terminal"

#ifdef __cplusplus

class CAudioCaptureTerminal : public IDispatchImpl<ITBasicAudioTerminal,&IID_ITBasicAudioTerminal,&LIBID_TAPI3Lib>,public IDispatchImpl<ITStaticAudioTerminal,&IID_ITStaticAudioTerminal,&LIBID_TAPI3Lib>,public CSingleFilterStaticTerminal,public CMSPObjectSafetyImpl
{
  BEGIN_COM_MAP(CAudioCaptureTerminal)
    COM_INTERFACE_ENTRY(IObjectSafety)
    COM_INTERFACE_ENTRY(ITBasicAudioTerminal)
    COM_INTERFACE_ENTRY(ITStaticAudioTerminal)
    COM_INTERFACE_ENTRY_CHAIN(CSingleFilterStaticTerminal)
  END_COM_MAP()
  DECLARE_VQI()
  DECLARE_LOG_ADDREF_RELEASE(CAudioCaptureTerminal)
public:
  CAudioCaptureTerminal();
  virtual ~CAudioCaptureTerminal();
  static HRESULT CreateTerminal(CComPtr<IMoniker> pMoniker,MSP_HANDLE htAddress,ITTerminal **ppTerm);
  HRESULT FindTerminalPin();
public:
  STDMETHOD(get_Balance)(__LONG32 *pVal);
  STDMETHOD(put_Balance)(__LONG32 newVal);
  STDMETHOD(get_Volume) (__LONG32 *pVal);
  STDMETHOD(put_Volume) (__LONG32 newVal);
public:
  STDMETHOD(get_WaveId) (__LONG32 *plWaveId);
  STDMETHODIMP CompleteConnectTerminal(void);
  STDMETHODIMP DisconnectTerminal(IGraphBuilder *pGraph,DWORD dwReserved);
  virtual HRESULT AddFiltersToGraph();
  virtual DWORD GetSupportedMediaTypes(void) { return (DWORD) TAPIMEDIATYPE_AUDIO; }
  HRESULT CreateFilters();
  inline HRESULT CreateFiltersIfRequired();
private:
  bool m_bResourceReserved;
  CComPtr<IAMAudioInputMixer> m_pIAMAudioInputMixer;
};

inline HRESULT CAudioCaptureTerminal::CreateFiltersIfRequired() {
  if(!m_pIFilter) return CreateFilters();
  return S_OK;
}

#endif /* __cplusplus */

#endif
