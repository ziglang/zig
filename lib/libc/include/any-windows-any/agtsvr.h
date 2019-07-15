/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 440
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

#ifndef __AgentServer_h__
#define __AgentServer_h__

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __IAgentUserInput_FWD_DEFINED__
#define __IAgentUserInput_FWD_DEFINED__
  typedef struct IAgentUserInput IAgentUserInput;
#endif

#ifndef __IAgentCommand_FWD_DEFINED__
#define __IAgentCommand_FWD_DEFINED__
  typedef struct IAgentCommand IAgentCommand;
#endif

#ifndef __IAgentCommandEx_FWD_DEFINED__
#define __IAgentCommandEx_FWD_DEFINED__
  typedef struct IAgentCommandEx IAgentCommandEx;
#endif

#ifndef __IAgentCommands_FWD_DEFINED__
#define __IAgentCommands_FWD_DEFINED__
  typedef struct IAgentCommands IAgentCommands;
#endif

#ifndef __IAgentCommandsEx_FWD_DEFINED__
#define __IAgentCommandsEx_FWD_DEFINED__
  typedef struct IAgentCommandsEx IAgentCommandsEx;
#endif

#ifndef __IAgentCommandWindow_FWD_DEFINED__
#define __IAgentCommandWindow_FWD_DEFINED__
  typedef struct IAgentCommandWindow IAgentCommandWindow;
#endif

#ifndef __IAgentSpeechInputProperties_FWD_DEFINED__
#define __IAgentSpeechInputProperties_FWD_DEFINED__
  typedef struct IAgentSpeechInputProperties IAgentSpeechInputProperties;
#endif

#ifndef __IAgentAudioOutputProperties_FWD_DEFINED__
#define __IAgentAudioOutputProperties_FWD_DEFINED__
  typedef struct IAgentAudioOutputProperties IAgentAudioOutputProperties;
#endif

#ifndef __IAgentAudioOutputPropertiesEx_FWD_DEFINED__
#define __IAgentAudioOutputPropertiesEx_FWD_DEFINED__
  typedef struct IAgentAudioOutputPropertiesEx IAgentAudioOutputPropertiesEx;
#endif

#ifndef __IAgentPropertySheet_FWD_DEFINED__
#define __IAgentPropertySheet_FWD_DEFINED__
  typedef struct IAgentPropertySheet IAgentPropertySheet;
#endif

#ifndef __IAgentBalloon_FWD_DEFINED__
#define __IAgentBalloon_FWD_DEFINED__
  typedef struct IAgentBalloon IAgentBalloon;
#endif

#ifndef __IAgentBalloonEx_FWD_DEFINED__
#define __IAgentBalloonEx_FWD_DEFINED__
  typedef struct IAgentBalloonEx IAgentBalloonEx;
#endif

#ifndef __IAgentCharacter_FWD_DEFINED__
#define __IAgentCharacter_FWD_DEFINED__
  typedef struct IAgentCharacter IAgentCharacter;
#endif

#ifndef __IAgentCharacterEx_FWD_DEFINED__
#define __IAgentCharacterEx_FWD_DEFINED__
  typedef struct IAgentCharacterEx IAgentCharacterEx;
#endif

#ifndef __IAgent_FWD_DEFINED__
#define __IAgent_FWD_DEFINED__
  typedef struct IAgent IAgent;
#endif

#ifndef __IAgentEx_FWD_DEFINED__
#define __IAgentEx_FWD_DEFINED__
  typedef struct IAgentEx IAgentEx;
#endif

#ifndef __IAgentNotifySink_FWD_DEFINED__
#define __IAgentNotifySink_FWD_DEFINED__
  typedef struct IAgentNotifySink IAgentNotifySink;
#endif

#ifndef __IAgentNotifySinkEx_FWD_DEFINED__
#define __IAgentNotifySinkEx_FWD_DEFINED__
  typedef struct IAgentNotifySinkEx IAgentNotifySinkEx;
#endif

#ifndef __IAgentPrivateNotifySink_FWD_DEFINED__
#define __IAgentPrivateNotifySink_FWD_DEFINED__
  typedef struct IAgentPrivateNotifySink IAgentPrivateNotifySink;
#endif

#ifndef __IAgentCustomMarshalMaker_FWD_DEFINED__
#define __IAgentCustomMarshalMaker_FWD_DEFINED__
  typedef struct IAgentCustomMarshalMaker IAgentCustomMarshalMaker;
#endif

#ifndef __IAgentClientStatus_FWD_DEFINED__
#define __IAgentClientStatus_FWD_DEFINED__
  typedef struct IAgentClientStatus IAgentClientStatus;
#endif

#ifndef __AgentServer_FWD_DEFINED__
#define __AgentServer_FWD_DEFINED__
#ifdef __cplusplus
  typedef class AgentServer AgentServer;
#else
  typedef struct AgentServer AgentServer;
#endif
#endif

#ifndef __IAgentUserInput_FWD_DEFINED__
#define __IAgentUserInput_FWD_DEFINED__
  typedef struct IAgentUserInput IAgentUserInput;
#endif

#ifndef __IAgentCommand_FWD_DEFINED__
#define __IAgentCommand_FWD_DEFINED__
  typedef struct IAgentCommand IAgentCommand;
#endif

#ifndef __IAgentCommandEx_FWD_DEFINED__
#define __IAgentCommandEx_FWD_DEFINED__
  typedef struct IAgentCommandEx IAgentCommandEx;
#endif

#ifndef __IAgentCommands_FWD_DEFINED__
#define __IAgentCommands_FWD_DEFINED__
  typedef struct IAgentCommands IAgentCommands;
#endif

#ifndef __IAgentCommandsEx_FWD_DEFINED__
#define __IAgentCommandsEx_FWD_DEFINED__
  typedef struct IAgentCommandsEx IAgentCommandsEx;
#endif

#ifndef __IAgentSpeechInputProperties_FWD_DEFINED__
#define __IAgentSpeechInputProperties_FWD_DEFINED__
  typedef struct IAgentSpeechInputProperties IAgentSpeechInputProperties;
#endif

#ifndef __IAgentAudioOutputProperties_FWD_DEFINED__
#define __IAgentAudioOutputProperties_FWD_DEFINED__
  typedef struct IAgentAudioOutputProperties IAgentAudioOutputProperties;
#endif

#ifndef __IAgentAudioOutputPropertiesEx_FWD_DEFINED__
#define __IAgentAudioOutputPropertiesEx_FWD_DEFINED__
  typedef struct IAgentAudioOutputPropertiesEx IAgentAudioOutputPropertiesEx;
#endif

#ifndef __IAgentPropertySheet_FWD_DEFINED__
#define __IAgentPropertySheet_FWD_DEFINED__
  typedef struct IAgentPropertySheet IAgentPropertySheet;
#endif

#ifndef __IAgentBalloon_FWD_DEFINED__
#define __IAgentBalloon_FWD_DEFINED__
  typedef struct IAgentBalloon IAgentBalloon;
#endif

#ifndef __IAgentBalloonEx_FWD_DEFINED__
#define __IAgentBalloonEx_FWD_DEFINED__
  typedef struct IAgentBalloonEx IAgentBalloonEx;
#endif

#ifndef __IAgentCharacter_FWD_DEFINED__
#define __IAgentCharacter_FWD_DEFINED__
  typedef struct IAgentCharacter IAgentCharacter;
#endif

#ifndef __IAgentCharacterEx_FWD_DEFINED__
#define __IAgentCharacterEx_FWD_DEFINED__
  typedef struct IAgentCharacterEx IAgentCharacterEx;
#endif

#ifndef __IAgent_FWD_DEFINED__
#define __IAgent_FWD_DEFINED__
  typedef struct IAgent IAgent;
#endif

#ifndef __IAgentEx_FWD_DEFINED__
#define __IAgentEx_FWD_DEFINED__
  typedef struct IAgentEx IAgentEx;
#endif

#ifndef __IAgentNotifySink_FWD_DEFINED__
#define __IAgentNotifySink_FWD_DEFINED__
  typedef struct IAgentNotifySink IAgentNotifySink;
#endif

#ifndef __IAgentNotifySinkEx_FWD_DEFINED__
#define __IAgentNotifySinkEx_FWD_DEFINED__
  typedef struct IAgentNotifySinkEx IAgentNotifySinkEx;
#endif

#ifndef __IAgentCommandWindow_FWD_DEFINED__
#define __IAgentCommandWindow_FWD_DEFINED__
  typedef struct IAgentCommandWindow IAgentCommandWindow;
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define NeverMoved (0)
#define UserMoved (1)
#define ProgramMoved (2)
#define OtherProgramMoved (3)
#define SystemMoved (4)

#define NeverShown (0)
#define UserHid (1)
#define UserShowed (2)
#define ProgramHid (3)
#define ProgramShowed (4)
#define OtherProgramHid (5)
#define OtherProgramShowed (6)
#define UserHidViaCharacterMenu (7)

#define UserHidViaTaskbarIcon (UserHid)

#define CSHELPCAUSE_COMMAND (1)
#define CSHELPCAUSE_OTHERPROGRAM (2)
#define CSHELPCAUSE_OPENCOMMANDSWINDOW (3)
#define CSHELPCAUSE_CLOSECOMMANDSWINDOW (4)
#define CSHELPCAUSE_SHOWCHARACTER (5)
#define CSHELPCAUSE_HIDECHARACTER (6)
#define CSHELPCAUSE_CHARACTER (7)

#define ACTIVATE_NOTTOPMOST (0)
#define ACTIVATE_TOPMOST (1)
#define ACTIVATE_NOTACTIVE (0)
#define ACTIVATE_ACTIVE (1)
#define ACTIVATE_INPUTACTIVE (2)

#define PREPARE_ANIMATION (0)
#define PREPARE_STATE (1)
#define PREPARE_WAVE (2)

#define STOP_TYPE_PLAY (0x1)
#define STOP_TYPE_MOVE (0x2)
#define STOP_TYPE_SPEAK (0x4)
#define STOP_TYPE_PREPARE (0x8)
#define STOP_TYPE_NONQUEUEDPREPARE (0x10)
#define STOP_TYPE_VISIBLE (0x20)

#define STOP_TYPE_ALL (0xffffffff)

#define BALLOON_STYLE_BALLOON_ON (0x1)
#define BALLOON_STYLE_SIZETOTEXT (0x2)
#define BALLOON_STYLE_AUTOHIDE (0x4)
#define BALLOON_STYLE_AUTOPACE (0x8)

#define AUDIO_STATUS_AVAILABLE (0)
#define AUDIO_STATUS_NOAUDIO (1)
#define AUDIO_STATUS_CANTOPENAUDIO (2)
#define AUDIO_STATUS_USERSPEAKING (3)
#define AUDIO_STATUS_CHARACTERSPEAKING (4)
#define AUDIO_STATUS_SROVERRIDEABLE (5)
#define AUDIO_STATUS_ERROR (6)

#define LISTEN_STATUS_CANLISTEN (0)
#define LISTEN_STATUS_NOAUDIO (1)
#define LISTEN_STATUS_NOTACTIVE (2)
#define LISTEN_STATUS_CANTOPENAUDIO (3)
#define LISTEN_STATUS_COULDNTINITIALIZESPEECH (4)
#define LISTEN_STATUS_SPEECHDISABLED (5)
#define LISTEN_STATUS_ERROR (6)

#define MK_ICON (0x1000)

#define LSCOMPLETE_CAUSE_PROGRAMDISABLED (1)
#define LSCOMPLETE_CAUSE_PROGRAMTIMEDOUT (2)
#define LSCOMPLETE_CAUSE_USERTIMEDOUT (3)
#define LSCOMPLETE_CAUSE_USERRELEASEDKEY (4)
#define LSCOMPLETE_CAUSE_USERUTTERANCEENDED (5)
#define LSCOMPLETE_CAUSE_CLIENTDEACTIVATED (6)
#define LSCOMPLETE_CAUSE_DEFAULTCHARCHANGE (7)
#define LSCOMPLETE_CAUSE_USERDISABLED (8)

  extern RPC_IF_HANDLE __MIDL_itf_AgentServer_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_AgentServer_0000_v0_0_s_ifspec;

#ifndef __IAgentUserInput_INTERFACE_DEFINED__
#define __IAgentUserInput_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentUserInput;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentUserInput : public IDispatch {
  public:
    virtual HRESULT WINAPI GetCount(__LONG32 *pdwCount) = 0;
    virtual HRESULT WINAPI GetItemID(__LONG32 dwItemIndex,__LONG32 *pdwCommandID) = 0;
    virtual HRESULT WINAPI GetItemConfidence(__LONG32 dwItemIndex,__LONG32 *plConfidence) = 0;
    virtual HRESULT WINAPI GetItemText(__LONG32 dwItemIndex,BSTR *pbszText) = 0;
    virtual HRESULT WINAPI GetAllItemData(VARIANT *pdwItemIndices,VARIANT *plConfidences,VARIANT *pbszText) = 0;
  };
#else
  typedef struct IAgentUserInputVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentUserInput *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentUserInput *This);
      ULONG (WINAPI *Release)(IAgentUserInput *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentUserInput *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentUserInput *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentUserInput *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentUserInput *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetCount)(IAgentUserInput *This,__LONG32 *pdwCount);
      HRESULT (WINAPI *GetItemID)(IAgentUserInput *This,__LONG32 dwItemIndex,__LONG32 *pdwCommandID);
      HRESULT (WINAPI *GetItemConfidence)(IAgentUserInput *This,__LONG32 dwItemIndex,__LONG32 *plConfidence);
      HRESULT (WINAPI *GetItemText)(IAgentUserInput *This,__LONG32 dwItemIndex,BSTR *pbszText);
      HRESULT (WINAPI *GetAllItemData)(IAgentUserInput *This,VARIANT *pdwItemIndices,VARIANT *plConfidences,VARIANT *pbszText);
    END_INTERFACE
  } IAgentUserInputVtbl;
  struct IAgentUserInput {
    CONST_VTBL struct IAgentUserInputVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentUserInput_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentUserInput_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentUserInput_Release(This) (This)->lpVtbl->Release(This)
#define IAgentUserInput_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentUserInput_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentUserInput_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentUserInput_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentUserInput_GetCount(This,pdwCount) (This)->lpVtbl->GetCount(This,pdwCount)
#define IAgentUserInput_GetItemID(This,dwItemIndex,pdwCommandID) (This)->lpVtbl->GetItemID(This,dwItemIndex,pdwCommandID)
#define IAgentUserInput_GetItemConfidence(This,dwItemIndex,plConfidence) (This)->lpVtbl->GetItemConfidence(This,dwItemIndex,plConfidence)
#define IAgentUserInput_GetItemText(This,dwItemIndex,pbszText) (This)->lpVtbl->GetItemText(This,dwItemIndex,pbszText)
#define IAgentUserInput_GetAllItemData(This,pdwItemIndices,plConfidences,pbszText) (This)->lpVtbl->GetAllItemData(This,pdwItemIndices,plConfidences,pbszText)
#endif
#endif
  HRESULT WINAPI IAgentUserInput_GetCount_Proxy(IAgentUserInput *This,__LONG32 *pdwCount);
  void __RPC_STUB IAgentUserInput_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentUserInput_GetItemID_Proxy(IAgentUserInput *This,__LONG32 dwItemIndex,__LONG32 *pdwCommandID);
  void __RPC_STUB IAgentUserInput_GetItemID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentUserInput_GetItemConfidence_Proxy(IAgentUserInput *This,__LONG32 dwItemIndex,__LONG32 *plConfidence);
  void __RPC_STUB IAgentUserInput_GetItemConfidence_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentUserInput_GetItemText_Proxy(IAgentUserInput *This,__LONG32 dwItemIndex,BSTR *pbszText);
  void __RPC_STUB IAgentUserInput_GetItemText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentUserInput_GetAllItemData_Proxy(IAgentUserInput *This,VARIANT *pdwItemIndices,VARIANT *plConfidences,VARIANT *pbszText);
  void __RPC_STUB IAgentUserInput_GetAllItemData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCommand_INTERFACE_DEFINED__
#define __IAgentCommand_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCommand;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCommand : public IDispatch {
  public:
    virtual HRESULT WINAPI SetCaption(BSTR bszCaption) = 0;
    virtual HRESULT WINAPI GetCaption(BSTR *pbszCaption) = 0;
    virtual HRESULT WINAPI SetVoice(BSTR bszVoice) = 0;
    virtual HRESULT WINAPI GetVoice(BSTR *pbszVoice) = 0;
    virtual HRESULT WINAPI SetEnabled(__LONG32 bEnabled) = 0;
    virtual HRESULT WINAPI GetEnabled(__LONG32 *pbEnabled) = 0;
    virtual HRESULT WINAPI SetVisible(__LONG32 bVisible) = 0;
    virtual HRESULT WINAPI GetVisible(__LONG32 *pbVisible) = 0;
    virtual HRESULT WINAPI SetConfidenceThreshold(__LONG32 lThreshold) = 0;
    virtual HRESULT WINAPI GetConfidenceThreshold(__LONG32 *plThreshold) = 0;
    virtual HRESULT WINAPI SetConfidenceText(BSTR bszTipText) = 0;
    virtual HRESULT WINAPI GetConfidenceText(BSTR *pbszTipText) = 0;
    virtual HRESULT WINAPI GetID(__LONG32 *pdwID) = 0;
  };
