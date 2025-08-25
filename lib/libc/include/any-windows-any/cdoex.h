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
#include "cdoexstr.h"
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

#ifndef __IItem_FWD_DEFINED__
#define __IItem_FWD_DEFINED__
typedef struct IItem IItem;
#endif

#ifndef __IAppointment_FWD_DEFINED__
#define __IAppointment_FWD_DEFINED__
typedef struct IAppointment IAppointment;
#endif

#ifndef __ICalendarMessage_FWD_DEFINED__
#define __ICalendarMessage_FWD_DEFINED__
typedef struct ICalendarMessage ICalendarMessage;
#endif

#ifndef __IIntegers_FWD_DEFINED__
#define __IIntegers_FWD_DEFINED__
typedef struct IIntegers IIntegers;
#endif

#ifndef __IVariants_FWD_DEFINED__
#define __IVariants_FWD_DEFINED__
typedef struct IVariants IVariants;
#endif

#ifndef __IRecurrencePattern_FWD_DEFINED__
#define __IRecurrencePattern_FWD_DEFINED__
typedef struct IRecurrencePattern IRecurrencePattern;
#endif

#ifndef __IException_FWD_DEFINED__
#define __IException_FWD_DEFINED__
typedef struct IException IException;
#endif

#ifndef __IRecurrencePatterns_FWD_DEFINED__
#define __IRecurrencePatterns_FWD_DEFINED__
typedef struct IRecurrencePatterns IRecurrencePatterns;
#endif

#ifndef __IExceptions_FWD_DEFINED__
#define __IExceptions_FWD_DEFINED__
typedef struct IExceptions IExceptions;
#endif

#ifndef __ICalendarPart_FWD_DEFINED__
#define __ICalendarPart_FWD_DEFINED__
typedef struct ICalendarPart ICalendarPart;
#endif

#ifndef __ICalendarParts_FWD_DEFINED__
#define __ICalendarParts_FWD_DEFINED__
typedef struct ICalendarParts ICalendarParts;
#endif

#ifndef __IAttendee_FWD_DEFINED__
#define __IAttendee_FWD_DEFINED__
typedef struct IAttendee IAttendee;
#endif

#ifndef __IAttendees_FWD_DEFINED__
#define __IAttendees_FWD_DEFINED__
typedef struct IAttendees IAttendees;
#endif

#ifndef __IMailbox_FWD_DEFINED__
#define __IMailbox_FWD_DEFINED__
typedef struct IMailbox IMailbox;
#endif

#ifndef __IFolder_FWD_DEFINED__
#define __IFolder_FWD_DEFINED__
typedef struct IFolder IFolder;
#endif

#ifndef __IContactGroupMembers_FWD_DEFINED__
#define __IContactGroupMembers_FWD_DEFINED__
typedef struct IContactGroupMembers IContactGroupMembers;
#endif

#ifndef __IPerson_FWD_DEFINED__
#define __IPerson_FWD_DEFINED__
typedef struct IPerson IPerson;
#endif

#ifndef __IAddressee_FWD_DEFINED__
#define __IAddressee_FWD_DEFINED__
typedef struct IAddressee IAddressee;
#endif

#ifndef __IAddressees_FWD_DEFINED__
#define __IAddressees_FWD_DEFINED__
typedef struct IAddressees IAddressees;
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

#ifndef __Item_FWD_DEFINED__
#define __Item_FWD_DEFINED__
#ifdef __cplusplus
typedef class Item Item;
#else
typedef struct Item Item;
#endif
#endif

#ifndef __Appointment_FWD_DEFINED__
#define __Appointment_FWD_DEFINED__
#ifdef __cplusplus
typedef class Appointment Appointment;
#else
typedef struct Appointment Appointment;
#endif
#endif

#ifndef __CalendarMessage_FWD_DEFINED__
#define __CalendarMessage_FWD_DEFINED__
#ifdef __cplusplus
typedef class CalendarMessage CalendarMessage;
#else
typedef struct CalendarMessage CalendarMessage;
#endif
#endif

#ifndef __Folder_FWD_DEFINED__
#define __Folder_FWD_DEFINED__
#ifdef __cplusplus
typedef class Folder Folder;
#else
typedef struct Folder Folder;
#endif
#endif

#ifndef __Person_FWD_DEFINED__
#define __Person_FWD_DEFINED__
#ifdef __cplusplus
typedef class Person Person;
#else
typedef struct Person Person;
#endif
#endif

#ifndef __Attendee_FWD_DEFINED__
#define __Attendee_FWD_DEFINED__
#ifdef __cplusplus
typedef class Attendee Attendee;
#else
typedef struct Attendee Attendee;
#endif
#endif

#ifndef __Addressee_FWD_DEFINED__
#define __Addressee_FWD_DEFINED__
#ifdef __cplusplus
typedef class Addressee Addressee;
#else
typedef struct Addressee Addressee;
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
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef enum CdoAttendeeRoleValues {
    cdoRequiredParticipant = 0,cdoOptionalParticipant = 1,cdoNonParticipant = 2,cdoChair = 3
  } CdoAttendeeRoleValues;

  typedef enum CdoAttendeeStatusValues {
    cdoAccepted = 0,cdoDeclined = 1,cdoAttendeeStatusTentative = 2,cdoNeedsAction = 3,cdoDelegated = 4,cdoCompleted = 5,cdoInProgress = 6
  } CdoAttendeeStatusValues;

  typedef enum CdoComponentType {
    cdoComponentTypeUnknown = 0,cdoComponentTypeAppointment = 1
  } CdoComponentType;

  typedef enum CdoConfigSource {
    cdoDefaults = -1,cdoIIS = 1,cdoOutlookExpress = 2,cdoDirectory = 3
  } CdoConfigSource;

  typedef enum CdoDayOfWeek {
    cdoSunday = 0,cdoMonday = 1,cdoTuesday = 2,cdoWednesday = 3,cdoThursday = 4,cdoFriday = 5,cdoSaturday = 6
  } CdoDayOfWeek;

  typedef enum CdoDSNOptions {
    cdoDSNDefault = 0,cdoDSNNever = 1,cdoDSNFailure = 2,cdoDSNSuccess = 4,cdoDSNDelay = 8,cdoDSNSuccessFailOrDelay = 14
  } CdoDSNOptions;

  typedef enum CdoEventStatus {
    cdoRunNextSink = 0,cdoSkipRemainingSinks = 1
  } CdoEventStatus;

  typedef enum CdoEventType {
    cdoSMTPOnArrival = 1,cdoNNTPOnPostEarly = 2,cdoNNTPOnPost = 3,cdoNNTPOnPostFinal = 4
  } CdoEventType;

  typedef enum CdoFileAsMappingId {
    cdoMapToNone = 0,cdoMapToLastFirst = 1,cdoMapToFirstLast = 2,cdoMapToOrg = 3,cdoMapToLastFirstOrg = 4,cdoMapToOrgLastFirst = 5
  } CdoFileAsMappingId;

  typedef enum CdoFrequency {
    cdoSecondly = 1,cdoMinutely = 2,cdoHourly = 3,cdoDaily = 4,cdoWeekly = 5,cdoMonthly = 6,cdoYearly = 7
  } CdoFrequency;

  typedef enum CdoGenderValues {
    cdoGenderUnspecified = 0,cdoFemale = 1,cdoMale = 2
  } CdoGenderValues;

  typedef enum cdoImportanceValues {
    cdoLow = 0,cdoNormal = 1,cdoHigh = 2
  } cdoImportanceValues;

  typedef enum CdoInstanceTypes {
    cdoSingle = 0,cdoMaster = 1,cdoInstance = 2,cdoException = 3
  } CdoInstanceTypes;

  typedef enum CdoMailingAddressIdValues {
    cdoNoAddress = 0,cdoHomeAddress = 1,cdoBusinessAddress = 2,cdoOtherAddress = 3
  } CdoMailingAddressIdValues;

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

  typedef enum CdoPatternEndType {
    cdoNoEndDate = 0,cdoEndByInstances = 1,cdoEndByDate = 2
  } CdoPatternEndType;

  typedef
    enum CdoPostUsing
  { cdoPostUsingPickup = 1,cdoPostUsingPort = 2,cdoPostUsingExchange = 3
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

  typedef enum CdoResolvedStatus {
    cdoUnresolved = 0,cdoResolved = 1,cdoAmbiguous = 2
  } CdoResolvedStatus;

  typedef enum CdoSendUsing {
    cdoSendUsingPickup = 1,cdoSendUsingPort = 2,cdoSendUsingExchange = 3
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
    cdoArab = 74,cdoTaipei = 75,cdoSydney2000 = 76,cdoInvalidTimeZone = 77
  } CdoTimeZoneId;

  typedef enum cdoURLSourceValues {
    cdoExchangeServerURL = 0,cdoClientStoreURL = 1
  } cdoURLSourceValues;

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
  public:
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

  extern RPC_IF_HANDLE __MIDL_itf_cdo_0295_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_cdo_0295_v0_0_s_ifspec;

#ifndef __IItem_INTERFACE_DEFINED__
#define __IItem_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IItem;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IItem : public IDispatch {
  public:
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
    virtual HRESULT WINAPI GetStream(_Stream **ppStream) = 0;
    virtual HRESULT WINAPI get_ChildCount(__LONG32 *varChildCount) = 0;
    virtual HRESULT WINAPI get_Configuration(IConfiguration **pConfiguration) = 0;
    virtual HRESULT WINAPI put_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI putref_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI get_ContentClass(BSTR *pContentClass) = 0;
    virtual HRESULT WINAPI put_ContentClass(BSTR varContentClass) = 0;
    virtual HRESULT WINAPI get_CreationDate(DATE *varCreationDate) = 0;
    virtual HRESULT WINAPI get_DataSource(IDataSource **varDataSource) = 0;
    virtual HRESULT WINAPI get_DisplayName(BSTR *varDisplayName) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_IsCollection(VARIANT_BOOL *varIsCollection) = 0;
    virtual HRESULT WINAPI get_IsHidden(VARIANT_BOOL *pIsHidden) = 0;
    virtual HRESULT WINAPI put_IsHidden(VARIANT_BOOL varIsHidden) = 0;
    virtual HRESULT WINAPI get_IsStructuredDocument(VARIANT_BOOL *varIsStructuredDocument) = 0;
    virtual HRESULT WINAPI get_LastModified(DATE *varLastModified) = 0;
    virtual HRESULT WINAPI get_ObjectCount(__LONG32 *varObjectCount) = 0;
    virtual HRESULT WINAPI get_ParentURL(BSTR *varParentURL) = 0;
    virtual HRESULT WINAPI get_VisibleCount(__LONG32 *varVisibleCount) = 0;
  };
