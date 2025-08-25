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
#error this stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __AgentControl_h__
#define __AgentControl_h__

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __IAgentCtlRequest_FWD_DEFINED__
#define __IAgentCtlRequest_FWD_DEFINED__
  typedef struct IAgentCtlRequest IAgentCtlRequest;
#endif

#ifndef __IAgentCtlUserInput_FWD_DEFINED__
#define __IAgentCtlUserInput_FWD_DEFINED__
  typedef struct IAgentCtlUserInput IAgentCtlUserInput;
#endif

#ifndef __IAgentCtlBalloon_FWD_DEFINED__
#define __IAgentCtlBalloon_FWD_DEFINED__
  typedef struct IAgentCtlBalloon IAgentCtlBalloon;
#endif

#ifndef __IAgentCtlBalloonEx_FWD_DEFINED__
#define __IAgentCtlBalloonEx_FWD_DEFINED__
  typedef struct IAgentCtlBalloonEx IAgentCtlBalloonEx;
#endif

#ifndef __IAgentCtlCommand_FWD_DEFINED__
#define __IAgentCtlCommand_FWD_DEFINED__
  typedef struct IAgentCtlCommand IAgentCtlCommand;
#endif

#ifndef __IAgentCtlCommandEx_FWD_DEFINED__
#define __IAgentCtlCommandEx_FWD_DEFINED__
  typedef struct IAgentCtlCommandEx IAgentCtlCommandEx;
#endif

#ifndef __IAgentCtlCommands_FWD_DEFINED__
#define __IAgentCtlCommands_FWD_DEFINED__
  typedef struct IAgentCtlCommands IAgentCtlCommands;
#endif

#ifndef __IAgentCtlCommandsEx_FWD_DEFINED__
#define __IAgentCtlCommandsEx_FWD_DEFINED__
  typedef struct IAgentCtlCommandsEx IAgentCtlCommandsEx;
#endif

#ifndef __IAgentCtlCharacter_FWD_DEFINED__
#define __IAgentCtlCharacter_FWD_DEFINED__
  typedef struct IAgentCtlCharacter IAgentCtlCharacter;
#endif

#ifndef __IAgentCtlAnimationNames_FWD_DEFINED__
#define __IAgentCtlAnimationNames_FWD_DEFINED__
  typedef struct IAgentCtlAnimationNames IAgentCtlAnimationNames;
#endif

#ifndef __IAgentCtlCharacterEx_FWD_DEFINED__
#define __IAgentCtlCharacterEx_FWD_DEFINED__
  typedef struct IAgentCtlCharacterEx IAgentCtlCharacterEx;
#endif

#ifndef __IAgentCtlCharacters_FWD_DEFINED__
#define __IAgentCtlCharacters_FWD_DEFINED__
  typedef struct IAgentCtlCharacters IAgentCtlCharacters;
#endif

#ifndef __IAgentCtlAudioObject_FWD_DEFINED__
#define __IAgentCtlAudioObject_FWD_DEFINED__
  typedef struct IAgentCtlAudioObject IAgentCtlAudioObject;
#endif

#ifndef __IAgentCtlAudioObjectEx_FWD_DEFINED__
#define __IAgentCtlAudioObjectEx_FWD_DEFINED__
  typedef struct IAgentCtlAudioObjectEx IAgentCtlAudioObjectEx;
#endif

#ifndef __IAgentCtlSpeechInput_FWD_DEFINED__
#define __IAgentCtlSpeechInput_FWD_DEFINED__
  typedef struct IAgentCtlSpeechInput IAgentCtlSpeechInput;
#endif

#ifndef __IAgentCtlPropertySheet_FWD_DEFINED__
#define __IAgentCtlPropertySheet_FWD_DEFINED__
  typedef struct IAgentCtlPropertySheet IAgentCtlPropertySheet;
#endif

#ifndef __IAgentCtlCommandsWindow_FWD_DEFINED__
#define __IAgentCtlCommandsWindow_FWD_DEFINED__
  typedef struct IAgentCtlCommandsWindow IAgentCtlCommandsWindow;
#endif

#ifndef __IAgentCtl_FWD_DEFINED__
#define __IAgentCtl_FWD_DEFINED__
  typedef struct IAgentCtl IAgentCtl;
#endif

#ifndef __IAgentCtlEx_FWD_DEFINED__
#define __IAgentCtlEx_FWD_DEFINED__
  typedef struct IAgentCtlEx IAgentCtlEx;
#endif

#ifndef __IAgentCtlCharacters_FWD_DEFINED__
#define __IAgentCtlCharacters_FWD_DEFINED__
  typedef struct IAgentCtlCharacters IAgentCtlCharacters;
#endif

#ifndef __IAgentCtlBalloon_FWD_DEFINED__
#define __IAgentCtlBalloon_FWD_DEFINED__
  typedef struct IAgentCtlBalloon IAgentCtlBalloon;
#endif

#ifndef __IAgentCtlBalloonEx_FWD_DEFINED__
#define __IAgentCtlBalloonEx_FWD_DEFINED__
  typedef struct IAgentCtlBalloonEx IAgentCtlBalloonEx;
#endif

#ifndef __IAgentCtlCharacter_FWD_DEFINED__
#define __IAgentCtlCharacter_FWD_DEFINED__
  typedef struct IAgentCtlCharacter IAgentCtlCharacter;
#endif

#ifndef __IAgentCtlCharacterEx_FWD_DEFINED__
#define __IAgentCtlCharacterEx_FWD_DEFINED__
  typedef struct IAgentCtlCharacterEx IAgentCtlCharacterEx;
#endif

#ifndef __IAgentCtlAudioObject_FWD_DEFINED__
#define __IAgentCtlAudioObject_FWD_DEFINED__
  typedef struct IAgentCtlAudioObject IAgentCtlAudioObject;
#endif

#ifndef __IAgentCtlAudioObjectEx_FWD_DEFINED__
#define __IAgentCtlAudioObjectEx_FWD_DEFINED__
  typedef struct IAgentCtlAudioObjectEx IAgentCtlAudioObjectEx;
#endif

#ifndef __IAgentCtlSpeechInput_FWD_DEFINED__
#define __IAgentCtlSpeechInput_FWD_DEFINED__
  typedef struct IAgentCtlSpeechInput IAgentCtlSpeechInput;
#endif

#ifndef __IAgentCtlPropertySheet_FWD_DEFINED__
#define __IAgentCtlPropertySheet_FWD_DEFINED__
  typedef struct IAgentCtlPropertySheet IAgentCtlPropertySheet;
#endif

#ifndef __IAgentCtlCommands_FWD_DEFINED__
#define __IAgentCtlCommands_FWD_DEFINED__
  typedef struct IAgentCtlCommands IAgentCtlCommands;
#endif

#ifndef __IAgentCtlCommandsEx_FWD_DEFINED__
#define __IAgentCtlCommandsEx_FWD_DEFINED__
  typedef struct IAgentCtlCommandsEx IAgentCtlCommandsEx;
#endif

#ifndef __IAgentCtlCommand_FWD_DEFINED__
#define __IAgentCtlCommand_FWD_DEFINED__
  typedef struct IAgentCtlCommand IAgentCtlCommand;
#endif

#ifndef __IAgentCtlCommandEx_FWD_DEFINED__
#define __IAgentCtlCommandEx_FWD_DEFINED__
  typedef struct IAgentCtlCommandEx IAgentCtlCommandEx;
#endif

#ifndef __IAgentCtlRequest_FWD_DEFINED__
#define __IAgentCtlRequest_FWD_DEFINED__
  typedef struct IAgentCtlRequest IAgentCtlRequest;
#endif

#ifndef __IAgentCtlUserInput_FWD_DEFINED__
#define __IAgentCtlUserInput_FWD_DEFINED__
  typedef struct IAgentCtlUserInput IAgentCtlUserInput;
#endif

#ifndef __IAgentCtlCommandsWindow_FWD_DEFINED__
#define __IAgentCtlCommandsWindow_FWD_DEFINED__
  typedef struct IAgentCtlCommandsWindow IAgentCtlCommandsWindow;
#endif

#ifndef __IAgentCtl_FWD_DEFINED__
#define __IAgentCtl_FWD_DEFINED__
  typedef struct IAgentCtl IAgentCtl;
#endif

#ifndef __IAgentCtlEx_FWD_DEFINED__
#define __IAgentCtlEx_FWD_DEFINED__
  typedef struct IAgentCtlEx IAgentCtlEx;
#endif

#ifndef ___AgentEvents_FWD_DEFINED__
#define ___AgentEvents_FWD_DEFINED__
  typedef struct _AgentEvents _AgentEvents;
#endif

#ifndef __Agent_FWD_DEFINED__
#define __Agent_FWD_DEFINED__

#ifdef __cplusplus
  typedef class Agent Agent;
#else
  typedef struct Agent Agent;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define RequestSuccess (0)
#define RequestFailed (1)
#define RequestPending (2)
#define RequestInterrupted (3)
#define RequestInProgress (4)

  extern RPC_IF_HANDLE __MIDL_itf_AgentControl_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_AgentControl_0000_v0_0_s_ifspec;

#ifndef __IAgentCtlRequest_INTERFACE_DEFINED__
#define __IAgentCtlRequest_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlRequest;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlRequest : public IDispatch {
  public:
    virtual HRESULT WINAPI get_ID(__LONG32 *ID) = 0;
    virtual HRESULT WINAPI get_Status(__LONG32 *Status) = 0;
    virtual HRESULT WINAPI get_Description(BSTR *Description) = 0;
    virtual HRESULT WINAPI get_Number(__LONG32 *Number) = 0;
  };
#else
  typedef struct IAgentCtlRequestVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlRequest *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlRequest *This);
      ULONG (WINAPI *Release)(IAgentCtlRequest *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlRequest *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlRequest *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlRequest *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlRequest *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_ID)(IAgentCtlRequest *This,__LONG32 *ID);
      HRESULT (WINAPI *get_Status)(IAgentCtlRequest *This,__LONG32 *Status);
      HRESULT (WINAPI *get_Description)(IAgentCtlRequest *This,BSTR *Description);
      HRESULT (WINAPI *get_Number)(IAgentCtlRequest *This,__LONG32 *Number);
    END_INTERFACE
  } IAgentCtlRequestVtbl;
  struct IAgentCtlRequest {
    CONST_VTBL struct IAgentCtlRequestVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlRequest_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlRequest_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlRequest_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlRequest_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlRequest_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlRequest_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlRequest_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlRequest_get_ID(This,ID) (This)->lpVtbl->get_ID(This,ID)
#define IAgentCtlRequest_get_Status(This,Status) (This)->lpVtbl->get_Status(This,Status)
#define IAgentCtlRequest_get_Description(This,Description) (This)->lpVtbl->get_Description(This,Description)
#define IAgentCtlRequest_get_Number(This,Number) (This)->lpVtbl->get_Number(This,Number)
#endif
#endif
  HRESULT WINAPI IAgentCtlRequest_get_ID_Proxy(IAgentCtlRequest *This,__LONG32 *ID);
  void __RPC_STUB IAgentCtlRequest_get_ID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlRequest_get_Status_Proxy(IAgentCtlRequest *This,__LONG32 *Status);
  void __RPC_STUB IAgentCtlRequest_get_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlRequest_get_Description_Proxy(IAgentCtlRequest *This,BSTR *Description);
  void __RPC_STUB IAgentCtlRequest_get_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlRequest_get_Number_Proxy(IAgentCtlRequest *This,__LONG32 *Number);
  void __RPC_STUB IAgentCtlRequest_get_Number_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlUserInput_INTERFACE_DEFINED__
#define __IAgentCtlUserInput_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlUserInput;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlUserInput : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(short *pCount) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pName) = 0;
    virtual HRESULT WINAPI get_CharacterID(BSTR *pCharacterID) = 0;
    virtual HRESULT WINAPI get_Confidence(__LONG32 *pConfidence) = 0;
    virtual HRESULT WINAPI get_Voice(BSTR *pVoice) = 0;
    virtual HRESULT WINAPI get_Alt1Name(BSTR *pAlt1Name) = 0;
    virtual HRESULT WINAPI get_Alt1Confidence(__LONG32 *pAlt1Confidence) = 0;
    virtual HRESULT WINAPI get_Alt1Voice(BSTR *pAlt1Voice) = 0;
    virtual HRESULT WINAPI get_Alt2Name(BSTR *pAlt2Name) = 0;
    virtual HRESULT WINAPI get_Alt2Confidence(__LONG32 *pAlt2Confidence) = 0;
    virtual HRESULT WINAPI get_Alt2Voice(BSTR *pAlt2Voice) = 0;
  };
#else
  typedef struct IAgentCtlUserInputVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlUserInput *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlUserInput *This);
      ULONG (WINAPI *Release)(IAgentCtlUserInput *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlUserInput *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlUserInput *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlUserInput *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlUserInput *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(IAgentCtlUserInput *This,short *pCount);
      HRESULT (WINAPI *get_Name)(IAgentCtlUserInput *This,BSTR *pName);
      HRESULT (WINAPI *get_CharacterID)(IAgentCtlUserInput *This,BSTR *pCharacterID);
      HRESULT (WINAPI *get_Confidence)(IAgentCtlUserInput *This,__LONG32 *pConfidence);
      HRESULT (WINAPI *get_Voice)(IAgentCtlUserInput *This,BSTR *pVoice);
      HRESULT (WINAPI *get_Alt1Name)(IAgentCtlUserInput *This,BSTR *pAlt1Name);
      HRESULT (WINAPI *get_Alt1Confidence)(IAgentCtlUserInput *This,__LONG32 *pAlt1Confidence);
      HRESULT (WINAPI *get_Alt1Voice)(IAgentCtlUserInput *This,BSTR *pAlt1Voice);
      HRESULT (WINAPI *get_Alt2Name)(IAgentCtlUserInput *This,BSTR *pAlt2Name);
      HRESULT (WINAPI *get_Alt2Confidence)(IAgentCtlUserInput *This,__LONG32 *pAlt2Confidence);
      HRESULT (WINAPI *get_Alt2Voice)(IAgentCtlUserInput *This,BSTR *pAlt2Voice);
    END_INTERFACE
  } IAgentCtlUserInputVtbl;
  struct IAgentCtlUserInput {
    CONST_VTBL struct IAgentCtlUserInputVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlUserInput_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlUserInput_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlUserInput_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlUserInput_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlUserInput_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlUserInput_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlUserInput_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlUserInput_get_Count(This,pCount) (This)->lpVtbl->get_Count(This,pCount)
#define IAgentCtlUserInput_get_Name(This,pName) (This)->lpVtbl->get_Name(This,pName)
#define IAgentCtlUserInput_get_CharacterID(This,pCharacterID) (This)->lpVtbl->get_CharacterID(This,pCharacterID)
#define IAgentCtlUserInput_get_Confidence(This,pConfidence) (This)->lpVtbl->get_Confidence(This,pConfidence)
#define IAgentCtlUserInput_get_Voice(This,pVoice) (This)->lpVtbl->get_Voice(This,pVoice)
#define IAgentCtlUserInput_get_Alt1Name(This,pAlt1Name) (This)->lpVtbl->get_Alt1Name(This,pAlt1Name)
#define IAgentCtlUserInput_get_Alt1Confidence(This,pAlt1Confidence) (This)->lpVtbl->get_Alt1Confidence(This,pAlt1Confidence)
#define IAgentCtlUserInput_get_Alt1Voice(This,pAlt1Voice) (This)->lpVtbl->get_Alt1Voice(This,pAlt1Voice)
#define IAgentCtlUserInput_get_Alt2Name(This,pAlt2Name) (This)->lpVtbl->get_Alt2Name(This,pAlt2Name)
#define IAgentCtlUserInput_get_Alt2Confidence(This,pAlt2Confidence) (This)->lpVtbl->get_Alt2Confidence(This,pAlt2Confidence)
#define IAgentCtlUserInput_get_Alt2Voice(This,pAlt2Voice) (This)->lpVtbl->get_Alt2Voice(This,pAlt2Voice)
#endif
#endif
  HRESULT WINAPI IAgentCtlUserInput_get_Count_Proxy(IAgentCtlUserInput *This,short *pCount);
  void __RPC_STUB IAgentCtlUserInput_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlUserInput_get_Name_Proxy(IAgentCtlUserInput *This,BSTR *pName);
  void __RPC_STUB IAgentCtlUserInput_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlUserInput_get_CharacterID_Proxy(IAgentCtlUserInput *This,BSTR *pCharacterID);
  void __RPC_STUB IAgentCtlUserInput_get_CharacterID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlUserInput_get_Confidence_Proxy(IAgentCtlUserInput *This,__LONG32 *pConfidence);
  void __RPC_STUB IAgentCtlUserInput_get_Confidence_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlUserInput_get_Voice_Proxy(IAgentCtlUserInput *This,BSTR *pVoice);
  void __RPC_STUB IAgentCtlUserInput_get_Voice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlUserInput_get_Alt1Name_Proxy(IAgentCtlUserInput *This,BSTR *pAlt1Name);
  void __RPC_STUB IAgentCtlUserInput_get_Alt1Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlUserInput_get_Alt1Confidence_Proxy(IAgentCtlUserInput *This,__LONG32 *pAlt1Confidence);
  void __RPC_STUB IAgentCtlUserInput_get_Alt1Confidence_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlUserInput_get_Alt1Voice_Proxy(IAgentCtlUserInput *This,BSTR *pAlt1Voice);
  void __RPC_STUB IAgentCtlUserInput_get_Alt1Voice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlUserInput_get_Alt2Name_Proxy(IAgentCtlUserInput *This,BSTR *pAlt2Name);
  void __RPC_STUB IAgentCtlUserInput_get_Alt2Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlUserInput_get_Alt2Confidence_Proxy(IAgentCtlUserInput *This,__LONG32 *pAlt2Confidence);
  void __RPC_STUB IAgentCtlUserInput_get_Alt2Confidence_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlUserInput_get_Alt2Voice_Proxy(IAgentCtlUserInput *This,BSTR *pAlt2Voice);
  void __RPC_STUB IAgentCtlUserInput_get_Alt2Voice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlBalloon_INTERFACE_DEFINED__
#define __IAgentCtlBalloon_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlBalloon;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlBalloon : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Enabled(VARIANT_BOOL *Enabled) = 0;
    virtual HRESULT WINAPI get_NumberOfLines(__LONG32 *Lines) = 0;
    virtual HRESULT WINAPI get_CharsPerLine(__LONG32 *CharsPerLine) = 0;
    virtual HRESULT WINAPI get_FontName(BSTR *FontName) = 0;
    virtual HRESULT WINAPI get_FontSize(__LONG32 *FontSize) = 0;
    virtual HRESULT WINAPI get_FontBold(VARIANT_BOOL *FontBold) = 0;
    virtual HRESULT WINAPI get_FontItalic(VARIANT_BOOL *FontItalic) = 0;
    virtual HRESULT WINAPI get_FontStrikethru(VARIANT_BOOL *FontStrikethru) = 0;
    virtual HRESULT WINAPI get_FontUnderline(VARIANT_BOOL *FontUnderline) = 0;
    virtual HRESULT WINAPI get_ForeColor(__LONG32 *ForeColor) = 0;
    virtual HRESULT WINAPI get_BackColor(__LONG32 *BackColor) = 0;
    virtual HRESULT WINAPI get_BorderColor(__LONG32 *BorderColor) = 0;
    virtual HRESULT WINAPI put_Visible(VARIANT_BOOL Visible) = 0;
    virtual HRESULT WINAPI get_Visible(VARIANT_BOOL *Visible) = 0;
    virtual HRESULT WINAPI put_FontName(BSTR FontName) = 0;
    virtual HRESULT WINAPI put_FontSize(__LONG32 FontSize) = 0;
    virtual HRESULT WINAPI put_FontCharSet(short FontCharSet) = 0;
    virtual HRESULT WINAPI get_FontCharSet(short *FontCharSet) = 0;
  };