#else
  typedef struct IAgentCommandVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCommand *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCommand *This);
      ULONG (WINAPI *Release)(IAgentCommand *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCommand *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCommand *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCommand *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCommand *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *SetCaption)(IAgentCommand *This,BSTR bszCaption);
      HRESULT (WINAPI *GetCaption)(IAgentCommand *This,BSTR *pbszCaption);
      HRESULT (WINAPI *SetVoice)(IAgentCommand *This,BSTR bszVoice);
      HRESULT (WINAPI *GetVoice)(IAgentCommand *This,BSTR *pbszVoice);
      HRESULT (WINAPI *SetEnabled)(IAgentCommand *This,__LONG32 bEnabled);
      HRESULT (WINAPI *GetEnabled)(IAgentCommand *This,__LONG32 *pbEnabled);
      HRESULT (WINAPI *SetVisible)(IAgentCommand *This,__LONG32 bVisible);
      HRESULT (WINAPI *GetVisible)(IAgentCommand *This,__LONG32 *pbVisible);
      HRESULT (WINAPI *SetConfidenceThreshold)(IAgentCommand *This,__LONG32 lThreshold);
      HRESULT (WINAPI *GetConfidenceThreshold)(IAgentCommand *This,__LONG32 *plThreshold);
      HRESULT (WINAPI *SetConfidenceText)(IAgentCommand *This,BSTR bszTipText);
      HRESULT (WINAPI *GetConfidenceText)(IAgentCommand *This,BSTR *pbszTipText);
      HRESULT (WINAPI *GetID)(IAgentCommand *This,__LONG32 *pdwID);
    END_INTERFACE
  } IAgentCommandVtbl;
  struct IAgentCommand {
    CONST_VTBL struct IAgentCommandVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCommand_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCommand_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCommand_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCommand_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCommand_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCommand_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCommand_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCommand_SetCaption(This,bszCaption) (This)->lpVtbl->SetCaption(This,bszCaption)
#define IAgentCommand_GetCaption(This,pbszCaption) (This)->lpVtbl->GetCaption(This,pbszCaption)
#define IAgentCommand_SetVoice(This,bszVoice) (This)->lpVtbl->SetVoice(This,bszVoice)
#define IAgentCommand_GetVoice(This,pbszVoice) (This)->lpVtbl->GetVoice(This,pbszVoice)
#define IAgentCommand_SetEnabled(This,bEnabled) (This)->lpVtbl->SetEnabled(This,bEnabled)
#define IAgentCommand_GetEnabled(This,pbEnabled) (This)->lpVtbl->GetEnabled(This,pbEnabled)
#define IAgentCommand_SetVisible(This,bVisible) (This)->lpVtbl->SetVisible(This,bVisible)
#define IAgentCommand_GetVisible(This,pbVisible) (This)->lpVtbl->GetVisible(This,pbVisible)
#define IAgentCommand_SetConfidenceThreshold(This,lThreshold) (This)->lpVtbl->SetConfidenceThreshold(This,lThreshold)
#define IAgentCommand_GetConfidenceThreshold(This,plThreshold) (This)->lpVtbl->GetConfidenceThreshold(This,plThreshold)
#define IAgentCommand_SetConfidenceText(This,bszTipText) (This)->lpVtbl->SetConfidenceText(This,bszTipText)
#define IAgentCommand_GetConfidenceText(This,pbszTipText) (This)->lpVtbl->GetConfidenceText(This,pbszTipText)
#define IAgentCommand_GetID(This,pdwID) (This)->lpVtbl->GetID(This,pdwID)
#endif
#endif

  HRESULT WINAPI IAgentCommand_SetCaption_Proxy(IAgentCommand *This,BSTR bszCaption);
  void __RPC_STUB IAgentCommand_SetCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_GetCaption_Proxy(IAgentCommand *This,BSTR *pbszCaption);
  void __RPC_STUB IAgentCommand_GetCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_SetVoice_Proxy(IAgentCommand *This,BSTR bszVoice);
  void __RPC_STUB IAgentCommand_SetVoice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_GetVoice_Proxy(IAgentCommand *This,BSTR *pbszVoice);
  void __RPC_STUB IAgentCommand_GetVoice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_SetEnabled_Proxy(IAgentCommand *This,__LONG32 bEnabled);
  void __RPC_STUB IAgentCommand_SetEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_GetEnabled_Proxy(IAgentCommand *This,__LONG32 *pbEnabled);
  void __RPC_STUB IAgentCommand_GetEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_SetVisible_Proxy(IAgentCommand *This,__LONG32 bVisible);
  void __RPC_STUB IAgentCommand_SetVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_GetVisible_Proxy(IAgentCommand *This,__LONG32 *pbVisible);
  void __RPC_STUB IAgentCommand_GetVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_SetConfidenceThreshold_Proxy(IAgentCommand *This,__LONG32 lThreshold);
  void __RPC_STUB IAgentCommand_SetConfidenceThreshold_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_GetConfidenceThreshold_Proxy(IAgentCommand *This,__LONG32 *plThreshold);
  void __RPC_STUB IAgentCommand_GetConfidenceThreshold_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_SetConfidenceText_Proxy(IAgentCommand *This,BSTR bszTipText);
  void __RPC_STUB IAgentCommand_SetConfidenceText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_GetConfidenceText_Proxy(IAgentCommand *This,BSTR *pbszTipText);
  void __RPC_STUB IAgentCommand_GetConfidenceText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommand_GetID_Proxy(IAgentCommand *This,__LONG32 *pdwID);
  void __RPC_STUB IAgentCommand_GetID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCommandEx_INTERFACE_DEFINED__
#define __IAgentCommandEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCommandEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCommandEx : public IAgentCommand {
  public:
    virtual HRESULT WINAPI SetHelpContextID(__LONG32 ulID) = 0;
    virtual HRESULT WINAPI GetHelpContextID(__LONG32 *pulID) = 0;
    virtual HRESULT WINAPI SetVoiceCaption(BSTR bszVoiceCaption) = 0;
    virtual HRESULT WINAPI GetVoiceCaption(BSTR *pbszVoiceCaption) = 0;
  };
#else
  typedef struct IAgentCommandExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCommandEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCommandEx *This);
      ULONG (WINAPI *Release)(IAgentCommandEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCommandEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCommandEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCommandEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCommandEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *SetCaption)(IAgentCommandEx *This,BSTR bszCaption);
      HRESULT (WINAPI *GetCaption)(IAgentCommandEx *This,BSTR *pbszCaption);
      HRESULT (WINAPI *SetVoice)(IAgentCommandEx *This,BSTR bszVoice);
      HRESULT (WINAPI *GetVoice)(IAgentCommandEx *This,BSTR *pbszVoice);
      HRESULT (WINAPI *SetEnabled)(IAgentCommandEx *This,__LONG32 bEnabled);
      HRESULT (WINAPI *GetEnabled)(IAgentCommandEx *This,__LONG32 *pbEnabled);
      HRESULT (WINAPI *SetVisible)(IAgentCommandEx *This,__LONG32 bVisible);
      HRESULT (WINAPI *GetVisible)(IAgentCommandEx *This,__LONG32 *pbVisible);
      HRESULT (WINAPI *SetConfidenceThreshold)(IAgentCommandEx *This,__LONG32 lThreshold);
      HRESULT (WINAPI *GetConfidenceThreshold)(IAgentCommandEx *This,__LONG32 *plThreshold);
      HRESULT (WINAPI *SetConfidenceText)(IAgentCommandEx *This,BSTR bszTipText);
      HRESULT (WINAPI *GetConfidenceText)(IAgentCommandEx *This,BSTR *pbszTipText);
      HRESULT (WINAPI *GetID)(IAgentCommandEx *This,__LONG32 *pdwID);
      HRESULT (WINAPI *SetHelpContextID)(IAgentCommandEx *This,__LONG32 ulID);
      HRESULT (WINAPI *GetHelpContextID)(IAgentCommandEx *This,__LONG32 *pulID);
      HRESULT (WINAPI *SetVoiceCaption)(IAgentCommandEx *This,BSTR bszVoiceCaption);
      HRESULT (WINAPI *GetVoiceCaption)(IAgentCommandEx *This,BSTR *pbszVoiceCaption);
    END_INTERFACE
  } IAgentCommandExVtbl;
  struct IAgentCommandEx {
    CONST_VTBL struct IAgentCommandExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCommandEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCommandEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCommandEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCommandEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCommandEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCommandEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCommandEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCommandEx_SetCaption(This,bszCaption) (This)->lpVtbl->SetCaption(This,bszCaption)
#define IAgentCommandEx_GetCaption(This,pbszCaption) (This)->lpVtbl->GetCaption(This,pbszCaption)
#define IAgentCommandEx_SetVoice(This,bszVoice) (This)->lpVtbl->SetVoice(This,bszVoice)
#define IAgentCommandEx_GetVoice(This,pbszVoice) (This)->lpVtbl->GetVoice(This,pbszVoice)
#define IAgentCommandEx_SetEnabled(This,bEnabled) (This)->lpVtbl->SetEnabled(This,bEnabled)
#define IAgentCommandEx_GetEnabled(This,pbEnabled) (This)->lpVtbl->GetEnabled(This,pbEnabled)
#define IAgentCommandEx_SetVisible(This,bVisible) (This)->lpVtbl->SetVisible(This,bVisible)
#define IAgentCommandEx_GetVisible(This,pbVisible) (This)->lpVtbl->GetVisible(This,pbVisible)
#define IAgentCommandEx_SetConfidenceThreshold(This,lThreshold) (This)->lpVtbl->SetConfidenceThreshold(This,lThreshold)
#define IAgentCommandEx_GetConfidenceThreshold(This,plThreshold) (This)->lpVtbl->GetConfidenceThreshold(This,plThreshold)
#define IAgentCommandEx_SetConfidenceText(This,bszTipText) (This)->lpVtbl->SetConfidenceText(This,bszTipText)
#define IAgentCommandEx_GetConfidenceText(This,pbszTipText) (This)->lpVtbl->GetConfidenceText(This,pbszTipText)
#define IAgentCommandEx_GetID(This,pdwID) (This)->lpVtbl->GetID(This,pdwID)
#define IAgentCommandEx_SetHelpContextID(This,ulID) (This)->lpVtbl->SetHelpContextID(This,ulID)
#define IAgentCommandEx_GetHelpContextID(This,pulID) (This)->lpVtbl->GetHelpContextID(This,pulID)
#define IAgentCommandEx_SetVoiceCaption(This,bszVoiceCaption) (This)->lpVtbl->SetVoiceCaption(This,bszVoiceCaption)
#define IAgentCommandEx_GetVoiceCaption(This,pbszVoiceCaption) (This)->lpVtbl->GetVoiceCaption(This,pbszVoiceCaption)
#endif
#endif
  HRESULT WINAPI IAgentCommandEx_SetHelpContextID_Proxy(IAgentCommandEx *This,__LONG32 ulID);
  void __RPC_STUB IAgentCommandEx_SetHelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandEx_GetHelpContextID_Proxy(IAgentCommandEx *This,__LONG32 *pulID);
  void __RPC_STUB IAgentCommandEx_GetHelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandEx_SetVoiceCaption_Proxy(IAgentCommandEx *This,BSTR bszVoiceCaption);
  void __RPC_STUB IAgentCommandEx_SetVoiceCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandEx_GetVoiceCaption_Proxy(IAgentCommandEx *This,BSTR *pbszVoiceCaption);
  void __RPC_STUB IAgentCommandEx_GetVoiceCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCommands_INTERFACE_DEFINED__
#define __IAgentCommands_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCommands;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCommands : public IDispatch {
  public:
    virtual HRESULT WINAPI GetCommand(__LONG32 dwCommandID,IUnknown **ppunkCommand) = 0;
    virtual HRESULT WINAPI GetCount(__LONG32 *pdwCount) = 0;
    virtual HRESULT WINAPI SetCaption(BSTR bszCaption) = 0;
    virtual HRESULT WINAPI GetCaption(BSTR *pbszCaption) = 0;
    virtual HRESULT WINAPI SetVoice(BSTR bszVoice) = 0;
    virtual HRESULT WINAPI GetVoice(BSTR *pbszVoice) = 0;
    virtual HRESULT WINAPI SetVisible(__LONG32 bVisible) = 0;
    virtual HRESULT WINAPI GetVisible(__LONG32 *pbVisible) = 0;
    virtual HRESULT WINAPI Add(BSTR bszCaption,BSTR bszVoice,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 *pdwID) = 0;
    virtual HRESULT WINAPI Insert(BSTR bszCaption,BSTR bszVoice,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 dwRefID,__LONG32 bBefore,__LONG32 *pdwID) = 0;
    virtual HRESULT WINAPI Remove(__LONG32 dwID) = 0;
    virtual HRESULT WINAPI RemoveAll(void) = 0;
  };
#else
  typedef struct IAgentCommandsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCommands *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCommands *This);
      ULONG (WINAPI *Release)(IAgentCommands *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCommands *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCommands *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCommands *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCommands *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetCommand)(IAgentCommands *This,__LONG32 dwCommandID,IUnknown **ppunkCommand);
      HRESULT (WINAPI *GetCount)(IAgentCommands *This,__LONG32 *pdwCount);
      HRESULT (WINAPI *SetCaption)(IAgentCommands *This,BSTR bszCaption);
      HRESULT (WINAPI *GetCaption)(IAgentCommands *This,BSTR *pbszCaption);
      HRESULT (WINAPI *SetVoice)(IAgentCommands *This,BSTR bszVoice);
      HRESULT (WINAPI *GetVoice)(IAgentCommands *This,BSTR *pbszVoice);
      HRESULT (WINAPI *SetVisible)(IAgentCommands *This,__LONG32 bVisible);
      HRESULT (WINAPI *GetVisible)(IAgentCommands *This,__LONG32 *pbVisible);
      HRESULT (WINAPI *Add)(IAgentCommands *This,BSTR bszCaption,BSTR bszVoice,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 *pdwID);
      HRESULT (WINAPI *Insert)(IAgentCommands *This,BSTR bszCaption,BSTR bszVoice,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 dwRefID,__LONG32 bBefore,__LONG32 *pdwID);
      HRESULT (WINAPI *Remove)(IAgentCommands *This,__LONG32 dwID);
      HRESULT (WINAPI *RemoveAll)(IAgentCommands *This);
    END_INTERFACE
  } IAgentCommandsVtbl;
  struct IAgentCommands {
    CONST_VTBL struct IAgentCommandsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCommands_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCommands_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCommands_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCommands_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCommands_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCommands_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCommands_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCommands_GetCommand(This,dwCommandID,ppunkCommand) (This)->lpVtbl->GetCommand(This,dwCommandID,ppunkCommand)
#define IAgentCommands_GetCount(This,pdwCount) (This)->lpVtbl->GetCount(This,pdwCount)
#define IAgentCommands_SetCaption(This,bszCaption) (This)->lpVtbl->SetCaption(This,bszCaption)
#define IAgentCommands_GetCaption(This,pbszCaption) (This)->lpVtbl->GetCaption(This,pbszCaption)
#define IAgentCommands_SetVoice(This,bszVoice) (This)->lpVtbl->SetVoice(This,bszVoice)
#define IAgentCommands_GetVoice(This,pbszVoice) (This)->lpVtbl->GetVoice(This,pbszVoice)
#define IAgentCommands_SetVisible(This,bVisible) (This)->lpVtbl->SetVisible(This,bVisible)
#define IAgentCommands_GetVisible(This,pbVisible) (This)->lpVtbl->GetVisible(This,pbVisible)
#define IAgentCommands_Add(This,bszCaption,bszVoice,bEnabled,bVisible,pdwID) (This)->lpVtbl->Add(This,bszCaption,bszVoice,bEnabled,bVisible,pdwID)
#define IAgentCommands_Insert(This,bszCaption,bszVoice,bEnabled,bVisible,dwRefID,bBefore,pdwID) (This)->lpVtbl->Insert(This,bszCaption,bszVoice,bEnabled,bVisible,dwRefID,bBefore,pdwID)
#define IAgentCommands_Remove(This,dwID) (This)->lpVtbl->Remove(This,dwID)
#define IAgentCommands_RemoveAll(This) (This)->lpVtbl->RemoveAll(This)
#endif
#endif
  HRESULT WINAPI IAgentCommands_GetCommand_Proxy(IAgentCommands *This,__LONG32 dwCommandID,IUnknown **ppunkCommand);
  void __RPC_STUB IAgentCommands_GetCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommands_GetCount_Proxy(IAgentCommands *This,__LONG32 *pdwCount);
  void __RPC_STUB IAgentCommands_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommands_SetCaption_Proxy(IAgentCommands *This,BSTR bszCaption);
  void __RPC_STUB IAgentCommands_SetCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommands_GetCaption_Proxy(IAgentCommands *This,BSTR *pbszCaption);
  void __RPC_STUB IAgentCommands_GetCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommands_SetVoice_Proxy(IAgentCommands *This,BSTR bszVoice);
  void __RPC_STUB IAgentCommands_SetVoice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommands_GetVoice_Proxy(IAgentCommands *This,BSTR *pbszVoice);
  void __RPC_STUB IAgentCommands_GetVoice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommands_SetVisible_Proxy(IAgentCommands *This,__LONG32 bVisible);
  void __RPC_STUB IAgentCommands_SetVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommands_GetVisible_Proxy(IAgentCommands *This,__LONG32 *pbVisible);
  void __RPC_STUB IAgentCommands_GetVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommands_Add_Proxy(IAgentCommands *This,BSTR bszCaption,BSTR bszVoice,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 *pdwID);
  void __RPC_STUB IAgentCommands_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommands_Insert_Proxy(IAgentCommands *This,BSTR bszCaption,BSTR bszVoice,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 dwRefID,__LONG32 bBefore,__LONG32 *pdwID);
  void __RPC_STUB IAgentCommands_Insert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommands_Remove_Proxy(IAgentCommands *This,__LONG32 dwID);
  void __RPC_STUB IAgentCommands_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommands_RemoveAll_Proxy(IAgentCommands *This);
  void __RPC_STUB IAgentCommands_RemoveAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCommandsEx_INTERFACE_DEFINED__
#define __IAgentCommandsEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCommandsEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCommandsEx : public IAgentCommands {
  public:
    virtual HRESULT WINAPI GetCommandEx(__LONG32 dwCommandID,IAgentCommandEx **ppCommandEx) = 0;
    virtual HRESULT WINAPI SetDefaultID(__LONG32 dwID) = 0;
    virtual HRESULT WINAPI GetDefaultID(__LONG32 *pdwID) = 0;
    virtual HRESULT WINAPI SetHelpContextID(__LONG32 ulHelpID) = 0;
    virtual HRESULT WINAPI GetHelpContextID(__LONG32 *pulHelpID) = 0;
    virtual HRESULT WINAPI SetFontName(BSTR bszFontName) = 0;
    virtual HRESULT WINAPI GetFontName(BSTR *pbszFontName) = 0;
    virtual HRESULT WINAPI SetFontSize(__LONG32 lFontSize) = 0;
    virtual HRESULT WINAPI GetFontSize(__LONG32 *lFontSize) = 0;
    virtual HRESULT WINAPI SetVoiceCaption(BSTR bszVoiceCaption) = 0;
    virtual HRESULT WINAPI GetVoiceCaption(BSTR *bszVoiceCaption) = 0;
    virtual HRESULT WINAPI AddEx(BSTR bszCaption,BSTR bszVoice,BSTR bszVoiceCaption,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 ulHelpId,__LONG32 *pdwID) = 0;
    virtual HRESULT WINAPI InsertEx(BSTR bszCaption,BSTR bszVoice,BSTR bszVoiceCaption,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 ulHelpId,__LONG32 dwRefID,__LONG32 bBefore,__LONG32 *pdwID) = 0;
    virtual HRESULT WINAPI SetGlobalVoiceCommandsEnabled(__LONG32 bEnable) = 0;
    virtual HRESULT WINAPI GetGlobalVoiceCommandsEnabled(__LONG32 *pbEnabled) = 0;
  };