#else
  typedef struct IItemVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IItem *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IItem *This);
      ULONG (WINAPI *Release)(IItem *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IItem *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IItem *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IItem *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IItem *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetInterface)(IItem *This,BSTR Interface,IDispatch **ppUnknown);
      HRESULT (WINAPI *GetStream)(IItem *This,_Stream **ppStream);
      HRESULT (WINAPI *get_ChildCount)(IItem *This,__LONG32 *varChildCount);
      HRESULT (WINAPI *get_Configuration)(IItem *This,IConfiguration **pConfiguration);
      HRESULT (WINAPI *put_Configuration)(IItem *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *putref_Configuration)(IItem *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *get_ContentClass)(IItem *This,BSTR *pContentClass);
      HRESULT (WINAPI *put_ContentClass)(IItem *This,BSTR varContentClass);
      HRESULT (WINAPI *get_CreationDate)(IItem *This,DATE *varCreationDate);
      HRESULT (WINAPI *get_DataSource)(IItem *This,IDataSource **varDataSource);
      HRESULT (WINAPI *get_DisplayName)(IItem *This,BSTR *varDisplayName);
      HRESULT (WINAPI *get_Fields)(IItem *This,Fields **varFields);
      HRESULT (WINAPI *get_IsCollection)(IItem *This,VARIANT_BOOL *varIsCollection);
      HRESULT (WINAPI *get_IsHidden)(IItem *This,VARIANT_BOOL *pIsHidden);
      HRESULT (WINAPI *put_IsHidden)(IItem *This,VARIANT_BOOL varIsHidden);
      HRESULT (WINAPI *get_IsStructuredDocument)(IItem *This,VARIANT_BOOL *varIsStructuredDocument);
      HRESULT (WINAPI *get_LastModified)(IItem *This,DATE *varLastModified);
      HRESULT (WINAPI *get_ObjectCount)(IItem *This,__LONG32 *varObjectCount);
      HRESULT (WINAPI *get_ParentURL)(IItem *This,BSTR *varParentURL);
      HRESULT (WINAPI *get_VisibleCount)(IItem *This,__LONG32 *varVisibleCount);
    END_INTERFACE
  } IItemVtbl;
  struct IItem {
    CONST_VTBL struct IItemVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IItem_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IItem_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IItem_Release(This) (This)->lpVtbl->Release(This)
#define IItem_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IItem_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IItem_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IItem_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IItem_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#define IItem_GetStream(This,ppStream) (This)->lpVtbl->GetStream(This,ppStream)
#define IItem_get_ChildCount(This,varChildCount) (This)->lpVtbl->get_ChildCount(This,varChildCount)
#define IItem_get_Configuration(This,pConfiguration) (This)->lpVtbl->get_Configuration(This,pConfiguration)
#define IItem_put_Configuration(This,varConfiguration) (This)->lpVtbl->put_Configuration(This,varConfiguration)
#define IItem_putref_Configuration(This,varConfiguration) (This)->lpVtbl->putref_Configuration(This,varConfiguration)
#define IItem_get_ContentClass(This,pContentClass) (This)->lpVtbl->get_ContentClass(This,pContentClass)
#define IItem_put_ContentClass(This,varContentClass) (This)->lpVtbl->put_ContentClass(This,varContentClass)
#define IItem_get_CreationDate(This,varCreationDate) (This)->lpVtbl->get_CreationDate(This,varCreationDate)
#define IItem_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IItem_get_DisplayName(This,varDisplayName) (This)->lpVtbl->get_DisplayName(This,varDisplayName)
#define IItem_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IItem_get_IsCollection(This,varIsCollection) (This)->lpVtbl->get_IsCollection(This,varIsCollection)
#define IItem_get_IsHidden(This,pIsHidden) (This)->lpVtbl->get_IsHidden(This,pIsHidden)
#define IItem_put_IsHidden(This,varIsHidden) (This)->lpVtbl->put_IsHidden(This,varIsHidden)
#define IItem_get_IsStructuredDocument(This,varIsStructuredDocument) (This)->lpVtbl->get_IsStructuredDocument(This,varIsStructuredDocument)
#define IItem_get_LastModified(This,varLastModified) (This)->lpVtbl->get_LastModified(This,varLastModified)
#define IItem_get_ObjectCount(This,varObjectCount) (This)->lpVtbl->get_ObjectCount(This,varObjectCount)
#define IItem_get_ParentURL(This,varParentURL) (This)->lpVtbl->get_ParentURL(This,varParentURL)
#define IItem_get_VisibleCount(This,varVisibleCount) (This)->lpVtbl->get_VisibleCount(This,varVisibleCount)
#endif
#endif
  HRESULT WINAPI IItem_GetInterface_Proxy(IItem *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IItem_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_GetStream_Proxy(IItem *This,_Stream **ppStream);
  void __RPC_STUB IItem_GetStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_ChildCount_Proxy(IItem *This,__LONG32 *varChildCount);
  void __RPC_STUB IItem_get_ChildCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_Configuration_Proxy(IItem *This,IConfiguration **pConfiguration);
  void __RPC_STUB IItem_get_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_put_Configuration_Proxy(IItem *This,IConfiguration *varConfiguration);
  void __RPC_STUB IItem_put_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_putref_Configuration_Proxy(IItem *This,IConfiguration *varConfiguration);
  void __RPC_STUB IItem_putref_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_ContentClass_Proxy(IItem *This,BSTR *pContentClass);
  void __RPC_STUB IItem_get_ContentClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_put_ContentClass_Proxy(IItem *This,BSTR varContentClass);
  void __RPC_STUB IItem_put_ContentClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_CreationDate_Proxy(IItem *This,DATE *varCreationDate);
  void __RPC_STUB IItem_get_CreationDate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_DataSource_Proxy(IItem *This,IDataSource **varDataSource);
  void __RPC_STUB IItem_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_DisplayName_Proxy(IItem *This,BSTR *varDisplayName);
  void __RPC_STUB IItem_get_DisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_Fields_Proxy(IItem *This,Fields **varFields);
  void __RPC_STUB IItem_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_IsCollection_Proxy(IItem *This,VARIANT_BOOL *varIsCollection);
  void __RPC_STUB IItem_get_IsCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_IsHidden_Proxy(IItem *This,VARIANT_BOOL *pIsHidden);
  void __RPC_STUB IItem_get_IsHidden_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_put_IsHidden_Proxy(IItem *This,VARIANT_BOOL varIsHidden);
  void __RPC_STUB IItem_put_IsHidden_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_IsStructuredDocument_Proxy(IItem *This,VARIANT_BOOL *varIsStructuredDocument);
  void __RPC_STUB IItem_get_IsStructuredDocument_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_LastModified_Proxy(IItem *This,DATE *varLastModified);
  void __RPC_STUB IItem_get_LastModified_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_ObjectCount_Proxy(IItem *This,__LONG32 *varObjectCount);
  void __RPC_STUB IItem_get_ObjectCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_ParentURL_Proxy(IItem *This,BSTR *varParentURL);
  void __RPC_STUB IItem_get_ParentURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IItem_get_VisibleCount_Proxy(IItem *This,__LONG32 *varVisibleCount);
  void __RPC_STUB IItem_get_VisibleCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAppointment_INTERFACE_DEFINED__
#define __IAppointment_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAppointment;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAppointment : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Attachments(IBodyParts **varAttachments) = 0;
    virtual HRESULT WINAPI get_Attendees(IAttendees **varAttendees) = 0;
    virtual HRESULT WINAPI get_BusyStatus(BSTR *pBusyStatus) = 0;
    virtual HRESULT WINAPI put_BusyStatus(BSTR varBusyStatus) = 0;
    virtual HRESULT WINAPI get_Keywords(VARIANT *pKeywords) = 0;
    virtual HRESULT WINAPI put_Keywords(VARIANT varKeywords) = 0;
    virtual HRESULT WINAPI get_Configuration(IConfiguration **pConfiguration) = 0;
    virtual HRESULT WINAPI put_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI putref_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI get_Contact(BSTR *pContact) = 0;
    virtual HRESULT WINAPI put_Contact(BSTR varContact) = 0;
    virtual HRESULT WINAPI get_ContactURL(BSTR *pContactURL) = 0;
    virtual HRESULT WINAPI put_ContactURL(BSTR varContactURL) = 0;
    virtual HRESULT WINAPI get_DataSource(IDataSource **varDataSource) = 0;
    virtual HRESULT WINAPI get_EndTime(DATE *pEndTime) = 0;
    virtual HRESULT WINAPI put_EndTime(DATE varEndTime) = 0;
    virtual HRESULT WINAPI get_Exceptions(IExceptions **varExceptions) = 0;
    virtual HRESULT WINAPI get_Duration(__LONG32 *pDuration) = 0;
    virtual HRESULT WINAPI put_Duration(__LONG32 varDuration) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_Location(BSTR *pLocation) = 0;
    virtual HRESULT WINAPI put_Location(BSTR varLocation) = 0;
    virtual HRESULT WINAPI get_LocationURL(BSTR *pLocationURL) = 0;
    virtual HRESULT WINAPI put_LocationURL(BSTR varLocationURL) = 0;
    virtual HRESULT WINAPI get_Priority(__LONG32 *pPriority) = 0;
    virtual HRESULT WINAPI put_Priority(__LONG32 varPriority) = 0;
    virtual HRESULT WINAPI get_ReplyTime(DATE *varReplyTime) = 0;
    virtual HRESULT WINAPI get_Resources(BSTR *pResources) = 0;
    virtual HRESULT WINAPI put_Resources(BSTR varResources) = 0;
    virtual HRESULT WINAPI get_ResponseRequested(VARIANT_BOOL *pResponseRequested) = 0;
    virtual HRESULT WINAPI put_ResponseRequested(VARIANT_BOOL varResponseRequested) = 0;
    virtual HRESULT WINAPI get_RecurrencePatterns(IRecurrencePatterns **varRecurrencePatterns) = 0;
    virtual HRESULT WINAPI get_Sensitivity(__LONG32 *pSensitivity) = 0;
    virtual HRESULT WINAPI put_Sensitivity(__LONG32 varSensitivity) = 0;
    virtual HRESULT WINAPI get_StartTime(DATE *pStartTime) = 0;
    virtual HRESULT WINAPI put_StartTime(DATE varStartTime) = 0;
    virtual HRESULT WINAPI get_MeetingStatus(BSTR *pMeetingStatus) = 0;
    virtual HRESULT WINAPI put_MeetingStatus(BSTR varMeetingStatus) = 0;
    virtual HRESULT WINAPI get_Subject(BSTR *pSubject) = 0;
    virtual HRESULT WINAPI put_Subject(BSTR varSubject) = 0;
    virtual HRESULT WINAPI get_Transparent(BSTR *pTransparent) = 0;
    virtual HRESULT WINAPI put_Transparent(BSTR varTransparent) = 0;
    virtual HRESULT WINAPI get_BodyPart(IBodyPart **varBodyPart) = 0;
    virtual HRESULT WINAPI get_GEOLatitude(double *pGEOLatitude) = 0;
    virtual HRESULT WINAPI put_GEOLatitude(double varGEOLatitude) = 0;
    virtual HRESULT WINAPI get_GEOLongitude(double *pGEOLongitude) = 0;
    virtual HRESULT WINAPI put_GEOLongitude(double varGEOLongitude) = 0;
    virtual HRESULT WINAPI get_AllDayEvent(VARIANT_BOOL *pAllDayEvent) = 0;
    virtual HRESULT WINAPI put_AllDayEvent(VARIANT_BOOL varAllDayEvent) = 0;
    virtual HRESULT WINAPI get_TextBody(BSTR *pTextBody) = 0;
    virtual HRESULT WINAPI put_TextBody(BSTR varTextBody) = 0;
    virtual HRESULT WINAPI get_ResponseText(BSTR *pResponseText) = 0;
    virtual HRESULT WINAPI put_ResponseText(BSTR varResponseText) = 0;
    virtual HRESULT WINAPI Accept(ICalendarMessage **Response) = 0;
    virtual HRESULT WINAPI AcceptTentative(ICalendarMessage **Response) = 0;
    virtual HRESULT WINAPI Cancel(BSTR EmailList,VARIANT_BOOL CleanupCalendar,BSTR UserName,BSTR Password,ICalendarMessage **Request) = 0;
    virtual HRESULT WINAPI CreateRequest(ICalendarMessage **Request) = 0;
    virtual HRESULT WINAPI Decline(VARIANT_BOOL CleanupCalendar,BSTR UserName,BSTR Password,ICalendarMessage **Response) = 0;
    virtual HRESULT WINAPI Invite(BSTR EmailList,ICalendarMessage **Request) = 0;
    virtual HRESULT WINAPI Publish(ICalendarMessage **Request) = 0;
    virtual HRESULT WINAPI GetFirstInstance(DATE MinDate,DATE MaxDate,IAppointment **Appointment) = 0;
    virtual HRESULT WINAPI GetNextInstance(IAppointment **Appointment) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
    virtual HRESULT WINAPI GetRecurringMaster(BSTR CalendarLocation,BSTR UserName,BSTR Password,IAppointment **Appointment) = 0;
  };
#else
  typedef struct IAppointmentVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAppointment *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAppointment *This);
      ULONG (WINAPI *Release)(IAppointment *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAppointment *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAppointment *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAppointment *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAppointment *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Attachments)(IAppointment *This,IBodyParts **varAttachments);
      HRESULT (WINAPI *get_Attendees)(IAppointment *This,IAttendees **varAttendees);
      HRESULT (WINAPI *get_BusyStatus)(IAppointment *This,BSTR *pBusyStatus);
      HRESULT (WINAPI *put_BusyStatus)(IAppointment *This,BSTR varBusyStatus);
      HRESULT (WINAPI *get_Keywords)(IAppointment *This,VARIANT *pKeywords);
      HRESULT (WINAPI *put_Keywords)(IAppointment *This,VARIANT varKeywords);
      HRESULT (WINAPI *get_Configuration)(IAppointment *This,IConfiguration **pConfiguration);
      HRESULT (WINAPI *put_Configuration)(IAppointment *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *putref_Configuration)(IAppointment *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *get_Contact)(IAppointment *This,BSTR *pContact);
      HRESULT (WINAPI *put_Contact)(IAppointment *This,BSTR varContact);
      HRESULT (WINAPI *get_ContactURL)(IAppointment *This,BSTR *pContactURL);
      HRESULT (WINAPI *put_ContactURL)(IAppointment *This,BSTR varContactURL);
      HRESULT (WINAPI *get_DataSource)(IAppointment *This,IDataSource **varDataSource);
      HRESULT (WINAPI *get_EndTime)(IAppointment *This,DATE *pEndTime);
      HRESULT (WINAPI *put_EndTime)(IAppointment *This,DATE varEndTime);
      HRESULT (WINAPI *get_Exceptions)(IAppointment *This,IExceptions **varExceptions);
      HRESULT (WINAPI *get_Duration)(IAppointment *This,__LONG32 *pDuration);
      HRESULT (WINAPI *put_Duration)(IAppointment *This,__LONG32 varDuration);
      HRESULT (WINAPI *get_Fields)(IAppointment *This,Fields **varFields);
      HRESULT (WINAPI *get_Location)(IAppointment *This,BSTR *pLocation);
      HRESULT (WINAPI *put_Location)(IAppointment *This,BSTR varLocation);
      HRESULT (WINAPI *get_LocationURL)(IAppointment *This,BSTR *pLocationURL);
      HRESULT (WINAPI *put_LocationURL)(IAppointment *This,BSTR varLocationURL);
      HRESULT (WINAPI *get_Priority)(IAppointment *This,__LONG32 *pPriority);
      HRESULT (WINAPI *put_Priority)(IAppointment *This,__LONG32 varPriority);
      HRESULT (WINAPI *get_ReplyTime)(IAppointment *This,DATE *varReplyTime);
      HRESULT (WINAPI *get_Resources)(IAppointment *This,BSTR *pResources);
      HRESULT (WINAPI *put_Resources)(IAppointment *This,BSTR varResources);
      HRESULT (WINAPI *get_ResponseRequested)(IAppointment *This,VARIANT_BOOL *pResponseRequested);
      HRESULT (WINAPI *put_ResponseRequested)(IAppointment *This,VARIANT_BOOL varResponseRequested);
      HRESULT (WINAPI *get_RecurrencePatterns)(IAppointment *This,IRecurrencePatterns **varRecurrencePatterns);
      HRESULT (WINAPI *get_Sensitivity)(IAppointment *This,__LONG32 *pSensitivity);
      HRESULT (WINAPI *put_Sensitivity)(IAppointment *This,__LONG32 varSensitivity);
      HRESULT (WINAPI *get_StartTime)(IAppointment *This,DATE *pStartTime);
      HRESULT (WINAPI *put_StartTime)(IAppointment *This,DATE varStartTime);
      HRESULT (WINAPI *get_MeetingStatus)(IAppointment *This,BSTR *pMeetingStatus);
      HRESULT (WINAPI *put_MeetingStatus)(IAppointment *This,BSTR varMeetingStatus);
      HRESULT (WINAPI *get_Subject)(IAppointment *This,BSTR *pSubject);
      HRESULT (WINAPI *put_Subject)(IAppointment *This,BSTR varSubject);
      HRESULT (WINAPI *get_Transparent)(IAppointment *This,BSTR *pTransparent);
      HRESULT (WINAPI *put_Transparent)(IAppointment *This,BSTR varTransparent);
      HRESULT (WINAPI *get_BodyPart)(IAppointment *This,IBodyPart **varBodyPart);
      HRESULT (WINAPI *get_GEOLatitude)(IAppointment *This,double *pGEOLatitude);
      HRESULT (WINAPI *put_GEOLatitude)(IAppointment *This,double varGEOLatitude);
      HRESULT (WINAPI *get_GEOLongitude)(IAppointment *This,double *pGEOLongitude);
      HRESULT (WINAPI *put_GEOLongitude)(IAppointment *This,double varGEOLongitude);
      HRESULT (WINAPI *get_AllDayEvent)(IAppointment *This,VARIANT_BOOL *pAllDayEvent);
      HRESULT (WINAPI *put_AllDayEvent)(IAppointment *This,VARIANT_BOOL varAllDayEvent);
      HRESULT (WINAPI *get_TextBody)(IAppointment *This,BSTR *pTextBody);
      HRESULT (WINAPI *put_TextBody)(IAppointment *This,BSTR varTextBody);
      HRESULT (WINAPI *get_ResponseText)(IAppointment *This,BSTR *pResponseText);
      HRESULT (WINAPI *put_ResponseText)(IAppointment *This,BSTR varResponseText);
      HRESULT (WINAPI *Accept)(IAppointment *This,ICalendarMessage **Response);
      HRESULT (WINAPI *AcceptTentative)(IAppointment *This,ICalendarMessage **Response);
      HRESULT (WINAPI *Cancel)(IAppointment *This,BSTR EmailList,VARIANT_BOOL CleanupCalendar,BSTR UserName,BSTR Password,ICalendarMessage **Request);
      HRESULT (WINAPI *CreateRequest)(IAppointment *This,ICalendarMessage **Request);
      HRESULT (WINAPI *Decline)(IAppointment *This,VARIANT_BOOL CleanupCalendar,BSTR UserName,BSTR Password,ICalendarMessage **Response);
      HRESULT (WINAPI *Invite)(IAppointment *This,BSTR EmailList,ICalendarMessage **Request);
      HRESULT (WINAPI *Publish)(IAppointment *This,ICalendarMessage **Request);
      HRESULT (WINAPI *GetFirstInstance)(IAppointment *This,DATE MinDate,DATE MaxDate,IAppointment **Appointment);
      HRESULT (WINAPI *GetNextInstance)(IAppointment *This,IAppointment **Appointment);
      HRESULT (WINAPI *GetInterface)(IAppointment *This,BSTR Interface,IDispatch **ppUnknown);
      HRESULT (WINAPI *GetRecurringMaster)(IAppointment *This,BSTR CalendarLocation,BSTR UserName,BSTR Password,IAppointment **Appointment);
    END_INTERFACE
  } IAppointmentVtbl;
  struct IAppointment {
    CONST_VTBL struct IAppointmentVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAppointment_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAppointment_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAppointment_Release(This) (This)->lpVtbl->Release(This)
#define IAppointment_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAppointment_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAppointment_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAppointment_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAppointment_get_Attachments(This,varAttachments) (This)->lpVtbl->get_Attachments(This,varAttachments)
#define IAppointment_get_Attendees(This,varAttendees) (This)->lpVtbl->get_Attendees(This,varAttendees)
#define IAppointment_get_BusyStatus(This,pBusyStatus) (This)->lpVtbl->get_BusyStatus(This,pBusyStatus)
#define IAppointment_put_BusyStatus(This,varBusyStatus) (This)->lpVtbl->put_BusyStatus(This,varBusyStatus)
#define IAppointment_get_Keywords(This,pKeywords) (This)->lpVtbl->get_Keywords(This,pKeywords)
#define IAppointment_put_Keywords(This,varKeywords) (This)->lpVtbl->put_Keywords(This,varKeywords)
#define IAppointment_get_Configuration(This,pConfiguration) (This)->lpVtbl->get_Configuration(This,pConfiguration)
#define IAppointment_put_Configuration(This,varConfiguration) (This)->lpVtbl->put_Configuration(This,varConfiguration)
#define IAppointment_putref_Configuration(This,varConfiguration) (This)->lpVtbl->putref_Configuration(This,varConfiguration)
#define IAppointment_get_Contact(This,pContact) (This)->lpVtbl->get_Contact(This,pContact)
#define IAppointment_put_Contact(This,varContact) (This)->lpVtbl->put_Contact(This,varContact)
#define IAppointment_get_ContactURL(This,pContactURL) (This)->lpVtbl->get_ContactURL(This,pContactURL)
#define IAppointment_put_ContactURL(This,varContactURL) (This)->lpVtbl->put_ContactURL(This,varContactURL)
#define IAppointment_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IAppointment_get_EndTime(This,pEndTime) (This)->lpVtbl->get_EndTime(This,pEndTime)
#define IAppointment_put_EndTime(This,varEndTime) (This)->lpVtbl->put_EndTime(This,varEndTime)
#define IAppointment_get_Exceptions(This,varExceptions) (This)->lpVtbl->get_Exceptions(This,varExceptions)
#define IAppointment_get_Duration(This,pDuration) (This)->lpVtbl->get_Duration(This,pDuration)
#define IAppointment_put_Duration(This,varDuration) (This)->lpVtbl->put_Duration(This,varDuration)
#define IAppointment_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IAppointment_get_Location(This,pLocation) (This)->lpVtbl->get_Location(This,pLocation)
#define IAppointment_put_Location(This,varLocation) (This)->lpVtbl->put_Location(This,varLocation)
#define IAppointment_get_LocationURL(This,pLocationURL) (This)->lpVtbl->get_LocationURL(This,pLocationURL)
#define IAppointment_put_LocationURL(This,varLocationURL) (This)->lpVtbl->put_LocationURL(This,varLocationURL)
#define IAppointment_get_Priority(This,pPriority) (This)->lpVtbl->get_Priority(This,pPriority)
#define IAppointment_put_Priority(This,varPriority) (This)->lpVtbl->put_Priority(This,varPriority)
#define IAppointment_get_ReplyTime(This,varReplyTime) (This)->lpVtbl->get_ReplyTime(This,varReplyTime)
#define IAppointment_get_Resources(This,pResources) (This)->lpVtbl->get_Resources(This,pResources)
#define IAppointment_put_Resources(This,varResources) (This)->lpVtbl->put_Resources(This,varResources)
#define IAppointment_get_ResponseRequested(This,pResponseRequested) (This)->lpVtbl->get_ResponseRequested(This,pResponseRequested)
#define IAppointment_put_ResponseRequested(This,varResponseRequested) (This)->lpVtbl->put_ResponseRequested(This,varResponseRequested)
#define IAppointment_get_RecurrencePatterns(This,varRecurrencePatterns) (This)->lpVtbl->get_RecurrencePatterns(This,varRecurrencePatterns)
#define IAppointment_get_Sensitivity(This,pSensitivity) (This)->lpVtbl->get_Sensitivity(This,pSensitivity)
#define IAppointment_put_Sensitivity(This,varSensitivity) (This)->lpVtbl->put_Sensitivity(This,varSensitivity)
#define IAppointment_get_StartTime(This,pStartTime) (This)->lpVtbl->get_StartTime(This,pStartTime)
#define IAppointment_put_StartTime(This,varStartTime) (This)->lpVtbl->put_StartTime(This,varStartTime)
#define IAppointment_get_MeetingStatus(This,pMeetingStatus) (This)->lpVtbl->get_MeetingStatus(This,pMeetingStatus)
#define IAppointment_put_MeetingStatus(This,varMeetingStatus) (This)->lpVtbl->put_MeetingStatus(This,varMeetingStatus)
#define IAppointment_get_Subject(This,pSubject) (This)->lpVtbl->get_Subject(This,pSubject)
#define IAppointment_put_Subject(This,varSubject) (This)->lpVtbl->put_Subject(This,varSubject)
#define IAppointment_get_Transparent(This,pTransparent) (This)->lpVtbl->get_Transparent(This,pTransparent)
#define IAppointment_put_Transparent(This,varTransparent) (This)->lpVtbl->put_Transparent(This,varTransparent)
#define IAppointment_get_BodyPart(This,varBodyPart) (This)->lpVtbl->get_BodyPart(This,varBodyPart)
#define IAppointment_get_GEOLatitude(This,pGEOLatitude) (This)->lpVtbl->get_GEOLatitude(This,pGEOLatitude)
#define IAppointment_put_GEOLatitude(This,varGEOLatitude) (This)->lpVtbl->put_GEOLatitude(This,varGEOLatitude)
#define IAppointment_get_GEOLongitude(This,pGEOLongitude) (This)->lpVtbl->get_GEOLongitude(This,pGEOLongitude)
#define IAppointment_put_GEOLongitude(This,varGEOLongitude) (This)->lpVtbl->put_GEOLongitude(This,varGEOLongitude)
#define IAppointment_get_AllDayEvent(This,pAllDayEvent) (This)->lpVtbl->get_AllDayEvent(This,pAllDayEvent)
#define IAppointment_put_AllDayEvent(This,varAllDayEvent) (This)->lpVtbl->put_AllDayEvent(This,varAllDayEvent)
#define IAppointment_get_TextBody(This,pTextBody) (This)->lpVtbl->get_TextBody(This,pTextBody)
#define IAppointment_put_TextBody(This,varTextBody) (This)->lpVtbl->put_TextBody(This,varTextBody)
#define IAppointment_get_ResponseText(This,pResponseText) (This)->lpVtbl->get_ResponseText(This,pResponseText)
#define IAppointment_put_ResponseText(This,varResponseText) (This)->lpVtbl->put_ResponseText(This,varResponseText)
#define IAppointment_Accept(This,Response) (This)->lpVtbl->Accept(This,Response)
#define IAppointment_AcceptTentative(This,Response) (This)->lpVtbl->AcceptTentative(This,Response)
#define IAppointment_Cancel(This,EmailList,CleanupCalendar,UserName,Password,Request) (This)->lpVtbl->Cancel(This,EmailList,CleanupCalendar,UserName,Password,Request)
#define IAppointment_CreateRequest(This,Request) (This)->lpVtbl->CreateRequest(This,Request)
#define IAppointment_Decline(This,CleanupCalendar,UserName,Password,Response) (This)->lpVtbl->Decline(This,CleanupCalendar,UserName,Password,Response)
#define IAppointment_Invite(This,EmailList,Request) (This)->lpVtbl->Invite(This,EmailList,Request)
#define IAppointment_Publish(This,Request) (This)->lpVtbl->Publish(This,Request)
#define IAppointment_GetFirstInstance(This,MinDate,MaxDate,Appointment) (This)->lpVtbl->GetFirstInstance(This,MinDate,MaxDate,Appointment)
#define IAppointment_GetNextInstance(This,Appointment) (This)->lpVtbl->GetNextInstance(This,Appointment)
#define IAppointment_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#define IAppointment_GetRecurringMaster(This,CalendarLocation,UserName,Password,Appointment) (This)->lpVtbl->GetRecurringMaster(This,CalendarLocation,UserName,Password,Appointment)
#endif
#endif
  HRESULT WINAPI IAppointment_get_Attachments_Proxy(IAppointment *This,IBodyParts **varAttachments);
  void __RPC_STUB IAppointment_get_Attachments_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Attendees_Proxy(IAppointment *This,IAttendees **varAttendees);
  void __RPC_STUB IAppointment_get_Attendees_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_BusyStatus_Proxy(IAppointment *This,BSTR *pBusyStatus);
  void __RPC_STUB IAppointment_get_BusyStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_BusyStatus_Proxy(IAppointment *This,BSTR varBusyStatus);
  void __RPC_STUB IAppointment_put_BusyStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Keywords_Proxy(IAppointment *This,VARIANT *pKeywords);
  void __RPC_STUB IAppointment_get_Keywords_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_Keywords_Proxy(IAppointment *This,VARIANT varKeywords);
  void __RPC_STUB IAppointment_put_Keywords_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Configuration_Proxy(IAppointment *This,IConfiguration **pConfiguration);
  void __RPC_STUB IAppointment_get_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_Configuration_Proxy(IAppointment *This,IConfiguration *varConfiguration);
  void __RPC_STUB IAppointment_put_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_putref_Configuration_Proxy(IAppointment *This,IConfiguration *varConfiguration);
  void __RPC_STUB IAppointment_putref_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Contact_Proxy(IAppointment *This,BSTR *pContact);
  void __RPC_STUB IAppointment_get_Contact_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_Contact_Proxy(IAppointment *This,BSTR varContact);
  void __RPC_STUB IAppointment_put_Contact_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_ContactURL_Proxy(IAppointment *This,BSTR *pContactURL);
  void __RPC_STUB IAppointment_get_ContactURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_ContactURL_Proxy(IAppointment *This,BSTR varContactURL);
  void __RPC_STUB IAppointment_put_ContactURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_DataSource_Proxy(IAppointment *This,IDataSource **varDataSource);
  void __RPC_STUB IAppointment_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_EndTime_Proxy(IAppointment *This,DATE *pEndTime);
  void __RPC_STUB IAppointment_get_EndTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_EndTime_Proxy(IAppointment *This,DATE varEndTime);
  void __RPC_STUB IAppointment_put_EndTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Exceptions_Proxy(IAppointment *This,IExceptions **varExceptions);
  void __RPC_STUB IAppointment_get_Exceptions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Duration_Proxy(IAppointment *This,__LONG32 *pDuration);
  void __RPC_STUB IAppointment_get_Duration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_Duration_Proxy(IAppointment *This,__LONG32 varDuration);
  void __RPC_STUB IAppointment_put_Duration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Fields_Proxy(IAppointment *This,Fields **varFields);
  void __RPC_STUB IAppointment_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Location_Proxy(IAppointment *This,BSTR *pLocation);
  void __RPC_STUB IAppointment_get_Location_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_Location_Proxy(IAppointment *This,BSTR varLocation);
  void __RPC_STUB IAppointment_put_Location_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_LocationURL_Proxy(IAppointment *This,BSTR *pLocationURL);
  void __RPC_STUB IAppointment_get_LocationURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_LocationURL_Proxy(IAppointment *This,BSTR varLocationURL);
  void __RPC_STUB IAppointment_put_LocationURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Priority_Proxy(IAppointment *This,__LONG32 *pPriority);
  void __RPC_STUB IAppointment_get_Priority_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_Priority_Proxy(IAppointment *This,__LONG32 varPriority);
  void __RPC_STUB IAppointment_put_Priority_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_ReplyTime_Proxy(IAppointment *This,DATE *varReplyTime);
  void __RPC_STUB IAppointment_get_ReplyTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Resources_Proxy(IAppointment *This,BSTR *pResources);
  void __RPC_STUB IAppointment_get_Resources_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_Resources_Proxy(IAppointment *This,BSTR varResources);
  void __RPC_STUB IAppointment_put_Resources_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_ResponseRequested_Proxy(IAppointment *This,VARIANT_BOOL *pResponseRequested);
  void __RPC_STUB IAppointment_get_ResponseRequested_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_ResponseRequested_Proxy(IAppointment *This,VARIANT_BOOL varResponseRequested);
  void __RPC_STUB IAppointment_put_ResponseRequested_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_RecurrencePatterns_Proxy(IAppointment *This,IRecurrencePatterns **varRecurrencePatterns);
  void __RPC_STUB IAppointment_get_RecurrencePatterns_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Sensitivity_Proxy(IAppointment *This,__LONG32 *pSensitivity);
  void __RPC_STUB IAppointment_get_Sensitivity_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_Sensitivity_Proxy(IAppointment *This,__LONG32 varSensitivity);
  void __RPC_STUB IAppointment_put_Sensitivity_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_StartTime_Proxy(IAppointment *This,DATE *pStartTime);
  void __RPC_STUB IAppointment_get_StartTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_StartTime_Proxy(IAppointment *This,DATE varStartTime);
  void __RPC_STUB IAppointment_put_StartTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_MeetingStatus_Proxy(IAppointment *This,BSTR *pMeetingStatus);
  void __RPC_STUB IAppointment_get_MeetingStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_MeetingStatus_Proxy(IAppointment *This,BSTR varMeetingStatus);
  void __RPC_STUB IAppointment_put_MeetingStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Subject_Proxy(IAppointment *This,BSTR *pSubject);
  void __RPC_STUB IAppointment_get_Subject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_Subject_Proxy(IAppointment *This,BSTR varSubject);
  void __RPC_STUB IAppointment_put_Subject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_Transparent_Proxy(IAppointment *This,BSTR *pTransparent);
  void __RPC_STUB IAppointment_get_Transparent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_Transparent_Proxy(IAppointment *This,BSTR varTransparent);
  void __RPC_STUB IAppointment_put_Transparent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_BodyPart_Proxy(IAppointment *This,IBodyPart **varBodyPart);
  void __RPC_STUB IAppointment_get_BodyPart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_GEOLatitude_Proxy(IAppointment *This,double *pGEOLatitude);
  void __RPC_STUB IAppointment_get_GEOLatitude_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_GEOLatitude_Proxy(IAppointment *This,double varGEOLatitude);
  void __RPC_STUB IAppointment_put_GEOLatitude_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_GEOLongitude_Proxy(IAppointment *This,double *pGEOLongitude);
  void __RPC_STUB IAppointment_get_GEOLongitude_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_GEOLongitude_Proxy(IAppointment *This,double varGEOLongitude);
  void __RPC_STUB IAppointment_put_GEOLongitude_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_AllDayEvent_Proxy(IAppointment *This,VARIANT_BOOL *pAllDayEvent);
  void __RPC_STUB IAppointment_get_AllDayEvent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_AllDayEvent_Proxy(IAppointment *This,VARIANT_BOOL varAllDayEvent);
  void __RPC_STUB IAppointment_put_AllDayEvent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_TextBody_Proxy(IAppointment *This,BSTR *pTextBody);
  void __RPC_STUB IAppointment_get_TextBody_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_TextBody_Proxy(IAppointment *This,BSTR varTextBody);
  void __RPC_STUB IAppointment_put_TextBody_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_get_ResponseText_Proxy(IAppointment *This,BSTR *pResponseText);
  void __RPC_STUB IAppointment_get_ResponseText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_put_ResponseText_Proxy(IAppointment *This,BSTR varResponseText);
  void __RPC_STUB IAppointment_put_ResponseText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_Accept_Proxy(IAppointment *This,ICalendarMessage **Response);
  void __RPC_STUB IAppointment_Accept_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_AcceptTentative_Proxy(IAppointment *This,ICalendarMessage **Response);
  void __RPC_STUB IAppointment_AcceptTentative_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_Cancel_Proxy(IAppointment *This,BSTR EmailList,VARIANT_BOOL CleanupCalendar,BSTR UserName,BSTR Password,ICalendarMessage **Request);
  void __RPC_STUB IAppointment_Cancel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_CreateRequest_Proxy(IAppointment *This,ICalendarMessage **Request);
  void __RPC_STUB IAppointment_CreateRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_Decline_Proxy(IAppointment *This,VARIANT_BOOL CleanupCalendar,BSTR UserName,BSTR Password,ICalendarMessage **Response);
  void __RPC_STUB IAppointment_Decline_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_Invite_Proxy(IAppointment *This,BSTR EmailList,ICalendarMessage **Request);
  void __RPC_STUB IAppointment_Invite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_Publish_Proxy(IAppointment *This,ICalendarMessage **Request);
  void __RPC_STUB IAppointment_Publish_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_GetFirstInstance_Proxy(IAppointment *This,DATE MinDate,DATE MaxDate,IAppointment **Appointment);
  void __RPC_STUB IAppointment_GetFirstInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_GetNextInstance_Proxy(IAppointment *This,IAppointment **Appointment);
  void __RPC_STUB IAppointment_GetNextInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_GetInterface_Proxy(IAppointment *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IAppointment_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppointment_GetRecurringMaster_Proxy(IAppointment *This,BSTR CalendarLocation,BSTR UserName,BSTR Password,IAppointment **Appointment);
  void __RPC_STUB IAppointment_GetRecurringMaster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICalendarMessage_INTERFACE_DEFINED__
#define __ICalendarMessage_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICalendarMessage;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICalendarMessage : public IDispatch {
  public:
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
    virtual HRESULT WINAPI get_CalendarParts(ICalendarParts **varCalendarParts) = 0;
    virtual HRESULT WINAPI get_Message(IMessage **varMessage) = 0;
    virtual HRESULT WINAPI get_DataSource(IDataSource **varDataSource) = 0;
    virtual HRESULT WINAPI get_Configuration(IConfiguration **pConfiguration) = 0;
    virtual HRESULT WINAPI put_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI putref_Configuration(IConfiguration *varConfiguration) = 0;
  };
#else
  typedef struct ICalendarMessageVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICalendarMessage *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICalendarMessage *This);
      ULONG (WINAPI *Release)(ICalendarMessage *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICalendarMessage *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICalendarMessage *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICalendarMessage *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICalendarMessage *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetInterface)(ICalendarMessage *This,BSTR Interface,IDispatch **ppUnknown);
      HRESULT (WINAPI *get_CalendarParts)(ICalendarMessage *This,ICalendarParts **varCalendarParts);
      HRESULT (WINAPI *get_Message)(ICalendarMessage *This,IMessage **varMessage);
      HRESULT (WINAPI *get_DataSource)(ICalendarMessage *This,IDataSource **varDataSource);
      HRESULT (WINAPI *get_Configuration)(ICalendarMessage *This,IConfiguration **pConfiguration);
      HRESULT (WINAPI *put_Configuration)(ICalendarMessage *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *putref_Configuration)(ICalendarMessage *This,IConfiguration *varConfiguration);
    END_INTERFACE
  } ICalendarMessageVtbl;
  struct ICalendarMessage {
    CONST_VTBL struct ICalendarMessageVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICalendarMessage_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICalendarMessage_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICalendarMessage_Release(This) (This)->lpVtbl->Release(This)
#define ICalendarMessage_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICalendarMessage_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICalendarMessage_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICalendarMessage_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICalendarMessage_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#define ICalendarMessage_get_CalendarParts(This,varCalendarParts) (This)->lpVtbl->get_CalendarParts(This,varCalendarParts)
#define ICalendarMessage_get_Message(This,varMessage) (This)->lpVtbl->get_Message(This,varMessage)
#define ICalendarMessage_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define ICalendarMessage_get_Configuration(This,pConfiguration) (This)->lpVtbl->get_Configuration(This,pConfiguration)
#define ICalendarMessage_put_Configuration(This,varConfiguration) (This)->lpVtbl->put_Configuration(This,varConfiguration)
#define ICalendarMessage_putref_Configuration(This,varConfiguration) (This)->lpVtbl->putref_Configuration(This,varConfiguration)
#endif
#endif
  HRESULT WINAPI ICalendarMessage_GetInterface_Proxy(ICalendarMessage *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB ICalendarMessage_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarMessage_get_CalendarParts_Proxy(ICalendarMessage *This,ICalendarParts **varCalendarParts);
  void __RPC_STUB ICalendarMessage_get_CalendarParts_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarMessage_get_Message_Proxy(ICalendarMessage *This,IMessage **varMessage);
  void __RPC_STUB ICalendarMessage_get_Message_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarMessage_get_DataSource_Proxy(ICalendarMessage *This,IDataSource **varDataSource);
  void __RPC_STUB ICalendarMessage_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarMessage_get_Configuration_Proxy(ICalendarMessage *This,IConfiguration **pConfiguration);
  void __RPC_STUB ICalendarMessage_get_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarMessage_put_Configuration_Proxy(ICalendarMessage *This,IConfiguration *varConfiguration);
  void __RPC_STUB ICalendarMessage_put_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarMessage_putref_Configuration_Proxy(ICalendarMessage *This,IConfiguration *varConfiguration);
  void __RPC_STUB ICalendarMessage_putref_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IIntegers_INTERFACE_DEFINED__
#define __IIntegers_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IIntegers;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IIntegers : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Index,__LONG32 *Value) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI Delete(__LONG32 *Value) = 0;
    virtual HRESULT WINAPI Add(__LONG32 NewValue) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **Unknown) = 0;
  };
