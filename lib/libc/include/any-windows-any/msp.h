/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __msp_h__
#define __msp_h__

#ifndef __ITPluggableTerminalEventSink_FWD_DEFINED__
#define __ITPluggableTerminalEventSink_FWD_DEFINED__
typedef struct ITPluggableTerminalEventSink ITPluggableTerminalEventSink;
#endif

#ifndef __ITPluggableTerminalEventSinkRegistration_FWD_DEFINED__
#define __ITPluggableTerminalEventSinkRegistration_FWD_DEFINED__
typedef struct ITPluggableTerminalEventSinkRegistration ITPluggableTerminalEventSinkRegistration;
#endif

#ifndef __ITMSPAddress_FWD_DEFINED__
#define __ITMSPAddress_FWD_DEFINED__
typedef struct ITMSPAddress ITMSPAddress;
#endif

#include "tapi3if.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef __LONG32 *MSP_HANDLE;

  typedef enum __MIDL___MIDL_itf_msp_0000_0001 {
    ADDRESS_TERMINAL_AVAILABLE = 0,ADDRESS_TERMINAL_UNAVAILABLE
  } MSP_ADDRESS_EVENT;

  typedef enum __MIDL___MIDL_itf_msp_0000_0002 {
    CALL_NEW_STREAM = 0,CALL_STREAM_FAIL,CALL_TERMINAL_FAIL,
    CALL_STREAM_NOT_USED,CALL_STREAM_ACTIVE,CALL_STREAM_INACTIVE
  } MSP_CALL_EVENT;

  typedef enum __MIDL___MIDL_itf_msp_0000_0003 {
    CALL_CAUSE_UNKNOWN = 0,CALL_CAUSE_BAD_DEVICE,CALL_CAUSE_CONNECT_FAIL,
    CALL_CAUSE_LOCAL_REQUEST,CALL_CAUSE_REMOTE_REQUEST,
    CALL_CAUSE_MEDIA_TIMEOUT,CALL_CAUSE_MEDIA_RECOVERED,
    CALL_CAUSE_QUALITY_OF_SERVICE
  } MSP_CALL_EVENT_CAUSE;

  typedef enum __MIDL___MIDL_itf_msp_0000_0004 {
    ME_ADDRESS_EVENT = 0,ME_CALL_EVENT,ME_TSP_DATA,ME_PRIVATE_EVENT,
    ME_ASR_TERMINAL_EVENT,ME_TTS_TERMINAL_EVENT,ME_FILE_TERMINAL_EVENT,
    ME_TONE_TERMINAL_EVENT
  } MSP_EVENT;

  typedef struct __MIDL___MIDL_itf_msp_0000_0005 {
    DWORD dwSize;
    MSP_EVENT Event;
    MSP_HANDLE hCall;
    __C89_NAMELESS union {
      struct {
	MSP_ADDRESS_EVENT Type;
	ITTerminal *pTerminal;
      } MSP_ADDRESS_EVENT_INFO;
      struct {
	MSP_CALL_EVENT Type;
	MSP_CALL_EVENT_CAUSE Cause;
	ITStream *pStream;
	ITTerminal *pTerminal;
	HRESULT hrError;
      } MSP_CALL_EVENT_INFO;
      struct {
	DWORD dwBufferSize;
	BYTE pBuffer[1 ];
      } MSP_TSP_DATA;
      struct {
	IDispatch *pEvent;
	__LONG32 lEventCode;
      } MSP_PRIVATE_EVENT_INFO;
      struct {
	ITTerminal *pParentFileTerminal;
	ITFileTrack *pFileTrack;
	TERMINAL_MEDIA_STATE TerminalMediaState;
	FT_STATE_EVENT_CAUSE ftecEventCause;
	HRESULT hrErrorCode;
      } MSP_FILE_TERMINAL_EVENT_INFO;
      struct {
	ITTerminal *pASRTerminal;
	HRESULT hrErrorCode;
      } MSP_ASR_TERMINAL_EVENT_INFO;
      struct {
	ITTerminal *pTTSTerminal;
	HRESULT hrErrorCode;
      } MSP_TTS_TERMINAL_EVENT_INFO;
      struct {
	ITTerminal *pToneTerminal;
	HRESULT hrErrorCode;
      } MSP_TONE_TERMINAL_EVENT_INFO;
    };
  } MSP_EVENT_INFO;

  extern RPC_IF_HANDLE __MIDL_itf_msp_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_msp_0000_v0_0_s_ifspec;

