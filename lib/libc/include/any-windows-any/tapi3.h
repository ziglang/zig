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

#ifndef __tapi3_h__
#define __tapi3_h__

#ifndef __ITAgent_FWD_DEFINED__
#define __ITAgent_FWD_DEFINED__
typedef struct ITAgent ITAgent;
#endif

#ifndef __ITAgentSession_FWD_DEFINED__
#define __ITAgentSession_FWD_DEFINED__
typedef struct ITAgentSession ITAgentSession;
#endif

#ifndef __ITACDGroup_FWD_DEFINED__
#define __ITACDGroup_FWD_DEFINED__
typedef struct ITACDGroup ITACDGroup;
#endif

#ifndef __ITQueue_FWD_DEFINED__
#define __ITQueue_FWD_DEFINED__
typedef struct ITQueue ITQueue;
#endif

#ifndef __ITAgentEvent_FWD_DEFINED__
#define __ITAgentEvent_FWD_DEFINED__
typedef struct ITAgentEvent ITAgentEvent;
#endif

#ifndef __ITAgentSessionEvent_FWD_DEFINED__
#define __ITAgentSessionEvent_FWD_DEFINED__
typedef struct ITAgentSessionEvent ITAgentSessionEvent;
#endif

#ifndef __ITACDGroupEvent_FWD_DEFINED__
#define __ITACDGroupEvent_FWD_DEFINED__
typedef struct ITACDGroupEvent ITACDGroupEvent;
#endif

#ifndef __ITQueueEvent_FWD_DEFINED__
#define __ITQueueEvent_FWD_DEFINED__
typedef struct ITQueueEvent ITQueueEvent;
#endif

#ifndef __ITAgentHandlerEvent_FWD_DEFINED__
#define __ITAgentHandlerEvent_FWD_DEFINED__
typedef struct ITAgentHandlerEvent ITAgentHandlerEvent;
#endif

#ifndef __ITTAPICallCenter_FWD_DEFINED__
#define __ITTAPICallCenter_FWD_DEFINED__
typedef struct ITTAPICallCenter ITTAPICallCenter;
#endif

#ifndef __ITAgentHandler_FWD_DEFINED__
#define __ITAgentHandler_FWD_DEFINED__
typedef struct ITAgentHandler ITAgentHandler;
#endif

#ifndef __IEnumAgent_FWD_DEFINED__
#define __IEnumAgent_FWD_DEFINED__
typedef struct IEnumAgent IEnumAgent;
#endif

#ifndef __IEnumAgentSession_FWD_DEFINED__
#define __IEnumAgentSession_FWD_DEFINED__
typedef struct IEnumAgentSession IEnumAgentSession;
#endif

#ifndef __IEnumQueue_FWD_DEFINED__
#define __IEnumQueue_FWD_DEFINED__
typedef struct IEnumQueue IEnumQueue;
#endif

#ifndef __IEnumACDGroup_FWD_DEFINED__
#define __IEnumACDGroup_FWD_DEFINED__
typedef struct IEnumACDGroup IEnumACDGroup;
#endif

#ifndef __IEnumAgentHandler_FWD_DEFINED__
#define __IEnumAgentHandler_FWD_DEFINED__
typedef struct IEnumAgentHandler IEnumAgentHandler;
#endif

#ifndef __ITAMMediaFormat_FWD_DEFINED__
#define __ITAMMediaFormat_FWD_DEFINED__
typedef struct ITAMMediaFormat ITAMMediaFormat;
#endif

#ifndef __ITAllocatorProperties_FWD_DEFINED__
#define __ITAllocatorProperties_FWD_DEFINED__
typedef struct ITAllocatorProperties ITAllocatorProperties;
#endif

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

#ifndef __ITAgent_FWD_DEFINED__
#define __ITAgent_FWD_DEFINED__
typedef struct ITAgent ITAgent;
#endif

#ifndef __ITAgentEvent_FWD_DEFINED__
#define __ITAgentEvent_FWD_DEFINED__
typedef struct ITAgentEvent ITAgentEvent;
#endif

#ifndef __ITAgentSession_FWD_DEFINED__
#define __ITAgentSession_FWD_DEFINED__
typedef struct ITAgentSession ITAgentSession;
#endif

#ifndef __ITAgentSessionEvent_FWD_DEFINED__
#define __ITAgentSessionEvent_FWD_DEFINED__
typedef struct ITAgentSessionEvent ITAgentSessionEvent;
#endif

#ifndef __ITACDGroup_FWD_DEFINED__
#define __ITACDGroup_FWD_DEFINED__
typedef struct ITACDGroup ITACDGroup;
#endif

#ifndef __ITACDGroupEvent_FWD_DEFINED__
#define __ITACDGroupEvent_FWD_DEFINED__
typedef struct ITACDGroupEvent ITACDGroupEvent;
#endif

#ifndef __ITQueue_FWD_DEFINED__
#define __ITQueue_FWD_DEFINED__
typedef struct ITQueue ITQueue;
#endif

#ifndef __ITQueueEvent_FWD_DEFINED__
#define __ITQueueEvent_FWD_DEFINED__
typedef struct ITQueueEvent ITQueueEvent;
#endif

#ifndef __ITTAPICallCenter_FWD_DEFINED__
#define __ITTAPICallCenter_FWD_DEFINED__
typedef struct ITTAPICallCenter ITTAPICallCenter;
#endif

#ifndef __ITAgentHandler_FWD_DEFINED__
#define __ITAgentHandler_FWD_DEFINED__
typedef struct ITAgentHandler ITAgentHandler;
#endif

#ifndef __ITAgentHandlerEvent_FWD_DEFINED__
#define __ITAgentHandlerEvent_FWD_DEFINED__
typedef struct ITAgentHandlerEvent ITAgentHandlerEvent;
#endif

#ifndef __ITTAPIDispatchEventNotification_FWD_DEFINED__
#define __ITTAPIDispatchEventNotification_FWD_DEFINED__
typedef struct ITTAPIDispatchEventNotification ITTAPIDispatchEventNotification;
#endif

#ifndef __TAPI_FWD_DEFINED__
#define __TAPI_FWD_DEFINED__

#ifdef __cplusplus
typedef class TAPI TAPI;
#else
typedef struct TAPI TAPI;
#endif
#endif

#ifndef __DispatchMapper_FWD_DEFINED__
#define __DispatchMapper_FWD_DEFINED__
#ifdef __cplusplus
typedef class DispatchMapper DispatchMapper;
#else
typedef struct DispatchMapper DispatchMapper;
#endif
#endif

#ifndef __RequestMakeCall_FWD_DEFINED__
#define __RequestMakeCall_FWD_DEFINED__
#ifdef __cplusplus
typedef class RequestMakeCall RequestMakeCall;
#else
typedef struct RequestMakeCall RequestMakeCall;
#endif
#endif

#ifndef __ITTAPIDispatchEventNotification_FWD_DEFINED__
#define __ITTAPIDispatchEventNotification_FWD_DEFINED__
typedef struct ITTAPIDispatchEventNotification ITTAPIDispatchEventNotification;
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "tapi3if.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef enum AGENT_EVENT {
    AE_NOT_READY = 0,
    AE_READY,AE_BUSY_ACD,AE_BUSY_INCOMING,AE_BUSY_OUTGOING,AE_UNKNOWN
  } AGENT_EVENT;

  typedef enum AGENT_STATE {
    AS_NOT_READY = 0,
    AS_READY,AS_BUSY_ACD,AS_BUSY_INCOMING,AS_BUSY_OUTGOING,AS_UNKNOWN
  } AGENT_STATE;

  typedef enum AGENT_SESSION_EVENT {
    ASE_NEW_SESSION = 0,
    ASE_NOT_READY,ASE_READY,ASE_BUSY,ASE_WRAPUP,ASE_END
  } AGENT_SESSION_EVENT;

  typedef enum AGENT_SESSION_STATE {
    ASST_NOT_READY = 0,
    ASST_READY,ASST_BUSY_ON_CALL,ASST_BUSY_WRAPUP,ASST_SESSION_ENDED
  } AGENT_SESSION_STATE;

  typedef enum AGENTHANDLER_EVENT {
    AHE_NEW_AGENTHANDLER = 0,
    AHE_AGENTHANDLER_REMOVED
  } AGENTHANDLER_EVENT;

  typedef enum ACDGROUP_EVENT {
    ACDGE_NEW_GROUP = 0,
    ACDGE_GROUP_REMOVED
  } ACDGROUP_EVENT;

  typedef enum ACDQUEUE_EVENT {
    ACDQE_NEW_QUEUE = 0,
    ACDQE_QUEUE_REMOVED
  } ACDQUEUE_EVENT;

  extern RPC_IF_HANDLE __MIDL_itf_tapi3_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_tapi3_0000_v0_0_s_ifspec;