#else
  typedef struct IAgentCtlBalloonVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlBalloon *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlBalloon *This);
      ULONG (WINAPI *Release)(IAgentCtlBalloon *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlBalloon *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlBalloon *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlBalloon *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlBalloon *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Enabled)(IAgentCtlBalloon *This,VARIANT_BOOL *Enabled);
      HRESULT (WINAPI *get_NumberOfLines)(IAgentCtlBalloon *This,__LONG32 *Lines);
      HRESULT (WINAPI *get_CharsPerLine)(IAgentCtlBalloon *This,__LONG32 *CharsPerLine);
      HRESULT (WINAPI *get_FontName)(IAgentCtlBalloon *This,BSTR *FontName);
      HRESULT (WINAPI *get_FontSize)(IAgentCtlBalloon *This,__LONG32 *FontSize);
      HRESULT (WINAPI *get_FontBold)(IAgentCtlBalloon *This,VARIANT_BOOL *FontBold);
      HRESULT (WINAPI *get_FontItalic)(IAgentCtlBalloon *This,VARIANT_BOOL *FontItalic);
      HRESULT (WINAPI *get_FontStrikethru)(IAgentCtlBalloon *This,VARIANT_BOOL *FontStrikethru);
      HRESULT (WINAPI *get_FontUnderline)(IAgentCtlBalloon *This,VARIANT_BOOL *FontUnderline);
      HRESULT (WINAPI *get_ForeColor)(IAgentCtlBalloon *This,__LONG32 *ForeColor);
      HRESULT (WINAPI *get_BackColor)(IAgentCtlBalloon *This,__LONG32 *BackColor);
      HRESULT (WINAPI *get_BorderColor)(IAgentCtlBalloon *This,__LONG32 *BorderColor);
      HRESULT (WINAPI *put_Visible)(IAgentCtlBalloon *This,VARIANT_BOOL Visible);
      HRESULT (WINAPI *get_Visible)(IAgentCtlBalloon *This,VARIANT_BOOL *Visible);
      HRESULT (WINAPI *put_FontName)(IAgentCtlBalloon *This,BSTR FontName);
      HRESULT (WINAPI *put_FontSize)(IAgentCtlBalloon *This,__LONG32 FontSize);
      HRESULT (WINAPI *put_FontCharSet)(IAgentCtlBalloon *This,short FontCharSet);
      HRESULT (WINAPI *get_FontCharSet)(IAgentCtlBalloon *This,short *FontCharSet);
    END_INTERFACE
  } IAgentCtlBalloonVtbl;
  struct IAgentCtlBalloon {
    CONST_VTBL struct IAgentCtlBalloonVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlBalloon_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlBalloon_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlBalloon_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlBalloon_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlBalloon_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlBalloon_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlBalloon_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlBalloon_get_Enabled(This,Enabled) (This)->lpVtbl->get_Enabled(This,Enabled)
#define IAgentCtlBalloon_get_NumberOfLines(This,Lines) (This)->lpVtbl->get_NumberOfLines(This,Lines)
#define IAgentCtlBalloon_get_CharsPerLine(This,CharsPerLine) (This)->lpVtbl->get_CharsPerLine(This,CharsPerLine)
#define IAgentCtlBalloon_get_FontName(This,FontName) (This)->lpVtbl->get_FontName(This,FontName)
#define IAgentCtlBalloon_get_FontSize(This,FontSize) (This)->lpVtbl->get_FontSize(This,FontSize)
#define IAgentCtlBalloon_get_FontBold(This,FontBold) (This)->lpVtbl->get_FontBold(This,FontBold)
#define IAgentCtlBalloon_get_FontItalic(This,FontItalic) (This)->lpVtbl->get_FontItalic(This,FontItalic)
#define IAgentCtlBalloon_get_FontStrikethru(This,FontStrikethru) (This)->lpVtbl->get_FontStrikethru(This,FontStrikethru)
#define IAgentCtlBalloon_get_FontUnderline(This,FontUnderline) (This)->lpVtbl->get_FontUnderline(This,FontUnderline)
#define IAgentCtlBalloon_get_ForeColor(This,ForeColor) (This)->lpVtbl->get_ForeColor(This,ForeColor)
#define IAgentCtlBalloon_get_BackColor(This,BackColor) (This)->lpVtbl->get_BackColor(This,BackColor)
#define IAgentCtlBalloon_get_BorderColor(This,BorderColor) (This)->lpVtbl->get_BorderColor(This,BorderColor)
#define IAgentCtlBalloon_put_Visible(This,Visible) (This)->lpVtbl->put_Visible(This,Visible)
#define IAgentCtlBalloon_get_Visible(This,Visible) (This)->lpVtbl->get_Visible(This,Visible)
#define IAgentCtlBalloon_put_FontName(This,FontName) (This)->lpVtbl->put_FontName(This,FontName)
#define IAgentCtlBalloon_put_FontSize(This,FontSize) (This)->lpVtbl->put_FontSize(This,FontSize)
#define IAgentCtlBalloon_put_FontCharSet(This,FontCharSet) (This)->lpVtbl->put_FontCharSet(This,FontCharSet)
#define IAgentCtlBalloon_get_FontCharSet(This,FontCharSet) (This)->lpVtbl->get_FontCharSet(This,FontCharSet)
#endif
#endif
  HRESULT WINAPI IAgentCtlBalloon_get_Enabled_Proxy(IAgentCtlBalloon *This,VARIANT_BOOL *Enabled);
  void __RPC_STUB IAgentCtlBalloon_get_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_NumberOfLines_Proxy(IAgentCtlBalloon *This,__LONG32 *Lines);
  void __RPC_STUB IAgentCtlBalloon_get_NumberOfLines_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_CharsPerLine_Proxy(IAgentCtlBalloon *This,__LONG32 *CharsPerLine);
  void __RPC_STUB IAgentCtlBalloon_get_CharsPerLine_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_FontName_Proxy(IAgentCtlBalloon *This,BSTR *FontName);
  void __RPC_STUB IAgentCtlBalloon_get_FontName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_FontSize_Proxy(IAgentCtlBalloon *This,__LONG32 *FontSize);
  void __RPC_STUB IAgentCtlBalloon_get_FontSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_FontBold_Proxy(IAgentCtlBalloon *This,VARIANT_BOOL *FontBold);
  void __RPC_STUB IAgentCtlBalloon_get_FontBold_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_FontItalic_Proxy(IAgentCtlBalloon *This,VARIANT_BOOL *FontItalic);
  void __RPC_STUB IAgentCtlBalloon_get_FontItalic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_FontStrikethru_Proxy(IAgentCtlBalloon *This,VARIANT_BOOL *FontStrikethru);
  void __RPC_STUB IAgentCtlBalloon_get_FontStrikethru_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_FontUnderline_Proxy(IAgentCtlBalloon *This,VARIANT_BOOL *FontUnderline);
  void __RPC_STUB IAgentCtlBalloon_get_FontUnderline_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_ForeColor_Proxy(IAgentCtlBalloon *This,__LONG32 *ForeColor);
  void __RPC_STUB IAgentCtlBalloon_get_ForeColor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_BackColor_Proxy(IAgentCtlBalloon *This,__LONG32 *BackColor);
  void __RPC_STUB IAgentCtlBalloon_get_BackColor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_BorderColor_Proxy(IAgentCtlBalloon *This,__LONG32 *BorderColor);
  void __RPC_STUB IAgentCtlBalloon_get_BorderColor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_put_Visible_Proxy(IAgentCtlBalloon *This,VARIANT_BOOL Visible);
  void __RPC_STUB IAgentCtlBalloon_put_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_Visible_Proxy(IAgentCtlBalloon *This,VARIANT_BOOL *Visible);
  void __RPC_STUB IAgentCtlBalloon_get_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_put_FontName_Proxy(IAgentCtlBalloon *This,BSTR FontName);
  void __RPC_STUB IAgentCtlBalloon_put_FontName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_put_FontSize_Proxy(IAgentCtlBalloon *This,__LONG32 FontSize);
  void __RPC_STUB IAgentCtlBalloon_put_FontSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_put_FontCharSet_Proxy(IAgentCtlBalloon *This,short FontCharSet);
  void __RPC_STUB IAgentCtlBalloon_put_FontCharSet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloon_get_FontCharSet_Proxy(IAgentCtlBalloon *This,short *FontCharSet);
  void __RPC_STUB IAgentCtlBalloon_get_FontCharSet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlBalloonEx_INTERFACE_DEFINED__
#define __IAgentCtlBalloonEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlBalloonEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlBalloonEx : public IAgentCtlBalloon {
  public:
    virtual HRESULT WINAPI put_Style(__LONG32 Style) = 0;
    virtual HRESULT WINAPI get_Style(__LONG32 *Style) = 0;
  };
#else
  typedef struct IAgentCtlBalloonExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlBalloonEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlBalloonEx *This);
      ULONG (WINAPI *Release)(IAgentCtlBalloonEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlBalloonEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlBalloonEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlBalloonEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlBalloonEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Enabled)(IAgentCtlBalloonEx *This,VARIANT_BOOL *Enabled);
      HRESULT (WINAPI *get_NumberOfLines)(IAgentCtlBalloonEx *This,__LONG32 *Lines);
      HRESULT (WINAPI *get_CharsPerLine)(IAgentCtlBalloonEx *This,__LONG32 *CharsPerLine);
      HRESULT (WINAPI *get_FontName)(IAgentCtlBalloonEx *This,BSTR *FontName);
      HRESULT (WINAPI *get_FontSize)(IAgentCtlBalloonEx *This,__LONG32 *FontSize);
      HRESULT (WINAPI *get_FontBold)(IAgentCtlBalloonEx *This,VARIANT_BOOL *FontBold);
      HRESULT (WINAPI *get_FontItalic)(IAgentCtlBalloonEx *This,VARIANT_BOOL *FontItalic);
      HRESULT (WINAPI *get_FontStrikethru)(IAgentCtlBalloonEx *This,VARIANT_BOOL *FontStrikethru);
      HRESULT (WINAPI *get_FontUnderline)(IAgentCtlBalloonEx *This,VARIANT_BOOL *FontUnderline);
      HRESULT (WINAPI *get_ForeColor)(IAgentCtlBalloonEx *This,__LONG32 *ForeColor);
      HRESULT (WINAPI *get_BackColor)(IAgentCtlBalloonEx *This,__LONG32 *BackColor);
      HRESULT (WINAPI *get_BorderColor)(IAgentCtlBalloonEx *This,__LONG32 *BorderColor);
      HRESULT (WINAPI *put_Visible)(IAgentCtlBalloonEx *This,VARIANT_BOOL Visible);
      HRESULT (WINAPI *get_Visible)(IAgentCtlBalloonEx *This,VARIANT_BOOL *Visible);
      HRESULT (WINAPI *put_FontName)(IAgentCtlBalloonEx *This,BSTR FontName);
      HRESULT (WINAPI *put_FontSize)(IAgentCtlBalloonEx *This,__LONG32 FontSize);
      HRESULT (WINAPI *put_FontCharSet)(IAgentCtlBalloonEx *This,short FontCharSet);
      HRESULT (WINAPI *get_FontCharSet)(IAgentCtlBalloonEx *This,short *FontCharSet);
      HRESULT (WINAPI *put_Style)(IAgentCtlBalloonEx *This,__LONG32 Style);
      HRESULT (WINAPI *get_Style)(IAgentCtlBalloonEx *This,__LONG32 *Style);
    END_INTERFACE
  } IAgentCtlBalloonExVtbl;
  struct IAgentCtlBalloonEx {
    CONST_VTBL struct IAgentCtlBalloonExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlBalloonEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlBalloonEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlBalloonEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlBalloonEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlBalloonEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlBalloonEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlBalloonEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlBalloonEx_get_Enabled(This,Enabled) (This)->lpVtbl->get_Enabled(This,Enabled)
#define IAgentCtlBalloonEx_get_NumberOfLines(This,Lines) (This)->lpVtbl->get_NumberOfLines(This,Lines)
#define IAgentCtlBalloonEx_get_CharsPerLine(This,CharsPerLine) (This)->lpVtbl->get_CharsPerLine(This,CharsPerLine)
#define IAgentCtlBalloonEx_get_FontName(This,FontName) (This)->lpVtbl->get_FontName(This,FontName)
#define IAgentCtlBalloonEx_get_FontSize(This,FontSize) (This)->lpVtbl->get_FontSize(This,FontSize)
#define IAgentCtlBalloonEx_get_FontBold(This,FontBold) (This)->lpVtbl->get_FontBold(This,FontBold)
#define IAgentCtlBalloonEx_get_FontItalic(This,FontItalic) (This)->lpVtbl->get_FontItalic(This,FontItalic)
#define IAgentCtlBalloonEx_get_FontStrikethru(This,FontStrikethru) (This)->lpVtbl->get_FontStrikethru(This,FontStrikethru)
#define IAgentCtlBalloonEx_get_FontUnderline(This,FontUnderline) (This)->lpVtbl->get_FontUnderline(This,FontUnderline)
#define IAgentCtlBalloonEx_get_ForeColor(This,ForeColor) (This)->lpVtbl->get_ForeColor(This,ForeColor)
#define IAgentCtlBalloonEx_get_BackColor(This,BackColor) (This)->lpVtbl->get_BackColor(This,BackColor)
#define IAgentCtlBalloonEx_get_BorderColor(This,BorderColor) (This)->lpVtbl->get_BorderColor(This,BorderColor)
#define IAgentCtlBalloonEx_put_Visible(This,Visible) (This)->lpVtbl->put_Visible(This,Visible)
#define IAgentCtlBalloonEx_get_Visible(This,Visible) (This)->lpVtbl->get_Visible(This,Visible)
#define IAgentCtlBalloonEx_put_FontName(This,FontName) (This)->lpVtbl->put_FontName(This,FontName)
#define IAgentCtlBalloonEx_put_FontSize(This,FontSize) (This)->lpVtbl->put_FontSize(This,FontSize)
#define IAgentCtlBalloonEx_put_FontCharSet(This,FontCharSet) (This)->lpVtbl->put_FontCharSet(This,FontCharSet)
#define IAgentCtlBalloonEx_get_FontCharSet(This,FontCharSet) (This)->lpVtbl->get_FontCharSet(This,FontCharSet)
#define IAgentCtlBalloonEx_put_Style(This,Style) (This)->lpVtbl->put_Style(This,Style)
#define IAgentCtlBalloonEx_get_Style(This,Style) (This)->lpVtbl->get_Style(This,Style)
#endif
#endif
  HRESULT WINAPI IAgentCtlBalloonEx_put_Style_Proxy(IAgentCtlBalloonEx *This,__LONG32 Style);
  void __RPC_STUB IAgentCtlBalloonEx_put_Style_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlBalloonEx_get_Style_Proxy(IAgentCtlBalloonEx *This,__LONG32 *Style);
  void __RPC_STUB IAgentCtlBalloonEx_get_Style_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlCommand_INTERFACE_DEFINED__
#define __IAgentCtlCommand_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlCommand;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlCommand : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Voice(BSTR *Voice) = 0;
    virtual HRESULT WINAPI put_Voice(BSTR Voice) = 0;
    virtual HRESULT WINAPI get_Caption(BSTR *Caption) = 0;
    virtual HRESULT WINAPI put_Caption(BSTR Caption) = 0;
    virtual HRESULT WINAPI get_Enabled(VARIANT_BOOL *Enabled) = 0;
    virtual HRESULT WINAPI put_Enabled(VARIANT_BOOL Enabled) = 0;
    virtual HRESULT WINAPI get_Visible(VARIANT_BOOL *Visible) = 0;
    virtual HRESULT WINAPI put_Visible(VARIANT_BOOL Visible) = 0;
    virtual HRESULT WINAPI get_Confidence(__LONG32 *Confidence) = 0;
    virtual HRESULT WINAPI put_Confidence(__LONG32 Confidence) = 0;
    virtual HRESULT WINAPI get_ConfidenceText(BSTR *Text) = 0;
    virtual HRESULT WINAPI put_ConfidenceText(BSTR Text) = 0;
  };
