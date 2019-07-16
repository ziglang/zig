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
#error this stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __cdo_h__
#define __cdo_h__
#include "cdosysstr.h"
#if defined __cplusplus && !defined CDO_NO_NAMESPACE
namespace CDO {
#else
#undef IDataSource
#endif

#ifndef __IDataSource_FWD_DEFINED__
#define __IDataSource_FWD_DEFINED__
typedef struct IDataSource IDataSource;
#endif

#ifndef __IMessage_FWD_DEFINED__
#define __IMessage_FWD_DEFINED__
typedef struct IMessage IMessage;
#endif

#ifndef __IBodyPart_FWD_DEFINED__
#define __IBodyPart_FWD_DEFINED__
typedef struct IBodyPart IBodyPart;
#endif

#ifndef __IConfiguration_FWD_DEFINED__
#define __IConfiguration_FWD_DEFINED__
typedef struct IConfiguration IConfiguration;
#endif

#ifndef __IMessages_FWD_DEFINED__
#define __IMessages_FWD_DEFINED__
typedef struct IMessages IMessages;
#endif

#ifndef __IDropDirectory_FWD_DEFINED__
#define __IDropDirectory_FWD_DEFINED__
typedef struct IDropDirectory IDropDirectory;
#endif

#ifndef __IBodyParts_FWD_DEFINED__
#define __IBodyParts_FWD_DEFINED__
typedef struct IBodyParts IBodyParts;
#endif

#ifndef __ISMTPScriptConnector_FWD_DEFINED__
#define __ISMTPScriptConnector_FWD_DEFINED__
typedef struct ISMTPScriptConnector ISMTPScriptConnector;
#endif

#ifndef __INNTPEarlyScriptConnector_FWD_DEFINED__
#define __INNTPEarlyScriptConnector_FWD_DEFINED__
typedef struct INNTPEarlyScriptConnector INNTPEarlyScriptConnector;
#endif

#ifndef __INNTPPostScriptConnector_FWD_DEFINED__
#define __INNTPPostScriptConnector_FWD_DEFINED__
typedef struct INNTPPostScriptConnector INNTPPostScriptConnector;
#endif

#ifndef __INNTPFinalScriptConnector_FWD_DEFINED__
#define __INNTPFinalScriptConnector_FWD_DEFINED__
typedef struct INNTPFinalScriptConnector INNTPFinalScriptConnector;
#endif

#ifndef __ISMTPOnArrival_FWD_DEFINED__
#define __ISMTPOnArrival_FWD_DEFINED__
typedef struct ISMTPOnArrival ISMTPOnArrival;
#endif

#ifndef __INNTPOnPostEarly_FWD_DEFINED__
#define __INNTPOnPostEarly_FWD_DEFINED__
typedef struct INNTPOnPostEarly INNTPOnPostEarly;
#endif

#ifndef __INNTPOnPost_FWD_DEFINED__
#define __INNTPOnPost_FWD_DEFINED__
typedef struct INNTPOnPost INNTPOnPost;
#endif

#ifndef __INNTPOnPostFinal_FWD_DEFINED__
#define __INNTPOnPostFinal_FWD_DEFINED__
typedef struct INNTPOnPostFinal INNTPOnPostFinal;
#endif

#ifndef __IProxyObject_FWD_DEFINED__
#define __IProxyObject_FWD_DEFINED__
typedef struct IProxyObject IProxyObject;
#endif

#ifndef __IGetInterface_FWD_DEFINED__
#define __IGetInterface_FWD_DEFINED__
typedef struct IGetInterface IGetInterface;
#endif

#ifndef __IBodyParts_FWD_DEFINED__
#define __IBodyParts_FWD_DEFINED__
typedef struct IBodyParts IBodyParts;
#endif

#ifndef __IMessages_FWD_DEFINED__
#define __IMessages_FWD_DEFINED__
typedef struct IMessages IMessages;
#endif

#ifndef __Message_FWD_DEFINED__
#define __Message_FWD_DEFINED__
#ifdef __cplusplus
typedef class Message Message;
#else
typedef struct Message Message;
#endif
#endif

#ifndef __Configuration_FWD_DEFINED__
#define __Configuration_FWD_DEFINED__
#ifdef __cplusplus
typedef class Configuration Configuration;
#else
typedef struct Configuration Configuration;
#endif
#endif

#ifndef __DropDirectory_FWD_DEFINED__
#define __DropDirectory_FWD_DEFINED__
#ifdef __cplusplus
typedef class DropDirectory DropDirectory;
#else
typedef struct DropDirectory DropDirectory;
#endif
#endif

#ifndef __SMTPConnector_FWD_DEFINED__
#define __SMTPConnector_FWD_DEFINED__
#ifdef __cplusplus
typedef class SMTPConnector SMTPConnector;
#else
typedef struct SMTPConnector SMTPConnector;
#endif
#endif

#ifndef __NNTPEarlyConnector_FWD_DEFINED__
#define __NNTPEarlyConnector_FWD_DEFINED__
#ifdef __cplusplus
typedef class NNTPEarlyConnector NNTPEarlyConnector;
#else
typedef struct NNTPEarlyConnector NNTPEarlyConnector;
#endif
#endif

#ifndef __NNTPPostConnector_FWD_DEFINED__
#define __NNTPPostConnector_FWD_DEFINED__
#ifdef __cplusplus
typedef class NNTPPostConnector NNTPPostConnector;
#else
typedef struct NNTPPostConnector NNTPPostConnector;
#endif
#endif

#ifndef __NNTPFinalConnector_FWD_DEFINED__
#define __NNTPFinalConnector_FWD_DEFINED__

#ifdef __cplusplus
typedef class NNTPFinalConnector NNTPFinalConnector;
#else
typedef struct NNTPFinalConnector NNTPFinalConnector;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifndef __cplusplus
typedef struct ADOError ADOError;
typedef struct ADOErrors ADOErrors;
typedef struct _ADOCommand _ADOCommand;
typedef struct _ADOConnection _ADOConnection;
typedef struct _ADORecord _ADORecord;
typedef struct IRecADOFields IRecADOFields;
typedef struct _ADOStream _ADOStream;
typedef struct _ADORecordset _ADORecordset;
typedef struct ADOField ADOField;
typedef struct _ADOField _ADOField;
typedef struct ADOFields ADOFields;
typedef struct _ADOParameter _ADOParameter;
typedef struct ADOParameters ADOParameters;
typedef struct ADOProperty ADOProperty;
typedef struct ADOProperties ADOProperties;
#endif
#include "adoint.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef enum CdoConfigSource {
    cdoDefaults = -1,cdoIIS = 1,cdoOutlookExpress = 2
  } CdoConfigSource;

  typedef enum CdoDSNOptions {
    cdoDSNDefault = 0,cdoDSNNever = 1,cdoDSNFailure = 2,cdoDSNSuccess = 4,cdoDSNDelay = 8,cdoDSNSuccessFailOrDelay = 14
  } CdoDSNOptions;

  typedef enum CdoEventStatus {
    cdoRunNextSink = 0,cdoSkipRemainingSinks = 1
  } CdoEventStatus;

  typedef enum CdoEventType {
    cdoSMTPOnArrival = 1,cdoNNTPOnPostEarly = 2,cdoNNTPOnPost = 3,cdoNNTPOnPostFinal = 4
  } CdoEventType;

  typedef enum cdoImportanceValues {
    cdoLow = 0,cdoNormal = 1,cdoHigh = 2
  } cdoImportanceValues;

  typedef enum CdoMessageStat {
    cdoStatSuccess = 0,cdoStatAbortDelivery = 2,cdoStatBadMail = 3
  } CdoMessageStat;

  typedef enum CdoMHTMLFlags {
    cdoSuppressNone = 0,cdoSuppressImages = 1,cdoSuppressBGSounds = 2,cdoSuppressFrames = 4,cdoSuppressObjects = 8,cdoSuppressStyleSheets = 16,
    cdoSuppressAll = 31
  } CdoMHTMLFlags;

  typedef enum CdoNNTPProcessingField {
    cdoPostMessage = 1,cdoProcessControl = 2,cdoProcessModerator = 4
  } CdoNNTPProcessingField;

  typedef enum CdoPostUsing {
    cdoPostUsingPickup = 1,cdoPostUsingPort = 2
  } CdoPostUsing;

  typedef enum cdoPriorityValues {
    cdoPriorityNonUrgent = -1,cdoPriorityNormal = 0,cdoPriorityUrgent = 1
  } cdoPriorityValues;

  typedef enum CdoProtocolsAuthentication {
    cdoAnonymous = 0,cdoBasic = 1,cdoNTLM = 2
  } CdoProtocolsAuthentication;

  typedef enum CdoReferenceType {
    cdoRefTypeId = 0,cdoRefTypeLocation = 1
  } CdoReferenceType;

  typedef enum CdoSendUsing {
    cdoSendUsingPickup = 1,cdoSendUsingPort = 2
  } CdoSendUsing;

  typedef enum cdoSensitivityValues {
    cdoSensitivityNone = 0,cdoPersonal = 1,cdoPrivate = 2,cdoCompanyConfidential = 3
  } cdoSensitivityValues;

  typedef enum CdoTimeZoneId {
    cdoUTC = 0,cdoGMT = 1,cdoSarajevo = 2,cdoParis = 3,cdoBerlin = 4,cdoEasternEurope = 5,cdoPrague = 6,cdoAthens = 7,cdoBrasilia = 8,
    cdoAtlanticCanada = 9,cdoEastern = 10,cdoCentral = 11,cdoMountain = 12,cdoPacific = 13,cdoAlaska = 14,cdoHawaii = 15,cdoMidwayIsland = 16,
    cdoWellington = 17,cdoBrisbane = 18,cdoAdelaide = 19,cdoTokyo = 20,cdoSingapore = 21,cdoBangkok = 22,cdoBombay = 23,cdoAbuDhabi = 24,
    cdoTehran = 25,cdoBaghdad = 26,cdoIsrael = 27,cdoNewfoundland = 28,cdoAzores = 29,cdoMidAtlantic = 30,cdoMonrovia = 31,cdoBuenosAires = 32,
    cdoCaracas = 33,cdoIndiana = 34,cdoBogota = 35,cdoSaskatchewan = 36,cdoMexicoCity = 37,cdoArizona = 38,cdoEniwetok = 39,cdoFiji = 40,
    cdoMagadan = 41,cdoHobart = 42,cdoGuam = 43,cdoDarwin = 44,cdoBeijing = 45,cdoAlmaty = 46,cdoIslamabad = 47,cdoKabul = 48,cdoCairo = 49,
    cdoHarare = 50,cdoMoscow = 51,cdoFloating = 52,cdoCapeVerde = 53,cdoCaucasus = 54,cdoCentralAmerica = 55,cdoEastAfrica = 56,cdoMelbourne = 57,
    cdoEkaterinburg = 58,cdoHelsinki = 59,cdoGreenland = 60,cdoRangoon = 61,cdoNepal = 62,cdoIrkutsk = 63,cdoKrasnoyarsk = 64,cdoSantiago = 65,
    cdoSriLanka = 66,cdoTonga = 67,cdoVladivostok = 68,cdoWestCentralAfrica = 69,cdoYakutsk = 70,cdoDhaka = 71,cdoSeoul = 72,cdoPerth = 73,
    cdoArab = 74,cdoTaipei = 75,cdoSydney2000 = 76,cdoInvalidTimeZone = 78
  } CdoTimeZoneId;

  extern RPC_IF_HANDLE __MIDL_itf_cdo_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_cdo_0000_v0_0_s_ifspec;