#else
  typedef struct IIntegersVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IIntegers *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IIntegers *This);
      ULONG (WINAPI *Release)(IIntegers *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IIntegers *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IIntegers *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IIntegers *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IIntegers *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IIntegers *This,__LONG32 Index,__LONG32 *Value);
      HRESULT (WINAPI *get_Count)(IIntegers *This,__LONG32 *Count);
      HRESULT (WINAPI *Delete)(IIntegers *This,__LONG32 *Value);
      HRESULT (WINAPI *Add)(IIntegers *This,__LONG32 NewValue);
      HRESULT (WINAPI *get__NewEnum)(IIntegers *This,IUnknown **Unknown);
    END_INTERFACE
  } IIntegersVtbl;
  struct IIntegers {
    CONST_VTBL struct IIntegersVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IIntegers_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IIntegers_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IIntegers_Release(This) (This)->lpVtbl->Release(This)
#define IIntegers_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IIntegers_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IIntegers_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IIntegers_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IIntegers_get_Item(This,Index,Value) (This)->lpVtbl->get_Item(This,Index,Value)
#define IIntegers_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IIntegers_Delete(This,Value) (This)->lpVtbl->Delete(This,Value)
#define IIntegers_Add(This,NewValue) (This)->lpVtbl->Add(This,NewValue)
#define IIntegers_get__NewEnum(This,Unknown) (This)->lpVtbl->get__NewEnum(This,Unknown)
#endif
#endif
  HRESULT WINAPI IIntegers_get_Item_Proxy(IIntegers *This,__LONG32 Index,__LONG32 *Value);
  void __RPC_STUB IIntegers_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIntegers_get_Count_Proxy(IIntegers *This,__LONG32 *Count);
  void __RPC_STUB IIntegers_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIntegers_Delete_Proxy(IIntegers *This,__LONG32 *Value);
  void __RPC_STUB IIntegers_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIntegers_Add_Proxy(IIntegers *This,__LONG32 NewValue);
  void __RPC_STUB IIntegers_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IIntegers_get__NewEnum_Proxy(IIntegers *This,IUnknown **Unknown);
  void __RPC_STUB IIntegers_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IVariants_INTERFACE_DEFINED__
#define __IVariants_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IVariants;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IVariants : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Index,VARIANT *Value) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI Delete(VARIANT *Value) = 0;
    virtual HRESULT WINAPI Add(VARIANT NewValue) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **Unknown) = 0;
  };
#else
  typedef struct IVariantsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IVariants *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IVariants *This);
      ULONG (WINAPI *Release)(IVariants *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IVariants *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IVariants *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IVariants *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IVariants *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IVariants *This,__LONG32 Index,VARIANT *Value);
      HRESULT (WINAPI *get_Count)(IVariants *This,__LONG32 *Count);
      HRESULT (WINAPI *Delete)(IVariants *This,VARIANT *Value);
      HRESULT (WINAPI *Add)(IVariants *This,VARIANT NewValue);
      HRESULT (WINAPI *get__NewEnum)(IVariants *This,IUnknown **Unknown);
    END_INTERFACE
  } IVariantsVtbl;
  struct IVariants {
    CONST_VTBL struct IVariantsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IVariants_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVariants_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVariants_Release(This) (This)->lpVtbl->Release(This)
#define IVariants_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IVariants_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IVariants_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IVariants_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IVariants_get_Item(This,Index,Value) (This)->lpVtbl->get_Item(This,Index,Value)
#define IVariants_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IVariants_Delete(This,Value) (This)->lpVtbl->Delete(This,Value)
#define IVariants_Add(This,NewValue) (This)->lpVtbl->Add(This,NewValue)
#define IVariants_get__NewEnum(This,Unknown) (This)->lpVtbl->get__NewEnum(This,Unknown)
#endif
#endif
  HRESULT WINAPI IVariants_get_Item_Proxy(IVariants *This,__LONG32 Index,VARIANT *Value);
  void __RPC_STUB IVariants_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IVariants_get_Count_Proxy(IVariants *This,__LONG32 *Count);
  void __RPC_STUB IVariants_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IVariants_Delete_Proxy(IVariants *This,VARIANT *Value);
  void __RPC_STUB IVariants_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IVariants_Add_Proxy(IVariants *This,VARIANT NewValue);
  void __RPC_STUB IVariants_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IVariants_get__NewEnum_Proxy(IVariants *This,IUnknown **Unknown);
  void __RPC_STUB IVariants_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRecurrencePattern_INTERFACE_DEFINED__
#define __IRecurrencePattern_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRecurrencePattern;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRecurrencePattern : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Interval(__LONG32 *pInterval) = 0;
    virtual HRESULT WINAPI put_Interval(__LONG32 varInterval) = 0;
    virtual HRESULT WINAPI get_Instances(__LONG32 *pInstances) = 0;
    virtual HRESULT WINAPI put_Instances(__LONG32 varInstances) = 0;
    virtual HRESULT WINAPI get_Frequency(CdoFrequency *pFrequency) = 0;
    virtual HRESULT WINAPI put_Frequency(CdoFrequency varFrequency) = 0;
    virtual HRESULT WINAPI get_PatternEndDate(DATE *pPatternEndDate) = 0;
    virtual HRESULT WINAPI put_PatternEndDate(DATE varPatternEndDate) = 0;
    virtual HRESULT WINAPI get_Type(BSTR *varType) = 0;
    virtual HRESULT WINAPI get_EndType(CdoPatternEndType *pEndType) = 0;
    virtual HRESULT WINAPI put_EndType(CdoPatternEndType varEndType) = 0;
    virtual HRESULT WINAPI get_FirstDayOfWeek(CdoDayOfWeek *pFirstDayOfWeek) = 0;
    virtual HRESULT WINAPI put_FirstDayOfWeek(CdoDayOfWeek varFirstDayOfWeek) = 0;
    virtual HRESULT WINAPI get_DaysOfMonth(IIntegers **varDaysOfMonth) = 0;
    virtual HRESULT WINAPI get_DaysOfWeek(IIntegers **varDaysOfWeek) = 0;
    virtual HRESULT WINAPI get_DaysOfYear(IIntegers **varDaysOfYear) = 0;
    virtual HRESULT WINAPI get_SecondsOfMinute(IIntegers **varSecondsOfMinute) = 0;
    virtual HRESULT WINAPI get_MinutesOfHour(IIntegers **varMinutesOfHour) = 0;
    virtual HRESULT WINAPI get_HoursOfDay(IIntegers **varHoursOfDay) = 0;
    virtual HRESULT WINAPI get_WeekDays(IVariants **varWeekDays) = 0;
    virtual HRESULT WINAPI get_WeeksOfYear(IIntegers **varWeeksOfYear) = 0;
    virtual HRESULT WINAPI get_MonthsOfYear(IIntegers **varMonthsOfYear) = 0;
    virtual HRESULT WINAPI get_ByPosition(IIntegers **varByPosition) = 0;
  };