#else
  typedef struct IAgentCommandsExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCommandsEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCommandsEx *This);
      ULONG (WINAPI *Release)(IAgentCommandsEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCommandsEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCommandsEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCommandsEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCommandsEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetCommand)(IAgentCommandsEx *This,__LONG32 dwCommandID,IUnknown **ppunkCommand);
      HRESULT (WINAPI *GetCount)(IAgentCommandsEx *This,__LONG32 *pdwCount);
      HRESULT (WINAPI *SetCaption)(IAgentCommandsEx *This,BSTR bszCaption);
      HRESULT (WINAPI *GetCaption)(IAgentCommandsEx *This,BSTR *pbszCaption);
      HRESULT (WINAPI *SetVoice)(IAgentCommandsEx *This,BSTR bszVoice);
      HRESULT (WINAPI *GetVoice)(IAgentCommandsEx *This,BSTR *pbszVoice);
      HRESULT (WINAPI *SetVisible)(IAgentCommandsEx *This,__LONG32 bVisible);
      HRESULT (WINAPI *GetVisible)(IAgentCommandsEx *This,__LONG32 *pbVisible);
      HRESULT (WINAPI *Add)(IAgentCommandsEx *This,BSTR bszCaption,BSTR bszVoice,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 *pdwID);
      HRESULT (WINAPI *Insert)(IAgentCommandsEx *This,BSTR bszCaption,BSTR bszVoice,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 dwRefID,__LONG32 bBefore,__LONG32 *pdwID);
      HRESULT (WINAPI *Remove)(IAgentCommandsEx *This,__LONG32 dwID);
      HRESULT (WINAPI *RemoveAll)(IAgentCommandsEx *This);
      HRESULT (WINAPI *GetCommandEx)(IAgentCommandsEx *This,__LONG32 dwCommandID,IAgentCommandEx **ppCommandEx);
      HRESULT (WINAPI *SetDefaultID)(IAgentCommandsEx *This,__LONG32 dwID);
      HRESULT (WINAPI *GetDefaultID)(IAgentCommandsEx *This,__LONG32 *pdwID);
      HRESULT (WINAPI *SetHelpContextID)(IAgentCommandsEx *This,__LONG32 ulHelpID);
      HRESULT (WINAPI *GetHelpContextID)(IAgentCommandsEx *This,__LONG32 *pulHelpID);
      HRESULT (WINAPI *SetFontName)(IAgentCommandsEx *This,BSTR bszFontName);
      HRESULT (WINAPI *GetFontName)(IAgentCommandsEx *This,BSTR *pbszFontName);
      HRESULT (WINAPI *SetFontSize)(IAgentCommandsEx *This,__LONG32 lFontSize);
      HRESULT (WINAPI *GetFontSize)(IAgentCommandsEx *This,__LONG32 *lFontSize);
      HRESULT (WINAPI *SetVoiceCaption)(IAgentCommandsEx *This,BSTR bszVoiceCaption);
      HRESULT (WINAPI *GetVoiceCaption)(IAgentCommandsEx *This,BSTR *bszVoiceCaption);
      HRESULT (WINAPI *AddEx)(IAgentCommandsEx *This,BSTR bszCaption,BSTR bszVoice,BSTR bszVoiceCaption,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 ulHelpId,__LONG32 *pdwID);
      HRESULT (WINAPI *InsertEx)(IAgentCommandsEx *This,BSTR bszCaption,BSTR bszVoice,BSTR bszVoiceCaption,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 ulHelpId,__LONG32 dwRefID,__LONG32 bBefore,__LONG32 *pdwID);
      HRESULT (WINAPI *SetGlobalVoiceCommandsEnabled)(IAgentCommandsEx *This,__LONG32 bEnable);
      HRESULT (WINAPI *GetGlobalVoiceCommandsEnabled)(IAgentCommandsEx *This,__LONG32 *pbEnabled);
    END_INTERFACE
  } IAgentCommandsExVtbl;
  struct IAgentCommandsEx {
    CONST_VTBL struct IAgentCommandsExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCommandsEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCommandsEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCommandsEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCommandsEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCommandsEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCommandsEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCommandsEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCommandsEx_GetCommand(This,dwCommandID,ppunkCommand) (This)->lpVtbl->GetCommand(This,dwCommandID,ppunkCommand)
#define IAgentCommandsEx_GetCount(This,pdwCount) (This)->lpVtbl->GetCount(This,pdwCount)
#define IAgentCommandsEx_SetCaption(This,bszCaption) (This)->lpVtbl->SetCaption(This,bszCaption)
#define IAgentCommandsEx_GetCaption(This,pbszCaption) (This)->lpVtbl->GetCaption(This,pbszCaption)
#define IAgentCommandsEx_SetVoice(This,bszVoice) (This)->lpVtbl->SetVoice(This,bszVoice)
#define IAgentCommandsEx_GetVoice(This,pbszVoice) (This)->lpVtbl->GetVoice(This,pbszVoice)
#define IAgentCommandsEx_SetVisible(This,bVisible) (This)->lpVtbl->SetVisible(This,bVisible)
#define IAgentCommandsEx_GetVisible(This,pbVisible) (This)->lpVtbl->GetVisible(This,pbVisible)
#define IAgentCommandsEx_Add(This,bszCaption,bszVoice,bEnabled,bVisible,pdwID) (This)->lpVtbl->Add(This,bszCaption,bszVoice,bEnabled,bVisible,pdwID)
#define IAgentCommandsEx_Insert(This,bszCaption,bszVoice,bEnabled,bVisible,dwRefID,bBefore,pdwID) (This)->lpVtbl->Insert(This,bszCaption,bszVoice,bEnabled,bVisible,dwRefID,bBefore,pdwID)
#define IAgentCommandsEx_Remove(This,dwID) (This)->lpVtbl->Remove(This,dwID)
#define IAgentCommandsEx_RemoveAll(This) (This)->lpVtbl->RemoveAll(This)
#define IAgentCommandsEx_GetCommandEx(This,dwCommandID,ppCommandEx) (This)->lpVtbl->GetCommandEx(This,dwCommandID,ppCommandEx)
#define IAgentCommandsEx_SetDefaultID(This,dwID) (This)->lpVtbl->SetDefaultID(This,dwID)
#define IAgentCommandsEx_GetDefaultID(This,pdwID) (This)->lpVtbl->GetDefaultID(This,pdwID)
#define IAgentCommandsEx_SetHelpContextID(This,ulHelpID) (This)->lpVtbl->SetHelpContextID(This,ulHelpID)
#define IAgentCommandsEx_GetHelpContextID(This,pulHelpID) (This)->lpVtbl->GetHelpContextID(This,pulHelpID)
#define IAgentCommandsEx_SetFontName(This,bszFontName) (This)->lpVtbl->SetFontName(This,bszFontName)
#define IAgentCommandsEx_GetFontName(This,pbszFontName) (This)->lpVtbl->GetFontName(This,pbszFontName)
#define IAgentCommandsEx_SetFontSize(This,lFontSize) (This)->lpVtbl->SetFontSize(This,lFontSize)
#define IAgentCommandsEx_GetFontSize(This,lFontSize) (This)->lpVtbl->GetFontSize(This,lFontSize)
#define IAgentCommandsEx_SetVoiceCaption(This,bszVoiceCaption) (This)->lpVtbl->SetVoiceCaption(This,bszVoiceCaption)
#define IAgentCommandsEx_GetVoiceCaption(This,bszVoiceCaption) (This)->lpVtbl->GetVoiceCaption(This,bszVoiceCaption)
#define IAgentCommandsEx_AddEx(This,bszCaption,bszVoice,bszVoiceCaption,bEnabled,bVisible,ulHelpId,pdwID) (This)->lpVtbl->AddEx(This,bszCaption,bszVoice,bszVoiceCaption,bEnabled,bVisible,ulHelpId,pdwID)
#define IAgentCommandsEx_InsertEx(This,bszCaption,bszVoice,bszVoiceCaption,bEnabled,bVisible,ulHelpId,dwRefID,bBefore,pdwID) (This)->lpVtbl->InsertEx(This,bszCaption,bszVoice,bszVoiceCaption,bEnabled,bVisible,ulHelpId,dwRefID,bBefore,pdwID)
#define IAgentCommandsEx_SetGlobalVoiceCommandsEnabled(This,bEnable) (This)->lpVtbl->SetGlobalVoiceCommandsEnabled(This,bEnable)
#define IAgentCommandsEx_GetGlobalVoiceCommandsEnabled(This,pbEnabled) (This)->lpVtbl->GetGlobalVoiceCommandsEnabled(This,pbEnabled)
#endif
#endif
  HRESULT WINAPI IAgentCommandsEx_GetCommandEx_Proxy(IAgentCommandsEx *This,__LONG32 dwCommandID,IAgentCommandEx **ppCommandEx);
  void __RPC_STUB IAgentCommandsEx_GetCommandEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_SetDefaultID_Proxy(IAgentCommandsEx *This,__LONG32 dwID);
  void __RPC_STUB IAgentCommandsEx_SetDefaultID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_GetDefaultID_Proxy(IAgentCommandsEx *This,__LONG32 *pdwID);
  void __RPC_STUB IAgentCommandsEx_GetDefaultID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_SetHelpContextID_Proxy(IAgentCommandsEx *This,__LONG32 ulHelpID);
  void __RPC_STUB IAgentCommandsEx_SetHelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_GetHelpContextID_Proxy(IAgentCommandsEx *This,__LONG32 *pulHelpID);
  void __RPC_STUB IAgentCommandsEx_GetHelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_SetFontName_Proxy(IAgentCommandsEx *This,BSTR bszFontName);
  void __RPC_STUB IAgentCommandsEx_SetFontName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_GetFontName_Proxy(IAgentCommandsEx *This,BSTR *pbszFontName);
  void __RPC_STUB IAgentCommandsEx_GetFontName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_SetFontSize_Proxy(IAgentCommandsEx *This,__LONG32 lFontSize);
  void __RPC_STUB IAgentCommandsEx_SetFontSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_GetFontSize_Proxy(IAgentCommandsEx *This,__LONG32 *lFontSize);
  void __RPC_STUB IAgentCommandsEx_GetFontSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_SetVoiceCaption_Proxy(IAgentCommandsEx *This,BSTR bszVoiceCaption);
  void __RPC_STUB IAgentCommandsEx_SetVoiceCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_GetVoiceCaption_Proxy(IAgentCommandsEx *This,BSTR *bszVoiceCaption);
  void __RPC_STUB IAgentCommandsEx_GetVoiceCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_AddEx_Proxy(IAgentCommandsEx *This,BSTR bszCaption,BSTR bszVoice,BSTR bszVoiceCaption,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 ulHelpId,__LONG32 *pdwID);
  void __RPC_STUB IAgentCommandsEx_AddEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_InsertEx_Proxy(IAgentCommandsEx *This,BSTR bszCaption,BSTR bszVoice,BSTR bszVoiceCaption,__LONG32 bEnabled,__LONG32 bVisible,__LONG32 ulHelpId,__LONG32 dwRefID,__LONG32 bBefore,__LONG32 *pdwID);
  void __RPC_STUB IAgentCommandsEx_InsertEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_SetGlobalVoiceCommandsEnabled_Proxy(IAgentCommandsEx *This,__LONG32 bEnable);
  void __RPC_STUB IAgentCommandsEx_SetGlobalVoiceCommandsEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandsEx_GetGlobalVoiceCommandsEnabled_Proxy(IAgentCommandsEx *This,__LONG32 *pbEnabled);
  void __RPC_STUB IAgentCommandsEx_GetGlobalVoiceCommandsEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCommandWindow_INTERFACE_DEFINED__
#define __IAgentCommandWindow_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCommandWindow;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCommandWindow : public IDispatch {
  public:
    virtual HRESULT WINAPI SetVisible(__LONG32 bVisible) = 0;
    virtual HRESULT WINAPI GetVisible(__LONG32 *pbVisible) = 0;
    virtual HRESULT WINAPI GetPosition(__LONG32 *plLeft,__LONG32 *plTop) = 0;
    virtual HRESULT WINAPI GetSize(__LONG32 *plWidth,__LONG32 *plHeight) = 0;
  };
#else
  typedef struct IAgentCommandWindowVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCommandWindow *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCommandWindow *This);
      ULONG (WINAPI *Release)(IAgentCommandWindow *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCommandWindow *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCommandWindow *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCommandWindow *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCommandWindow *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *SetVisible)(IAgentCommandWindow *This,__LONG32 bVisible);
      HRESULT (WINAPI *GetVisible)(IAgentCommandWindow *This,__LONG32 *pbVisible);
      HRESULT (WINAPI *GetPosition)(IAgentCommandWindow *This,__LONG32 *plLeft,__LONG32 *plTop);
      HRESULT (WINAPI *GetSize)(IAgentCommandWindow *This,__LONG32 *plWidth,__LONG32 *plHeight);
    END_INTERFACE
  } IAgentCommandWindowVtbl;
  struct IAgentCommandWindow {
    CONST_VTBL struct IAgentCommandWindowVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCommandWindow_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCommandWindow_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCommandWindow_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCommandWindow_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCommandWindow_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCommandWindow_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCommandWindow_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCommandWindow_SetVisible(This,bVisible) (This)->lpVtbl->SetVisible(This,bVisible)
#define IAgentCommandWindow_GetVisible(This,pbVisible) (This)->lpVtbl->GetVisible(This,pbVisible)
#define IAgentCommandWindow_GetPosition(This,plLeft,plTop) (This)->lpVtbl->GetPosition(This,plLeft,plTop)
#define IAgentCommandWindow_GetSize(This,plWidth,plHeight) (This)->lpVtbl->GetSize(This,plWidth,plHeight)
#endif
#endif
  HRESULT WINAPI IAgentCommandWindow_SetVisible_Proxy(IAgentCommandWindow *This,__LONG32 bVisible);
  void __RPC_STUB IAgentCommandWindow_SetVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandWindow_GetVisible_Proxy(IAgentCommandWindow *This,__LONG32 *pbVisible);
  void __RPC_STUB IAgentCommandWindow_GetVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandWindow_GetPosition_Proxy(IAgentCommandWindow *This,__LONG32 *plLeft,__LONG32 *plTop);
  void __RPC_STUB IAgentCommandWindow_GetPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCommandWindow_GetSize_Proxy(IAgentCommandWindow *This,__LONG32 *plWidth,__LONG32 *plHeight);
  void __RPC_STUB IAgentCommandWindow_GetSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentSpeechInputProperties_INTERFACE_DEFINED__
#define __IAgentSpeechInputProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentSpeechInputProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentSpeechInputProperties : public IDispatch {
  public:
    virtual HRESULT WINAPI GetInstalled(__LONG32 *pbInstalled) = 0;
    virtual HRESULT WINAPI GetEnabled(__LONG32 *pbEnabled) = 0;
    virtual HRESULT WINAPI GetHotKey(BSTR *pbszHotCharKey) = 0;
    virtual HRESULT WINAPI GetLCID(LCID *plcidCurrent) = 0;
    virtual HRESULT WINAPI GetEngine(BSTR *pbszEngine) = 0;
    virtual HRESULT WINAPI SetEngine(BSTR bszEngine) = 0;
    virtual HRESULT WINAPI GetListeningTip(__LONG32 *pbListeningTip) = 0;
  };
#else
  typedef struct IAgentSpeechInputPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentSpeechInputProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentSpeechInputProperties *This);
      ULONG (WINAPI *Release)(IAgentSpeechInputProperties *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentSpeechInputProperties *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentSpeechInputProperties *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentSpeechInputProperties *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentSpeechInputProperties *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetInstalled)(IAgentSpeechInputProperties *This,__LONG32 *pbInstalled);
      HRESULT (WINAPI *GetEnabled)(IAgentSpeechInputProperties *This,__LONG32 *pbEnabled);
      HRESULT (WINAPI *GetHotKey)(IAgentSpeechInputProperties *This,BSTR *pbszHotCharKey);
      HRESULT (WINAPI *GetLCID)(IAgentSpeechInputProperties *This,LCID *plcidCurrent);
      HRESULT (WINAPI *GetEngine)(IAgentSpeechInputProperties *This,BSTR *pbszEngine);
      HRESULT (WINAPI *SetEngine)(IAgentSpeechInputProperties *This,BSTR bszEngine);
      HRESULT (WINAPI *GetListeningTip)(IAgentSpeechInputProperties *This,__LONG32 *pbListeningTip);
    END_INTERFACE
  } IAgentSpeechInputPropertiesVtbl;
  struct IAgentSpeechInputProperties {
    CONST_VTBL struct IAgentSpeechInputPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentSpeechInputProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentSpeechInputProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentSpeechInputProperties_Release(This) (This)->lpVtbl->Release(This)
#define IAgentSpeechInputProperties_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentSpeechInputProperties_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentSpeechInputProperties_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentSpeechInputProperties_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentSpeechInputProperties_GetInstalled(This,pbInstalled) (This)->lpVtbl->GetInstalled(This,pbInstalled)
#define IAgentSpeechInputProperties_GetEnabled(This,pbEnabled) (This)->lpVtbl->GetEnabled(This,pbEnabled)
#define IAgentSpeechInputProperties_GetHotKey(This,pbszHotCharKey) (This)->lpVtbl->GetHotKey(This,pbszHotCharKey)
#define IAgentSpeechInputProperties_GetLCID(This,plcidCurrent) (This)->lpVtbl->GetLCID(This,plcidCurrent)
#define IAgentSpeechInputProperties_GetEngine(This,pbszEngine) (This)->lpVtbl->GetEngine(This,pbszEngine)
#define IAgentSpeechInputProperties_SetEngine(This,bszEngine) (This)->lpVtbl->SetEngine(This,bszEngine)
#define IAgentSpeechInputProperties_GetListeningTip(This,pbListeningTip) (This)->lpVtbl->GetListeningTip(This,pbListeningTip)
#endif
#endif
  HRESULT WINAPI IAgentSpeechInputProperties_GetInstalled_Proxy(IAgentSpeechInputProperties *This,__LONG32 *pbInstalled);
  void __RPC_STUB IAgentSpeechInputProperties_GetInstalled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentSpeechInputProperties_GetEnabled_Proxy(IAgentSpeechInputProperties *This,__LONG32 *pbEnabled);
  void __RPC_STUB IAgentSpeechInputProperties_GetEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentSpeechInputProperties_GetHotKey_Proxy(IAgentSpeechInputProperties *This,BSTR *pbszHotCharKey);
  void __RPC_STUB IAgentSpeechInputProperties_GetHotKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentSpeechInputProperties_GetLCID_Proxy(IAgentSpeechInputProperties *This,LCID *plcidCurrent);
  void __RPC_STUB IAgentSpeechInputProperties_GetLCID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentSpeechInputProperties_GetEngine_Proxy(IAgentSpeechInputProperties *This,BSTR *pbszEngine);
  void __RPC_STUB IAgentSpeechInputProperties_GetEngine_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentSpeechInputProperties_SetEngine_Proxy(IAgentSpeechInputProperties *This,BSTR bszEngine);
  void __RPC_STUB IAgentSpeechInputProperties_SetEngine_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentSpeechInputProperties_GetListeningTip_Proxy(IAgentSpeechInputProperties *This,__LONG32 *pbListeningTip);
  void __RPC_STUB IAgentSpeechInputProperties_GetListeningTip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentAudioOutputProperties_INTERFACE_DEFINED__
#define __IAgentAudioOutputProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentAudioOutputProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentAudioOutputProperties : public IDispatch {
  public:
    virtual HRESULT WINAPI GetEnabled(__LONG32 *pbEnabled) = 0;
    virtual HRESULT WINAPI GetUsingSoundEffects(__LONG32 *pbUsingSoundEffects) = 0;
  };
