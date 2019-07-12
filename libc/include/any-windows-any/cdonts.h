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

#ifndef __cdonts_h__
#define __cdonts_h__

#ifndef __INewMail_FWD_DEFINED__
#define __INewMail_FWD_DEFINED__
typedef struct INewMail INewMail;
#endif

#ifndef __ISession_FWD_DEFINED__
#define __ISession_FWD_DEFINED__
typedef struct ISession ISession;
#endif

#ifndef __Folder_FWD_DEFINED__
#define __Folder_FWD_DEFINED__
typedef struct Folder Folder;
#endif

#ifndef __Messages_FWD_DEFINED__
#define __Messages_FWD_DEFINED__
typedef struct Messages Messages;
#endif

#ifndef __Message_FWD_DEFINED__
#define __Message_FWD_DEFINED__
typedef struct Message Message;
#endif

#ifndef __Recipients_FWD_DEFINED__
#define __Recipients_FWD_DEFINED__
typedef struct Recipients Recipients;
#endif

#ifndef __Recipient_FWD_DEFINED__
#define __Recipient_FWD_DEFINED__
typedef struct Recipient Recipient;
#endif

#ifndef __Attachments_FWD_DEFINED__
#define __Attachments_FWD_DEFINED__
typedef struct Attachments Attachments;
#endif

#ifndef __Attachment_FWD_DEFINED__
#define __Attachment_FWD_DEFINED__
typedef struct Attachment Attachment;
#endif

#ifndef __AddressEntry_FWD_DEFINED__
#define __AddressEntry_FWD_DEFINED__
typedef struct AddressEntry AddressEntry;
#endif

#ifndef __NewMail_FWD_DEFINED__
#define __NewMail_FWD_DEFINED__
#ifdef __cplusplus
typedef class NewMail NewMail;
#else
typedef struct NewMail NewMail;
#endif
#endif

#ifndef __Session_FWD_DEFINED__
#define __Session_FWD_DEFINED__
#ifdef __cplusplus
typedef class Session Session;
#else
typedef struct Session Session;
#endif
#endif

#ifndef __AddressEntry_FWD_DEFINED__
#define __AddressEntry_FWD_DEFINED__
typedef struct AddressEntry AddressEntry;
#endif

#ifndef __Attachment_FWD_DEFINED__
#define __Attachment_FWD_DEFINED__
typedef struct Attachment Attachment;
#endif

#ifndef __Attachments_FWD_DEFINED__
#define __Attachments_FWD_DEFINED__
typedef struct Attachments Attachments;
#endif

#ifndef __Folder_FWD_DEFINED__
#define __Folder_FWD_DEFINED__
typedef struct Folder Folder;
#endif

#ifndef __Messages_FWD_DEFINED__
#define __Messages_FWD_DEFINED__
typedef struct Messages Messages;
#endif

#ifndef __Message_FWD_DEFINED__
#define __Message_FWD_DEFINED__
typedef struct Message Message;
#endif

#ifndef __Recipient_FWD_DEFINED__
#define __Recipient_FWD_DEFINED__
typedef struct Recipient Recipient;
#endif

#ifndef __Recipients_FWD_DEFINED__
#define __Recipients_FWD_DEFINED__
typedef struct Recipients Recipients;
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef enum CdoErrorType {
    CdoE_CALL_FAILED = 0x80004005,CdoE_NOT_ENOUGH_MEMORY = 0x8007000e,CdoE_INVALID_PARAMETER = 0x80070057,CdoE_INTERFACE_NOT_SUPPORTED = 0x80004002,
    CdoE_NO_ACCESS = 0x80070005,CdoE_NO_SUPPORT = 0x80040102,CdoE_BAD_CHARWIDTH = 0x80040103,CdoE_STRING_TOO_LONG = 0x80040105,
    CdoE_UNKNOWN_FLAGS = 0x80040106,CdoE_INVALID_ENTRYID = 0x80040107,CdoE_INVALID_OBJECT = 0x80040108,CdoE_OBJECT_CHANGED = 0x80040109,
    CdoE_OBJECT_DELETED = 0x8004010a,CdoE_BUSY = 0x8004010b,CdoE_NOT_ENOUGH_DISK = 0x8004010d,CdoE_NOT_ENOUGH_RESOURCES = 0x8004010e,
    CdoE_NOT_FOUND = 0x8004010f,CdoE_VERSION = 0x80040110,CdoE_LOGON_FAILED = 0x80040111,CdoE_SESSION_LIMIT = 0x80040112,CdoE_USER_CANCEL = 0x80040113,
    CdoE_UNABLE_TO_ABORT = 0x80040114,CdoE_NETWORK_ERROR = 0x80040115,CdoE_DISK_ERROR = 0x80040116,CdoE_TOO_COMPLEX = 0x80040117,
    CdoE_BAD_COLUMN = 0x80040118,CdoE_EXTENDED_ERROR = 0x80040119,CdoE_COMPUTED = 0x8004011a,CdoE_CORRUPT_DATA = 0x8004011b,
    CdoE_UNCONFIGURED = 0x8004011c,CdoE_FAILONEPROVIDER = 0x8004011d,CdoE_UNKNOWN_CPID = 0x8004011e,CdoE_UNKNOWN_LCID = 0x8004011f,
    CdoE_PASSWORD_CHANGE_REQUIRED = 0x80040120,CdoE_PASSWORD_EXPIRED = 0x80040121,CdoE_INVALID_WORKSTATION_ACCOUNT = 0x80040122,
    CdoE_INVALID_ACCESS_TIME = 0x80040123,CdoE_ACCOUNT_DISABLED = 0x80040124,CdoE_END_OF_SESSION = 0x80040200,CdoE_UNKNOWN_ENTRYID = 0x80040201,
    CdoE_MISSING_REQUIRED_COLUMN = 0x80040202,CdoW_NO_SERVICE = 0x40203,CdoE_BAD_VALUE = 0x80040301,CdoE_INVALID_TYPE = 0x80040302,
    CdoE_TYPE_NO_SUPPORT = 0x80040303,CdoE_UNEXPECTED_TYPE = 0x80040304,CdoE_TOO_BIG = 0x80040305,CdoE_DECLINE_COPY = 0x80040306,
    CdoE_UNEXPECTED_ID = 0x80040307,CdoW_ERRORS_RETURNED = 0x40380,CdoE_UNABLE_TO_COMPLETE = 0x80040400,CdoE_TIMEOUT = 0x80040401,
    CdoE_TABLE_EMPTY = 0x80040402,CdoE_TABLE_TOO_BIG = 0x80040403,CdoE_INVALID_BOOKMARK = 0x80040405,CdoW_POSITION_CHANGED = 0x40481,
    CdoW_APPROX_COUNT = 0x40482,CdoE_WAIT = 0x80040500,CdoE_CANCEL = 0x80040501,CdoE_NOT_ME = 0x80040502,CdoW_CANCEL_MESSAGE = 0x40580,
    CdoE_CORRUPT_STORE = 0x80040600,CdoE_NOT_IN_QUEUE = 0x80040601,CdoE_NO_SUPPRESS = 0x80040602,CdoE_COLLISION = 0x80040604,
    CdoE_NOT_INITIALIZED = 0x80040605,CdoE_NON_STANDARD = 0x80040606,CdoE_NO_RECIPIENTS = 0x80040607,CdoE_SUBMITTED = 0x80040608,
    CdoE_HAS_FOLDERS = 0x80040609,CdoE_HAS_MESSAGES = 0x8004060a,CdoE_FOLDER_CYCLE = 0x8004060b,CdoW_PARTIAL_COMPLETION = 0x40680,
    CdoE_AMBIGUOUS_RECIP = 0x80040700
  } CdoErrorType;

  DEFINE_GUID(LIBID_CDONTS,0x0E064ADD,0x9D99,0x11D0,0xAB,0xE5,0x00,0xAA,0x00,0x64,0xD4,0x70);
  DEFINE_GUID(CLSID_NewMail,0xAF0EB60E,0x0775,0x11D1,0xA7,0x7D,0x00,0xC0,0x4F,0xC2,0xF5,0xB3);
  DEFINE_GUID(CLSID_Session,0x0E064AEC,0x9D99,0x11D0,0xAB,0xE5,0x00,0xAA,0x00,0x64,0xD4,0x70);
  DEFINE_GUID(IID_INewMail,0xAF0EB60D,0x0775,0x11D1,0xA7,0x7D,0x00,0xC0,0x4F,0xC2,0xF5,0xB3);
  DEFINE_GUID(IID_ISession,0x0E064AEB,0x9D99,0x11D0,0xAB,0xE5,0x00,0xAA,0x00,0x64,0xD4,0x70);
  DEFINE_GUID(IID_Folder,0x0E064A01,0x9D99,0x11D0,0xAB,0xE5,0x00,0xAA,0x00,0x64,0xD4,0x70);
  DEFINE_GUID(IID_Messages,0x0E064A02,0x9D99,0x11D0,0xAB,0xE5,0x00,0xAA,0x00,0x64,0xD4,0x70);
  DEFINE_GUID(IID_Message,0x0E064A03,0x9D99,0x11D0,0xAB,0xE5,0x00,0xAA,0x00,0x64,0xD4,0x70);
  DEFINE_GUID(IID_Recipients,0x0E064A04,0x9D99,0x11D0,0xAB,0xE5,0x00,0xAA,0x00,0x64,0xD4,0x70);
  DEFINE_GUID(IID_Recipient,0x0E064A05,0x9D99,0x11D0,0xAB,0xE5,0x00,0xAA,0x00,0x64,0xD4,0x70);
  DEFINE_GUID(IID_Attachments,0x0E064A06,0x9D99,0x11D0,0xAB,0xE5,0x00,0xAA,0x00,0x64,0xD4,0x70);
  DEFINE_GUID(IID_Attachment,0x0E064A07,0x9D99,0x11D0,0xAB,0xE5,0x00,0xAA,0x00,0x64,0xD4,0x70);
  DEFINE_GUID(IID_AddressEntry,0x0E064A08,0x9D99,0x11D0,0xAB,0xE5,0x00,0xAA,0x00,0x64,0xD4,0x70);

  extern RPC_IF_HANDLE __MIDL_itf_actmsg_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_actmsg_0000_v0_0_s_ifspec;