#ifndef __ITAgent_INTERFACE_DEFINED__
#define __ITAgent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAgent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAgent : public IDispatch {
  public:
    virtual HRESULT WINAPI EnumerateAgentSessions(IEnumAgentSession **ppEnumAgentSession) = 0;
    virtual HRESULT WINAPI CreateSession(ITACDGroup *pACDGroup,ITAddress *pAddress,ITAgentSession **ppAgentSession) = 0;
    virtual HRESULT WINAPI CreateSessionWithPIN(ITACDGroup *pACDGroup,ITAddress *pAddress,BSTR pPIN,ITAgentSession **ppAgentSession) = 0;
    virtual HRESULT WINAPI get_ID(BSTR *ppID) = 0;
    virtual HRESULT WINAPI get_User(BSTR *ppUser) = 0;
    virtual HRESULT WINAPI put_State(AGENT_STATE AgentState) = 0;
    virtual HRESULT WINAPI get_State(AGENT_STATE *pAgentState) = 0;
    virtual HRESULT WINAPI put_MeasurementPeriod(__LONG32 lPeriod) = 0;
    virtual HRESULT WINAPI get_MeasurementPeriod(__LONG32 *plPeriod) = 0;
    virtual HRESULT WINAPI get_OverallCallRate(CURRENCY *pcyCallrate) = 0;
    virtual HRESULT WINAPI get_NumberOfACDCalls(__LONG32 *plCalls) = 0;
    virtual HRESULT WINAPI get_NumberOfIncomingCalls(__LONG32 *plCalls) = 0;
    virtual HRESULT WINAPI get_NumberOfOutgoingCalls(__LONG32 *plCalls) = 0;
    virtual HRESULT WINAPI get_TotalACDTalkTime(__LONG32 *plTalkTime) = 0;
    virtual HRESULT WINAPI get_TotalACDCallTime(__LONG32 *plCallTime) = 0;
    virtual HRESULT WINAPI get_TotalWrapUpTime(__LONG32 *plWrapUpTime) = 0;
    virtual HRESULT WINAPI get_AgentSessions(VARIANT *pVariant) = 0;
  };
#else
  typedef struct ITAgentVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAgent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAgent *This);
      ULONG (WINAPI *Release)(ITAgent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAgent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAgent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAgent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAgent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *EnumerateAgentSessions)(ITAgent *This,IEnumAgentSession **ppEnumAgentSession);
      HRESULT (WINAPI *CreateSession)(ITAgent *This,ITACDGroup *pACDGroup,ITAddress *pAddress,ITAgentSession **ppAgentSession);
      HRESULT (WINAPI *CreateSessionWithPIN)(ITAgent *This,ITACDGroup *pACDGroup,ITAddress *pAddress,BSTR pPIN,ITAgentSession **ppAgentSession);
      HRESULT (WINAPI *get_ID)(ITAgent *This,BSTR *ppID);
      HRESULT (WINAPI *get_User)(ITAgent *This,BSTR *ppUser);
      HRESULT (WINAPI *put_State)(ITAgent *This,AGENT_STATE AgentState);
      HRESULT (WINAPI *get_State)(ITAgent *This,AGENT_STATE *pAgentState);
      HRESULT (WINAPI *put_MeasurementPeriod)(ITAgent *This,__LONG32 lPeriod);
      HRESULT (WINAPI *get_MeasurementPeriod)(ITAgent *This,__LONG32 *plPeriod);
      HRESULT (WINAPI *get_OverallCallRate)(ITAgent *This,CURRENCY *pcyCallrate);
      HRESULT (WINAPI *get_NumberOfACDCalls)(ITAgent *This,__LONG32 *plCalls);
      HRESULT (WINAPI *get_NumberOfIncomingCalls)(ITAgent *This,__LONG32 *plCalls);
      HRESULT (WINAPI *get_NumberOfOutgoingCalls)(ITAgent *This,__LONG32 *plCalls);
      HRESULT (WINAPI *get_TotalACDTalkTime)(ITAgent *This,__LONG32 *plTalkTime);
      HRESULT (WINAPI *get_TotalACDCallTime)(ITAgent *This,__LONG32 *plCallTime);
      HRESULT (WINAPI *get_TotalWrapUpTime)(ITAgent *This,__LONG32 *plWrapUpTime);
      HRESULT (WINAPI *get_AgentSessions)(ITAgent *This,VARIANT *pVariant);
    END_INTERFACE
  } ITAgentVtbl;
  struct ITAgent {
    CONST_VTBL struct ITAgentVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAgent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAgent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAgent_Release(This) (This)->lpVtbl->Release(This)
#define ITAgent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAgent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAgent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAgent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAgent_EnumerateAgentSessions(This,ppEnumAgentSession) (This)->lpVtbl->EnumerateAgentSessions(This,ppEnumAgentSession)
#define ITAgent_CreateSession(This,pACDGroup,pAddress,ppAgentSession) (This)->lpVtbl->CreateSession(This,pACDGroup,pAddress,ppAgentSession)
#define ITAgent_CreateSessionWithPIN(This,pACDGroup,pAddress,pPIN,ppAgentSession) (This)->lpVtbl->CreateSessionWithPIN(This,pACDGroup,pAddress,pPIN,ppAgentSession)
#define ITAgent_get_ID(This,ppID) (This)->lpVtbl->get_ID(This,ppID)
#define ITAgent_get_User(This,ppUser) (This)->lpVtbl->get_User(This,ppUser)
#define ITAgent_put_State(This,AgentState) (This)->lpVtbl->put_State(This,AgentState)
#define ITAgent_get_State(This,pAgentState) (This)->lpVtbl->get_State(This,pAgentState)
#define ITAgent_put_MeasurementPeriod(This,lPeriod) (This)->lpVtbl->put_MeasurementPeriod(This,lPeriod)
#define ITAgent_get_MeasurementPeriod(This,plPeriod) (This)->lpVtbl->get_MeasurementPeriod(This,plPeriod)
#define ITAgent_get_OverallCallRate(This,pcyCallrate) (This)->lpVtbl->get_OverallCallRate(This,pcyCallrate)
#define ITAgent_get_NumberOfACDCalls(This,plCalls) (This)->lpVtbl->get_NumberOfACDCalls(This,plCalls)
#define ITAgent_get_NumberOfIncomingCalls(This,plCalls) (This)->lpVtbl->get_NumberOfIncomingCalls(This,plCalls)
#define ITAgent_get_NumberOfOutgoingCalls(This,plCalls) (This)->lpVtbl->get_NumberOfOutgoingCalls(This,plCalls)
#define ITAgent_get_TotalACDTalkTime(This,plTalkTime) (This)->lpVtbl->get_TotalACDTalkTime(This,plTalkTime)
#define ITAgent_get_TotalACDCallTime(This,plCallTime) (This)->lpVtbl->get_TotalACDCallTime(This,plCallTime)
#define ITAgent_get_TotalWrapUpTime(This,plWrapUpTime) (This)->lpVtbl->get_TotalWrapUpTime(This,plWrapUpTime)
#define ITAgent_get_AgentSessions(This,pVariant) (This)->lpVtbl->get_AgentSessions(This,pVariant)
#endif
#endif
  HRESULT WINAPI ITAgent_EnumerateAgentSessions_Proxy(ITAgent *This,IEnumAgentSession **ppEnumAgentSession);
  void __RPC_STUB ITAgent_EnumerateAgentSessions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_CreateSession_Proxy(ITAgent *This,ITACDGroup *pACDGroup,ITAddress *pAddress,ITAgentSession **ppAgentSession);
  void __RPC_STUB ITAgent_CreateSession_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_CreateSessionWithPIN_Proxy(ITAgent *This,ITACDGroup *pACDGroup,ITAddress *pAddress,BSTR pPIN,ITAgentSession **ppAgentSession);
  void __RPC_STUB ITAgent_CreateSessionWithPIN_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_ID_Proxy(ITAgent *This,BSTR *ppID);
  void __RPC_STUB ITAgent_get_ID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_User_Proxy(ITAgent *This,BSTR *ppUser);
  void __RPC_STUB ITAgent_get_User_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_put_State_Proxy(ITAgent *This,AGENT_STATE AgentState);
  void __RPC_STUB ITAgent_put_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_State_Proxy(ITAgent *This,AGENT_STATE *pAgentState);
  void __RPC_STUB ITAgent_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_put_MeasurementPeriod_Proxy(ITAgent *This,__LONG32 lPeriod);
  void __RPC_STUB ITAgent_put_MeasurementPeriod_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_MeasurementPeriod_Proxy(ITAgent *This,__LONG32 *plPeriod);
  void __RPC_STUB ITAgent_get_MeasurementPeriod_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_OverallCallRate_Proxy(ITAgent *This,CURRENCY *pcyCallrate);
  void __RPC_STUB ITAgent_get_OverallCallRate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_NumberOfACDCalls_Proxy(ITAgent *This,__LONG32 *plCalls);
  void __RPC_STUB ITAgent_get_NumberOfACDCalls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_NumberOfIncomingCalls_Proxy(ITAgent *This,__LONG32 *plCalls);
  void __RPC_STUB ITAgent_get_NumberOfIncomingCalls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_NumberOfOutgoingCalls_Proxy(ITAgent *This,__LONG32 *plCalls);
  void __RPC_STUB ITAgent_get_NumberOfOutgoingCalls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_TotalACDTalkTime_Proxy(ITAgent *This,__LONG32 *plTalkTime);
  void __RPC_STUB ITAgent_get_TotalACDTalkTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_TotalACDCallTime_Proxy(ITAgent *This,__LONG32 *plCallTime);
  void __RPC_STUB ITAgent_get_TotalACDCallTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_TotalWrapUpTime_Proxy(ITAgent *This,__LONG32 *plWrapUpTime);
  void __RPC_STUB ITAgent_get_TotalWrapUpTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgent_get_AgentSessions_Proxy(ITAgent *This,VARIANT *pVariant);
  void __RPC_STUB ITAgent_get_AgentSessions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAgentSession_INTERFACE_DEFINED__
#define __ITAgentSession_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAgentSession;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAgentSession : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Agent(ITAgent **ppAgent) = 0;
    virtual HRESULT WINAPI get_Address(ITAddress **ppAddress) = 0;
    virtual HRESULT WINAPI get_ACDGroup(ITACDGroup **ppACDGroup) = 0;
    virtual HRESULT WINAPI put_State(AGENT_SESSION_STATE SessionState) = 0;
    virtual HRESULT WINAPI get_State(AGENT_SESSION_STATE *pSessionState) = 0;
    virtual HRESULT WINAPI get_SessionStartTime(DATE *pdateSessionStart) = 0;
    virtual HRESULT WINAPI get_SessionDuration(__LONG32 *plDuration) = 0;
    virtual HRESULT WINAPI get_NumberOfCalls(__LONG32 *plCalls) = 0;
    virtual HRESULT WINAPI get_TotalTalkTime(__LONG32 *plTalkTime) = 0;
    virtual HRESULT WINAPI get_AverageTalkTime(__LONG32 *plTalkTime) = 0;
    virtual HRESULT WINAPI get_TotalCallTime(__LONG32 *plCallTime) = 0;
    virtual HRESULT WINAPI get_AverageCallTime(__LONG32 *plCallTime) = 0;
    virtual HRESULT WINAPI get_TotalWrapUpTime(__LONG32 *plWrapUpTime) = 0;
    virtual HRESULT WINAPI get_AverageWrapUpTime(__LONG32 *plWrapUpTime) = 0;
    virtual HRESULT WINAPI get_ACDCallRate(CURRENCY *pcyCallrate) = 0;
    virtual HRESULT WINAPI get_LongestTimeToAnswer(__LONG32 *plAnswerTime) = 0;
    virtual HRESULT WINAPI get_AverageTimeToAnswer(__LONG32 *plAnswerTime) = 0;
  };