#ifndef __IDataSource_INTERFACE_DEFINED__
#define __IDataSource_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDataSource;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDataSource : public IDispatch {
  public:
    virtual HRESULT WINAPI get_SourceClass(BSTR *varSourceClass) = 0;
    virtual HRESULT WINAPI get_Source(IUnknown **varSource) = 0;
    virtual HRESULT WINAPI get_IsDirty(VARIANT_BOOL *pIsDirty) = 0;
    virtual HRESULT WINAPI put_IsDirty(VARIANT_BOOL varIsDirty) = 0;
    virtual HRESULT WINAPI get_SourceURL(BSTR *varSourceURL) = 0;
    virtual HRESULT WINAPI get_ActiveConnection(_Connection **varActiveConnection) = 0;
    virtual HRESULT WINAPI SaveToObject(IUnknown *Source,BSTR InterfaceName) = 0;
    virtual HRESULT WINAPI OpenObject(IUnknown *Source,BSTR InterfaceName) = 0;
    virtual HRESULT WINAPI SaveTo(BSTR SourceURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password) = 0;
    virtual HRESULT WINAPI Open(BSTR SourceURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password) = 0;
    virtual HRESULT WINAPI Save(void) = 0;
    virtual HRESULT WINAPI SaveToContainer(BSTR ContainerURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password) = 0;
  };
#else
  typedef struct IDataSourceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDataSource *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDataSource *This);
      ULONG (WINAPI *Release)(IDataSource *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IDataSource *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IDataSource *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IDataSource *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IDataSource *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_SourceClass)(IDataSource *This,BSTR *varSourceClass);
      HRESULT (WINAPI *get_Source)(IDataSource *This,IUnknown **varSource);
      HRESULT (WINAPI *get_IsDirty)(IDataSource *This,VARIANT_BOOL *pIsDirty);
      HRESULT (WINAPI *put_IsDirty)(IDataSource *This,VARIANT_BOOL varIsDirty);
      HRESULT (WINAPI *get_SourceURL)(IDataSource *This,BSTR *varSourceURL);
      HRESULT (WINAPI *get_ActiveConnection)(IDataSource *This,_Connection **varActiveConnection);
      HRESULT (WINAPI *SaveToObject)(IDataSource *This,IUnknown *Source,BSTR InterfaceName);
      HRESULT (WINAPI *OpenObject)(IDataSource *This,IUnknown *Source,BSTR InterfaceName);
      HRESULT (WINAPI *SaveTo)(IDataSource *This,BSTR SourceURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password);
      HRESULT (WINAPI *Open)(IDataSource *This,BSTR SourceURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password);
      HRESULT (WINAPI *Save)(IDataSource *This);
      HRESULT (WINAPI *SaveToContainer)(IDataSource *This,BSTR ContainerURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password);
    END_INTERFACE
  } IDataSourceVtbl;
  struct IDataSource {
    CONST_VTBL struct IDataSourceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDataSource_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDataSource_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDataSource_Release(This) (This)->lpVtbl->Release(This)
#define IDataSource_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IDataSource_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IDataSource_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IDataSource_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IDataSource_get_SourceClass(This,varSourceClass) (This)->lpVtbl->get_SourceClass(This,varSourceClass)
#define IDataSource_get_Source(This,varSource) (This)->lpVtbl->get_Source(This,varSource)
#define IDataSource_get_IsDirty(This,pIsDirty) (This)->lpVtbl->get_IsDirty(This,pIsDirty)
#define IDataSource_put_IsDirty(This,varIsDirty) (This)->lpVtbl->put_IsDirty(This,varIsDirty)
#define IDataSource_get_SourceURL(This,varSourceURL) (This)->lpVtbl->get_SourceURL(This,varSourceURL)
#define IDataSource_get_ActiveConnection(This,varActiveConnection) (This)->lpVtbl->get_ActiveConnection(This,varActiveConnection)
#define IDataSource_SaveToObject(This,Source,InterfaceName) (This)->lpVtbl->SaveToObject(This,Source,InterfaceName)
#define IDataSource_OpenObject(This,Source,InterfaceName) (This)->lpVtbl->OpenObject(This,Source,InterfaceName)
#define IDataSource_SaveTo(This,SourceURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password) (This)->lpVtbl->SaveTo(This,SourceURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password)
#define IDataSource_Open(This,SourceURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password) (This)->lpVtbl->Open(This,SourceURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password)
#define IDataSource_Save(This) (This)->lpVtbl->Save(This)
#define IDataSource_SaveToContainer(This,ContainerURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password) (This)->lpVtbl->SaveToContainer(This,ContainerURL,ActiveConnection,Mode,CreateOptions,Options,UserName,Password)
#endif
#endif
  HRESULT WINAPI IDataSource_get_SourceClass_Proxy(IDataSource *This,BSTR *varSourceClass);
  void __RPC_STUB IDataSource_get_SourceClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource_get_Source_Proxy(IDataSource *This,IUnknown **varSource);
  void __RPC_STUB IDataSource_get_Source_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource_get_IsDirty_Proxy(IDataSource *This,VARIANT_BOOL *pIsDirty);
  void __RPC_STUB IDataSource_get_IsDirty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource_put_IsDirty_Proxy(IDataSource *This,VARIANT_BOOL varIsDirty);
  void __RPC_STUB IDataSource_put_IsDirty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource_get_SourceURL_Proxy(IDataSource *This,BSTR *varSourceURL);
  void __RPC_STUB IDataSource_get_SourceURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource_get_ActiveConnection_Proxy(IDataSource *This,_Connection **varActiveConnection);
  void __RPC_STUB IDataSource_get_ActiveConnection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource_SaveToObject_Proxy(IDataSource *This,IUnknown *Source,BSTR InterfaceName);
  void __RPC_STUB IDataSource_SaveToObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource_OpenObject_Proxy(IDataSource *This,IUnknown *Source,BSTR InterfaceName);
  void __RPC_STUB IDataSource_OpenObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource_SaveTo_Proxy(IDataSource *This,BSTR SourceURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password);
  void __RPC_STUB IDataSource_SaveTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource_Open_Proxy(IDataSource *This,BSTR SourceURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password);
  void __RPC_STUB IDataSource_Open_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource_Save_Proxy(IDataSource *This);
  void __RPC_STUB IDataSource_Save_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataSource_SaveToContainer_Proxy(IDataSource *This,BSTR ContainerURL,IDispatch *ActiveConnection,ConnectModeEnum Mode,RecordCreateOptionsEnum CreateOptions,RecordOpenOptionsEnum Options,BSTR UserName,BSTR Password);
  void __RPC_STUB IDataSource_SaveToContainer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMessage_INTERFACE_DEFINED__
#define __IMessage_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMessage;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMessage : public IDispatch {
  public:
    virtual HRESULT WINAPI get_BCC(BSTR *pBCC) = 0;
    virtual HRESULT WINAPI put_BCC(BSTR varBCC) = 0;
    virtual HRESULT WINAPI get_CC(BSTR *pCC) = 0;
    virtual HRESULT WINAPI put_CC(BSTR varCC) = 0;
    virtual HRESULT WINAPI get_FollowUpTo(BSTR *pFollowUpTo) = 0;
    virtual HRESULT WINAPI put_FollowUpTo(BSTR varFollowUpTo) = 0;
    virtual HRESULT WINAPI get_From(BSTR *pFrom) = 0;
    virtual HRESULT WINAPI put_From(BSTR varFrom) = 0;
    virtual HRESULT WINAPI get_Keywords(BSTR *pKeywords) = 0;
    virtual HRESULT WINAPI put_Keywords(BSTR varKeywords) = 0;
    virtual HRESULT WINAPI get_MimeFormatted(VARIANT_BOOL *pMimeFormatted) = 0;
    virtual HRESULT WINAPI put_MimeFormatted(VARIANT_BOOL varMimeFormatted) = 0;
    virtual HRESULT WINAPI get_Newsgroups(BSTR *pNewsgroups) = 0;
    virtual HRESULT WINAPI put_Newsgroups(BSTR varNewsgroups) = 0;
    virtual HRESULT WINAPI get_Organization(BSTR *pOrganization) = 0;
    virtual HRESULT WINAPI put_Organization(BSTR varOrganization) = 0;
    virtual HRESULT WINAPI get_ReceivedTime(DATE *varReceivedTime) = 0;
    virtual HRESULT WINAPI get_ReplyTo(BSTR *pReplyTo) = 0;
    virtual HRESULT WINAPI put_ReplyTo(BSTR varReplyTo) = 0;
    virtual HRESULT WINAPI get_DSNOptions(CdoDSNOptions *pDSNOptions) = 0;
    virtual HRESULT WINAPI put_DSNOptions(CdoDSNOptions varDSNOptions) = 0;
    virtual HRESULT WINAPI get_SentOn(DATE *varSentOn) = 0;
    virtual HRESULT WINAPI get_Subject(BSTR *pSubject) = 0;
    virtual HRESULT WINAPI put_Subject(BSTR varSubject) = 0;
    virtual HRESULT WINAPI get_To(BSTR *pTo) = 0;
    virtual HRESULT WINAPI put_To(BSTR varTo) = 0;
    virtual HRESULT WINAPI get_TextBody(BSTR *pTextBody) = 0;
    virtual HRESULT WINAPI put_TextBody(BSTR varTextBody) = 0;
    virtual HRESULT WINAPI get_HTMLBody(BSTR *pHTMLBody) = 0;
    virtual HRESULT WINAPI put_HTMLBody(BSTR varHTMLBody) = 0;
    virtual HRESULT WINAPI get_Attachments(IBodyParts **varAttachments) = 0;
    virtual HRESULT WINAPI get_Sender(BSTR *pSender) = 0;
    virtual HRESULT WINAPI put_Sender(BSTR varSender) = 0;
    virtual HRESULT WINAPI get_Configuration(IConfiguration **pConfiguration) = 0;
    virtual HRESULT WINAPI put_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI putref_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI get_AutoGenerateTextBody(VARIANT_BOOL *pAutoGenerateTextBody) = 0;
    virtual HRESULT WINAPI put_AutoGenerateTextBody(VARIANT_BOOL varAutoGenerateTextBody) = 0;
    virtual HRESULT WINAPI get_EnvelopeFields(Fields **varEnvelopeFields) = 0;
    virtual HRESULT WINAPI get_TextBodyPart(IBodyPart **varTextBodyPart) = 0;
    virtual HRESULT WINAPI get_HTMLBodyPart(IBodyPart **varHTMLBodyPart) = 0;
    virtual HRESULT WINAPI get_BodyPart(IBodyPart **varBodyPart) = 0;
    virtual HRESULT WINAPI get_DataSource(IDataSource **varDataSource) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_MDNRequested(VARIANT_BOOL *pMDNRequested) = 0;
    virtual HRESULT WINAPI put_MDNRequested(VARIANT_BOOL varMDNRequested) = 0;
    virtual HRESULT WINAPI AddRelatedBodyPart(BSTR URL,BSTR Reference,CdoReferenceType ReferenceType,BSTR UserName,BSTR Password,IBodyPart **ppBody) = 0;
    virtual HRESULT WINAPI AddAttachment(BSTR URL,BSTR UserName,BSTR Password,IBodyPart **ppBody) = 0;
    virtual HRESULT WINAPI CreateMHTMLBody(BSTR URL,CdoMHTMLFlags Flags,BSTR UserName,BSTR Password) = 0;
    virtual HRESULT WINAPI Forward(IMessage **ppMsg) = 0;
    virtual HRESULT WINAPI Post(void) = 0;
    virtual HRESULT WINAPI PostReply(IMessage **ppMsg) = 0;
    virtual HRESULT WINAPI Reply(IMessage **ppMsg) = 0;
    virtual HRESULT WINAPI ReplyAll(IMessage **ppMsg) = 0;
    virtual HRESULT WINAPI Send(void) = 0;
    virtual HRESULT WINAPI GetStream(_Stream **ppStream) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
  };