#ifndef __INewMail_INTERFACE_DEFINED__
#define __INewMail_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INewMail;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INewMail : public IDispatch {
  public:
    virtual HRESULT WINAPI put_Value(BSTR bstrHeader,BSTR newVal) = 0;
    virtual HRESULT WINAPI put_To(BSTR newVal) = 0;
    virtual HRESULT WINAPI put_Cc(BSTR newVal) = 0;
    virtual HRESULT WINAPI put_Bcc(BSTR newVal) = 0;
    virtual HRESULT WINAPI put_Body(VARIANT newVal) = 0;
    virtual HRESULT WINAPI put_Importance(__LONG32 newVal) = 0;
    virtual HRESULT WINAPI put_BodyFormat(__LONG32 newVal) = 0;
    virtual HRESULT WINAPI put_MailFormat(__LONG32 newVal) = 0;
    virtual HRESULT WINAPI put_Subject(BSTR newVal) = 0;
    virtual HRESULT WINAPI put_From(BSTR newVal) = 0;
    virtual HRESULT WINAPI Send(VARIANT From,VARIANT To,VARIANT Subject,VARIANT Body,VARIANT Importance) = 0;
    virtual HRESULT WINAPI AttachFile(VARIANT Source,VARIANT FileName,VARIANT EncodingMethod) = 0;
    virtual HRESULT WINAPI AttachURL(VARIANT Source,VARIANT ContentLocation,VARIANT ContentBase,VARIANT EncodingMethod) = 0;
    virtual HRESULT WINAPI SetLocaleIDs(__LONG32 CodePageID) = 0;
    virtual HRESULT WINAPI put_ContentLocation(BSTR newVal) = 0;
    virtual HRESULT WINAPI put_ContentBase(BSTR newVal) = 0;
    virtual HRESULT WINAPI get_Version(BSTR *Version) = 0;
  };
#else
  typedef struct INewMailVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INewMail *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INewMail *This);
      ULONG (WINAPI *Release)(INewMail *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INewMail *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INewMail *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INewMail *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INewMail *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *put_Value)(INewMail *This,BSTR bstrHeader,BSTR newVal);
      HRESULT (WINAPI *put_To)(INewMail *This,BSTR newVal);
      HRESULT (WINAPI *put_Cc)(INewMail *This,BSTR newVal);
      HRESULT (WINAPI *put_Bcc)(INewMail *This,BSTR newVal);
      HRESULT (WINAPI *put_Body)(INewMail *This,VARIANT newVal);
      HRESULT (WINAPI *put_Importance)(INewMail *This,__LONG32 newVal);
      HRESULT (WINAPI *put_BodyFormat)(INewMail *This,__LONG32 newVal);
      HRESULT (WINAPI *put_MailFormat)(INewMail *This,__LONG32 newVal);
      HRESULT (WINAPI *put_Subject)(INewMail *This,BSTR newVal);
      HRESULT (WINAPI *put_From)(INewMail *This,BSTR newVal);
      HRESULT (WINAPI *Send)(INewMail *This,VARIANT From,VARIANT To,VARIANT Subject,VARIANT Body,VARIANT Importance);
      HRESULT (WINAPI *AttachFile)(INewMail *This,VARIANT Source,VARIANT FileName,VARIANT EncodingMethod);
      HRESULT (WINAPI *AttachURL)(INewMail *This,VARIANT Source,VARIANT ContentLocation,VARIANT ContentBase,VARIANT EncodingMethod);
      HRESULT (WINAPI *SetLocaleIDs)(INewMail *This,__LONG32 CodePageID);
      HRESULT (WINAPI *put_ContentLocation)(INewMail *This,BSTR newVal);
      HRESULT (WINAPI *put_ContentBase)(INewMail *This,BSTR newVal);
      HRESULT (WINAPI *get_Version)(INewMail *This,BSTR *Version);
    END_INTERFACE
  } INewMailVtbl;
  struct INewMail {
    CONST_VTBL struct INewMailVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INewMail_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INewMail_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INewMail_Release(This) (This)->lpVtbl->Release(This)
#define INewMail_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INewMail_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INewMail_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INewMail_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INewMail_put_Value(This,bstrHeader,newVal) (This)->lpVtbl->put_Value(This,bstrHeader,newVal)
#define INewMail_put_To(This,newVal) (This)->lpVtbl->put_To(This,newVal)
#define INewMail_put_Cc(This,newVal) (This)->lpVtbl->put_Cc(This,newVal)
#define INewMail_put_Bcc(This,newVal) (This)->lpVtbl->put_Bcc(This,newVal)
#define INewMail_put_Body(This,newVal) (This)->lpVtbl->put_Body(This,newVal)
#define INewMail_put_Importance(This,newVal) (This)->lpVtbl->put_Importance(This,newVal)
#define INewMail_put_BodyFormat(This,newVal) (This)->lpVtbl->put_BodyFormat(This,newVal)
#define INewMail_put_MailFormat(This,newVal) (This)->lpVtbl->put_MailFormat(This,newVal)
#define INewMail_put_Subject(This,newVal) (This)->lpVtbl->put_Subject(This,newVal)
#define INewMail_put_From(This,newVal) (This)->lpVtbl->put_From(This,newVal)
#define INewMail_Send(This,From,To,Subject,Body,Importance) (This)->lpVtbl->Send(This,From,To,Subject,Body,Importance)
#define INewMail_AttachFile(This,Source,FileName,EncodingMethod) (This)->lpVtbl->AttachFile(This,Source,FileName,EncodingMethod)
#define INewMail_AttachURL(This,Source,ContentLocation,ContentBase,EncodingMethod) (This)->lpVtbl->AttachURL(This,Source,ContentLocation,ContentBase,EncodingMethod)
#define INewMail_SetLocaleIDs(This,CodePageID) (This)->lpVtbl->SetLocaleIDs(This,CodePageID)
#define INewMail_put_ContentLocation(This,newVal) (This)->lpVtbl->put_ContentLocation(This,newVal)
#define INewMail_put_ContentBase(This,newVal) (This)->lpVtbl->put_ContentBase(This,newVal)
#define INewMail_get_Version(This,Version) (This)->lpVtbl->get_Version(This,Version)
#endif
#endif
  HRESULT WINAPI INewMail_put_Value_Proxy(INewMail *This,BSTR bstrHeader,BSTR newVal);
  void __RPC_STUB INewMail_put_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_put_To_Proxy(INewMail *This,BSTR newVal);
  void __RPC_STUB INewMail_put_To_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_put_Cc_Proxy(INewMail *This,BSTR newVal);
  void __RPC_STUB INewMail_put_Cc_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_put_Bcc_Proxy(INewMail *This,BSTR newVal);
  void __RPC_STUB INewMail_put_Bcc_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_put_Body_Proxy(INewMail *This,VARIANT newVal);
  void __RPC_STUB INewMail_put_Body_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_put_Importance_Proxy(INewMail *This,__LONG32 newVal);
  void __RPC_STUB INewMail_put_Importance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_put_BodyFormat_Proxy(INewMail *This,__LONG32 newVal);
  void __RPC_STUB INewMail_put_BodyFormat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_put_MailFormat_Proxy(INewMail *This,__LONG32 newVal);
  void __RPC_STUB INewMail_put_MailFormat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_put_Subject_Proxy(INewMail *This,BSTR newVal);
  void __RPC_STUB INewMail_put_Subject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_put_From_Proxy(INewMail *This,BSTR newVal);
  void __RPC_STUB INewMail_put_From_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_Send_Proxy(INewMail *This,VARIANT From,VARIANT To,VARIANT Subject,VARIANT Body,VARIANT Importance);
  void __RPC_STUB INewMail_Send_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_AttachFile_Proxy(INewMail *This,VARIANT Source,VARIANT FileName,VARIANT EncodingMethod);
  void __RPC_STUB INewMail_AttachFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_AttachURL_Proxy(INewMail *This,VARIANT Source,VARIANT ContentLocation,VARIANT ContentBase,VARIANT EncodingMethod);
  void __RPC_STUB INewMail_AttachURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_SetLocaleIDs_Proxy(INewMail *This,__LONG32 CodePageID);
  void __RPC_STUB INewMail_SetLocaleIDs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_put_ContentLocation_Proxy(INewMail *This,BSTR newVal);
  void __RPC_STUB INewMail_put_ContentLocation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_put_ContentBase_Proxy(INewMail *This,BSTR newVal);
  void __RPC_STUB INewMail_put_ContentBase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI INewMail_get_Version_Proxy(INewMail *This,BSTR *Version);
  void __RPC_STUB INewMail_get_Version_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISession_INTERFACE_DEFINED__
#define __ISession_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISession;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISession : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Application(VARIANT *varApplication) = 0;
    virtual HRESULT WINAPI get_Parent(VARIANT *varParent) = 0;
    virtual HRESULT WINAPI get_Session(VARIANT *varSession) = 0;
    virtual HRESULT WINAPI get_Class(__LONG32 *varClass) = 0;
    virtual HRESULT WINAPI get_Version(BSTR *varVersion) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *varName) = 0;
    virtual HRESULT WINAPI get_Inbox(VARIANT *varInbox) = 0;
    virtual HRESULT WINAPI get_Outbox(VARIANT *varOutbox) = 0;
    virtual HRESULT WINAPI get_MessageFormat(__LONG32 *pMessageFormat) = 0;
    virtual HRESULT WINAPI put_MessageFormat(__LONG32 varMessageFormat) = 0;
    virtual HRESULT WINAPI LogonSMTP(VARIANT DisplayName,VARIANT Address) = 0;
    virtual HRESULT WINAPI Logoff(void) = 0;
    virtual HRESULT WINAPI GetDefaultFolder(VARIANT Type,VARIANT *pvarResult) = 0;
    virtual HRESULT WINAPI GetMessage(VARIANT MessageID,VARIANT StoreID,VARIANT *pvarResult) = 0;
    virtual HRESULT WINAPI SetLocaleIDs(__LONG32 CodePageID) = 0;
    virtual HRESULT WINAPI SetReserved(VARIANT var1,VARIANT var2) = 0;
  };