#else
  typedef struct ITAgentSessionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAgentSession *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAgentSession *This);
      ULONG (WINAPI *Release)(ITAgentSession *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAgentSession *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAgentSession *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAgentSession *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAgentSession *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Agent)(ITAgentSession *This,ITAgent **ppAgent);
      HRESULT (WINAPI *get_Address)(ITAgentSession *This,ITAddress **ppAddress);
      HRESULT (WINAPI *get_ACDGroup)(ITAgentSession *This,ITACDGroup **ppACDGroup);
      HRESULT (WINAPI *put_State)(ITAgentSession *This,AGENT_SESSION_STATE SessionState);
      HRESULT (WINAPI *get_State)(ITAgentSession *This,AGENT_SESSION_STATE *pSessionState);
      HRESULT (WINAPI *get_SessionStartTime)(ITAgentSession *This,DATE *pdateSessionStart);
      HRESULT (WINAPI *get_SessionDuration)(ITAgentSession *This,__LONG32 *plDuration);
      HRESULT (WINAPI *get_NumberOfCalls)(ITAgentSession *This,__LONG32 *plCalls);
      HRESULT (WINAPI *get_TotalTalkTime)(ITAgentSession *This,__LONG32 *plTalkTime);
      HRESULT (WINAPI *get_AverageTalkTime)(ITAgentSession *This,__LONG32 *plTalkTime);
      HRESULT (WINAPI *get_TotalCallTime)(ITAgentSession *This,__LONG32 *plCallTime);
      HRESULT (WINAPI *get_AverageCallTime)(ITAgentSession *This,__LONG32 *plCallTime);
      HRESULT (WINAPI *get_TotalWrapUpTime)(ITAgentSession *This,__LONG32 *plWrapUpTime);
      HRESULT (WINAPI *get_AverageWrapUpTime)(ITAgentSession *This,__LONG32 *plWrapUpTime);
      HRESULT (WINAPI *get_ACDCallRate)(ITAgentSession *This,CURRENCY *pcyCallrate);
      HRESULT (WINAPI *get_LongestTimeToAnswer)(ITAgentSession *This,__LONG32 *plAnswerTime);
      HRESULT (WINAPI *get_AverageTimeToAnswer)(ITAgentSession *This,__LONG32 *plAnswerTime);
    END_INTERFACE
  } ITAgentSessionVtbl;
  struct ITAgentSession {
    CONST_VTBL struct ITAgentSessionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAgentSession_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAgentSession_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAgentSession_Release(This) (This)->lpVtbl->Release(This)
#define ITAgentSession_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAgentSession_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAgentSession_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAgentSession_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAgentSession_get_Agent(This,ppAgent) (This)->lpVtbl->get_Agent(This,ppAgent)
#define ITAgentSession_get_Address(This,ppAddress) (This)->lpVtbl->get_Address(This,ppAddress)
#define ITAgentSession_get_ACDGroup(This,ppACDGroup) (This)->lpVtbl->get_ACDGroup(This,ppACDGroup)
#define ITAgentSession_put_State(This,SessionState) (This)->lpVtbl->put_State(This,SessionState)
#define ITAgentSession_get_State(This,pSessionState) (This)->lpVtbl->get_State(This,pSessionState)
#define ITAgentSession_get_SessionStartTime(This,pdateSessionStart) (This)->lpVtbl->get_SessionStartTime(This,pdateSessionStart)
#define ITAgentSession_get_SessionDuration(This,plDuration) (This)->lpVtbl->get_SessionDuration(This,plDuration)
#define ITAgentSession_get_NumberOfCalls(This,plCalls) (This)->lpVtbl->get_NumberOfCalls(This,plCalls)
#define ITAgentSession_get_TotalTalkTime(This,plTalkTime) (This)->lpVtbl->get_TotalTalkTime(This,plTalkTime)
#define ITAgentSession_get_AverageTalkTime(This,plTalkTime) (This)->lpVtbl->get_AverageTalkTime(This,plTalkTime)
#define ITAgentSession_get_TotalCallTime(This,plCallTime) (This)->lpVtbl->get_TotalCallTime(This,plCallTime)
#define ITAgentSession_get_AverageCallTime(This,plCallTime) (This)->lpVtbl->get_AverageCallTime(This,plCallTime)
#define ITAgentSession_get_TotalWrapUpTime(This,plWrapUpTime) (This)->lpVtbl->get_TotalWrapUpTime(This,plWrapUpTime)
#define ITAgentSession_get_AverageWrapUpTime(This,plWrapUpTime) (This)->lpVtbl->get_AverageWrapUpTime(This,plWrapUpTime)
#define ITAgentSession_get_ACDCallRate(This,pcyCallrate) (This)->lpVtbl->get_ACDCallRate(This,pcyCallrate)
#define ITAgentSession_get_LongestTimeToAnswer(This,plAnswerTime) (This)->lpVtbl->get_LongestTimeToAnswer(This,plAnswerTime)
#define ITAgentSession_get_AverageTimeToAnswer(This,plAnswerTime) (This)->lpVtbl->get_AverageTimeToAnswer(This,plAnswerTime)
#endif
#endif
  HRESULT WINAPI ITAgentSession_get_Agent_Proxy(ITAgentSession *This,ITAgent **ppAgent);
  void __RPC_STUB ITAgentSession_get_Agent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_Address_Proxy(ITAgentSession *This,ITAddress **ppAddress);
  void __RPC_STUB ITAgentSession_get_Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_ACDGroup_Proxy(ITAgentSession *This,ITACDGroup **ppACDGroup);
  void __RPC_STUB ITAgentSession_get_ACDGroup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_put_State_Proxy(ITAgentSession *This,AGENT_SESSION_STATE SessionState);
  void __RPC_STUB ITAgentSession_put_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_State_Proxy(ITAgentSession *This,AGENT_SESSION_STATE *pSessionState);
  void __RPC_STUB ITAgentSession_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_SessionStartTime_Proxy(ITAgentSession *This,DATE *pdateSessionStart);
  void __RPC_STUB ITAgentSession_get_SessionStartTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_SessionDuration_Proxy(ITAgentSession *This,__LONG32 *plDuration);
  void __RPC_STUB ITAgentSession_get_SessionDuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_NumberOfCalls_Proxy(ITAgentSession *This,__LONG32 *plCalls);
  void __RPC_STUB ITAgentSession_get_NumberOfCalls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_TotalTalkTime_Proxy(ITAgentSession *This,__LONG32 *plTalkTime);
  void __RPC_STUB ITAgentSession_get_TotalTalkTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_AverageTalkTime_Proxy(ITAgentSession *This,__LONG32 *plTalkTime);
  void __RPC_STUB ITAgentSession_get_AverageTalkTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_TotalCallTime_Proxy(ITAgentSession *This,__LONG32 *plCallTime);
  void __RPC_STUB ITAgentSession_get_TotalCallTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_AverageCallTime_Proxy(ITAgentSession *This,__LONG32 *plCallTime);
  void __RPC_STUB ITAgentSession_get_AverageCallTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_TotalWrapUpTime_Proxy(ITAgentSession *This,__LONG32 *plWrapUpTime);
  void __RPC_STUB ITAgentSession_get_TotalWrapUpTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_AverageWrapUpTime_Proxy(ITAgentSession *This,__LONG32 *plWrapUpTime);
  void __RPC_STUB ITAgentSession_get_AverageWrapUpTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_ACDCallRate_Proxy(ITAgentSession *This,CURRENCY *pcyCallrate);
  void __RPC_STUB ITAgentSession_get_ACDCallRate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_LongestTimeToAnswer_Proxy(ITAgentSession *This,__LONG32 *plAnswerTime);
  void __RPC_STUB ITAgentSession_get_LongestTimeToAnswer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSession_get_AverageTimeToAnswer_Proxy(ITAgentSession *This,__LONG32 *plAnswerTime);
  void __RPC_STUB ITAgentSession_get_AverageTimeToAnswer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITACDGroup_INTERFACE_DEFINED__
#define __ITACDGroup_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITACDGroup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITACDGroup : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *ppName) = 0;
    virtual HRESULT WINAPI EnumerateQueues(IEnumQueue **ppEnumQueue) = 0;
    virtual HRESULT WINAPI get_Queues(VARIANT *pVariant) = 0;
  };