#else
  typedef struct IMessageVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMessage *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMessage *This);
      ULONG (WINAPI *Release)(IMessage *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMessage *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMessage *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMessage *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMessage *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_BCC)(IMessage *This,BSTR *pBCC);
      HRESULT (WINAPI *put_BCC)(IMessage *This,BSTR varBCC);
      HRESULT (WINAPI *get_CC)(IMessage *This,BSTR *pCC);
      HRESULT (WINAPI *put_CC)(IMessage *This,BSTR varCC);
      HRESULT (WINAPI *get_FollowUpTo)(IMessage *This,BSTR *pFollowUpTo);
      HRESULT (WINAPI *put_FollowUpTo)(IMessage *This,BSTR varFollowUpTo);
      HRESULT (WINAPI *get_From)(IMessage *This,BSTR *pFrom);
      HRESULT (WINAPI *put_From)(IMessage *This,BSTR varFrom);
      HRESULT (WINAPI *get_Keywords)(IMessage *This,BSTR *pKeywords);
      HRESULT (WINAPI *put_Keywords)(IMessage *This,BSTR varKeywords);
      HRESULT (WINAPI *get_MimeFormatted)(IMessage *This,VARIANT_BOOL *pMimeFormatted);
      HRESULT (WINAPI *put_MimeFormatted)(IMessage *This,VARIANT_BOOL varMimeFormatted);
      HRESULT (WINAPI *get_Newsgroups)(IMessage *This,BSTR *pNewsgroups);
      HRESULT (WINAPI *put_Newsgroups)(IMessage *This,BSTR varNewsgroups);
      HRESULT (WINAPI *get_Organization)(IMessage *This,BSTR *pOrganization);
      HRESULT (WINAPI *put_Organization)(IMessage *This,BSTR varOrganization);
      HRESULT (WINAPI *get_ReceivedTime)(IMessage *This,DATE *varReceivedTime);
      HRESULT (WINAPI *get_ReplyTo)(IMessage *This,BSTR *pReplyTo);
      HRESULT (WINAPI *put_ReplyTo)(IMessage *This,BSTR varReplyTo);
      HRESULT (WINAPI *get_DSNOptions)(IMessage *This,CdoDSNOptions *pDSNOptions);
      HRESULT (WINAPI *put_DSNOptions)(IMessage *This,CdoDSNOptions varDSNOptions);
      HRESULT (WINAPI *get_SentOn)(IMessage *This,DATE *varSentOn);
      HRESULT (WINAPI *get_Subject)(IMessage *This,BSTR *pSubject);
      HRESULT (WINAPI *put_Subject)(IMessage *This,BSTR varSubject);
      HRESULT (WINAPI *get_To)(IMessage *This,BSTR *pTo);
      HRESULT (WINAPI *put_To)(IMessage *This,BSTR varTo);
      HRESULT (WINAPI *get_TextBody)(IMessage *This,BSTR *pTextBody);
      HRESULT (WINAPI *put_TextBody)(IMessage *This,BSTR varTextBody);
      HRESULT (WINAPI *get_HTMLBody)(IMessage *This,BSTR *pHTMLBody);
      HRESULT (WINAPI *put_HTMLBody)(IMessage *This,BSTR varHTMLBody);
      HRESULT (WINAPI *get_Attachments)(IMessage *This,IBodyParts **varAttachments);
      HRESULT (WINAPI *get_Sender)(IMessage *This,BSTR *pSender);
      HRESULT (WINAPI *put_Sender)(IMessage *This,BSTR varSender);
      HRESULT (WINAPI *get_Configuration)(IMessage *This,IConfiguration **pConfiguration);
      HRESULT (WINAPI *put_Configuration)(IMessage *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *putref_Configuration)(IMessage *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *get_AutoGenerateTextBody)(IMessage *This,VARIANT_BOOL *pAutoGenerateTextBody);
      HRESULT (WINAPI *put_AutoGenerateTextBody)(IMessage *This,VARIANT_BOOL varAutoGenerateTextBody);
      HRESULT (WINAPI *get_EnvelopeFields)(IMessage *This,Fields **varEnvelopeFields);
      HRESULT (WINAPI *get_TextBodyPart)(IMessage *This,IBodyPart **varTextBodyPart);
      HRESULT (WINAPI *get_HTMLBodyPart)(IMessage *This,IBodyPart **varHTMLBodyPart);
      HRESULT (WINAPI *get_BodyPart)(IMessage *This,IBodyPart **varBodyPart);
      HRESULT (WINAPI *get_DataSource)(IMessage *This,IDataSource **varDataSource);
      HRESULT (WINAPI *get_Fields)(IMessage *This,Fields **varFields);
      HRESULT (WINAPI *get_MDNRequested)(IMessage *This,VARIANT_BOOL *pMDNRequested);
      HRESULT (WINAPI *put_MDNRequested)(IMessage *This,VARIANT_BOOL varMDNRequested);
      HRESULT (WINAPI *AddRelatedBodyPart)(IMessage *This,BSTR URL,BSTR Reference,CdoReferenceType ReferenceType,BSTR UserName,BSTR Password,IBodyPart **ppBody);
      HRESULT (WINAPI *AddAttachment)(IMessage *This,BSTR URL,BSTR UserName,BSTR Password,IBodyPart **ppBody);
      HRESULT (WINAPI *CreateMHTMLBody)(IMessage *This,BSTR URL,CdoMHTMLFlags Flags,BSTR UserName,BSTR Password);
      HRESULT (WINAPI *Forward)(IMessage *This,IMessage **ppMsg);
      HRESULT (WINAPI *Post)(IMessage *This);
      HRESULT (WINAPI *PostReply)(IMessage *This,IMessage **ppMsg);
      HRESULT (WINAPI *Reply)(IMessage *This,IMessage **ppMsg);
      HRESULT (WINAPI *ReplyAll)(IMessage *This,IMessage **ppMsg);
      HRESULT (WINAPI *Send)(IMessage *This);
      HRESULT (WINAPI *GetStream)(IMessage *This,_Stream **ppStream);
      HRESULT (WINAPI *GetInterface)(IMessage *This,BSTR Interface,IDispatch **ppUnknown);
    END_INTERFACE
  } IMessageVtbl;
  struct IMessage {
    CONST_VTBL struct IMessageVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMessage_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMessage_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMessage_Release(This) (This)->lpVtbl->Release(This)
#define IMessage_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMessage_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMessage_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMessage_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMessage_get_BCC(This,pBCC) (This)->lpVtbl->get_BCC(This,pBCC)
#define IMessage_put_BCC(This,varBCC) (This)->lpVtbl->put_BCC(This,varBCC)
#define IMessage_get_CC(This,pCC) (This)->lpVtbl->get_CC(This,pCC)
#define IMessage_put_CC(This,varCC) (This)->lpVtbl->put_CC(This,varCC)
#define IMessage_get_FollowUpTo(This,pFollowUpTo) (This)->lpVtbl->get_FollowUpTo(This,pFollowUpTo)
#define IMessage_put_FollowUpTo(This,varFollowUpTo) (This)->lpVtbl->put_FollowUpTo(This,varFollowUpTo)
#define IMessage_get_From(This,pFrom) (This)->lpVtbl->get_From(This,pFrom)
#define IMessage_put_From(This,varFrom) (This)->lpVtbl->put_From(This,varFrom)
#define IMessage_get_Keywords(This,pKeywords) (This)->lpVtbl->get_Keywords(This,pKeywords)
#define IMessage_put_Keywords(This,varKeywords) (This)->lpVtbl->put_Keywords(This,varKeywords)
#define IMessage_get_MimeFormatted(This,pMimeFormatted) (This)->lpVtbl->get_MimeFormatted(This,pMimeFormatted)
#define IMessage_put_MimeFormatted(This,varMimeFormatted) (This)->lpVtbl->put_MimeFormatted(This,varMimeFormatted)
#define IMessage_get_Newsgroups(This,pNewsgroups) (This)->lpVtbl->get_Newsgroups(This,pNewsgroups)
#define IMessage_put_Newsgroups(This,varNewsgroups) (This)->lpVtbl->put_Newsgroups(This,varNewsgroups)
#define IMessage_get_Organization(This,pOrganization) (This)->lpVtbl->get_Organization(This,pOrganization)
#define IMessage_put_Organization(This,varOrganization) (This)->lpVtbl->put_Organization(This,varOrganization)
#define IMessage_get_ReceivedTime(This,varReceivedTime) (This)->lpVtbl->get_ReceivedTime(This,varReceivedTime)
#define IMessage_get_ReplyTo(This,pReplyTo) (This)->lpVtbl->get_ReplyTo(This,pReplyTo)
#define IMessage_put_ReplyTo(This,varReplyTo) (This)->lpVtbl->put_ReplyTo(This,varReplyTo)
#define IMessage_get_DSNOptions(This,pDSNOptions) (This)->lpVtbl->get_DSNOptions(This,pDSNOptions)
#define IMessage_put_DSNOptions(This,varDSNOptions) (This)->lpVtbl->put_DSNOptions(This,varDSNOptions)
#define IMessage_get_SentOn(This,varSentOn) (This)->lpVtbl->get_SentOn(This,varSentOn)
#define IMessage_get_Subject(This,pSubject) (This)->lpVtbl->get_Subject(This,pSubject)
#define IMessage_put_Subject(This,varSubject) (This)->lpVtbl->put_Subject(This,varSubject)
#define IMessage_get_To(This,pTo) (This)->lpVtbl->get_To(This,pTo)
#define IMessage_put_To(This,varTo) (This)->lpVtbl->put_To(This,varTo)
#define IMessage_get_TextBody(This,pTextBody) (This)->lpVtbl->get_TextBody(This,pTextBody)
#define IMessage_put_TextBody(This,varTextBody) (This)->lpVtbl->put_TextBody(This,varTextBody)
#define IMessage_get_HTMLBody(This,pHTMLBody) (This)->lpVtbl->get_HTMLBody(This,pHTMLBody)
#define IMessage_put_HTMLBody(This,varHTMLBody) (This)->lpVtbl->put_HTMLBody(This,varHTMLBody)
#define IMessage_get_Attachments(This,varAttachments) (This)->lpVtbl->get_Attachments(This,varAttachments)
#define IMessage_get_Sender(This,pSender) (This)->lpVtbl->get_Sender(This,pSender)
#define IMessage_put_Sender(This,varSender) (This)->lpVtbl->put_Sender(This,varSender)
#define IMessage_get_Configuration(This,pConfiguration) (This)->lpVtbl->get_Configuration(This,pConfiguration)
#define IMessage_put_Configuration(This,varConfiguration) (This)->lpVtbl->put_Configuration(This,varConfiguration)
#define IMessage_putref_Configuration(This,varConfiguration) (This)->lpVtbl->putref_Configuration(This,varConfiguration)
#define IMessage_get_AutoGenerateTextBody(This,pAutoGenerateTextBody) (This)->lpVtbl->get_AutoGenerateTextBody(This,pAutoGenerateTextBody)
#define IMessage_put_AutoGenerateTextBody(This,varAutoGenerateTextBody) (This)->lpVtbl->put_AutoGenerateTextBody(This,varAutoGenerateTextBody)
#define IMessage_get_EnvelopeFields(This,varEnvelopeFields) (This)->lpVtbl->get_EnvelopeFields(This,varEnvelopeFields)
#define IMessage_get_TextBodyPart(This,varTextBodyPart) (This)->lpVtbl->get_TextBodyPart(This,varTextBodyPart)
#define IMessage_get_HTMLBodyPart(This,varHTMLBodyPart) (This)->lpVtbl->get_HTMLBodyPart(This,varHTMLBodyPart)
#define IMessage_get_BodyPart(This,varBodyPart) (This)->lpVtbl->get_BodyPart(This,varBodyPart)
#define IMessage_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IMessage_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IMessage_get_MDNRequested(This,pMDNRequested) (This)->lpVtbl->get_MDNRequested(This,pMDNRequested)
#define IMessage_put_MDNRequested(This,varMDNRequested) (This)->lpVtbl->put_MDNRequested(This,varMDNRequested)
#define IMessage_AddRelatedBodyPart(This,URL,Reference,ReferenceType,UserName,Password,ppBody) (This)->lpVtbl->AddRelatedBodyPart(This,URL,Reference,ReferenceType,UserName,Password,ppBody)
#define IMessage_AddAttachment(This,URL,UserName,Password,ppBody) (This)->lpVtbl->AddAttachment(This,URL,UserName,Password,ppBody)
#define IMessage_CreateMHTMLBody(This,URL,Flags,UserName,Password) (This)->lpVtbl->CreateMHTMLBody(This,URL,Flags,UserName,Password)
#define IMessage_Forward(This,ppMsg) (This)->lpVtbl->Forward(This,ppMsg)
#define IMessage_Post(This) (This)->lpVtbl->Post(This)
#define IMessage_PostReply(This,ppMsg) (This)->lpVtbl->PostReply(This,ppMsg)
#define IMessage_Reply(This,ppMsg) (This)->lpVtbl->Reply(This,ppMsg)
#define IMessage_ReplyAll(This,ppMsg) (This)->lpVtbl->ReplyAll(This,ppMsg)
#define IMessage_Send(This) (This)->lpVtbl->Send(This)
#define IMessage_GetStream(This,ppStream) (This)->lpVtbl->GetStream(This,ppStream)
#define IMessage_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#endif
#endif
  HRESULT WINAPI IMessage_get_BCC_Proxy(IMessage *This,BSTR *pBCC);
  void __RPC_STUB IMessage_get_BCC_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_BCC_Proxy(IMessage *This,BSTR varBCC);
  void __RPC_STUB IMessage_put_BCC_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_CC_Proxy(IMessage *This,BSTR *pCC);
  void __RPC_STUB IMessage_get_CC_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_CC_Proxy(IMessage *This,BSTR varCC);
  void __RPC_STUB IMessage_put_CC_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_FollowUpTo_Proxy(IMessage *This,BSTR *pFollowUpTo);
  void __RPC_STUB IMessage_get_FollowUpTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_FollowUpTo_Proxy(IMessage *This,BSTR varFollowUpTo);
  void __RPC_STUB IMessage_put_FollowUpTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_From_Proxy(IMessage *This,BSTR *pFrom);
  void __RPC_STUB IMessage_get_From_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_From_Proxy(IMessage *This,BSTR varFrom);
  void __RPC_STUB IMessage_put_From_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_Keywords_Proxy(IMessage *This,BSTR *pKeywords);
  void __RPC_STUB IMessage_get_Keywords_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_Keywords_Proxy(IMessage *This,BSTR varKeywords);
  void __RPC_STUB IMessage_put_Keywords_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_MimeFormatted_Proxy(IMessage *This,VARIANT_BOOL *pMimeFormatted);
  void __RPC_STUB IMessage_get_MimeFormatted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_MimeFormatted_Proxy(IMessage *This,VARIANT_BOOL varMimeFormatted);
  void __RPC_STUB IMessage_put_MimeFormatted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_Newsgroups_Proxy(IMessage *This,BSTR *pNewsgroups);
  void __RPC_STUB IMessage_get_Newsgroups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_Newsgroups_Proxy(IMessage *This,BSTR varNewsgroups);
  void __RPC_STUB IMessage_put_Newsgroups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_Organization_Proxy(IMessage *This,BSTR *pOrganization);
  void __RPC_STUB IMessage_get_Organization_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_Organization_Proxy(IMessage *This,BSTR varOrganization);
  void __RPC_STUB IMessage_put_Organization_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_ReceivedTime_Proxy(IMessage *This,DATE *varReceivedTime);
  void __RPC_STUB IMessage_get_ReceivedTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_ReplyTo_Proxy(IMessage *This,BSTR *pReplyTo);
  void __RPC_STUB IMessage_get_ReplyTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_ReplyTo_Proxy(IMessage *This,BSTR varReplyTo);
  void __RPC_STUB IMessage_put_ReplyTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_DSNOptions_Proxy(IMessage *This,CdoDSNOptions *pDSNOptions);
  void __RPC_STUB IMessage_get_DSNOptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_DSNOptions_Proxy(IMessage *This,CdoDSNOptions varDSNOptions);
  void __RPC_STUB IMessage_put_DSNOptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_SentOn_Proxy(IMessage *This,DATE *varSentOn);
  void __RPC_STUB IMessage_get_SentOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_Subject_Proxy(IMessage *This,BSTR *pSubject);
  void __RPC_STUB IMessage_get_Subject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_Subject_Proxy(IMessage *This,BSTR varSubject);
  void __RPC_STUB IMessage_put_Subject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_To_Proxy(IMessage *This,BSTR *pTo);
  void __RPC_STUB IMessage_get_To_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_To_Proxy(IMessage *This,BSTR varTo);
  void __RPC_STUB IMessage_put_To_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_TextBody_Proxy(IMessage *This,BSTR *pTextBody);
  void __RPC_STUB IMessage_get_TextBody_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_TextBody_Proxy(IMessage *This,BSTR varTextBody);
  void __RPC_STUB IMessage_put_TextBody_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_HTMLBody_Proxy(IMessage *This,BSTR *pHTMLBody);
  void __RPC_STUB IMessage_get_HTMLBody_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_HTMLBody_Proxy(IMessage *This,BSTR varHTMLBody);
  void __RPC_STUB IMessage_put_HTMLBody_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_Attachments_Proxy(IMessage *This,IBodyParts **varAttachments);
  void __RPC_STUB IMessage_get_Attachments_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_Sender_Proxy(IMessage *This,BSTR *pSender);
  void __RPC_STUB IMessage_get_Sender_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_Sender_Proxy(IMessage *This,BSTR varSender);
  void __RPC_STUB IMessage_put_Sender_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_Configuration_Proxy(IMessage *This,IConfiguration **pConfiguration);
  void __RPC_STUB IMessage_get_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_Configuration_Proxy(IMessage *This,IConfiguration *varConfiguration);
  void __RPC_STUB IMessage_put_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_putref_Configuration_Proxy(IMessage *This,IConfiguration *varConfiguration);
  void __RPC_STUB IMessage_putref_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_AutoGenerateTextBody_Proxy(IMessage *This,VARIANT_BOOL *pAutoGenerateTextBody);
  void __RPC_STUB IMessage_get_AutoGenerateTextBody_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_AutoGenerateTextBody_Proxy(IMessage *This,VARIANT_BOOL varAutoGenerateTextBody);
  void __RPC_STUB IMessage_put_AutoGenerateTextBody_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_EnvelopeFields_Proxy(IMessage *This,Fields **varEnvelopeFields);
  void __RPC_STUB IMessage_get_EnvelopeFields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_TextBodyPart_Proxy(IMessage *This,IBodyPart **varTextBodyPart);
  void __RPC_STUB IMessage_get_TextBodyPart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_HTMLBodyPart_Proxy(IMessage *This,IBodyPart **varHTMLBodyPart);
  void __RPC_STUB IMessage_get_HTMLBodyPart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_BodyPart_Proxy(IMessage *This,IBodyPart **varBodyPart);
  void __RPC_STUB IMessage_get_BodyPart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_DataSource_Proxy(IMessage *This,IDataSource **varDataSource);
  void __RPC_STUB IMessage_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_Fields_Proxy(IMessage *This,Fields **varFields);
  void __RPC_STUB IMessage_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_get_MDNRequested_Proxy(IMessage *This,VARIANT_BOOL *pMDNRequested);
  void __RPC_STUB IMessage_get_MDNRequested_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_put_MDNRequested_Proxy(IMessage *This,VARIANT_BOOL varMDNRequested);
  void __RPC_STUB IMessage_put_MDNRequested_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_AddRelatedBodyPart_Proxy(IMessage *This,BSTR URL,BSTR Reference,CdoReferenceType ReferenceType,BSTR UserName,BSTR Password,IBodyPart **ppBody);
  void __RPC_STUB IMessage_AddRelatedBodyPart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_AddAttachment_Proxy(IMessage *This,BSTR URL,BSTR UserName,BSTR Password,IBodyPart **ppBody);
  void __RPC_STUB IMessage_AddAttachment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_CreateMHTMLBody_Proxy(IMessage *This,BSTR URL,CdoMHTMLFlags Flags,BSTR UserName,BSTR Password);
  void __RPC_STUB IMessage_CreateMHTMLBody_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_Forward_Proxy(IMessage *This,IMessage **ppMsg);
  void __RPC_STUB IMessage_Forward_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_Post_Proxy(IMessage *This);
  void __RPC_STUB IMessage_Post_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_PostReply_Proxy(IMessage *This,IMessage **ppMsg);
  void __RPC_STUB IMessage_PostReply_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_Reply_Proxy(IMessage *This,IMessage **ppMsg);
  void __RPC_STUB IMessage_Reply_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_ReplyAll_Proxy(IMessage *This,IMessage **ppMsg);
  void __RPC_STUB IMessage_ReplyAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_Send_Proxy(IMessage *This);
  void __RPC_STUB IMessage_Send_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_GetStream_Proxy(IMessage *This,_Stream **ppStream);
  void __RPC_STUB IMessage_GetStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessage_GetInterface_Proxy(IMessage *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IMessage_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBodyPart_INTERFACE_DEFINED__
#define __IBodyPart_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBodyPart;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBodyPart : public IDispatch {
  public:
    virtual HRESULT WINAPI get_BodyParts(IBodyParts **varBodyParts) = 0;
    virtual HRESULT WINAPI get_ContentTransferEncoding(BSTR *pContentTransferEncoding) = 0;
    virtual HRESULT WINAPI put_ContentTransferEncoding(BSTR varContentTransferEncoding) = 0;
    virtual HRESULT WINAPI get_ContentMediaType(BSTR *pContentMediaType) = 0;
    virtual HRESULT WINAPI put_ContentMediaType(BSTR varContentMediaType) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_Charset(BSTR *pCharset) = 0;
    virtual HRESULT WINAPI put_Charset(BSTR varCharset) = 0;
    virtual HRESULT WINAPI get_FileName(BSTR *varFileName) = 0;
    virtual HRESULT WINAPI get_DataSource(IDataSource **varDataSource) = 0;
    virtual HRESULT WINAPI get_ContentClass(BSTR *pContentClass) = 0;
    virtual HRESULT WINAPI put_ContentClass(BSTR varContentClass) = 0;
    virtual HRESULT WINAPI get_ContentClassName(BSTR *pContentClassName) = 0;
    virtual HRESULT WINAPI put_ContentClassName(BSTR varContentClassName) = 0;
    virtual HRESULT WINAPI get_Parent(IBodyPart **varParent) = 0;
    virtual HRESULT WINAPI AddBodyPart(__LONG32 Index,IBodyPart **ppPart) = 0;
    virtual HRESULT WINAPI SaveToFile(BSTR FileName) = 0;
    virtual HRESULT WINAPI GetEncodedContentStream(_Stream **ppStream) = 0;
    virtual HRESULT WINAPI GetDecodedContentStream(_Stream **ppStream) = 0;
    virtual HRESULT WINAPI GetStream(_Stream **ppStream) = 0;
    virtual HRESULT WINAPI GetFieldParameter(BSTR FieldName,BSTR Parameter,BSTR *pbstrValue) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
  };
#else
  typedef struct IBodyPartVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBodyPart *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBodyPart *This);
      ULONG (WINAPI *Release)(IBodyPart *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IBodyPart *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IBodyPart *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IBodyPart *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IBodyPart *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_BodyParts)(IBodyPart *This,IBodyParts **varBodyParts);
      HRESULT (WINAPI *get_ContentTransferEncoding)(IBodyPart *This,BSTR *pContentTransferEncoding);
      HRESULT (WINAPI *put_ContentTransferEncoding)(IBodyPart *This,BSTR varContentTransferEncoding);
      HRESULT (WINAPI *get_ContentMediaType)(IBodyPart *This,BSTR *pContentMediaType);
      HRESULT (WINAPI *put_ContentMediaType)(IBodyPart *This,BSTR varContentMediaType);
      HRESULT (WINAPI *get_Fields)(IBodyPart *This,Fields **varFields);
      HRESULT (WINAPI *get_Charset)(IBodyPart *This,BSTR *pCharset);
      HRESULT (WINAPI *put_Charset)(IBodyPart *This,BSTR varCharset);
      HRESULT (WINAPI *get_FileName)(IBodyPart *This,BSTR *varFileName);
      HRESULT (WINAPI *get_DataSource)(IBodyPart *This,IDataSource **varDataSource);
      HRESULT (WINAPI *get_ContentClass)(IBodyPart *This,BSTR *pContentClass);
      HRESULT (WINAPI *put_ContentClass)(IBodyPart *This,BSTR varContentClass);
      HRESULT (WINAPI *get_ContentClassName)(IBodyPart *This,BSTR *pContentClassName);
      HRESULT (WINAPI *put_ContentClassName)(IBodyPart *This,BSTR varContentClassName);
      HRESULT (WINAPI *get_Parent)(IBodyPart *This,IBodyPart **varParent);
      HRESULT (WINAPI *AddBodyPart)(IBodyPart *This,__LONG32 Index,IBodyPart **ppPart);
      HRESULT (WINAPI *SaveToFile)(IBodyPart *This,BSTR FileName);
      HRESULT (WINAPI *GetEncodedContentStream)(IBodyPart *This,_Stream **ppStream);
      HRESULT (WINAPI *GetDecodedContentStream)(IBodyPart *This,_Stream **ppStream);
      HRESULT (WINAPI *GetStream)(IBodyPart *This,_Stream **ppStream);
      HRESULT (WINAPI *GetFieldParameter)(IBodyPart *This,BSTR FieldName,BSTR Parameter,BSTR *pbstrValue);
      HRESULT (WINAPI *GetInterface)(IBodyPart *This,BSTR Interface,IDispatch **ppUnknown);
    END_INTERFACE
  } IBodyPartVtbl;
  struct IBodyPart {
    CONST_VTBL struct IBodyPartVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBodyPart_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBodyPart_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBodyPart_Release(This) (This)->lpVtbl->Release(This)
#define IBodyPart_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IBodyPart_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IBodyPart_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IBodyPart_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IBodyPart_get_BodyParts(This,varBodyParts) (This)->lpVtbl->get_BodyParts(This,varBodyParts)
#define IBodyPart_get_ContentTransferEncoding(This,pContentTransferEncoding) (This)->lpVtbl->get_ContentTransferEncoding(This,pContentTransferEncoding)
#define IBodyPart_put_ContentTransferEncoding(This,varContentTransferEncoding) (This)->lpVtbl->put_ContentTransferEncoding(This,varContentTransferEncoding)
#define IBodyPart_get_ContentMediaType(This,pContentMediaType) (This)->lpVtbl->get_ContentMediaType(This,pContentMediaType)
#define IBodyPart_put_ContentMediaType(This,varContentMediaType) (This)->lpVtbl->put_ContentMediaType(This,varContentMediaType)
#define IBodyPart_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IBodyPart_get_Charset(This,pCharset) (This)->lpVtbl->get_Charset(This,pCharset)
#define IBodyPart_put_Charset(This,varCharset) (This)->lpVtbl->put_Charset(This,varCharset)
#define IBodyPart_get_FileName(This,varFileName) (This)->lpVtbl->get_FileName(This,varFileName)
#define IBodyPart_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IBodyPart_get_ContentClass(This,pContentClass) (This)->lpVtbl->get_ContentClass(This,pContentClass)
#define IBodyPart_put_ContentClass(This,varContentClass) (This)->lpVtbl->put_ContentClass(This,varContentClass)
#define IBodyPart_get_ContentClassName(This,pContentClassName) (This)->lpVtbl->get_ContentClassName(This,pContentClassName)
#define IBodyPart_put_ContentClassName(This,varContentClassName) (This)->lpVtbl->put_ContentClassName(This,varContentClassName)
#define IBodyPart_get_Parent(This,varParent) (This)->lpVtbl->get_Parent(This,varParent)
#define IBodyPart_AddBodyPart(This,Index,ppPart) (This)->lpVtbl->AddBodyPart(This,Index,ppPart)
#define IBodyPart_SaveToFile(This,FileName) (This)->lpVtbl->SaveToFile(This,FileName)
#define IBodyPart_GetEncodedContentStream(This,ppStream) (This)->lpVtbl->GetEncodedContentStream(This,ppStream)
#define IBodyPart_GetDecodedContentStream(This,ppStream) (This)->lpVtbl->GetDecodedContentStream(This,ppStream)
#define IBodyPart_GetStream(This,ppStream) (This)->lpVtbl->GetStream(This,ppStream)
#define IBodyPart_GetFieldParameter(This,FieldName,Parameter,pbstrValue) (This)->lpVtbl->GetFieldParameter(This,FieldName,Parameter,pbstrValue)
#define IBodyPart_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#endif
#endif
  HRESULT WINAPI IBodyPart_get_BodyParts_Proxy(IBodyPart *This,IBodyParts **varBodyParts);
  void __RPC_STUB IBodyPart_get_BodyParts_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_get_ContentTransferEncoding_Proxy(IBodyPart *This,BSTR *pContentTransferEncoding);
  void __RPC_STUB IBodyPart_get_ContentTransferEncoding_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_put_ContentTransferEncoding_Proxy(IBodyPart *This,BSTR varContentTransferEncoding);
  void __RPC_STUB IBodyPart_put_ContentTransferEncoding_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_get_ContentMediaType_Proxy(IBodyPart *This,BSTR *pContentMediaType);
  void __RPC_STUB IBodyPart_get_ContentMediaType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_put_ContentMediaType_Proxy(IBodyPart *This,BSTR varContentMediaType);
  void __RPC_STUB IBodyPart_put_ContentMediaType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_get_Fields_Proxy(IBodyPart *This,Fields **varFields);
  void __RPC_STUB IBodyPart_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_get_Charset_Proxy(IBodyPart *This,BSTR *pCharset);
  void __RPC_STUB IBodyPart_get_Charset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_put_Charset_Proxy(IBodyPart *This,BSTR varCharset);
  void __RPC_STUB IBodyPart_put_Charset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_get_FileName_Proxy(IBodyPart *This,BSTR *varFileName);
  void __RPC_STUB IBodyPart_get_FileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_get_DataSource_Proxy(IBodyPart *This,IDataSource **varDataSource);
  void __RPC_STUB IBodyPart_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_get_ContentClass_Proxy(IBodyPart *This,BSTR *pContentClass);
  void __RPC_STUB IBodyPart_get_ContentClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_put_ContentClass_Proxy(IBodyPart *This,BSTR varContentClass);
  void __RPC_STUB IBodyPart_put_ContentClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_get_ContentClassName_Proxy(IBodyPart *This,BSTR *pContentClassName);
  void __RPC_STUB IBodyPart_get_ContentClassName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_put_ContentClassName_Proxy(IBodyPart *This,BSTR varContentClassName);
  void __RPC_STUB IBodyPart_put_ContentClassName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_get_Parent_Proxy(IBodyPart *This,IBodyPart **varParent);
  void __RPC_STUB IBodyPart_get_Parent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_AddBodyPart_Proxy(IBodyPart *This,__LONG32 Index,IBodyPart **ppPart);
  void __RPC_STUB IBodyPart_AddBodyPart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_SaveToFile_Proxy(IBodyPart *This,BSTR FileName);
  void __RPC_STUB IBodyPart_SaveToFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_GetEncodedContentStream_Proxy(IBodyPart *This,_Stream **ppStream);
  void __RPC_STUB IBodyPart_GetEncodedContentStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_GetDecodedContentStream_Proxy(IBodyPart *This,_Stream **ppStream);
  void __RPC_STUB IBodyPart_GetDecodedContentStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_GetStream_Proxy(IBodyPart *This,_Stream **ppStream);
  void __RPC_STUB IBodyPart_GetStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_GetFieldParameter_Proxy(IBodyPart *This,BSTR FieldName,BSTR Parameter,BSTR *pbstrValue);
  void __RPC_STUB IBodyPart_GetFieldParameter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyPart_GetInterface_Proxy(IBodyPart *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IBodyPart_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IConfiguration_INTERFACE_DEFINED__
#define __IConfiguration_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IConfiguration;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IConfiguration : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI Load(CdoConfigSource LoadFrom,BSTR URL) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
  };
#else
  typedef struct IConfigurationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IConfiguration *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IConfiguration *This);
      ULONG (WINAPI *Release)(IConfiguration *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IConfiguration *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IConfiguration *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IConfiguration *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IConfiguration *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Fields)(IConfiguration *This,Fields **varFields);
      HRESULT (WINAPI *Load)(IConfiguration *This,CdoConfigSource LoadFrom,BSTR URL);
      HRESULT (WINAPI *GetInterface)(IConfiguration *This,BSTR Interface,IDispatch **ppUnknown);
    END_INTERFACE
  } IConfigurationVtbl;
  struct IConfiguration {
    CONST_VTBL struct IConfigurationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IConfiguration_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IConfiguration_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IConfiguration_Release(This) (This)->lpVtbl->Release(This)
#define IConfiguration_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IConfiguration_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IConfiguration_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IConfiguration_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IConfiguration_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IConfiguration_Load(This,LoadFrom,URL) (This)->lpVtbl->Load(This,LoadFrom,URL)
#define IConfiguration_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#endif
#endif
  HRESULT WINAPI IConfiguration_get_Fields_Proxy(IConfiguration *This,Fields **varFields);
  void __RPC_STUB IConfiguration_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IConfiguration_Load_Proxy(IConfiguration *This,CdoConfigSource LoadFrom,BSTR URL);
  void __RPC_STUB IConfiguration_Load_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IConfiguration_GetInterface_Proxy(IConfiguration *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IConfiguration_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMessages_INTERFACE_DEFINED__
#define __IMessages_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMessages;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMessages : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Index,IMessage **ppMessage) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *varCount) = 0;
    virtual HRESULT WINAPI Delete(__LONG32 Index) = 0;
    virtual HRESULT WINAPI DeleteAll(void) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI get_Filename(VARIANT var,BSTR *Filename) = 0;
  };
#else
  typedef struct IMessagesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMessages *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMessages *This);
      ULONG (WINAPI *Release)(IMessages *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMessages *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMessages *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMessages *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMessages *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IMessages *This,__LONG32 Index,IMessage **ppMessage);
      HRESULT (WINAPI *get_Count)(IMessages *This,__LONG32 *varCount);
      HRESULT (WINAPI *Delete)(IMessages *This,__LONG32 Index);
      HRESULT (WINAPI *DeleteAll)(IMessages *This);
      HRESULT (WINAPI *get__NewEnum)(IMessages *This,IUnknown **retval);
      HRESULT (WINAPI *get_Filename)(IMessages *This,VARIANT var,BSTR *Filename);
    END_INTERFACE
  } IMessagesVtbl;
  struct IMessages {
    CONST_VTBL struct IMessagesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMessages_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMessages_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMessages_Release(This) (This)->lpVtbl->Release(This)
#define IMessages_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMessages_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMessages_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMessages_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMessages_get_Item(This,Index,ppMessage) (This)->lpVtbl->get_Item(This,Index,ppMessage)
#define IMessages_get_Count(This,varCount) (This)->lpVtbl->get_Count(This,varCount)
#define IMessages_Delete(This,Index) (This)->lpVtbl->Delete(This,Index)
#define IMessages_DeleteAll(This) (This)->lpVtbl->DeleteAll(This)
#define IMessages_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define IMessages_get_Filename(This,var,Filename) (This)->lpVtbl->get_Filename(This,var,Filename)
#endif
#endif
  HRESULT WINAPI IMessages_get_Item_Proxy(IMessages *This,__LONG32 Index,IMessage **ppMessage);
  void __RPC_STUB IMessages_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessages_get_Count_Proxy(IMessages *This,__LONG32 *varCount);
  void __RPC_STUB IMessages_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessages_Delete_Proxy(IMessages *This,__LONG32 Index);
  void __RPC_STUB IMessages_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessages_DeleteAll_Proxy(IMessages *This);
  void __RPC_STUB IMessages_DeleteAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessages_get__NewEnum_Proxy(IMessages *This,IUnknown **retval);
  void __RPC_STUB IMessages_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessages_get_Filename_Proxy(IMessages *This,VARIANT var,BSTR *Filename);
  void __RPC_STUB IMessages_get_Filename_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDropDirectory_INTERFACE_DEFINED__
#define __IDropDirectory_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDropDirectory;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDropDirectory : public IDispatch {
  public:
    virtual HRESULT WINAPI GetMessages(BSTR DirName,IMessages **Msgs) = 0;
  };