#else
  typedef struct ISessionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISession *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISession *This);
      ULONG (WINAPI *Release)(ISession *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISession *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISession *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISession *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISession *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Application)(ISession *This,VARIANT *varApplication);
      HRESULT (WINAPI *get_Parent)(ISession *This,VARIANT *varParent);
      HRESULT (WINAPI *get_Session)(ISession *This,VARIANT *varSession);
      HRESULT (WINAPI *get_Class)(ISession *This,__LONG32 *varClass);
      HRESULT (WINAPI *get_Version)(ISession *This,BSTR *varVersion);
      HRESULT (WINAPI *get_Name)(ISession *This,BSTR *varName);
      HRESULT (WINAPI *get_Inbox)(ISession *This,VARIANT *varInbox);
      HRESULT (WINAPI *get_Outbox)(ISession *This,VARIANT *varOutbox);
      HRESULT (WINAPI *get_MessageFormat)(ISession *This,__LONG32 *pMessageFormat);
      HRESULT (WINAPI *put_MessageFormat)(ISession *This,__LONG32 varMessageFormat);
      HRESULT (WINAPI *LogonSMTP)(ISession *This,VARIANT DisplayName,VARIANT Address);
      HRESULT (WINAPI *Logoff)(ISession *This);
      HRESULT (WINAPI *GetDefaultFolder)(ISession *This,VARIANT Type,VARIANT *pvarResult);
      HRESULT (WINAPI *GetMessage)(ISession *This,VARIANT MessageID,VARIANT StoreID,VARIANT *pvarResult);
      HRESULT (WINAPI *SetLocaleIDs)(ISession *This,__LONG32 CodePageID);
      HRESULT (WINAPI *SetReserved)(ISession *This,VARIANT var1,VARIANT var2);
    END_INTERFACE
  } ISessionVtbl;
  struct ISession {
    CONST_VTBL struct ISessionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISession_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISession_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISession_Release(This) (This)->lpVtbl->Release(This)
#define ISession_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISession_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISession_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISession_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISession_get_Application(This,varApplication) (This)->lpVtbl->get_Application(This,varApplication)
#define ISession_get_Parent(This,varParent) (This)->lpVtbl->get_Parent(This,varParent)
#define ISession_get_Session(This,varSession) (This)->lpVtbl->get_Session(This,varSession)
#define ISession_get_Class(This,varClass) (This)->lpVtbl->get_Class(This,varClass)
#define ISession_get_Version(This,varVersion) (This)->lpVtbl->get_Version(This,varVersion)
#define ISession_get_Name(This,varName) (This)->lpVtbl->get_Name(This,varName)
#define ISession_get_Inbox(This,varInbox) (This)->lpVtbl->get_Inbox(This,varInbox)
#define ISession_get_Outbox(This,varOutbox) (This)->lpVtbl->get_Outbox(This,varOutbox)
#define ISession_get_MessageFormat(This,pMessageFormat) (This)->lpVtbl->get_MessageFormat(This,pMessageFormat)
#define ISession_put_MessageFormat(This,varMessageFormat) (This)->lpVtbl->put_MessageFormat(This,varMessageFormat)
#define ISession_LogonSMTP(This,DisplayName,Address) (This)->lpVtbl->LogonSMTP(This,DisplayName,Address)
#define ISession_Logoff(This) (This)->lpVtbl->Logoff(This)
#define ISession_GetDefaultFolder(This,Type,pvarResult) (This)->lpVtbl->GetDefaultFolder(This,Type,pvarResult)
#define ISession_GetMessage(This,MessageID,StoreID,pvarResult) (This)->lpVtbl->GetMessage(This,MessageID,StoreID,pvarResult)
#define ISession_SetLocaleIDs(This,CodePageID) (This)->lpVtbl->SetLocaleIDs(This,CodePageID)
#define ISession_SetReserved(This,var1,var2) (This)->lpVtbl->SetReserved(This,var1,var2)
#endif
#endif
  HRESULT WINAPI ISession_get_Application_Proxy(ISession *This,VARIANT *varApplication);
  void __RPC_STUB ISession_get_Application_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_get_Parent_Proxy(ISession *This,VARIANT *varParent);
  void __RPC_STUB ISession_get_Parent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_get_Session_Proxy(ISession *This,VARIANT *varSession);
  void __RPC_STUB ISession_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_get_Class_Proxy(ISession *This,__LONG32 *varClass);
  void __RPC_STUB ISession_get_Class_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_get_Version_Proxy(ISession *This,BSTR *varVersion);
  void __RPC_STUB ISession_get_Version_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_get_Name_Proxy(ISession *This,BSTR *varName);
  void __RPC_STUB ISession_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_get_Inbox_Proxy(ISession *This,VARIANT *varInbox);
  void __RPC_STUB ISession_get_Inbox_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_get_Outbox_Proxy(ISession *This,VARIANT *varOutbox);
  void __RPC_STUB ISession_get_Outbox_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_get_MessageFormat_Proxy(ISession *This,__LONG32 *pMessageFormat);
  void __RPC_STUB ISession_get_MessageFormat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_put_MessageFormat_Proxy(ISession *This,__LONG32 varMessageFormat);
  void __RPC_STUB ISession_put_MessageFormat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_LogonSMTP_Proxy(ISession *This,VARIANT DisplayName,VARIANT Address);
  void __RPC_STUB ISession_LogonSMTP_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_Logoff_Proxy(ISession *This);
  void __RPC_STUB ISession_Logoff_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_GetDefaultFolder_Proxy(ISession *This,VARIANT Type,VARIANT *pvarResult);
  void __RPC_STUB ISession_GetDefaultFolder_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_GetMessage_Proxy(ISession *This,VARIANT MessageID,VARIANT StoreID,VARIANT *pvarResult);
  void __RPC_STUB ISession_GetMessage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_SetLocaleIDs_Proxy(ISession *This,__LONG32 CodePageID);
  void __RPC_STUB ISession_SetLocaleIDs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISession_SetReserved_Proxy(ISession *This,VARIANT var1,VARIANT var2);
  void __RPC_STUB ISession_SetReserved_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Folder_INTERFACE_DEFINED__
#define __Folder_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Folder;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Folder : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Application(VARIANT *varApplication) = 0;
    virtual HRESULT WINAPI get_Parent(VARIANT *varParent) = 0;
    virtual HRESULT WINAPI get_Session(VARIANT *varSession) = 0;
    virtual HRESULT WINAPI get_Class(__LONG32 *varClass) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *varName) = 0;
    virtual HRESULT WINAPI get_Messages(VARIANT *varMessages) = 0;
  };