#else
  typedef struct ITACDGroupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITACDGroup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITACDGroup *This);
      ULONG (WINAPI *Release)(ITACDGroup *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITACDGroup *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITACDGroup *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITACDGroup *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITACDGroup *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(ITACDGroup *This,BSTR *ppName);
      HRESULT (WINAPI *EnumerateQueues)(ITACDGroup *This,IEnumQueue **ppEnumQueue);
      HRESULT (WINAPI *get_Queues)(ITACDGroup *This,VARIANT *pVariant);
    END_INTERFACE
  } ITACDGroupVtbl;
  struct ITACDGroup {
    CONST_VTBL struct ITACDGroupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITACDGroup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITACDGroup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITACDGroup_Release(This) (This)->lpVtbl->Release(This)
#define ITACDGroup_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITACDGroup_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITACDGroup_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITACDGroup_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITACDGroup_get_Name(This,ppName) (This)->lpVtbl->get_Name(This,ppName)
#define ITACDGroup_EnumerateQueues(This,ppEnumQueue) (This)->lpVtbl->EnumerateQueues(This,ppEnumQueue)
#define ITACDGroup_get_Queues(This,pVariant) (This)->lpVtbl->get_Queues(This,pVariant)
#endif
#endif
  HRESULT WINAPI ITACDGroup_get_Name_Proxy(ITACDGroup *This,BSTR *ppName);
  void __RPC_STUB ITACDGroup_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITACDGroup_EnumerateQueues_Proxy(ITACDGroup *This,IEnumQueue **ppEnumQueue);
  void __RPC_STUB ITACDGroup_EnumerateQueues_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITACDGroup_get_Queues_Proxy(ITACDGroup *This,VARIANT *pVariant);
  void __RPC_STUB ITACDGroup_get_Queues_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITQueue_INTERFACE_DEFINED__
#define __ITQueue_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITQueue;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITQueue : public IDispatch {
  public:
    virtual HRESULT WINAPI put_MeasurementPeriod(__LONG32 lPeriod) = 0;
    virtual HRESULT WINAPI get_MeasurementPeriod(__LONG32 *plPeriod) = 0;
    virtual HRESULT WINAPI get_TotalCallsQueued(__LONG32 *plCalls) = 0;
    virtual HRESULT WINAPI get_CurrentCallsQueued(__LONG32 *plCalls) = 0;
    virtual HRESULT WINAPI get_TotalCallsAbandoned(__LONG32 *plCalls) = 0;
    virtual HRESULT WINAPI get_TotalCallsFlowedIn(__LONG32 *plCalls) = 0;
    virtual HRESULT WINAPI get_TotalCallsFlowedOut(__LONG32 *plCalls) = 0;
    virtual HRESULT WINAPI get_LongestEverWaitTime(__LONG32 *plWaitTime) = 0;
    virtual HRESULT WINAPI get_CurrentLongestWaitTime(__LONG32 *plWaitTime) = 0;
    virtual HRESULT WINAPI get_AverageWaitTime(__LONG32 *plWaitTime) = 0;
    virtual HRESULT WINAPI get_FinalDisposition(__LONG32 *plCalls) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *ppName) = 0;
  };
#else
  typedef struct ITQueueVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITQueue *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITQueue *This);
      ULONG (WINAPI *Release)(ITQueue *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITQueue *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITQueue *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITQueue *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITQueue *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *put_MeasurementPeriod)(ITQueue *This,__LONG32 lPeriod);
      HRESULT (WINAPI *get_MeasurementPeriod)(ITQueue *This,__LONG32 *plPeriod);
      HRESULT (WINAPI *get_TotalCallsQueued)(ITQueue *This,__LONG32 *plCalls);
      HRESULT (WINAPI *get_CurrentCallsQueued)(ITQueue *This,__LONG32 *plCalls);
      HRESULT (WINAPI *get_TotalCallsAbandoned)(ITQueue *This,__LONG32 *plCalls);
      HRESULT (WINAPI *get_TotalCallsFlowedIn)(ITQueue *This,__LONG32 *plCalls);
      HRESULT (WINAPI *get_TotalCallsFlowedOut)(ITQueue *This,__LONG32 *plCalls);
      HRESULT (WINAPI *get_LongestEverWaitTime)(ITQueue *This,__LONG32 *plWaitTime);
      HRESULT (WINAPI *get_CurrentLongestWaitTime)(ITQueue *This,__LONG32 *plWaitTime);
      HRESULT (WINAPI *get_AverageWaitTime)(ITQueue *This,__LONG32 *plWaitTime);
      HRESULT (WINAPI *get_FinalDisposition)(ITQueue *This,__LONG32 *plCalls);
      HRESULT (WINAPI *get_Name)(ITQueue *This,BSTR *ppName);
    END_INTERFACE
  } ITQueueVtbl;
  struct ITQueue {
    CONST_VTBL struct ITQueueVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITQueue_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITQueue_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITQueue_Release(This) (This)->lpVtbl->Release(This)
#define ITQueue_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITQueue_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITQueue_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITQueue_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITQueue_put_MeasurementPeriod(This,lPeriod) (This)->lpVtbl->put_MeasurementPeriod(This,lPeriod)
#define ITQueue_get_MeasurementPeriod(This,plPeriod) (This)->lpVtbl->get_MeasurementPeriod(This,plPeriod)
#define ITQueue_get_TotalCallsQueued(This,plCalls) (This)->lpVtbl->get_TotalCallsQueued(This,plCalls)
#define ITQueue_get_CurrentCallsQueued(This,plCalls) (This)->lpVtbl->get_CurrentCallsQueued(This,plCalls)
#define ITQueue_get_TotalCallsAbandoned(This,plCalls) (This)->lpVtbl->get_TotalCallsAbandoned(This,plCalls)
#define ITQueue_get_TotalCallsFlowedIn(This,plCalls) (This)->lpVtbl->get_TotalCallsFlowedIn(This,plCalls)
#define ITQueue_get_TotalCallsFlowedOut(This,plCalls) (This)->lpVtbl->get_TotalCallsFlowedOut(This,plCalls)
#define ITQueue_get_LongestEverWaitTime(This,plWaitTime) (This)->lpVtbl->get_LongestEverWaitTime(This,plWaitTime)
#define ITQueue_get_CurrentLongestWaitTime(This,plWaitTime) (This)->lpVtbl->get_CurrentLongestWaitTime(This,plWaitTime)
#define ITQueue_get_AverageWaitTime(This,plWaitTime) (This)->lpVtbl->get_AverageWaitTime(This,plWaitTime)
#define ITQueue_get_FinalDisposition(This,plCalls) (This)->lpVtbl->get_FinalDisposition(This,plCalls)
#define ITQueue_get_Name(This,ppName) (This)->lpVtbl->get_Name(This,ppName)
#endif
#endif
  HRESULT WINAPI ITQueue_put_MeasurementPeriod_Proxy(ITQueue *This,__LONG32 lPeriod);
  void __RPC_STUB ITQueue_put_MeasurementPeriod_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueue_get_MeasurementPeriod_Proxy(ITQueue *This,__LONG32 *plPeriod);
  void __RPC_STUB ITQueue_get_MeasurementPeriod_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueue_get_TotalCallsQueued_Proxy(ITQueue *This,__LONG32 *plCalls);
  void __RPC_STUB ITQueue_get_TotalCallsQueued_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueue_get_CurrentCallsQueued_Proxy(ITQueue *This,__LONG32 *plCalls);
  void __RPC_STUB ITQueue_get_CurrentCallsQueued_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueue_get_TotalCallsAbandoned_Proxy(ITQueue *This,__LONG32 *plCalls);
  void __RPC_STUB ITQueue_get_TotalCallsAbandoned_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueue_get_TotalCallsFlowedIn_Proxy(ITQueue *This,__LONG32 *plCalls);
  void __RPC_STUB ITQueue_get_TotalCallsFlowedIn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueue_get_TotalCallsFlowedOut_Proxy(ITQueue *This,__LONG32 *plCalls);
  void __RPC_STUB ITQueue_get_TotalCallsFlowedOut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueue_get_LongestEverWaitTime_Proxy(ITQueue *This,__LONG32 *plWaitTime);
  void __RPC_STUB ITQueue_get_LongestEverWaitTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueue_get_CurrentLongestWaitTime_Proxy(ITQueue *This,__LONG32 *plWaitTime);
  void __RPC_STUB ITQueue_get_CurrentLongestWaitTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueue_get_AverageWaitTime_Proxy(ITQueue *This,__LONG32 *plWaitTime);
  void __RPC_STUB ITQueue_get_AverageWaitTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueue_get_FinalDisposition_Proxy(ITQueue *This,__LONG32 *plCalls);
  void __RPC_STUB ITQueue_get_FinalDisposition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueue_get_Name_Proxy(ITQueue *This,BSTR *ppName);
  void __RPC_STUB ITQueue_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAgentEvent_INTERFACE_DEFINED__
#define __ITAgentEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAgentEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAgentEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Agent(ITAgent **ppAgent) = 0;
    virtual HRESULT WINAPI get_Event(AGENT_EVENT *pEvent) = 0;
  };