#else
  typedef struct IDropDirectoryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDropDirectory *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDropDirectory *This);
      ULONG (WINAPI *Release)(IDropDirectory *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IDropDirectory *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IDropDirectory *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IDropDirectory *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IDropDirectory *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetMessages)(IDropDirectory *This,BSTR DirName,IMessages **Msgs);
    END_INTERFACE
  } IDropDirectoryVtbl;
  struct IDropDirectory {
    CONST_VTBL struct IDropDirectoryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDropDirectory_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDropDirectory_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDropDirectory_Release(This) (This)->lpVtbl->Release(This)
#define IDropDirectory_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IDropDirectory_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IDropDirectory_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IDropDirectory_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IDropDirectory_GetMessages(This,DirName,Msgs) (This)->lpVtbl->GetMessages(This,DirName,Msgs)
#endif
#endif
  HRESULT WINAPI IDropDirectory_GetMessages_Proxy(IDropDirectory *This,BSTR DirName,IMessages **Msgs);
  void __RPC_STUB IDropDirectory_GetMessages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBodyParts_INTERFACE_DEFINED__
#define __IBodyParts_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBodyParts;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBodyParts : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *varCount) = 0;
    virtual HRESULT WINAPI get_Item(__LONG32 Index,IBodyPart **ppBody) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Delete(VARIANT varBP) = 0;
    virtual HRESULT WINAPI DeleteAll(void) = 0;
    virtual HRESULT WINAPI Add(__LONG32 Index,IBodyPart **ppPart) = 0;
  };