#else
  typedef struct FolderVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Folder *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Folder *This);
      ULONG (WINAPI *Release)(Folder *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Folder *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Folder *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Folder *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Folder *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Application)(Folder *This,VARIANT *varApplication);
      HRESULT (WINAPI *get_Parent)(Folder *This,VARIANT *varParent);
      HRESULT (WINAPI *get_Session)(Folder *This,VARIANT *varSession);
      HRESULT (WINAPI *get_Class)(Folder *This,__LONG32 *varClass);
      HRESULT (WINAPI *get_Name)(Folder *This,BSTR *varName);
      HRESULT (WINAPI *get_Messages)(Folder *This,VARIANT *varMessages);
    END_INTERFACE
  } FolderVtbl;
  struct Folder {
    CONST_VTBL struct FolderVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Folder_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Folder_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Folder_Release(This) (This)->lpVtbl->Release(This)
#define Folder_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Folder_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Folder_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Folder_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Folder_get_Application(This,varApplication) (This)->lpVtbl->get_Application(This,varApplication)
#define Folder_get_Parent(This,varParent) (This)->lpVtbl->get_Parent(This,varParent)
#define Folder_get_Session(This,varSession) (This)->lpVtbl->get_Session(This,varSession)
#define Folder_get_Class(This,varClass) (This)->lpVtbl->get_Class(This,varClass)
#define Folder_get_Name(This,varName) (This)->lpVtbl->get_Name(This,varName)
#define Folder_get_Messages(This,varMessages) (This)->lpVtbl->get_Messages(This,varMessages)
#endif
#endif
  HRESULT WINAPI Folder_get_Application_Proxy(Folder *This,VARIANT *varApplication);
  void __RPC_STUB Folder_get_Application_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Folder_get_Parent_Proxy(Folder *This,VARIANT *varParent);
  void __RPC_STUB Folder_get_Parent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Folder_get_Session_Proxy(Folder *This,VARIANT *varSession);
  void __RPC_STUB Folder_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Folder_get_Class_Proxy(Folder *This,__LONG32 *varClass);
  void __RPC_STUB Folder_get_Class_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Folder_get_Name_Proxy(Folder *This,BSTR *varName);
  void __RPC_STUB Folder_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Folder_get_Messages_Proxy(Folder *This,VARIANT *varMessages);
  void __RPC_STUB Folder_get_Messages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Messages_INTERFACE_DEFINED__
#define __Messages_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Messages;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Messages : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Application(VARIANT *varApplication) = 0;
    virtual HRESULT WINAPI get_Parent(VARIANT *varParent) = 0;
    virtual HRESULT WINAPI get_Session(VARIANT *varSession) = 0;
    virtual HRESULT WINAPI get_Class(__LONG32 *varClass) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *varCount) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT *var,VARIANT *pvarResult) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppunkResult) = 0;
    virtual HRESULT WINAPI Add(VARIANT Subject,VARIANT Text,VARIANT Importance,VARIANT *pvarResult) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
    virtual HRESULT WINAPI GetFirst(VARIANT *pvarResult) = 0;
    virtual HRESULT WINAPI GetNext(VARIANT *pvarResult) = 0;
    virtual HRESULT WINAPI GetLast(VARIANT *pvarResult) = 0;
    virtual HRESULT WINAPI GetPrevious(VARIANT *pvarResult) = 0;
  };
#else
  typedef struct MessagesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Messages *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Messages *This);
      ULONG (WINAPI *Release)(Messages *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Messages *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Messages *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Messages *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Messages *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Application)(Messages *This,VARIANT *varApplication);
      HRESULT (WINAPI *get_Parent)(Messages *This,VARIANT *varParent);
      HRESULT (WINAPI *get_Session)(Messages *This,VARIANT *varSession);
      HRESULT (WINAPI *get_Class)(Messages *This,__LONG32 *varClass);
      HRESULT (WINAPI *get_Count)(Messages *This,__LONG32 *varCount);
      HRESULT (WINAPI *get_Item)(Messages *This,VARIANT *var,VARIANT *pvarResult);
      HRESULT (WINAPI *get__NewEnum)(Messages *This,IUnknown **ppunkResult);
      HRESULT (WINAPI *Add)(Messages *This,VARIANT Subject,VARIANT Text,VARIANT Importance,VARIANT *pvarResult);
      HRESULT (WINAPI *Delete)(Messages *This);
      HRESULT (WINAPI *GetFirst)(Messages *This,VARIANT *pvarResult);
      HRESULT (WINAPI *GetNext)(Messages *This,VARIANT *pvarResult);
      HRESULT (WINAPI *GetLast)(Messages *This,VARIANT *pvarResult);
      HRESULT (WINAPI *GetPrevious)(Messages *This,VARIANT *pvarResult);
    END_INTERFACE
  } MessagesVtbl;
  struct Messages {
    CONST_VTBL struct MessagesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Messages_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Messages_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Messages_Release(This) (This)->lpVtbl->Release(This)
#define Messages_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Messages_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Messages_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Messages_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Messages_get_Application(This,varApplication) (This)->lpVtbl->get_Application(This,varApplication)
#define Messages_get_Parent(This,varParent) (This)->lpVtbl->get_Parent(This,varParent)
#define Messages_get_Session(This,varSession) (This)->lpVtbl->get_Session(This,varSession)
#define Messages_get_Class(This,varClass) (This)->lpVtbl->get_Class(This,varClass)
#define Messages_get_Count(This,varCount) (This)->lpVtbl->get_Count(This,varCount)
#define Messages_get_Item(This,var,pvarResult) (This)->lpVtbl->get_Item(This,var,pvarResult)
#define Messages_get__NewEnum(This,ppunkResult) (This)->lpVtbl->get__NewEnum(This,ppunkResult)
#define Messages_Add(This,Subject,Text,Importance,pvarResult) (This)->lpVtbl->Add(This,Subject,Text,Importance,pvarResult)
#define Messages_Delete(This) (This)->lpVtbl->Delete(This)
#define Messages_GetFirst(This,pvarResult) (This)->lpVtbl->GetFirst(This,pvarResult)
#define Messages_GetNext(This,pvarResult) (This)->lpVtbl->GetNext(This,pvarResult)
#define Messages_GetLast(This,pvarResult) (This)->lpVtbl->GetLast(This,pvarResult)
#define Messages_GetPrevious(This,pvarResult) (This)->lpVtbl->GetPrevious(This,pvarResult)
#endif
#endif
  HRESULT WINAPI Messages_get_Application_Proxy(Messages *This,VARIANT *varApplication);
  void __RPC_STUB Messages_get_Application_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_get_Parent_Proxy(Messages *This,VARIANT *varParent);
  void __RPC_STUB Messages_get_Parent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_get_Session_Proxy(Messages *This,VARIANT *varSession);
  void __RPC_STUB Messages_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_get_Class_Proxy(Messages *This,__LONG32 *varClass);
  void __RPC_STUB Messages_get_Class_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_get_Count_Proxy(Messages *This,__LONG32 *varCount);
  void __RPC_STUB Messages_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_get_Item_Proxy(Messages *This,VARIANT *var,VARIANT *pvarResult);
  void __RPC_STUB Messages_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_get__NewEnum_Proxy(Messages *This,IUnknown **ppunkResult);
  void __RPC_STUB Messages_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_Add_Proxy(Messages *This,VARIANT Subject,VARIANT Text,VARIANT Importance,VARIANT *pvarResult);
  void __RPC_STUB Messages_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_Delete_Proxy(Messages *This);
  void __RPC_STUB Messages_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_GetFirst_Proxy(Messages *This,VARIANT *pvarResult);
  void __RPC_STUB Messages_GetFirst_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_GetNext_Proxy(Messages *This,VARIANT *pvarResult);
  void __RPC_STUB Messages_GetNext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_GetLast_Proxy(Messages *This,VARIANT *pvarResult);
  void __RPC_STUB Messages_GetLast_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Messages_GetPrevious_Proxy(Messages *This,VARIANT *pvarResult);
  void __RPC_STUB Messages_GetPrevious_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Message_INTERFACE_DEFINED__
#define __Message_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Message;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Message : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Application(VARIANT *varApplication) = 0;
    virtual HRESULT WINAPI get_Parent(VARIANT *varParent) = 0;
    virtual HRESULT WINAPI get_Session(VARIANT *varSession) = 0;
    virtual HRESULT WINAPI get_Class(__LONG32 *varClass) = 0;
    virtual HRESULT WINAPI get_Size(__LONG32 *varSize) = 0;
    virtual HRESULT WINAPI get_Importance(__LONG32 *pImportance) = 0;
    virtual HRESULT WINAPI put_Importance(__LONG32 varImportance) = 0;
    virtual HRESULT WINAPI get_Subject(BSTR *pSubject) = 0;
    virtual HRESULT WINAPI put_Subject(BSTR varSubject) = 0;
    virtual HRESULT WINAPI get_Sender(VARIANT *varSender) = 0;
    virtual HRESULT WINAPI get_TimeSent(VARIANT *varTimeSent) = 0;
    virtual HRESULT WINAPI put_TimeSent(VARIANT varTimeSent) = 0;
    virtual HRESULT WINAPI get_TimeReceived(VARIANT *varTimeReceived) = 0;
    virtual HRESULT WINAPI put_TimeReceived(VARIANT varTimeReceived) = 0;
    virtual HRESULT WINAPI get_Text(VARIANT *varText) = 0;
    virtual HRESULT WINAPI put_Text(VARIANT varText) = 0;
    virtual HRESULT WINAPI get_HTMLText(VARIANT *varHTMLText) = 0;
    virtual HRESULT WINAPI put_HTMLText(VARIANT varHTMLText) = 0;
    virtual HRESULT WINAPI get_Recipients(VARIANT *varRecipients) = 0;
    virtual HRESULT WINAPI put_Recipients(VARIANT varRecipients) = 0;
    virtual HRESULT WINAPI get_Attachments(VARIANT *varAttachments) = 0;
    virtual HRESULT WINAPI put_MessageFormat(__LONG32 __MIDL_0011) = 0;
    virtual HRESULT WINAPI get_ContentLocation(VARIANT *varContentLocation) = 0;
    virtual HRESULT WINAPI put_ContentLocation(VARIANT varContentLocation) = 0;
    virtual HRESULT WINAPI get_ContentBase(VARIANT *varContentBase) = 0;
    virtual HRESULT WINAPI put_ContentBase(VARIANT varContentBase) = 0;
    virtual HRESULT WINAPI get_ContentID(VARIANT *varContentID) = 0;
    virtual HRESULT WINAPI put_ContentID(VARIANT varContentID) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
    virtual HRESULT WINAPI Send(void) = 0;
  };