#else
  typedef struct IAgentAudioOutputPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentAudioOutputProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentAudioOutputProperties *This);
      ULONG (WINAPI *Release)(IAgentAudioOutputProperties *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentAudioOutputProperties *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentAudioOutputProperties *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentAudioOutputProperties *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentAudioOutputProperties *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetEnabled)(IAgentAudioOutputProperties *This,__LONG32 *pbEnabled);
      HRESULT (WINAPI *GetUsingSoundEffects)(IAgentAudioOutputProperties *This,__LONG32 *pbUsingSoundEffects);
    END_INTERFACE
  } IAgentAudioOutputPropertiesVtbl;
  struct IAgentAudioOutputProperties {
    CONST_VTBL struct IAgentAudioOutputPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentAudioOutputProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentAudioOutputProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentAudioOutputProperties_Release(This) (This)->lpVtbl->Release(This)
#define IAgentAudioOutputProperties_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentAudioOutputProperties_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentAudioOutputProperties_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentAudioOutputProperties_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentAudioOutputProperties_GetEnabled(This,pbEnabled) (This)->lpVtbl->GetEnabled(This,pbEnabled)
#define IAgentAudioOutputProperties_GetUsingSoundEffects(This,pbUsingSoundEffects) (This)->lpVtbl->GetUsingSoundEffects(This,pbUsingSoundEffects)
#endif
#endif
  HRESULT WINAPI IAgentAudioOutputProperties_GetEnabled_Proxy(IAgentAudioOutputProperties *This,__LONG32 *pbEnabled);
  void __RPC_STUB IAgentAudioOutputProperties_GetEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentAudioOutputProperties_GetUsingSoundEffects_Proxy(IAgentAudioOutputProperties *This,__LONG32 *pbUsingSoundEffects);
  void __RPC_STUB IAgentAudioOutputProperties_GetUsingSoundEffects_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentAudioOutputPropertiesEx_INTERFACE_DEFINED__
#define __IAgentAudioOutputPropertiesEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentAudioOutputPropertiesEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentAudioOutputPropertiesEx : public IAgentAudioOutputProperties {
  public:
    virtual HRESULT WINAPI GetStatus(__LONG32 *plStatus) = 0;
  };
#else
  typedef struct IAgentAudioOutputPropertiesExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentAudioOutputPropertiesEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentAudioOutputPropertiesEx *This);
      ULONG (WINAPI *Release)(IAgentAudioOutputPropertiesEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentAudioOutputPropertiesEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentAudioOutputPropertiesEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentAudioOutputPropertiesEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentAudioOutputPropertiesEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetEnabled)(IAgentAudioOutputPropertiesEx *This,__LONG32 *pbEnabled);
      HRESULT (WINAPI *GetUsingSoundEffects)(IAgentAudioOutputPropertiesEx *This,__LONG32 *pbUsingSoundEffects);
      HRESULT (WINAPI *GetStatus)(IAgentAudioOutputPropertiesEx *This,__LONG32 *plStatus);
    END_INTERFACE
  } IAgentAudioOutputPropertiesExVtbl;
  struct IAgentAudioOutputPropertiesEx {
    CONST_VTBL struct IAgentAudioOutputPropertiesExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentAudioOutputPropertiesEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentAudioOutputPropertiesEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentAudioOutputPropertiesEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentAudioOutputPropertiesEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentAudioOutputPropertiesEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentAudioOutputPropertiesEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentAudioOutputPropertiesEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentAudioOutputPropertiesEx_GetEnabled(This,pbEnabled) (This)->lpVtbl->GetEnabled(This,pbEnabled)
#define IAgentAudioOutputPropertiesEx_GetUsingSoundEffects(This,pbUsingSoundEffects) (This)->lpVtbl->GetUsingSoundEffects(This,pbUsingSoundEffects)
#define IAgentAudioOutputPropertiesEx_GetStatus(This,plStatus) (This)->lpVtbl->GetStatus(This,plStatus)
#endif
#endif
  HRESULT WINAPI IAgentAudioOutputPropertiesEx_GetStatus_Proxy(IAgentAudioOutputPropertiesEx *This,__LONG32 *plStatus);
  void __RPC_STUB IAgentAudioOutputPropertiesEx_GetStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentPropertySheet_INTERFACE_DEFINED__
#define __IAgentPropertySheet_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentPropertySheet;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentPropertySheet : public IDispatch {
  public:
    virtual HRESULT WINAPI GetVisible(__LONG32 *pbVisible) = 0;
    virtual HRESULT WINAPI SetVisible(__LONG32 bVisible) = 0;
    virtual HRESULT WINAPI GetPosition(__LONG32 *plLeft,__LONG32 *plTop) = 0;
    virtual HRESULT WINAPI GetSize(__LONG32 *plWidth,__LONG32 *plHeight) = 0;
    virtual HRESULT WINAPI GetPage(BSTR *pbszPage) = 0;
    virtual HRESULT WINAPI SetPage(BSTR bszPage) = 0;
  };
#else
  typedef struct IAgentPropertySheetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentPropertySheet *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentPropertySheet *This);
      ULONG (WINAPI *Release)(IAgentPropertySheet *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentPropertySheet *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentPropertySheet *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentPropertySheet *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentPropertySheet *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetVisible)(IAgentPropertySheet *This,__LONG32 *pbVisible);
      HRESULT (WINAPI *SetVisible)(IAgentPropertySheet *This,__LONG32 bVisible);
      HRESULT (WINAPI *GetPosition)(IAgentPropertySheet *This,__LONG32 *plLeft,__LONG32 *plTop);
      HRESULT (WINAPI *GetSize)(IAgentPropertySheet *This,__LONG32 *plWidth,__LONG32 *plHeight);
      HRESULT (WINAPI *GetPage)(IAgentPropertySheet *This,BSTR *pbszPage);
      HRESULT (WINAPI *SetPage)(IAgentPropertySheet *This,BSTR bszPage);
    END_INTERFACE
  } IAgentPropertySheetVtbl;
  struct IAgentPropertySheet {
    CONST_VTBL struct IAgentPropertySheetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentPropertySheet_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentPropertySheet_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentPropertySheet_Release(This) (This)->lpVtbl->Release(This)
#define IAgentPropertySheet_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentPropertySheet_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentPropertySheet_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentPropertySheet_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentPropertySheet_GetVisible(This,pbVisible) (This)->lpVtbl->GetVisible(This,pbVisible)
#define IAgentPropertySheet_SetVisible(This,bVisible) (This)->lpVtbl->SetVisible(This,bVisible)
#define IAgentPropertySheet_GetPosition(This,plLeft,plTop) (This)->lpVtbl->GetPosition(This,plLeft,plTop)
#define IAgentPropertySheet_GetSize(This,plWidth,plHeight) (This)->lpVtbl->GetSize(This,plWidth,plHeight)
#define IAgentPropertySheet_GetPage(This,pbszPage) (This)->lpVtbl->GetPage(This,pbszPage)
#define IAgentPropertySheet_SetPage(This,bszPage) (This)->lpVtbl->SetPage(This,bszPage)
#endif
#endif
  HRESULT WINAPI IAgentPropertySheet_GetVisible_Proxy(IAgentPropertySheet *This,__LONG32 *pbVisible);
  void __RPC_STUB IAgentPropertySheet_GetVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentPropertySheet_SetVisible_Proxy(IAgentPropertySheet *This,__LONG32 bVisible);
  void __RPC_STUB IAgentPropertySheet_SetVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentPropertySheet_GetPosition_Proxy(IAgentPropertySheet *This,__LONG32 *plLeft,__LONG32 *plTop);
  void __RPC_STUB IAgentPropertySheet_GetPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentPropertySheet_GetSize_Proxy(IAgentPropertySheet *This,__LONG32 *plWidth,__LONG32 *plHeight);
  void __RPC_STUB IAgentPropertySheet_GetSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentPropertySheet_GetPage_Proxy(IAgentPropertySheet *This,BSTR *pbszPage);
  void __RPC_STUB IAgentPropertySheet_GetPage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentPropertySheet_SetPage_Proxy(IAgentPropertySheet *This,BSTR bszPage);
  void __RPC_STUB IAgentPropertySheet_SetPage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentBalloon_INTERFACE_DEFINED__
#define __IAgentBalloon_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentBalloon;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentBalloon : public IDispatch {
  public:
    virtual HRESULT WINAPI GetEnabled(__LONG32 *pbEnabled) = 0;
    virtual HRESULT WINAPI GetNumLines(__LONG32 *plLines) = 0;
    virtual HRESULT WINAPI GetNumCharsPerLine(__LONG32 *plCharsPerLine) = 0;
    virtual HRESULT WINAPI GetFontName(BSTR *pbszFontName) = 0;
    virtual HRESULT WINAPI GetFontSize(__LONG32 *plFontSize) = 0;
    virtual HRESULT WINAPI GetFontBold(__LONG32 *pbFontBold) = 0;
    virtual HRESULT WINAPI GetFontItalic(__LONG32 *pbFontItalic) = 0;
    virtual HRESULT WINAPI GetFontStrikethru(__LONG32 *pbFontStrikethru) = 0;
    virtual HRESULT WINAPI GetFontUnderline(__LONG32 *pbFontUnderline) = 0;
    virtual HRESULT WINAPI GetForeColor(__LONG32 *plFGColor) = 0;
    virtual HRESULT WINAPI GetBackColor(__LONG32 *plBGColor) = 0;
    virtual HRESULT WINAPI GetBorderColor(__LONG32 *plBorderColor) = 0;
    virtual HRESULT WINAPI SetVisible(__LONG32 bVisible) = 0;
    virtual HRESULT WINAPI GetVisible(__LONG32 *pbVisible) = 0;
    virtual HRESULT WINAPI SetFontName(BSTR bszFontName) = 0;
    virtual HRESULT WINAPI SetFontSize(__LONG32 lFontSize) = 0;
    virtual HRESULT WINAPI SetFontCharSet(short sFontCharSet) = 0;
    virtual HRESULT WINAPI GetFontCharSet(short *psFontCharSet) = 0;
  };
#else
  typedef struct IAgentBalloonVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentBalloon *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentBalloon *This);
      ULONG (WINAPI *Release)(IAgentBalloon *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentBalloon *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentBalloon *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentBalloon *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentBalloon *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetEnabled)(IAgentBalloon *This,__LONG32 *pbEnabled);
      HRESULT (WINAPI *GetNumLines)(IAgentBalloon *This,__LONG32 *plLines);
      HRESULT (WINAPI *GetNumCharsPerLine)(IAgentBalloon *This,__LONG32 *plCharsPerLine);
      HRESULT (WINAPI *GetFontName)(IAgentBalloon *This,BSTR *pbszFontName);
      HRESULT (WINAPI *GetFontSize)(IAgentBalloon *This,__LONG32 *plFontSize);
      HRESULT (WINAPI *GetFontBold)(IAgentBalloon *This,__LONG32 *pbFontBold);
      HRESULT (WINAPI *GetFontItalic)(IAgentBalloon *This,__LONG32 *pbFontItalic);
      HRESULT (WINAPI *GetFontStrikethru)(IAgentBalloon *This,__LONG32 *pbFontStrikethru);
      HRESULT (WINAPI *GetFontUnderline)(IAgentBalloon *This,__LONG32 *pbFontUnderline);
      HRESULT (WINAPI *GetForeColor)(IAgentBalloon *This,__LONG32 *plFGColor);
      HRESULT (WINAPI *GetBackColor)(IAgentBalloon *This,__LONG32 *plBGColor);
      HRESULT (WINAPI *GetBorderColor)(IAgentBalloon *This,__LONG32 *plBorderColor);
      HRESULT (WINAPI *SetVisible)(IAgentBalloon *This,__LONG32 bVisible);
      HRESULT (WINAPI *GetVisible)(IAgentBalloon *This,__LONG32 *pbVisible);
      HRESULT (WINAPI *SetFontName)(IAgentBalloon *This,BSTR bszFontName);
      HRESULT (WINAPI *SetFontSize)(IAgentBalloon *This,__LONG32 lFontSize);
      HRESULT (WINAPI *SetFontCharSet)(IAgentBalloon *This,short sFontCharSet);
      HRESULT (WINAPI *GetFontCharSet)(IAgentBalloon *This,short *psFontCharSet);
    END_INTERFACE
  } IAgentBalloonVtbl;
  struct IAgentBalloon {
    CONST_VTBL struct IAgentBalloonVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentBalloon_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentBalloon_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentBalloon_Release(This) (This)->lpVtbl->Release(This)
#define IAgentBalloon_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentBalloon_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentBalloon_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentBalloon_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentBalloon_GetEnabled(This,pbEnabled) (This)->lpVtbl->GetEnabled(This,pbEnabled)
#define IAgentBalloon_GetNumLines(This,plLines) (This)->lpVtbl->GetNumLines(This,plLines)
#define IAgentBalloon_GetNumCharsPerLine(This,plCharsPerLine) (This)->lpVtbl->GetNumCharsPerLine(This,plCharsPerLine)
#define IAgentBalloon_GetFontName(This,pbszFontName) (This)->lpVtbl->GetFontName(This,pbszFontName)
#define IAgentBalloon_GetFontSize(This,plFontSize) (This)->lpVtbl->GetFontSize(This,plFontSize)
#define IAgentBalloon_GetFontBold(This,pbFontBold) (This)->lpVtbl->GetFontBold(This,pbFontBold)
#define IAgentBalloon_GetFontItalic(This,pbFontItalic) (This)->lpVtbl->GetFontItalic(This,pbFontItalic)
#define IAgentBalloon_GetFontStrikethru(This,pbFontStrikethru) (This)->lpVtbl->GetFontStrikethru(This,pbFontStrikethru)
#define IAgentBalloon_GetFontUnderline(This,pbFontUnderline) (This)->lpVtbl->GetFontUnderline(This,pbFontUnderline)
#define IAgentBalloon_GetForeColor(This,plFGColor) (This)->lpVtbl->GetForeColor(This,plFGColor)
#define IAgentBalloon_GetBackColor(This,plBGColor) (This)->lpVtbl->GetBackColor(This,plBGColor)
#define IAgentBalloon_GetBorderColor(This,plBorderColor) (This)->lpVtbl->GetBorderColor(This,plBorderColor)
#define IAgentBalloon_SetVisible(This,bVisible) (This)->lpVtbl->SetVisible(This,bVisible)
#define IAgentBalloon_GetVisible(This,pbVisible) (This)->lpVtbl->GetVisible(This,pbVisible)
#define IAgentBalloon_SetFontName(This,bszFontName) (This)->lpVtbl->SetFontName(This,bszFontName)
#define IAgentBalloon_SetFontSize(This,lFontSize) (This)->lpVtbl->SetFontSize(This,lFontSize)
#define IAgentBalloon_SetFontCharSet(This,sFontCharSet) (This)->lpVtbl->SetFontCharSet(This,sFontCharSet)
#define IAgentBalloon_GetFontCharSet(This,psFontCharSet) (This)->lpVtbl->GetFontCharSet(This,psFontCharSet)
#endif
#endif
  HRESULT WINAPI IAgentBalloon_GetEnabled_Proxy(IAgentBalloon *This,__LONG32 *pbEnabled);
  void __RPC_STUB IAgentBalloon_GetEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetNumLines_Proxy(IAgentBalloon *This,__LONG32 *plLines);
  void __RPC_STUB IAgentBalloon_GetNumLines_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetNumCharsPerLine_Proxy(IAgentBalloon *This,__LONG32 *plCharsPerLine);
  void __RPC_STUB IAgentBalloon_GetNumCharsPerLine_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetFontName_Proxy(IAgentBalloon *This,BSTR *pbszFontName);
  void __RPC_STUB IAgentBalloon_GetFontName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetFontSize_Proxy(IAgentBalloon *This,__LONG32 *plFontSize);
  void __RPC_STUB IAgentBalloon_GetFontSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetFontBold_Proxy(IAgentBalloon *This,__LONG32 *pbFontBold);
  void __RPC_STUB IAgentBalloon_GetFontBold_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetFontItalic_Proxy(IAgentBalloon *This,__LONG32 *pbFontItalic);
  void __RPC_STUB IAgentBalloon_GetFontItalic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetFontStrikethru_Proxy(IAgentBalloon *This,__LONG32 *pbFontStrikethru);
  void __RPC_STUB IAgentBalloon_GetFontStrikethru_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetFontUnderline_Proxy(IAgentBalloon *This,__LONG32 *pbFontUnderline);
  void __RPC_STUB IAgentBalloon_GetFontUnderline_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetForeColor_Proxy(IAgentBalloon *This,__LONG32 *plFGColor);
  void __RPC_STUB IAgentBalloon_GetForeColor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetBackColor_Proxy(IAgentBalloon *This,__LONG32 *plBGColor);
  void __RPC_STUB IAgentBalloon_GetBackColor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetBorderColor_Proxy(IAgentBalloon *This,__LONG32 *plBorderColor);
  void __RPC_STUB IAgentBalloon_GetBorderColor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_SetVisible_Proxy(IAgentBalloon *This,__LONG32 bVisible);
  void __RPC_STUB IAgentBalloon_SetVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetVisible_Proxy(IAgentBalloon *This,__LONG32 *pbVisible);
  void __RPC_STUB IAgentBalloon_GetVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_SetFontName_Proxy(IAgentBalloon *This,BSTR bszFontName);
  void __RPC_STUB IAgentBalloon_SetFontName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_SetFontSize_Proxy(IAgentBalloon *This,__LONG32 lFontSize);
  void __RPC_STUB IAgentBalloon_SetFontSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_SetFontCharSet_Proxy(IAgentBalloon *This,short sFontCharSet);
  void __RPC_STUB IAgentBalloon_SetFontCharSet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloon_GetFontCharSet_Proxy(IAgentBalloon *This,short *psFontCharSet);
  void __RPC_STUB IAgentBalloon_GetFontCharSet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentBalloonEx_INTERFACE_DEFINED__
#define __IAgentBalloonEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentBalloonEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentBalloonEx : public IAgentBalloon {
  public:
    virtual HRESULT WINAPI SetStyle(__LONG32 lStyle) = 0;
    virtual HRESULT WINAPI GetStyle(__LONG32 *plStyle) = 0;
    virtual HRESULT WINAPI SetNumLines(__LONG32 lLines) = 0;
    virtual HRESULT WINAPI SetNumCharsPerLine(__LONG32 lCharsPerLine) = 0;
  };