#else
  typedef struct IRecurrencePatternVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRecurrencePattern *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRecurrencePattern *This);
      ULONG (WINAPI *Release)(IRecurrencePattern *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRecurrencePattern *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRecurrencePattern *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRecurrencePattern *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRecurrencePattern *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Interval)(IRecurrencePattern *This,__LONG32 *pInterval);
      HRESULT (WINAPI *put_Interval)(IRecurrencePattern *This,__LONG32 varInterval);
      HRESULT (WINAPI *get_Instances)(IRecurrencePattern *This,__LONG32 *pInstances);
      HRESULT (WINAPI *put_Instances)(IRecurrencePattern *This,__LONG32 varInstances);
      HRESULT (WINAPI *get_Frequency)(IRecurrencePattern *This,CdoFrequency *pFrequency);
      HRESULT (WINAPI *put_Frequency)(IRecurrencePattern *This,CdoFrequency varFrequency);
      HRESULT (WINAPI *get_PatternEndDate)(IRecurrencePattern *This,DATE *pPatternEndDate);
      HRESULT (WINAPI *put_PatternEndDate)(IRecurrencePattern *This,DATE varPatternEndDate);
      HRESULT (WINAPI *get_Type)(IRecurrencePattern *This,BSTR *varType);
      HRESULT (WINAPI *get_EndType)(IRecurrencePattern *This,CdoPatternEndType *pEndType);
      HRESULT (WINAPI *put_EndType)(IRecurrencePattern *This,CdoPatternEndType varEndType);
      HRESULT (WINAPI *get_FirstDayOfWeek)(IRecurrencePattern *This,CdoDayOfWeek *pFirstDayOfWeek);
      HRESULT (WINAPI *put_FirstDayOfWeek)(IRecurrencePattern *This,CdoDayOfWeek varFirstDayOfWeek);
      HRESULT (WINAPI *get_DaysOfMonth)(IRecurrencePattern *This,IIntegers **varDaysOfMonth);
      HRESULT (WINAPI *get_DaysOfWeek)(IRecurrencePattern *This,IIntegers **varDaysOfWeek);
      HRESULT (WINAPI *get_DaysOfYear)(IRecurrencePattern *This,IIntegers **varDaysOfYear);
      HRESULT (WINAPI *get_SecondsOfMinute)(IRecurrencePattern *This,IIntegers **varSecondsOfMinute);
      HRESULT (WINAPI *get_MinutesOfHour)(IRecurrencePattern *This,IIntegers **varMinutesOfHour);
      HRESULT (WINAPI *get_HoursOfDay)(IRecurrencePattern *This,IIntegers **varHoursOfDay);
      HRESULT (WINAPI *get_WeekDays)(IRecurrencePattern *This,IVariants **varWeekDays);
      HRESULT (WINAPI *get_WeeksOfYear)(IRecurrencePattern *This,IIntegers **varWeeksOfYear);
      HRESULT (WINAPI *get_MonthsOfYear)(IRecurrencePattern *This,IIntegers **varMonthsOfYear);
      HRESULT (WINAPI *get_ByPosition)(IRecurrencePattern *This,IIntegers **varByPosition);
    END_INTERFACE
  } IRecurrencePatternVtbl;
  struct IRecurrencePattern {
    CONST_VTBL struct IRecurrencePatternVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRecurrencePattern_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRecurrencePattern_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRecurrencePattern_Release(This) (This)->lpVtbl->Release(This)
#define IRecurrencePattern_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRecurrencePattern_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRecurrencePattern_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRecurrencePattern_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRecurrencePattern_get_Interval(This,pInterval) (This)->lpVtbl->get_Interval(This,pInterval)
#define IRecurrencePattern_put_Interval(This,varInterval) (This)->lpVtbl->put_Interval(This,varInterval)
#define IRecurrencePattern_get_Instances(This,pInstances) (This)->lpVtbl->get_Instances(This,pInstances)
#define IRecurrencePattern_put_Instances(This,varInstances) (This)->lpVtbl->put_Instances(This,varInstances)
#define IRecurrencePattern_get_Frequency(This,pFrequency) (This)->lpVtbl->get_Frequency(This,pFrequency)
#define IRecurrencePattern_put_Frequency(This,varFrequency) (This)->lpVtbl->put_Frequency(This,varFrequency)
#define IRecurrencePattern_get_PatternEndDate(This,pPatternEndDate) (This)->lpVtbl->get_PatternEndDate(This,pPatternEndDate)
#define IRecurrencePattern_put_PatternEndDate(This,varPatternEndDate) (This)->lpVtbl->put_PatternEndDate(This,varPatternEndDate)
#define IRecurrencePattern_get_Type(This,varType) (This)->lpVtbl->get_Type(This,varType)
#define IRecurrencePattern_get_EndType(This,pEndType) (This)->lpVtbl->get_EndType(This,pEndType)
#define IRecurrencePattern_put_EndType(This,varEndType) (This)->lpVtbl->put_EndType(This,varEndType)
#define IRecurrencePattern_get_FirstDayOfWeek(This,pFirstDayOfWeek) (This)->lpVtbl->get_FirstDayOfWeek(This,pFirstDayOfWeek)
#define IRecurrencePattern_put_FirstDayOfWeek(This,varFirstDayOfWeek) (This)->lpVtbl->put_FirstDayOfWeek(This,varFirstDayOfWeek)
#define IRecurrencePattern_get_DaysOfMonth(This,varDaysOfMonth) (This)->lpVtbl->get_DaysOfMonth(This,varDaysOfMonth)
#define IRecurrencePattern_get_DaysOfWeek(This,varDaysOfWeek) (This)->lpVtbl->get_DaysOfWeek(This,varDaysOfWeek)
#define IRecurrencePattern_get_DaysOfYear(This,varDaysOfYear) (This)->lpVtbl->get_DaysOfYear(This,varDaysOfYear)
#define IRecurrencePattern_get_SecondsOfMinute(This,varSecondsOfMinute) (This)->lpVtbl->get_SecondsOfMinute(This,varSecondsOfMinute)
#define IRecurrencePattern_get_MinutesOfHour(This,varMinutesOfHour) (This)->lpVtbl->get_MinutesOfHour(This,varMinutesOfHour)
#define IRecurrencePattern_get_HoursOfDay(This,varHoursOfDay) (This)->lpVtbl->get_HoursOfDay(This,varHoursOfDay)
#define IRecurrencePattern_get_WeekDays(This,varWeekDays) (This)->lpVtbl->get_WeekDays(This,varWeekDays)
#define IRecurrencePattern_get_WeeksOfYear(This,varWeeksOfYear) (This)->lpVtbl->get_WeeksOfYear(This,varWeeksOfYear)
#define IRecurrencePattern_get_MonthsOfYear(This,varMonthsOfYear) (This)->lpVtbl->get_MonthsOfYear(This,varMonthsOfYear)
#define IRecurrencePattern_get_ByPosition(This,varByPosition) (This)->lpVtbl->get_ByPosition(This,varByPosition)
#endif
#endif
  HRESULT WINAPI IRecurrencePattern_get_Interval_Proxy(IRecurrencePattern *This,__LONG32 *pInterval);
  void __RPC_STUB IRecurrencePattern_get_Interval_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_put_Interval_Proxy(IRecurrencePattern *This,__LONG32 varInterval);
  void __RPC_STUB IRecurrencePattern_put_Interval_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_Instances_Proxy(IRecurrencePattern *This,__LONG32 *pInstances);
  void __RPC_STUB IRecurrencePattern_get_Instances_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_put_Instances_Proxy(IRecurrencePattern *This,__LONG32 varInstances);
  void __RPC_STUB IRecurrencePattern_put_Instances_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_Frequency_Proxy(IRecurrencePattern *This,CdoFrequency *pFrequency);
  void __RPC_STUB IRecurrencePattern_get_Frequency_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_put_Frequency_Proxy(IRecurrencePattern *This,CdoFrequency varFrequency);
  void __RPC_STUB IRecurrencePattern_put_Frequency_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_PatternEndDate_Proxy(IRecurrencePattern *This,DATE *pPatternEndDate);
  void __RPC_STUB IRecurrencePattern_get_PatternEndDate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_put_PatternEndDate_Proxy(IRecurrencePattern *This,DATE varPatternEndDate);
  void __RPC_STUB IRecurrencePattern_put_PatternEndDate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_Type_Proxy(IRecurrencePattern *This,BSTR *varType);
  void __RPC_STUB IRecurrencePattern_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_EndType_Proxy(IRecurrencePattern *This,CdoPatternEndType *pEndType);
  void __RPC_STUB IRecurrencePattern_get_EndType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_put_EndType_Proxy(IRecurrencePattern *This,CdoPatternEndType varEndType);
  void __RPC_STUB IRecurrencePattern_put_EndType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_FirstDayOfWeek_Proxy(IRecurrencePattern *This,CdoDayOfWeek *pFirstDayOfWeek);
  void __RPC_STUB IRecurrencePattern_get_FirstDayOfWeek_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_put_FirstDayOfWeek_Proxy(IRecurrencePattern *This,CdoDayOfWeek varFirstDayOfWeek);
  void __RPC_STUB IRecurrencePattern_put_FirstDayOfWeek_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_DaysOfMonth_Proxy(IRecurrencePattern *This,IIntegers **varDaysOfMonth);
  void __RPC_STUB IRecurrencePattern_get_DaysOfMonth_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_DaysOfWeek_Proxy(IRecurrencePattern *This,IIntegers **varDaysOfWeek);
  void __RPC_STUB IRecurrencePattern_get_DaysOfWeek_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_DaysOfYear_Proxy(IRecurrencePattern *This,IIntegers **varDaysOfYear);
  void __RPC_STUB IRecurrencePattern_get_DaysOfYear_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_SecondsOfMinute_Proxy(IRecurrencePattern *This,IIntegers **varSecondsOfMinute);
  void __RPC_STUB IRecurrencePattern_get_SecondsOfMinute_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_MinutesOfHour_Proxy(IRecurrencePattern *This,IIntegers **varMinutesOfHour);
  void __RPC_STUB IRecurrencePattern_get_MinutesOfHour_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_HoursOfDay_Proxy(IRecurrencePattern *This,IIntegers **varHoursOfDay);
  void __RPC_STUB IRecurrencePattern_get_HoursOfDay_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_WeekDays_Proxy(IRecurrencePattern *This,IVariants **varWeekDays);
  void __RPC_STUB IRecurrencePattern_get_WeekDays_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_WeeksOfYear_Proxy(IRecurrencePattern *This,IIntegers **varWeeksOfYear);
  void __RPC_STUB IRecurrencePattern_get_WeeksOfYear_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_MonthsOfYear_Proxy(IRecurrencePattern *This,IIntegers **varMonthsOfYear);
  void __RPC_STUB IRecurrencePattern_get_MonthsOfYear_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePattern_get_ByPosition_Proxy(IRecurrencePattern *This,IIntegers **varByPosition);
  void __RPC_STUB IRecurrencePattern_get_ByPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IException_INTERFACE_DEFINED__
#define __IException_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IException;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IException : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Type(BSTR *varType) = 0;
    virtual HRESULT WINAPI get_RecurrenceIDRange(BSTR *pRecurrenceIDRange) = 0;
    virtual HRESULT WINAPI put_RecurrenceIDRange(BSTR varRecurrenceIDRange) = 0;
    virtual HRESULT WINAPI get_RecurrenceID(DATE *pRecurrenceID) = 0;
    virtual HRESULT WINAPI put_RecurrenceID(DATE varRecurrenceID) = 0;
    virtual HRESULT WINAPI get_StartTime(DATE *pStartTime) = 0;
    virtual HRESULT WINAPI put_StartTime(DATE varStartTime) = 0;
    virtual HRESULT WINAPI get_EndTime(DATE *pEndTime) = 0;
    virtual HRESULT WINAPI put_EndTime(DATE varEndTime) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
  };
#else
  typedef struct IExceptionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IException *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IException *This);
      ULONG (WINAPI *Release)(IException *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IException *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IException *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IException *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IException *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Type)(IException *This,BSTR *varType);
      HRESULT (WINAPI *get_RecurrenceIDRange)(IException *This,BSTR *pRecurrenceIDRange);
      HRESULT (WINAPI *put_RecurrenceIDRange)(IException *This,BSTR varRecurrenceIDRange);
      HRESULT (WINAPI *get_RecurrenceID)(IException *This,DATE *pRecurrenceID);
      HRESULT (WINAPI *put_RecurrenceID)(IException *This,DATE varRecurrenceID);
      HRESULT (WINAPI *get_StartTime)(IException *This,DATE *pStartTime);
      HRESULT (WINAPI *put_StartTime)(IException *This,DATE varStartTime);
      HRESULT (WINAPI *get_EndTime)(IException *This,DATE *pEndTime);
      HRESULT (WINAPI *put_EndTime)(IException *This,DATE varEndTime);
      HRESULT (WINAPI *get_Fields)(IException *This,Fields **varFields);
    END_INTERFACE
  } IExceptionVtbl;
  struct IException {
    CONST_VTBL struct IExceptionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IException_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IException_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IException_Release(This) (This)->lpVtbl->Release(This)
#define IException_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IException_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IException_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IException_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IException_get_Type(This,varType) (This)->lpVtbl->get_Type(This,varType)
#define IException_get_RecurrenceIDRange(This,pRecurrenceIDRange) (This)->lpVtbl->get_RecurrenceIDRange(This,pRecurrenceIDRange)
#define IException_put_RecurrenceIDRange(This,varRecurrenceIDRange) (This)->lpVtbl->put_RecurrenceIDRange(This,varRecurrenceIDRange)
#define IException_get_RecurrenceID(This,pRecurrenceID) (This)->lpVtbl->get_RecurrenceID(This,pRecurrenceID)
#define IException_put_RecurrenceID(This,varRecurrenceID) (This)->lpVtbl->put_RecurrenceID(This,varRecurrenceID)
#define IException_get_StartTime(This,pStartTime) (This)->lpVtbl->get_StartTime(This,pStartTime)
#define IException_put_StartTime(This,varStartTime) (This)->lpVtbl->put_StartTime(This,varStartTime)
#define IException_get_EndTime(This,pEndTime) (This)->lpVtbl->get_EndTime(This,pEndTime)
#define IException_put_EndTime(This,varEndTime) (This)->lpVtbl->put_EndTime(This,varEndTime)
#define IException_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#endif
#endif
  HRESULT WINAPI IException_get_Type_Proxy(IException *This,BSTR *varType);
  void __RPC_STUB IException_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IException_get_RecurrenceIDRange_Proxy(IException *This,BSTR *pRecurrenceIDRange);
  void __RPC_STUB IException_get_RecurrenceIDRange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IException_put_RecurrenceIDRange_Proxy(IException *This,BSTR varRecurrenceIDRange);
  void __RPC_STUB IException_put_RecurrenceIDRange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IException_get_RecurrenceID_Proxy(IException *This,DATE *pRecurrenceID);
  void __RPC_STUB IException_get_RecurrenceID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IException_put_RecurrenceID_Proxy(IException *This,DATE varRecurrenceID);
  void __RPC_STUB IException_put_RecurrenceID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IException_get_StartTime_Proxy(IException *This,DATE *pStartTime);
  void __RPC_STUB IException_get_StartTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IException_put_StartTime_Proxy(IException *This,DATE varStartTime);
  void __RPC_STUB IException_put_StartTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IException_get_EndTime_Proxy(IException *This,DATE *pEndTime);
  void __RPC_STUB IException_get_EndTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IException_put_EndTime_Proxy(IException *This,DATE varEndTime);
  void __RPC_STUB IException_put_EndTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IException_get_Fields_Proxy(IException *This,Fields **varFields);
  void __RPC_STUB IException_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRecurrencePatterns_INTERFACE_DEFINED__
#define __IRecurrencePatterns_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRecurrencePatterns;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRecurrencePatterns : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Index,IRecurrencePattern **RecurrencePattern) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI Delete(__LONG32 Index) = 0;
    virtual HRESULT WINAPI Add(BSTR Type,IRecurrencePattern **RecurrencePattern) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **Unknown) = 0;
  };
#else
  typedef struct IRecurrencePatternsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRecurrencePatterns *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRecurrencePatterns *This);
      ULONG (WINAPI *Release)(IRecurrencePatterns *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRecurrencePatterns *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRecurrencePatterns *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRecurrencePatterns *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRecurrencePatterns *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IRecurrencePatterns *This,__LONG32 Index,IRecurrencePattern **RecurrencePattern);
      HRESULT (WINAPI *get_Count)(IRecurrencePatterns *This,__LONG32 *Count);
      HRESULT (WINAPI *Delete)(IRecurrencePatterns *This,__LONG32 Index);
      HRESULT (WINAPI *Add)(IRecurrencePatterns *This,BSTR Type,IRecurrencePattern **RecurrencePattern);
      HRESULT (WINAPI *get__NewEnum)(IRecurrencePatterns *This,IUnknown **Unknown);
    END_INTERFACE
  } IRecurrencePatternsVtbl;
  struct IRecurrencePatterns {
    CONST_VTBL struct IRecurrencePatternsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRecurrencePatterns_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRecurrencePatterns_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRecurrencePatterns_Release(This) (This)->lpVtbl->Release(This)
#define IRecurrencePatterns_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRecurrencePatterns_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRecurrencePatterns_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRecurrencePatterns_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRecurrencePatterns_get_Item(This,Index,RecurrencePattern) (This)->lpVtbl->get_Item(This,Index,RecurrencePattern)
#define IRecurrencePatterns_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IRecurrencePatterns_Delete(This,Index) (This)->lpVtbl->Delete(This,Index)
#define IRecurrencePatterns_Add(This,Type,RecurrencePattern) (This)->lpVtbl->Add(This,Type,RecurrencePattern)
#define IRecurrencePatterns_get__NewEnum(This,Unknown) (This)->lpVtbl->get__NewEnum(This,Unknown)
#endif
#endif
  HRESULT WINAPI IRecurrencePatterns_get_Item_Proxy(IRecurrencePatterns *This,__LONG32 Index,IRecurrencePattern **RecurrencePattern);
  void __RPC_STUB IRecurrencePatterns_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePatterns_get_Count_Proxy(IRecurrencePatterns *This,__LONG32 *Count);
  void __RPC_STUB IRecurrencePatterns_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePatterns_Delete_Proxy(IRecurrencePatterns *This,__LONG32 Index);
  void __RPC_STUB IRecurrencePatterns_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePatterns_Add_Proxy(IRecurrencePatterns *This,BSTR Type,IRecurrencePattern **RecurrencePattern);
  void __RPC_STUB IRecurrencePatterns_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRecurrencePatterns_get__NewEnum_Proxy(IRecurrencePatterns *This,IUnknown **Unknown);
  void __RPC_STUB IRecurrencePatterns_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IExceptions_INTERFACE_DEFINED__
#define __IExceptions_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IExceptions;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IExceptions : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Index,IException **Exception) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI Delete(__LONG32 Index) = 0;
    virtual HRESULT WINAPI Add(BSTR Type,IException **Exception) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **Unknown) = 0;
  };
#else
  typedef struct IExceptionsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IExceptions *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IExceptions *This);
      ULONG (WINAPI *Release)(IExceptions *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IExceptions *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IExceptions *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IExceptions *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IExceptions *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IExceptions *This,__LONG32 Index,IException **Exception);
      HRESULT (WINAPI *get_Count)(IExceptions *This,__LONG32 *Count);
      HRESULT (WINAPI *Delete)(IExceptions *This,__LONG32 Index);
      HRESULT (WINAPI *Add)(IExceptions *This,BSTR Type,IException **Exception);
      HRESULT (WINAPI *get__NewEnum)(IExceptions *This,IUnknown **Unknown);
    END_INTERFACE
  } IExceptionsVtbl;
  struct IExceptions {
    CONST_VTBL struct IExceptionsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IExceptions_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IExceptions_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IExceptions_Release(This) (This)->lpVtbl->Release(This)
#define IExceptions_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IExceptions_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IExceptions_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IExceptions_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IExceptions_get_Item(This,Index,Exception) (This)->lpVtbl->get_Item(This,Index,Exception)
#define IExceptions_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IExceptions_Delete(This,Index) (This)->lpVtbl->Delete(This,Index)
#define IExceptions_Add(This,Type,Exception) (This)->lpVtbl->Add(This,Type,Exception)
#define IExceptions_get__NewEnum(This,Unknown) (This)->lpVtbl->get__NewEnum(This,Unknown)
#endif
#endif
  HRESULT WINAPI IExceptions_get_Item_Proxy(IExceptions *This,__LONG32 Index,IException **Exception);
  void __RPC_STUB IExceptions_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExceptions_get_Count_Proxy(IExceptions *This,__LONG32 *Count);
  void __RPC_STUB IExceptions_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExceptions_Delete_Proxy(IExceptions *This,__LONG32 Index);
  void __RPC_STUB IExceptions_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExceptions_Add_Proxy(IExceptions *This,BSTR Type,IException **Exception);
  void __RPC_STUB IExceptions_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExceptions_get__NewEnum_Proxy(IExceptions *This,IUnknown **Unknown);
  void __RPC_STUB IExceptions_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICalendarPart_INTERFACE_DEFINED__
#define __ICalendarPart_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICalendarPart;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICalendarPart : public IDispatch {
  public:
    virtual HRESULT WINAPI GetAssociatedItem(BSTR CalendarLocation,BSTR UserName,BSTR Password,IDispatch **Item) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
    virtual HRESULT WINAPI get_ComponentType(CdoComponentType *varComponentType) = 0;
    virtual HRESULT WINAPI get_ProdID(BSTR *varProdID) = 0;
    virtual HRESULT WINAPI get_CalendarVersion(BSTR *varCalendarVersion) = 0;
    virtual HRESULT WINAPI get_CalendarMethod(BSTR *varCalendarMethod) = 0;
    virtual HRESULT WINAPI GetUpdatedItem(BSTR CalendarLocation,BSTR UserName,BSTR Password,IDispatch **Item) = 0;
  };