#else
  typedef struct MessageVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Message *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Message *This);
      ULONG (WINAPI *Release)(Message *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Message *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Message *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Message *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Message *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Application)(Message *This,VARIANT *varApplication);
      HRESULT (WINAPI *get_Parent)(Message *This,VARIANT *varParent);
      HRESULT (WINAPI *get_Session)(Message *This,VARIANT *varSession);
      HRESULT (WINAPI *get_Class)(Message *This,__LONG32 *varClass);
      HRESULT (WINAPI *get_Size)(Message *This,__LONG32 *varSize);
      HRESULT (WINAPI *get_Importance)(Message *This,__LONG32 *pImportance);
      HRESULT (WINAPI *put_Importance)(Message *This,__LONG32 varImportance);
      HRESULT (WINAPI *get_Subject)(Message *This,BSTR *pSubject);
      HRESULT (WINAPI *put_Subject)(Message *This,BSTR varSubject);
      HRESULT (WINAPI *get_Sender)(Message *This,VARIANT *varSender);
      HRESULT (WINAPI *get_TimeSent)(Message *This,VARIANT *varTimeSent);
      HRESULT (WINAPI *put_TimeSent)(Message *This,VARIANT varTimeSent);
      HRESULT (WINAPI *get_TimeReceived)(Message *This,VARIANT *varTimeReceived);
      HRESULT (WINAPI *put_TimeReceived)(Message *This,VARIANT varTimeReceived);
      HRESULT (WINAPI *get_Text)(Message *This,VARIANT *varText);
      HRESULT (WINAPI *put_Text)(Message *This,VARIANT varText);
      HRESULT (WINAPI *get_HTMLText)(Message *This,VARIANT *varHTMLText);
      HRESULT (WINAPI *put_HTMLText)(Message *This,VARIANT varHTMLText);
      HRESULT (WINAPI *get_Recipients)(Message *This,VARIANT *varRecipients);
      HRESULT (WINAPI *put_Recipients)(Message *This,VARIANT varRecipients);
      HRESULT (WINAPI *get_Attachments)(Message *This,VARIANT *varAttachments);
      HRESULT (WINAPI *put_MessageFormat)(Message *This,__LONG32 __MIDL_0011);
      HRESULT (WINAPI *get_ContentLocation)(Message *This,VARIANT *varContentLocation);
      HRESULT (WINAPI *put_ContentLocation)(Message *This,VARIANT varContentLocation);
      HRESULT (WINAPI *get_ContentBase)(Message *This,VARIANT *varContentBase);
      HRESULT (WINAPI *put_ContentBase)(Message *This,VARIANT varContentBase);
      HRESULT (WINAPI *get_ContentID)(Message *This,VARIANT *varContentID);
      HRESULT (WINAPI *put_ContentID)(Message *This,VARIANT varContentID);
      HRESULT (WINAPI *Delete)(Message *This);
      HRESULT (WINAPI *Send)(Message *This);
    END_INTERFACE
  } MessageVtbl;
  struct Message {
    CONST_VTBL struct MessageVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Message_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Message_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Message_Release(This) (This)->lpVtbl->Release(This)
#define Message_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Message_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Message_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Message_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Message_get_Application(This,varApplication) (This)->lpVtbl->get_Application(This,varApplication)
#define Message_get_Parent(This,varParent) (This)->lpVtbl->get_Parent(This,varParent)
#define Message_get_Session(This,varSession) (This)->lpVtbl->get_Session(This,varSession)
#define Message_get_Class(This,varClass) (This)->lpVtbl->get_Class(This,varClass)
#define Message_get_Size(This,varSize) (This)->lpVtbl->get_Size(This,varSize)
#define Message_get_Importance(This,pImportance) (This)->lpVtbl->get_Importance(This,pImportance)
#define Message_put_Importance(This,varImportance) (This)->lpVtbl->put_Importance(This,varImportance)
#define Message_get_Subject(This,pSubject) (This)->lpVtbl->get_Subject(This,pSubject)
#define Message_put_Subject(This,varSubject) (This)->lpVtbl->put_Subject(This,varSubject)
#define Message_get_Sender(This,varSender) (This)->lpVtbl->get_Sender(This,varSender)
#define Message_get_TimeSent(This,varTimeSent) (This)->lpVtbl->get_TimeSent(This,varTimeSent)
#define Message_put_TimeSent(This,varTimeSent) (This)->lpVtbl->put_TimeSent(This,varTimeSent)
#define Message_get_TimeReceived(This,varTimeReceived) (This)->lpVtbl->get_TimeReceived(This,varTimeReceived)
#define Message_put_TimeReceived(This,varTimeReceived) (This)->lpVtbl->put_TimeReceived(This,varTimeReceived)
#define Message_get_Text(This,varText) (This)->lpVtbl->get_Text(This,varText)
#define Message_put_Text(This,varText) (This)->lpVtbl->put_Text(This,varText)
#define Message_get_HTMLText(This,varHTMLText) (This)->lpVtbl->get_HTMLText(This,varHTMLText)
#define Message_put_HTMLText(This,varHTMLText) (This)->lpVtbl->put_HTMLText(This,varHTMLText)
#define Message_get_Recipients(This,varRecipients) (This)->lpVtbl->get_Recipients(This,varRecipients)
#define Message_put_Recipients(This,varRecipients) (This)->lpVtbl->put_Recipients(This,varRecipients)
#define Message_get_Attachments(This,varAttachments) (This)->lpVtbl->get_Attachments(This,varAttachments)
#define Message_put_MessageFormat(This,__MIDL_0011) (This)->lpVtbl->put_MessageFormat(This,__MIDL_0011)
#define Message_get_ContentLocation(This,varContentLocation) (This)->lpVtbl->get_ContentLocation(This,varContentLocation)
#define Message_put_ContentLocation(This,varContentLocation) (This)->lpVtbl->put_ContentLocation(This,varContentLocation)
#define Message_get_ContentBase(This,varContentBase) (This)->lpVtbl->get_ContentBase(This,varContentBase)
#define Message_put_ContentBase(This,varContentBase) (This)->lpVtbl->put_ContentBase(This,varContentBase)
#define Message_get_ContentID(This,varContentID) (This)->lpVtbl->get_ContentID(This,varContentID)
#define Message_put_ContentID(This,varContentID) (This)->lpVtbl->put_ContentID(This,varContentID)
#define Message_Delete(This) (This)->lpVtbl->Delete(This)
#define Message_Send(This) (This)->lpVtbl->Send(This)
#endif
#endif
  HRESULT WINAPI Message_get_Application_Proxy(Message *This,VARIANT *varApplication);
  void __RPC_STUB Message_get_Application_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_Parent_Proxy(Message *This,VARIANT *varParent);
  void __RPC_STUB Message_get_Parent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_Session_Proxy(Message *This,VARIANT *varSession);
  void __RPC_STUB Message_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_Class_Proxy(Message *This,__LONG32 *varClass);
  void __RPC_STUB Message_get_Class_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_Size_Proxy(Message *This,__LONG32 *varSize);
  void __RPC_STUB Message_get_Size_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_Importance_Proxy(Message *This,__LONG32 *pImportance);
  void __RPC_STUB Message_get_Importance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_put_Importance_Proxy(Message *This,__LONG32 varImportance);
  void __RPC_STUB Message_put_Importance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_Subject_Proxy(Message *This,BSTR *pSubject);
  void __RPC_STUB Message_get_Subject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_put_Subject_Proxy(Message *This,BSTR varSubject);
  void __RPC_STUB Message_put_Subject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_Sender_Proxy(Message *This,VARIANT *varSender);
  void __RPC_STUB Message_get_Sender_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_TimeSent_Proxy(Message *This,VARIANT *varTimeSent);
  void __RPC_STUB Message_get_TimeSent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_put_TimeSent_Proxy(Message *This,VARIANT varTimeSent);
  void __RPC_STUB Message_put_TimeSent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_TimeReceived_Proxy(Message *This,VARIANT *varTimeReceived);
  void __RPC_STUB Message_get_TimeReceived_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_put_TimeReceived_Proxy(Message *This,VARIANT varTimeReceived);
  void __RPC_STUB Message_put_TimeReceived_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_Text_Proxy(Message *This,VARIANT *varText);
  void __RPC_STUB Message_get_Text_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_put_Text_Proxy(Message *This,VARIANT varText);
  void __RPC_STUB Message_put_Text_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_HTMLText_Proxy(Message *This,VARIANT *varHTMLText);
  void __RPC_STUB Message_get_HTMLText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_put_HTMLText_Proxy(Message *This,VARIANT varHTMLText);
  void __RPC_STUB Message_put_HTMLText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_Recipients_Proxy(Message *This,VARIANT *varRecipients);
  void __RPC_STUB Message_get_Recipients_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_put_Recipients_Proxy(Message *This,VARIANT varRecipients);
  void __RPC_STUB Message_put_Recipients_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_Attachments_Proxy(Message *This,VARIANT *varAttachments);
  void __RPC_STUB Message_get_Attachments_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_put_MessageFormat_Proxy(Message *This,__LONG32 __MIDL_0011);
  void __RPC_STUB Message_put_MessageFormat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_ContentLocation_Proxy(Message *This,VARIANT *varContentLocation);
  void __RPC_STUB Message_get_ContentLocation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_put_ContentLocation_Proxy(Message *This,VARIANT varContentLocation);
  void __RPC_STUB Message_put_ContentLocation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_ContentBase_Proxy(Message *This,VARIANT *varContentBase);
  void __RPC_STUB Message_get_ContentBase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_put_ContentBase_Proxy(Message *This,VARIANT varContentBase);
  void __RPC_STUB Message_put_ContentBase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_get_ContentID_Proxy(Message *This,VARIANT *varContentID);
  void __RPC_STUB Message_get_ContentID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_put_ContentID_Proxy(Message *This,VARIANT varContentID);
  void __RPC_STUB Message_put_ContentID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_Delete_Proxy(Message *This);
  void __RPC_STUB Message_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Message_Send_Proxy(Message *This);
  void __RPC_STUB Message_Send_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Recipients_INTERFACE_DEFINED__
#define __Recipients_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Recipients;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Recipients : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Application(VARIANT *varApplication) = 0;
    virtual HRESULT WINAPI get_Parent(VARIANT *varParent) = 0;
    virtual HRESULT WINAPI get_Session(VARIANT *varSession) = 0;
    virtual HRESULT WINAPI get_Class(__LONG32 *varClass) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT *var,VARIANT *pvarResult) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *varCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppunkResult) = 0;
    virtual HRESULT WINAPI Add(VARIANT Name,VARIANT Address,VARIANT Type,VARIANT *pvarResult) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
  };