#else
  typedef struct IAgentCtlCommandVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlCommand *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlCommand *This);
      ULONG (WINAPI *Release)(IAgentCtlCommand *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlCommand *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlCommand *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlCommand *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlCommand *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Voice)(IAgentCtlCommand *This,BSTR *Voice);
      HRESULT (WINAPI *put_Voice)(IAgentCtlCommand *This,BSTR Voice);
      HRESULT (WINAPI *get_Caption)(IAgentCtlCommand *This,BSTR *Caption);
      HRESULT (WINAPI *put_Caption)(IAgentCtlCommand *This,BSTR Caption);
      HRESULT (WINAPI *get_Enabled)(IAgentCtlCommand *This,VARIANT_BOOL *Enabled);
      HRESULT (WINAPI *put_Enabled)(IAgentCtlCommand *This,VARIANT_BOOL Enabled);
      HRESULT (WINAPI *get_Visible)(IAgentCtlCommand *This,VARIANT_BOOL *Visible);
      HRESULT (WINAPI *put_Visible)(IAgentCtlCommand *This,VARIANT_BOOL Visible);
      HRESULT (WINAPI *get_Confidence)(IAgentCtlCommand *This,__LONG32 *Confidence);
      HRESULT (WINAPI *put_Confidence)(IAgentCtlCommand *This,__LONG32 Confidence);
      HRESULT (WINAPI *get_ConfidenceText)(IAgentCtlCommand *This,BSTR *Text);
      HRESULT (WINAPI *put_ConfidenceText)(IAgentCtlCommand *This,BSTR Text);
    END_INTERFACE
  } IAgentCtlCommandVtbl;
  struct IAgentCtlCommand {
    CONST_VTBL struct IAgentCtlCommandVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlCommand_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlCommand_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlCommand_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlCommand_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlCommand_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlCommand_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlCommand_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlCommand_get_Voice(This,Voice) (This)->lpVtbl->get_Voice(This,Voice)
#define IAgentCtlCommand_put_Voice(This,Voice) (This)->lpVtbl->put_Voice(This,Voice)
#define IAgentCtlCommand_get_Caption(This,Caption) (This)->lpVtbl->get_Caption(This,Caption)
#define IAgentCtlCommand_put_Caption(This,Caption) (This)->lpVtbl->put_Caption(This,Caption)
#define IAgentCtlCommand_get_Enabled(This,Enabled) (This)->lpVtbl->get_Enabled(This,Enabled)
#define IAgentCtlCommand_put_Enabled(This,Enabled) (This)->lpVtbl->put_Enabled(This,Enabled)
#define IAgentCtlCommand_get_Visible(This,Visible) (This)->lpVtbl->get_Visible(This,Visible)
#define IAgentCtlCommand_put_Visible(This,Visible) (This)->lpVtbl->put_Visible(This,Visible)
#define IAgentCtlCommand_get_Confidence(This,Confidence) (This)->lpVtbl->get_Confidence(This,Confidence)
#define IAgentCtlCommand_put_Confidence(This,Confidence) (This)->lpVtbl->put_Confidence(This,Confidence)
#define IAgentCtlCommand_get_ConfidenceText(This,Text) (This)->lpVtbl->get_ConfidenceText(This,Text)
#define IAgentCtlCommand_put_ConfidenceText(This,Text) (This)->lpVtbl->put_ConfidenceText(This,Text)
#endif
#endif
  HRESULT WINAPI IAgentCtlCommand_get_Voice_Proxy(IAgentCtlCommand *This,BSTR *Voice);
  void __RPC_STUB IAgentCtlCommand_get_Voice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommand_put_Voice_Proxy(IAgentCtlCommand *This,BSTR Voice);
  void __RPC_STUB IAgentCtlCommand_put_Voice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommand_get_Caption_Proxy(IAgentCtlCommand *This,BSTR *Caption);
  void __RPC_STUB IAgentCtlCommand_get_Caption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommand_put_Caption_Proxy(IAgentCtlCommand *This,BSTR Caption);
  void __RPC_STUB IAgentCtlCommand_put_Caption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommand_get_Enabled_Proxy(IAgentCtlCommand *This,VARIANT_BOOL *Enabled);
  void __RPC_STUB IAgentCtlCommand_get_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommand_put_Enabled_Proxy(IAgentCtlCommand *This,VARIANT_BOOL Enabled);
  void __RPC_STUB IAgentCtlCommand_put_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommand_get_Visible_Proxy(IAgentCtlCommand *This,VARIANT_BOOL *Visible);
  void __RPC_STUB IAgentCtlCommand_get_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommand_put_Visible_Proxy(IAgentCtlCommand *This,VARIANT_BOOL Visible);
  void __RPC_STUB IAgentCtlCommand_put_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommand_get_Confidence_Proxy(IAgentCtlCommand *This,__LONG32 *Confidence);
  void __RPC_STUB IAgentCtlCommand_get_Confidence_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommand_put_Confidence_Proxy(IAgentCtlCommand *This,__LONG32 Confidence);
  void __RPC_STUB IAgentCtlCommand_put_Confidence_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommand_get_ConfidenceText_Proxy(IAgentCtlCommand *This,BSTR *Text);
  void __RPC_STUB IAgentCtlCommand_get_ConfidenceText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommand_put_ConfidenceText_Proxy(IAgentCtlCommand *This,BSTR Text);
  void __RPC_STUB IAgentCtlCommand_put_ConfidenceText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlCommandEx_INTERFACE_DEFINED__
#define __IAgentCtlCommandEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlCommandEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlCommandEx : public IAgentCtlCommand {
  public:
    virtual HRESULT WINAPI put_HelpContextID(__LONG32 ID) = 0;
    virtual HRESULT WINAPI get_HelpContextID(__LONG32 *ID) = 0;
    virtual HRESULT WINAPI put_VoiceCaption(BSTR VoiceCaption) = 0;
    virtual HRESULT WINAPI get_VoiceCaption(BSTR *VoiceCaption) = 0;
  };
#else
  typedef struct IAgentCtlCommandExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlCommandEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlCommandEx *This);
      ULONG (WINAPI *Release)(IAgentCtlCommandEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlCommandEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlCommandEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlCommandEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlCommandEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Voice)(IAgentCtlCommandEx *This,BSTR *Voice);
      HRESULT (WINAPI *put_Voice)(IAgentCtlCommandEx *This,BSTR Voice);
      HRESULT (WINAPI *get_Caption)(IAgentCtlCommandEx *This,BSTR *Caption);
      HRESULT (WINAPI *put_Caption)(IAgentCtlCommandEx *This,BSTR Caption);
      HRESULT (WINAPI *get_Enabled)(IAgentCtlCommandEx *This,VARIANT_BOOL *Enabled);
      HRESULT (WINAPI *put_Enabled)(IAgentCtlCommandEx *This,VARIANT_BOOL Enabled);
      HRESULT (WINAPI *get_Visible)(IAgentCtlCommandEx *This,VARIANT_BOOL *Visible);
      HRESULT (WINAPI *put_Visible)(IAgentCtlCommandEx *This,VARIANT_BOOL Visible);
      HRESULT (WINAPI *get_Confidence)(IAgentCtlCommandEx *This,__LONG32 *Confidence);
      HRESULT (WINAPI *put_Confidence)(IAgentCtlCommandEx *This,__LONG32 Confidence);
      HRESULT (WINAPI *get_ConfidenceText)(IAgentCtlCommandEx *This,BSTR *Text);
      HRESULT (WINAPI *put_ConfidenceText)(IAgentCtlCommandEx *This,BSTR Text);
      HRESULT (WINAPI *put_HelpContextID)(IAgentCtlCommandEx *This,__LONG32 ID);
      HRESULT (WINAPI *get_HelpContextID)(IAgentCtlCommandEx *This,__LONG32 *ID);
      HRESULT (WINAPI *put_VoiceCaption)(IAgentCtlCommandEx *This,BSTR VoiceCaption);
      HRESULT (WINAPI *get_VoiceCaption)(IAgentCtlCommandEx *This,BSTR *VoiceCaption);
    END_INTERFACE
  } IAgentCtlCommandExVtbl;
  struct IAgentCtlCommandEx {
    CONST_VTBL struct IAgentCtlCommandExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlCommandEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlCommandEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlCommandEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlCommandEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlCommandEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlCommandEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlCommandEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlCommandEx_get_Voice(This,Voice) (This)->lpVtbl->get_Voice(This,Voice)
#define IAgentCtlCommandEx_put_Voice(This,Voice) (This)->lpVtbl->put_Voice(This,Voice)
#define IAgentCtlCommandEx_get_Caption(This,Caption) (This)->lpVtbl->get_Caption(This,Caption)
#define IAgentCtlCommandEx_put_Caption(This,Caption) (This)->lpVtbl->put_Caption(This,Caption)
#define IAgentCtlCommandEx_get_Enabled(This,Enabled) (This)->lpVtbl->get_Enabled(This,Enabled)
#define IAgentCtlCommandEx_put_Enabled(This,Enabled) (This)->lpVtbl->put_Enabled(This,Enabled)
#define IAgentCtlCommandEx_get_Visible(This,Visible) (This)->lpVtbl->get_Visible(This,Visible)
#define IAgentCtlCommandEx_put_Visible(This,Visible) (This)->lpVtbl->put_Visible(This,Visible)
#define IAgentCtlCommandEx_get_Confidence(This,Confidence) (This)->lpVtbl->get_Confidence(This,Confidence)
#define IAgentCtlCommandEx_put_Confidence(This,Confidence) (This)->lpVtbl->put_Confidence(This,Confidence)
#define IAgentCtlCommandEx_get_ConfidenceText(This,Text) (This)->lpVtbl->get_ConfidenceText(This,Text)
#define IAgentCtlCommandEx_put_ConfidenceText(This,Text) (This)->lpVtbl->put_ConfidenceText(This,Text)
#define IAgentCtlCommandEx_put_HelpContextID(This,ID) (This)->lpVtbl->put_HelpContextID(This,ID)
#define IAgentCtlCommandEx_get_HelpContextID(This,ID) (This)->lpVtbl->get_HelpContextID(This,ID)
#define IAgentCtlCommandEx_put_VoiceCaption(This,VoiceCaption) (This)->lpVtbl->put_VoiceCaption(This,VoiceCaption)
#define IAgentCtlCommandEx_get_VoiceCaption(This,VoiceCaption) (This)->lpVtbl->get_VoiceCaption(This,VoiceCaption)
#endif
#endif
  HRESULT WINAPI IAgentCtlCommandEx_put_HelpContextID_Proxy(IAgentCtlCommandEx *This,__LONG32 ID);
  void __RPC_STUB IAgentCtlCommandEx_put_HelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandEx_get_HelpContextID_Proxy(IAgentCtlCommandEx *This,__LONG32 *ID);
  void __RPC_STUB IAgentCtlCommandEx_get_HelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandEx_put_VoiceCaption_Proxy(IAgentCtlCommandEx *This,BSTR VoiceCaption);
  void __RPC_STUB IAgentCtlCommandEx_put_VoiceCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandEx_get_VoiceCaption_Proxy(IAgentCtlCommandEx *This,BSTR *VoiceCaption);
  void __RPC_STUB IAgentCtlCommandEx_get_VoiceCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlCommands_INTERFACE_DEFINED__
#define __IAgentCtlCommands_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlCommands;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlCommands : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(BSTR Name,IAgentCtlCommandEx **Item) = 0;
    virtual HRESULT WINAPI Command(BSTR Name,IAgentCtlCommandEx **Item) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI get_Caption(BSTR *Caption) = 0;
    virtual HRESULT WINAPI put_Caption(BSTR Caption) = 0;
    virtual HRESULT WINAPI get_Voice(BSTR *Voice) = 0;
    virtual HRESULT WINAPI put_Voice(BSTR Voice) = 0;
    virtual HRESULT WINAPI get_Visible(VARIANT_BOOL *Visible) = 0;
    virtual HRESULT WINAPI put_Visible(VARIANT_BOOL Visible) = 0;
    virtual HRESULT WINAPI get_Enum(IUnknown **ppunkEnum) = 0;
    virtual HRESULT WINAPI Add(BSTR Name,VARIANT Caption,VARIANT Voice,VARIANT Enabled,VARIANT Visible,IAgentCtlCommand **Command) = 0;
    virtual HRESULT WINAPI Insert(BSTR Name,BSTR RefName,VARIANT Before,VARIANT Caption,VARIANT Voice,VARIANT Enabled,VARIANT Visible,IAgentCtlCommand **Command) = 0;
    virtual HRESULT WINAPI Remove(BSTR Name) = 0;
    virtual HRESULT WINAPI RemoveAll(void) = 0;
  };
#else
  typedef struct IAgentCtlCommandsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlCommands *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlCommands *This);
      ULONG (WINAPI *Release)(IAgentCtlCommands *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlCommands *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlCommands *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlCommands *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlCommands *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IAgentCtlCommands *This,BSTR Name,IAgentCtlCommandEx **Item);
      HRESULT (WINAPI *Command)(IAgentCtlCommands *This,BSTR Name,IAgentCtlCommandEx **Item);
      HRESULT (WINAPI *get_Count)(IAgentCtlCommands *This,__LONG32 *Count);
      HRESULT (WINAPI *get_Caption)(IAgentCtlCommands *This,BSTR *Caption);
      HRESULT (WINAPI *put_Caption)(IAgentCtlCommands *This,BSTR Caption);
      HRESULT (WINAPI *get_Voice)(IAgentCtlCommands *This,BSTR *Voice);
      HRESULT (WINAPI *put_Voice)(IAgentCtlCommands *This,BSTR Voice);
      HRESULT (WINAPI *get_Visible)(IAgentCtlCommands *This,VARIANT_BOOL *Visible);
      HRESULT (WINAPI *put_Visible)(IAgentCtlCommands *This,VARIANT_BOOL Visible);
      HRESULT (WINAPI *get_Enum)(IAgentCtlCommands *This,IUnknown **ppunkEnum);
      HRESULT (WINAPI *Add)(IAgentCtlCommands *This,BSTR Name,VARIANT Caption,VARIANT Voice,VARIANT Enabled,VARIANT Visible,IAgentCtlCommand **Command);
      HRESULT (WINAPI *Insert)(IAgentCtlCommands *This,BSTR Name,BSTR RefName,VARIANT Before,VARIANT Caption,VARIANT Voice,VARIANT Enabled,VARIANT Visible,IAgentCtlCommand **Command);
      HRESULT (WINAPI *Remove)(IAgentCtlCommands *This,BSTR Name);
      HRESULT (WINAPI *RemoveAll)(IAgentCtlCommands *This);
    END_INTERFACE
  } IAgentCtlCommandsVtbl;
  struct IAgentCtlCommands {
    CONST_VTBL struct IAgentCtlCommandsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlCommands_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlCommands_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlCommands_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlCommands_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlCommands_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlCommands_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlCommands_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlCommands_get_Item(This,Name,Item) (This)->lpVtbl->get_Item(This,Name,Item)
#define IAgentCtlCommands_Command(This,Name,Item) (This)->lpVtbl->Command(This,Name,Item)
#define IAgentCtlCommands_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IAgentCtlCommands_get_Caption(This,Caption) (This)->lpVtbl->get_Caption(This,Caption)
#define IAgentCtlCommands_put_Caption(This,Caption) (This)->lpVtbl->put_Caption(This,Caption)
#define IAgentCtlCommands_get_Voice(This,Voice) (This)->lpVtbl->get_Voice(This,Voice)
#define IAgentCtlCommands_put_Voice(This,Voice) (This)->lpVtbl->put_Voice(This,Voice)
#define IAgentCtlCommands_get_Visible(This,Visible) (This)->lpVtbl->get_Visible(This,Visible)
#define IAgentCtlCommands_put_Visible(This,Visible) (This)->lpVtbl->put_Visible(This,Visible)
#define IAgentCtlCommands_get_Enum(This,ppunkEnum) (This)->lpVtbl->get_Enum(This,ppunkEnum)
#define IAgentCtlCommands_Add(This,Name,Caption,Voice,Enabled,Visible,Command) (This)->lpVtbl->Add(This,Name,Caption,Voice,Enabled,Visible,Command)
#define IAgentCtlCommands_Insert(This,Name,RefName,Before,Caption,Voice,Enabled,Visible,Command) (This)->lpVtbl->Insert(This,Name,RefName,Before,Caption,Voice,Enabled,Visible,Command)
#define IAgentCtlCommands_Remove(This,Name) (This)->lpVtbl->Remove(This,Name)
#define IAgentCtlCommands_RemoveAll(This) (This)->lpVtbl->RemoveAll(This)
#endif
#endif
  HRESULT WINAPI IAgentCtlCommands_get_Item_Proxy(IAgentCtlCommands *This,BSTR Name,IAgentCtlCommandEx **Item);
  void __RPC_STUB IAgentCtlCommands_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_Command_Proxy(IAgentCtlCommands *This,BSTR Name,IAgentCtlCommandEx **Item);
  void __RPC_STUB IAgentCtlCommands_Command_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_get_Count_Proxy(IAgentCtlCommands *This,__LONG32 *Count);
  void __RPC_STUB IAgentCtlCommands_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_get_Caption_Proxy(IAgentCtlCommands *This,BSTR *Caption);
  void __RPC_STUB IAgentCtlCommands_get_Caption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_put_Caption_Proxy(IAgentCtlCommands *This,BSTR Caption);
  void __RPC_STUB IAgentCtlCommands_put_Caption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_get_Voice_Proxy(IAgentCtlCommands *This,BSTR *Voice);
  void __RPC_STUB IAgentCtlCommands_get_Voice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_put_Voice_Proxy(IAgentCtlCommands *This,BSTR Voice);
  void __RPC_STUB IAgentCtlCommands_put_Voice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_get_Visible_Proxy(IAgentCtlCommands *This,VARIANT_BOOL *Visible);
  void __RPC_STUB IAgentCtlCommands_get_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_put_Visible_Proxy(IAgentCtlCommands *This,VARIANT_BOOL Visible);
  void __RPC_STUB IAgentCtlCommands_put_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_get_Enum_Proxy(IAgentCtlCommands *This,IUnknown **ppunkEnum);
  void __RPC_STUB IAgentCtlCommands_get_Enum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_Add_Proxy(IAgentCtlCommands *This,BSTR Name,VARIANT Caption,VARIANT Voice,VARIANT Enabled,VARIANT Visible,IAgentCtlCommand **Command);
  void __RPC_STUB IAgentCtlCommands_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_Insert_Proxy(IAgentCtlCommands *This,BSTR Name,BSTR RefName,VARIANT Before,VARIANT Caption,VARIANT Voice,VARIANT Enabled,VARIANT Visible,IAgentCtlCommand **Command);
  void __RPC_STUB IAgentCtlCommands_Insert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_Remove_Proxy(IAgentCtlCommands *This,BSTR Name);
  void __RPC_STUB IAgentCtlCommands_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommands_RemoveAll_Proxy(IAgentCtlCommands *This);
  void __RPC_STUB IAgentCtlCommands_RemoveAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlCommandsEx_INTERFACE_DEFINED__
#define __IAgentCtlCommandsEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlCommandsEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlCommandsEx : public IAgentCtlCommands {
  public:
    virtual HRESULT WINAPI put_DefaultCommand(BSTR Name) = 0;
    virtual HRESULT WINAPI get_DefaultCommand(BSTR *Name) = 0;
    virtual HRESULT WINAPI put_HelpContextID(__LONG32 ID) = 0;
    virtual HRESULT WINAPI get_HelpContextID(__LONG32 *ID) = 0;
    virtual HRESULT WINAPI put_FontName(BSTR FontName) = 0;
    virtual HRESULT WINAPI get_FontName(BSTR *FontName) = 0;
    virtual HRESULT WINAPI get_FontSize(__LONG32 *FontSize) = 0;
    virtual HRESULT WINAPI put_FontSize(__LONG32 FontSize) = 0;
    virtual HRESULT WINAPI put_VoiceCaption(BSTR VoiceCaption) = 0;
    virtual HRESULT WINAPI get_VoiceCaption(BSTR *VoiceCaption) = 0;
    virtual HRESULT WINAPI put_GlobalVoiceCommandsEnabled(VARIANT_BOOL Enable) = 0;
    virtual HRESULT WINAPI get_GlobalVoiceCommandsEnabled(VARIANT_BOOL *Enable) = 0;
  };