#else
  typedef struct IAgentBalloonExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentBalloonEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentBalloonEx *This);
      ULONG (WINAPI *Release)(IAgentBalloonEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentBalloonEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentBalloonEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentBalloonEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentBalloonEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetEnabled)(IAgentBalloonEx *This,__LONG32 *pbEnabled);
      HRESULT (WINAPI *GetNumLines)(IAgentBalloonEx *This,__LONG32 *plLines);
      HRESULT (WINAPI *GetNumCharsPerLine)(IAgentBalloonEx *This,__LONG32 *plCharsPerLine);
      HRESULT (WINAPI *GetFontName)(IAgentBalloonEx *This,BSTR *pbszFontName);
      HRESULT (WINAPI *GetFontSize)(IAgentBalloonEx *This,__LONG32 *plFontSize);
      HRESULT (WINAPI *GetFontBold)(IAgentBalloonEx *This,__LONG32 *pbFontBold);
      HRESULT (WINAPI *GetFontItalic)(IAgentBalloonEx *This,__LONG32 *pbFontItalic);
      HRESULT (WINAPI *GetFontStrikethru)(IAgentBalloonEx *This,__LONG32 *pbFontStrikethru);
      HRESULT (WINAPI *GetFontUnderline)(IAgentBalloonEx *This,__LONG32 *pbFontUnderline);
      HRESULT (WINAPI *GetForeColor)(IAgentBalloonEx *This,__LONG32 *plFGColor);
      HRESULT (WINAPI *GetBackColor)(IAgentBalloonEx *This,__LONG32 *plBGColor);
      HRESULT (WINAPI *GetBorderColor)(IAgentBalloonEx *This,__LONG32 *plBorderColor);
      HRESULT (WINAPI *SetVisible)(IAgentBalloonEx *This,__LONG32 bVisible);
      HRESULT (WINAPI *GetVisible)(IAgentBalloonEx *This,__LONG32 *pbVisible);
      HRESULT (WINAPI *SetFontName)(IAgentBalloonEx *This,BSTR bszFontName);
      HRESULT (WINAPI *SetFontSize)(IAgentBalloonEx *This,__LONG32 lFontSize);
      HRESULT (WINAPI *SetFontCharSet)(IAgentBalloonEx *This,short sFontCharSet);
      HRESULT (WINAPI *GetFontCharSet)(IAgentBalloonEx *This,short *psFontCharSet);
      HRESULT (WINAPI *SetStyle)(IAgentBalloonEx *This,__LONG32 lStyle);
      HRESULT (WINAPI *GetStyle)(IAgentBalloonEx *This,__LONG32 *plStyle);
      HRESULT (WINAPI *SetNumLines)(IAgentBalloonEx *This,__LONG32 lLines);
      HRESULT (WINAPI *SetNumCharsPerLine)(IAgentBalloonEx *This,__LONG32 lCharsPerLine);
    END_INTERFACE
  } IAgentBalloonExVtbl;
  struct IAgentBalloonEx {
    CONST_VTBL struct IAgentBalloonExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentBalloonEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentBalloonEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentBalloonEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentBalloonEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentBalloonEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentBalloonEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentBalloonEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentBalloonEx_GetEnabled(This,pbEnabled) (This)->lpVtbl->GetEnabled(This,pbEnabled)
#define IAgentBalloonEx_GetNumLines(This,plLines) (This)->lpVtbl->GetNumLines(This,plLines)
#define IAgentBalloonEx_GetNumCharsPerLine(This,plCharsPerLine) (This)->lpVtbl->GetNumCharsPerLine(This,plCharsPerLine)
#define IAgentBalloonEx_GetFontName(This,pbszFontName) (This)->lpVtbl->GetFontName(This,pbszFontName)
#define IAgentBalloonEx_GetFontSize(This,plFontSize) (This)->lpVtbl->GetFontSize(This,plFontSize)
#define IAgentBalloonEx_GetFontBold(This,pbFontBold) (This)->lpVtbl->GetFontBold(This,pbFontBold)
#define IAgentBalloonEx_GetFontItalic(This,pbFontItalic) (This)->lpVtbl->GetFontItalic(This,pbFontItalic)
#define IAgentBalloonEx_GetFontStrikethru(This,pbFontStrikethru) (This)->lpVtbl->GetFontStrikethru(This,pbFontStrikethru)
#define IAgentBalloonEx_GetFontUnderline(This,pbFontUnderline) (This)->lpVtbl->GetFontUnderline(This,pbFontUnderline)
#define IAgentBalloonEx_GetForeColor(This,plFGColor) (This)->lpVtbl->GetForeColor(This,plFGColor)
#define IAgentBalloonEx_GetBackColor(This,plBGColor) (This)->lpVtbl->GetBackColor(This,plBGColor)
#define IAgentBalloonEx_GetBorderColor(This,plBorderColor) (This)->lpVtbl->GetBorderColor(This,plBorderColor)
#define IAgentBalloonEx_SetVisible(This,bVisible) (This)->lpVtbl->SetVisible(This,bVisible)
#define IAgentBalloonEx_GetVisible(This,pbVisible) (This)->lpVtbl->GetVisible(This,pbVisible)
#define IAgentBalloonEx_SetFontName(This,bszFontName) (This)->lpVtbl->SetFontName(This,bszFontName)
#define IAgentBalloonEx_SetFontSize(This,lFontSize) (This)->lpVtbl->SetFontSize(This,lFontSize)
#define IAgentBalloonEx_SetFontCharSet(This,sFontCharSet) (This)->lpVtbl->SetFontCharSet(This,sFontCharSet)
#define IAgentBalloonEx_GetFontCharSet(This,psFontCharSet) (This)->lpVtbl->GetFontCharSet(This,psFontCharSet)
#define IAgentBalloonEx_SetStyle(This,lStyle) (This)->lpVtbl->SetStyle(This,lStyle)
#define IAgentBalloonEx_GetStyle(This,plStyle) (This)->lpVtbl->GetStyle(This,plStyle)
#define IAgentBalloonEx_SetNumLines(This,lLines) (This)->lpVtbl->SetNumLines(This,lLines)
#define IAgentBalloonEx_SetNumCharsPerLine(This,lCharsPerLine) (This)->lpVtbl->SetNumCharsPerLine(This,lCharsPerLine)
#endif
#endif
  HRESULT WINAPI IAgentBalloonEx_SetStyle_Proxy(IAgentBalloonEx *This,__LONG32 lStyle);
  void __RPC_STUB IAgentBalloonEx_SetStyle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloonEx_GetStyle_Proxy(IAgentBalloonEx *This,__LONG32 *plStyle);
  void __RPC_STUB IAgentBalloonEx_GetStyle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloonEx_SetNumLines_Proxy(IAgentBalloonEx *This,__LONG32 lLines);
  void __RPC_STUB IAgentBalloonEx_SetNumLines_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentBalloonEx_SetNumCharsPerLine_Proxy(IAgentBalloonEx *This,__LONG32 lCharsPerLine);
  void __RPC_STUB IAgentBalloonEx_SetNumCharsPerLine_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCharacter_INTERFACE_DEFINED__
#define __IAgentCharacter_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCharacter;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCharacter : public IDispatch {
  public:
    virtual HRESULT WINAPI GetVisible(__LONG32 *pbVisible) = 0;
    virtual HRESULT WINAPI SetPosition(__LONG32 lLeft,__LONG32 lTop) = 0;
    virtual HRESULT WINAPI GetPosition(__LONG32 *plLeft,__LONG32 *plTop) = 0;
    virtual HRESULT WINAPI SetSize(__LONG32 lWidth,__LONG32 lHeight) = 0;
    virtual HRESULT WINAPI GetSize(__LONG32 *plWidth,__LONG32 *plHeight) = 0;
    virtual HRESULT WINAPI GetName(BSTR *pbszName) = 0;
    virtual HRESULT WINAPI GetDescription(BSTR *pbszDescription) = 0;
    virtual HRESULT WINAPI GetTTSSpeed(__LONG32 *pdwSpeed) = 0;
    virtual HRESULT WINAPI GetTTSPitch(short *pwPitch) = 0;
    virtual HRESULT WINAPI Activate(short sState) = 0;
    virtual HRESULT WINAPI SetIdleOn(__LONG32 bOn) = 0;
    virtual HRESULT WINAPI GetIdleOn(__LONG32 *pbOn) = 0;
    virtual HRESULT WINAPI Prepare(__LONG32 dwType,BSTR bszName,__LONG32 bQueue,__LONG32 *pdwReqID) = 0;
    virtual HRESULT WINAPI Play(BSTR bszAnimation,__LONG32 *pdwReqID) = 0;
    virtual HRESULT WINAPI Stop(__LONG32 dwReqID) = 0;
    virtual HRESULT WINAPI StopAll(__LONG32 lTypes) = 0;
    virtual HRESULT WINAPI Wait(__LONG32 dwReqID,__LONG32 *pdwReqID) = 0;
    virtual HRESULT WINAPI Interrupt(__LONG32 dwReqID,__LONG32 *pdwReqID) = 0;
    virtual HRESULT WINAPI Show(__LONG32 bFast,__LONG32 *pdwReqID) = 0;
    virtual HRESULT WINAPI Hide(__LONG32 bFast,__LONG32 *pdwReqID) = 0;
    virtual HRESULT WINAPI Speak(BSTR bszText,BSTR bszUrl,__LONG32 *pdwReqID) = 0;
    virtual HRESULT WINAPI MoveTo(short x,short y,__LONG32 lSpeed,__LONG32 *pdwReqID) = 0;
    virtual HRESULT WINAPI GestureAt(short x,short y,__LONG32 *pdwReqID) = 0;
    virtual HRESULT WINAPI GetMoveCause(__LONG32 *pdwCause) = 0;
    virtual HRESULT WINAPI GetVisibilityCause(__LONG32 *pdwCause) = 0;
    virtual HRESULT WINAPI HasOtherClients(__LONG32 *plNumOtherClients) = 0;
    virtual HRESULT WINAPI SetSoundEffectsOn(__LONG32 bOn) = 0;
    virtual HRESULT WINAPI GetSoundEffectsOn(__LONG32 *pbOn) = 0;
    virtual HRESULT WINAPI SetName(BSTR bszName) = 0;
    virtual HRESULT WINAPI SetDescription(BSTR bszDescription) = 0;
    virtual HRESULT WINAPI GetExtraData(BSTR *pbszExtraData) = 0;
  };