#else
  typedef struct RecipientsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Recipients *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Recipients *This);
      ULONG (WINAPI *Release)(Recipients *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Recipients *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Recipients *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Recipients *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Recipients *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Application)(Recipients *This,VARIANT *varApplication);
      HRESULT (WINAPI *get_Parent)(Recipients *This,VARIANT *varParent);
      HRESULT (WINAPI *get_Session)(Recipients *This,VARIANT *varSession);
      HRESULT (WINAPI *get_Class)(Recipients *This,__LONG32 *varClass);
      HRESULT (WINAPI *get_Item)(Recipients *This,VARIANT *var,VARIANT *pvarResult);
      HRESULT (WINAPI *get_Count)(Recipients *This,__LONG32 *varCount);
      HRESULT (WINAPI *get__NewEnum)(Recipients *This,IUnknown **ppunkResult);
      HRESULT (WINAPI *Add)(Recipients *This,VARIANT Name,VARIANT Address,VARIANT Type,VARIANT *pvarResult);
      HRESULT (WINAPI *Delete)(Recipients *This);
    END_INTERFACE
  } RecipientsVtbl;
  struct Recipients {
    CONST_VTBL struct RecipientsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Recipients_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Recipients_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Recipients_Release(This) (This)->lpVtbl->Release(This)
#define Recipients_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Recipients_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Recipients_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Recipients_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Recipients_get_Application(This,varApplication) (This)->lpVtbl->get_Application(This,varApplication)
#define Recipients_get_Parent(This,varParent) (This)->lpVtbl->get_Parent(This,varParent)
#define Recipients_get_Session(This,varSession) (This)->lpVtbl->get_Session(This,varSession)
#define Recipients_get_Class(This,varClass) (This)->lpVtbl->get_Class(This,varClass)
#define Recipients_get_Item(This,var,pvarResult) (This)->lpVtbl->get_Item(This,var,pvarResult)
#define Recipients_get_Count(This,varCount) (This)->lpVtbl->get_Count(This,varCount)
#define Recipients_get__NewEnum(This,ppunkResult) (This)->lpVtbl->get__NewEnum(This,ppunkResult)
#define Recipients_Add(This,Name,Address,Type,pvarResult) (This)->lpVtbl->Add(This,Name,Address,Type,pvarResult)
#define Recipients_Delete(This) (This)->lpVtbl->Delete(This)
#endif
#endif
  HRESULT WINAPI Recipients_get_Application_Proxy(Recipients *This,VARIANT *varApplication);
  void __RPC_STUB Recipients_get_Application_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipients_get_Parent_Proxy(Recipients *This,VARIANT *varParent);
  void __RPC_STUB Recipients_get_Parent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipients_get_Session_Proxy(Recipients *This,VARIANT *varSession);
  void __RPC_STUB Recipients_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipients_get_Class_Proxy(Recipients *This,__LONG32 *varClass);
  void __RPC_STUB Recipients_get_Class_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipients_get_Item_Proxy(Recipients *This,VARIANT *var,VARIANT *pvarResult);
  void __RPC_STUB Recipients_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipients_get_Count_Proxy(Recipients *This,__LONG32 *varCount);
  void __RPC_STUB Recipients_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipients_get__NewEnum_Proxy(Recipients *This,IUnknown **ppunkResult);
  void __RPC_STUB Recipients_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipients_Add_Proxy(Recipients *This,VARIANT Name,VARIANT Address,VARIANT Type,VARIANT *pvarResult);
  void __RPC_STUB Recipients_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipients_Delete_Proxy(Recipients *This);
  void __RPC_STUB Recipients_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Recipient_INTERFACE_DEFINED__
#define __Recipient_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Recipient;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Recipient : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Application(VARIANT *varApplication) = 0;
    virtual HRESULT WINAPI get_Parent(VARIANT *varParent) = 0;
    virtual HRESULT WINAPI get_Session(VARIANT *varSession) = 0;
    virtual HRESULT WINAPI get_Class(__LONG32 *varClass) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR bstrName) = 0;
    virtual HRESULT WINAPI get_Type(__LONG32 *pType) = 0;
    virtual HRESULT WINAPI put_Type(__LONG32 varType) = 0;
    virtual HRESULT WINAPI get_Address(BSTR *pAddress) = 0;
    virtual HRESULT WINAPI put_Address(BSTR varAddress) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
  };