#else
  typedef struct ICalendarPartVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICalendarPart *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICalendarPart *This);
      ULONG (WINAPI *Release)(ICalendarPart *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICalendarPart *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICalendarPart *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICalendarPart *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICalendarPart *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetAssociatedItem)(ICalendarPart *This,BSTR CalendarLocation,BSTR UserName,BSTR Password,IDispatch **Item);
      HRESULT (WINAPI *GetInterface)(ICalendarPart *This,BSTR Interface,IDispatch **ppUnknown);
      HRESULT (WINAPI *get_ComponentType)(ICalendarPart *This,CdoComponentType *varComponentType);
      HRESULT (WINAPI *get_ProdID)(ICalendarPart *This,BSTR *varProdID);
      HRESULT (WINAPI *get_CalendarVersion)(ICalendarPart *This,BSTR *varCalendarVersion);
      HRESULT (WINAPI *get_CalendarMethod)(ICalendarPart *This,BSTR *varCalendarMethod);
      HRESULT (WINAPI *GetUpdatedItem)(ICalendarPart *This,BSTR CalendarLocation,BSTR UserName,BSTR Password,IDispatch **Item);
    END_INTERFACE
  } ICalendarPartVtbl;
  struct ICalendarPart {
    CONST_VTBL struct ICalendarPartVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICalendarPart_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICalendarPart_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICalendarPart_Release(This) (This)->lpVtbl->Release(This)
#define ICalendarPart_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICalendarPart_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICalendarPart_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICalendarPart_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICalendarPart_GetAssociatedItem(This,CalendarLocation,UserName,Password,Item) (This)->lpVtbl->GetAssociatedItem(This,CalendarLocation,UserName,Password,Item)
#define ICalendarPart_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#define ICalendarPart_get_ComponentType(This,varComponentType) (This)->lpVtbl->get_ComponentType(This,varComponentType)
#define ICalendarPart_get_ProdID(This,varProdID) (This)->lpVtbl->get_ProdID(This,varProdID)
#define ICalendarPart_get_CalendarVersion(This,varCalendarVersion) (This)->lpVtbl->get_CalendarVersion(This,varCalendarVersion)
#define ICalendarPart_get_CalendarMethod(This,varCalendarMethod) (This)->lpVtbl->get_CalendarMethod(This,varCalendarMethod)
#define ICalendarPart_GetUpdatedItem(This,CalendarLocation,UserName,Password,Item) (This)->lpVtbl->GetUpdatedItem(This,CalendarLocation,UserName,Password,Item)
#endif
#endif
  HRESULT WINAPI ICalendarPart_GetAssociatedItem_Proxy(ICalendarPart *This,BSTR CalendarLocation,BSTR UserName,BSTR Password,IDispatch **Item);
  void __RPC_STUB ICalendarPart_GetAssociatedItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarPart_GetInterface_Proxy(ICalendarPart *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB ICalendarPart_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarPart_get_ComponentType_Proxy(ICalendarPart *This,CdoComponentType *varComponentType);
  void __RPC_STUB ICalendarPart_get_ComponentType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarPart_get_ProdID_Proxy(ICalendarPart *This,BSTR *varProdID);
  void __RPC_STUB ICalendarPart_get_ProdID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarPart_get_CalendarVersion_Proxy(ICalendarPart *This,BSTR *varCalendarVersion);
  void __RPC_STUB ICalendarPart_get_CalendarVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarPart_get_CalendarMethod_Proxy(ICalendarPart *This,BSTR *varCalendarMethod);
  void __RPC_STUB ICalendarPart_get_CalendarMethod_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarPart_GetUpdatedItem_Proxy(ICalendarPart *This,BSTR CalendarLocation,BSTR UserName,BSTR Password,IDispatch **Item);
  void __RPC_STUB ICalendarPart_GetUpdatedItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICalendarParts_INTERFACE_DEFINED__
#define __ICalendarParts_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICalendarParts;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICalendarParts : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Index,ICalendarPart **CalendarPart) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI Delete(__LONG32 Index) = 0;
    virtual HRESULT WINAPI Add(IUnknown *CalendarPart,CdoComponentType ComponentType) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **Unknown) = 0;

  };
#else
  typedef struct ICalendarPartsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICalendarParts *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICalendarParts *This);
      ULONG (WINAPI *Release)(ICalendarParts *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICalendarParts *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICalendarParts *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICalendarParts *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICalendarParts *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(ICalendarParts *This,__LONG32 Index,ICalendarPart **CalendarPart);
      HRESULT (WINAPI *get_Count)(ICalendarParts *This,__LONG32 *Count);
      HRESULT (WINAPI *Delete)(ICalendarParts *This,__LONG32 Index);
      HRESULT (WINAPI *Add)(ICalendarParts *This,IUnknown *CalendarPart,CdoComponentType ComponentType);
      HRESULT (WINAPI *get__NewEnum)(ICalendarParts *This,IUnknown **Unknown);
    END_INTERFACE
  } ICalendarPartsVtbl;
  struct ICalendarParts {
    CONST_VTBL struct ICalendarPartsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICalendarParts_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICalendarParts_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICalendarParts_Release(This) (This)->lpVtbl->Release(This)
#define ICalendarParts_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICalendarParts_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICalendarParts_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICalendarParts_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICalendarParts_get_Item(This,Index,CalendarPart) (This)->lpVtbl->get_Item(This,Index,CalendarPart)
#define ICalendarParts_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define ICalendarParts_Delete(This,Index) (This)->lpVtbl->Delete(This,Index)
#define ICalendarParts_Add(This,CalendarPart,ComponentType) (This)->lpVtbl->Add(This,CalendarPart,ComponentType)
#define ICalendarParts_get__NewEnum(This,Unknown) (This)->lpVtbl->get__NewEnum(This,Unknown)
#endif
#endif
  HRESULT WINAPI ICalendarParts_get_Item_Proxy(ICalendarParts *This,__LONG32 Index,ICalendarPart **CalendarPart);
  void __RPC_STUB ICalendarParts_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarParts_get_Count_Proxy(ICalendarParts *This,__LONG32 *Count);
  void __RPC_STUB ICalendarParts_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarParts_Delete_Proxy(ICalendarParts *This,__LONG32 Index);
  void __RPC_STUB ICalendarParts_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarParts_Add_Proxy(ICalendarParts *This,IUnknown *CalendarPart,CdoComponentType ComponentType);
  void __RPC_STUB ICalendarParts_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICalendarParts_get__NewEnum_Proxy(ICalendarParts *This,IUnknown **Unknown);
  void __RPC_STUB ICalendarParts_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAttendee_INTERFACE_DEFINED__
#define __IAttendee_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAttendee;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct
IAttendee : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DisplayName(BSTR *pDisplayName) = 0;
    virtual HRESULT WINAPI put_DisplayName(BSTR varDisplayName) = 0;
    virtual HRESULT WINAPI get_Type(BSTR *pType) = 0;
    virtual HRESULT WINAPI put_Type(BSTR varType) = 0;
    virtual HRESULT WINAPI get_Address(BSTR *pAddress) = 0;
    virtual HRESULT WINAPI put_Address(BSTR varAddress) = 0;
    virtual HRESULT WINAPI get_IsOrganizer(VARIANT_BOOL *pIsOrganizer) = 0;
    virtual HRESULT WINAPI put_IsOrganizer(VARIANT_BOOL varIsOrganizer) = 0;
    virtual HRESULT WINAPI get_Role(CdoAttendeeRoleValues *pRole) = 0;
    virtual HRESULT WINAPI put_Role(CdoAttendeeRoleValues varRole) = 0;
    virtual HRESULT WINAPI get_Status(CdoAttendeeStatusValues *pStatus) = 0;
    virtual HRESULT WINAPI put_Status(CdoAttendeeStatusValues varStatus) = 0;
  };
#else
  typedef struct IAttendeeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAttendee *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAttendee *This);
      ULONG (WINAPI *Release)(IAttendee *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAttendee *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAttendee *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAttendee *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAttendee *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DisplayName)(IAttendee *This,BSTR *pDisplayName);
      HRESULT (WINAPI *put_DisplayName)(IAttendee *This,BSTR varDisplayName);
      HRESULT (WINAPI *get_Type)(IAttendee *This,BSTR *pType);
      HRESULT (WINAPI *put_Type)(IAttendee *This,BSTR varType);
      HRESULT (WINAPI *get_Address)(IAttendee *This,BSTR *pAddress);
      HRESULT (WINAPI *put_Address)(IAttendee *This,BSTR varAddress);
      HRESULT (WINAPI *get_IsOrganizer)(IAttendee *This,VARIANT_BOOL *pIsOrganizer);
      HRESULT (WINAPI *put_IsOrganizer)(IAttendee *This,VARIANT_BOOL varIsOrganizer);
      HRESULT (WINAPI *get_Role)(IAttendee *This,CdoAttendeeRoleValues *pRole);
      HRESULT (WINAPI *put_Role)(IAttendee *This,CdoAttendeeRoleValues varRole);
      HRESULT (WINAPI *get_Status)(IAttendee *This,CdoAttendeeStatusValues *pStatus);
      HRESULT (WINAPI *put_Status)(IAttendee *This,CdoAttendeeStatusValues varStatus);
    END_INTERFACE
  } IAttendeeVtbl;
  struct IAttendee {
    CONST_VTBL struct IAttendeeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAttendee_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAttendee_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAttendee_Release(This) (This)->lpVtbl->Release(This)
#define IAttendee_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAttendee_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAttendee_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAttendee_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAttendee_get_DisplayName(This,pDisplayName) (This)->lpVtbl->get_DisplayName(This,pDisplayName)
#define IAttendee_put_DisplayName(This,varDisplayName) (This)->lpVtbl->put_DisplayName(This,varDisplayName)
#define IAttendee_get_Type(This,pType) (This)->lpVtbl->get_Type(This,pType)
#define IAttendee_put_Type(This,varType) (This)->lpVtbl->put_Type(This,varType)
#define IAttendee_get_Address(This,pAddress) (This)->lpVtbl->get_Address(This,pAddress)
#define IAttendee_put_Address(This,varAddress) (This)->lpVtbl->put_Address(This,varAddress)
#define IAttendee_get_IsOrganizer(This,pIsOrganizer) (This)->lpVtbl->get_IsOrganizer(This,pIsOrganizer)
#define IAttendee_put_IsOrganizer(This,varIsOrganizer) (This)->lpVtbl->put_IsOrganizer(This,varIsOrganizer)
#define IAttendee_get_Role(This,pRole) (This)->lpVtbl->get_Role(This,pRole)
#define IAttendee_put_Role(This,varRole) (This)->lpVtbl->put_Role(This,varRole)
#define IAttendee_get_Status(This,pStatus) (This)->lpVtbl->get_Status(This,pStatus)
#define IAttendee_put_Status(This,varStatus) (This)->lpVtbl->put_Status(This,varStatus)
#endif
#endif
  HRESULT WINAPI IAttendee_get_DisplayName_Proxy(IAttendee *This,BSTR *pDisplayName);
  void __RPC_STUB IAttendee_get_DisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendee_put_DisplayName_Proxy(IAttendee *This,BSTR varDisplayName);
  void __RPC_STUB IAttendee_put_DisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendee_get_Type_Proxy(IAttendee *This,BSTR *pType);
  void __RPC_STUB IAttendee_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendee_put_Type_Proxy(IAttendee *This,BSTR varType);
  void __RPC_STUB IAttendee_put_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendee_get_Address_Proxy(IAttendee *This,BSTR *pAddress);
  void __RPC_STUB IAttendee_get_Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendee_put_Address_Proxy(IAttendee *This,BSTR varAddress);
  void __RPC_STUB IAttendee_put_Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendee_get_IsOrganizer_Proxy(IAttendee *This,VARIANT_BOOL *pIsOrganizer);
  void __RPC_STUB IAttendee_get_IsOrganizer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendee_put_IsOrganizer_Proxy(IAttendee *This,VARIANT_BOOL varIsOrganizer);
  void __RPC_STUB IAttendee_put_IsOrganizer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendee_get_Role_Proxy(IAttendee *This,CdoAttendeeRoleValues *pRole);
  void __RPC_STUB IAttendee_get_Role_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendee_put_Role_Proxy(IAttendee *This,CdoAttendeeRoleValues varRole);
  void __RPC_STUB IAttendee_put_Role_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendee_get_Status_Proxy(IAttendee *This,CdoAttendeeStatusValues *pStatus);
  void __RPC_STUB IAttendee_get_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendee_put_Status_Proxy(IAttendee *This,CdoAttendeeStatusValues varStatus);
  void __RPC_STUB IAttendee_put_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAttendees_INTERFACE_DEFINED__
#define __IAttendees_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAttendees;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAttendees : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Index,IAttendee **Attendee) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI Delete(__LONG32 Index) = 0;
    virtual HRESULT WINAPI Add(BSTR Address,IAttendee **Attendee) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **Unknown) = 0;
  };
#else
  typedef struct IAttendeesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAttendees *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAttendees *This);
      ULONG (WINAPI *Release)(IAttendees *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAttendees *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAttendees *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAttendees *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAttendees *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IAttendees *This,__LONG32 Index,IAttendee **Attendee);
      HRESULT (WINAPI *get_Count)(IAttendees *This,__LONG32 *Count);
      HRESULT (WINAPI *Delete)(IAttendees *This,__LONG32 Index);
      HRESULT (WINAPI *Add)(IAttendees *This,BSTR Address,IAttendee **Attendee);
      HRESULT (WINAPI *get__NewEnum)(IAttendees *This,IUnknown **Unknown);
    END_INTERFACE
  } IAttendeesVtbl;
  struct IAttendees {
    CONST_VTBL struct IAttendeesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAttendees_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAttendees_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAttendees_Release(This) (This)->lpVtbl->Release(This)
#define IAttendees_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAttendees_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAttendees_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAttendees_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAttendees_get_Item(This,Index,Attendee) (This)->lpVtbl->get_Item(This,Index,Attendee)
#define IAttendees_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IAttendees_Delete(This,Index) (This)->lpVtbl->Delete(This,Index)
#define IAttendees_Add(This,Address,Attendee) (This)->lpVtbl->Add(This,Address,Attendee)
#define IAttendees_get__NewEnum(This,Unknown) (This)->lpVtbl->get__NewEnum(This,Unknown)
#endif
#endif
  HRESULT WINAPI IAttendees_get_Item_Proxy(IAttendees *This,__LONG32 Index,IAttendee **Attendee);
  void __RPC_STUB IAttendees_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendees_get_Count_Proxy(IAttendees *This,__LONG32 *Count);
  void __RPC_STUB IAttendees_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendees_Delete_Proxy(IAttendees *This,__LONG32 Index);
  void __RPC_STUB IAttendees_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendees_Add_Proxy(IAttendees *This,BSTR Address,IAttendee **Attendee);
  void __RPC_STUB IAttendees_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAttendees_get__NewEnum_Proxy(IAttendees *This,IUnknown **Unknown);
  void __RPC_STUB IAttendees_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMailbox_INTERFACE_DEFINED__
#define __IMailbox_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMailbox;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMailbox : public IDispatch {
  public:
    virtual HRESULT WINAPI get_BaseFolder(BSTR *varBaseFolder) = 0;
    virtual HRESULT WINAPI get_RootFolder(BSTR *varRootFolder) = 0;
    virtual HRESULT WINAPI get_Inbox(BSTR *varInbox) = 0;
    virtual HRESULT WINAPI get_Outbox(BSTR *varOutbox) = 0;
    virtual HRESULT WINAPI get_SentItems(BSTR *varSentItems) = 0;
    virtual HRESULT WINAPI get_Drafts(BSTR *varDrafts) = 0;
    virtual HRESULT WINAPI get_DeletedItems(BSTR *varDeletedItems) = 0;
    virtual HRESULT WINAPI get_Calendar(BSTR *varCalendar) = 0;
    virtual HRESULT WINAPI get_Tasks(BSTR *varTasks) = 0;
    virtual HRESULT WINAPI get_Contacts(BSTR *varContacts) = 0;
    virtual HRESULT WINAPI get_Notes(BSTR *varNotes) = 0;
    virtual HRESULT WINAPI get_Journal(BSTR *varJournal) = 0;
  };