#else
  typedef struct IBodyPartsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBodyParts *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBodyParts *This);
      ULONG (WINAPI *Release)(IBodyParts *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IBodyParts *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IBodyParts *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IBodyParts *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IBodyParts *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(IBodyParts *This,__LONG32 *varCount);
      HRESULT (WINAPI *get_Item)(IBodyParts *This,__LONG32 Index,IBodyPart **ppBody);
      HRESULT (WINAPI *get__NewEnum)(IBodyParts *This,IUnknown **retval);
      HRESULT (WINAPI *Delete)(IBodyParts *This,VARIANT varBP);
      HRESULT (WINAPI *DeleteAll)(IBodyParts *This);
      HRESULT (WINAPI *Add)(IBodyParts *This,__LONG32 Index,IBodyPart **ppPart);
    END_INTERFACE
  } IBodyPartsVtbl;
  struct IBodyParts {
    CONST_VTBL struct IBodyPartsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBodyParts_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBodyParts_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBodyParts_Release(This) (This)->lpVtbl->Release(This)
#define IBodyParts_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IBodyParts_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IBodyParts_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IBodyParts_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IBodyParts_get_Count(This,varCount) (This)->lpVtbl->get_Count(This,varCount)
#define IBodyParts_get_Item(This,Index,ppBody) (This)->lpVtbl->get_Item(This,Index,ppBody)
#define IBodyParts_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define IBodyParts_Delete(This,varBP) (This)->lpVtbl->Delete(This,varBP)
#define IBodyParts_DeleteAll(This) (This)->lpVtbl->DeleteAll(This)
#define IBodyParts_Add(This,Index,ppPart) (This)->lpVtbl->Add(This,Index,ppPart)
#endif
#endif
  HRESULT WINAPI IBodyParts_get_Count_Proxy(IBodyParts *This,__LONG32 *varCount);
  void __RPC_STUB IBodyParts_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyParts_get_Item_Proxy(IBodyParts *This,__LONG32 Index,IBodyPart **ppBody);
  void __RPC_STUB IBodyParts_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyParts_get__NewEnum_Proxy(IBodyParts *This,IUnknown **retval);
  void __RPC_STUB IBodyParts_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyParts_Delete_Proxy(IBodyParts *This,VARIANT varBP);
  void __RPC_STUB IBodyParts_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyParts_DeleteAll_Proxy(IBodyParts *This);
  void __RPC_STUB IBodyParts_DeleteAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBodyParts_Add_Proxy(IBodyParts *This,__LONG32 Index,IBodyPart **ppPart);
  void __RPC_STUB IBodyParts_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISMTPScriptConnector_INTERFACE_DEFINED__
#define __ISMTPScriptConnector_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISMTPScriptConnector;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISMTPScriptConnector : public IDispatch {
  public:
  };