#else
  typedef struct ITAgentEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAgentEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAgentEvent *This);
      ULONG (WINAPI *Release)(ITAgentEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAgentEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAgentEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAgentEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAgentEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Agent)(ITAgentEvent *This,ITAgent **ppAgent);
      HRESULT (WINAPI *get_Event)(ITAgentEvent *This,AGENT_EVENT *pEvent);
    END_INTERFACE
  } ITAgentEventVtbl;
  struct ITAgentEvent {
    CONST_VTBL struct ITAgentEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAgentEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAgentEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAgentEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITAgentEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAgentEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAgentEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAgentEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAgentEvent_get_Agent(This,ppAgent) (This)->lpVtbl->get_Agent(This,ppAgent)
#define ITAgentEvent_get_Event(This,pEvent) (This)->lpVtbl->get_Event(This,pEvent)
#endif
#endif
  HRESULT WINAPI ITAgentEvent_get_Agent_Proxy(ITAgentEvent *This,ITAgent **ppAgent);
  void __RPC_STUB ITAgentEvent_get_Agent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentEvent_get_Event_Proxy(ITAgentEvent *This,AGENT_EVENT *pEvent);
  void __RPC_STUB ITAgentEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAgentSessionEvent_INTERFACE_DEFINED__
#define __ITAgentSessionEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAgentSessionEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAgentSessionEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Session(ITAgentSession **ppSession) = 0;
    virtual HRESULT WINAPI get_Event(AGENT_SESSION_EVENT *pEvent) = 0;
  };
#else
  typedef struct ITAgentSessionEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAgentSessionEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAgentSessionEvent *This);
      ULONG (WINAPI *Release)(ITAgentSessionEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAgentSessionEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAgentSessionEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAgentSessionEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAgentSessionEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Session)(ITAgentSessionEvent *This,ITAgentSession **ppSession);
      HRESULT (WINAPI *get_Event)(ITAgentSessionEvent *This,AGENT_SESSION_EVENT *pEvent);
    END_INTERFACE
  } ITAgentSessionEventVtbl;
  struct ITAgentSessionEvent {
    CONST_VTBL struct ITAgentSessionEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAgentSessionEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAgentSessionEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAgentSessionEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITAgentSessionEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAgentSessionEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAgentSessionEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAgentSessionEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAgentSessionEvent_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#define ITAgentSessionEvent_get_Event(This,pEvent) (This)->lpVtbl->get_Event(This,pEvent)
#endif
#endif
  HRESULT WINAPI ITAgentSessionEvent_get_Session_Proxy(ITAgentSessionEvent *This,ITAgentSession **ppSession);
  void __RPC_STUB ITAgentSessionEvent_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentSessionEvent_get_Event_Proxy(ITAgentSessionEvent *This,AGENT_SESSION_EVENT *pEvent);
  void __RPC_STUB ITAgentSessionEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITACDGroupEvent_INTERFACE_DEFINED__
#define __ITACDGroupEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITACDGroupEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITACDGroupEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Group(ITACDGroup **ppGroup) = 0;
    virtual HRESULT WINAPI get_Event(ACDGROUP_EVENT *pEvent) = 0;
  };
#else
  typedef struct ITACDGroupEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITACDGroupEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITACDGroupEvent *This);
      ULONG (WINAPI *Release)(ITACDGroupEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITACDGroupEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITACDGroupEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITACDGroupEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITACDGroupEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Group)(ITACDGroupEvent *This,ITACDGroup **ppGroup);
      HRESULT (WINAPI *get_Event)(ITACDGroupEvent *This,ACDGROUP_EVENT *pEvent);
    END_INTERFACE
  } ITACDGroupEventVtbl;
  struct ITACDGroupEvent {
    CONST_VTBL struct ITACDGroupEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITACDGroupEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITACDGroupEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITACDGroupEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITACDGroupEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITACDGroupEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITACDGroupEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITACDGroupEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITACDGroupEvent_get_Group(This,ppGroup) (This)->lpVtbl->get_Group(This,ppGroup)
#define ITACDGroupEvent_get_Event(This,pEvent) (This)->lpVtbl->get_Event(This,pEvent)
#endif
#endif
  HRESULT WINAPI ITACDGroupEvent_get_Group_Proxy(ITACDGroupEvent *This,ITACDGroup **ppGroup);
  void __RPC_STUB ITACDGroupEvent_get_Group_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITACDGroupEvent_get_Event_Proxy(ITACDGroupEvent *This,ACDGROUP_EVENT *pEvent);
  void __RPC_STUB ITACDGroupEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITQueueEvent_INTERFACE_DEFINED__
#define __ITQueueEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITQueueEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITQueueEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Queue(ITQueue **ppQueue) = 0;
    virtual HRESULT WINAPI get_Event(ACDQUEUE_EVENT *pEvent) = 0;
  };
#else
  typedef struct ITQueueEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITQueueEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITQueueEvent *This);
      ULONG (WINAPI *Release)(ITQueueEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITQueueEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITQueueEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITQueueEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITQueueEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Queue)(ITQueueEvent *This,ITQueue **ppQueue);
      HRESULT (WINAPI *get_Event)(ITQueueEvent *This,ACDQUEUE_EVENT *pEvent);
    END_INTERFACE
  } ITQueueEventVtbl;
  struct ITQueueEvent {
    CONST_VTBL struct ITQueueEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITQueueEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITQueueEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITQueueEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITQueueEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITQueueEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITQueueEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITQueueEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITQueueEvent_get_Queue(This,ppQueue) (This)->lpVtbl->get_Queue(This,ppQueue)
#define ITQueueEvent_get_Event(This,pEvent) (This)->lpVtbl->get_Event(This,pEvent)
#endif
#endif
  HRESULT WINAPI ITQueueEvent_get_Queue_Proxy(ITQueueEvent *This,ITQueue **ppQueue);
  void __RPC_STUB ITQueueEvent_get_Queue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQueueEvent_get_Event_Proxy(ITQueueEvent *This,ACDQUEUE_EVENT *pEvent);
  void __RPC_STUB ITQueueEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAgentHandlerEvent_INTERFACE_DEFINED__
#define __ITAgentHandlerEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAgentHandlerEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAgentHandlerEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_AgentHandler(ITAgentHandler **ppAgentHandler) = 0;
    virtual HRESULT WINAPI get_Event(AGENTHANDLER_EVENT *pEvent) = 0;
  };
#else
  typedef struct ITAgentHandlerEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAgentHandlerEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAgentHandlerEvent *This);
      ULONG (WINAPI *Release)(ITAgentHandlerEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAgentHandlerEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAgentHandlerEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAgentHandlerEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAgentHandlerEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_AgentHandler)(ITAgentHandlerEvent *This,ITAgentHandler **ppAgentHandler);
      HRESULT (WINAPI *get_Event)(ITAgentHandlerEvent *This,AGENTHANDLER_EVENT *pEvent);
    END_INTERFACE
  } ITAgentHandlerEventVtbl;
  struct ITAgentHandlerEvent {
    CONST_VTBL struct ITAgentHandlerEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAgentHandlerEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAgentHandlerEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAgentHandlerEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITAgentHandlerEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAgentHandlerEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAgentHandlerEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAgentHandlerEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAgentHandlerEvent_get_AgentHandler(This,ppAgentHandler) (This)->lpVtbl->get_AgentHandler(This,ppAgentHandler)
#define ITAgentHandlerEvent_get_Event(This,pEvent) (This)->lpVtbl->get_Event(This,pEvent)
#endif
#endif
  HRESULT WINAPI ITAgentHandlerEvent_get_AgentHandler_Proxy(ITAgentHandlerEvent *This,ITAgentHandler **ppAgentHandler);
  void __RPC_STUB ITAgentHandlerEvent_get_AgentHandler_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentHandlerEvent_get_Event_Proxy(ITAgentHandlerEvent *This,AGENTHANDLER_EVENT *pEvent);
  void __RPC_STUB ITAgentHandlerEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTAPICallCenter_INTERFACE_DEFINED__
#define __ITTAPICallCenter_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTAPICallCenter;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTAPICallCenter : public IDispatch {
  public:
    virtual HRESULT WINAPI EnumerateAgentHandlers(IEnumAgentHandler **ppEnumHandler) = 0;
    virtual HRESULT WINAPI get_AgentHandlers(VARIANT *pVariant) = 0;
  };