#else
  typedef struct RecipientVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Recipient *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Recipient *This);
      ULONG (WINAPI *Release)(Recipient *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Recipient *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Recipient *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Recipient *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Recipient *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Application)(Recipient *This,VARIANT *varApplication);
      HRESULT (WINAPI *get_Parent)(Recipient *This,VARIANT *varParent);
      HRESULT (WINAPI *get_Session)(Recipient *This,VARIANT *varSession);
      HRESULT (WINAPI *get_Class)(Recipient *This,__LONG32 *varClass);
      HRESULT (WINAPI *get_Name)(Recipient *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_Name)(Recipient *This,BSTR bstrName);
      HRESULT (WINAPI *get_Type)(Recipient *This,__LONG32 *pType);
      HRESULT (WINAPI *put_Type)(Recipient *This,__LONG32 varType);
      HRESULT (WINAPI *get_Address)(Recipient *This,BSTR *pAddress);
      HRESULT (WINAPI *put_Address)(Recipient *This,BSTR varAddress);
      HRESULT (WINAPI *Delete)(Recipient *This);
    END_INTERFACE
  } RecipientVtbl;
  struct Recipient {
    CONST_VTBL struct RecipientVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Recipient_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Recipient_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Recipient_Release(This) (This)->lpVtbl->Release(This)
#define Recipient_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Recipient_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Recipient_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Recipient_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Recipient_get_Application(This,varApplication) (This)->lpVtbl->get_Application(This,varApplication)
#define Recipient_get_Parent(This,varParent) (This)->lpVtbl->get_Parent(This,varParent)
#define Recipient_get_Session(This,varSession) (This)->lpVtbl->get_Session(This,varSession)
#define Recipient_get_Class(This,varClass) (This)->lpVtbl->get_Class(This,varClass)
#define Recipient_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define Recipient_put_Name(This,bstrName) (This)->lpVtbl->put_Name(This,bstrName)
#define Recipient_get_Type(This,pType) (This)->lpVtbl->get_Type(This,pType)
#define Recipient_put_Type(This,varType) (This)->lpVtbl->put_Type(This,varType)
#define Recipient_get_Address(This,pAddress) (This)->lpVtbl->get_Address(This,pAddress)
#define Recipient_put_Address(This,varAddress) (This)->lpVtbl->put_Address(This,varAddress)
#define Recipient_Delete(This) (This)->lpVtbl->Delete(This)
#endif
#endif
  HRESULT WINAPI Recipient_get_Application_Proxy(Recipient *This,VARIANT *varApplication);
  void __RPC_STUB Recipient_get_Application_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipient_get_Parent_Proxy(Recipient *This,VARIANT *varParent);
  void __RPC_STUB Recipient_get_Parent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipient_get_Session_Proxy(Recipient *This,VARIANT *varSession);
  void __RPC_STUB Recipient_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipient_get_Class_Proxy(Recipient *This,__LONG32 *varClass);
  void __RPC_STUB Recipient_get_Class_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipient_get_Name_Proxy(Recipient *This,BSTR *pbstrName);
  void __RPC_STUB Recipient_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipient_put_Name_Proxy(Recipient *This,BSTR bstrName);
  void __RPC_STUB Recipient_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipient_get_Type_Proxy(Recipient *This,__LONG32 *pType);
  void __RPC_STUB Recipient_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipient_put_Type_Proxy(Recipient *This,__LONG32 varType);
  void __RPC_STUB Recipient_put_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipient_get_Address_Proxy(Recipient *This,BSTR *pAddress);
  void __RPC_STUB Recipient_get_Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipient_put_Address_Proxy(Recipient *This,BSTR varAddress);
  void __RPC_STUB Recipient_put_Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Recipient_Delete_Proxy(Recipient *This);
  void __RPC_STUB Recipient_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Attachments_INTERFACE_DEFINED__
#define __Attachments_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Attachments;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Attachments : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Application(VARIANT *varApplication) = 0;
    virtual HRESULT WINAPI get_Parent(VARIANT *varParent) = 0;
    virtual HRESULT WINAPI get_Session(VARIANT *varSession) = 0;
    virtual HRESULT WINAPI get_Class(__LONG32 *varClass) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT *var,VARIANT *pvarResult) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *varCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppunkResult) = 0;
    virtual HRESULT WINAPI Add(VARIANT Name,VARIANT Type,VARIANT Source,VARIANT ContentLocation,VARIANT ContentBase,VARIANT *pvarResult) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
  };
#else
  typedef struct AttachmentsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Attachments *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Attachments *This);
      ULONG (WINAPI *Release)(Attachments *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Attachments *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Attachments *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Attachments *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Attachments *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Application)(Attachments *This,VARIANT *varApplication);
      HRESULT (WINAPI *get_Parent)(Attachments *This,VARIANT *varParent);
      HRESULT (WINAPI *get_Session)(Attachments *This,VARIANT *varSession);
      HRESULT (WINAPI *get_Class)(Attachments *This,__LONG32 *varClass);
      HRESULT (WINAPI *get_Item)(Attachments *This,VARIANT *var,VARIANT *pvarResult);
      HRESULT (WINAPI *get_Count)(Attachments *This,__LONG32 *varCount);
      HRESULT (WINAPI *get__NewEnum)(Attachments *This,IUnknown **ppunkResult);
      HRESULT (WINAPI *Add)(Attachments *This,VARIANT Name,VARIANT Type,VARIANT Source,VARIANT ContentLocation,VARIANT ContentBase,VARIANT *pvarResult);
      HRESULT (WINAPI *Delete)(Attachments *This);
    END_INTERFACE
  } AttachmentsVtbl;
  struct Attachments {
    CONST_VTBL struct AttachmentsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Attachments_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Attachments_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Attachments_Release(This) (This)->lpVtbl->Release(This)
#define Attachments_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Attachments_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Attachments_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Attachments_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Attachments_get_Application(This,varApplication) (This)->lpVtbl->get_Application(This,varApplication)
#define Attachments_get_Parent(This,varParent) (This)->lpVtbl->get_Parent(This,varParent)
#define Attachments_get_Session(This,varSession) (This)->lpVtbl->get_Session(This,varSession)
#define Attachments_get_Class(This,varClass) (This)->lpVtbl->get_Class(This,varClass)
#define Attachments_get_Item(This,var,pvarResult) (This)->lpVtbl->get_Item(This,var,pvarResult)
#define Attachments_get_Count(This,varCount) (This)->lpVtbl->get_Count(This,varCount)
#define Attachments_get__NewEnum(This,ppunkResult) (This)->lpVtbl->get__NewEnum(This,ppunkResult)
#define Attachments_Add(This,Name,Type,Source,ContentLocation,ContentBase,pvarResult) (This)->lpVtbl->Add(This,Name,Type,Source,ContentLocation,ContentBase,pvarResult)
#define Attachments_Delete(This) (This)->lpVtbl->Delete(This)
#endif
#endif
  HRESULT WINAPI Attachments_get_Application_Proxy(Attachments *This,VARIANT *varApplication);
  void __RPC_STUB Attachments_get_Application_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachments_get_Parent_Proxy(Attachments *This,VARIANT *varParent);
  void __RPC_STUB Attachments_get_Parent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachments_get_Session_Proxy(Attachments *This,VARIANT *varSession);
  void __RPC_STUB Attachments_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachments_get_Class_Proxy(Attachments *This,__LONG32 *varClass);
  void __RPC_STUB Attachments_get_Class_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachments_get_Item_Proxy(Attachments *This,VARIANT *var,VARIANT *pvarResult);
  void __RPC_STUB Attachments_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachments_get_Count_Proxy(Attachments *This,__LONG32 *varCount);
  void __RPC_STUB Attachments_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachments_get__NewEnum_Proxy(Attachments *This,IUnknown **ppunkResult);
  void __RPC_STUB Attachments_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachments_Add_Proxy(Attachments *This,VARIANT Name,VARIANT Type,VARIANT Source,VARIANT ContentLocation,VARIANT ContentBase,VARIANT *pvarResult);
  void __RPC_STUB Attachments_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachments_Delete_Proxy(Attachments *This);
  void __RPC_STUB Attachments_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Attachment_INTERFACE_DEFINED__
#define __Attachment_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Attachment;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Attachment : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Application(VARIANT *varApplication) = 0;
    virtual HRESULT WINAPI get_Parent(VARIANT *varParent) = 0;
    virtual HRESULT WINAPI get_Session(VARIANT *varSession) = 0;
    virtual HRESULT WINAPI get_Class(__LONG32 *varClass) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR bstrName) = 0;
    virtual HRESULT WINAPI get_Type(__LONG32 *pType) = 0;
    virtual HRESULT WINAPI put_Type(__LONG32 varType) = 0;
    virtual HRESULT WINAPI get_Source(VARIANT *varSource) = 0;
    virtual HRESULT WINAPI put_Source(VARIANT varSource) = 0;
    virtual HRESULT WINAPI get_ContentLocation(VARIANT *varContentLocation) = 0;
    virtual HRESULT WINAPI get_ContentBase(VARIANT *varContentBase) = 0;
    virtual HRESULT WINAPI get_ContentID(VARIANT *varContentID) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
    virtual HRESULT WINAPI ReadFromFile(BSTR FileName) = 0;
    virtual HRESULT WINAPI WriteToFile(BSTR FileName) = 0;
  };