#else
  typedef struct ISMTPScriptConnectorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISMTPScriptConnector *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISMTPScriptConnector *This);
      ULONG (WINAPI *Release)(ISMTPScriptConnector *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISMTPScriptConnector *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISMTPScriptConnector *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISMTPScriptConnector *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISMTPScriptConnector *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } ISMTPScriptConnectorVtbl;
  struct ISMTPScriptConnector {
    CONST_VTBL struct ISMTPScriptConnectorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISMTPScriptConnector_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISMTPScriptConnector_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISMTPScriptConnector_Release(This) (This)->lpVtbl->Release(This)
#define ISMTPScriptConnector_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISMTPScriptConnector_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISMTPScriptConnector_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISMTPScriptConnector_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

#ifndef __INNTPEarlyScriptConnector_INTERFACE_DEFINED__
#define __INNTPEarlyScriptConnector_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INNTPEarlyScriptConnector;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INNTPEarlyScriptConnector : public IDispatch {
  };
#else
  typedef struct INNTPEarlyScriptConnectorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INNTPEarlyScriptConnector *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INNTPEarlyScriptConnector *This);
      ULONG (WINAPI *Release)(INNTPEarlyScriptConnector *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INNTPEarlyScriptConnector *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INNTPEarlyScriptConnector *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INNTPEarlyScriptConnector *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INNTPEarlyScriptConnector *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } INNTPEarlyScriptConnectorVtbl;
  struct INNTPEarlyScriptConnector {
    CONST_VTBL struct INNTPEarlyScriptConnectorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INNTPEarlyScriptConnector_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INNTPEarlyScriptConnector_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INNTPEarlyScriptConnector_Release(This) (This)->lpVtbl->Release(This)
#define INNTPEarlyScriptConnector_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INNTPEarlyScriptConnector_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INNTPEarlyScriptConnector_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INNTPEarlyScriptConnector_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

#ifndef __INNTPPostScriptConnector_INTERFACE_DEFINED__
#define __INNTPPostScriptConnector_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INNTPPostScriptConnector;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INNTPPostScriptConnector : public IDispatch {
  };