#else
  typedef struct IAgentCtlCommandsExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlCommandsEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlCommandsEx *This);
      ULONG (WINAPI *Release)(IAgentCtlCommandsEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlCommandsEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlCommandsEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlCommandsEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlCommandsEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IAgentCtlCommandsEx *This,BSTR Name,IAgentCtlCommandEx **Item);
      HRESULT (WINAPI *Command)(IAgentCtlCommandsEx *This,BSTR Name,IAgentCtlCommandEx **Item);
      HRESULT (WINAPI *get_Count)(IAgentCtlCommandsEx *This,__LONG32 *Count);
      HRESULT (WINAPI *get_Caption)(IAgentCtlCommandsEx *This,BSTR *Caption);
      HRESULT (WINAPI *put_Caption)(IAgentCtlCommandsEx *This,BSTR Caption);
      HRESULT (WINAPI *get_Voice)(IAgentCtlCommandsEx *This,BSTR *Voice);
      HRESULT (WINAPI *put_Voice)(IAgentCtlCommandsEx *This,BSTR Voice);
      HRESULT (WINAPI *get_Visible)(IAgentCtlCommandsEx *This,VARIANT_BOOL *Visible);
      HRESULT (WINAPI *put_Visible)(IAgentCtlCommandsEx *This,VARIANT_BOOL Visible);
      HRESULT (WINAPI *get_Enum)(IAgentCtlCommandsEx *This,IUnknown **ppunkEnum);
      HRESULT (WINAPI *Add)(IAgentCtlCommandsEx *This,BSTR Name,VARIANT Caption,VARIANT Voice,VARIANT Enabled,VARIANT Visible,IAgentCtlCommand **Command);
      HRESULT (WINAPI *Insert)(IAgentCtlCommandsEx *This,BSTR Name,BSTR RefName,VARIANT Before,VARIANT Caption,VARIANT Voice,VARIANT Enabled,VARIANT Visible,IAgentCtlCommand **Command);
      HRESULT (WINAPI *Remove)(IAgentCtlCommandsEx *This,BSTR Name);
      HRESULT (WINAPI *RemoveAll)(IAgentCtlCommandsEx *This);
      HRESULT (WINAPI *put_DefaultCommand)(IAgentCtlCommandsEx *This,BSTR Name);
      HRESULT (WINAPI *get_DefaultCommand)(IAgentCtlCommandsEx *This,BSTR *Name);
      HRESULT (WINAPI *put_HelpContextID)(IAgentCtlCommandsEx *This,__LONG32 ID);
      HRESULT (WINAPI *get_HelpContextID)(IAgentCtlCommandsEx *This,__LONG32 *ID);
      HRESULT (WINAPI *put_FontName)(IAgentCtlCommandsEx *This,BSTR FontName);
      HRESULT (WINAPI *get_FontName)(IAgentCtlCommandsEx *This,BSTR *FontName);
      HRESULT (WINAPI *get_FontSize)(IAgentCtlCommandsEx *This,__LONG32 *FontSize);
      HRESULT (WINAPI *put_FontSize)(IAgentCtlCommandsEx *This,__LONG32 FontSize);
      HRESULT (WINAPI *put_VoiceCaption)(IAgentCtlCommandsEx *This,BSTR VoiceCaption);
      HRESULT (WINAPI *get_VoiceCaption)(IAgentCtlCommandsEx *This,BSTR *VoiceCaption);
      HRESULT (WINAPI *put_GlobalVoiceCommandsEnabled)(IAgentCtlCommandsEx *This,VARIANT_BOOL Enable);
      HRESULT (WINAPI *get_GlobalVoiceCommandsEnabled)(IAgentCtlCommandsEx *This,VARIANT_BOOL *Enable);
    END_INTERFACE
  } IAgentCtlCommandsExVtbl;
  struct IAgentCtlCommandsEx {
    CONST_VTBL struct IAgentCtlCommandsExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlCommandsEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlCommandsEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlCommandsEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlCommandsEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlCommandsEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlCommandsEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlCommandsEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlCommandsEx_get_Item(This,Name,Item) (This)->lpVtbl->get_Item(This,Name,Item)
#define IAgentCtlCommandsEx_Command(This,Name,Item) (This)->lpVtbl->Command(This,Name,Item)
#define IAgentCtlCommandsEx_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IAgentCtlCommandsEx_get_Caption(This,Caption) (This)->lpVtbl->get_Caption(This,Caption)
#define IAgentCtlCommandsEx_put_Caption(This,Caption) (This)->lpVtbl->put_Caption(This,Caption)
#define IAgentCtlCommandsEx_get_Voice(This,Voice) (This)->lpVtbl->get_Voice(This,Voice)
#define IAgentCtlCommandsEx_put_Voice(This,Voice) (This)->lpVtbl->put_Voice(This,Voice)
#define IAgentCtlCommandsEx_get_Visible(This,Visible) (This)->lpVtbl->get_Visible(This,Visible)
#define IAgentCtlCommandsEx_put_Visible(This,Visible) (This)->lpVtbl->put_Visible(This,Visible)
#define IAgentCtlCommandsEx_get_Enum(This,ppunkEnum) (This)->lpVtbl->get_Enum(This,ppunkEnum)
#define IAgentCtlCommandsEx_Add(This,Name,Caption,Voice,Enabled,Visible,Command) (This)->lpVtbl->Add(This,Name,Caption,Voice,Enabled,Visible,Command)
#define IAgentCtlCommandsEx_Insert(This,Name,RefName,Before,Caption,Voice,Enabled,Visible,Command) (This)->lpVtbl->Insert(This,Name,RefName,Before,Caption,Voice,Enabled,Visible,Command)
#define IAgentCtlCommandsEx_Remove(This,Name) (This)->lpVtbl->Remove(This,Name)
#define IAgentCtlCommandsEx_RemoveAll(This) (This)->lpVtbl->RemoveAll(This)
#define IAgentCtlCommandsEx_put_DefaultCommand(This,Name) (This)->lpVtbl->put_DefaultCommand(This,Name)
#define IAgentCtlCommandsEx_get_DefaultCommand(This,Name) (This)->lpVtbl->get_DefaultCommand(This,Name)
#define IAgentCtlCommandsEx_put_HelpContextID(This,ID) (This)->lpVtbl->put_HelpContextID(This,ID)
#define IAgentCtlCommandsEx_get_HelpContextID(This,ID) (This)->lpVtbl->get_HelpContextID(This,ID)
#define IAgentCtlCommandsEx_put_FontName(This,FontName) (This)->lpVtbl->put_FontName(This,FontName)
#define IAgentCtlCommandsEx_get_FontName(This,FontName) (This)->lpVtbl->get_FontName(This,FontName)
#define IAgentCtlCommandsEx_get_FontSize(This,FontSize) (This)->lpVtbl->get_FontSize(This,FontSize)
#define IAgentCtlCommandsEx_put_FontSize(This,FontSize) (This)->lpVtbl->put_FontSize(This,FontSize)
#define IAgentCtlCommandsEx_put_VoiceCaption(This,VoiceCaption) (This)->lpVtbl->put_VoiceCaption(This,VoiceCaption)
#define IAgentCtlCommandsEx_get_VoiceCaption(This,VoiceCaption) (This)->lpVtbl->get_VoiceCaption(This,VoiceCaption)
#define IAgentCtlCommandsEx_put_GlobalVoiceCommandsEnabled(This,Enable) (This)->lpVtbl->put_GlobalVoiceCommandsEnabled(This,Enable)
#define IAgentCtlCommandsEx_get_GlobalVoiceCommandsEnabled(This,Enable) (This)->lpVtbl->get_GlobalVoiceCommandsEnabled(This,Enable)
#endif
#endif
  HRESULT WINAPI IAgentCtlCommandsEx_put_DefaultCommand_Proxy(IAgentCtlCommandsEx *This,BSTR Name);
  void __RPC_STUB IAgentCtlCommandsEx_put_DefaultCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsEx_get_DefaultCommand_Proxy(IAgentCtlCommandsEx *This,BSTR *Name);
  void __RPC_STUB IAgentCtlCommandsEx_get_DefaultCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsEx_put_HelpContextID_Proxy(IAgentCtlCommandsEx *This,__LONG32 ID);
  void __RPC_STUB IAgentCtlCommandsEx_put_HelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsEx_get_HelpContextID_Proxy(IAgentCtlCommandsEx *This,__LONG32 *ID);
  void __RPC_STUB IAgentCtlCommandsEx_get_HelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsEx_put_FontName_Proxy(IAgentCtlCommandsEx *This,BSTR FontName);
  void __RPC_STUB IAgentCtlCommandsEx_put_FontName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsEx_get_FontName_Proxy(IAgentCtlCommandsEx *This,BSTR *FontName);
  void __RPC_STUB IAgentCtlCommandsEx_get_FontName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsEx_get_FontSize_Proxy(IAgentCtlCommandsEx *This,__LONG32 *FontSize);
  void __RPC_STUB IAgentCtlCommandsEx_get_FontSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsEx_put_FontSize_Proxy(IAgentCtlCommandsEx *This,__LONG32 FontSize);
  void __RPC_STUB IAgentCtlCommandsEx_put_FontSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsEx_put_VoiceCaption_Proxy(IAgentCtlCommandsEx *This,BSTR VoiceCaption);
  void __RPC_STUB IAgentCtlCommandsEx_put_VoiceCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsEx_get_VoiceCaption_Proxy(IAgentCtlCommandsEx *This,BSTR *VoiceCaption);
  void __RPC_STUB IAgentCtlCommandsEx_get_VoiceCaption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsEx_put_GlobalVoiceCommandsEnabled_Proxy(IAgentCtlCommandsEx *This,VARIANT_BOOL Enable);
  void __RPC_STUB IAgentCtlCommandsEx_put_GlobalVoiceCommandsEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsEx_get_GlobalVoiceCommandsEnabled_Proxy(IAgentCtlCommandsEx *This,VARIANT_BOOL *Enable);
  void __RPC_STUB IAgentCtlCommandsEx_get_GlobalVoiceCommandsEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlCharacter_INTERFACE_DEFINED__
#define __IAgentCtlCharacter_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlCharacter;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlCharacter : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Balloon(IAgentCtlBalloonEx **ppidBalloon) = 0;
    virtual HRESULT WINAPI get_Commands(IAgentCtlCommandsEx **ppidCommands) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *Name) = 0;
    virtual HRESULT WINAPI get_Description(BSTR *Description) = 0;
    virtual HRESULT WINAPI get_Visible(VARIANT_BOOL *Visible) = 0;
    virtual HRESULT WINAPI put_Left(short Left) = 0;
    virtual HRESULT WINAPI get_Left(short *Left) = 0;
    virtual HRESULT WINAPI put_Top(short Top) = 0;
    virtual HRESULT WINAPI get_Top(short *Top) = 0;
    virtual HRESULT WINAPI put_Height(short Height) = 0;
    virtual HRESULT WINAPI get_Height(short *Height) = 0;
    virtual HRESULT WINAPI put_Width(short Width) = 0;
    virtual HRESULT WINAPI get_Width(short *Width) = 0;
    virtual HRESULT WINAPI get_Speed(__LONG32 *Speed) = 0;
    virtual HRESULT WINAPI get_Pitch(__LONG32 *Pitch) = 0;
    virtual HRESULT WINAPI put_IdleOn(VARIANT_BOOL On) = 0;
    virtual HRESULT WINAPI get_IdleOn(VARIANT_BOOL *On) = 0;
    virtual HRESULT WINAPI Activate(VARIANT State,VARIANT_BOOL *Success) = 0;
    virtual HRESULT WINAPI Play(BSTR Animation,IAgentCtlRequest **Request) = 0;
    virtual HRESULT WINAPI Get(BSTR Type,BSTR Name,VARIANT Queue,IAgentCtlRequest **Request) = 0;
    virtual HRESULT WINAPI Stop(VARIANT Request) = 0;
    virtual HRESULT WINAPI Wait(IDispatch *WaitForRequest,IAgentCtlRequest **Request) = 0;
    virtual HRESULT WINAPI Interrupt(IDispatch *InterruptRequest,IAgentCtlRequest **Request) = 0;
    virtual HRESULT WINAPI Speak(VARIANT Text,VARIANT Url,IAgentCtlRequest **Request) = 0;
    virtual HRESULT WINAPI GestureAt(short x,short y,IAgentCtlRequest **Request) = 0;
    virtual HRESULT WINAPI MoveTo(short x,short y,VARIANT Speed,IAgentCtlRequest **Request) = 0;
    virtual HRESULT WINAPI Hide(VARIANT Fast,IAgentCtlRequest **Request) = 0;
    virtual HRESULT WINAPI Show(VARIANT Fast,IAgentCtlRequest **Request) = 0;
    virtual HRESULT WINAPI StopAll(VARIANT Types) = 0;
    virtual HRESULT WINAPI get_MoveCause(short *MoveCause) = 0;
    virtual HRESULT WINAPI get_VisibilityCause(short *VisibilityCause) = 0;
    virtual HRESULT WINAPI get_HasOtherClients(VARIANT_BOOL *HasOtherClients) = 0;
    virtual HRESULT WINAPI put_SoundEffectsOn(VARIANT_BOOL On) = 0;
    virtual HRESULT WINAPI get_SoundEffectsOn(VARIANT_BOOL *On) = 0;
    virtual HRESULT WINAPI put_Name(BSTR Name) = 0;
    virtual HRESULT WINAPI put_Description(BSTR Description) = 0;
    virtual HRESULT WINAPI get_ExtraData(BSTR *ExtraData) = 0;
  };