#else
  typedef struct ITTAPICallCenterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTAPICallCenter *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTAPICallCenter *This);
      ULONG (WINAPI *Release)(ITTAPICallCenter *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTAPICallCenter *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTAPICallCenter *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTAPICallCenter *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTAPICallCenter *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *EnumerateAgentHandlers)(ITTAPICallCenter *This,IEnumAgentHandler **ppEnumHandler);
      HRESULT (WINAPI *get_AgentHandlers)(ITTAPICallCenter *This,VARIANT *pVariant);
    END_INTERFACE
  } ITTAPICallCenterVtbl;
  struct ITTAPICallCenter {
    CONST_VTBL struct ITTAPICallCenterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTAPICallCenter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTAPICallCenter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTAPICallCenter_Release(This) (This)->lpVtbl->Release(This)
#define ITTAPICallCenter_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTAPICallCenter_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTAPICallCenter_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTAPICallCenter_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITTAPICallCenter_EnumerateAgentHandlers(This,ppEnumHandler) (This)->lpVtbl->EnumerateAgentHandlers(This,ppEnumHandler)
#define ITTAPICallCenter_get_AgentHandlers(This,pVariant) (This)->lpVtbl->get_AgentHandlers(This,pVariant)
#endif
#endif
  HRESULT WINAPI ITTAPICallCenter_EnumerateAgentHandlers_Proxy(ITTAPICallCenter *This,IEnumAgentHandler **ppEnumHandler);
  void __RPC_STUB ITTAPICallCenter_EnumerateAgentHandlers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPICallCenter_get_AgentHandlers_Proxy(ITTAPICallCenter *This,VARIANT *pVariant);
  void __RPC_STUB ITTAPICallCenter_get_AgentHandlers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAgentHandler_INTERFACE_DEFINED__
#define __ITAgentHandler_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAgentHandler;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAgentHandler : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *ppName) = 0;
    virtual HRESULT WINAPI CreateAgent(ITAgent **ppAgent) = 0;
    virtual HRESULT WINAPI CreateAgentWithID(BSTR pID,BSTR pPIN,ITAgent **ppAgent) = 0;
    virtual HRESULT WINAPI EnumerateACDGroups(IEnumACDGroup **ppEnumACDGroup) = 0;
    virtual HRESULT WINAPI EnumerateUsableAddresses(IEnumAddress **ppEnumAddress) = 0;
    virtual HRESULT WINAPI get_ACDGroups(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI get_UsableAddresses(VARIANT *pVariant) = 0;
  };
#else
  typedef struct ITAgentHandlerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAgentHandler *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAgentHandler *This);
      ULONG (WINAPI *Release)(ITAgentHandler *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAgentHandler *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAgentHandler *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAgentHandler *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAgentHandler *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(ITAgentHandler *This,BSTR *ppName);
      HRESULT (WINAPI *CreateAgent)(ITAgentHandler *This,ITAgent **ppAgent);
      HRESULT (WINAPI *CreateAgentWithID)(ITAgentHandler *This,BSTR pID,BSTR pPIN,ITAgent **ppAgent);
      HRESULT (WINAPI *EnumerateACDGroups)(ITAgentHandler *This,IEnumACDGroup **ppEnumACDGroup);
      HRESULT (WINAPI *EnumerateUsableAddresses)(ITAgentHandler *This,IEnumAddress **ppEnumAddress);
      HRESULT (WINAPI *get_ACDGroups)(ITAgentHandler *This,VARIANT *pVariant);
      HRESULT (WINAPI *get_UsableAddresses)(ITAgentHandler *This,VARIANT *pVariant);
    END_INTERFACE
  } ITAgentHandlerVtbl;
  struct ITAgentHandler {
    CONST_VTBL struct ITAgentHandlerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAgentHandler_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAgentHandler_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAgentHandler_Release(This) (This)->lpVtbl->Release(This)
#define ITAgentHandler_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAgentHandler_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAgentHandler_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAgentHandler_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAgentHandler_get_Name(This,ppName) (This)->lpVtbl->get_Name(This,ppName)
#define ITAgentHandler_CreateAgent(This,ppAgent) (This)->lpVtbl->CreateAgent(This,ppAgent)
#define ITAgentHandler_CreateAgentWithID(This,pID,pPIN,ppAgent) (This)->lpVtbl->CreateAgentWithID(This,pID,pPIN,ppAgent)
#define ITAgentHandler_EnumerateACDGroups(This,ppEnumACDGroup) (This)->lpVtbl->EnumerateACDGroups(This,ppEnumACDGroup)
#define ITAgentHandler_EnumerateUsableAddresses(This,ppEnumAddress) (This)->lpVtbl->EnumerateUsableAddresses(This,ppEnumAddress)
#define ITAgentHandler_get_ACDGroups(This,pVariant) (This)->lpVtbl->get_ACDGroups(This,pVariant)
#define ITAgentHandler_get_UsableAddresses(This,pVariant) (This)->lpVtbl->get_UsableAddresses(This,pVariant)
#endif
#endif
  HRESULT WINAPI ITAgentHandler_get_Name_Proxy(ITAgentHandler *This,BSTR *ppName);
  void __RPC_STUB ITAgentHandler_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentHandler_CreateAgent_Proxy(ITAgentHandler *This,ITAgent **ppAgent);
  void __RPC_STUB ITAgentHandler_CreateAgent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentHandler_CreateAgentWithID_Proxy(ITAgentHandler *This,BSTR pID,BSTR pPIN,ITAgent **ppAgent);
  void __RPC_STUB ITAgentHandler_CreateAgentWithID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentHandler_EnumerateACDGroups_Proxy(ITAgentHandler *This,IEnumACDGroup **ppEnumACDGroup);
  void __RPC_STUB ITAgentHandler_EnumerateACDGroups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentHandler_EnumerateUsableAddresses_Proxy(ITAgentHandler *This,IEnumAddress **ppEnumAddress);
  void __RPC_STUB ITAgentHandler_EnumerateUsableAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentHandler_get_ACDGroups_Proxy(ITAgentHandler *This,VARIANT *pVariant);
  void __RPC_STUB ITAgentHandler_get_ACDGroups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAgentHandler_get_UsableAddresses_Proxy(ITAgentHandler *This,VARIANT *pVariant);
  void __RPC_STUB ITAgentHandler_get_UsableAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumAgent_INTERFACE_DEFINED__
#define __IEnumAgent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumAgent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumAgent : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITAgent **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumAgent **ppEnum) = 0;
  };
#else
  typedef struct IEnumAgentVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumAgent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumAgent *This);
      ULONG (WINAPI *Release)(IEnumAgent *This);
      HRESULT (WINAPI *Next)(IEnumAgent *This,ULONG celt,ITAgent **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumAgent *This);
      HRESULT (WINAPI *Skip)(IEnumAgent *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumAgent *This,IEnumAgent **ppEnum);
    END_INTERFACE
  } IEnumAgentVtbl;
  struct IEnumAgent {
    CONST_VTBL struct IEnumAgentVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumAgent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumAgent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumAgent_Release(This) (This)->lpVtbl->Release(This)
#define IEnumAgent_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumAgent_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumAgent_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumAgent_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumAgent_Next_Proxy(IEnumAgent *This,ULONG celt,ITAgent **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumAgent_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAgent_Reset_Proxy(IEnumAgent *This);
  void __RPC_STUB IEnumAgent_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAgent_Skip_Proxy(IEnumAgent *This,ULONG celt);
  void __RPC_STUB IEnumAgent_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAgent_Clone_Proxy(IEnumAgent *This,IEnumAgent **ppEnum);
  void __RPC_STUB IEnumAgent_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumAgentSession_INTERFACE_DEFINED__
#define __IEnumAgentSession_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumAgentSession;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumAgentSession : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITAgentSession **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumAgentSession **ppEnum) = 0;
  };
#else
  typedef struct IEnumAgentSessionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumAgentSession *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumAgentSession *This);
      ULONG (WINAPI *Release)(IEnumAgentSession *This);
      HRESULT (WINAPI *Next)(IEnumAgentSession *This,ULONG celt,ITAgentSession **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumAgentSession *This);
      HRESULT (WINAPI *Skip)(IEnumAgentSession *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumAgentSession *This,IEnumAgentSession **ppEnum);
    END_INTERFACE
  } IEnumAgentSessionVtbl;
  struct IEnumAgentSession {
    CONST_VTBL struct IEnumAgentSessionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumAgentSession_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumAgentSession_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumAgentSession_Release(This) (This)->lpVtbl->Release(This)
#define IEnumAgentSession_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumAgentSession_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumAgentSession_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumAgentSession_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumAgentSession_Next_Proxy(IEnumAgentSession *This,ULONG celt,ITAgentSession **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumAgentSession_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAgentSession_Reset_Proxy(IEnumAgentSession *This);
  void __RPC_STUB IEnumAgentSession_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAgentSession_Skip_Proxy(IEnumAgentSession *This,ULONG celt);
  void __RPC_STUB IEnumAgentSession_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAgentSession_Clone_Proxy(IEnumAgentSession *This,IEnumAgentSession **ppEnum);
  void __RPC_STUB IEnumAgentSession_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumQueue_INTERFACE_DEFINED__
#define __IEnumQueue_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumQueue;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumQueue : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITQueue **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumQueue **ppEnum) = 0;
  };