#else
  typedef struct IAgentCharacterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCharacter *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCharacter *This);
      ULONG (WINAPI *Release)(IAgentCharacter *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCharacter *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCharacter *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCharacter *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCharacter *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetVisible)(IAgentCharacter *This,__LONG32 *pbVisible);
      HRESULT (WINAPI *SetPosition)(IAgentCharacter *This,__LONG32 lLeft,__LONG32 lTop);
      HRESULT (WINAPI *GetPosition)(IAgentCharacter *This,__LONG32 *plLeft,__LONG32 *plTop);
      HRESULT (WINAPI *SetSize)(IAgentCharacter *This,__LONG32 lWidth,__LONG32 lHeight);
      HRESULT (WINAPI *GetSize)(IAgentCharacter *This,__LONG32 *plWidth,__LONG32 *plHeight);
      HRESULT (WINAPI *GetName)(IAgentCharacter *This,BSTR *pbszName);
      HRESULT (WINAPI *GetDescription)(IAgentCharacter *This,BSTR *pbszDescription);
      HRESULT (WINAPI *GetTTSSpeed)(IAgentCharacter *This,__LONG32 *pdwSpeed);
      HRESULT (WINAPI *GetTTSPitch)(IAgentCharacter *This,short *pwPitch);
      HRESULT (WINAPI *Activate)(IAgentCharacter *This,short sState);
      HRESULT (WINAPI *SetIdleOn)(IAgentCharacter *This,__LONG32 bOn);
      HRESULT (WINAPI *GetIdleOn)(IAgentCharacter *This,__LONG32 *pbOn);
      HRESULT (WINAPI *Prepare)(IAgentCharacter *This,__LONG32 dwType,BSTR bszName,__LONG32 bQueue,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Play)(IAgentCharacter *This,BSTR bszAnimation,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Stop)(IAgentCharacter *This,__LONG32 dwReqID);
      HRESULT (WINAPI *StopAll)(IAgentCharacter *This,__LONG32 lTypes);
      HRESULT (WINAPI *Wait)(IAgentCharacter *This,__LONG32 dwReqID,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Interrupt)(IAgentCharacter *This,__LONG32 dwReqID,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Show)(IAgentCharacter *This,__LONG32 bFast,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Hide)(IAgentCharacter *This,__LONG32 bFast,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Speak)(IAgentCharacter *This,BSTR bszText,BSTR bszUrl,__LONG32 *pdwReqID);
      HRESULT (WINAPI *MoveTo)(IAgentCharacter *This,short x,short y,__LONG32 lSpeed,__LONG32 *pdwReqID);
      HRESULT (WINAPI *GestureAt)(IAgentCharacter *This,short x,short y,__LONG32 *pdwReqID);
      HRESULT (WINAPI *GetMoveCause)(IAgentCharacter *This,__LONG32 *pdwCause);
      HRESULT (WINAPI *GetVisibilityCause)(IAgentCharacter *This,__LONG32 *pdwCause);
      HRESULT (WINAPI *HasOtherClients)(IAgentCharacter *This,__LONG32 *plNumOtherClients);
      HRESULT (WINAPI *SetSoundEffectsOn)(IAgentCharacter *This,__LONG32 bOn);
      HRESULT (WINAPI *GetSoundEffectsOn)(IAgentCharacter *This,__LONG32 *pbOn);
      HRESULT (WINAPI *SetName)(IAgentCharacter *This,BSTR bszName);
      HRESULT (WINAPI *SetDescription)(IAgentCharacter *This,BSTR bszDescription);
      HRESULT (WINAPI *GetExtraData)(IAgentCharacter *This,BSTR *pbszExtraData);
    END_INTERFACE
  } IAgentCharacterVtbl;
  struct IAgentCharacter {
    CONST_VTBL struct IAgentCharacterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCharacter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCharacter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCharacter_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCharacter_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCharacter_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCharacter_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCharacter_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCharacter_GetVisible(This,pbVisible) (This)->lpVtbl->GetVisible(This,pbVisible)
#define IAgentCharacter_SetPosition(This,lLeft,lTop) (This)->lpVtbl->SetPosition(This,lLeft,lTop)
#define IAgentCharacter_GetPosition(This,plLeft,plTop) (This)->lpVtbl->GetPosition(This,plLeft,plTop)
#define IAgentCharacter_SetSize(This,lWidth,lHeight) (This)->lpVtbl->SetSize(This,lWidth,lHeight)
#define IAgentCharacter_GetSize(This,plWidth,plHeight) (This)->lpVtbl->GetSize(This,plWidth,plHeight)
#define IAgentCharacter_GetName(This,pbszName) (This)->lpVtbl->GetName(This,pbszName)
#define IAgentCharacter_GetDescription(This,pbszDescription) (This)->lpVtbl->GetDescription(This,pbszDescription)
#define IAgentCharacter_GetTTSSpeed(This,pdwSpeed) (This)->lpVtbl->GetTTSSpeed(This,pdwSpeed)
#define IAgentCharacter_GetTTSPitch(This,pwPitch) (This)->lpVtbl->GetTTSPitch(This,pwPitch)
#define IAgentCharacter_Activate(This,sState) (This)->lpVtbl->Activate(This,sState)
#define IAgentCharacter_SetIdleOn(This,bOn) (This)->lpVtbl->SetIdleOn(This,bOn)
#define IAgentCharacter_GetIdleOn(This,pbOn) (This)->lpVtbl->GetIdleOn(This,pbOn)
#define IAgentCharacter_Prepare(This,dwType,bszName,bQueue,pdwReqID) (This)->lpVtbl->Prepare(This,dwType,bszName,bQueue,pdwReqID)
#define IAgentCharacter_Play(This,bszAnimation,pdwReqID) (This)->lpVtbl->Play(This,bszAnimation,pdwReqID)
#define IAgentCharacter_Stop(This,dwReqID) (This)->lpVtbl->Stop(This,dwReqID)
#define IAgentCharacter_StopAll(This,lTypes) (This)->lpVtbl->StopAll(This,lTypes)
#define IAgentCharacter_Wait(This,dwReqID,pdwReqID) (This)->lpVtbl->Wait(This,dwReqID,pdwReqID)
#define IAgentCharacter_Interrupt(This,dwReqID,pdwReqID) (This)->lpVtbl->Interrupt(This,dwReqID,pdwReqID)
#define IAgentCharacter_Show(This,bFast,pdwReqID) (This)->lpVtbl->Show(This,bFast,pdwReqID)
#define IAgentCharacter_Hide(This,bFast,pdwReqID) (This)->lpVtbl->Hide(This,bFast,pdwReqID)
#define IAgentCharacter_Speak(This,bszText,bszUrl,pdwReqID) (This)->lpVtbl->Speak(This,bszText,bszUrl,pdwReqID)
#define IAgentCharacter_MoveTo(This,x,y,lSpeed,pdwReqID) (This)->lpVtbl->MoveTo(This,x,y,lSpeed,pdwReqID)
#define IAgentCharacter_GestureAt(This,x,y,pdwReqID) (This)->lpVtbl->GestureAt(This,x,y,pdwReqID)
#define IAgentCharacter_GetMoveCause(This,pdwCause) (This)->lpVtbl->GetMoveCause(This,pdwCause)
#define IAgentCharacter_GetVisibilityCause(This,pdwCause) (This)->lpVtbl->GetVisibilityCause(This,pdwCause)
#define IAgentCharacter_HasOtherClients(This,plNumOtherClients) (This)->lpVtbl->HasOtherClients(This,plNumOtherClients)
#define IAgentCharacter_SetSoundEffectsOn(This,bOn) (This)->lpVtbl->SetSoundEffectsOn(This,bOn)
#define IAgentCharacter_GetSoundEffectsOn(This,pbOn) (This)->lpVtbl->GetSoundEffectsOn(This,pbOn)
#define IAgentCharacter_SetName(This,bszName) (This)->lpVtbl->SetName(This,bszName)
#define IAgentCharacter_SetDescription(This,bszDescription) (This)->lpVtbl->SetDescription(This,bszDescription)
#define IAgentCharacter_GetExtraData(This,pbszExtraData) (This)->lpVtbl->GetExtraData(This,pbszExtraData)
#endif
#endif
  HRESULT WINAPI IAgentCharacter_GetVisible_Proxy(IAgentCharacter *This,__LONG32 *pbVisible);
  void __RPC_STUB IAgentCharacter_GetVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_SetPosition_Proxy(IAgentCharacter *This,__LONG32 lLeft,__LONG32 lTop);
  void __RPC_STUB IAgentCharacter_SetPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GetPosition_Proxy(IAgentCharacter *This,__LONG32 *plLeft,__LONG32 *plTop);
  void __RPC_STUB IAgentCharacter_GetPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_SetSize_Proxy(IAgentCharacter *This,__LONG32 lWidth,__LONG32 lHeight);
  void __RPC_STUB IAgentCharacter_SetSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GetSize_Proxy(IAgentCharacter *This,__LONG32 *plWidth,__LONG32 *plHeight);
  void __RPC_STUB IAgentCharacter_GetSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GetName_Proxy(IAgentCharacter *This,BSTR *pbszName);
  void __RPC_STUB IAgentCharacter_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GetDescription_Proxy(IAgentCharacter *This,BSTR *pbszDescription);
  void __RPC_STUB IAgentCharacter_GetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GetTTSSpeed_Proxy(IAgentCharacter *This,__LONG32 *pdwSpeed);
  void __RPC_STUB IAgentCharacter_GetTTSSpeed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GetTTSPitch_Proxy(IAgentCharacter *This,short *pwPitch);
  void __RPC_STUB IAgentCharacter_GetTTSPitch_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_Activate_Proxy(IAgentCharacter *This,short sState);
  void __RPC_STUB IAgentCharacter_Activate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_SetIdleOn_Proxy(IAgentCharacter *This,__LONG32 bOn);
  void __RPC_STUB IAgentCharacter_SetIdleOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GetIdleOn_Proxy(IAgentCharacter *This,__LONG32 *pbOn);
  void __RPC_STUB IAgentCharacter_GetIdleOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_Prepare_Proxy(IAgentCharacter *This,__LONG32 dwType,BSTR bszName,__LONG32 bQueue,__LONG32 *pdwReqID);
  void __RPC_STUB IAgentCharacter_Prepare_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_Play_Proxy(IAgentCharacter *This,BSTR bszAnimation,__LONG32 *pdwReqID);
  void __RPC_STUB IAgentCharacter_Play_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_Stop_Proxy(IAgentCharacter *This,__LONG32 dwReqID);
  void __RPC_STUB IAgentCharacter_Stop_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_StopAll_Proxy(IAgentCharacter *This,__LONG32 lTypes);
  void __RPC_STUB IAgentCharacter_StopAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_Wait_Proxy(IAgentCharacter *This,__LONG32 dwReqID,__LONG32 *pdwReqID);
  void __RPC_STUB IAgentCharacter_Wait_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_Interrupt_Proxy(IAgentCharacter *This,__LONG32 dwReqID,__LONG32 *pdwReqID);
  void __RPC_STUB IAgentCharacter_Interrupt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_Show_Proxy(IAgentCharacter *This,__LONG32 bFast,__LONG32 *pdwReqID);
  void __RPC_STUB IAgentCharacter_Show_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_Hide_Proxy(IAgentCharacter *This,__LONG32 bFast,__LONG32 *pdwReqID);
  void __RPC_STUB IAgentCharacter_Hide_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_Speak_Proxy(IAgentCharacter *This,BSTR bszText,BSTR bszUrl,__LONG32 *pdwReqID);
  void __RPC_STUB IAgentCharacter_Speak_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_MoveTo_Proxy(IAgentCharacter *This,short x,short y,__LONG32 lSpeed,__LONG32 *pdwReqID);
  void __RPC_STUB IAgentCharacter_MoveTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GestureAt_Proxy(IAgentCharacter *This,short x,short y,__LONG32 *pdwReqID);
  void __RPC_STUB IAgentCharacter_GestureAt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GetMoveCause_Proxy(IAgentCharacter *This,__LONG32 *pdwCause);
  void __RPC_STUB IAgentCharacter_GetMoveCause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GetVisibilityCause_Proxy(IAgentCharacter *This,__LONG32 *pdwCause);
  void __RPC_STUB IAgentCharacter_GetVisibilityCause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_HasOtherClients_Proxy(IAgentCharacter *This,__LONG32 *plNumOtherClients);
  void __RPC_STUB IAgentCharacter_HasOtherClients_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_SetSoundEffectsOn_Proxy(IAgentCharacter *This,__LONG32 bOn);
  void __RPC_STUB IAgentCharacter_SetSoundEffectsOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GetSoundEffectsOn_Proxy(IAgentCharacter *This,__LONG32 *pbOn);
  void __RPC_STUB IAgentCharacter_GetSoundEffectsOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_SetName_Proxy(IAgentCharacter *This,BSTR bszName);
  void __RPC_STUB IAgentCharacter_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_SetDescription_Proxy(IAgentCharacter *This,BSTR bszDescription);
  void __RPC_STUB IAgentCharacter_SetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacter_GetExtraData_Proxy(IAgentCharacter *This,BSTR *pbszExtraData);
  void __RPC_STUB IAgentCharacter_GetExtraData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCharacterEx_INTERFACE_DEFINED__
#define __IAgentCharacterEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCharacterEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCharacterEx : public IAgentCharacter {
  public:
    virtual HRESULT WINAPI ShowPopupMenu(short x,short y) = 0;
    virtual HRESULT WINAPI SetAutoPopupMenu(__LONG32 bAutoPopupMenu) = 0;
    virtual HRESULT WINAPI GetAutoPopupMenu(__LONG32 *pbAutoPopupMenu) = 0;
    virtual HRESULT WINAPI GetHelpFileName(BSTR *pbszName) = 0;
    virtual HRESULT WINAPI SetHelpFileName(BSTR bszName) = 0;
    virtual HRESULT WINAPI SetHelpModeOn(__LONG32 bHelpModeOn) = 0;
    virtual HRESULT WINAPI GetHelpModeOn(__LONG32 *pbHelpModeOn) = 0;
    virtual HRESULT WINAPI SetHelpContextID(__LONG32 ulID) = 0;
    virtual HRESULT WINAPI GetHelpContextID(__LONG32 *pulID) = 0;
    virtual HRESULT WINAPI GetActive(short *psState) = 0;
    virtual HRESULT WINAPI Listen(__LONG32 bListen) = 0;
    virtual HRESULT WINAPI SetLanguageID(__LONG32 langid) = 0;
    virtual HRESULT WINAPI GetLanguageID(__LONG32 *plangid) = 0;
    virtual HRESULT WINAPI GetTTSModeID(BSTR *pbszModeID) = 0;
    virtual HRESULT WINAPI SetTTSModeID(BSTR bszModeID) = 0;
    virtual HRESULT WINAPI GetSRModeID(BSTR *pbszModeID) = 0;
    virtual HRESULT WINAPI SetSRModeID(BSTR bszModeID) = 0;
    virtual HRESULT WINAPI GetGUID(BSTR *pbszID) = 0;
    virtual HRESULT WINAPI GetOriginalSize(__LONG32 *plWidth,__LONG32 *plHeight) = 0;
    virtual HRESULT WINAPI Think(BSTR bszText,__LONG32 *pdwReqID) = 0;
    virtual HRESULT WINAPI GetVersion(short *psMajor,short *psMinor) = 0;
    virtual HRESULT WINAPI GetAnimationNames(IUnknown **punkEnum) = 0;
    virtual HRESULT WINAPI GetSRStatus(__LONG32 *plStatus) = 0;
  };
#else
  typedef struct IAgentCharacterExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCharacterEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCharacterEx *This);
      ULONG (WINAPI *Release)(IAgentCharacterEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCharacterEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCharacterEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCharacterEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCharacterEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetVisible)(IAgentCharacterEx *This,__LONG32 *pbVisible);
      HRESULT (WINAPI *SetPosition)(IAgentCharacterEx *This,__LONG32 lLeft,__LONG32 lTop);
      HRESULT (WINAPI *GetPosition)(IAgentCharacterEx *This,__LONG32 *plLeft,__LONG32 *plTop);
      HRESULT (WINAPI *SetSize)(IAgentCharacterEx *This,__LONG32 lWidth,__LONG32 lHeight);
      HRESULT (WINAPI *GetSize)(IAgentCharacterEx *This,__LONG32 *plWidth,__LONG32 *plHeight);
      HRESULT (WINAPI *GetName)(IAgentCharacterEx *This,BSTR *pbszName);
      HRESULT (WINAPI *GetDescription)(IAgentCharacterEx *This,BSTR *pbszDescription);
      HRESULT (WINAPI *GetTTSSpeed)(IAgentCharacterEx *This,__LONG32 *pdwSpeed);
      HRESULT (WINAPI *GetTTSPitch)(IAgentCharacterEx *This,short *pwPitch);
      HRESULT (WINAPI *Activate)(IAgentCharacterEx *This,short sState);
      HRESULT (WINAPI *SetIdleOn)(IAgentCharacterEx *This,__LONG32 bOn);
      HRESULT (WINAPI *GetIdleOn)(IAgentCharacterEx *This,__LONG32 *pbOn);
      HRESULT (WINAPI *Prepare)(IAgentCharacterEx *This,__LONG32 dwType,BSTR bszName,__LONG32 bQueue,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Play)(IAgentCharacterEx *This,BSTR bszAnimation,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Stop)(IAgentCharacterEx *This,__LONG32 dwReqID);
      HRESULT (WINAPI *StopAll)(IAgentCharacterEx *This,__LONG32 lTypes);
      HRESULT (WINAPI *Wait)(IAgentCharacterEx *This,__LONG32 dwReqID,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Interrupt)(IAgentCharacterEx *This,__LONG32 dwReqID,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Show)(IAgentCharacterEx *This,__LONG32 bFast,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Hide)(IAgentCharacterEx *This,__LONG32 bFast,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Speak)(IAgentCharacterEx *This,BSTR bszText,BSTR bszUrl,__LONG32 *pdwReqID);
      HRESULT (WINAPI *MoveTo)(IAgentCharacterEx *This,short x,short y,__LONG32 lSpeed,__LONG32 *pdwReqID);
      HRESULT (WINAPI *GestureAt)(IAgentCharacterEx *This,short x,short y,__LONG32 *pdwReqID);
      HRESULT (WINAPI *GetMoveCause)(IAgentCharacterEx *This,__LONG32 *pdwCause);
      HRESULT (WINAPI *GetVisibilityCause)(IAgentCharacterEx *This,__LONG32 *pdwCause);
      HRESULT (WINAPI *HasOtherClients)(IAgentCharacterEx *This,__LONG32 *plNumOtherClients);
      HRESULT (WINAPI *SetSoundEffectsOn)(IAgentCharacterEx *This,__LONG32 bOn);
      HRESULT (WINAPI *GetSoundEffectsOn)(IAgentCharacterEx *This,__LONG32 *pbOn);
      HRESULT (WINAPI *SetName)(IAgentCharacterEx *This,BSTR bszName);
      HRESULT (WINAPI *SetDescription)(IAgentCharacterEx *This,BSTR bszDescription);
      HRESULT (WINAPI *GetExtraData)(IAgentCharacterEx *This,BSTR *pbszExtraData);
      HRESULT (WINAPI *ShowPopupMenu)(IAgentCharacterEx *This,short x,short y);
      HRESULT (WINAPI *SetAutoPopupMenu)(IAgentCharacterEx *This,__LONG32 bAutoPopupMenu);
      HRESULT (WINAPI *GetAutoPopupMenu)(IAgentCharacterEx *This,__LONG32 *pbAutoPopupMenu);
      HRESULT (WINAPI *GetHelpFileName)(IAgentCharacterEx *This,BSTR *pbszName);
      HRESULT (WINAPI *SetHelpFileName)(IAgentCharacterEx *This,BSTR bszName);
      HRESULT (WINAPI *SetHelpModeOn)(IAgentCharacterEx *This,__LONG32 bHelpModeOn);
      HRESULT (WINAPI *GetHelpModeOn)(IAgentCharacterEx *This,__LONG32 *pbHelpModeOn);
      HRESULT (WINAPI *SetHelpContextID)(IAgentCharacterEx *This,__LONG32 ulID);
      HRESULT (WINAPI *GetHelpContextID)(IAgentCharacterEx *This,__LONG32 *pulID);
      HRESULT (WINAPI *GetActive)(IAgentCharacterEx *This,short *psState);
      HRESULT (WINAPI *Listen)(IAgentCharacterEx *This,__LONG32 bListen);
      HRESULT (WINAPI *SetLanguageID)(IAgentCharacterEx *This,__LONG32 langid);
      HRESULT (WINAPI *GetLanguageID)(IAgentCharacterEx *This,__LONG32 *plangid);
      HRESULT (WINAPI *GetTTSModeID)(IAgentCharacterEx *This,BSTR *pbszModeID);
      HRESULT (WINAPI *SetTTSModeID)(IAgentCharacterEx *This,BSTR bszModeID);
      HRESULT (WINAPI *GetSRModeID)(IAgentCharacterEx *This,BSTR *pbszModeID);
      HRESULT (WINAPI *SetSRModeID)(IAgentCharacterEx *This,BSTR bszModeID);
      HRESULT (WINAPI *GetGUID)(IAgentCharacterEx *This,BSTR *pbszID);
      HRESULT (WINAPI *GetOriginalSize)(IAgentCharacterEx *This,__LONG32 *plWidth,__LONG32 *plHeight);
      HRESULT (WINAPI *Think)(IAgentCharacterEx *This,BSTR bszText,__LONG32 *pdwReqID);
      HRESULT (WINAPI *GetVersion)(IAgentCharacterEx *This,short *psMajor,short *psMinor);
      HRESULT (WINAPI *GetAnimationNames)(IAgentCharacterEx *This,IUnknown **punkEnum);
      HRESULT (WINAPI *GetSRStatus)(IAgentCharacterEx *This,__LONG32 *plStatus);
    END_INTERFACE
  } IAgentCharacterExVtbl;
  struct IAgentCharacterEx {
    CONST_VTBL struct IAgentCharacterExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCharacterEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCharacterEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCharacterEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCharacterEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCharacterEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCharacterEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCharacterEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCharacterEx_GetVisible(This,pbVisible) (This)->lpVtbl->GetVisible(This,pbVisible)
#define IAgentCharacterEx_SetPosition(This,lLeft,lTop) (This)->lpVtbl->SetPosition(This,lLeft,lTop)
#define IAgentCharacterEx_GetPosition(This,plLeft,plTop) (This)->lpVtbl->GetPosition(This,plLeft,plTop)
#define IAgentCharacterEx_SetSize(This,lWidth,lHeight) (This)->lpVtbl->SetSize(This,lWidth,lHeight)
#define IAgentCharacterEx_GetSize(This,plWidth,plHeight) (This)->lpVtbl->GetSize(This,plWidth,plHeight)
#define IAgentCharacterEx_GetName(This,pbszName) (This)->lpVtbl->GetName(This,pbszName)
#define IAgentCharacterEx_GetDescription(This,pbszDescription) (This)->lpVtbl->GetDescription(This,pbszDescription)
#define IAgentCharacterEx_GetTTSSpeed(This,pdwSpeed) (This)->lpVtbl->GetTTSSpeed(This,pdwSpeed)
#define IAgentCharacterEx_GetTTSPitch(This,pwPitch) (This)->lpVtbl->GetTTSPitch(This,pwPitch)
#define IAgentCharacterEx_Activate(This,sState) (This)->lpVtbl->Activate(This,sState)
#define IAgentCharacterEx_SetIdleOn(This,bOn) (This)->lpVtbl->SetIdleOn(This,bOn)
#define IAgentCharacterEx_GetIdleOn(This,pbOn) (This)->lpVtbl->GetIdleOn(This,pbOn)
#define IAgentCharacterEx_Prepare(This,dwType,bszName,bQueue,pdwReqID) (This)->lpVtbl->Prepare(This,dwType,bszName,bQueue,pdwReqID)
#define IAgentCharacterEx_Play(This,bszAnimation,pdwReqID) (This)->lpVtbl->Play(This,bszAnimation,pdwReqID)
#define IAgentCharacterEx_Stop(This,dwReqID) (This)->lpVtbl->Stop(This,dwReqID)
#define IAgentCharacterEx_StopAll(This,lTypes) (This)->lpVtbl->StopAll(This,lTypes)
#define IAgentCharacterEx_Wait(This,dwReqID,pdwReqID) (This)->lpVtbl->Wait(This,dwReqID,pdwReqID)
#define IAgentCharacterEx_Interrupt(This,dwReqID,pdwReqID) (This)->lpVtbl->Interrupt(This,dwReqID,pdwReqID)
#define IAgentCharacterEx_Show(This,bFast,pdwReqID) (This)->lpVtbl->Show(This,bFast,pdwReqID)
#define IAgentCharacterEx_Hide(This,bFast,pdwReqID) (This)->lpVtbl->Hide(This,bFast,pdwReqID)
#define IAgentCharacterEx_Speak(This,bszText,bszUrl,pdwReqID) (This)->lpVtbl->Speak(This,bszText,bszUrl,pdwReqID)
#define IAgentCharacterEx_MoveTo(This,x,y,lSpeed,pdwReqID) (This)->lpVtbl->MoveTo(This,x,y,lSpeed,pdwReqID)
#define IAgentCharacterEx_GestureAt(This,x,y,pdwReqID) (This)->lpVtbl->GestureAt(This,x,y,pdwReqID)
#define IAgentCharacterEx_GetMoveCause(This,pdwCause) (This)->lpVtbl->GetMoveCause(This,pdwCause)
#define IAgentCharacterEx_GetVisibilityCause(This,pdwCause) (This)->lpVtbl->GetVisibilityCause(This,pdwCause)
#define IAgentCharacterEx_HasOtherClients(This,plNumOtherClients) (This)->lpVtbl->HasOtherClients(This,plNumOtherClients)
#define IAgentCharacterEx_SetSoundEffectsOn(This,bOn) (This)->lpVtbl->SetSoundEffectsOn(This,bOn)
#define IAgentCharacterEx_GetSoundEffectsOn(This,pbOn) (This)->lpVtbl->GetSoundEffectsOn(This,pbOn)
#define IAgentCharacterEx_SetName(This,bszName) (This)->lpVtbl->SetName(This,bszName)
#define IAgentCharacterEx_SetDescription(This,bszDescription) (This)->lpVtbl->SetDescription(This,bszDescription)
#define IAgentCharacterEx_GetExtraData(This,pbszExtraData) (This)->lpVtbl->GetExtraData(This,pbszExtraData)
#define IAgentCharacterEx_ShowPopupMenu(This,x,y) (This)->lpVtbl->ShowPopupMenu(This,x,y)
#define IAgentCharacterEx_SetAutoPopupMenu(This,bAutoPopupMenu) (This)->lpVtbl->SetAutoPopupMenu(This,bAutoPopupMenu)
#define IAgentCharacterEx_GetAutoPopupMenu(This,pbAutoPopupMenu) (This)->lpVtbl->GetAutoPopupMenu(This,pbAutoPopupMenu)
#define IAgentCharacterEx_GetHelpFileName(This,pbszName) (This)->lpVtbl->GetHelpFileName(This,pbszName)
#define IAgentCharacterEx_SetHelpFileName(This,bszName) (This)->lpVtbl->SetHelpFileName(This,bszName)
#define IAgentCharacterEx_SetHelpModeOn(This,bHelpModeOn) (This)->lpVtbl->SetHelpModeOn(This,bHelpModeOn)
#define IAgentCharacterEx_GetHelpModeOn(This,pbHelpModeOn) (This)->lpVtbl->GetHelpModeOn(This,pbHelpModeOn)
#define IAgentCharacterEx_SetHelpContextID(This,ulID) (This)->lpVtbl->SetHelpContextID(This,ulID)
#define IAgentCharacterEx_GetHelpContextID(This,pulID) (This)->lpVtbl->GetHelpContextID(This,pulID)
#define IAgentCharacterEx_GetActive(This,psState) (This)->lpVtbl->GetActive(This,psState)
#define IAgentCharacterEx_Listen(This,bListen) (This)->lpVtbl->Listen(This,bListen)
#define IAgentCharacterEx_SetLanguageID(This,langid) (This)->lpVtbl->SetLanguageID(This,langid)
#define IAgentCharacterEx_GetLanguageID(This,plangid) (This)->lpVtbl->GetLanguageID(This,plangid)
#define IAgentCharacterEx_GetTTSModeID(This,pbszModeID) (This)->lpVtbl->GetTTSModeID(This,pbszModeID)
#define IAgentCharacterEx_SetTTSModeID(This,bszModeID) (This)->lpVtbl->SetTTSModeID(This,bszModeID)
#define IAgentCharacterEx_GetSRModeID(This,pbszModeID) (This)->lpVtbl->GetSRModeID(This,pbszModeID)
#define IAgentCharacterEx_SetSRModeID(This,bszModeID) (This)->lpVtbl->SetSRModeID(This,bszModeID)
#define IAgentCharacterEx_GetGUID(This,pbszID) (This)->lpVtbl->GetGUID(This,pbszID)
#define IAgentCharacterEx_GetOriginalSize(This,plWidth,plHeight) (This)->lpVtbl->GetOriginalSize(This,plWidth,plHeight)
#define IAgentCharacterEx_Think(This,bszText,pdwReqID) (This)->lpVtbl->Think(This,bszText,pdwReqID)
#define IAgentCharacterEx_GetVersion(This,psMajor,psMinor) (This)->lpVtbl->GetVersion(This,psMajor,psMinor)
#define IAgentCharacterEx_GetAnimationNames(This,punkEnum) (This)->lpVtbl->GetAnimationNames(This,punkEnum)
#define IAgentCharacterEx_GetSRStatus(This,plStatus) (This)->lpVtbl->GetSRStatus(This,plStatus)
#endif
#endif
  HRESULT WINAPI IAgentCharacterEx_ShowPopupMenu_Proxy(IAgentCharacterEx *This,short x,short y);
  void __RPC_STUB IAgentCharacterEx_ShowPopupMenu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_SetAutoPopupMenu_Proxy(IAgentCharacterEx *This,__LONG32 bAutoPopupMenu);
  void __RPC_STUB IAgentCharacterEx_SetAutoPopupMenu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetAutoPopupMenu_Proxy(IAgentCharacterEx *This,__LONG32 *pbAutoPopupMenu);
  void __RPC_STUB IAgentCharacterEx_GetAutoPopupMenu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetHelpFileName_Proxy(IAgentCharacterEx *This,BSTR *pbszName);
  void __RPC_STUB IAgentCharacterEx_GetHelpFileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_SetHelpFileName_Proxy(IAgentCharacterEx *This,BSTR bszName);
  void __RPC_STUB IAgentCharacterEx_SetHelpFileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_SetHelpModeOn_Proxy(IAgentCharacterEx *This,__LONG32 bHelpModeOn);
  void __RPC_STUB IAgentCharacterEx_SetHelpModeOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetHelpModeOn_Proxy(IAgentCharacterEx *This,__LONG32 *pbHelpModeOn);
  void __RPC_STUB IAgentCharacterEx_GetHelpModeOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_SetHelpContextID_Proxy(IAgentCharacterEx *This,__LONG32 ulID);
  void __RPC_STUB IAgentCharacterEx_SetHelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetHelpContextID_Proxy(IAgentCharacterEx *This,__LONG32 *pulID);
  void __RPC_STUB IAgentCharacterEx_GetHelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetActive_Proxy(IAgentCharacterEx *This,short *psState);
  void __RPC_STUB IAgentCharacterEx_GetActive_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_Listen_Proxy(IAgentCharacterEx *This,__LONG32 bListen);
  void __RPC_STUB IAgentCharacterEx_Listen_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_SetLanguageID_Proxy(IAgentCharacterEx *This,__LONG32 langid);
  void __RPC_STUB IAgentCharacterEx_SetLanguageID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetLanguageID_Proxy(IAgentCharacterEx *This,__LONG32 *plangid);
  void __RPC_STUB IAgentCharacterEx_GetLanguageID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetTTSModeID_Proxy(IAgentCharacterEx *This,BSTR *pbszModeID);
  void __RPC_STUB IAgentCharacterEx_GetTTSModeID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_SetTTSModeID_Proxy(IAgentCharacterEx *This,BSTR bszModeID);
  void __RPC_STUB IAgentCharacterEx_SetTTSModeID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetSRModeID_Proxy(IAgentCharacterEx *This,BSTR *pbszModeID);
  void __RPC_STUB IAgentCharacterEx_GetSRModeID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_SetSRModeID_Proxy(IAgentCharacterEx *This,BSTR bszModeID);
  void __RPC_STUB IAgentCharacterEx_SetSRModeID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetGUID_Proxy(IAgentCharacterEx *This,BSTR *pbszID);
  void __RPC_STUB IAgentCharacterEx_GetGUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetOriginalSize_Proxy(IAgentCharacterEx *This,__LONG32 *plWidth,__LONG32 *plHeight);
  void __RPC_STUB IAgentCharacterEx_GetOriginalSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_Think_Proxy(IAgentCharacterEx *This,BSTR bszText,__LONG32 *pdwReqID);
  void __RPC_STUB IAgentCharacterEx_Think_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetVersion_Proxy(IAgentCharacterEx *This,short *psMajor,short *psMinor);
  void __RPC_STUB IAgentCharacterEx_GetVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetAnimationNames_Proxy(IAgentCharacterEx *This,IUnknown **punkEnum);
  void __RPC_STUB IAgentCharacterEx_GetAnimationNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCharacterEx_GetSRStatus_Proxy(IAgentCharacterEx *This,__LONG32 *plStatus);
  void __RPC_STUB IAgentCharacterEx_GetSRStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgent_INTERFACE_DEFINED__
#define __IAgent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgent : public IDispatch {
  public:
    virtual HRESULT WINAPI Load(VARIANT vLoadKey,__LONG32 *pdwCharID,__LONG32 *pdwReqID) = 0;
    virtual HRESULT WINAPI Unload(__LONG32 dwCharID) = 0;
    virtual HRESULT WINAPI Register(IUnknown *punkNotifySink,__LONG32 *pdwSinkID) = 0;
    virtual HRESULT WINAPI Unregister(__LONG32 dwSinkID) = 0;
    virtual HRESULT WINAPI GetCharacter(__LONG32 dwCharID,IDispatch **ppunkCharacter) = 0;
    virtual HRESULT WINAPI GetSuspended(__LONG32 *pbSuspended) = 0;
  };