#else
  typedef struct IAgentCtlCharacterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlCharacter *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlCharacter *This);
      ULONG (WINAPI *Release)(IAgentCtlCharacter *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlCharacter *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlCharacter *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlCharacter *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlCharacter *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Balloon)(IAgentCtlCharacter *This,IAgentCtlBalloonEx **ppidBalloon);
      HRESULT (WINAPI *get_Commands)(IAgentCtlCharacter *This,IAgentCtlCommandsEx **ppidCommands);
      HRESULT (WINAPI *get_Name)(IAgentCtlCharacter *This,BSTR *Name);
      HRESULT (WINAPI *get_Description)(IAgentCtlCharacter *This,BSTR *Description);
      HRESULT (WINAPI *get_Visible)(IAgentCtlCharacter *This,VARIANT_BOOL *Visible);
      HRESULT (WINAPI *put_Left)(IAgentCtlCharacter *This,short Left);
      HRESULT (WINAPI *get_Left)(IAgentCtlCharacter *This,short *Left);
      HRESULT (WINAPI *put_Top)(IAgentCtlCharacter *This,short Top);
      HRESULT (WINAPI *get_Top)(IAgentCtlCharacter *This,short *Top);
      HRESULT (WINAPI *put_Height)(IAgentCtlCharacter *This,short Height);
      HRESULT (WINAPI *get_Height)(IAgentCtlCharacter *This,short *Height);
      HRESULT (WINAPI *put_Width)(IAgentCtlCharacter *This,short Width);
      HRESULT (WINAPI *get_Width)(IAgentCtlCharacter *This,short *Width);
      HRESULT (WINAPI *get_Speed)(IAgentCtlCharacter *This,__LONG32 *Speed);
      HRESULT (WINAPI *get_Pitch)(IAgentCtlCharacter *This,__LONG32 *Pitch);
      HRESULT (WINAPI *put_IdleOn)(IAgentCtlCharacter *This,VARIANT_BOOL On);
      HRESULT (WINAPI *get_IdleOn)(IAgentCtlCharacter *This,VARIANT_BOOL *On);
      HRESULT (WINAPI *Activate)(IAgentCtlCharacter *This,VARIANT State,VARIANT_BOOL *Success);
      HRESULT (WINAPI *Play)(IAgentCtlCharacter *This,BSTR Animation,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Get)(IAgentCtlCharacter *This,BSTR Type,BSTR Name,VARIANT Queue,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Stop)(IAgentCtlCharacter *This,VARIANT Request);
      HRESULT (WINAPI *Wait)(IAgentCtlCharacter *This,IDispatch *WaitForRequest,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Interrupt)(IAgentCtlCharacter *This,IDispatch *InterruptRequest,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Speak)(IAgentCtlCharacter *This,VARIANT Text,VARIANT Url,IAgentCtlRequest **Request);
      HRESULT (WINAPI *GestureAt)(IAgentCtlCharacter *This,short x,short y,IAgentCtlRequest **Request);
      HRESULT (WINAPI *MoveTo)(IAgentCtlCharacter *This,short x,short y,VARIANT Speed,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Hide)(IAgentCtlCharacter *This,VARIANT Fast,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Show)(IAgentCtlCharacter *This,VARIANT Fast,IAgentCtlRequest **Request);
      HRESULT (WINAPI *StopAll)(IAgentCtlCharacter *This,VARIANT Types);
      HRESULT (WINAPI *get_MoveCause)(IAgentCtlCharacter *This,short *MoveCause);
      HRESULT (WINAPI *get_VisibilityCause)(IAgentCtlCharacter *This,short *VisibilityCause);
      HRESULT (WINAPI *get_HasOtherClients)(IAgentCtlCharacter *This,VARIANT_BOOL *HasOtherClients);
      HRESULT (WINAPI *put_SoundEffectsOn)(IAgentCtlCharacter *This,VARIANT_BOOL On);
      HRESULT (WINAPI *get_SoundEffectsOn)(IAgentCtlCharacter *This,VARIANT_BOOL *On);
      HRESULT (WINAPI *put_Name)(IAgentCtlCharacter *This,BSTR Name);
      HRESULT (WINAPI *put_Description)(IAgentCtlCharacter *This,BSTR Description);
      HRESULT (WINAPI *get_ExtraData)(IAgentCtlCharacter *This,BSTR *ExtraData);
    END_INTERFACE
  } IAgentCtlCharacterVtbl;
  struct IAgentCtlCharacter {
    CONST_VTBL struct IAgentCtlCharacterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlCharacter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlCharacter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlCharacter_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlCharacter_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlCharacter_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlCharacter_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlCharacter_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlCharacter_get_Balloon(This,ppidBalloon) (This)->lpVtbl->get_Balloon(This,ppidBalloon)
#define IAgentCtlCharacter_get_Commands(This,ppidCommands) (This)->lpVtbl->get_Commands(This,ppidCommands)
#define IAgentCtlCharacter_get_Name(This,Name) (This)->lpVtbl->get_Name(This,Name)
#define IAgentCtlCharacter_get_Description(This,Description) (This)->lpVtbl->get_Description(This,Description)
#define IAgentCtlCharacter_get_Visible(This,Visible) (This)->lpVtbl->get_Visible(This,Visible)
#define IAgentCtlCharacter_put_Left(This,Left) (This)->lpVtbl->put_Left(This,Left)
#define IAgentCtlCharacter_get_Left(This,Left) (This)->lpVtbl->get_Left(This,Left)
#define IAgentCtlCharacter_put_Top(This,Top) (This)->lpVtbl->put_Top(This,Top)
#define IAgentCtlCharacter_get_Top(This,Top) (This)->lpVtbl->get_Top(This,Top)
#define IAgentCtlCharacter_put_Height(This,Height) (This)->lpVtbl->put_Height(This,Height)
#define IAgentCtlCharacter_get_Height(This,Height) (This)->lpVtbl->get_Height(This,Height)
#define IAgentCtlCharacter_put_Width(This,Width) (This)->lpVtbl->put_Width(This,Width)
#define IAgentCtlCharacter_get_Width(This,Width) (This)->lpVtbl->get_Width(This,Width)
#define IAgentCtlCharacter_get_Speed(This,Speed) (This)->lpVtbl->get_Speed(This,Speed)
#define IAgentCtlCharacter_get_Pitch(This,Pitch) (This)->lpVtbl->get_Pitch(This,Pitch)
#define IAgentCtlCharacter_put_IdleOn(This,On) (This)->lpVtbl->put_IdleOn(This,On)
#define IAgentCtlCharacter_get_IdleOn(This,On) (This)->lpVtbl->get_IdleOn(This,On)
#define IAgentCtlCharacter_Activate(This,State,Success) (This)->lpVtbl->Activate(This,State,Success)
#define IAgentCtlCharacter_Play(This,Animation,Request) (This)->lpVtbl->Play(This,Animation,Request)
#define IAgentCtlCharacter_Get(This,Type,Name,Queue,Request) (This)->lpVtbl->Get(This,Type,Name,Queue,Request)
#define IAgentCtlCharacter_Stop(This,Request) (This)->lpVtbl->Stop(This,Request)
#define IAgentCtlCharacter_Wait(This,WaitForRequest,Request) (This)->lpVtbl->Wait(This,WaitForRequest,Request)
#define IAgentCtlCharacter_Interrupt(This,InterruptRequest,Request) (This)->lpVtbl->Interrupt(This,InterruptRequest,Request)
#define IAgentCtlCharacter_Speak(This,Text,Url,Request) (This)->lpVtbl->Speak(This,Text,Url,Request)
#define IAgentCtlCharacter_GestureAt(This,x,y,Request) (This)->lpVtbl->GestureAt(This,x,y,Request)
#define IAgentCtlCharacter_MoveTo(This,x,y,Speed,Request) (This)->lpVtbl->MoveTo(This,x,y,Speed,Request)
#define IAgentCtlCharacter_Hide(This,Fast,Request) (This)->lpVtbl->Hide(This,Fast,Request)
#define IAgentCtlCharacter_Show(This,Fast,Request) (This)->lpVtbl->Show(This,Fast,Request)
#define IAgentCtlCharacter_StopAll(This,Types) (This)->lpVtbl->StopAll(This,Types)
#define IAgentCtlCharacter_get_MoveCause(This,MoveCause) (This)->lpVtbl->get_MoveCause(This,MoveCause)
#define IAgentCtlCharacter_get_VisibilityCause(This,VisibilityCause) (This)->lpVtbl->get_VisibilityCause(This,VisibilityCause)
#define IAgentCtlCharacter_get_HasOtherClients(This,HasOtherClients) (This)->lpVtbl->get_HasOtherClients(This,HasOtherClients)
#define IAgentCtlCharacter_put_SoundEffectsOn(This,On) (This)->lpVtbl->put_SoundEffectsOn(This,On)
#define IAgentCtlCharacter_get_SoundEffectsOn(This,On) (This)->lpVtbl->get_SoundEffectsOn(This,On)
#define IAgentCtlCharacter_put_Name(This,Name) (This)->lpVtbl->put_Name(This,Name)
#define IAgentCtlCharacter_put_Description(This,Description) (This)->lpVtbl->put_Description(This,Description)
#define IAgentCtlCharacter_get_ExtraData(This,ExtraData) (This)->lpVtbl->get_ExtraData(This,ExtraData)
#endif
#endif
  HRESULT WINAPI IAgentCtlCharacter_get_Balloon_Proxy(IAgentCtlCharacter *This,IAgentCtlBalloonEx **ppidBalloon);
  void __RPC_STUB IAgentCtlCharacter_get_Balloon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_Commands_Proxy(IAgentCtlCharacter *This,IAgentCtlCommandsEx **ppidCommands);
  void __RPC_STUB IAgentCtlCharacter_get_Commands_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_Name_Proxy(IAgentCtlCharacter *This,BSTR *Name);
  void __RPC_STUB IAgentCtlCharacter_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_Description_Proxy(IAgentCtlCharacter *This,BSTR *Description);
  void __RPC_STUB IAgentCtlCharacter_get_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_Visible_Proxy(IAgentCtlCharacter *This,VARIANT_BOOL *Visible);
  void __RPC_STUB IAgentCtlCharacter_get_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_put_Left_Proxy(IAgentCtlCharacter *This,short Left);
  void __RPC_STUB IAgentCtlCharacter_put_Left_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_Left_Proxy(IAgentCtlCharacter *This,short *Left);
  void __RPC_STUB IAgentCtlCharacter_get_Left_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_put_Top_Proxy(IAgentCtlCharacter *This,short Top);
  void __RPC_STUB IAgentCtlCharacter_put_Top_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_Top_Proxy(IAgentCtlCharacter *This,short *Top);
  void __RPC_STUB IAgentCtlCharacter_get_Top_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_put_Height_Proxy(IAgentCtlCharacter *This,short Height);
  void __RPC_STUB IAgentCtlCharacter_put_Height_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_Height_Proxy(IAgentCtlCharacter *This,short *Height);
  void __RPC_STUB IAgentCtlCharacter_get_Height_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_put_Width_Proxy(IAgentCtlCharacter *This,short Width);
  void __RPC_STUB IAgentCtlCharacter_put_Width_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_Width_Proxy(IAgentCtlCharacter *This,short *Width);
  void __RPC_STUB IAgentCtlCharacter_get_Width_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_Speed_Proxy(IAgentCtlCharacter *This,__LONG32 *Speed);
  void __RPC_STUB IAgentCtlCharacter_get_Speed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_Pitch_Proxy(IAgentCtlCharacter *This,__LONG32 *Pitch);
  void __RPC_STUB IAgentCtlCharacter_get_Pitch_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_put_IdleOn_Proxy(IAgentCtlCharacter *This,VARIANT_BOOL On);
  void __RPC_STUB IAgentCtlCharacter_put_IdleOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_IdleOn_Proxy(IAgentCtlCharacter *This,VARIANT_BOOL *On);
  void __RPC_STUB IAgentCtlCharacter_get_IdleOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_Activate_Proxy(IAgentCtlCharacter *This,VARIANT State,VARIANT_BOOL *Success);
  void __RPC_STUB IAgentCtlCharacter_Activate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_Play_Proxy(IAgentCtlCharacter *This,BSTR Animation,IAgentCtlRequest **Request);
  void __RPC_STUB IAgentCtlCharacter_Play_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_Get_Proxy(IAgentCtlCharacter *This,BSTR Type,BSTR Name,VARIANT Queue,IAgentCtlRequest **Request);
  void __RPC_STUB IAgentCtlCharacter_Get_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_Stop_Proxy(IAgentCtlCharacter *This,VARIANT Request);
  void __RPC_STUB IAgentCtlCharacter_Stop_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_Wait_Proxy(IAgentCtlCharacter *This,IDispatch *WaitForRequest,IAgentCtlRequest **Request);
  void __RPC_STUB IAgentCtlCharacter_Wait_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_Interrupt_Proxy(IAgentCtlCharacter *This,IDispatch *InterruptRequest,IAgentCtlRequest **Request);
  void __RPC_STUB IAgentCtlCharacter_Interrupt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_Speak_Proxy(IAgentCtlCharacter *This,VARIANT Text,VARIANT Url,IAgentCtlRequest **Request);
  void __RPC_STUB IAgentCtlCharacter_Speak_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_GestureAt_Proxy(IAgentCtlCharacter *This,short x,short y,IAgentCtlRequest **Request);
  void __RPC_STUB IAgentCtlCharacter_GestureAt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_MoveTo_Proxy(IAgentCtlCharacter *This,short x,short y,VARIANT Speed,IAgentCtlRequest **Request);
  void __RPC_STUB IAgentCtlCharacter_MoveTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_Hide_Proxy(IAgentCtlCharacter *This,VARIANT Fast,IAgentCtlRequest **Request);
  void __RPC_STUB IAgentCtlCharacter_Hide_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_Show_Proxy(IAgentCtlCharacter *This,VARIANT Fast,IAgentCtlRequest **Request);
  void __RPC_STUB IAgentCtlCharacter_Show_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_StopAll_Proxy(IAgentCtlCharacter *This,VARIANT Types);
  void __RPC_STUB IAgentCtlCharacter_StopAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_MoveCause_Proxy(IAgentCtlCharacter *This,short *MoveCause);
  void __RPC_STUB IAgentCtlCharacter_get_MoveCause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_VisibilityCause_Proxy(IAgentCtlCharacter *This,short *VisibilityCause);
  void __RPC_STUB IAgentCtlCharacter_get_VisibilityCause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_HasOtherClients_Proxy(IAgentCtlCharacter *This,VARIANT_BOOL *HasOtherClients);
  void __RPC_STUB IAgentCtlCharacter_get_HasOtherClients_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_put_SoundEffectsOn_Proxy(IAgentCtlCharacter *This,VARIANT_BOOL On);
  void __RPC_STUB IAgentCtlCharacter_put_SoundEffectsOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_SoundEffectsOn_Proxy(IAgentCtlCharacter *This,VARIANT_BOOL *On);
  void __RPC_STUB IAgentCtlCharacter_get_SoundEffectsOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_put_Name_Proxy(IAgentCtlCharacter *This,BSTR Name);
  void __RPC_STUB IAgentCtlCharacter_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_put_Description_Proxy(IAgentCtlCharacter *This,BSTR Description);
  void __RPC_STUB IAgentCtlCharacter_put_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacter_get_ExtraData_Proxy(IAgentCtlCharacter *This,BSTR *ExtraData);
  void __RPC_STUB IAgentCtlCharacter_get_ExtraData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlAnimationNames_INTERFACE_DEFINED__
#define __IAgentCtlAnimationNames_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlAnimationNames;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlAnimationNames : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Enum(IUnknown **ppunkEnum) = 0;
  };
#else
  typedef struct IAgentCtlAnimationNamesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlAnimationNames *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlAnimationNames *This);
      ULONG (WINAPI *Release)(IAgentCtlAnimationNames *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlAnimationNames *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlAnimationNames *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlAnimationNames *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlAnimationNames *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Enum)(IAgentCtlAnimationNames *This,IUnknown **ppunkEnum);
    END_INTERFACE
  } IAgentCtlAnimationNamesVtbl;
  struct IAgentCtlAnimationNames {
    CONST_VTBL struct IAgentCtlAnimationNamesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlAnimationNames_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlAnimationNames_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlAnimationNames_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlAnimationNames_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlAnimationNames_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlAnimationNames_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlAnimationNames_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlAnimationNames_get_Enum(This,ppunkEnum) (This)->lpVtbl->get_Enum(This,ppunkEnum)
#endif
#endif
  HRESULT WINAPI IAgentCtlAnimationNames_get_Enum_Proxy(IAgentCtlAnimationNames *This,IUnknown **ppunkEnum);
  void __RPC_STUB IAgentCtlAnimationNames_get_Enum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlCharacterEx_INTERFACE_DEFINED__
#define __IAgentCtlCharacterEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlCharacterEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlCharacterEx : public IAgentCtlCharacter {
  public:
    virtual HRESULT WINAPI ShowPopupMenu(short x,short y,VARIANT_BOOL *Showed) = 0;
    virtual HRESULT WINAPI put_AutoPopupMenu(VARIANT_BOOL On) = 0;
    virtual HRESULT WINAPI get_AutoPopupMenu(VARIANT_BOOL *On) = 0;
    virtual HRESULT WINAPI put_HelpModeOn(VARIANT_BOOL On) = 0;
    virtual HRESULT WINAPI get_HelpModeOn(VARIANT_BOOL *On) = 0;
    virtual HRESULT WINAPI put_HelpContextID(__LONG32 ID) = 0;
    virtual HRESULT WINAPI get_HelpContextID(__LONG32 *ID) = 0;
    virtual HRESULT WINAPI get_Active(short *State) = 0;
    virtual HRESULT WINAPI Listen(VARIANT_BOOL Listen,VARIANT_BOOL *StartedListening) = 0;
    virtual HRESULT WINAPI put_LanguageID(__LONG32 LanguageID) = 0;
    virtual HRESULT WINAPI get_LanguageID(__LONG32 *LanguageID) = 0;
    virtual HRESULT WINAPI get_SRModeID(BSTR *EngineModeId) = 0;
    virtual HRESULT WINAPI put_SRModeID(BSTR EngineModeId) = 0;
    virtual HRESULT WINAPI get_TTSModeID(BSTR *EngineModeId) = 0;
    virtual HRESULT WINAPI put_TTSModeID(BSTR EngineModeId) = 0;
    virtual HRESULT WINAPI get_HelpFile(BSTR *File) = 0;
    virtual HRESULT WINAPI put_HelpFile(BSTR File) = 0;
    virtual HRESULT WINAPI get_GUID(BSTR *GUID) = 0;
    virtual HRESULT WINAPI get_OriginalHeight(short *Height) = 0;
    virtual HRESULT WINAPI get_OriginalWidth(short *Width) = 0;
    virtual HRESULT WINAPI Think(BSTR Text,IAgentCtlRequest **Request) = 0;
    virtual HRESULT WINAPI get_Version(BSTR *Version) = 0;
    virtual HRESULT WINAPI get_AnimationNames(IAgentCtlAnimationNames **Names) = 0;
    virtual HRESULT WINAPI get_SRStatus(__LONG32 *Status) = 0;
  };