#else
  typedef struct INNTPPostScriptConnectorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INNTPPostScriptConnector *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INNTPPostScriptConnector *This);
      ULONG (WINAPI *Release)(INNTPPostScriptConnector *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INNTPPostScriptConnector *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INNTPPostScriptConnector *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INNTPPostScriptConnector *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INNTPPostScriptConnector *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } INNTPPostScriptConnectorVtbl;
  struct INNTPPostScriptConnector {
    CONST_VTBL struct INNTPPostScriptConnectorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INNTPPostScriptConnector_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INNTPPostScriptConnector_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INNTPPostScriptConnector_Release(This) (This)->lpVtbl->Release(This)
#define INNTPPostScriptConnector_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INNTPPostScriptConnector_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INNTPPostScriptConnector_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INNTPPostScriptConnector_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

#ifndef __INNTPFinalScriptConnector_INTERFACE_DEFINED__
#define __INNTPFinalScriptConnector_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INNTPFinalScriptConnector;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INNTPFinalScriptConnector : public IDispatch {
  };
#else
  typedef struct INNTPFinalScriptConnectorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INNTPFinalScriptConnector *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INNTPFinalScriptConnector *This);
      ULONG (WINAPI *Release)(INNTPFinalScriptConnector *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INNTPFinalScriptConnector *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INNTPFinalScriptConnector *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INNTPFinalScriptConnector *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INNTPFinalScriptConnector *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } INNTPFinalScriptConnectorVtbl;
  struct INNTPFinalScriptConnector {
    CONST_VTBL struct INNTPFinalScriptConnectorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INNTPFinalScriptConnector_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INNTPFinalScriptConnector_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INNTPFinalScriptConnector_Release(This) (This)->lpVtbl->Release(This)
#define INNTPFinalScriptConnector_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INNTPFinalScriptConnector_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INNTPFinalScriptConnector_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INNTPFinalScriptConnector_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

#ifndef __ISMTPOnArrival_INTERFACE_DEFINED__
#define __ISMTPOnArrival_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISMTPOnArrival;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISMTPOnArrival : public IDispatch {
  public:
    virtual HRESULT WINAPI OnArrival(IMessage *Msg,CdoEventStatus *EventStatus) = 0;
  };
#else
  typedef struct ISMTPOnArrivalVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISMTPOnArrival *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISMTPOnArrival *This);
      ULONG (WINAPI *Release)(ISMTPOnArrival *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISMTPOnArrival *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISMTPOnArrival *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISMTPOnArrival *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISMTPOnArrival *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *OnArrival)(ISMTPOnArrival *This,IMessage *Msg,CdoEventStatus *EventStatus);
    END_INTERFACE
  } ISMTPOnArrivalVtbl;
  struct ISMTPOnArrival {
    CONST_VTBL struct ISMTPOnArrivalVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISMTPOnArrival_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISMTPOnArrival_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISMTPOnArrival_Release(This) (This)->lpVtbl->Release(This)
#define ISMTPOnArrival_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISMTPOnArrival_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISMTPOnArrival_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISMTPOnArrival_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISMTPOnArrival_OnArrival(This,Msg,EventStatus) (This)->lpVtbl->OnArrival(This,Msg,EventStatus)
#endif
#endif
  HRESULT WINAPI ISMTPOnArrival_OnArrival_Proxy(ISMTPOnArrival *This,IMessage *Msg,CdoEventStatus *EventStatus);
  void __RPC_STUB ISMTPOnArrival_OnArrival_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INNTPOnPostEarly_INTERFACE_DEFINED__
#define __INNTPOnPostEarly_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INNTPOnPostEarly;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INNTPOnPostEarly : public IDispatch {
  public:
    virtual HRESULT WINAPI OnPostEarly(IMessage *Msg,CdoEventStatus *EventStatus) = 0;

  };
#else
  typedef struct INNTPOnPostEarlyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INNTPOnPostEarly *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INNTPOnPostEarly *This);
      ULONG (WINAPI *Release)(INNTPOnPostEarly *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INNTPOnPostEarly *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INNTPOnPostEarly *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INNTPOnPostEarly *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INNTPOnPostEarly *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *OnPostEarly)(INNTPOnPostEarly *This,IMessage *Msg,CdoEventStatus *EventStatus);
    END_INTERFACE
  } INNTPOnPostEarlyVtbl;
  struct INNTPOnPostEarly {
    CONST_VTBL struct INNTPOnPostEarlyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INNTPOnPostEarly_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INNTPOnPostEarly_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INNTPOnPostEarly_Release(This) (This)->lpVtbl->Release(This)
#define INNTPOnPostEarly_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INNTPOnPostEarly_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INNTPOnPostEarly_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INNTPOnPostEarly_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INNTPOnPostEarly_OnPostEarly(This,Msg,EventStatus) (This)->lpVtbl->OnPostEarly(This,Msg,EventStatus)
#endif
#endif
  HRESULT WINAPI INNTPOnPostEarly_OnPostEarly_Proxy(INNTPOnPostEarly *This,IMessage *Msg,CdoEventStatus *EventStatus);
  void __RPC_STUB INNTPOnPostEarly_OnPostEarly_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INNTPOnPost_INTERFACE_DEFINED__
#define __INNTPOnPost_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INNTPOnPost;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INNTPOnPost : public IDispatch {
  public:
    virtual HRESULT WINAPI OnPost(IMessage *Msg,CdoEventStatus *EventStatus) = 0;
  };