#else
  typedef struct AttachmentVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Attachment *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Attachment *This);
      ULONG (WINAPI *Release)(Attachment *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Attachment *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Attachment *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Attachment *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Attachment *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Application)(Attachment *This,VARIANT *varApplication);
      HRESULT (WINAPI *get_Parent)(Attachment *This,VARIANT *varParent);
      HRESULT (WINAPI *get_Session)(Attachment *This,VARIANT *varSession);
      HRESULT (WINAPI *get_Class)(Attachment *This,__LONG32 *varClass);
      HRESULT (WINAPI *get_Name)(Attachment *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_Name)(Attachment *This,BSTR bstrName);
      HRESULT (WINAPI *get_Type)(Attachment *This,__LONG32 *pType);
      HRESULT (WINAPI *put_Type)(Attachment *This,__LONG32 varType);
      HRESULT (WINAPI *get_Source)(Attachment *This,VARIANT *varSource);
      HRESULT (WINAPI *put_Source)(Attachment *This,VARIANT varSource);
      HRESULT (WINAPI *get_ContentLocation)(Attachment *This,VARIANT *varContentLocation);
      HRESULT (WINAPI *get_ContentBase)(Attachment *This,VARIANT *varContentBase);
      HRESULT (WINAPI *get_ContentID)(Attachment *This,VARIANT *varContentID);
      HRESULT (WINAPI *Delete)(Attachment *This);
      HRESULT (WINAPI *ReadFromFile)(Attachment *This,BSTR FileName);
      HRESULT (WINAPI *WriteToFile)(Attachment *This,BSTR FileName);
    END_INTERFACE
  } AttachmentVtbl;
  struct Attachment {
    CONST_VTBL struct AttachmentVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Attachment_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Attachment_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Attachment_Release(This) (This)->lpVtbl->Release(This)
#define Attachment_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Attachment_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Attachment_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Attachment_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Attachment_get_Application(This,varApplication) (This)->lpVtbl->get_Application(This,varApplication)
#define Attachment_get_Parent(This,varParent) (This)->lpVtbl->get_Parent(This,varParent)
#define Attachment_get_Session(This,varSession) (This)->lpVtbl->get_Session(This,varSession)
#define Attachment_get_Class(This,varClass) (This)->lpVtbl->get_Class(This,varClass)
#define Attachment_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define Attachment_put_Name(This,bstrName) (This)->lpVtbl->put_Name(This,bstrName)
#define Attachment_get_Type(This,pType) (This)->lpVtbl->get_Type(This,pType)
#define Attachment_put_Type(This,varType) (This)->lpVtbl->put_Type(This,varType)
#define Attachment_get_Source(This,varSource) (This)->lpVtbl->get_Source(This,varSource)
#define Attachment_put_Source(This,varSource) (This)->lpVtbl->put_Source(This,varSource)
#define Attachment_get_ContentLocation(This,varContentLocation) (This)->lpVtbl->get_ContentLocation(This,varContentLocation)
#define Attachment_get_ContentBase(This,varContentBase) (This)->lpVtbl->get_ContentBase(This,varContentBase)
#define Attachment_get_ContentID(This,varContentID) (This)->lpVtbl->get_ContentID(This,varContentID)
#define Attachment_Delete(This) (This)->lpVtbl->Delete(This)
#define Attachment_ReadFromFile(This,FileName) (This)->lpVtbl->ReadFromFile(This,FileName)
#define Attachment_WriteToFile(This,FileName) (This)->lpVtbl->WriteToFile(This,FileName)
#endif
#endif
  HRESULT WINAPI Attachment_get_Application_Proxy(Attachment *This,VARIANT *varApplication);
  void __RPC_STUB Attachment_get_Application_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_get_Parent_Proxy(Attachment *This,VARIANT *varParent);
  void __RPC_STUB Attachment_get_Parent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_get_Session_Proxy(Attachment *This,VARIANT *varSession);
  void __RPC_STUB Attachment_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_get_Class_Proxy(Attachment *This,__LONG32 *varClass);
  void __RPC_STUB Attachment_get_Class_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_get_Name_Proxy(Attachment *This,BSTR *pbstrName);
  void __RPC_STUB Attachment_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_put_Name_Proxy(Attachment *This,BSTR bstrName);
  void __RPC_STUB Attachment_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_get_Type_Proxy(Attachment *This,__LONG32 *pType);
  void __RPC_STUB Attachment_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_put_Type_Proxy(Attachment *This,__LONG32 varType);
  void __RPC_STUB Attachment_put_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_get_Source_Proxy(Attachment *This,VARIANT *varSource);
  void __RPC_STUB Attachment_get_Source_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_put_Source_Proxy(Attachment *This,VARIANT varSource);
  void __RPC_STUB Attachment_put_Source_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_get_ContentLocation_Proxy(Attachment *This,VARIANT *varContentLocation);
  void __RPC_STUB Attachment_get_ContentLocation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_get_ContentBase_Proxy(Attachment *This,VARIANT *varContentBase);
  void __RPC_STUB Attachment_get_ContentBase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_get_ContentID_Proxy(Attachment *This,VARIANT *varContentID);
  void __RPC_STUB Attachment_get_ContentID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_Delete_Proxy(Attachment *This);
  void __RPC_STUB Attachment_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_ReadFromFile_Proxy(Attachment *This,BSTR FileName);
  void __RPC_STUB Attachment_ReadFromFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Attachment_WriteToFile_Proxy(Attachment *This,BSTR FileName);
  void __RPC_STUB Attachment_WriteToFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AddressEntry_INTERFACE_DEFINED__
#define __AddressEntry_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AddressEntry;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AddressEntry : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Application(VARIANT *varApplication) = 0;
    virtual HRESULT WINAPI get_Parent(VARIANT *varParent) = 0;
    virtual HRESULT WINAPI get_Session(VARIANT *varSession) = 0;
    virtual HRESULT WINAPI get_Class(__LONG32 *varClass) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI get_Address(BSTR *varAddress) = 0;
    virtual HRESULT WINAPI get_Type(BSTR *varType) = 0;
  };
#else
  typedef struct AddressEntryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AddressEntry *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AddressEntry *This);
      ULONG (WINAPI *Release)(AddressEntry *This);
      HRESULT (WINAPI *GetTypeInfoCount)(AddressEntry *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(AddressEntry *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(AddressEntry *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(AddressEntry *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Application)(AddressEntry *This,VARIANT *varApplication);
      HRESULT (WINAPI *get_Parent)(AddressEntry *This,VARIANT *varParent);
      HRESULT (WINAPI *get_Session)(AddressEntry *This,VARIANT *varSession);
      HRESULT (WINAPI *get_Class)(AddressEntry *This,__LONG32 *varClass);
      HRESULT (WINAPI *get_Name)(AddressEntry *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_Address)(AddressEntry *This,BSTR *varAddress);
      HRESULT (WINAPI *get_Type)(AddressEntry *This,BSTR *varType);
    END_INTERFACE
  } AddressEntryVtbl;
  struct AddressEntry {
    CONST_VTBL struct AddressEntryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AddressEntry_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AddressEntry_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AddressEntry_Release(This) (This)->lpVtbl->Release(This)
#define AddressEntry_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define AddressEntry_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define AddressEntry_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define AddressEntry_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define AddressEntry_get_Application(This,varApplication) (This)->lpVtbl->get_Application(This,varApplication)
#define AddressEntry_get_Parent(This,varParent) (This)->lpVtbl->get_Parent(This,varParent)
#define AddressEntry_get_Session(This,varSession) (This)->lpVtbl->get_Session(This,varSession)
#define AddressEntry_get_Class(This,varClass) (This)->lpVtbl->get_Class(This,varClass)
#define AddressEntry_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define AddressEntry_get_Address(This,varAddress) (This)->lpVtbl->get_Address(This,varAddress)
#define AddressEntry_get_Type(This,varType) (This)->lpVtbl->get_Type(This,varType)
#endif
#endif
  HRESULT WINAPI AddressEntry_get_Application_Proxy(AddressEntry *This,VARIANT *varApplication);
  void __RPC_STUB AddressEntry_get_Application_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AddressEntry_get_Parent_Proxy(AddressEntry *This,VARIANT *varParent);
  void __RPC_STUB AddressEntry_get_Parent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AddressEntry_get_Session_Proxy(AddressEntry *This,VARIANT *varSession);
  void __RPC_STUB AddressEntry_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AddressEntry_get_Class_Proxy(AddressEntry *This,__LONG32 *varClass);
  void __RPC_STUB AddressEntry_get_Class_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AddressEntry_get_Name_Proxy(AddressEntry *This,BSTR *pbstrName);
  void __RPC_STUB AddressEntry_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AddressEntry_get_Address_Proxy(AddressEntry *This,BSTR *varAddress);
  void __RPC_STUB AddressEntry_get_Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AddressEntry_get_Type_Proxy(AddressEntry *This,BSTR *varType);
  void __RPC_STUB AddressEntry_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __CDONTS_LIBRARY_DEFINED__
#define __CDONTS_LIBRARY_DEFINED__
  typedef enum CdoRecipientTypes {
    CdoTo = 1,CdoCc = 2,CdoBcc = 3
  } CdoRecipientTypes;

  typedef enum CdoImportance {
    CdoLow = 0,CdoNormal = 1,CdoHigh = 2
  } CdoImportance;

  typedef enum CdoAttachmentTypes {
    CdoFileData = 1,CdoEmbeddedMessage = 4
  } CdoAttachmentTypes;

  typedef enum CdoFolderTypes {
    CdoDefaultFolderInbox = 1,CdoDefaultFolderOutbox = 2
  } CdoFolderTypes;

  typedef enum CdoMessageFormats {
    CdoMime = 0,CdoText = 1
  } CdoMessageFormats;

  typedef enum CdoMailFormats {
    CdoMailFormatMime = 0,CdoMailFormatText = 1
  } CdoMailFormats;

  typedef enum CdoBodyFormats {
    CdoBodyFormatHTML = 0,CdoBodyFormatText = 1
  } CdoBodyFormats;

  typedef enum CdoEncodingMethod {
    CdoEncodingUUencode = 0,CdoEncodingBase64 = 1
  } CdoEncodingMethod;

  typedef enum __MIDL___MIDL_itf_actmsg_0253_0001 {
    CdoSession = 0,CdoFolder = 2,CdoMsg = 3,CdoRecipient = 4,CdoAttachment = 5,CdoAddressEntry = 8,CdoMessages = 16,CdoRecipients = 17,
    CdoAttachments = 18,CdoClassTotal = 29
  } CdoObjectClass;

  EXTERN_C const IID LIBID_CDONTS;
  EXTERN_C const CLSID CLSID_NewMail;
#ifdef __cplusplus
  class NewMail;
#endif
  EXTERN_C const CLSID CLSID_Session;
#ifdef __cplusplus
  class Session;
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