#else
  typedef struct IAgentCtlCharacterExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlCharacterEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlCharacterEx *This);
      ULONG (WINAPI *Release)(IAgentCtlCharacterEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlCharacterEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlCharacterEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlCharacterEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlCharacterEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Balloon)(IAgentCtlCharacterEx *This,IAgentCtlBalloonEx **ppidBalloon);
      HRESULT (WINAPI *get_Commands)(IAgentCtlCharacterEx *This,IAgentCtlCommandsEx **ppidCommands);
      HRESULT (WINAPI *get_Name)(IAgentCtlCharacterEx *This,BSTR *Name);
      HRESULT (WINAPI *get_Description)(IAgentCtlCharacterEx *This,BSTR *Description);
      HRESULT (WINAPI *get_Visible)(IAgentCtlCharacterEx *This,VARIANT_BOOL *Visible);
      HRESULT (WINAPI *put_Left)(IAgentCtlCharacterEx *This,short Left);
      HRESULT (WINAPI *get_Left)(IAgentCtlCharacterEx *This,short *Left);
      HRESULT (WINAPI *put_Top)(IAgentCtlCharacterEx *This,short Top);
      HRESULT (WINAPI *get_Top)(IAgentCtlCharacterEx *This,short *Top);
      HRESULT (WINAPI *put_Height)(IAgentCtlCharacterEx *This,short Height);
      HRESULT (WINAPI *get_Height)(IAgentCtlCharacterEx *This,short *Height);
      HRESULT (WINAPI *put_Width)(IAgentCtlCharacterEx *This,short Width);
      HRESULT (WINAPI *get_Width)(IAgentCtlCharacterEx *This,short *Width);
      HRESULT (WINAPI *get_Speed)(IAgentCtlCharacterEx *This,__LONG32 *Speed);
      HRESULT (WINAPI *get_Pitch)(IAgentCtlCharacterEx *This,__LONG32 *Pitch);
      HRESULT (WINAPI *put_IdleOn)(IAgentCtlCharacterEx *This,VARIANT_BOOL On);
      HRESULT (WINAPI *get_IdleOn)(IAgentCtlCharacterEx *This,VARIANT_BOOL *On);
      HRESULT (WINAPI *Activate)(IAgentCtlCharacterEx *This,VARIANT State,VARIANT_BOOL *Success);
      HRESULT (WINAPI *Play)(IAgentCtlCharacterEx *This,BSTR Animation,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Get)(IAgentCtlCharacterEx *This,BSTR Type,BSTR Name,VARIANT Queue,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Stop)(IAgentCtlCharacterEx *This,VARIANT Request);
      HRESULT (WINAPI *Wait)(IAgentCtlCharacterEx *This,IDispatch *WaitForRequest,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Interrupt)(IAgentCtlCharacterEx *This,IDispatch *InterruptRequest,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Speak)(IAgentCtlCharacterEx *This,VARIANT Text,VARIANT Url,IAgentCtlRequest **Request);
      HRESULT (WINAPI *GestureAt)(IAgentCtlCharacterEx *This,short x,short y,IAgentCtlRequest **Request);
      HRESULT (WINAPI *MoveTo)(IAgentCtlCharacterEx *This,short x,short y,VARIANT Speed,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Hide)(IAgentCtlCharacterEx *This,VARIANT Fast,IAgentCtlRequest **Request);
      HRESULT (WINAPI *Show)(IAgentCtlCharacterEx *This,VARIANT Fast,IAgentCtlRequest **Request);
      HRESULT (WINAPI *StopAll)(IAgentCtlCharacterEx *This,VARIANT Types);
      HRESULT (WINAPI *get_MoveCause)(IAgentCtlCharacterEx *This,short *MoveCause);
      HRESULT (WINAPI *get_VisibilityCause)(IAgentCtlCharacterEx *This,short *VisibilityCause);
      HRESULT (WINAPI *get_HasOtherClients)(IAgentCtlCharacterEx *This,VARIANT_BOOL *HasOtherClients);
      HRESULT (WINAPI *put_SoundEffectsOn)(IAgentCtlCharacterEx *This,VARIANT_BOOL On);
      HRESULT (WINAPI *get_SoundEffectsOn)(IAgentCtlCharacterEx *This,VARIANT_BOOL *On);
      HRESULT (WINAPI *put_Name)(IAgentCtlCharacterEx *This,BSTR Name);
      HRESULT (WINAPI *put_Description)(IAgentCtlCharacterEx *This,BSTR Description);
      HRESULT (WINAPI *get_ExtraData)(IAgentCtlCharacterEx *This,BSTR *ExtraData);
      HRESULT (WINAPI *ShowPopupMenu)(IAgentCtlCharacterEx *This,short x,short y,VARIANT_BOOL *Showed);
      HRESULT (WINAPI *put_AutoPopupMenu)(IAgentCtlCharacterEx *This,VARIANT_BOOL On);
      HRESULT (WINAPI *get_AutoPopupMenu)(IAgentCtlCharacterEx *This,VARIANT_BOOL *On);
      HRESULT (WINAPI *put_HelpModeOn)(IAgentCtlCharacterEx *This,VARIANT_BOOL On);
      HRESULT (WINAPI *get_HelpModeOn)(IAgentCtlCharacterEx *This,VARIANT_BOOL *On);
      HRESULT (WINAPI *put_HelpContextID)(IAgentCtlCharacterEx *This,__LONG32 ID);
      HRESULT (WINAPI *get_HelpContextID)(IAgentCtlCharacterEx *This,__LONG32 *ID);
      HRESULT (WINAPI *get_Active)(IAgentCtlCharacterEx *This,short *State);
      HRESULT (WINAPI *Listen)(IAgentCtlCharacterEx *This,VARIANT_BOOL Listen,VARIANT_BOOL *StartedListening);
      HRESULT (WINAPI *put_LanguageID)(IAgentCtlCharacterEx *This,__LONG32 LanguageID);
      HRESULT (WINAPI *get_LanguageID)(IAgentCtlCharacterEx *This,__LONG32 *LanguageID);
      HRESULT (WINAPI *get_SRModeID)(IAgentCtlCharacterEx *This,BSTR *EngineModeId);
      HRESULT (WINAPI *put_SRModeID)(IAgentCtlCharacterEx *This,BSTR EngineModeId);
      HRESULT (WINAPI *get_TTSModeID)(IAgentCtlCharacterEx *This,BSTR *EngineModeId);
      HRESULT (WINAPI *put_TTSModeID)(IAgentCtlCharacterEx *This,BSTR EngineModeId);
      HRESULT (WINAPI *get_HelpFile)(IAgentCtlCharacterEx *This,BSTR *File);
      HRESULT (WINAPI *put_HelpFile)(IAgentCtlCharacterEx *This,BSTR File);
      HRESULT (WINAPI *get_GUID)(IAgentCtlCharacterEx *This,BSTR *GUID);
      HRESULT (WINAPI *get_OriginalHeight)(IAgentCtlCharacterEx *This,short *Height);
      HRESULT (WINAPI *get_OriginalWidth)(IAgentCtlCharacterEx *This,short *Width);
      HRESULT (WINAPI *Think)(IAgentCtlCharacterEx *This,BSTR Text,IAgentCtlRequest **Request);
      HRESULT (WINAPI *get_Version)(IAgentCtlCharacterEx *This,BSTR *Version);
      HRESULT (WINAPI *get_AnimationNames)(IAgentCtlCharacterEx *This,IAgentCtlAnimationNames **Names);
      HRESULT (WINAPI *get_SRStatus)(IAgentCtlCharacterEx *This,__LONG32 *Status);
    END_INTERFACE
  } IAgentCtlCharacterExVtbl;
  struct IAgentCtlCharacterEx {
    CONST_VTBL struct IAgentCtlCharacterExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlCharacterEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlCharacterEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlCharacterEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlCharacterEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlCharacterEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlCharacterEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlCharacterEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlCharacterEx_get_Balloon(This,ppidBalloon) (This)->lpVtbl->get_Balloon(This,ppidBalloon)
#define IAgentCtlCharacterEx_get_Commands(This,ppidCommands) (This)->lpVtbl->get_Commands(This,ppidCommands)
#define IAgentCtlCharacterEx_get_Name(This,Name) (This)->lpVtbl->get_Name(This,Name)
#define IAgentCtlCharacterEx_get_Description(This,Description) (This)->lpVtbl->get_Description(This,Description)
#define IAgentCtlCharacterEx_get_Visible(This,Visible) (This)->lpVtbl->get_Visible(This,Visible)
#define IAgentCtlCharacterEx_put_Left(This,Left) (This)->lpVtbl->put_Left(This,Left)
#define IAgentCtlCharacterEx_get_Left(This,Left) (This)->lpVtbl->get_Left(This,Left)
#define IAgentCtlCharacterEx_put_Top(This,Top) (This)->lpVtbl->put_Top(This,Top)
#define IAgentCtlCharacterEx_get_Top(This,Top) (This)->lpVtbl->get_Top(This,Top)
#define IAgentCtlCharacterEx_put_Height(This,Height) (This)->lpVtbl->put_Height(This,Height)
#define IAgentCtlCharacterEx_get_Height(This,Height) (This)->lpVtbl->get_Height(This,Height)
#define IAgentCtlCharacterEx_put_Width(This,Width) (This)->lpVtbl->put_Width(This,Width)
#define IAgentCtlCharacterEx_get_Width(This,Width) (This)->lpVtbl->get_Width(This,Width)
#define IAgentCtlCharacterEx_get_Speed(This,Speed) (This)->lpVtbl->get_Speed(This,Speed)
#define IAgentCtlCharacterEx_get_Pitch(This,Pitch) (This)->lpVtbl->get_Pitch(This,Pitch)
#define IAgentCtlCharacterEx_put_IdleOn(This,On) (This)->lpVtbl->put_IdleOn(This,On)
#define IAgentCtlCharacterEx_get_IdleOn(This,On) (This)->lpVtbl->get_IdleOn(This,On)
#define IAgentCtlCharacterEx_Activate(This,State,Success) (This)->lpVtbl->Activate(This,State,Success)
#define IAgentCtlCharacterEx_Play(This,Animation,Request) (This)->lpVtbl->Play(This,Animation,Request)
#define IAgentCtlCharacterEx_Get(This,Type,Name,Queue,Request) (This)->lpVtbl->Get(This,Type,Name,Queue,Request)
#define IAgentCtlCharacterEx_Stop(This,Request) (This)->lpVtbl->Stop(This,Request)
#define IAgentCtlCharacterEx_Wait(This,WaitForRequest,Request) (This)->lpVtbl->Wait(This,WaitForRequest,Request)
#define IAgentCtlCharacterEx_Interrupt(This,InterruptRequest,Request) (This)->lpVtbl->Interrupt(This,InterruptRequest,Request)
#define IAgentCtlCharacterEx_Speak(This,Text,Url,Request) (This)->lpVtbl->Speak(This,Text,Url,Request)
#define IAgentCtlCharacterEx_GestureAt(This,x,y,Request) (This)->lpVtbl->GestureAt(This,x,y,Request)
#define IAgentCtlCharacterEx_MoveTo(This,x,y,Speed,Request) (This)->lpVtbl->MoveTo(This,x,y,Speed,Request)
#define IAgentCtlCharacterEx_Hide(This,Fast,Request) (This)->lpVtbl->Hide(This,Fast,Request)
#define IAgentCtlCharacterEx_Show(This,Fast,Request) (This)->lpVtbl->Show(This,Fast,Request)
#define IAgentCtlCharacterEx_StopAll(This,Types) (This)->lpVtbl->StopAll(This,Types)
#define IAgentCtlCharacterEx_get_MoveCause(This,MoveCause) (This)->lpVtbl->get_MoveCause(This,MoveCause)
#define IAgentCtlCharacterEx_get_VisibilityCause(This,VisibilityCause) (This)->lpVtbl->get_VisibilityCause(This,VisibilityCause)
#define IAgentCtlCharacterEx_get_HasOtherClients(This,HasOtherClients) (This)->lpVtbl->get_HasOtherClients(This,HasOtherClients)
#define IAgentCtlCharacterEx_put_SoundEffectsOn(This,On) (This)->lpVtbl->put_SoundEffectsOn(This,On)
#define IAgentCtlCharacterEx_get_SoundEffectsOn(This,On) (This)->lpVtbl->get_SoundEffectsOn(This,On)
#define IAgentCtlCharacterEx_put_Name(This,Name) (This)->lpVtbl->put_Name(This,Name)
#define IAgentCtlCharacterEx_put_Description(This,Description) (This)->lpVtbl->put_Description(This,Description)
#define IAgentCtlCharacterEx_get_ExtraData(This,ExtraData) (This)->lpVtbl->get_ExtraData(This,ExtraData)
#define IAgentCtlCharacterEx_ShowPopupMenu(This,x,y,Showed) (This)->lpVtbl->ShowPopupMenu(This,x,y,Showed)
#define IAgentCtlCharacterEx_put_AutoPopupMenu(This,On) (This)->lpVtbl->put_AutoPopupMenu(This,On)
#define IAgentCtlCharacterEx_get_AutoPopupMenu(This,On) (This)->lpVtbl->get_AutoPopupMenu(This,On)
#define IAgentCtlCharacterEx_put_HelpModeOn(This,On) (This)->lpVtbl->put_HelpModeOn(This,On)
#define IAgentCtlCharacterEx_get_HelpModeOn(This,On) (This)->lpVtbl->get_HelpModeOn(This,On)
#define IAgentCtlCharacterEx_put_HelpContextID(This,ID) (This)->lpVtbl->put_HelpContextID(This,ID)
#define IAgentCtlCharacterEx_get_HelpContextID(This,ID) (This)->lpVtbl->get_HelpContextID(This,ID)
#define IAgentCtlCharacterEx_get_Active(This,State) (This)->lpVtbl->get_Active(This,State)
#define IAgentCtlCharacterEx_Listen(This,Listen,StartedListening) (This)->lpVtbl->Listen(This,Listen,StartedListening)
#define IAgentCtlCharacterEx_put_LanguageID(This,LanguageID) (This)->lpVtbl->put_LanguageID(This,LanguageID)
#define IAgentCtlCharacterEx_get_LanguageID(This,LanguageID) (This)->lpVtbl->get_LanguageID(This,LanguageID)
#define IAgentCtlCharacterEx_get_SRModeID(This,EngineModeId) (This)->lpVtbl->get_SRModeID(This,EngineModeId)
#define IAgentCtlCharacterEx_put_SRModeID(This,EngineModeId) (This)->lpVtbl->put_SRModeID(This,EngineModeId)
#define IAgentCtlCharacterEx_get_TTSModeID(This,EngineModeId) (This)->lpVtbl->get_TTSModeID(This,EngineModeId)
#define IAgentCtlCharacterEx_put_TTSModeID(This,EngineModeId) (This)->lpVtbl->put_TTSModeID(This,EngineModeId)
#define IAgentCtlCharacterEx_get_HelpFile(This,File) (This)->lpVtbl->get_HelpFile(This,File)
#define IAgentCtlCharacterEx_put_HelpFile(This,File) (This)->lpVtbl->put_HelpFile(This,File)
#define IAgentCtlCharacterEx_get_GUID(This,GUID) (This)->lpVtbl->get_GUID(This,GUID)
#define IAgentCtlCharacterEx_get_OriginalHeight(This,Height) (This)->lpVtbl->get_OriginalHeight(This,Height)
#define IAgentCtlCharacterEx_get_OriginalWidth(This,Width) (This)->lpVtbl->get_OriginalWidth(This,Width)
#define IAgentCtlCharacterEx_Think(This,Text,Request) (This)->lpVtbl->Think(This,Text,Request)
#define IAgentCtlCharacterEx_get_Version(This,Version) (This)->lpVtbl->get_Version(This,Version)
#define IAgentCtlCharacterEx_get_AnimationNames(This,Names) (This)->lpVtbl->get_AnimationNames(This,Names)
#define IAgentCtlCharacterEx_get_SRStatus(This,Status) (This)->lpVtbl->get_SRStatus(This,Status)
#endif
#endif
  HRESULT WINAPI IAgentCtlCharacterEx_ShowPopupMenu_Proxy(IAgentCtlCharacterEx *This,short x,short y,VARIANT_BOOL *Showed);
  void __RPC_STUB IAgentCtlCharacterEx_ShowPopupMenu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_put_AutoPopupMenu_Proxy(IAgentCtlCharacterEx *This,VARIANT_BOOL On);
  void __RPC_STUB IAgentCtlCharacterEx_put_AutoPopupMenu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_AutoPopupMenu_Proxy(IAgentCtlCharacterEx *This,VARIANT_BOOL *On);
  void __RPC_STUB IAgentCtlCharacterEx_get_AutoPopupMenu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_put_HelpModeOn_Proxy(IAgentCtlCharacterEx *This,VARIANT_BOOL On);
  void __RPC_STUB IAgentCtlCharacterEx_put_HelpModeOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_HelpModeOn_Proxy(IAgentCtlCharacterEx *This,VARIANT_BOOL *On);
  void __RPC_STUB IAgentCtlCharacterEx_get_HelpModeOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_put_HelpContextID_Proxy(IAgentCtlCharacterEx *This,__LONG32 ID);
  void __RPC_STUB IAgentCtlCharacterEx_put_HelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_HelpContextID_Proxy(IAgentCtlCharacterEx *This,__LONG32 *ID);
  void __RPC_STUB IAgentCtlCharacterEx_get_HelpContextID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_Active_Proxy(IAgentCtlCharacterEx *This,short *State);
  void __RPC_STUB IAgentCtlCharacterEx_get_Active_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_Listen_Proxy(IAgentCtlCharacterEx *This,VARIANT_BOOL Listen,VARIANT_BOOL *StartedListening);
  void __RPC_STUB IAgentCtlCharacterEx_Listen_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_put_LanguageID_Proxy(IAgentCtlCharacterEx *This,__LONG32 LanguageID);
  void __RPC_STUB IAgentCtlCharacterEx_put_LanguageID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_LanguageID_Proxy(IAgentCtlCharacterEx *This,__LONG32 *LanguageID);
  void __RPC_STUB IAgentCtlCharacterEx_get_LanguageID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_SRModeID_Proxy(IAgentCtlCharacterEx *This,BSTR *EngineModeId);
  void __RPC_STUB IAgentCtlCharacterEx_get_SRModeID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_put_SRModeID_Proxy(IAgentCtlCharacterEx *This,BSTR EngineModeId);
  void __RPC_STUB IAgentCtlCharacterEx_put_SRModeID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_TTSModeID_Proxy(IAgentCtlCharacterEx *This,BSTR *EngineModeId);
  void __RPC_STUB IAgentCtlCharacterEx_get_TTSModeID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_put_TTSModeID_Proxy(IAgentCtlCharacterEx *This,BSTR EngineModeId);
  void __RPC_STUB IAgentCtlCharacterEx_put_TTSModeID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_HelpFile_Proxy(IAgentCtlCharacterEx *This,BSTR *File);
  void __RPC_STUB IAgentCtlCharacterEx_get_HelpFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_put_HelpFile_Proxy(IAgentCtlCharacterEx *This,BSTR File);
  void __RPC_STUB IAgentCtlCharacterEx_put_HelpFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_GUID_Proxy(IAgentCtlCharacterEx *This,BSTR *GUID);
  void __RPC_STUB IAgentCtlCharacterEx_get_GUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_OriginalHeight_Proxy(IAgentCtlCharacterEx *This,short *Height);
  void __RPC_STUB IAgentCtlCharacterEx_get_OriginalHeight_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_OriginalWidth_Proxy(IAgentCtlCharacterEx *This,short *Width);
  void __RPC_STUB IAgentCtlCharacterEx_get_OriginalWidth_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_Think_Proxy(IAgentCtlCharacterEx *This,BSTR Text,IAgentCtlRequest **Request);
  void __RPC_STUB IAgentCtlCharacterEx_Think_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_Version_Proxy(IAgentCtlCharacterEx *This,BSTR *Version);
  void __RPC_STUB IAgentCtlCharacterEx_get_Version_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_AnimationNames_Proxy(IAgentCtlCharacterEx *This,IAgentCtlAnimationNames **Names);
  void __RPC_STUB IAgentCtlCharacterEx_get_AnimationNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacterEx_get_SRStatus_Proxy(IAgentCtlCharacterEx *This,__LONG32 *Status);
  void __RPC_STUB IAgentCtlCharacterEx_get_SRStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlCharacters_INTERFACE_DEFINED__
#define __IAgentCtlCharacters_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlCharacters;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlCharacters : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(BSTR CharacterID,IAgentCtlCharacterEx **ppidItem) = 0;
    virtual HRESULT WINAPI Character(BSTR CharacterID,IAgentCtlCharacterEx **ppidItem) = 0;
    virtual HRESULT WINAPI get_Enum(IUnknown **ppunkEnum) = 0;
    virtual HRESULT WINAPI Unload(BSTR CharacterID) = 0;
    virtual HRESULT WINAPI Load(BSTR CharacterID,VARIANT LoadKey,IAgentCtlRequest **ppidRequest) = 0;
  };