#else
  typedef struct IMailboxVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMailbox *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMailbox *This);
      ULONG (WINAPI *Release)(IMailbox *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMailbox *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMailbox *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMailbox *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMailbox *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_BaseFolder)(IMailbox *This,BSTR *varBaseFolder);
      HRESULT (WINAPI *get_RootFolder)(IMailbox *This,BSTR *varRootFolder);
      HRESULT (WINAPI *get_Inbox)(IMailbox *This,BSTR *varInbox);
      HRESULT (WINAPI *get_Outbox)(IMailbox *This,BSTR *varOutbox);
      HRESULT (WINAPI *get_SentItems)(IMailbox *This,BSTR *varSentItems);
      HRESULT (WINAPI *get_Drafts)(IMailbox *This,BSTR *varDrafts);
      HRESULT (WINAPI *get_DeletedItems)(IMailbox *This,BSTR *varDeletedItems);
      HRESULT (WINAPI *get_Calendar)(IMailbox *This,BSTR *varCalendar);
      HRESULT (WINAPI *get_Tasks)(IMailbox *This,BSTR *varTasks);
      HRESULT (WINAPI *get_Contacts)(IMailbox *This,BSTR *varContacts);
      HRESULT (WINAPI *get_Notes)(IMailbox *This,BSTR *varNotes);
      HRESULT (WINAPI *get_Journal)(IMailbox *This,BSTR *varJournal);
    END_INTERFACE
  } IMailboxVtbl;
  struct IMailbox {
    CONST_VTBL struct IMailboxVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMailbox_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMailbox_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMailbox_Release(This) (This)->lpVtbl->Release(This)
#define IMailbox_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMailbox_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMailbox_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMailbox_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMailbox_get_BaseFolder(This,varBaseFolder) (This)->lpVtbl->get_BaseFolder(This,varBaseFolder)
#define IMailbox_get_RootFolder(This,varRootFolder) (This)->lpVtbl->get_RootFolder(This,varRootFolder)
#define IMailbox_get_Inbox(This,varInbox) (This)->lpVtbl->get_Inbox(This,varInbox)
#define IMailbox_get_Outbox(This,varOutbox) (This)->lpVtbl->get_Outbox(This,varOutbox)
#define IMailbox_get_SentItems(This,varSentItems) (This)->lpVtbl->get_SentItems(This,varSentItems)
#define IMailbox_get_Drafts(This,varDrafts) (This)->lpVtbl->get_Drafts(This,varDrafts)
#define IMailbox_get_DeletedItems(This,varDeletedItems) (This)->lpVtbl->get_DeletedItems(This,varDeletedItems)
#define IMailbox_get_Calendar(This,varCalendar) (This)->lpVtbl->get_Calendar(This,varCalendar)
#define IMailbox_get_Tasks(This,varTasks) (This)->lpVtbl->get_Tasks(This,varTasks)
#define IMailbox_get_Contacts(This,varContacts) (This)->lpVtbl->get_Contacts(This,varContacts)
#define IMailbox_get_Notes(This,varNotes) (This)->lpVtbl->get_Notes(This,varNotes)
#define IMailbox_get_Journal(This,varJournal) (This)->lpVtbl->get_Journal(This,varJournal)
#endif
#endif
  HRESULT WINAPI IMailbox_get_BaseFolder_Proxy(IMailbox *This,BSTR *varBaseFolder);
  void __RPC_STUB IMailbox_get_BaseFolder_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailbox_get_RootFolder_Proxy(IMailbox *This,BSTR *varRootFolder);
  void __RPC_STUB IMailbox_get_RootFolder_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailbox_get_Inbox_Proxy(IMailbox *This,BSTR *varInbox);
  void __RPC_STUB IMailbox_get_Inbox_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailbox_get_Outbox_Proxy(IMailbox *This,BSTR *varOutbox);
  void __RPC_STUB IMailbox_get_Outbox_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailbox_get_SentItems_Proxy(IMailbox *This,BSTR *varSentItems);
  void __RPC_STUB IMailbox_get_SentItems_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailbox_get_Drafts_Proxy(IMailbox *This,BSTR *varDrafts);
  void __RPC_STUB IMailbox_get_Drafts_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailbox_get_DeletedItems_Proxy(IMailbox *This,BSTR *varDeletedItems);
  void __RPC_STUB IMailbox_get_DeletedItems_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailbox_get_Calendar_Proxy(IMailbox *This,BSTR *varCalendar);
  void __RPC_STUB IMailbox_get_Calendar_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailbox_get_Tasks_Proxy(IMailbox *This,BSTR *varTasks);
  void __RPC_STUB IMailbox_get_Tasks_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailbox_get_Contacts_Proxy(IMailbox *This,BSTR *varContacts);
  void __RPC_STUB IMailbox_get_Contacts_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailbox_get_Notes_Proxy(IMailbox *This,BSTR *varNotes);
  void __RPC_STUB IMailbox_get_Notes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMailbox_get_Journal_Proxy(IMailbox *This,BSTR *varJournal);
  void __RPC_STUB IMailbox_get_Journal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IFolder_INTERFACE_DEFINED__
#define __IFolder_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IFolder;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IFolder : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DisplayName(BSTR *varDisplayName) = 0;
    virtual HRESULT WINAPI get_Configuration(IConfiguration **pConfiguration) = 0;
    virtual HRESULT WINAPI put_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI putref_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI get_DataSource(IDataSource **varDataSource) = 0;
    virtual HRESULT WINAPI get_EmailAddress(BSTR *varEmailAddress) = 0;
    virtual HRESULT WINAPI get_UnreadItemCount(LONG *varUnreadItemCount) = 0;
    virtual HRESULT WINAPI get_VisibleCount(LONG *varVisibleCount) = 0;
    virtual HRESULT WINAPI get_ItemCount(LONG *varItemCount) = 0;
    virtual HRESULT WINAPI get_HasSubFolders(VARIANT_BOOL *varHasSubFolders) = 0;
    virtual HRESULT WINAPI get_Description(BSTR *pDescription) = 0;
    virtual HRESULT WINAPI put_Description(BSTR varDescription) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_ContentClass(BSTR *pContentClass) = 0;
    virtual HRESULT WINAPI put_ContentClass(BSTR varContentClass) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
  };
#else
  typedef struct IFolderVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IFolder *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IFolder *This);
      ULONG (WINAPI *Release)(IFolder *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IFolder *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IFolder *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IFolder *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IFolder *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DisplayName)(IFolder *This,BSTR *varDisplayName);
      HRESULT (WINAPI *get_Configuration)(IFolder *This,IConfiguration **pConfiguration);
      HRESULT (WINAPI *put_Configuration)(IFolder *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *putref_Configuration)(IFolder *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *get_DataSource)(IFolder *This,IDataSource **varDataSource);
      HRESULT (WINAPI *get_EmailAddress)(IFolder *This,BSTR *varEmailAddress);
      HRESULT (WINAPI *get_UnreadItemCount)(IFolder *This,LONG *varUnreadItemCount);
      HRESULT (WINAPI *get_VisibleCount)(IFolder *This,LONG *varVisibleCount);
      HRESULT (WINAPI *get_ItemCount)(IFolder *This,LONG *varItemCount);
      HRESULT (WINAPI *get_HasSubFolders)(IFolder *This,VARIANT_BOOL *varHasSubFolders);
      HRESULT (WINAPI *get_Description)(IFolder *This,BSTR *pDescription);
      HRESULT (WINAPI *put_Description)(IFolder *This,BSTR varDescription);
      HRESULT (WINAPI *get_Fields)(IFolder *This,Fields **varFields);
      HRESULT (WINAPI *get_ContentClass)(IFolder *This,BSTR *pContentClass);
      HRESULT (WINAPI *put_ContentClass)(IFolder *This,BSTR varContentClass);
      HRESULT (WINAPI *GetInterface)(IFolder *This,BSTR Interface,IDispatch **ppUnknown);
    END_INTERFACE
  } IFolderVtbl;
  struct IFolder {
    CONST_VTBL struct IFolderVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IFolder_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IFolder_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IFolder_Release(This) (This)->lpVtbl->Release(This)
#define IFolder_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IFolder_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IFolder_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IFolder_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IFolder_get_DisplayName(This,varDisplayName) (This)->lpVtbl->get_DisplayName(This,varDisplayName)
#define IFolder_get_Configuration(This,pConfiguration) (This)->lpVtbl->get_Configuration(This,pConfiguration)
#define IFolder_put_Configuration(This,varConfiguration) (This)->lpVtbl->put_Configuration(This,varConfiguration)
#define IFolder_putref_Configuration(This,varConfiguration) (This)->lpVtbl->putref_Configuration(This,varConfiguration)
#define IFolder_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IFolder_get_EmailAddress(This,varEmailAddress) (This)->lpVtbl->get_EmailAddress(This,varEmailAddress)
#define IFolder_get_UnreadItemCount(This,varUnreadItemCount) (This)->lpVtbl->get_UnreadItemCount(This,varUnreadItemCount)
#define IFolder_get_VisibleCount(This,varVisibleCount) (This)->lpVtbl->get_VisibleCount(This,varVisibleCount)
#define IFolder_get_ItemCount(This,varItemCount) (This)->lpVtbl->get_ItemCount(This,varItemCount)
#define IFolder_get_HasSubFolders(This,varHasSubFolders) (This)->lpVtbl->get_HasSubFolders(This,varHasSubFolders)
#define IFolder_get_Description(This,pDescription) (This)->lpVtbl->get_Description(This,pDescription)
#define IFolder_put_Description(This,varDescription) (This)->lpVtbl->put_Description(This,varDescription)
#define IFolder_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IFolder_get_ContentClass(This,pContentClass) (This)->lpVtbl->get_ContentClass(This,pContentClass)
#define IFolder_put_ContentClass(This,varContentClass) (This)->lpVtbl->put_ContentClass(This,varContentClass)
#define IFolder_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#endif
#endif
  HRESULT WINAPI IFolder_get_DisplayName_Proxy(IFolder *This,BSTR *varDisplayName);
  void __RPC_STUB IFolder_get_DisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_get_Configuration_Proxy(IFolder *This,IConfiguration **pConfiguration);
  void __RPC_STUB IFolder_get_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_put_Configuration_Proxy(IFolder *This,IConfiguration *varConfiguration);
  void __RPC_STUB IFolder_put_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_putref_Configuration_Proxy(IFolder *This,IConfiguration *varConfiguration);
  void __RPC_STUB IFolder_putref_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_get_DataSource_Proxy(IFolder *This,IDataSource **varDataSource);
  void __RPC_STUB IFolder_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_get_EmailAddress_Proxy(IFolder *This,BSTR *varEmailAddress);
  void __RPC_STUB IFolder_get_EmailAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_get_UnreadItemCount_Proxy(IFolder *This,LONG *varUnreadItemCount);
  void __RPC_STUB IFolder_get_UnreadItemCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_get_VisibleCount_Proxy(IFolder *This,LONG *varVisibleCount);
  void __RPC_STUB IFolder_get_VisibleCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_get_ItemCount_Proxy(IFolder *This,LONG *varItemCount);
  void __RPC_STUB IFolder_get_ItemCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_get_HasSubFolders_Proxy(IFolder *This,VARIANT_BOOL *varHasSubFolders);
  void __RPC_STUB IFolder_get_HasSubFolders_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_get_Description_Proxy(IFolder *This,BSTR *pDescription);
  void __RPC_STUB IFolder_get_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_put_Description_Proxy(IFolder *This,BSTR varDescription);
  void __RPC_STUB IFolder_put_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_get_Fields_Proxy(IFolder *This,Fields **varFields);
  void __RPC_STUB IFolder_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_get_ContentClass_Proxy(IFolder *This,BSTR *pContentClass);
  void __RPC_STUB IFolder_get_ContentClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_put_ContentClass_Proxy(IFolder *This,BSTR varContentClass);
  void __RPC_STUB IFolder_put_ContentClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IFolder_GetInterface_Proxy(IFolder *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IFolder_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IContactGroupMembers_INTERFACE_DEFINED__
#define __IContactGroupMembers_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IContactGroupMembers;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IContactGroupMembers : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Index,BSTR *pVal) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI Delete(BSTR *Member) = 0;
    virtual HRESULT WINAPI Add(BSTR val) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **Unknown) = 0;
  };
#else
  typedef struct IContactGroupMembersVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IContactGroupMembers *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IContactGroupMembers *This);
      ULONG (WINAPI *Release)(IContactGroupMembers *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IContactGroupMembers *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IContactGroupMembers *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IContactGroupMembers *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IContactGroupMembers *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IContactGroupMembers *This,__LONG32 Index,BSTR *pVal);
      HRESULT (WINAPI *get_Count)(IContactGroupMembers *This,__LONG32 *Count);
      HRESULT (WINAPI *Delete)(IContactGroupMembers *This,BSTR *Member);
      HRESULT (WINAPI *Add)(IContactGroupMembers *This,BSTR val);
      HRESULT (WINAPI *get__NewEnum)(IContactGroupMembers *This,IUnknown **Unknown);
    END_INTERFACE
  } IContactGroupMembersVtbl;
  struct IContactGroupMembers {
    CONST_VTBL struct IContactGroupMembersVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IContactGroupMembers_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IContactGroupMembers_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IContactGroupMembers_Release(This) (This)->lpVtbl->Release(This)
#define IContactGroupMembers_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IContactGroupMembers_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IContactGroupMembers_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IContactGroupMembers_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IContactGroupMembers_get_Item(This,Index,pVal) (This)->lpVtbl->get_Item(This,Index,pVal)
#define IContactGroupMembers_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IContactGroupMembers_Delete(This,Member) (This)->lpVtbl->Delete(This,Member)
#define IContactGroupMembers_Add(This,val) (This)->lpVtbl->Add(This,val)
#define IContactGroupMembers_get__NewEnum(This,Unknown) (This)->lpVtbl->get__NewEnum(This,Unknown)
#endif
#endif
  HRESULT WINAPI IContactGroupMembers_get_Item_Proxy(IContactGroupMembers *This,__LONG32 Index,BSTR *pVal);
  void __RPC_STUB IContactGroupMembers_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IContactGroupMembers_get_Count_Proxy(IContactGroupMembers *This,__LONG32 *Count);
  void __RPC_STUB IContactGroupMembers_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IContactGroupMembers_Delete_Proxy(IContactGroupMembers *This,BSTR *Member);
  void __RPC_STUB IContactGroupMembers_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IContactGroupMembers_Add_Proxy(IContactGroupMembers *This,BSTR val);
  void __RPC_STUB IContactGroupMembers_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IContactGroupMembers_get__NewEnum_Proxy(IContactGroupMembers *This,IUnknown **Unknown);
  void __RPC_STUB IContactGroupMembers_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IPerson_INTERFACE_DEFINED__
#define __IPerson_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IPerson;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPerson : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DataSource(IDataSource **varDataSource) = 0;
    virtual HRESULT WINAPI get_Configuration(IConfiguration **pConfiguration) = 0;
    virtual HRESULT WINAPI put_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI putref_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_MailingAddressID(CdoMailingAddressIdValues *pMailingAddressID) = 0;
    virtual HRESULT WINAPI put_MailingAddressID(CdoMailingAddressIdValues varMailingAddressID) = 0;
    virtual HRESULT WINAPI get_MailingAddress(BSTR *varMailingAddress) = 0;
    virtual HRESULT WINAPI get_FileAsMapping(CdoFileAsMappingId *pFileAsMapping) = 0;
    virtual HRESULT WINAPI put_FileAsMapping(CdoFileAsMappingId varFileAsMapping) = 0;
    virtual HRESULT WINAPI get_FileAs(BSTR *pFileAs) = 0;
    virtual HRESULT WINAPI put_FileAs(BSTR varFileAs) = 0;
    virtual HRESULT WINAPI get_WorkPhone(BSTR *pWorkPhone) = 0;
    virtual HRESULT WINAPI put_WorkPhone(BSTR varWorkPhone) = 0;
    virtual HRESULT WINAPI get_WorkFax(BSTR *pWorkFax) = 0;
    virtual HRESULT WINAPI put_WorkFax(BSTR varWorkFax) = 0;
    virtual HRESULT WINAPI get_HomePhone(BSTR *pHomePhone) = 0;
    virtual HRESULT WINAPI put_HomePhone(BSTR varHomePhone) = 0;
    virtual HRESULT WINAPI get_MobilePhone(BSTR *pMobilePhone) = 0;
    virtual HRESULT WINAPI put_MobilePhone(BSTR varMobilePhone) = 0;
    virtual HRESULT WINAPI get_FirstName(BSTR *pFirstName) = 0;
    virtual HRESULT WINAPI put_FirstName(BSTR varFirstName) = 0;
    virtual HRESULT WINAPI get_LastName(BSTR *pLastName) = 0;
    virtual HRESULT WINAPI put_LastName(BSTR varLastName) = 0;
    virtual HRESULT WINAPI get_NamePrefix(BSTR *pNamePrefix) = 0;
    virtual HRESULT WINAPI put_NamePrefix(BSTR varNamePrefix) = 0;
    virtual HRESULT WINAPI get_NameSuffix(BSTR *pNameSuffix) = 0;
    virtual HRESULT WINAPI put_NameSuffix(BSTR varNameSuffix) = 0;
    virtual HRESULT WINAPI get_Email(BSTR *pEmail) = 0;
    virtual HRESULT WINAPI put_Email(BSTR varEmail) = 0;
    virtual HRESULT WINAPI get_Email2(BSTR *pEmail2) = 0;
    virtual HRESULT WINAPI put_Email2(BSTR varEmail2) = 0;
    virtual HRESULT WINAPI get_Email3(BSTR *pEmail3) = 0;
    virtual HRESULT WINAPI put_Email3(BSTR varEmail3) = 0;
    virtual HRESULT WINAPI GetVCardStream(_Stream **Stream) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
    virtual HRESULT WINAPI get_WorkStreet(BSTR *pWorkStreet) = 0;
    virtual HRESULT WINAPI put_WorkStreet(BSTR varWorkStreet) = 0;
    virtual HRESULT WINAPI get_WorkCity(BSTR *pWorkCity) = 0;
    virtual HRESULT WINAPI put_WorkCity(BSTR varWorkCity) = 0;
    virtual HRESULT WINAPI get_WorkCountry(BSTR *pWorkCountry) = 0;
    virtual HRESULT WINAPI put_WorkCountry(BSTR varWorkCountry) = 0;
    virtual HRESULT WINAPI get_WorkPostalCode(BSTR *pWorkPostalCode) = 0;
    virtual HRESULT WINAPI put_WorkPostalCode(BSTR varWorkPostalCode) = 0;
    virtual HRESULT WINAPI get_WorkPostOfficeBox(BSTR *pWorkPostOfficeBox) = 0;
    virtual HRESULT WINAPI put_WorkPostOfficeBox(BSTR varWorkPostOfficeBox) = 0;
    virtual HRESULT WINAPI get_WorkPostalAddress(BSTR *varWorkPostalAddress) = 0;
    virtual HRESULT WINAPI get_WorkState(BSTR *pWorkState) = 0;
    virtual HRESULT WINAPI put_WorkState(BSTR varWorkState) = 0;
    virtual HRESULT WINAPI get_WorkPager(BSTR *pWorkPager) = 0;
    virtual HRESULT WINAPI put_WorkPager(BSTR varWorkPager) = 0;
    virtual HRESULT WINAPI get_HomeStreet(BSTR *pHomeStreet) = 0;
    virtual HRESULT WINAPI put_HomeStreet(BSTR varHomeStreet) = 0;
    virtual HRESULT WINAPI get_HomeCity(BSTR *pHomeCity) = 0;
    virtual HRESULT WINAPI put_HomeCity(BSTR varHomeCity) = 0;
    virtual HRESULT WINAPI get_HomeCountry(BSTR *pHomeCountry) = 0;
    virtual HRESULT WINAPI put_HomeCountry(BSTR varHomeCountry) = 0;
    virtual HRESULT WINAPI get_HomePostalCode(BSTR *pHomePostalCode) = 0;
    virtual HRESULT WINAPI put_HomePostalCode(BSTR varHomePostalCode) = 0;
    virtual HRESULT WINAPI get_HomePostOfficeBox(BSTR *pHomePostOfficeBox) = 0;
    virtual HRESULT WINAPI put_HomePostOfficeBox(BSTR varHomePostOfficeBox) = 0;
    virtual HRESULT WINAPI get_HomePostalAddress(BSTR *varHomePostalAddress) = 0;
    virtual HRESULT WINAPI get_HomeState(BSTR *pHomeState) = 0;
    virtual HRESULT WINAPI put_HomeState(BSTR varHomeState) = 0;
    virtual HRESULT WINAPI get_HomeFax(BSTR *pHomeFax) = 0;
    virtual HRESULT WINAPI put_HomeFax(BSTR varHomeFax) = 0;
    virtual HRESULT WINAPI get_MiddleName(BSTR *pMiddleName) = 0;
    virtual HRESULT WINAPI put_MiddleName(BSTR varMiddleName) = 0;
    virtual HRESULT WINAPI get_Initials(BSTR *pInitials) = 0;
    virtual HRESULT WINAPI put_Initials(BSTR varInitials) = 0;
    virtual HRESULT WINAPI get_EmailAddresses(VARIANT *pEmailAddresses) = 0;
    virtual HRESULT WINAPI put_EmailAddresses(VARIANT varEmailAddresses) = 0;
    virtual HRESULT WINAPI get_Company(BSTR *pCompany) = 0;
    virtual HRESULT WINAPI put_Company(BSTR varCompany) = 0;
    virtual HRESULT WINAPI get_Title(BSTR *pTitle) = 0;
    virtual HRESULT WINAPI put_Title(BSTR varTitle) = 0;
  };