#else
  typedef struct IAgentVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgent *This);
      ULONG (WINAPI *Release)(IAgent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Load)(IAgent *This,VARIANT vLoadKey,__LONG32 *pdwCharID,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Unload)(IAgent *This,__LONG32 dwCharID);
      HRESULT (WINAPI *Register)(IAgent *This,IUnknown *punkNotifySink,__LONG32 *pdwSinkID);
      HRESULT (WINAPI *Unregister)(IAgent *This,__LONG32 dwSinkID);
      HRESULT (WINAPI *GetCharacter)(IAgent *This,__LONG32 dwCharID,IDispatch **ppunkCharacter);
      HRESULT (WINAPI *GetSuspended)(IAgent *This,__LONG32 *pbSuspended);
    END_INTERFACE
  } IAgentVtbl;
  struct IAgent {
    CONST_VTBL struct IAgentVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgent_Release(This) (This)->lpVtbl->Release(This)
#define IAgent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgent_Load(This,vLoadKey,pdwCharID,pdwReqID) (This)->lpVtbl->Load(This,vLoadKey,pdwCharID,pdwReqID)
#define IAgent_Unload(This,dwCharID) (This)->lpVtbl->Unload(This,dwCharID)
#define IAgent_Register(This,punkNotifySink,pdwSinkID) (This)->lpVtbl->Register(This,punkNotifySink,pdwSinkID)
#define IAgent_Unregister(This,dwSinkID) (This)->lpVtbl->Unregister(This,dwSinkID)
#define IAgent_GetCharacter(This,dwCharID,ppunkCharacter) (This)->lpVtbl->GetCharacter(This,dwCharID,ppunkCharacter)
#define IAgent_GetSuspended(This,pbSuspended) (This)->lpVtbl->GetSuspended(This,pbSuspended)
#endif
#endif
  HRESULT WINAPI IAgent_Load_Proxy(IAgent *This,VARIANT vLoadKey,__LONG32 *pdwCharID,__LONG32 *pdwReqID);
  void __RPC_STUB IAgent_Load_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgent_Unload_Proxy(IAgent *This,__LONG32 dwCharID);
  void __RPC_STUB IAgent_Unload_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgent_Register_Proxy(IAgent *This,IUnknown *punkNotifySink,__LONG32 *pdwSinkID);
  void __RPC_STUB IAgent_Register_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgent_Unregister_Proxy(IAgent *This,__LONG32 dwSinkID);
  void __RPC_STUB IAgent_Unregister_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgent_GetCharacter_Proxy(IAgent *This,__LONG32 dwCharID,IDispatch **ppunkCharacter);
  void __RPC_STUB IAgent_GetCharacter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgent_GetSuspended_Proxy(IAgent *This,__LONG32 *pbSuspended);
  void __RPC_STUB IAgent_GetSuspended_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentEx_INTERFACE_DEFINED__
#define __IAgentEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentEx : public IAgent {
  public:
    virtual HRESULT WINAPI GetCharacterEx(__LONG32 dwCharID,IAgentCharacterEx **ppCharacterEx) = 0;
    virtual HRESULT WINAPI GetVersion(short *psMajor,short *psMinor) = 0;
    virtual HRESULT WINAPI ShowDefaultCharacterProperties(short x,short y,__LONG32 bUseDefaultPosition) = 0;
  };
#else
  typedef struct IAgentExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentEx *This);
      ULONG (WINAPI *Release)(IAgentEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Load)(IAgentEx *This,VARIANT vLoadKey,__LONG32 *pdwCharID,__LONG32 *pdwReqID);
      HRESULT (WINAPI *Unload)(IAgentEx *This,__LONG32 dwCharID);
      HRESULT (WINAPI *Register)(IAgentEx *This,IUnknown *punkNotifySink,__LONG32 *pdwSinkID);
      HRESULT (WINAPI *Unregister)(IAgentEx *This,__LONG32 dwSinkID);
      HRESULT (WINAPI *GetCharacter)(IAgentEx *This,__LONG32 dwCharID,IDispatch **ppunkCharacter);
      HRESULT (WINAPI *GetSuspended)(IAgentEx *This,__LONG32 *pbSuspended);
      HRESULT (WINAPI *GetCharacterEx)(IAgentEx *This,__LONG32 dwCharID,IAgentCharacterEx **ppCharacterEx);
      HRESULT (WINAPI *GetVersion)(IAgentEx *This,short *psMajor,short *psMinor);
      HRESULT (WINAPI *ShowDefaultCharacterProperties)(IAgentEx *This,short x,short y,__LONG32 bUseDefaultPosition);
    END_INTERFACE
  } IAgentExVtbl;
  struct IAgentEx {
    CONST_VTBL struct IAgentExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentEx_Load(This,vLoadKey,pdwCharID,pdwReqID) (This)->lpVtbl->Load(This,vLoadKey,pdwCharID,pdwReqID)
#define IAgentEx_Unload(This,dwCharID) (This)->lpVtbl->Unload(This,dwCharID)
#define IAgentEx_Register(This,punkNotifySink,pdwSinkID) (This)->lpVtbl->Register(This,punkNotifySink,pdwSinkID)
#define IAgentEx_Unregister(This,dwSinkID) (This)->lpVtbl->Unregister(This,dwSinkID)
#define IAgentEx_GetCharacter(This,dwCharID,ppunkCharacter) (This)->lpVtbl->GetCharacter(This,dwCharID,ppunkCharacter)
#define IAgentEx_GetSuspended(This,pbSuspended) (This)->lpVtbl->GetSuspended(This,pbSuspended)
#define IAgentEx_GetCharacterEx(This,dwCharID,ppCharacterEx) (This)->lpVtbl->GetCharacterEx(This,dwCharID,ppCharacterEx)
#define IAgentEx_GetVersion(This,psMajor,psMinor) (This)->lpVtbl->GetVersion(This,psMajor,psMinor)
#define IAgentEx_ShowDefaultCharacterProperties(This,x,y,bUseDefaultPosition) (This)->lpVtbl->ShowDefaultCharacterProperties(This,x,y,bUseDefaultPosition)
#endif
#endif
  HRESULT WINAPI IAgentEx_GetCharacterEx_Proxy(IAgentEx *This,__LONG32 dwCharID,IAgentCharacterEx **ppCharacterEx);
  void __RPC_STUB IAgentEx_GetCharacterEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentEx_GetVersion_Proxy(IAgentEx *This,short *psMajor,short *psMinor);
  void __RPC_STUB IAgentEx_GetVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentEx_ShowDefaultCharacterProperties_Proxy(IAgentEx *This,short x,short y,__LONG32 bUseDefaultPosition);
  void __RPC_STUB IAgentEx_ShowDefaultCharacterProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentNotifySink_INTERFACE_DEFINED__
#define __IAgentNotifySink_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentNotifySink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentNotifySink : public IDispatch {
  public:
    virtual HRESULT WINAPI Command(__LONG32 dwCommandID,IUnknown *punkUserInput) = 0;
    virtual HRESULT WINAPI ActivateInputState(__LONG32 dwCharID,__LONG32 bActivated) = 0;
    virtual HRESULT WINAPI Restart(void) = 0;
    virtual HRESULT WINAPI Shutdown(void) = 0;
    virtual HRESULT WINAPI VisibleState(__LONG32 dwCharID,__LONG32 bVisible,__LONG32 dwCause) = 0;
    virtual HRESULT WINAPI Click(__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y) = 0;
    virtual HRESULT WINAPI DblClick(__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y) = 0;
    virtual HRESULT WINAPI DragStart(__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y) = 0;
    virtual HRESULT WINAPI DragComplete(__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y) = 0;
    virtual HRESULT WINAPI RequestStart(__LONG32 dwRequestID) = 0;
    virtual HRESULT WINAPI RequestComplete(__LONG32 dwRequestID,__LONG32 hrStatus) = 0;
    virtual HRESULT WINAPI BookMark(__LONG32 dwBookMarkID) = 0;
    virtual HRESULT WINAPI Idle(__LONG32 dwCharID,__LONG32 bStart) = 0;
    virtual HRESULT WINAPI Move(__LONG32 dwCharID,__LONG32 x,__LONG32 y,__LONG32 dwCause) = 0;
    virtual HRESULT WINAPI Size(__LONG32 dwCharID,__LONG32 lWidth,__LONG32 lHeight) = 0;
    virtual HRESULT WINAPI BalloonVisibleState(__LONG32 dwCharID,__LONG32 bVisible) = 0;
  };