#else
  typedef struct IAgentCtlCharactersVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlCharacters *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlCharacters *This);
      ULONG (WINAPI *Release)(IAgentCtlCharacters *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlCharacters *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlCharacters *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlCharacters *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlCharacters *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IAgentCtlCharacters *This,BSTR CharacterID,IAgentCtlCharacterEx **ppidItem);
      HRESULT (WINAPI *Character)(IAgentCtlCharacters *This,BSTR CharacterID,IAgentCtlCharacterEx **ppidItem);
      HRESULT (WINAPI *get_Enum)(IAgentCtlCharacters *This,IUnknown **ppunkEnum);
      HRESULT (WINAPI *Unload)(IAgentCtlCharacters *This,BSTR CharacterID);
      HRESULT (WINAPI *Load)(IAgentCtlCharacters *This,BSTR CharacterID,VARIANT LoadKey,IAgentCtlRequest **ppidRequest);
    END_INTERFACE
  } IAgentCtlCharactersVtbl;
  struct IAgentCtlCharacters {
    CONST_VTBL struct IAgentCtlCharactersVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlCharacters_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlCharacters_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlCharacters_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlCharacters_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlCharacters_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlCharacters_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlCharacters_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlCharacters_get_Item(This,CharacterID,ppidItem) (This)->lpVtbl->get_Item(This,CharacterID,ppidItem)
#define IAgentCtlCharacters_Character(This,CharacterID,ppidItem) (This)->lpVtbl->Character(This,CharacterID,ppidItem)
#define IAgentCtlCharacters_get_Enum(This,ppunkEnum) (This)->lpVtbl->get_Enum(This,ppunkEnum)
#define IAgentCtlCharacters_Unload(This,CharacterID) (This)->lpVtbl->Unload(This,CharacterID)
#define IAgentCtlCharacters_Load(This,CharacterID,LoadKey,ppidRequest) (This)->lpVtbl->Load(This,CharacterID,LoadKey,ppidRequest)
#endif
#endif
  HRESULT WINAPI IAgentCtlCharacters_get_Item_Proxy(IAgentCtlCharacters *This,BSTR CharacterID,IAgentCtlCharacterEx **ppidItem);
  void __RPC_STUB IAgentCtlCharacters_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacters_Character_Proxy(IAgentCtlCharacters *This,BSTR CharacterID,IAgentCtlCharacterEx **ppidItem);
  void __RPC_STUB IAgentCtlCharacters_Character_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacters_get_Enum_Proxy(IAgentCtlCharacters *This,IUnknown **ppunkEnum);
  void __RPC_STUB IAgentCtlCharacters_get_Enum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacters_Unload_Proxy(IAgentCtlCharacters *This,BSTR CharacterID);
  void __RPC_STUB IAgentCtlCharacters_Unload_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCharacters_Load_Proxy(IAgentCtlCharacters *This,BSTR CharacterID,VARIANT LoadKey,IAgentCtlRequest **ppidRequest);
  void __RPC_STUB IAgentCtlCharacters_Load_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlAudioObject_INTERFACE_DEFINED__
#define __IAgentCtlAudioObject_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlAudioObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlAudioObject : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Enabled(VARIANT_BOOL *AudioEnabled) = 0;
    virtual HRESULT WINAPI get_SoundEffects(VARIANT_BOOL *SoundEffects) = 0;
  };
#else
  typedef struct IAgentCtlAudioObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlAudioObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlAudioObject *This);
      ULONG (WINAPI *Release)(IAgentCtlAudioObject *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlAudioObject *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlAudioObject *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlAudioObject *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlAudioObject *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Enabled)(IAgentCtlAudioObject *This,VARIANT_BOOL *AudioEnabled);
      HRESULT (WINAPI *get_SoundEffects)(IAgentCtlAudioObject *This,VARIANT_BOOL *SoundEffects);
    END_INTERFACE
  } IAgentCtlAudioObjectVtbl;
  struct IAgentCtlAudioObject {
    CONST_VTBL struct IAgentCtlAudioObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlAudioObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlAudioObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlAudioObject_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlAudioObject_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlAudioObject_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlAudioObject_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlAudioObject_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlAudioObject_get_Enabled(This,AudioEnabled) (This)->lpVtbl->get_Enabled(This,AudioEnabled)
#define IAgentCtlAudioObject_get_SoundEffects(This,SoundEffects) (This)->lpVtbl->get_SoundEffects(This,SoundEffects)
#endif
#endif
  HRESULT WINAPI IAgentCtlAudioObject_get_Enabled_Proxy(IAgentCtlAudioObject *This,VARIANT_BOOL *AudioEnabled);
  void __RPC_STUB IAgentCtlAudioObject_get_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlAudioObject_get_SoundEffects_Proxy(IAgentCtlAudioObject *This,VARIANT_BOOL *SoundEffects);
  void __RPC_STUB IAgentCtlAudioObject_get_SoundEffects_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlAudioObjectEx_INTERFACE_DEFINED__
#define __IAgentCtlAudioObjectEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlAudioObjectEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlAudioObjectEx : public IAgentCtlAudioObject {
  public:
    virtual HRESULT WINAPI get_Status(short *Available) = 0;
  };
#else
  typedef struct IAgentCtlAudioObjectExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlAudioObjectEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlAudioObjectEx *This);
      ULONG (WINAPI *Release)(IAgentCtlAudioObjectEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlAudioObjectEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlAudioObjectEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlAudioObjectEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlAudioObjectEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Enabled)(IAgentCtlAudioObjectEx *This,VARIANT_BOOL *AudioEnabled);
      HRESULT (WINAPI *get_SoundEffects)(IAgentCtlAudioObjectEx *This,VARIANT_BOOL *SoundEffects);
      HRESULT (WINAPI *get_Status)(IAgentCtlAudioObjectEx *This,short *Available);
    END_INTERFACE
  } IAgentCtlAudioObjectExVtbl;
  struct IAgentCtlAudioObjectEx {
    CONST_VTBL struct IAgentCtlAudioObjectExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlAudioObjectEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlAudioObjectEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlAudioObjectEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlAudioObjectEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlAudioObjectEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlAudioObjectEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlAudioObjectEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlAudioObjectEx_get_Enabled(This,AudioEnabled) (This)->lpVtbl->get_Enabled(This,AudioEnabled)
#define IAgentCtlAudioObjectEx_get_SoundEffects(This,SoundEffects) (This)->lpVtbl->get_SoundEffects(This,SoundEffects)
#define IAgentCtlAudioObjectEx_get_Status(This,Available) (This)->lpVtbl->get_Status(This,Available)
#endif
#endif
  HRESULT WINAPI IAgentCtlAudioObjectEx_get_Status_Proxy(IAgentCtlAudioObjectEx *This,short *Available);
  void __RPC_STUB IAgentCtlAudioObjectEx_get_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlSpeechInput_INTERFACE_DEFINED__
#define __IAgentCtlSpeechInput_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlSpeechInput;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlSpeechInput : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Enabled(VARIANT_BOOL *VoiceEnabled) = 0;
    virtual HRESULT WINAPI get_Language(BSTR *Language) = 0;
    virtual HRESULT WINAPI get_HotKey(BSTR *HotKey) = 0;
    virtual HRESULT WINAPI get_Installed(VARIANT_BOOL *VoiceInstalled) = 0;
    virtual HRESULT WINAPI get_Engine(BSTR *Engine) = 0;
    virtual HRESULT WINAPI put_Engine(BSTR Engine) = 0;
    virtual HRESULT WINAPI get_ListeningTip(VARIANT_BOOL *ListeningTip) = 0;
  };
#else
  typedef struct IAgentCtlSpeechInputVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlSpeechInput *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlSpeechInput *This);
      ULONG (WINAPI *Release)(IAgentCtlSpeechInput *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlSpeechInput *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlSpeechInput *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlSpeechInput *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlSpeechInput *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Enabled)(IAgentCtlSpeechInput *This,VARIANT_BOOL *VoiceEnabled);
      HRESULT (WINAPI *get_Language)(IAgentCtlSpeechInput *This,BSTR *Language);
      HRESULT (WINAPI *get_HotKey)(IAgentCtlSpeechInput *This,BSTR *HotKey);
      HRESULT (WINAPI *get_Installed)(IAgentCtlSpeechInput *This,VARIANT_BOOL *VoiceInstalled);
      HRESULT (WINAPI *get_Engine)(IAgentCtlSpeechInput *This,BSTR *Engine);
      HRESULT (WINAPI *put_Engine)(IAgentCtlSpeechInput *This,BSTR Engine);
      HRESULT (WINAPI *get_ListeningTip)(IAgentCtlSpeechInput *This,VARIANT_BOOL *ListeningTip);
    END_INTERFACE
  } IAgentCtlSpeechInputVtbl;
  struct IAgentCtlSpeechInput {
    CONST_VTBL struct IAgentCtlSpeechInputVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlSpeechInput_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlSpeechInput_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlSpeechInput_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlSpeechInput_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlSpeechInput_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlSpeechInput_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlSpeechInput_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlSpeechInput_get_Enabled(This,VoiceEnabled) (This)->lpVtbl->get_Enabled(This,VoiceEnabled)
#define IAgentCtlSpeechInput_get_Language(This,Language) (This)->lpVtbl->get_Language(This,Language)
#define IAgentCtlSpeechInput_get_HotKey(This,HotKey) (This)->lpVtbl->get_HotKey(This,HotKey)
#define IAgentCtlSpeechInput_get_Installed(This,VoiceInstalled) (This)->lpVtbl->get_Installed(This,VoiceInstalled)
#define IAgentCtlSpeechInput_get_Engine(This,Engine) (This)->lpVtbl->get_Engine(This,Engine)
#define IAgentCtlSpeechInput_put_Engine(This,Engine) (This)->lpVtbl->put_Engine(This,Engine)
#define IAgentCtlSpeechInput_get_ListeningTip(This,ListeningTip) (This)->lpVtbl->get_ListeningTip(This,ListeningTip)
#endif
#endif
  HRESULT WINAPI IAgentCtlSpeechInput_get_Enabled_Proxy(IAgentCtlSpeechInput *This,VARIANT_BOOL *VoiceEnabled);
  void __RPC_STUB IAgentCtlSpeechInput_get_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlSpeechInput_get_Language_Proxy(IAgentCtlSpeechInput *This,BSTR *Language);
  void __RPC_STUB IAgentCtlSpeechInput_get_Language_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlSpeechInput_get_HotKey_Proxy(IAgentCtlSpeechInput *This,BSTR *HotKey);
  void __RPC_STUB IAgentCtlSpeechInput_get_HotKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlSpeechInput_get_Installed_Proxy(IAgentCtlSpeechInput *This,VARIANT_BOOL *VoiceInstalled);
  void __RPC_STUB IAgentCtlSpeechInput_get_Installed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlSpeechInput_get_Engine_Proxy(IAgentCtlSpeechInput *This,BSTR *Engine);
  void __RPC_STUB IAgentCtlSpeechInput_get_Engine_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlSpeechInput_put_Engine_Proxy(IAgentCtlSpeechInput *This,BSTR Engine);
  void __RPC_STUB IAgentCtlSpeechInput_put_Engine_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlSpeechInput_get_ListeningTip_Proxy(IAgentCtlSpeechInput *This,VARIANT_BOOL *ListeningTip);
  void __RPC_STUB IAgentCtlSpeechInput_get_ListeningTip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlPropertySheet_INTERFACE_DEFINED__
#define __IAgentCtlPropertySheet_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlPropertySheet;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlPropertySheet : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Left(short *Left) = 0;
    virtual HRESULT WINAPI get_Top(short *Top) = 0;
    virtual HRESULT WINAPI get_Height(short *Height) = 0;
    virtual HRESULT WINAPI get_Width(short *Width) = 0;
    virtual HRESULT WINAPI put_Visible(VARIANT_BOOL Visible) = 0;
    virtual HRESULT WINAPI get_Visible(VARIANT_BOOL *Visible) = 0;
    virtual HRESULT WINAPI put_Page(BSTR Page) = 0;
    virtual HRESULT WINAPI get_Page(BSTR *Page) = 0;
  };