#ifndef __ITPluggableTerminalEventSink_INTERFACE_DEFINED__
#define __ITPluggableTerminalEventSink_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITPluggableTerminalEventSink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITPluggableTerminalEventSink : public IUnknown {
  public:
    virtual HRESULT WINAPI FireEvent(const MSP_EVENT_INFO *pMspEventInfo) = 0;
  };
#else
  typedef struct ITPluggableTerminalEventSinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITPluggableTerminalEventSink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITPluggableTerminalEventSink *This);
      ULONG (WINAPI *Release)(ITPluggableTerminalEventSink *This);
      HRESULT (WINAPI *FireEvent)(ITPluggableTerminalEventSink *This,const MSP_EVENT_INFO *pMspEventInfo);
    END_INTERFACE
  } ITPluggableTerminalEventSinkVtbl;
  struct ITPluggableTerminalEventSink {
    CONST_VTBL struct ITPluggableTerminalEventSinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITPluggableTerminalEventSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITPluggableTerminalEventSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITPluggableTerminalEventSink_Release(This) (This)->lpVtbl->Release(This)
#define ITPluggableTerminalEventSink_FireEvent(This,pMspEventInfo) (This)->lpVtbl->FireEvent(This,pMspEventInfo)
#endif
#endif
  HRESULT WINAPI ITPluggableTerminalEventSink_FireEvent_Proxy(ITPluggableTerminalEventSink *This,const MSP_EVENT_INFO *pMspEventInfo);
  void __RPC_STUB ITPluggableTerminalEventSink_FireEvent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITPluggableTerminalEventSinkRegistration_INTERFACE_DEFINED__
#define __ITPluggableTerminalEventSinkRegistration_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITPluggableTerminalEventSinkRegistration;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITPluggableTerminalEventSinkRegistration : public IUnknown {
  public:
    virtual HRESULT WINAPI RegisterSink(ITPluggableTerminalEventSink *pEventSink) = 0;
    virtual HRESULT WINAPI UnregisterSink(void) = 0;
  };
#else
  typedef struct ITPluggableTerminalEventSinkRegistrationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITPluggableTerminalEventSinkRegistration *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITPluggableTerminalEventSinkRegistration *This);
      ULONG (WINAPI *Release)(ITPluggableTerminalEventSinkRegistration *This);
      HRESULT (WINAPI *RegisterSink)(ITPluggableTerminalEventSinkRegistration *This,ITPluggableTerminalEventSink *pEventSink);
      HRESULT (WINAPI *UnregisterSink)(ITPluggableTerminalEventSinkRegistration *This);
    END_INTERFACE
  } ITPluggableTerminalEventSinkRegistrationVtbl;
  struct ITPluggableTerminalEventSinkRegistration {
    CONST_VTBL struct ITPluggableTerminalEventSinkRegistrationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITPluggableTerminalEventSinkRegistration_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITPluggableTerminalEventSinkRegistration_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITPluggableTerminalEventSinkRegistration_Release(This) (This)->lpVtbl->Release(This)
#define ITPluggableTerminalEventSinkRegistration_RegisterSink(This,pEventSink) (This)->lpVtbl->RegisterSink(This,pEventSink)
#define ITPluggableTerminalEventSinkRegistration_UnregisterSink(This) (This)->lpVtbl->UnregisterSink(This)
#endif
#endif
  HRESULT WINAPI ITPluggableTerminalEventSinkRegistration_RegisterSink_Proxy(ITPluggableTerminalEventSinkRegistration *This,ITPluggableTerminalEventSink *pEventSink);
  void __RPC_STUB ITPluggableTerminalEventSinkRegistration_RegisterSink_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalEventSinkRegistration_UnregisterSink_Proxy(ITPluggableTerminalEventSinkRegistration *This);
  void __RPC_STUB ITPluggableTerminalEventSinkRegistration_UnregisterSink_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITMSPAddress_INTERFACE_DEFINED__
#define __ITMSPAddress_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITMSPAddress;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITMSPAddress : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(MSP_HANDLE hEvent) = 0;
    virtual HRESULT WINAPI Shutdown(void) = 0;
    virtual HRESULT WINAPI CreateMSPCall(MSP_HANDLE hCall,DWORD dwReserved,DWORD dwMediaType,IUnknown *pOuterUnknown,IUnknown **ppStreamControl) = 0;
    virtual HRESULT WINAPI ShutdownMSPCall(IUnknown *pStreamControl) = 0;
    virtual HRESULT WINAPI ReceiveTSPData(IUnknown *pMSPCall,BYTE *pBuffer,DWORD dwSize) = 0;
    virtual HRESULT WINAPI GetEvent(DWORD *pdwSize,byte *pEventBuffer) = 0;
  };