#else
  typedef struct INNTPOnPostVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INNTPOnPost *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INNTPOnPost *This);
      ULONG (WINAPI *Release)(INNTPOnPost *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INNTPOnPost *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INNTPOnPost *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INNTPOnPost *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INNTPOnPost *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *OnPost)(INNTPOnPost *This,IMessage *Msg,CdoEventStatus *EventStatus);
    END_INTERFACE
  } INNTPOnPostVtbl;
  struct INNTPOnPost {
    CONST_VTBL struct INNTPOnPostVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INNTPOnPost_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INNTPOnPost_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INNTPOnPost_Release(This) (This)->lpVtbl->Release(This)
#define INNTPOnPost_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INNTPOnPost_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INNTPOnPost_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INNTPOnPost_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INNTPOnPost_OnPost(This,Msg,EventStatus) (This)->lpVtbl->OnPost(This,Msg,EventStatus)
#endif
#endif
  HRESULT WINAPI INNTPOnPost_OnPost_Proxy(INNTPOnPost *This,IMessage *Msg,CdoEventStatus *EventStatus);
  void __RPC_STUB INNTPOnPost_OnPost_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __INNTPOnPostFinal_INTERFACE_DEFINED__
#define __INNTPOnPostFinal_INTERFACE_DEFINED__
  EXTERN_C const IID IID_INNTPOnPostFinal;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct INNTPOnPostFinal : public IDispatch {
  public:
    virtual HRESULT WINAPI OnPostFinal(IMessage *Msg,CdoEventStatus *EventStatus) = 0;
  };
#else
  typedef struct INNTPOnPostFinalVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(INNTPOnPostFinal *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(INNTPOnPostFinal *This);
      ULONG (WINAPI *Release)(INNTPOnPostFinal *This);
      HRESULT (WINAPI *GetTypeInfoCount)(INNTPOnPostFinal *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(INNTPOnPostFinal *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(INNTPOnPostFinal *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(INNTPOnPostFinal *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *OnPostFinal)(INNTPOnPostFinal *This,IMessage *Msg,CdoEventStatus *EventStatus);
    END_INTERFACE
  } INNTPOnPostFinalVtbl;
  struct INNTPOnPostFinal {
    CONST_VTBL struct INNTPOnPostFinalVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define INNTPOnPostFinal_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define INNTPOnPostFinal_AddRef(This) (This)->lpVtbl->AddRef(This)
#define INNTPOnPostFinal_Release(This) (This)->lpVtbl->Release(This)
#define INNTPOnPostFinal_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define INNTPOnPostFinal_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define INNTPOnPostFinal_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define INNTPOnPostFinal_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define INNTPOnPostFinal_OnPostFinal(This,Msg,EventStatus) (This)->lpVtbl->OnPostFinal(This,Msg,EventStatus)
#endif
#endif
  HRESULT WINAPI INNTPOnPostFinal_OnPostFinal_Proxy(INNTPOnPostFinal *This,IMessage *Msg,CdoEventStatus *EventStatus);
  void __RPC_STUB INNTPOnPostFinal_OnPostFinal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IProxyObject_INTERFACE_DEFINED__
#define __IProxyObject_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IProxyObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IProxyObject : public IUnknown {
  public:
    virtual HRESULT WINAPI get_Object(IUnknown **ppParent) = 0;
  };
#else
  typedef struct IProxyObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IProxyObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IProxyObject *This);
      ULONG (WINAPI *Release)(IProxyObject *This);
      HRESULT (WINAPI *get_Object)(IProxyObject *This,IUnknown **ppParent);
    END_INTERFACE
  } IProxyObjectVtbl;
  struct IProxyObject {
    CONST_VTBL struct IProxyObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IProxyObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IProxyObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IProxyObject_Release(This) (This)->lpVtbl->Release(This)
#define IProxyObject_get_Object(This,ppParent) (This)->lpVtbl->get_Object(This,ppParent)
#endif
#endif
  HRESULT WINAPI IProxyObject_get_Object_Proxy(IProxyObject *This,IUnknown **ppParent);
  void __RPC_STUB IProxyObject_get_Object_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetInterface_INTERFACE_DEFINED__
#define __IGetInterface_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetInterface;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetInterface : public IUnknown {
  public:
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
    virtual HRESULT WINAPI GetInterfaceInner(BSTR Interface,IDispatch **ppUnknown) = 0;
  };
#else
  typedef struct IGetInterfaceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetInterface *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetInterface *This);
      ULONG (WINAPI *Release)(IGetInterface *This);
      HRESULT (WINAPI *GetInterface)(IGetInterface *This,BSTR Interface,IDispatch **ppUnknown);
      HRESULT (WINAPI *GetInterfaceInner)(IGetInterface *This,BSTR Interface,IDispatch **ppUnknown);
    END_INTERFACE
  } IGetInterfaceVtbl;
  struct IGetInterface {
    CONST_VTBL struct IGetInterfaceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetInterface_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetInterface_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetInterface_Release(This) (This)->lpVtbl->Release(This)
#define IGetInterface_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#define IGetInterface_GetInterfaceInner(This,Interface,ppUnknown) (This)->lpVtbl->GetInterfaceInner(This,Interface,ppUnknown)
#endif
#endif
  HRESULT WINAPI IGetInterface_GetInterface_Proxy(IGetInterface *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IGetInterface_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IGetInterface_GetInterfaceInner_Proxy(IGetInterface *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IGetInterface_GetInterfaceInner_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __CDO_LIBRARY_DEFINED__
#define __CDO_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_CDO;

#ifndef __CdoErrors_MODULE_DEFINED__
#define __CdoErrors_MODULE_DEFINED__
  const LONG CDO_E_UNCAUGHT_EXCEPTION = 0x80040201;
  const LONG CDO_E_NOT_OPENED = 0x80040202;
  const LONG CDO_E_UNSUPPORTED_DATASOURCE = 0x80040203;
  const LONG CDO_E_INVALID_PROPERTYNAME = 0x80040204;
  const LONG CDO_E_PROP_UNSUPPORTED = 0x80040205;
  const LONG CDO_E_INACTIVE = 0x80040206;
  const LONG CDO_E_NO_SUPPORT_FOR_OBJECTS = 0x80040207;
  const LONG CDO_E_NOT_AVAILABLE = 0x80040208;
  const LONG CDO_E_NO_DEFAULT_DROP_DIR = 0x80040209;
  const LONG CDO_E_SMTP_SERVER_REQUIRED = 0x8004020a;
  const LONG CDO_E_NNTP_SERVER_REQUIRED = 0x8004020b;
  const LONG CDO_E_RECIPIENT_MISSING = 0x8004020c;
  const LONG CDO_E_FROM_MISSING = 0x8004020d;
  const LONG CDO_E_SENDER_REJECTED = 0x8004020e;
  const LONG CDO_E_RECIPIENTS_REJECTED = 0x8004020f;
  const LONG CDO_E_NNTP_POST_FAILED = 0x80040210;
  const LONG CDO_E_SMTP_SEND_FAILED = 0x80040211;
  const LONG CDO_E_CONNECTION_DROPPED = 0x80040212;
  const LONG CDO_E_FAILED_TO_CONNECT = 0x80040213;
  const LONG CDO_E_INVALID_POST = 0x80040214;
  const LONG CDO_E_AUTHENTICATION_FAILURE = 0x80040215;
  const LONG CDO_E_INVALID_CONTENT_TYPE = 0x80040216;
  const LONG CDO_E_LOGON_FAILURE = 0x80040217;
  const LONG CDO_E_HTTP_NOT_FOUND = 0x80040218;
  const LONG CDO_E_HTTP_FORBIDDEN = 0x80040219;
  const LONG CDO_E_HTTP_FAILED = 0x8004021a;
  const LONG CDO_E_MULTIPART_NO_DATA = 0x8004021b;
  const LONG CDO_E_INVALID_ENCODING_FOR_MULTIPART = 0x8004021c;
  const LONG CDO_E_UNSAFE_OPERATION = 0x8004021d;
  const LONG CDO_E_PROP_NOT_FOUND = 0x8004021e;
  const LONG CDO_E_INVALID_SEND_OPTION = 0x80040220;
  const LONG CDO_E_INVALID_POST_OPTION = 0x80040221;
  const LONG CDO_E_NO_PICKUP_DIR = 0x80040222;
  const LONG CDO_E_NOT_ALL_DELETED = 0x80040223;
  const LONG CDO_E_NO_METHOD = 0x80040224;
  const LONG CDO_E_PROP_READONLY = 0x80040227;
  const LONG CDO_E_PROP_CANNOT_DELETE = 0x80040228;
  const LONG CDO_E_BAD_DATA = 0x80040229;
  const LONG CDO_E_PROP_NONHEADER = 0x8004022a;
  const LONG CDO_E_INVALID_CHARSET = 0x8004022b;
  const LONG CDO_E_ADOSTREAM_NOT_BOUND = 0x8004022c;
  const LONG CDO_E_CONTENTPROPXML_NOT_FOUND = 0x8004022d;
  const LONG CDO_E_CONTENTPROPXML_WRONG_CHARSET = 0x8004022e;
  const LONG CDO_E_CONTENTPROPXML_PARSE_FAILED = 0x8004022f;
  const LONG CDO_E_CONTENTPROPXML_CONVERT_FAILED = 0x80040230;
  const LONG CDO_E_NO_DIRECTORIES_SPECIFIED = 0x80040231;
  const LONG CDO_E_DIRECTORIES_UNREACHABLE = 0x80040232;
  const LONG CDO_E_BAD_SENDER = 0x80040233;
  const LONG CDO_E_SELF_BINDING = 0x80040234;
  const LONG CDO_E_BAD_ATTENDEE_DATA = 0x80040235;
  const LONG CDO_E_ROLE_NOMORE_AVAILABLE = 0x80040236;
  const LONG CDO_E_BAD_TASKTYPE_ONASSIGN = 0x80040237;
  const LONG CDO_E_NOT_ASSIGNEDTO_USER = 0x80040238;
  const LONG CDO_E_OUTOFDATE = 0x80040239;
  const LONG CDO_E_ARGUMENT1 = 0x80044000;
  const LONG CDO_E_ARGUMENT2 = 0x80044001;
  const LONG CDO_E_ARGUMENT3 = 0x80044002;
  const LONG CDO_E_ARGUMENT4 = 0x80044003;
  const LONG CDO_E_ARGUMENT5 = 0x80044004;
  const LONG CDO_E_NOT_FOUND = 0x800cce05;
  const LONG CDO_E_INVALID_ENCODING_TYPE = 0x800cce1d;
#endif

  EXTERN_C const CLSID CLSID_Message;
#ifdef __cplusplus
  class Message;
#endif
  EXTERN_C const CLSID CLSID_Configuration;
#ifdef __cplusplus
  class Configuration;
#endif
  EXTERN_C const CLSID CLSID_DropDirectory;
#ifdef __cplusplus
  class DropDirectory;
#endif
  EXTERN_C const CLSID CLSID_SMTPConnector;
#ifdef __cplusplus
  class SMTPConnector;
#endif
  EXTERN_C const CLSID CLSID_NNTPEarlyConnector;
#ifdef __cplusplus
  class  NNTPEarlyConnector;
#endif
  EXTERN_C const CLSID CLSID_NNTPPostConnector;
#ifdef __cplusplus
  class NNTPPostConnector;
#endif
  EXTERN_C const CLSID CLSID_NNTPFinalConnector;
#ifdef __cplusplus
  class NNTPFinalConnector;
#endif
#endif
#if defined __cplusplus && !defined CDO_NO_NAMESPACE
}
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