#else
  typedef struct IPersonVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPerson *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPerson *This);
      ULONG (WINAPI *Release)(IPerson *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IPerson *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IPerson *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IPerson *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IPerson *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DataSource)(IPerson *This,IDataSource **varDataSource);
      HRESULT (WINAPI *get_Configuration)(IPerson *This,IConfiguration **pConfiguration);
      HRESULT (WINAPI *put_Configuration)(IPerson *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *putref_Configuration)(IPerson *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *get_Fields)(IPerson *This,Fields **varFields);
      HRESULT (WINAPI *get_MailingAddressID)(IPerson *This,CdoMailingAddressIdValues *pMailingAddressID);
      HRESULT (WINAPI *put_MailingAddressID)(IPerson *This,CdoMailingAddressIdValues varMailingAddressID);
      HRESULT (WINAPI *get_MailingAddress)(IPerson *This,BSTR *varMailingAddress);
      HRESULT (WINAPI *get_FileAsMapping)(IPerson *This,CdoFileAsMappingId *pFileAsMapping);
      HRESULT (WINAPI *put_FileAsMapping)(IPerson *This,CdoFileAsMappingId varFileAsMapping);
      HRESULT (WINAPI *get_FileAs)(IPerson *This,BSTR *pFileAs);
      HRESULT (WINAPI *put_FileAs)(IPerson *This,BSTR varFileAs);
      HRESULT (WINAPI *get_WorkPhone)(IPerson *This,BSTR *pWorkPhone);
      HRESULT (WINAPI *put_WorkPhone)(IPerson *This,BSTR varWorkPhone);
      HRESULT (WINAPI *get_WorkFax)(IPerson *This,BSTR *pWorkFax);
      HRESULT (WINAPI *put_WorkFax)(IPerson *This,BSTR varWorkFax);
      HRESULT (WINAPI *get_HomePhone)(IPerson *This,BSTR *pHomePhone);
      HRESULT (WINAPI *put_HomePhone)(IPerson *This,BSTR varHomePhone);
      HRESULT (WINAPI *get_MobilePhone)(IPerson *This,BSTR *pMobilePhone);
      HRESULT (WINAPI *put_MobilePhone)(IPerson *This,BSTR varMobilePhone);
      HRESULT (WINAPI *get_FirstName)(IPerson *This,BSTR *pFirstName);
      HRESULT (WINAPI *put_FirstName)(IPerson *This,BSTR varFirstName);
      HRESULT (WINAPI *get_LastName)(IPerson *This,BSTR *pLastName);
      HRESULT (WINAPI *put_LastName)(IPerson *This,BSTR varLastName);
      HRESULT (WINAPI *get_NamePrefix)(IPerson *This,BSTR *pNamePrefix);
      HRESULT (WINAPI *put_NamePrefix)(IPerson *This,BSTR varNamePrefix);
      HRESULT (WINAPI *get_NameSuffix)(IPerson *This,BSTR *pNameSuffix);
      HRESULT (WINAPI *put_NameSuffix)(IPerson *This,BSTR varNameSuffix);
      HRESULT (WINAPI *get_Email)(IPerson *This,BSTR *pEmail);
      HRESULT (WINAPI *put_Email)(IPerson *This,BSTR varEmail);
      HRESULT (WINAPI *get_Email2)(IPerson *This,BSTR *pEmail2);
      HRESULT (WINAPI *put_Email2)(IPerson *This,BSTR varEmail2);
      HRESULT (WINAPI *get_Email3)(IPerson *This,BSTR *pEmail3);
      HRESULT (WINAPI *put_Email3)(IPerson *This,BSTR varEmail3);
      HRESULT (WINAPI *GetVCardStream)(IPerson *This,_Stream **Stream);
      HRESULT (WINAPI *GetInterface)(IPerson *This,BSTR Interface,IDispatch **ppUnknown);
      HRESULT (WINAPI *get_WorkStreet)(IPerson *This,BSTR *pWorkStreet);
      HRESULT (WINAPI *put_WorkStreet)(IPerson *This,BSTR varWorkStreet);
      HRESULT (WINAPI *get_WorkCity)(IPerson *This,BSTR *pWorkCity);
      HRESULT (WINAPI *put_WorkCity)(IPerson *This,BSTR varWorkCity);
      HRESULT (WINAPI *get_WorkCountry)(IPerson *This,BSTR *pWorkCountry);
      HRESULT (WINAPI *put_WorkCountry)(IPerson *This,BSTR varWorkCountry);
      HRESULT (WINAPI *get_WorkPostalCode)(IPerson *This,BSTR *pWorkPostalCode);
      HRESULT (WINAPI *put_WorkPostalCode)(IPerson *This,BSTR varWorkPostalCode);
      HRESULT (WINAPI *get_WorkPostOfficeBox)(IPerson *This,BSTR *pWorkPostOfficeBox);
      HRESULT (WINAPI *put_WorkPostOfficeBox)(IPerson *This,BSTR varWorkPostOfficeBox);
      HRESULT (WINAPI *get_WorkPostalAddress)(IPerson *This,BSTR *varWorkPostalAddress);
      HRESULT (WINAPI *get_WorkState)(IPerson *This,BSTR *pWorkState);
      HRESULT (WINAPI *put_WorkState)(IPerson *This,BSTR varWorkState);
      HRESULT (WINAPI *get_WorkPager)(IPerson *This,BSTR *pWorkPager);
      HRESULT (WINAPI *put_WorkPager)(IPerson *This,BSTR varWorkPager);
      HRESULT (WINAPI *get_HomeStreet)(IPerson *This,BSTR *pHomeStreet);
      HRESULT (WINAPI *put_HomeStreet)(IPerson *This,BSTR varHomeStreet);
      HRESULT (WINAPI *get_HomeCity)(IPerson *This,BSTR *pHomeCity);
      HRESULT (WINAPI *put_HomeCity)(IPerson *This,BSTR varHomeCity);
      HRESULT (WINAPI *get_HomeCountry)(IPerson *This,BSTR *pHomeCountry);
      HRESULT (WINAPI *put_HomeCountry)(IPerson *This,BSTR varHomeCountry);
      HRESULT (WINAPI *get_HomePostalCode)(IPerson *This,BSTR *pHomePostalCode);
      HRESULT (WINAPI *put_HomePostalCode)(IPerson *This,BSTR varHomePostalCode);
      HRESULT (WINAPI *get_HomePostOfficeBox)(IPerson *This,BSTR *pHomePostOfficeBox);
      HRESULT (WINAPI *put_HomePostOfficeBox)(IPerson *This,BSTR varHomePostOfficeBox);
      HRESULT (WINAPI *get_HomePostalAddress)(IPerson *This,BSTR *varHomePostalAddress);
      HRESULT (WINAPI *get_HomeState)(IPerson *This,BSTR *pHomeState);
      HRESULT (WINAPI *put_HomeState)(IPerson *This,BSTR varHomeState);
      HRESULT (WINAPI *get_HomeFax)(IPerson *This,BSTR *pHomeFax);
      HRESULT (WINAPI *put_HomeFax)(IPerson *This,BSTR varHomeFax);
      HRESULT (WINAPI *get_MiddleName)(IPerson *This,BSTR *pMiddleName);
      HRESULT (WINAPI *put_MiddleName)(IPerson *This,BSTR varMiddleName);
      HRESULT (WINAPI *get_Initials)(IPerson *This,BSTR *pInitials);
      HRESULT (WINAPI *put_Initials)(IPerson *This,BSTR varInitials);
      HRESULT (WINAPI *get_EmailAddresses)(IPerson *This,VARIANT *pEmailAddresses);
      HRESULT (WINAPI *put_EmailAddresses)(IPerson *This,VARIANT varEmailAddresses);
      HRESULT (WINAPI *get_Company)(IPerson *This,BSTR *pCompany);
      HRESULT (WINAPI *put_Company)(IPerson *This,BSTR varCompany);
      HRESULT (WINAPI *get_Title)(IPerson *This,BSTR *pTitle);
      HRESULT (WINAPI *put_Title)(IPerson *This,BSTR varTitle);
    END_INTERFACE
  } IPersonVtbl;
  struct IPerson {
    CONST_VTBL struct IPersonVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPerson_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPerson_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPerson_Release(This) (This)->lpVtbl->Release(This)
#define IPerson_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IPerson_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IPerson_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IPerson_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IPerson_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IPerson_get_Configuration(This,pConfiguration) (This)->lpVtbl->get_Configuration(This,pConfiguration)
#define IPerson_put_Configuration(This,varConfiguration) (This)->lpVtbl->put_Configuration(This,varConfiguration)
#define IPerson_putref_Configuration(This,varConfiguration) (This)->lpVtbl->putref_Configuration(This,varConfiguration)
#define IPerson_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IPerson_get_MailingAddressID(This,pMailingAddressID) (This)->lpVtbl->get_MailingAddressID(This,pMailingAddressID)
#define IPerson_put_MailingAddressID(This,varMailingAddressID) (This)->lpVtbl->put_MailingAddressID(This,varMailingAddressID)
#define IPerson_get_MailingAddress(This,varMailingAddress) (This)->lpVtbl->get_MailingAddress(This,varMailingAddress)
#define IPerson_get_FileAsMapping(This,pFileAsMapping) (This)->lpVtbl->get_FileAsMapping(This,pFileAsMapping)
#define IPerson_put_FileAsMapping(This,varFileAsMapping) (This)->lpVtbl->put_FileAsMapping(This,varFileAsMapping)
#define IPerson_get_FileAs(This,pFileAs) (This)->lpVtbl->get_FileAs(This,pFileAs)
#define IPerson_put_FileAs(This,varFileAs) (This)->lpVtbl->put_FileAs(This,varFileAs)
#define IPerson_get_WorkPhone(This,pWorkPhone) (This)->lpVtbl->get_WorkPhone(This,pWorkPhone)
#define IPerson_put_WorkPhone(This,varWorkPhone) (This)->lpVtbl->put_WorkPhone(This,varWorkPhone)
#define IPerson_get_WorkFax(This,pWorkFax) (This)->lpVtbl->get_WorkFax(This,pWorkFax)
#define IPerson_put_WorkFax(This,varWorkFax) (This)->lpVtbl->put_WorkFax(This,varWorkFax)
#define IPerson_get_HomePhone(This,pHomePhone) (This)->lpVtbl->get_HomePhone(This,pHomePhone)
#define IPerson_put_HomePhone(This,varHomePhone) (This)->lpVtbl->put_HomePhone(This,varHomePhone)
#define IPerson_get_MobilePhone(This,pMobilePhone) (This)->lpVtbl->get_MobilePhone(This,pMobilePhone)
#define IPerson_put_MobilePhone(This,varMobilePhone) (This)->lpVtbl->put_MobilePhone(This,varMobilePhone)
#define IPerson_get_FirstName(This,pFirstName) (This)->lpVtbl->get_FirstName(This,pFirstName)
#define IPerson_put_FirstName(This,varFirstName) (This)->lpVtbl->put_FirstName(This,varFirstName)
#define IPerson_get_LastName(This,pLastName) (This)->lpVtbl->get_LastName(This,pLastName)
#define IPerson_put_LastName(This,varLastName) (This)->lpVtbl->put_LastName(This,varLastName)
#define IPerson_get_NamePrefix(This,pNamePrefix) (This)->lpVtbl->get_NamePrefix(This,pNamePrefix)
#define IPerson_put_NamePrefix(This,varNamePrefix) (This)->lpVtbl->put_NamePrefix(This,varNamePrefix)
#define IPerson_get_NameSuffix(This,pNameSuffix) (This)->lpVtbl->get_NameSuffix(This,pNameSuffix)
#define IPerson_put_NameSuffix(This,varNameSuffix) (This)->lpVtbl->put_NameSuffix(This,varNameSuffix)
#define IPerson_get_Email(This,pEmail) (This)->lpVtbl->get_Email(This,pEmail)
#define IPerson_put_Email(This,varEmail) (This)->lpVtbl->put_Email(This,varEmail)
#define IPerson_get_Email2(This,pEmail2) (This)->lpVtbl->get_Email2(This,pEmail2)
#define IPerson_put_Email2(This,varEmail2) (This)->lpVtbl->put_Email2(This,varEmail2)
#define IPerson_get_Email3(This,pEmail3) (This)->lpVtbl->get_Email3(This,pEmail3)
#define IPerson_put_Email3(This,varEmail3) (This)->lpVtbl->put_Email3(This,varEmail3)
#define IPerson_GetVCardStream(This,Stream) (This)->lpVtbl->GetVCardStream(This,Stream)
#define IPerson_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#define IPerson_get_WorkStreet(This,pWorkStreet) (This)->lpVtbl->get_WorkStreet(This,pWorkStreet)
#define IPerson_put_WorkStreet(This,varWorkStreet) (This)->lpVtbl->put_WorkStreet(This,varWorkStreet)
#define IPerson_get_WorkCity(This,pWorkCity) (This)->lpVtbl->get_WorkCity(This,pWorkCity)
#define IPerson_put_WorkCity(This,varWorkCity) (This)->lpVtbl->put_WorkCity(This,varWorkCity)
#define IPerson_get_WorkCountry(This,pWorkCountry) (This)->lpVtbl->get_WorkCountry(This,pWorkCountry)
#define IPerson_put_WorkCountry(This,varWorkCountry) (This)->lpVtbl->put_WorkCountry(This,varWorkCountry)
#define IPerson_get_WorkPostalCode(This,pWorkPostalCode) (This)->lpVtbl->get_WorkPostalCode(This,pWorkPostalCode)
#define IPerson_put_WorkPostalCode(This,varWorkPostalCode) (This)->lpVtbl->put_WorkPostalCode(This,varWorkPostalCode)
#define IPerson_get_WorkPostOfficeBox(This,pWorkPostOfficeBox) (This)->lpVtbl->get_WorkPostOfficeBox(This,pWorkPostOfficeBox)
#define IPerson_put_WorkPostOfficeBox(This,varWorkPostOfficeBox) (This)->lpVtbl->put_WorkPostOfficeBox(This,varWorkPostOfficeBox)
#define IPerson_get_WorkPostalAddress(This,varWorkPostalAddress) (This)->lpVtbl->get_WorkPostalAddress(This,varWorkPostalAddress)
#define IPerson_get_WorkState(This,pWorkState) (This)->lpVtbl->get_WorkState(This,pWorkState)
#define IPerson_put_WorkState(This,varWorkState) (This)->lpVtbl->put_WorkState(This,varWorkState)
#define IPerson_get_WorkPager(This,pWorkPager) (This)->lpVtbl->get_WorkPager(This,pWorkPager)
#define IPerson_put_WorkPager(This,varWorkPager) (This)->lpVtbl->put_WorkPager(This,varWorkPager)
#define IPerson_get_HomeStreet(This,pHomeStreet) (This)->lpVtbl->get_HomeStreet(This,pHomeStreet)
#define IPerson_put_HomeStreet(This,varHomeStreet) (This)->lpVtbl->put_HomeStreet(This,varHomeStreet)
#define IPerson_get_HomeCity(This,pHomeCity) (This)->lpVtbl->get_HomeCity(This,pHomeCity)
#define IPerson_put_HomeCity(This,varHomeCity) (This)->lpVtbl->put_HomeCity(This,varHomeCity)
#define IPerson_get_HomeCountry(This,pHomeCountry) (This)->lpVtbl->get_HomeCountry(This,pHomeCountry)
#define IPerson_put_HomeCountry(This,varHomeCountry) (This)->lpVtbl->put_HomeCountry(This,varHomeCountry)
#define IPerson_get_HomePostalCode(This,pHomePostalCode) (This)->lpVtbl->get_HomePostalCode(This,pHomePostalCode)
#define IPerson_put_HomePostalCode(This,varHomePostalCode) (This)->lpVtbl->put_HomePostalCode(This,varHomePostalCode)
#define IPerson_get_HomePostOfficeBox(This,pHomePostOfficeBox) (This)->lpVtbl->get_HomePostOfficeBox(This,pHomePostOfficeBox)
#define IPerson_put_HomePostOfficeBox(This,varHomePostOfficeBox) (This)->lpVtbl->put_HomePostOfficeBox(This,varHomePostOfficeBox)
#define IPerson_get_HomePostalAddress(This,varHomePostalAddress) (This)->lpVtbl->get_HomePostalAddress(This,varHomePostalAddress)
#define IPerson_get_HomeState(This,pHomeState) (This)->lpVtbl->get_HomeState(This,pHomeState)
#define IPerson_put_HomeState(This,varHomeState) (This)->lpVtbl->put_HomeState(This,varHomeState)
#define IPerson_get_HomeFax(This,pHomeFax) (This)->lpVtbl->get_HomeFax(This,pHomeFax)
#define IPerson_put_HomeFax(This,varHomeFax) (This)->lpVtbl->put_HomeFax(This,varHomeFax)
#define IPerson_get_MiddleName(This,pMiddleName) (This)->lpVtbl->get_MiddleName(This,pMiddleName)
#define IPerson_put_MiddleName(This,varMiddleName) (This)->lpVtbl->put_MiddleName(This,varMiddleName)
#define IPerson_get_Initials(This,pInitials) (This)->lpVtbl->get_Initials(This,pInitials)
#define IPerson_put_Initials(This,varInitials) (This)->lpVtbl->put_Initials(This,varInitials)
#define IPerson_get_EmailAddresses(This,pEmailAddresses) (This)->lpVtbl->get_EmailAddresses(This,pEmailAddresses)
#define IPerson_put_EmailAddresses(This,varEmailAddresses) (This)->lpVtbl->put_EmailAddresses(This,varEmailAddresses)
#define IPerson_get_Company(This,pCompany) (This)->lpVtbl->get_Company(This,pCompany)
#define IPerson_put_Company(This,varCompany) (This)->lpVtbl->put_Company(This,varCompany)
#define IPerson_get_Title(This,pTitle) (This)->lpVtbl->get_Title(This,pTitle)
#define IPerson_put_Title(This,varTitle) (This)->lpVtbl->put_Title(This,varTitle)
#endif
#endif
  HRESULT WINAPI IPerson_get_DataSource_Proxy(IPerson *This,IDataSource **varDataSource);
  void __RPC_STUB IPerson_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_Configuration_Proxy(IPerson *This,IConfiguration **pConfiguration);
  void __RPC_STUB IPerson_get_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_Configuration_Proxy(IPerson *This,IConfiguration *varConfiguration);
  void __RPC_STUB IPerson_put_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_putref_Configuration_Proxy(IPerson *This,IConfiguration *varConfiguration);
  void __RPC_STUB IPerson_putref_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_Fields_Proxy(IPerson *This,Fields **varFields);
  void __RPC_STUB IPerson_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_MailingAddressID_Proxy(IPerson *This,CdoMailingAddressIdValues *pMailingAddressID);
  void __RPC_STUB IPerson_get_MailingAddressID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_MailingAddressID_Proxy(IPerson *This,CdoMailingAddressIdValues varMailingAddressID);
  void __RPC_STUB IPerson_put_MailingAddressID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_MailingAddress_Proxy(IPerson *This,BSTR *varMailingAddress);
  void __RPC_STUB IPerson_get_MailingAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_FileAsMapping_Proxy(IPerson *This,CdoFileAsMappingId *pFileAsMapping);
  void __RPC_STUB IPerson_get_FileAsMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_FileAsMapping_Proxy(IPerson *This,CdoFileAsMappingId varFileAsMapping);
  void __RPC_STUB IPerson_put_FileAsMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_FileAs_Proxy(IPerson *This,BSTR *pFileAs);
  void __RPC_STUB IPerson_get_FileAs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_FileAs_Proxy(IPerson *This,BSTR varFileAs);
  void __RPC_STUB IPerson_put_FileAs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_WorkPhone_Proxy(IPerson *This,BSTR *pWorkPhone);
  void __RPC_STUB IPerson_get_WorkPhone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_WorkPhone_Proxy(IPerson *This,BSTR varWorkPhone);
  void __RPC_STUB IPerson_put_WorkPhone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_WorkFax_Proxy(IPerson *This,BSTR *pWorkFax);
  void __RPC_STUB IPerson_get_WorkFax_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_WorkFax_Proxy(IPerson *This,BSTR varWorkFax);
  void __RPC_STUB IPerson_put_WorkFax_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_HomePhone_Proxy(IPerson *This,BSTR *pHomePhone);
  void __RPC_STUB IPerson_get_HomePhone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_HomePhone_Proxy(IPerson *This,BSTR varHomePhone);
  void __RPC_STUB IPerson_put_HomePhone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_MobilePhone_Proxy(IPerson *This,BSTR *pMobilePhone);
  void __RPC_STUB IPerson_get_MobilePhone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_MobilePhone_Proxy(IPerson *This,BSTR varMobilePhone);
  void __RPC_STUB IPerson_put_MobilePhone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_FirstName_Proxy(IPerson *This,BSTR *pFirstName);
  void __RPC_STUB IPerson_get_FirstName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_FirstName_Proxy(IPerson *This,BSTR varFirstName);
  void __RPC_STUB IPerson_put_FirstName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_LastName_Proxy(IPerson *This,BSTR *pLastName);
  void __RPC_STUB IPerson_get_LastName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_LastName_Proxy(IPerson *This,BSTR varLastName);
  void __RPC_STUB IPerson_put_LastName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_NamePrefix_Proxy(IPerson *This,BSTR *pNamePrefix);
  void __RPC_STUB IPerson_get_NamePrefix_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_NamePrefix_Proxy(IPerson *This,BSTR varNamePrefix);
  void __RPC_STUB IPerson_put_NamePrefix_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_NameSuffix_Proxy(IPerson *This,BSTR *pNameSuffix);
  void __RPC_STUB IPerson_get_NameSuffix_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_NameSuffix_Proxy(IPerson *This,BSTR varNameSuffix);
  void __RPC_STUB IPerson_put_NameSuffix_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_Email_Proxy(IPerson *This,BSTR *pEmail);
  void __RPC_STUB IPerson_get_Email_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_Email_Proxy(IPerson *This,BSTR varEmail);
  void __RPC_STUB IPerson_put_Email_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_Email2_Proxy(IPerson *This,BSTR *pEmail2);
  void __RPC_STUB IPerson_get_Email2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_Email2_Proxy(IPerson *This,BSTR varEmail2);
  void __RPC_STUB IPerson_put_Email2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_Email3_Proxy(IPerson *This,BSTR *pEmail3);
  void __RPC_STUB IPerson_get_Email3_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_Email3_Proxy(IPerson *This,BSTR varEmail3);
  void __RPC_STUB IPerson_put_Email3_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_GetVCardStream_Proxy(IPerson *This,_Stream **Stream);
  void __RPC_STUB IPerson_GetVCardStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_GetInterface_Proxy(IPerson *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IPerson_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_WorkStreet_Proxy(IPerson *This,BSTR *pWorkStreet);
  void __RPC_STUB IPerson_get_WorkStreet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_WorkStreet_Proxy(IPerson *This,BSTR varWorkStreet);
  void __RPC_STUB IPerson_put_WorkStreet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_WorkCity_Proxy(IPerson *This,BSTR *pWorkCity);
  void __RPC_STUB IPerson_get_WorkCity_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_WorkCity_Proxy(IPerson *This,BSTR varWorkCity);
  void __RPC_STUB IPerson_put_WorkCity_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_WorkCountry_Proxy(IPerson *This,BSTR *pWorkCountry);
  void __RPC_STUB IPerson_get_WorkCountry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_WorkCountry_Proxy(IPerson *This,BSTR varWorkCountry);
  void __RPC_STUB IPerson_put_WorkCountry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_WorkPostalCode_Proxy(IPerson *This,BSTR *pWorkPostalCode);
  void __RPC_STUB IPerson_get_WorkPostalCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_WorkPostalCode_Proxy(IPerson *This,BSTR varWorkPostalCode);
  void __RPC_STUB IPerson_put_WorkPostalCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_WorkPostOfficeBox_Proxy(IPerson *This,BSTR *pWorkPostOfficeBox);
  void __RPC_STUB IPerson_get_WorkPostOfficeBox_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_WorkPostOfficeBox_Proxy(IPerson *This,BSTR varWorkPostOfficeBox);
  void __RPC_STUB IPerson_put_WorkPostOfficeBox_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_WorkPostalAddress_Proxy(IPerson *This,BSTR *varWorkPostalAddress);
  void __RPC_STUB IPerson_get_WorkPostalAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_WorkState_Proxy(IPerson *This,BSTR *pWorkState);
  void __RPC_STUB IPerson_get_WorkState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_WorkState_Proxy(IPerson *This,BSTR varWorkState);
  void __RPC_STUB IPerson_put_WorkState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_WorkPager_Proxy(IPerson *This,BSTR *pWorkPager);
  void __RPC_STUB IPerson_get_WorkPager_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_WorkPager_Proxy(IPerson *This,BSTR varWorkPager);
  void __RPC_STUB IPerson_put_WorkPager_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_HomeStreet_Proxy(IPerson *This,BSTR *pHomeStreet);
  void __RPC_STUB IPerson_get_HomeStreet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_HomeStreet_Proxy(IPerson *This,BSTR varHomeStreet);
  void __RPC_STUB IPerson_put_HomeStreet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_HomeCity_Proxy(IPerson *This,BSTR *pHomeCity);
  void __RPC_STUB IPerson_get_HomeCity_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_HomeCity_Proxy(IPerson *This,BSTR varHomeCity);
  void __RPC_STUB IPerson_put_HomeCity_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_HomeCountry_Proxy(IPerson *This,BSTR *pHomeCountry);
  void __RPC_STUB IPerson_get_HomeCountry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_HomeCountry_Proxy(IPerson *This,BSTR varHomeCountry);
  void __RPC_STUB IPerson_put_HomeCountry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_HomePostalCode_Proxy(IPerson *This,BSTR *pHomePostalCode);
  void __RPC_STUB IPerson_get_HomePostalCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_HomePostalCode_Proxy(IPerson *This,BSTR varHomePostalCode);
  void __RPC_STUB IPerson_put_HomePostalCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_HomePostOfficeBox_Proxy(IPerson *This,BSTR *pHomePostOfficeBox);
  void __RPC_STUB IPerson_get_HomePostOfficeBox_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_HomePostOfficeBox_Proxy(IPerson *This,BSTR varHomePostOfficeBox);
  void __RPC_STUB IPerson_put_HomePostOfficeBox_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_HomePostalAddress_Proxy(IPerson *This,BSTR *varHomePostalAddress);
  void __RPC_STUB IPerson_get_HomePostalAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_HomeState_Proxy(IPerson *This,BSTR *pHomeState);
  void __RPC_STUB IPerson_get_HomeState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_HomeState_Proxy(IPerson *This,BSTR varHomeState);
  void __RPC_STUB IPerson_put_HomeState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_HomeFax_Proxy(IPerson *This,BSTR *pHomeFax);
  void __RPC_STUB IPerson_get_HomeFax_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_HomeFax_Proxy(IPerson *This,BSTR varHomeFax);
  void __RPC_STUB IPerson_put_HomeFax_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_MiddleName_Proxy(IPerson *This,BSTR *pMiddleName);
  void __RPC_STUB IPerson_get_MiddleName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_MiddleName_Proxy(IPerson *This,BSTR varMiddleName);
  void __RPC_STUB IPerson_put_MiddleName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_Initials_Proxy(IPerson *This,BSTR *pInitials);
  void __RPC_STUB IPerson_get_Initials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_Initials_Proxy(IPerson *This,BSTR varInitials);
  void __RPC_STUB IPerson_put_Initials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_EmailAddresses_Proxy(IPerson *This,VARIANT *pEmailAddresses);
  void __RPC_STUB IPerson_get_EmailAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_EmailAddresses_Proxy(IPerson *This,VARIANT varEmailAddresses);
  void __RPC_STUB IPerson_put_EmailAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_Company_Proxy(IPerson *This,BSTR *pCompany);
  void __RPC_STUB IPerson_get_Company_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_Company_Proxy(IPerson *This,BSTR varCompany);
  void __RPC_STUB IPerson_put_Company_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_get_Title_Proxy(IPerson *This,BSTR *pTitle);
  void __RPC_STUB IPerson_get_Title_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPerson_put_Title_Proxy(IPerson *This,BSTR varTitle);
  void __RPC_STUB IPerson_put_Title_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAddressee_INTERFACE_DEFINED__
#define __IAddressee_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAddressee;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAddressee : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Fields(Fields **varFields) = 0;
    virtual HRESULT WINAPI get_Configuration(IConfiguration **pConfiguration) = 0;
    virtual HRESULT WINAPI put_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI putref_Configuration(IConfiguration *varConfiguration) = 0;
    virtual HRESULT WINAPI get_DisplayName(BSTR *pDisplayName) = 0;
    virtual HRESULT WINAPI put_DisplayName(BSTR varDisplayName) = 0;
    virtual HRESULT WINAPI get_EmailAddress(BSTR *pEmailAddress) = 0;
    virtual HRESULT WINAPI put_EmailAddress(BSTR varEmailAddress) = 0;
    virtual HRESULT WINAPI get_DataSource(IDataSource **varDataSource) = 0;
    virtual HRESULT WINAPI get_DirURL(BSTR *varDirURL) = 0;
    virtual HRESULT WINAPI get_ResolvedStatus(CdoResolvedStatus *pResolvedStatus) = 0;
    virtual HRESULT WINAPI put_ResolvedStatus(CdoResolvedStatus varResolvedStatus) = 0;
    virtual HRESULT WINAPI get_ContentClass(BSTR *varContentClass) = 0;
    virtual HRESULT WINAPI get_AmbiguousNames(IAddressees **varAmbiguousNames) = 0;
    virtual HRESULT WINAPI GetInterface(BSTR Interface,IDispatch **ppUnknown) = 0;
    virtual HRESULT WINAPI GetFreeBusy(DATE StartTime,DATE EndTime,__LONG32 Interval,BSTR HTTPHost,BSTR VRoot,BSTR UserName,BSTR Password,BSTR *pbstrRet) = 0;
    virtual HRESULT WINAPI CheckName(BSTR Directory,BSTR UserName,BSTR Password,VARIANT_BOOL *pBRet) = 0;
  };
#else
  typedef struct IAddresseeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAddressee *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAddressee *This);
      ULONG (WINAPI *Release)(IAddressee *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAddressee *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAddressee *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAddressee *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAddressee *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Fields)(IAddressee *This,Fields **varFields);
      HRESULT (WINAPI *get_Configuration)(IAddressee *This,IConfiguration **pConfiguration);
      HRESULT (WINAPI *put_Configuration)(IAddressee *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *putref_Configuration)(IAddressee *This,IConfiguration *varConfiguration);
      HRESULT (WINAPI *get_DisplayName)(IAddressee *This,BSTR *pDisplayName);
      HRESULT (WINAPI *put_DisplayName)(IAddressee *This,BSTR varDisplayName);
      HRESULT (WINAPI *get_EmailAddress)(IAddressee *This,BSTR *pEmailAddress);
      HRESULT (WINAPI *put_EmailAddress)(IAddressee *This,BSTR varEmailAddress);
      HRESULT (WINAPI *get_DataSource)(IAddressee *This,IDataSource **varDataSource);
      HRESULT (WINAPI *get_DirURL)(IAddressee *This,BSTR *varDirURL);
      HRESULT (WINAPI *get_ResolvedStatus)(IAddressee *This,CdoResolvedStatus *pResolvedStatus);
      HRESULT (WINAPI *put_ResolvedStatus)(IAddressee *This,CdoResolvedStatus varResolvedStatus);
      HRESULT (WINAPI *get_ContentClass)(IAddressee *This,BSTR *varContentClass);
      HRESULT (WINAPI *get_AmbiguousNames)(IAddressee *This,IAddressees **varAmbiguousNames);
      HRESULT (WINAPI *GetInterface)(IAddressee *This,BSTR Interface,IDispatch **ppUnknown);
      HRESULT (WINAPI *GetFreeBusy)(IAddressee *This,DATE StartTime,DATE EndTime,__LONG32 Interval,BSTR HTTPHost,BSTR VRoot,BSTR UserName,BSTR Password,BSTR *pbstrRet);
      HRESULT (WINAPI *CheckName)(IAddressee *This,BSTR Directory,BSTR UserName,BSTR Password,VARIANT_BOOL *pBRet);
    END_INTERFACE
  } IAddresseeVtbl;
  struct IAddressee {
    CONST_VTBL struct IAddresseeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAddressee_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAddressee_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAddressee_Release(This) (This)->lpVtbl->Release(This)
#define IAddressee_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAddressee_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAddressee_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAddressee_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAddressee_get_Fields(This,varFields) (This)->lpVtbl->get_Fields(This,varFields)
#define IAddressee_get_Configuration(This,pConfiguration) (This)->lpVtbl->get_Configuration(This,pConfiguration)
#define IAddressee_put_Configuration(This,varConfiguration) (This)->lpVtbl->put_Configuration(This,varConfiguration)
#define IAddressee_putref_Configuration(This,varConfiguration) (This)->lpVtbl->putref_Configuration(This,varConfiguration)
#define IAddressee_get_DisplayName(This,pDisplayName) (This)->lpVtbl->get_DisplayName(This,pDisplayName)
#define IAddressee_put_DisplayName(This,varDisplayName) (This)->lpVtbl->put_DisplayName(This,varDisplayName)
#define IAddressee_get_EmailAddress(This,pEmailAddress) (This)->lpVtbl->get_EmailAddress(This,pEmailAddress)
#define IAddressee_put_EmailAddress(This,varEmailAddress) (This)->lpVtbl->put_EmailAddress(This,varEmailAddress)
#define IAddressee_get_DataSource(This,varDataSource) (This)->lpVtbl->get_DataSource(This,varDataSource)
#define IAddressee_get_DirURL(This,varDirURL) (This)->lpVtbl->get_DirURL(This,varDirURL)
#define IAddressee_get_ResolvedStatus(This,pResolvedStatus) (This)->lpVtbl->get_ResolvedStatus(This,pResolvedStatus)
#define IAddressee_put_ResolvedStatus(This,varResolvedStatus) (This)->lpVtbl->put_ResolvedStatus(This,varResolvedStatus)
#define IAddressee_get_ContentClass(This,varContentClass) (This)->lpVtbl->get_ContentClass(This,varContentClass)
#define IAddressee_get_AmbiguousNames(This,varAmbiguousNames) (This)->lpVtbl->get_AmbiguousNames(This,varAmbiguousNames)
#define IAddressee_GetInterface(This,Interface,ppUnknown) (This)->lpVtbl->GetInterface(This,Interface,ppUnknown)
#define IAddressee_GetFreeBusy(This,StartTime,EndTime,Interval,HTTPHost,VRoot,UserName,Password,pbstrRet) (This)->lpVtbl->GetFreeBusy(This,StartTime,EndTime,Interval,HTTPHost,VRoot,UserName,Password,pbstrRet)
#define IAddressee_CheckName(This,Directory,UserName,Password,pBRet) (This)->lpVtbl->CheckName(This,Directory,UserName,Password,pBRet)
#endif
#endif
  HRESULT WINAPI IAddressee_get_Fields_Proxy(IAddressee *This,Fields **varFields);
  void __RPC_STUB IAddressee_get_Fields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_get_Configuration_Proxy(IAddressee *This,IConfiguration **pConfiguration);
  void __RPC_STUB IAddressee_get_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_put_Configuration_Proxy(IAddressee *This,IConfiguration *varConfiguration);
  void __RPC_STUB IAddressee_put_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_putref_Configuration_Proxy(IAddressee *This,IConfiguration *varConfiguration);
  void __RPC_STUB IAddressee_putref_Configuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_get_DisplayName_Proxy(IAddressee *This,BSTR *pDisplayName);
  void __RPC_STUB IAddressee_get_DisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_put_DisplayName_Proxy(IAddressee *This,BSTR varDisplayName);
  void __RPC_STUB IAddressee_put_DisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_get_EmailAddress_Proxy(IAddressee *This,BSTR *pEmailAddress);
  void __RPC_STUB IAddressee_get_EmailAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_put_EmailAddress_Proxy(IAddressee *This,BSTR varEmailAddress);
  void __RPC_STUB IAddressee_put_EmailAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_get_DataSource_Proxy(IAddressee *This,IDataSource **varDataSource);
  void __RPC_STUB IAddressee_get_DataSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_get_DirURL_Proxy(IAddressee *This,BSTR *varDirURL);
  void __RPC_STUB IAddressee_get_DirURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_get_ResolvedStatus_Proxy(IAddressee *This,CdoResolvedStatus *pResolvedStatus);
  void __RPC_STUB IAddressee_get_ResolvedStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_put_ResolvedStatus_Proxy(IAddressee *This,CdoResolvedStatus varResolvedStatus);
  void __RPC_STUB IAddressee_put_ResolvedStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_get_ContentClass_Proxy(IAddressee *This,BSTR *varContentClass);
  void __RPC_STUB IAddressee_get_ContentClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_get_AmbiguousNames_Proxy(IAddressee *This,IAddressees **varAmbiguousNames);
  void __RPC_STUB IAddressee_get_AmbiguousNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_GetInterface_Proxy(IAddressee *This,BSTR Interface,IDispatch **ppUnknown);
  void __RPC_STUB IAddressee_GetInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_GetFreeBusy_Proxy(IAddressee *This,DATE StartTime,DATE EndTime,__LONG32 Interval,BSTR HTTPHost,BSTR VRoot,BSTR UserName,BSTR Password,BSTR *pbstrRet);
  void __RPC_STUB IAddressee_GetFreeBusy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressee_CheckName_Proxy(IAddressee *This,BSTR Directory,BSTR UserName,BSTR Password,VARIANT_BOOL *pBRet);
  void __RPC_STUB IAddressee_CheckName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAddressees_INTERFACE_DEFINED__
#define __IAddressees_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAddressees;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAddressees : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(__LONG32 Index,IAddressee **Value) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *Count) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **Unknown) = 0;
  };