#else
  typedef struct IAgentCtlPropertySheetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlPropertySheet *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlPropertySheet *This);
      ULONG (WINAPI *Release)(IAgentCtlPropertySheet *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlPropertySheet *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlPropertySheet *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlPropertySheet *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlPropertySheet *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Left)(IAgentCtlPropertySheet *This,short *Left);
      HRESULT (WINAPI *get_Top)(IAgentCtlPropertySheet *This,short *Top);
      HRESULT (WINAPI *get_Height)(IAgentCtlPropertySheet *This,short *Height);
      HRESULT (WINAPI *get_Width)(IAgentCtlPropertySheet *This,short *Width);
      HRESULT (WINAPI *put_Visible)(IAgentCtlPropertySheet *This,VARIANT_BOOL Visible);
      HRESULT (WINAPI *get_Visible)(IAgentCtlPropertySheet *This,VARIANT_BOOL *Visible);
      HRESULT (WINAPI *put_Page)(IAgentCtlPropertySheet *This,BSTR Page);
      HRESULT (WINAPI *get_Page)(IAgentCtlPropertySheet *This,BSTR *Page);
    END_INTERFACE
  } IAgentCtlPropertySheetVtbl;
  struct IAgentCtlPropertySheet {
    CONST_VTBL struct IAgentCtlPropertySheetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlPropertySheet_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlPropertySheet_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlPropertySheet_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlPropertySheet_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlPropertySheet_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlPropertySheet_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlPropertySheet_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlPropertySheet_get_Left(This,Left) (This)->lpVtbl->get_Left(This,Left)
#define IAgentCtlPropertySheet_get_Top(This,Top) (This)->lpVtbl->get_Top(This,Top)
#define IAgentCtlPropertySheet_get_Height(This,Height) (This)->lpVtbl->get_Height(This,Height)
#define IAgentCtlPropertySheet_get_Width(This,Width) (This)->lpVtbl->get_Width(This,Width)
#define IAgentCtlPropertySheet_put_Visible(This,Visible) (This)->lpVtbl->put_Visible(This,Visible)
#define IAgentCtlPropertySheet_get_Visible(This,Visible) (This)->lpVtbl->get_Visible(This,Visible)
#define IAgentCtlPropertySheet_put_Page(This,Page) (This)->lpVtbl->put_Page(This,Page)
#define IAgentCtlPropertySheet_get_Page(This,Page) (This)->lpVtbl->get_Page(This,Page)
#endif
#endif
  HRESULT WINAPI IAgentCtlPropertySheet_get_Left_Proxy(IAgentCtlPropertySheet *This,short *Left);
  void __RPC_STUB IAgentCtlPropertySheet_get_Left_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlPropertySheet_get_Top_Proxy(IAgentCtlPropertySheet *This,short *Top);
  void __RPC_STUB IAgentCtlPropertySheet_get_Top_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlPropertySheet_get_Height_Proxy(IAgentCtlPropertySheet *This,short *Height);
  void __RPC_STUB IAgentCtlPropertySheet_get_Height_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlPropertySheet_get_Width_Proxy(IAgentCtlPropertySheet *This,short *Width);
  void __RPC_STUB IAgentCtlPropertySheet_get_Width_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlPropertySheet_put_Visible_Proxy(IAgentCtlPropertySheet *This,VARIANT_BOOL Visible);
  void __RPC_STUB IAgentCtlPropertySheet_put_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlPropertySheet_get_Visible_Proxy(IAgentCtlPropertySheet *This,VARIANT_BOOL *Visible);
  void __RPC_STUB IAgentCtlPropertySheet_get_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlPropertySheet_put_Page_Proxy(IAgentCtlPropertySheet *This,BSTR Page);
  void __RPC_STUB IAgentCtlPropertySheet_put_Page_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlPropertySheet_get_Page_Proxy(IAgentCtlPropertySheet *This,BSTR *Page);
  void __RPC_STUB IAgentCtlPropertySheet_get_Page_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlCommandsWindow_INTERFACE_DEFINED__
#define __IAgentCtlCommandsWindow_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlCommandsWindow;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlCommandsWindow : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Visible(VARIANT_BOOL *Visible) = 0;
    virtual HRESULT WINAPI put_Visible(VARIANT_BOOL Visible) = 0;
    virtual HRESULT WINAPI get_Left(short *Left) = 0;
    virtual HRESULT WINAPI get_Top(short *Top) = 0;
    virtual HRESULT WINAPI get_Height(short *Height) = 0;
    virtual HRESULT WINAPI get_Width(short *Width) = 0;
  };
#else
  typedef struct IAgentCtlCommandsWindowVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlCommandsWindow *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlCommandsWindow *This);
      ULONG (WINAPI *Release)(IAgentCtlCommandsWindow *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlCommandsWindow *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlCommandsWindow *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlCommandsWindow *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlCommandsWindow *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Visible)(IAgentCtlCommandsWindow *This,VARIANT_BOOL *Visible);
      HRESULT (WINAPI *put_Visible)(IAgentCtlCommandsWindow *This,VARIANT_BOOL Visible);
      HRESULT (WINAPI *get_Left)(IAgentCtlCommandsWindow *This,short *Left);
      HRESULT (WINAPI *get_Top)(IAgentCtlCommandsWindow *This,short *Top);
      HRESULT (WINAPI *get_Height)(IAgentCtlCommandsWindow *This,short *Height);
      HRESULT (WINAPI *get_Width)(IAgentCtlCommandsWindow *This,short *Width);
    END_INTERFACE
  } IAgentCtlCommandsWindowVtbl;
  struct IAgentCtlCommandsWindow {
    CONST_VTBL struct IAgentCtlCommandsWindowVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlCommandsWindow_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlCommandsWindow_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlCommandsWindow_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlCommandsWindow_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlCommandsWindow_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlCommandsWindow_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlCommandsWindow_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlCommandsWindow_get_Visible(This,Visible) (This)->lpVtbl->get_Visible(This,Visible)
#define IAgentCtlCommandsWindow_put_Visible(This,Visible) (This)->lpVtbl->put_Visible(This,Visible)
#define IAgentCtlCommandsWindow_get_Left(This,Left) (This)->lpVtbl->get_Left(This,Left)
#define IAgentCtlCommandsWindow_get_Top(This,Top) (This)->lpVtbl->get_Top(This,Top)
#define IAgentCtlCommandsWindow_get_Height(This,Height) (This)->lpVtbl->get_Height(This,Height)
#define IAgentCtlCommandsWindow_get_Width(This,Width) (This)->lpVtbl->get_Width(This,Width)
#endif
#endif
  HRESULT WINAPI IAgentCtlCommandsWindow_get_Visible_Proxy(IAgentCtlCommandsWindow *This,VARIANT_BOOL *Visible);
  void __RPC_STUB IAgentCtlCommandsWindow_get_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsWindow_put_Visible_Proxy(IAgentCtlCommandsWindow *This,VARIANT_BOOL Visible);
  void __RPC_STUB IAgentCtlCommandsWindow_put_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsWindow_get_Left_Proxy(IAgentCtlCommandsWindow *This,short *Left);
  void __RPC_STUB IAgentCtlCommandsWindow_get_Left_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsWindow_get_Top_Proxy(IAgentCtlCommandsWindow *This,short *Top);
  void __RPC_STUB IAgentCtlCommandsWindow_get_Top_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsWindow_get_Height_Proxy(IAgentCtlCommandsWindow *This,short *Height);
  void __RPC_STUB IAgentCtlCommandsWindow_get_Height_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlCommandsWindow_get_Width_Proxy(IAgentCtlCommandsWindow *This,short *Width);
  void __RPC_STUB IAgentCtlCommandsWindow_get_Width_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtl_INTERFACE_DEFINED__
#define __IAgentCtl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtl : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Characters(IAgentCtlCharacters **Characters) = 0;
    virtual HRESULT WINAPI get_AudioOutput(IAgentCtlAudioObjectEx **AudioOutput) = 0;
    virtual HRESULT WINAPI get_SpeechInput(IAgentCtlSpeechInput **SpeechInput) = 0;
    virtual HRESULT WINAPI get_PropertySheet(IAgentCtlPropertySheet **PropSheet) = 0;
    virtual HRESULT WINAPI get_CommandsWindow(IAgentCtlCommandsWindow **CommandsWindow) = 0;
    virtual HRESULT WINAPI get_Connected(VARIANT_BOOL *Connected) = 0;
    virtual HRESULT WINAPI put_Connected(VARIANT_BOOL Connected) = 0;
    virtual HRESULT WINAPI get_Suspended(VARIANT_BOOL *Suspended) = 0;
  };
#else
  typedef struct IAgentCtlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtl *This);
      ULONG (WINAPI *Release)(IAgentCtl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Characters)(IAgentCtl *This,IAgentCtlCharacters **Characters);
      HRESULT (WINAPI *get_AudioOutput)(IAgentCtl *This,IAgentCtlAudioObjectEx **AudioOutput);
      HRESULT (WINAPI *get_SpeechInput)(IAgentCtl *This,IAgentCtlSpeechInput **SpeechInput);
      HRESULT (WINAPI *get_PropertySheet)(IAgentCtl *This,IAgentCtlPropertySheet **PropSheet);
      HRESULT (WINAPI *get_CommandsWindow)(IAgentCtl *This,IAgentCtlCommandsWindow **CommandsWindow);
      HRESULT (WINAPI *get_Connected)(IAgentCtl *This,VARIANT_BOOL *Connected);
      HRESULT (WINAPI *put_Connected)(IAgentCtl *This,VARIANT_BOOL Connected);
      HRESULT (WINAPI *get_Suspended)(IAgentCtl *This,VARIANT_BOOL *Suspended);
    END_INTERFACE
  } IAgentCtlVtbl;
  struct IAgentCtl {
    CONST_VTBL struct IAgentCtlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtl_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtl_get_Characters(This,Characters) (This)->lpVtbl->get_Characters(This,Characters)
#define IAgentCtl_get_AudioOutput(This,AudioOutput) (This)->lpVtbl->get_AudioOutput(This,AudioOutput)
#define IAgentCtl_get_SpeechInput(This,SpeechInput) (This)->lpVtbl->get_SpeechInput(This,SpeechInput)
#define IAgentCtl_get_PropertySheet(This,PropSheet) (This)->lpVtbl->get_PropertySheet(This,PropSheet)
#define IAgentCtl_get_CommandsWindow(This,CommandsWindow) (This)->lpVtbl->get_CommandsWindow(This,CommandsWindow)
#define IAgentCtl_get_Connected(This,Connected) (This)->lpVtbl->get_Connected(This,Connected)
#define IAgentCtl_put_Connected(This,Connected) (This)->lpVtbl->put_Connected(This,Connected)
#define IAgentCtl_get_Suspended(This,Suspended) (This)->lpVtbl->get_Suspended(This,Suspended)
#endif
#endif
  HRESULT WINAPI IAgentCtl_get_Characters_Proxy(IAgentCtl *This,IAgentCtlCharacters **Characters);
  void __RPC_STUB IAgentCtl_get_Characters_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtl_get_AudioOutput_Proxy(IAgentCtl *This,IAgentCtlAudioObjectEx **AudioOutput);
  void __RPC_STUB IAgentCtl_get_AudioOutput_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtl_get_SpeechInput_Proxy(IAgentCtl *This,IAgentCtlSpeechInput **SpeechInput);
  void __RPC_STUB IAgentCtl_get_SpeechInput_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtl_get_PropertySheet_Proxy(IAgentCtl *This,IAgentCtlPropertySheet **PropSheet);
  void __RPC_STUB IAgentCtl_get_PropertySheet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtl_get_CommandsWindow_Proxy(IAgentCtl *This,IAgentCtlCommandsWindow **CommandsWindow);
  void __RPC_STUB IAgentCtl_get_CommandsWindow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtl_get_Connected_Proxy(IAgentCtl *This,VARIANT_BOOL *Connected);
  void __RPC_STUB IAgentCtl_get_Connected_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtl_put_Connected_Proxy(IAgentCtl *This,VARIANT_BOOL Connected);
  void __RPC_STUB IAgentCtl_put_Connected_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtl_get_Suspended_Proxy(IAgentCtl *This,VARIANT_BOOL *Suspended);
  void __RPC_STUB IAgentCtl_get_Suspended_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAgentCtlEx_INTERFACE_DEFINED__
#define __IAgentCtlEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAgentCtlEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAgentCtlEx : public IAgentCtl {
  public:
    virtual HRESULT WINAPI ShowDefaultCharacterProperties(VARIANT x,VARIANT y) = 0;
    virtual HRESULT WINAPI get_RaiseRequestErrors(VARIANT_BOOL *RaiseErrors) = 0;
    virtual HRESULT WINAPI put_RaiseRequestErrors(VARIANT_BOOL RaiseErrors) = 0;
  };
#else
  typedef struct IAgentCtlExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAgentCtlEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAgentCtlEx *This);
      ULONG (WINAPI *Release)(IAgentCtlEx *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAgentCtlEx *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAgentCtlEx *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAgentCtlEx *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAgentCtlEx *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Characters)(IAgentCtlEx *This,IAgentCtlCharacters **Characters);
      HRESULT (WINAPI *get_AudioOutput)(IAgentCtlEx *This,IAgentCtlAudioObjectEx **AudioOutput);
      HRESULT (WINAPI *get_SpeechInput)(IAgentCtlEx *This,IAgentCtlSpeechInput **SpeechInput);
      HRESULT (WINAPI *get_PropertySheet)(IAgentCtlEx *This,IAgentCtlPropertySheet **PropSheet);
      HRESULT (WINAPI *get_CommandsWindow)(IAgentCtlEx *This,IAgentCtlCommandsWindow **CommandsWindow);
      HRESULT (WINAPI *get_Connected)(IAgentCtlEx *This,VARIANT_BOOL *Connected);
      HRESULT (WINAPI *put_Connected)(IAgentCtlEx *This,VARIANT_BOOL Connected);
      HRESULT (WINAPI *get_Suspended)(IAgentCtlEx *This,VARIANT_BOOL *Suspended);
      HRESULT (WINAPI *ShowDefaultCharacterProperties)(IAgentCtlEx *This,VARIANT x,VARIANT y);
      HRESULT (WINAPI *get_RaiseRequestErrors)(IAgentCtlEx *This,VARIANT_BOOL *RaiseErrors);
      HRESULT (WINAPI *put_RaiseRequestErrors)(IAgentCtlEx *This,VARIANT_BOOL RaiseErrors);
    END_INTERFACE
  } IAgentCtlExVtbl;
  struct IAgentCtlEx {
    CONST_VTBL struct IAgentCtlExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAgentCtlEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAgentCtlEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAgentCtlEx_Release(This) (This)->lpVtbl->Release(This)
#define IAgentCtlEx_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAgentCtlEx_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAgentCtlEx_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAgentCtlEx_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAgentCtlEx_get_Characters(This,Characters) (This)->lpVtbl->get_Characters(This,Characters)
#define IAgentCtlEx_get_AudioOutput(This,AudioOutput) (This)->lpVtbl->get_AudioOutput(This,AudioOutput)
#define IAgentCtlEx_get_SpeechInput(This,SpeechInput) (This)->lpVtbl->get_SpeechInput(This,SpeechInput)
#define IAgentCtlEx_get_PropertySheet(This,PropSheet) (This)->lpVtbl->get_PropertySheet(This,PropSheet)
#define IAgentCtlEx_get_CommandsWindow(This,CommandsWindow) (This)->lpVtbl->get_CommandsWindow(This,CommandsWindow)
#define IAgentCtlEx_get_Connected(This,Connected) (This)->lpVtbl->get_Connected(This,Connected)
#define IAgentCtlEx_put_Connected(This,Connected) (This)->lpVtbl->put_Connected(This,Connected)
#define IAgentCtlEx_get_Suspended(This,Suspended) (This)->lpVtbl->get_Suspended(This,Suspended)
#define IAgentCtlEx_ShowDefaultCharacterProperties(This,x,y) (This)->lpVtbl->ShowDefaultCharacterProperties(This,x,y)
#define IAgentCtlEx_get_RaiseRequestErrors(This,RaiseErrors) (This)->lpVtbl->get_RaiseRequestErrors(This,RaiseErrors)
#define IAgentCtlEx_put_RaiseRequestErrors(This,RaiseErrors) (This)->lpVtbl->put_RaiseRequestErrors(This,RaiseErrors)
#endif
#endif
  HRESULT WINAPI IAgentCtlEx_ShowDefaultCharacterProperties_Proxy(IAgentCtlEx *This,VARIANT x,VARIANT y);
  void __RPC_STUB IAgentCtlEx_ShowDefaultCharacterProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlEx_get_RaiseRequestErrors_Proxy(IAgentCtlEx *This,VARIANT_BOOL *RaiseErrors);
  void __RPC_STUB IAgentCtlEx_get_RaiseRequestErrors_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAgentCtlEx_put_RaiseRequestErrors_Proxy(IAgentCtlEx *This,VARIANT_BOOL RaiseErrors);
  void __RPC_STUB IAgentCtlEx_put_RaiseRequestErrors_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define CONTROL_MAJOR_VERSION (2)
#define CONTROL_MINOR_VERSION (0)

  extern RPC_IF_HANDLE __MIDL_itf_AgentControl_0227_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_AgentControl_0227_v0_0_s_ifspec;

#ifndef __AgentObjects_LIBRARY_DEFINED__
#define __AgentObjects_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_AgentObjects;

#ifndef ___AgentEvents_DISPINTERFACE_DEFINED__
#define ___AgentEvents_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID__AgentEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct _AgentEvents : public IDispatch {
  };
#else
  typedef struct _AgentEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(_AgentEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(_AgentEvents *This);
      ULONG (WINAPI *Release)(_AgentEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(_AgentEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(_AgentEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(_AgentEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(_AgentEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } _AgentEventsVtbl;
  struct _AgentEvents {
    CONST_VTBL struct _AgentEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _AgentEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define _AgentEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define _AgentEvents_Release(This) (This)->lpVtbl->Release(This)
#define _AgentEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define _AgentEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define _AgentEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define _AgentEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

  EXTERN_C const CLSID CLSID_Agent;
#ifdef __cplusplus
  class Agent;
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