#else
  typedef struct IEnumQueueVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumQueue *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumQueue *This);
      ULONG (WINAPI *Release)(IEnumQueue *This);
      HRESULT (WINAPI *Next)(IEnumQueue *This,ULONG celt,ITQueue **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumQueue *This);
      HRESULT (WINAPI *Skip)(IEnumQueue *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumQueue *This,IEnumQueue **ppEnum);
    END_INTERFACE
  } IEnumQueueVtbl;
  struct IEnumQueue {
    CONST_VTBL struct IEnumQueueVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumQueue_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumQueue_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumQueue_Release(This) (This)->lpVtbl->Release(This)
#define IEnumQueue_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumQueue_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumQueue_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumQueue_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumQueue_Next_Proxy(IEnumQueue *This,ULONG celt,ITQueue **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumQueue_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumQueue_Reset_Proxy(IEnumQueue *This);
  void __RPC_STUB IEnumQueue_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumQueue_Skip_Proxy(IEnumQueue *This,ULONG celt);
  void __RPC_STUB IEnumQueue_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumQueue_Clone_Proxy(IEnumQueue *This,IEnumQueue **ppEnum);
  void __RPC_STUB IEnumQueue_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumACDGroup_INTERFACE_DEFINED__
#define __IEnumACDGroup_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumACDGroup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumACDGroup : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITACDGroup **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumACDGroup **ppEnum) = 0;
  };
#else
  typedef struct IEnumACDGroupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumACDGroup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumACDGroup *This);
      ULONG (WINAPI *Release)(IEnumACDGroup *This);
      HRESULT (WINAPI *Next)(IEnumACDGroup *This,ULONG celt,ITACDGroup **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumACDGroup *This);
      HRESULT (WINAPI *Skip)(IEnumACDGroup *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumACDGroup *This,IEnumACDGroup **ppEnum);
    END_INTERFACE
  } IEnumACDGroupVtbl;
  struct IEnumACDGroup {
    CONST_VTBL struct IEnumACDGroupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumACDGroup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumACDGroup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumACDGroup_Release(This) (This)->lpVtbl->Release(This)
#define IEnumACDGroup_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumACDGroup_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumACDGroup_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumACDGroup_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumACDGroup_Next_Proxy(IEnumACDGroup *This,ULONG celt,ITACDGroup **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumACDGroup_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumACDGroup_Reset_Proxy(IEnumACDGroup *This);
  void __RPC_STUB IEnumACDGroup_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumACDGroup_Skip_Proxy(IEnumACDGroup *This,ULONG celt);
  void __RPC_STUB IEnumACDGroup_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumACDGroup_Clone_Proxy(IEnumACDGroup *This,IEnumACDGroup **ppEnum);
  void __RPC_STUB IEnumACDGroup_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumAgentHandler_INTERFACE_DEFINED__
#define __IEnumAgentHandler_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumAgentHandler;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumAgentHandler : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITAgentHandler **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumAgentHandler **ppEnum) = 0;
  };
#else
  typedef struct IEnumAgentHandlerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumAgentHandler *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumAgentHandler *This);
      ULONG (WINAPI *Release)(IEnumAgentHandler *This);
      HRESULT (WINAPI *Next)(IEnumAgentHandler *This,ULONG celt,ITAgentHandler **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumAgentHandler *This);
      HRESULT (WINAPI *Skip)(IEnumAgentHandler *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumAgentHandler *This,IEnumAgentHandler **ppEnum);
    END_INTERFACE
  } IEnumAgentHandlerVtbl;
  struct IEnumAgentHandler {
    CONST_VTBL struct IEnumAgentHandlerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumAgentHandler_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumAgentHandler_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumAgentHandler_Release(This) (This)->lpVtbl->Release(This)
#define IEnumAgentHandler_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumAgentHandler_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumAgentHandler_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumAgentHandler_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumAgentHandler_Next_Proxy(IEnumAgentHandler *This,ULONG celt,ITAgentHandler **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumAgentHandler_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAgentHandler_Reset_Proxy(IEnumAgentHandler *This);
  void __RPC_STUB IEnumAgentHandler_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAgentHandler_Skip_Proxy(IEnumAgentHandler *This,ULONG celt);
  void __RPC_STUB IEnumAgentHandler_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAgentHandler_Clone_Proxy(IEnumAgentHandler *This,IEnumAgentHandler **ppEnum);
  void __RPC_STUB IEnumAgentHandler_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_tapi3_0520_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_tapi3_0520_v0_0_s_ifspec;
#ifndef __ITAMMediaFormat_INTERFACE_DEFINED__
#define __ITAMMediaFormat_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAMMediaFormat;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAMMediaFormat : public IUnknown {
  public:
    virtual HRESULT WINAPI get_MediaFormat(AM_MEDIA_TYPE **ppmt) = 0;
    virtual HRESULT WINAPI put_MediaFormat(const AM_MEDIA_TYPE *pmt) = 0;
  };
#else
  typedef struct ITAMMediaFormatVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAMMediaFormat *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAMMediaFormat *This);
      ULONG (WINAPI *Release)(ITAMMediaFormat *This);
      HRESULT (WINAPI *get_MediaFormat)(ITAMMediaFormat *This,AM_MEDIA_TYPE **ppmt);
      HRESULT (WINAPI *put_MediaFormat)(ITAMMediaFormat *This,const AM_MEDIA_TYPE *pmt);
    END_INTERFACE
  } ITAMMediaFormatVtbl;
  struct ITAMMediaFormat {
    CONST_VTBL struct ITAMMediaFormatVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAMMediaFormat_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAMMediaFormat_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAMMediaFormat_Release(This) (This)->lpVtbl->Release(This)
#define ITAMMediaFormat_get_MediaFormat(This,ppmt) (This)->lpVtbl->get_MediaFormat(This,ppmt)
#define ITAMMediaFormat_put_MediaFormat(This,pmt) (This)->lpVtbl->put_MediaFormat(This,pmt)
#endif
#endif
  HRESULT WINAPI ITAMMediaFormat_get_MediaFormat_Proxy(ITAMMediaFormat *This,AM_MEDIA_TYPE **ppmt);
  void __RPC_STUB ITAMMediaFormat_get_MediaFormat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAMMediaFormat_put_MediaFormat_Proxy(ITAMMediaFormat *This,const AM_MEDIA_TYPE *pmt);
  void __RPC_STUB ITAMMediaFormat_put_MediaFormat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAllocatorProperties_INTERFACE_DEFINED__
#define __ITAllocatorProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAllocatorProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAllocatorProperties : public IUnknown {
  public:
    virtual HRESULT WINAPI SetAllocatorProperties(ALLOCATOR_PROPERTIES *pAllocProperties) = 0;
    virtual HRESULT WINAPI GetAllocatorProperties(ALLOCATOR_PROPERTIES *pAllocProperties) = 0;
    virtual HRESULT WINAPI SetAllocateBuffers(WINBOOL bAllocBuffers) = 0;
    virtual HRESULT WINAPI GetAllocateBuffers(WINBOOL *pbAllocBuffers) = 0;
    virtual HRESULT WINAPI SetBufferSize(DWORD BufferSize) = 0;
    virtual HRESULT WINAPI GetBufferSize(DWORD *pBufferSize) = 0;
  };