#else
  typedef struct IAddresseesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAddressees *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAddressees *This);
      ULONG (WINAPI *Release)(IAddressees *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAddressees *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAddressees *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAddressees *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAddressees *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IAddressees *This,__LONG32 Index,IAddressee **Value);
      HRESULT (WINAPI *get_Count)(IAddressees *This,__LONG32 *Count);
      HRESULT (WINAPI *get__NewEnum)(IAddressees *This,IUnknown **Unknown);
    END_INTERFACE
  } IAddresseesVtbl;
  struct IAddressees {
    CONST_VTBL struct IAddresseesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAddressees_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAddressees_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAddressees_Release(This) (This)->lpVtbl->Release(This)
#define IAddressees_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAddressees_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAddressees_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAddressees_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAddressees_get_Item(This,Index,Value) (This)->lpVtbl->get_Item(This,Index,Value)
#define IAddressees_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define IAddressees_get__NewEnum(This,Unknown) (This)->lpVtbl->get__NewEnum(This,Unknown)
#endif
#endif
  HRESULT WINAPI IAddressees_get_Item_Proxy(IAddressees *This,__LONG32 Index,IAddressee **Value);
  void __RPC_STUB IAddressees_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressees_get_Count_Proxy(IAddressees *This,__LONG32 *Count);
  void __RPC_STUB IAddressees_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAddressees_get__NewEnum_Proxy(IAddressees *This,IUnknown **Unknown);
  void __RPC_STUB IAddressees_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
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
  const BSTR cdoActiveConnection = L"http://schemas.microsoft.com/cdo/configuration/activeconnection";
  const BSTR cdoMailboxURL = L"http://schemas.microsoft.com/cdo/configuration/mailboxurl";
  const BSTR cdoGetContentLanguage = L"DAV:getcontentlanguage";
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
  class NNTPEarlyConnector;
#endif
  EXTERN_C const CLSID CLSID_NNTPPostConnector;
#ifdef __cplusplus
  class NNTPPostConnector;
#endif
  EXTERN_C const CLSID CLSID_NNTPFinalConnector;
#ifdef __cplusplus
  class NNTPFinalConnector;
#endif
  EXTERN_C const CLSID CLSID_Item;
#ifdef __cplusplus
  class Item;
#endif
  EXTERN_C const CLSID CLSID_Appointment;
#ifdef __cplusplus
  class Appointment;
#endif
  EXTERN_C const CLSID CLSID_CalendarMessage;
#ifdef __cplusplus
  class CalendarMessage;
#endif
  EXTERN_C const CLSID CLSID_Folder;
#ifdef __cplusplus
  class Folder;
#endif
  EXTERN_C const CLSID CLSID_Person;
#ifdef __cplusplus
  class Person;
#endif
  EXTERN_C const CLSID CLSID_Attendee;
#ifdef __cplusplus
  class Attendee;
#endif
  EXTERN_C const CLSID CLSID_Addressee;
#ifdef __cplusplus
  class Addressee;
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