#else
  typedef struct ITMSPAddressVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITMSPAddress *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITMSPAddress *This);
      ULONG (WINAPI *Release)(ITMSPAddress *This);
      HRESULT (WINAPI *Initialize)(ITMSPAddress *This,MSP_HANDLE hEvent);
      HRESULT (WINAPI *Shutdown)(ITMSPAddress *This);
      HRESULT (WINAPI *CreateMSPCall)(ITMSPAddress *This,MSP_HANDLE hCall,DWORD dwReserved,DWORD dwMediaType,IUnknown *pOuterUnknown,IUnknown **ppStreamControl);
      HRESULT (WINAPI *ShutdownMSPCall)(ITMSPAddress *This,IUnknown *pStreamControl);
      HRESULT (WINAPI *ReceiveTSPData)(ITMSPAddress *This,IUnknown *pMSPCall,BYTE *pBuffer,DWORD dwSize);
      HRESULT (WINAPI *GetEvent)(ITMSPAddress *This,DWORD *pdwSize,byte *pEventBuffer);
    END_INTERFACE
  } ITMSPAddressVtbl;
  struct ITMSPAddress {
    CONST_VTBL struct ITMSPAddressVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITMSPAddress_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITMSPAddress_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITMSPAddress_Release(This) (This)->lpVtbl->Release(This)
#define ITMSPAddress_Initialize(This,hEvent) (This)->lpVtbl->Initialize(This,hEvent)
#define ITMSPAddress_Shutdown(This) (This)->lpVtbl->Shutdown(This)
#define ITMSPAddress_CreateMSPCall(This,hCall,dwReserved,dwMediaType,pOuterUnknown,ppStreamControl) (This)->lpVtbl->CreateMSPCall(This,hCall,dwReserved,dwMediaType,pOuterUnknown,ppStreamControl)
#define ITMSPAddress_ShutdownMSPCall(This,pStreamControl) (This)->lpVtbl->ShutdownMSPCall(This,pStreamControl)
#define ITMSPAddress_ReceiveTSPData(This,pMSPCall,pBuffer,dwSize) (This)->lpVtbl->ReceiveTSPData(This,pMSPCall,pBuffer,dwSize)
#define ITMSPAddress_GetEvent(This,pdwSize,pEventBuffer) (This)->lpVtbl->GetEvent(This,pdwSize,pEventBuffer)
#endif
#endif
  HRESULT WINAPI ITMSPAddress_Initialize_Proxy(ITMSPAddress *This,MSP_HANDLE hEvent);
  void __RPC_STUB ITMSPAddress_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMSPAddress_Shutdown_Proxy(ITMSPAddress *This);
  void __RPC_STUB ITMSPAddress_Shutdown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMSPAddress_CreateMSPCall_Proxy(ITMSPAddress *This,MSP_HANDLE hCall,DWORD dwReserved,DWORD dwMediaType,IUnknown *pOuterUnknown,IUnknown **ppStreamControl);
  void __RPC_STUB ITMSPAddress_CreateMSPCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMSPAddress_ShutdownMSPCall_Proxy(ITMSPAddress *This,IUnknown *pStreamControl);
  void __RPC_STUB ITMSPAddress_ShutdownMSPCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMSPAddress_ReceiveTSPData_Proxy(ITMSPAddress *This,IUnknown *pMSPCall,BYTE *pBuffer,DWORD dwSize);
  void __RPC_STUB ITMSPAddress_ReceiveTSPData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMSPAddress_GetEvent_Proxy(ITMSPAddress *This,DWORD *pdwSize,byte *pEventBuffer);
  void __RPC_STUB ITMSPAddress_GetEvent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