#else
  typedef struct ITAllocatorPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAllocatorProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAllocatorProperties *This);
      ULONG (WINAPI *Release)(ITAllocatorProperties *This);
      HRESULT (WINAPI *SetAllocatorProperties)(ITAllocatorProperties *This,ALLOCATOR_PROPERTIES *pAllocProperties);
      HRESULT (WINAPI *GetAllocatorProperties)(ITAllocatorProperties *This,ALLOCATOR_PROPERTIES *pAllocProperties);
      HRESULT (WINAPI *SetAllocateBuffers)(ITAllocatorProperties *This,WINBOOL bAllocBuffers);
      HRESULT (WINAPI *GetAllocateBuffers)(ITAllocatorProperties *This,WINBOOL *pbAllocBuffers);
      HRESULT (WINAPI *SetBufferSize)(ITAllocatorProperties *This,DWORD BufferSize);
      HRESULT (WINAPI *GetBufferSize)(ITAllocatorProperties *This,DWORD *pBufferSize);
    END_INTERFACE
  } ITAllocatorPropertiesVtbl;
  struct ITAllocatorProperties {
    CONST_VTBL struct ITAllocatorPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAllocatorProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAllocatorProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAllocatorProperties_Release(This) (This)->lpVtbl->Release(This)
#define ITAllocatorProperties_SetAllocatorProperties(This,pAllocProperties) (This)->lpVtbl->SetAllocatorProperties(This,pAllocProperties)
#define ITAllocatorProperties_GetAllocatorProperties(This,pAllocProperties) (This)->lpVtbl->GetAllocatorProperties(This,pAllocProperties)
#define ITAllocatorProperties_SetAllocateBuffers(This,bAllocBuffers) (This)->lpVtbl->SetAllocateBuffers(This,bAllocBuffers)
#define ITAllocatorProperties_GetAllocateBuffers(This,pbAllocBuffers) (This)->lpVtbl->GetAllocateBuffers(This,pbAllocBuffers)
#define ITAllocatorProperties_SetBufferSize(This,BufferSize) (This)->lpVtbl->SetBufferSize(This,BufferSize)
#define ITAllocatorProperties_GetBufferSize(This,pBufferSize) (This)->lpVtbl->GetBufferSize(This,pBufferSize)
#endif
#endif
  HRESULT WINAPI ITAllocatorProperties_SetAllocatorProperties_Proxy(ITAllocatorProperties *This,ALLOCATOR_PROPERTIES *pAllocProperties);
  void __RPC_STUB ITAllocatorProperties_SetAllocatorProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAllocatorProperties_GetAllocatorProperties_Proxy(ITAllocatorProperties *This,ALLOCATOR_PROPERTIES *pAllocProperties);
  void __RPC_STUB ITAllocatorProperties_GetAllocatorProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAllocatorProperties_SetAllocateBuffers_Proxy(ITAllocatorProperties *This,WINBOOL bAllocBuffers);
  void __RPC_STUB ITAllocatorProperties_SetAllocateBuffers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAllocatorProperties_GetAllocateBuffers_Proxy(ITAllocatorProperties *This,WINBOOL *pbAllocBuffers);
  void __RPC_STUB ITAllocatorProperties_GetAllocateBuffers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAllocatorProperties_SetBufferSize_Proxy(ITAllocatorProperties *This,DWORD BufferSize);
  void __RPC_STUB ITAllocatorProperties_SetBufferSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAllocatorProperties_GetBufferSize_Proxy(ITAllocatorProperties *This,DWORD *pBufferSize);
  void __RPC_STUB ITAllocatorProperties_GetBufferSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef __LONG32 *MSP_HANDLE;

  typedef enum __MIDL___MIDL_itf_tapi3_0524_0001 {
    ADDRESS_TERMINAL_AVAILABLE = 0,
    ADDRESS_TERMINAL_UNAVAILABLE
  } MSP_ADDRESS_EVENT;

  typedef enum __MIDL___MIDL_itf_tapi3_0524_0002 {
    CALL_NEW_STREAM = 0,
    CALL_STREAM_FAIL,CALL_TERMINAL_FAIL,CALL_STREAM_NOT_USED,CALL_STREAM_ACTIVE,
    CALL_STREAM_INACTIVE
  } MSP_CALL_EVENT;

  typedef enum __MIDL___MIDL_itf_tapi3_0524_0003 {
    CALL_CAUSE_UNKNOWN = 0,
    CALL_CAUSE_BAD_DEVICE,CALL_CAUSE_CONNECT_FAIL,CALL_CAUSE_LOCAL_REQUEST,CALL_CAUSE_REMOTE_REQUEST,
    CALL_CAUSE_MEDIA_TIMEOUT,CALL_CAUSE_MEDIA_RECOVERED,CALL_CAUSE_QUALITY_OF_SERVICE
  } MSP_CALL_EVENT_CAUSE;

  typedef enum __MIDL___MIDL_itf_tapi3_0524_0004 {
    ME_ADDRESS_EVENT = 0,
    ME_CALL_EVENT,ME_TSP_DATA,ME_PRIVATE_EVENT,ME_ASR_TERMINAL_EVENT,
    ME_TTS_TERMINAL_EVENT,ME_FILE_TERMINAL_EVENT,ME_TONE_TERMINAL_EVENT
  } MSP_EVENT;

  typedef struct __MIDL___MIDL_itf_tapi3_0524_0005 {
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

  extern RPC_IF_HANDLE __MIDL_itf_tapi3_0524_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_tapi3_0524_v0_0_s_ifspec;
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

#ifndef __TAPI3Lib_LIBRARY_DEFINED__
#define __TAPI3Lib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_TAPI3Lib;
#ifndef __ITTAPIDispatchEventNotification_DISPINTERFACE_DEFINED__
#define __ITTAPIDispatchEventNotification_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID_ITTAPIDispatchEventNotification;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTAPIDispatchEventNotification : public IDispatch {
  };
#else
  typedef struct ITTAPIDispatchEventNotificationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTAPIDispatchEventNotification *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTAPIDispatchEventNotification *This);
      ULONG (WINAPI *Release)(ITTAPIDispatchEventNotification *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTAPIDispatchEventNotification *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTAPIDispatchEventNotification *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTAPIDispatchEventNotification *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTAPIDispatchEventNotification *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } ITTAPIDispatchEventNotificationVtbl;
  struct ITTAPIDispatchEventNotification {
    CONST_VTBL struct ITTAPIDispatchEventNotificationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTAPIDispatchEventNotification_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTAPIDispatchEventNotification_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTAPIDispatchEventNotification_Release(This) (This)->lpVtbl->Release(This)
#define ITTAPIDispatchEventNotification_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTAPIDispatchEventNotification_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTAPIDispatchEventNotification_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTAPIDispatchEventNotification_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

  EXTERN_C const CLSID CLSID_TAPI;
#ifdef __cplusplus
  class TAPI;
#endif
  EXTERN_C const CLSID CLSID_DispatchMapper;
#ifdef __cplusplus
  class DispatchMapper;
#endif
  EXTERN_C const CLSID CLSID_RequestMakeCall;
#ifdef __cplusplus
  class RequestMakeCall;
#endif
#ifndef __TapiConstants_MODULE_DEFINED__
#define __TapiConstants_MODULE_DEFINED__
  const BSTR CLSID_String_VideoWindowTerm = L"{F7438990-D6EB-11D0-82A6-00AA00B5CA1B}";
  const BSTR CLSID_String_VideoInputTerminal = L"{AAF578EC-DC70-11D0-8ED3-00C04FB6809F}";
  const BSTR CLSID_String_HandsetTerminal = L"{AAF578EB-DC70-11D0-8ED3-00C04FB6809F}";
  const BSTR CLSID_String_HeadsetTerminal = L"{AAF578ED-DC70-11D0-8ED3-00C04FB6809F}";
  const BSTR CLSID_String_SpeakerphoneTerminal = L"{AAF578EE-DC70-11D0-8ED3-00C04FB6809F}";
  const BSTR CLSID_String_MicrophoneTerminal = L"{AAF578EF-DC70-11D0-8ED3-00C04FB6809F}";
  const BSTR CLSID_String_SpeakersTerminal = L"{AAF578F0-DC70-11D0-8ED3-00C04FB6809F}";
  const BSTR CLSID_String_MediaStreamTerminal = L"{E2F7AEF7-4971-11D1-A671-006097C9A2E8}";
  const BSTR CLSID_String_FileRecordingTerminal = L"{521F3D06-C3D0-4511-8617-86B9A783DA77}";
  const BSTR CLSID_String_FilePlaybackTerminal = L"{0CB9914C-79CD-47DC-ADB0-327F47CEFB20}";
  const BSTR TAPIPROTOCOL_String_PSTN = L"{831CE2D6-83B5-11D1-BB5C-00C04FB6809F}";
  const BSTR TAPIPROTOCOL_String_H323 = L"{831CE2D7-83B5-11D1-BB5C-00C04FB6809F}";
  const BSTR TAPIPROTOCOL_String_Multicast = L"{831CE2D8-83B5-11D1-BB5C-00C04FB6809F}";
  const __LONG32 LINEADDRESSTYPE_PHONENUMBER = 0x1;
  const __LONG32 LINEADDRESSTYPE_SDP = 0x2;
  const __LONG32 LINEADDRESSTYPE_EMAILNAME = 0x4;
  const __LONG32 LINEADDRESSTYPE_DOMAINNAME = 0x8;
  const __LONG32 LINEADDRESSTYPE_IPADDRESS = 0x10;
  const __LONG32 LINEDIGITMODE_PULSE = 0x1;
  const __LONG32 LINEDIGITMODE_DTMF = 0x2;
  const __LONG32 LINEDIGITMODE_DTMFEND = 0x4;
  const __LONG32 TAPIMEDIATYPE_AUDIO = 0x8;
  const __LONG32 TAPIMEDIATYPE_VIDEO = 0x8000;
  const __LONG32 TAPIMEDIATYPE_DATAMODEM = 0x10;
  const __LONG32 TAPIMEDIATYPE_G3FAX = 0x20;
  const __LONG32 TAPIMEDIATYPE_MULTITRACK = 0x10000;
#endif
#endif

#define TAPI_CURRENT_VERSION 0x00030001
#include <tapi.h>
#include <tapi3err.h>

  extern RPC_IF_HANDLE __MIDL_itf_tapi3_0530_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_tapi3_0530_v0_0_s_ifspec;

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