#else
  typedef struct IAgentNotifySinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentNotifySink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentNotifySink *This);
      ULONG (WINAPI *Release)(IAgentNotifySink *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentNotifySink *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentNotifySink *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentNotifySink *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentNotifySink *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Command)(IAgentNotifySink *This,__LONG32 dwCommandID,IUnknown *punkUserInput);
      HRESULT (WINAPI *ActivateInputState)(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 bActivated);
      HRESULT (WINAPI *Restart)(IAgentNotifySink *This);
      HRESULT (WINAPI *Shutdown)(IAgentNotifySink *This);
      HRESULT (WINAPI *VisibleState)(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 bVisible,__LONG32 dwCause);
      HRESULT (WINAPI *Click)(IAgentNotifySink *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
      HRESULT (WINAPI *DblClick)(IAgentNotifySink *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
      HRESULT (WINAPI *DragStart)(IAgentNotifySink *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
      HRESULT (WINAPI *DragComplete)(IAgentNotifySink *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
      HRESULT (WINAPI *RequestStart)(IAgentNotifySink *This,__LONG32 dwRequestID);
      HRESULT (WINAPI *RequestComplete)(IAgentNotifySink *This,__LONG32 dwRequestID,__LONG32 hrStatus);
      HRESULT (WINAPI *BookMark)(IAgentNotifySink *This,__LONG32 dwBookMarkID);
      HRESULT (WINAPI *Idle)(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 bStart);
      HRESULT (WINAPI *Move)(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 x,__LONG32 y,__LONG32 dwCause);
      HRESULT (WINAPI *Size)(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 lWidth,__LONG32 lHeight);
      HRESULT (WINAPI *BalloonVisibleState)(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 bVisible);
    END_INTERFACE
  } IAgentNotifySinkVtbl;
  struct IAgentNotifySink {
    CONST_VTBL struct IAgentNotifySinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentNotifySink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentNotifySink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentNotifySink_Release(This) (This)->lpVtbl->Release(This)
#define IAgentNotifySink_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentNotifySink_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentNotifySink_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentNotifySink_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentNotifySink_Command(This,dwCommandID,punkUserInput) (This)->lpVtbl->Command(This,dwCommandID,punkUserInput)
#define IAgentNotifySink_ActivateInputState(This,dwCharID,bActivated) (This)->lpVtbl->ActivateInputState(This,dwCharID,bActivated)
#define IAgentNotifySink_Restart(This) (This)->lpVtbl->Restart(This)
#define IAgentNotifySink_Shutdown(This) (This)->lpVtbl->Shutdown(This)
#define IAgentNotifySink_VisibleState(This,dwCharID,bVisible,dwCause) (This)->lpVtbl->VisibleState(This,dwCharID,bVisible,dwCause)
#define IAgentNotifySink_Click(This,dwCharID,fwKeys,x,y) (This)->lpVtbl->Click(This,dwCharID,fwKeys,x,y)
#define IAgentNotifySink_DblClick(This,dwCharID,fwKeys,x,y) (This)->lpVtbl->DblClick(This,dwCharID,fwKeys,x,y)
#define IAgentNotifySink_DragStart(This,dwCharID,fwKeys,x,y) (This)->lpVtbl->DragStart(This,dwCharID,fwKeys,x,y)
#define IAgentNotifySink_DragComplete(This,dwCharID,fwKeys,x,y) (This)->lpVtbl->DragComplete(This,dwCharID,fwKeys,x,y)
#define IAgentNotifySink_RequestStart(This,dwRequestID) (This)->lpVtbl->RequestStart(This,dwRequestID)
#define IAgentNotifySink_RequestComplete(This,dwRequestID,hrStatus) (This)->lpVtbl->RequestComplete(This,dwRequestID,hrStatus)
#define IAgentNotifySink_BookMark(This,dwBookMarkID) (This)->lpVtbl->BookMark(This,dwBookMarkID)
#define IAgentNotifySink_Idle(This,dwCharID,bStart) (This)->lpVtbl->Idle(This,dwCharID,bStart)
#define IAgentNotifySink_Move(This,dwCharID,x,y,dwCause) (This)->lpVtbl->Move(This,dwCharID,x,y,dwCause)
#define IAgentNotifySink_Size(This,dwCharID,lWidth,lHeight) (This)->lpVtbl->Size(This,dwCharID,lWidth,lHeight)
#define IAgentNotifySink_BalloonVisibleState(This,dwCharID,bVisible) (This)->lpVtbl->BalloonVisibleState(This,dwCharID,bVisible)
#endif
#endif
  HRESULT WINAPI IAgentNotifySink_Command_Proxy(IAgentNotifySink *This,__LONG32 dwCommandID,IUnknown *punkUserInput);
  void __RPC_STUB IAgentNotifySink_Command_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_ActivateInputState_Proxy(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 bActivated);
  void __RPC_STUB IAgentNotifySink_ActivateInputState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_Restart_Proxy(IAgentNotifySink *This);
  void __RPC_STUB IAgentNotifySink_Restart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_Shutdown_Proxy(IAgentNotifySink *This);
  void __RPC_STUB IAgentNotifySink_Shutdown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_VisibleState_Proxy(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 bVisible,__LONG32 dwCause);
  void __RPC_STUB IAgentNotifySink_VisibleState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_Click_Proxy(IAgentNotifySink *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
  void __RPC_STUB IAgentNotifySink_Click_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_DblClick_Proxy(IAgentNotifySink *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
  void __RPC_STUB IAgentNotifySink_DblClick_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_DragStart_Proxy(IAgentNotifySink *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
  void __RPC_STUB IAgentNotifySink_DragStart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_DragComplete_Proxy(IAgentNotifySink *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
  void __RPC_STUB IAgentNotifySink_DragComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_RequestStart_Proxy(IAgentNotifySink *This,__LONG32 dwRequestID);
  void __RPC_STUB IAgentNotifySink_RequestStart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_RequestComplete_Proxy(IAgentNotifySink *This,__LONG32 dwRequestID,__LONG32 hrStatus);
  void __RPC_STUB IAgentNotifySink_RequestComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_BookMark_Proxy(IAgentNotifySink *This,__LONG32 dwBookMarkID);
  void __RPC_STUB IAgentNotifySink_BookMark_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_Idle_Proxy(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 bStart);
  void __RPC_STUB IAgentNotifySink_Idle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_Move_Proxy(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 x,__LONG32 y,__LONG32 dwCause);
  void __RPC_STUB IAgentNotifySink_Move_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_Size_Proxy(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 lWidth,__LONG32 lHeight);
  void __RPC_STUB IAgentNotifySink_Size_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySink_BalloonVisibleState_Proxy(IAgentNotifySink *This,__LONG32 dwCharID,__LONG32 bVisible);
  void __RPC_STUB IAgentNotifySink_BalloonVisibleState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentNotifySinkEx_INTERFACE_DEFINED__
#define __IAgentNotifySinkEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentNotifySinkEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentNotifySinkEx : public IAgentNotifySink {
  public:
    virtual HRESULT WINAPI HelpComplete(__LONG32 dwCharID,__LONG32 dwCommandID,__LONG32 dwCause) = 0;
    virtual HRESULT WINAPI ListeningState(__LONG32 dwCharID,__LONG32 bListening,__LONG32 dwCause) = 0;
    virtual HRESULT WINAPI DefaultCharacterChange(BSTR bszGUID) = 0;
    virtual HRESULT WINAPI AgentPropertyChange(void) = 0;
    virtual HRESULT WINAPI ActiveClientChange(__LONG32 dwCharID,__LONG32 lStatus) = 0;
  };
#else
  typedef struct IAgentNotifySinkExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentNotifySinkEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentNotifySinkEx *This);
      ULONG (WINAPI *Release)(IAgentNotifySinkEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentNotifySinkEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentNotifySinkEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentNotifySinkEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentNotifySinkEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Command)(IAgentNotifySinkEx *This,__LONG32 dwCommandID,IUnknown *punkUserInput);
      HRESULT (WINAPI *ActivateInputState)(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 bActivated);
      HRESULT (WINAPI *Restart)(IAgentNotifySinkEx *This);
      HRESULT (WINAPI *Shutdown)(IAgentNotifySinkEx *This);
      HRESULT (WINAPI *VisibleState)(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 bVisible,__LONG32 dwCause);
      HRESULT (WINAPI *Click)(IAgentNotifySinkEx *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
      HRESULT (WINAPI *DblClick)(IAgentNotifySinkEx *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
      HRESULT (WINAPI *DragStart)(IAgentNotifySinkEx *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
      HRESULT (WINAPI *DragComplete)(IAgentNotifySinkEx *This,__LONG32 dwCharID,short fwKeys,__LONG32 x,__LONG32 y);
      HRESULT (WINAPI *RequestStart)(IAgentNotifySinkEx *This,__LONG32 dwRequestID);
      HRESULT (WINAPI *RequestComplete)(IAgentNotifySinkEx *This,__LONG32 dwRequestID,__LONG32 hrStatus);
      HRESULT (WINAPI *BookMark)(IAgentNotifySinkEx *This,__LONG32 dwBookMarkID);
      HRESULT (WINAPI *Idle)(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 bStart);
      HRESULT (WINAPI *Move)(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 x,__LONG32 y,__LONG32 dwCause);
      HRESULT (WINAPI *Size)(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 lWidth,__LONG32 lHeight);
      HRESULT (WINAPI *BalloonVisibleState)(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 bVisible);
      HRESULT (WINAPI *HelpComplete)(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 dwCommandID,__LONG32 dwCause);
      HRESULT (WINAPI *ListeningState)(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 bListening,__LONG32 dwCause);
      HRESULT (WINAPI *DefaultCharacterChange)(IAgentNotifySinkEx *This,BSTR bszGUID);
      HRESULT (WINAPI *AgentPropertyChange)(IAgentNotifySinkEx *This);
      HRESULT (WINAPI *ActiveClientChange)(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 lStatus);
    END_INTERFACE
  } IAgentNotifySinkExVtbl;
  struct IAgentNotifySinkEx {
    CONST_VTBL struct IAgentNotifySinkExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentNotifySinkEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentNotifySinkEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentNotifySinkEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentNotifySinkEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentNotifySinkEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentNotifySinkEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentNotifySinkEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentNotifySinkEx_Command(This,dwCommandID,punkUserInput) (This)->lpVtbl->Command(This,dwCommandID,punkUserInput)
#define IAgentNotifySinkEx_ActivateInputState(This,dwCharID,bActivated) (This)->lpVtbl->ActivateInputState(This,dwCharID,bActivated)
#define IAgentNotifySinkEx_Restart(This) (This)->lpVtbl->Restart(This)
#define IAgentNotifySinkEx_Shutdown(This) (This)->lpVtbl->Shutdown(This)
#define IAgentNotifySinkEx_VisibleState(This,dwCharID,bVisible,dwCause) (This)->lpVtbl->VisibleState(This,dwCharID,bVisible,dwCause)
#define IAgentNotifySinkEx_Click(This,dwCharID,fwKeys,x,y) (This)->lpVtbl->Click(This,dwCharID,fwKeys,x,y)
#define IAgentNotifySinkEx_DblClick(This,dwCharID,fwKeys,x,y) (This)->lpVtbl->DblClick(This,dwCharID,fwKeys,x,y)
#define IAgentNotifySinkEx_DragStart(This,dwCharID,fwKeys,x,y) (This)->lpVtbl->DragStart(This,dwCharID,fwKeys,x,y)
#define IAgentNotifySinkEx_DragComplete(This,dwCharID,fwKeys,x,y) (This)->lpVtbl->DragComplete(This,dwCharID,fwKeys,x,y)
#define IAgentNotifySinkEx_RequestStart(This,dwRequestID) (This)->lpVtbl->RequestStart(This,dwRequestID)
#define IAgentNotifySinkEx_RequestComplete(This,dwRequestID,hrStatus) (This)->lpVtbl->RequestComplete(This,dwRequestID,hrStatus)
#define IAgentNotifySinkEx_BookMark(This,dwBookMarkID) (This)->lpVtbl->BookMark(This,dwBookMarkID)
#define IAgentNotifySinkEx_Idle(This,dwCharID,bStart) (This)->lpVtbl->Idle(This,dwCharID,bStart)
#define IAgentNotifySinkEx_Move(This,dwCharID,x,y,dwCause) (This)->lpVtbl->Move(This,dwCharID,x,y,dwCause)
#define IAgentNotifySinkEx_Size(This,dwCharID,lWidth,lHeight) (This)->lpVtbl->Size(This,dwCharID,lWidth,lHeight)
#define IAgentNotifySinkEx_BalloonVisibleState(This,dwCharID,bVisible) (This)->lpVtbl->BalloonVisibleState(This,dwCharID,bVisible)
#define IAgentNotifySinkEx_HelpComplete(This,dwCharID,dwCommandID,dwCause) (This)->lpVtbl->HelpComplete(This,dwCharID,dwCommandID,dwCause)
#define IAgentNotifySinkEx_ListeningState(This,dwCharID,bListening,dwCause) (This)->lpVtbl->ListeningState(This,dwCharID,bListening,dwCause)
#define IAgentNotifySinkEx_DefaultCharacterChange(This,bszGUID) (This)->lpVtbl->DefaultCharacterChange(This,bszGUID)
#define IAgentNotifySinkEx_AgentPropertyChange(This) (This)->lpVtbl->AgentPropertyChange(This)
#define IAgentNotifySinkEx_ActiveClientChange(This,dwCharID,lStatus) (This)->lpVtbl->ActiveClientChange(This,dwCharID,lStatus)
#endif
#endif
  HRESULT WINAPI IAgentNotifySinkEx_HelpComplete_Proxy(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 dwCommandID,__LONG32 dwCause);
  void __RPC_STUB IAgentNotifySinkEx_HelpComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySinkEx_ListeningState_Proxy(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 bListening,__LONG32 dwCause);
  void __RPC_STUB IAgentNotifySinkEx_ListeningState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySinkEx_DefaultCharacterChange_Proxy(IAgentNotifySinkEx *This,BSTR bszGUID);
  void __RPC_STUB IAgentNotifySinkEx_DefaultCharacterChange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySinkEx_AgentPropertyChange_Proxy(IAgentNotifySinkEx *This);
  void __RPC_STUB IAgentNotifySinkEx_AgentPropertyChange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentNotifySinkEx_ActiveClientChange_Proxy(IAgentNotifySinkEx *This,__LONG32 dwCharID,__LONG32 lStatus);
  void __RPC_STUB IAgentNotifySinkEx_ActiveClientChange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentPrivateNotifySink_INTERFACE_DEFINED__
#define __IAgentPrivateNotifySink_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentPrivateNotifySink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentPrivateNotifySink : public IUnknown {
  public:
    virtual HRESULT WINAPI ReleaseAll(void) = 0;
    virtual HRESULT WINAPI ReleaseOne(void *pnNotify) = 0;
    virtual HRESULT WINAPI GetClientID(DWORD *pdwClientID) = 0;
  };
#else
  typedef struct IAgentPrivateNotifySinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentPrivateNotifySink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentPrivateNotifySink *This);
      ULONG (WINAPI *Release)(IAgentPrivateNotifySink *This);
      HRESULT (WINAPI *ReleaseAll)(IAgentPrivateNotifySink *This);
      HRESULT (WINAPI *ReleaseOne)(IAgentPrivateNotifySink *This,void *pnNotify);
      HRESULT (WINAPI *GetClientID)(IAgentPrivateNotifySink *This,DWORD *pdwClientID);
    END_INTERFACE
  } IAgentPrivateNotifySinkVtbl;
  struct IAgentPrivateNotifySink {
    CONST_VTBL struct IAgentPrivateNotifySinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentPrivateNotifySink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentPrivateNotifySink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentPrivateNotifySink_Release(This) (This)->lpVtbl->Release(This)
#define IAgentPrivateNotifySink_ReleaseAll(This) (This)->lpVtbl->ReleaseAll(This)
#define IAgentPrivateNotifySink_ReleaseOne(This,pnNotify) (This)->lpVtbl->ReleaseOne(This,pnNotify)
#define IAgentPrivateNotifySink_GetClientID(This,pdwClientID) (This)->lpVtbl->GetClientID(This,pdwClientID)
#endif
#endif
  HRESULT WINAPI IAgentPrivateNotifySink_ReleaseAll_Proxy(IAgentPrivateNotifySink *This);
  void __RPC_STUB IAgentPrivateNotifySink_ReleaseAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentPrivateNotifySink_ReleaseOne_Proxy(IAgentPrivateNotifySink *This,void *pnNotify);
  void __RPC_STUB IAgentPrivateNotifySink_ReleaseOne_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentPrivateNotifySink_GetClientID_Proxy(IAgentPrivateNotifySink *This,DWORD *pdwClientID);
  void __RPC_STUB IAgentPrivateNotifySink_GetClientID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCustomMarshalMaker_INTERFACE_DEFINED__
#define __IAgentCustomMarshalMaker_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCustomMarshalMaker;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCustomMarshalMaker : public IUnknown {
  public:
    virtual HRESULT WINAPI Create(IUnknown *pSink,REFIID riidSink,IUnknown **pMarshaledSink) = 0;

  };
#else
  typedef struct IAgentCustomMarshalMakerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCustomMarshalMaker *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCustomMarshalMaker *This);
      ULONG (WINAPI *Release)(IAgentCustomMarshalMaker *This);
      HRESULT (WINAPI *Create)(IAgentCustomMarshalMaker *This,IUnknown *pSink,REFIID riidSink,IUnknown **pMarshaledSink);
    END_INTERFACE
  } IAgentCustomMarshalMakerVtbl;
  struct IAgentCustomMarshalMaker {
    CONST_VTBL struct IAgentCustomMarshalMakerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCustomMarshalMaker_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCustomMarshalMaker_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCustomMarshalMaker_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCustomMarshalMaker_Create(This,pSink,riidSink,pMarshaledSink) (This)->lpVtbl->Create(This,pSink,riidSink,pMarshaledSink)
#endif
#endif
  HRESULT WINAPI IAgentCustomMarshalMaker_Create_Proxy(IAgentCustomMarshalMaker *This,IUnknown *pSink,REFIID riidSink,IUnknown **pMarshaledSink);
  void __RPC_STUB IAgentCustomMarshalMaker_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentClientStatus_INTERFACE_DEFINED__
#define __IAgentClientStatus_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentClientStatus;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentClientStatus : public IUnknown {
  public:
    virtual HRESULT WINAPI Ping(void) = 0;
  };
#else
  typedef struct IAgentClientStatusVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentClientStatus *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentClientStatus *This);
      ULONG (WINAPI *Release)(IAgentClientStatus *This);
      HRESULT (WINAPI *Ping)(IAgentClientStatus *This);
    END_INTERFACE
  } IAgentClientStatusVtbl;
  struct IAgentClientStatus {
    CONST_VTBL struct IAgentClientStatusVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentClientStatus_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentClientStatus_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentClientStatus_Release(This) (This)->lpVtbl->Release(This)
#define IAgentClientStatus_Ping(This) (This)->lpVtbl->Ping(This)
#endif
#endif
  HRESULT WINAPI IAgentClientStatus_Ping_Proxy(IAgentClientStatus *This);
  void __RPC_STUB IAgentClientStatus_Ping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define AGENT_VERSION_MAJOR (2)
#define AGENT_VERSION_MINOR (0)

  extern RPC_IF_HANDLE __MIDL_itf_AgentServer_0229_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_AgentServer_0229_v0_0_s_ifspec;

#ifndef __AgentServerObjects_LIBRARY_DEFINED__
#define __AgentServerObjects_LIBRARY_DEFINED__

  EXTERN_C const IID LIBID_AgentServerObjects;
  EXTERN_C const CLSID CLSID_AgentServer;

#ifdef __cplusplus
  class AgentServer;
#endif
#endif

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
