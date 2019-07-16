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

#ifndef __tapi3if_h__
#define __tapi3if_h__

#ifndef __ITTAPI_FWD_DEFINED__
#define __ITTAPI_FWD_DEFINED__
typedef struct ITTAPI ITTAPI;
#endif

#ifndef __ITTAPI2_FWD_DEFINED__
#define __ITTAPI2_FWD_DEFINED__
typedef struct ITTAPI2 ITTAPI2;
#endif

#ifndef __ITMediaSupport_FWD_DEFINED__
#define __ITMediaSupport_FWD_DEFINED__
typedef struct ITMediaSupport ITMediaSupport;
#endif

#ifndef __ITPluggableTerminalClassInfo_FWD_DEFINED__
#define __ITPluggableTerminalClassInfo_FWD_DEFINED__
typedef struct ITPluggableTerminalClassInfo ITPluggableTerminalClassInfo;
#endif

#ifndef __ITPluggableTerminalSuperclassInfo_FWD_DEFINED__
#define __ITPluggableTerminalSuperclassInfo_FWD_DEFINED__
typedef struct ITPluggableTerminalSuperclassInfo ITPluggableTerminalSuperclassInfo;
#endif

#ifndef __ITTerminalSupport_FWD_DEFINED__
#define __ITTerminalSupport_FWD_DEFINED__
typedef struct ITTerminalSupport ITTerminalSupport;
#endif

#ifndef __ITTerminalSupport2_FWD_DEFINED__
#define __ITTerminalSupport2_FWD_DEFINED__
typedef struct ITTerminalSupport2 ITTerminalSupport2;
#endif

#ifndef __ITAddress_FWD_DEFINED__
#define __ITAddress_FWD_DEFINED__
typedef struct ITAddress ITAddress;
#endif

#ifndef __ITAddress2_FWD_DEFINED__
#define __ITAddress2_FWD_DEFINED__
typedef struct ITAddress2 ITAddress2;
#endif

#ifndef __ITAddressCapabilities_FWD_DEFINED__
#define __ITAddressCapabilities_FWD_DEFINED__
typedef struct ITAddressCapabilities ITAddressCapabilities;
#endif

#ifndef __ITPhone_FWD_DEFINED__
#define __ITPhone_FWD_DEFINED__
typedef struct ITPhone ITPhone;
#endif

#ifndef __ITAutomatedPhoneControl_FWD_DEFINED__
#define __ITAutomatedPhoneControl_FWD_DEFINED__
typedef struct ITAutomatedPhoneControl ITAutomatedPhoneControl;
#endif

#ifndef __ITBasicCallControl_FWD_DEFINED__
#define __ITBasicCallControl_FWD_DEFINED__
typedef struct ITBasicCallControl ITBasicCallControl;
#endif

#ifndef __ITCallInfo_FWD_DEFINED__
#define __ITCallInfo_FWD_DEFINED__
typedef struct ITCallInfo ITCallInfo;
#endif

#ifndef __ITCallInfo2_FWD_DEFINED__
#define __ITCallInfo2_FWD_DEFINED__
typedef struct ITCallInfo2 ITCallInfo2;
#endif

#ifndef __ITTerminal_FWD_DEFINED__
#define __ITTerminal_FWD_DEFINED__
typedef struct ITTerminal ITTerminal;
#endif

#ifndef __ITMultiTrackTerminal_FWD_DEFINED__
#define __ITMultiTrackTerminal_FWD_DEFINED__
typedef struct ITMultiTrackTerminal ITMultiTrackTerminal;
#endif

#ifndef __ITFileTrack_FWD_DEFINED__
#define __ITFileTrack_FWD_DEFINED__
typedef struct ITFileTrack ITFileTrack;
#endif

#ifndef __ITMediaPlayback_FWD_DEFINED__
#define __ITMediaPlayback_FWD_DEFINED__
typedef struct ITMediaPlayback ITMediaPlayback;
#endif

#ifndef __ITMediaRecord_FWD_DEFINED__
#define __ITMediaRecord_FWD_DEFINED__
typedef struct ITMediaRecord ITMediaRecord;
#endif

#ifndef __ITMediaControl_FWD_DEFINED__
#define __ITMediaControl_FWD_DEFINED__
typedef struct ITMediaControl ITMediaControl;
#endif

#ifndef __ITBasicAudioTerminal_FWD_DEFINED__
#define __ITBasicAudioTerminal_FWD_DEFINED__
typedef struct ITBasicAudioTerminal ITBasicAudioTerminal;
#endif

#ifndef __ITStaticAudioTerminal_FWD_DEFINED__
#define __ITStaticAudioTerminal_FWD_DEFINED__
typedef struct ITStaticAudioTerminal ITStaticAudioTerminal;
#endif

#ifndef __ITCallHub_FWD_DEFINED__
#define __ITCallHub_FWD_DEFINED__
typedef struct ITCallHub ITCallHub;
#endif

#ifndef __ITLegacyAddressMediaControl_FWD_DEFINED__
#define __ITLegacyAddressMediaControl_FWD_DEFINED__
typedef struct ITLegacyAddressMediaControl ITLegacyAddressMediaControl;
#endif

#ifndef __ITPrivateEvent_FWD_DEFINED__
#define __ITPrivateEvent_FWD_DEFINED__
typedef struct ITPrivateEvent ITPrivateEvent;
#endif

#ifndef __ITLegacyAddressMediaControl2_FWD_DEFINED__
#define __ITLegacyAddressMediaControl2_FWD_DEFINED__
typedef struct ITLegacyAddressMediaControl2 ITLegacyAddressMediaControl2;
#endif

#ifndef __ITLegacyCallMediaControl_FWD_DEFINED__
#define __ITLegacyCallMediaControl_FWD_DEFINED__
typedef struct ITLegacyCallMediaControl ITLegacyCallMediaControl;
#endif

#ifndef __ITLegacyCallMediaControl2_FWD_DEFINED__
#define __ITLegacyCallMediaControl2_FWD_DEFINED__
typedef struct ITLegacyCallMediaControl2 ITLegacyCallMediaControl2;
#endif

#ifndef __ITDetectTone_FWD_DEFINED__
#define __ITDetectTone_FWD_DEFINED__
typedef struct ITDetectTone ITDetectTone;
#endif

#ifndef __ITCustomTone_FWD_DEFINED__
#define __ITCustomTone_FWD_DEFINED__
typedef struct ITCustomTone ITCustomTone;
#endif

#ifndef __IEnumPhone_FWD_DEFINED__
#define __IEnumPhone_FWD_DEFINED__
typedef struct IEnumPhone IEnumPhone;
#endif

#ifndef __IEnumTerminal_FWD_DEFINED__
#define __IEnumTerminal_FWD_DEFINED__
typedef struct IEnumTerminal IEnumTerminal;
#endif

#ifndef __IEnumTerminalClass_FWD_DEFINED__
#define __IEnumTerminalClass_FWD_DEFINED__
typedef struct IEnumTerminalClass IEnumTerminalClass;
#endif

#ifndef __IEnumCall_FWD_DEFINED__
#define __IEnumCall_FWD_DEFINED__
typedef struct IEnumCall IEnumCall;
#endif

#ifndef __IEnumAddress_FWD_DEFINED__
#define __IEnumAddress_FWD_DEFINED__
typedef struct IEnumAddress IEnumAddress;
#endif

#ifndef __IEnumCallHub_FWD_DEFINED__
#define __IEnumCallHub_FWD_DEFINED__
typedef struct IEnumCallHub IEnumCallHub;
#endif

#ifndef __IEnumBstr_FWD_DEFINED__
#define __IEnumBstr_FWD_DEFINED__
typedef struct IEnumBstr IEnumBstr;
#endif

#ifndef __IEnumPluggableTerminalClassInfo_FWD_DEFINED__
#define __IEnumPluggableTerminalClassInfo_FWD_DEFINED__
typedef struct IEnumPluggableTerminalClassInfo IEnumPluggableTerminalClassInfo;
#endif

#ifndef __IEnumPluggableSuperclassInfo_FWD_DEFINED__
#define __IEnumPluggableSuperclassInfo_FWD_DEFINED__
typedef struct IEnumPluggableSuperclassInfo IEnumPluggableSuperclassInfo;
#endif

#ifndef __ITPhoneEvent_FWD_DEFINED__
#define __ITPhoneEvent_FWD_DEFINED__
typedef struct ITPhoneEvent ITPhoneEvent;
#endif

#ifndef __ITCallStateEvent_FWD_DEFINED__
#define __ITCallStateEvent_FWD_DEFINED__
typedef struct ITCallStateEvent ITCallStateEvent;
#endif

#ifndef __ITPhoneDeviceSpecificEvent_FWD_DEFINED__
#define __ITPhoneDeviceSpecificEvent_FWD_DEFINED__
typedef struct ITPhoneDeviceSpecificEvent ITPhoneDeviceSpecificEvent;
#endif

#ifndef __ITCallMediaEvent_FWD_DEFINED__
#define __ITCallMediaEvent_FWD_DEFINED__
typedef struct ITCallMediaEvent ITCallMediaEvent;
#endif

#ifndef __ITDigitDetectionEvent_FWD_DEFINED__
#define __ITDigitDetectionEvent_FWD_DEFINED__
typedef struct ITDigitDetectionEvent ITDigitDetectionEvent;
#endif

#ifndef __ITDigitGenerationEvent_FWD_DEFINED__
#define __ITDigitGenerationEvent_FWD_DEFINED__
typedef struct ITDigitGenerationEvent ITDigitGenerationEvent;
#endif

#ifndef __ITDigitsGatheredEvent_FWD_DEFINED__
#define __ITDigitsGatheredEvent_FWD_DEFINED__
typedef struct ITDigitsGatheredEvent ITDigitsGatheredEvent;
#endif

#ifndef __ITToneDetectionEvent_FWD_DEFINED__
#define __ITToneDetectionEvent_FWD_DEFINED__
typedef struct ITToneDetectionEvent ITToneDetectionEvent;
#endif

#ifndef __ITTAPIObjectEvent_FWD_DEFINED__
#define __ITTAPIObjectEvent_FWD_DEFINED__
typedef struct ITTAPIObjectEvent ITTAPIObjectEvent;
#endif

#ifndef __ITTAPIObjectEvent2_FWD_DEFINED__
#define __ITTAPIObjectEvent2_FWD_DEFINED__
typedef struct ITTAPIObjectEvent2 ITTAPIObjectEvent2;
#endif

#ifndef __ITTAPIEventNotification_FWD_DEFINED__
#define __ITTAPIEventNotification_FWD_DEFINED__
typedef struct ITTAPIEventNotification ITTAPIEventNotification;
#endif

#ifndef __ITCallHubEvent_FWD_DEFINED__
#define __ITCallHubEvent_FWD_DEFINED__
typedef struct ITCallHubEvent ITCallHubEvent;
#endif

#ifndef __ITAddressEvent_FWD_DEFINED__
#define __ITAddressEvent_FWD_DEFINED__
typedef struct ITAddressEvent ITAddressEvent;
#endif

#ifndef __ITAddressDeviceSpecificEvent_FWD_DEFINED__
#define __ITAddressDeviceSpecificEvent_FWD_DEFINED__
typedef struct ITAddressDeviceSpecificEvent ITAddressDeviceSpecificEvent;
#endif

#ifndef __ITFileTerminalEvent_FWD_DEFINED__
#define __ITFileTerminalEvent_FWD_DEFINED__
typedef struct ITFileTerminalEvent ITFileTerminalEvent;
#endif

#ifndef __ITTTSTerminalEvent_FWD_DEFINED__
#define __ITTTSTerminalEvent_FWD_DEFINED__
typedef struct ITTTSTerminalEvent ITTTSTerminalEvent;
#endif

#ifndef __ITASRTerminalEvent_FWD_DEFINED__
#define __ITASRTerminalEvent_FWD_DEFINED__
typedef struct ITASRTerminalEvent ITASRTerminalEvent;
#endif

#ifndef __ITToneTerminalEvent_FWD_DEFINED__
#define __ITToneTerminalEvent_FWD_DEFINED__
typedef struct ITToneTerminalEvent ITToneTerminalEvent;
#endif

#ifndef __ITQOSEvent_FWD_DEFINED__
#define __ITQOSEvent_FWD_DEFINED__
typedef struct ITQOSEvent ITQOSEvent;
#endif

#ifndef __ITCallInfoChangeEvent_FWD_DEFINED__
#define __ITCallInfoChangeEvent_FWD_DEFINED__
typedef struct ITCallInfoChangeEvent ITCallInfoChangeEvent;
#endif

#ifndef __ITRequest_FWD_DEFINED__
#define __ITRequest_FWD_DEFINED__
typedef struct ITRequest ITRequest;
#endif

#ifndef __ITRequestEvent_FWD_DEFINED__
#define __ITRequestEvent_FWD_DEFINED__
typedef struct ITRequestEvent ITRequestEvent;
#endif

#ifndef __ITCollection_FWD_DEFINED__
#define __ITCollection_FWD_DEFINED__
typedef struct ITCollection ITCollection;
#endif

#ifndef __ITCollection2_FWD_DEFINED__
#define __ITCollection2_FWD_DEFINED__
typedef struct ITCollection2 ITCollection2;
#endif

#ifndef __ITForwardInformation_FWD_DEFINED__
#define __ITForwardInformation_FWD_DEFINED__
typedef struct ITForwardInformation ITForwardInformation;
#endif

#ifndef __ITForwardInformation2_FWD_DEFINED__
#define __ITForwardInformation2_FWD_DEFINED__
typedef struct ITForwardInformation2 ITForwardInformation2;
#endif

#ifndef __ITAddressTranslation_FWD_DEFINED__
#define __ITAddressTranslation_FWD_DEFINED__
typedef struct ITAddressTranslation ITAddressTranslation;
#endif

#ifndef __ITAddressTranslationInfo_FWD_DEFINED__
#define __ITAddressTranslationInfo_FWD_DEFINED__
typedef struct ITAddressTranslationInfo ITAddressTranslationInfo;
#endif

#ifndef __ITLocationInfo_FWD_DEFINED__
#define __ITLocationInfo_FWD_DEFINED__
typedef struct ITLocationInfo ITLocationInfo;
#endif

#ifndef __IEnumLocation_FWD_DEFINED__
#define __IEnumLocation_FWD_DEFINED__
typedef struct IEnumLocation IEnumLocation;
#endif

#ifndef __ITCallingCard_FWD_DEFINED__
#define __ITCallingCard_FWD_DEFINED__
typedef struct ITCallingCard ITCallingCard;
#endif

#ifndef __IEnumCallingCard_FWD_DEFINED__
#define __IEnumCallingCard_FWD_DEFINED__
typedef struct IEnumCallingCard IEnumCallingCard;
#endif

#ifndef __ITCallNotificationEvent_FWD_DEFINED__
#define __ITCallNotificationEvent_FWD_DEFINED__
typedef struct ITCallNotificationEvent ITCallNotificationEvent;
#endif

#ifndef __ITDispatchMapper_FWD_DEFINED__
#define __ITDispatchMapper_FWD_DEFINED__
typedef struct ITDispatchMapper ITDispatchMapper;
#endif

#ifndef __ITStreamControl_FWD_DEFINED__
#define __ITStreamControl_FWD_DEFINED__
typedef struct ITStreamControl ITStreamControl;
#endif

#ifndef __ITStream_FWD_DEFINED__
#define __ITStream_FWD_DEFINED__
typedef struct ITStream ITStream;
#endif

#ifndef __IEnumStream_FWD_DEFINED__
#define __IEnumStream_FWD_DEFINED__
typedef struct IEnumStream IEnumStream;
#endif

#ifndef __ITSubStreamControl_FWD_DEFINED__
#define __ITSubStreamControl_FWD_DEFINED__
typedef struct ITSubStreamControl ITSubStreamControl;
#endif

#ifndef __ITSubStream_FWD_DEFINED__
#define __ITSubStream_FWD_DEFINED__
typedef struct ITSubStream ITSubStream;
#endif

#ifndef __IEnumSubStream_FWD_DEFINED__
#define __IEnumSubStream_FWD_DEFINED__
typedef struct IEnumSubStream IEnumSubStream;
#endif

#ifndef __ITLegacyWaveSupport_FWD_DEFINED__
#define __ITLegacyWaveSupport_FWD_DEFINED__
typedef struct ITLegacyWaveSupport ITLegacyWaveSupport;
#endif

#ifndef __ITBasicCallControl2_FWD_DEFINED__
#define __ITBasicCallControl2_FWD_DEFINED__
typedef struct ITBasicCallControl2 ITBasicCallControl2;
#endif

#ifndef __ITScriptableAudioFormat_FWD_DEFINED__
#define __ITScriptableAudioFormat_FWD_DEFINED__
typedef struct ITScriptableAudioFormat ITScriptableAudioFormat;
#endif

#include "oaidl.h"
#include "strmif.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifdef _X86_
  typedef __LONG32 TAPIHWND;
#else
  typedef LONGLONG TAPIHWND;
#endif
  typedef __LONG32 TAPI_DIGITMODE;

  typedef enum TAPI_TONEMODE {
    TTM_RINGBACK = 0x2,TTM_BUSY = 0x4,TTM_BEEP = 0x8,TTM_BILLING = 0x10
  } TAPI_TONEMODE;

  typedef enum TAPI_GATHERTERM {
    TGT_BUFFERFULL = 0x1,TGT_TERMDIGIT = 0x2,TGT_FIRSTTIMEOUT = 0x4,TGT_INTERTIMEOUT = 0x8,TGT_CANCEL = 0x10
  } TAPI_GATHERTERM;

  typedef struct TAPI_CUSTOMTONE {
    DWORD dwFrequency;
    DWORD dwCadenceOn;
    DWORD dwCadenceOff;
    DWORD dwVolume;
  } TAPI_CUSTOMTONE;

  typedef struct TAPI_CUSTOMTONE *LPTAPI_CUSTOMTONE;

  typedef struct TAPI_DETECTTONE {
    DWORD dwAppSpecific;
    DWORD dwDuration;
    DWORD dwFrequency1;
    DWORD dwFrequency2;
    DWORD dwFrequency3;
  } TAPI_DETECTTONE;

  typedef struct TAPI_DETECTTONE *LPTAPI_DETECTTONE;

  typedef enum ADDRESS_EVENT {
    AE_STATE = 0,
    AE_CAPSCHANGE,AE_RINGING,AE_CONFIGCHANGE,AE_FORWARD,AE_NEWTERMINAL,
    AE_REMOVETERMINAL,AE_MSGWAITON,AE_MSGWAITOFF,
    AE_LASTITEM = AE_MSGWAITOFF
  } ADDRESS_EVENT;

  typedef enum ADDRESS_STATE {
    AS_INSERVICE = 0,
    AS_OUTOFSERVICE
  } ADDRESS_STATE;

  typedef enum CALL_STATE {
    CS_IDLE = 0,
    CS_INPROGRESS,CS_CONNECTED,CS_DISCONNECTED,CS_OFFERING,CS_HOLD,CS_QUEUED,
    CS_LASTITEM = CS_QUEUED
  } CALL_STATE;

  typedef enum CALL_STATE_EVENT_CAUSE {
    CEC_NONE = 0,
    CEC_DISCONNECT_NORMAL,CEC_DISCONNECT_BUSY,CEC_DISCONNECT_BADADDRESS,
    CEC_DISCONNECT_NOANSWER,CEC_DISCONNECT_CANCELLED,CEC_DISCONNECT_REJECTED,
    CEC_DISCONNECT_FAILED,CEC_DISCONNECT_BLOCKED
  } CALL_STATE_EVENT_CAUSE;

  typedef enum CALL_MEDIA_EVENT {
    CME_NEW_STREAM = 0,
    CME_STREAM_FAIL,CME_TERMINAL_FAIL,CME_STREAM_NOT_USED,CME_STREAM_ACTIVE,
    CME_STREAM_INACTIVE,
    CME_LASTITEM = CME_STREAM_INACTIVE
  } CALL_MEDIA_EVENT;

  typedef enum CALL_MEDIA_EVENT_CAUSE {
    CMC_UNKNOWN = 0,
    CMC_BAD_DEVICE,CMC_CONNECT_FAIL,CMC_LOCAL_REQUEST,CMC_REMOTE_REQUEST,
    CMC_MEDIA_TIMEOUT,CMC_MEDIA_RECOVERED,CMC_QUALITY_OF_SERVICE
  } CALL_MEDIA_EVENT_CAUSE;

  typedef enum DISCONNECT_CODE {
    DC_NORMAL = 0,
    DC_NOANSWER,DC_REJECTED
  } DISCONNECT_CODE;

  typedef enum TERMINAL_STATE {
    TS_INUSE = 0,
    TS_NOTINUSE
  } TERMINAL_STATE;

  typedef enum TERMINAL_DIRECTION {
    TD_CAPTURE = 0,
    TD_RENDER,TD_BIDIRECTIONAL,TD_MULTITRACK_MIXED,TD_NONE
  } TERMINAL_DIRECTION;

  typedef enum TERMINAL_TYPE {
    TT_STATIC = 0,
    TT_DYNAMIC
  } TERMINAL_TYPE;

  typedef enum CALL_PRIVILEGE {
    CP_OWNER = 0,
    CP_MONITOR
  } CALL_PRIVILEGE;

  typedef enum TAPI_EVENT {
    TE_TAPIOBJECT = 0x1,TE_ADDRESS = 0x2,TE_CALLNOTIFICATION = 0x4,TE_CALLSTATE = 0x8,
    TE_CALLMEDIA = 0x10,TE_CALLHUB = 0x20,TE_CALLINFOCHANGE = 0x40,TE_PRIVATE = 0x80,
    TE_REQUEST = 0x100,TE_AGENT = 0x200,TE_AGENTSESSION = 0x400,TE_QOSEVENT = 0x800,
    TE_AGENTHANDLER = 0x1000,TE_ACDGROUP = 0x2000,TE_QUEUE = 0x4000,TE_DIGITEVENT = 0x8000,
    TE_GENERATEEVENT = 0x10000,TE_ASRTERMINAL = 0x20000,TE_TTSTERMINAL = 0x40000,TE_FILETERMINAL = 0x80000,
    TE_TONETERMINAL = 0x100000,TE_PHONEEVENT = 0x200000,TE_TONEEVENT = 0x400000,TE_GATHERDIGITS = 0x800000,
    TE_ADDRESSDEVSPECIFIC = 0x1000000,TE_PHONEDEVSPECIFIC = 0x2000000
  } TAPI_EVENT;

  typedef enum CALL_NOTIFICATION_EVENT {
    CNE_OWNER = 0,CNE_MONITOR,
    CNE_LASTITEM = CNE_MONITOR
  } CALL_NOTIFICATION_EVENT;

  typedef enum CALLHUB_EVENT {
    CHE_CALLJOIN = 0,
    CHE_CALLLEAVE,CHE_CALLHUBNEW,CHE_CALLHUBIDLE,
    CHE_LASTITEM = CHE_CALLHUBIDLE
  } CALLHUB_EVENT;

  typedef enum CALLHUB_STATE {
    CHS_ACTIVE = 0,
    CHS_IDLE
  } CALLHUB_STATE;

  typedef enum TAPIOBJECT_EVENT {
    TE_ADDRESSCREATE = 0,
    TE_ADDRESSREMOVE,TE_REINIT,TE_TRANSLATECHANGE,TE_ADDRESSCLOSE,TE_PHONECREATE,
    TE_PHONEREMOVE
  } TAPIOBJECT_EVENT;

  typedef enum TAPI_OBJECT_TYPE {
    TOT_NONE = 0,
    TOT_TAPI,TOT_ADDRESS,TOT_TERMINAL,TOT_CALL,TOT_CALLHUB,TOT_PHONE
  } TAPI_OBJECT_TYPE;

  typedef enum QOS_SERVICE_LEVEL {
    QSL_NEEDED = 1,
    QSL_IF_AVAILABLE = 2,
    QSL_BEST_EFFORT = 3
  } QOS_SERVICE_LEVEL;

  typedef enum QOS_EVENT {
    QE_NOQOS = 1,QE_ADMISSIONFAILURE = 2,QE_POLICYFAILURE = 3,QE_GENERICERROR = 4,
    QE_LASTITEM = QE_GENERICERROR
  } QOS_EVENT;

  typedef enum CALLINFOCHANGE_CAUSE {
    CIC_OTHER = 0,
    CIC_DEVSPECIFIC,CIC_BEARERMODE,CIC_RATE,CIC_APPSPECIFIC,CIC_CALLID,
    CIC_RELATEDCALLID,CIC_ORIGIN,CIC_REASON,CIC_COMPLETIONID,CIC_NUMOWNERINCR,
    CIC_NUMOWNERDECR,CIC_NUMMONITORS,CIC_TRUNK,CIC_CALLERID,CIC_CALLEDID,
    CIC_CONNECTEDID,CIC_REDIRECTIONID,CIC_REDIRECTINGID,CIC_USERUSERINFO,
    CIC_HIGHLEVELCOMP,CIC_LOWLEVELCOMP,CIC_CHARGINGINFO,CIC_TREATMENT,
    CIC_CALLDATA,CIC_PRIVILEGE,CIC_MEDIATYPE,
    CIC_LASTITEM = CIC_MEDIATYPE
  } CALLINFOCHANGE_CAUSE;

  typedef enum CALLINFO_LONG {
    CIL_MEDIATYPESAVAILABLE = 0,
    CIL_BEARERMODE,CIL_CALLERIDADDRESSTYPE,CIL_CALLEDIDADDRESSTYPE,CIL_CONNECTEDIDADDRESSTYPE,
    CIL_REDIRECTIONIDADDRESSTYPE,CIL_REDIRECTINGIDADDRESSTYPE,CIL_ORIGIN,
    CIL_REASON,CIL_APPSPECIFIC,CIL_CALLPARAMSFLAGS,CIL_CALLTREATMENT,CIL_MINRATE,
    CIL_MAXRATE,CIL_COUNTRYCODE,CIL_CALLID,CIL_RELATEDCALLID,CIL_COMPLETIONID,
    CIL_NUMBEROFOWNERS,CIL_NUMBEROFMONITORS,CIL_TRUNK,CIL_RATE,CIL_GENERATEDIGITDURATION,
    CIL_MONITORDIGITMODES,CIL_MONITORMEDIAMODES
  } CALLINFO_LONG;

  typedef enum CALLINFO_STRING {
    CIS_CALLERIDNAME = 0,
    CIS_CALLERIDNUMBER,CIS_CALLEDIDNAME,CIS_CALLEDIDNUMBER,CIS_CONNECTEDIDNAME,
    CIS_CONNECTEDIDNUMBER,CIS_REDIRECTIONIDNAME,CIS_REDIRECTIONIDNUMBER,
    CIS_REDIRECTINGIDNAME,CIS_REDIRECTINGIDNUMBER,CIS_CALLEDPARTYFRIENDLYNAME,
    CIS_COMMENT,CIS_DISPLAYABLEADDRESS,CIS_CALLINGPARTYID
  } CALLINFO_STRING;

  typedef enum CALLINFO_BUFFER {
    CIB_USERUSERINFO = 0,
    CIB_DEVSPECIFICBUFFER,CIB_CALLDATABUFFER,CIB_CHARGINGINFOBUFFER,
    CIB_HIGHLEVELCOMPATIBILITYBUFFER,CIB_LOWLEVELCOMPATIBILITYBUFFER
  } CALLINFO_BUFFER;

  typedef enum ADDRESS_CAPABILITY {
    AC_ADDRESSTYPES = 0,
    AC_BEARERMODES,AC_MAXACTIVECALLS,AC_MAXONHOLDCALLS,
    AC_MAXONHOLDPENDINGCALLS,AC_MAXNUMCONFERENCE,AC_MAXNUMTRANSCONF,
    AC_MONITORDIGITSUPPORT,AC_GENERATEDIGITSUPPORT,AC_GENERATETONEMODES,
    AC_GENERATETONEMAXNUMFREQ,AC_MONITORTONEMAXNUMFREQ,AC_MONITORTONEMAXNUMENTRIES,
    AC_DEVCAPFLAGS,AC_ANSWERMODES,AC_LINEFEATURES,AC_SETTABLEDEVSTATUS,
    AC_PARKSUPPORT,AC_CALLERIDSUPPORT,AC_CALLEDIDSUPPORT,AC_CONNECTEDIDSUPPORT,
    AC_REDIRECTIONIDSUPPORT,AC_REDIRECTINGIDSUPPORT,AC_ADDRESSCAPFLAGS,
    AC_CALLFEATURES1,AC_CALLFEATURES2,AC_REMOVEFROMCONFCAPS,AC_REMOVEFROMCONFSTATE,
    AC_TRANSFERMODES,AC_ADDRESSFEATURES,AC_PREDICTIVEAUTOTRANSFERSTATES,
    AC_MAXCALLDATASIZE,AC_LINEID,AC_ADDRESSID,AC_FORWARDMODES,AC_MAXFORWARDENTRIES,
    AC_MAXSPECIFICENTRIES,AC_MINFWDNUMRINGS,AC_MAXFWDNUMRINGS,AC_MAXCALLCOMPLETIONS,
    AC_CALLCOMPLETIONCONDITIONS,AC_CALLCOMPLETIONMODES,AC_PERMANENTDEVICEID,
    AC_GATHERDIGITSMINTIMEOUT,AC_GATHERDIGITSMAXTIMEOUT,AC_GENERATEDIGITMINDURATION,
    AC_GENERATEDIGITMAXDURATION,AC_GENERATEDIGITDEFAULTDURATION
  } ADDRESS_CAPABILITY;

  typedef enum ADDRESS_CAPABILITY_STRING {
    ACS_PROTOCOL = 0,
    ACS_ADDRESSDEVICESPECIFIC,ACS_LINEDEVICESPECIFIC,
    ACS_PROVIDERSPECIFIC,ACS_SWITCHSPECIFIC,ACS_PERMANENTDEVICEGUID
  } ADDRESS_CAPABILITY_STRING;

  typedef enum FULLDUPLEX_SUPPORT {
    FDS_SUPPORTED = 0,
    FDS_NOTSUPPORTED,FDS_UNKNOWN
  } FULLDUPLEX_SUPPORT;

  typedef enum FINISH_MODE {
    FM_ASTRANSFER = 0,
    FM_ASCONFERENCE
  } FINISH_MODE;

  typedef enum PHONE_PRIVILEGE {
    PP_OWNER = 0,
    PP_MONITOR
  } PHONE_PRIVILEGE;

  typedef enum PHONE_HOOK_SWITCH_DEVICE {
    PHSD_HANDSET = 0x1,PHSD_SPEAKERPHONE = 0x2,PHSD_HEADSET = 0x4
  } PHONE_HOOK_SWITCH_DEVICE;

  typedef enum PHONE_HOOK_SWITCH_STATE {
    PHSS_ONHOOK = 0x1,PHSS_OFFHOOK_MIC_ONLY = 0x2,PHSS_OFFHOOK_SPEAKER_ONLY = 0x4,PHSS_OFFHOOK = 0x8
  } PHONE_HOOK_SWITCH_STATE;

  typedef enum PHONE_LAMP_MODE {
    LM_DUMMY = 0x1,LM_OFF = 0x2,LM_STEADY = 0x4,LM_WINK = 0x8,
    LM_FLASH = 0x10,LM_FLUTTER = 0x20,LM_BROKENFLUTTER = 0x40,LM_UNKNOWN = 0x80
  } PHONE_LAMP_MODE;

  typedef enum PHONECAPS_LONG {
    PCL_HOOKSWITCHES = 0,
    PCL_HANDSETHOOKSWITCHMODES,PCL_HEADSETHOOKSWITCHMODES,PCL_SPEAKERPHONEHOOKSWITCHMODES,
    PCL_DISPLAYNUMROWS,PCL_DISPLAYNUMCOLUMNS,PCL_NUMRINGMODES,PCL_NUMBUTTONLAMPS,
    PCL_GENERICPHONE
  } PHONECAPS_LONG;

  typedef enum PHONECAPS_STRING {
    PCS_PHONENAME = 0,
    PCS_PHONEINFO,PCS_PROVIDERINFO
  } PHONECAPS_STRING;

  typedef enum PHONECAPS_BUFFER {
    PCB_DEVSPECIFICBUFFER = 0
  } PHONECAPS_BUFFER;

  typedef enum PHONE_BUTTON_STATE {
    PBS_UP = 0x1,PBS_DOWN = 0x2,PBS_UNKNOWN = 0x4,PBS_UNAVAIL = 0x8
  } PHONE_BUTTON_STATE;

  typedef enum PHONE_BUTTON_MODE {
    PBM_DUMMY = 0,
    PBM_CALL,PBM_FEATURE,PBM_KEYPAD,PBM_LOCAL,PBM_DISPLAY
  } PHONE_BUTTON_MODE;

  typedef enum PHONE_BUTTON_FUNCTION {
    PBF_UNKNOWN = 0,
    PBF_CONFERENCE,PBF_TRANSFER,PBF_DROP,PBF_HOLD,PBF_RECALL,PBF_DISCONNECT,PBF_CONNECT,
    PBF_MSGWAITON,PBF_MSGWAITOFF,PBF_SELECTRING,PBF_ABBREVDIAL,PBF_FORWARD,
    PBF_PICKUP,PBF_RINGAGAIN,PBF_PARK,PBF_REJECT,PBF_REDIRECT,PBF_MUTE,
    PBF_VOLUMEUP,PBF_VOLUMEDOWN,PBF_SPEAKERON,PBF_SPEAKEROFF,PBF_FLASH,
    PBF_DATAON,PBF_DATAOFF,PBF_DONOTDISTURB,PBF_INTERCOM,PBF_BRIDGEDAPP,
    PBF_BUSY,PBF_CALLAPP,PBF_DATETIME,PBF_DIRECTORY,PBF_COVER,PBF_CALLID,
    PBF_LASTNUM,PBF_NIGHTSRV,PBF_SENDCALLS,PBF_MSGINDICATOR,PBF_REPDIAL,
    PBF_SETREPDIAL,PBF_SYSTEMSPEED,PBF_STATIONSPEED,PBF_CAMPON,PBF_SAVEREPEAT,
    PBF_QUEUECALL,PBF_NONE,PBF_SEND
  } PHONE_BUTTON_FUNCTION;

  typedef enum PHONE_TONE {
    PT_KEYPADZERO = 0,
    PT_KEYPADONE,PT_KEYPADTWO,PT_KEYPADTHREE,PT_KEYPADFOUR,PT_KEYPADFIVE,PT_KEYPADSIX,
    PT_KEYPADSEVEN,PT_KEYPADEIGHT,PT_KEYPADNINE,PT_KEYPADSTAR,PT_KEYPADPOUND,PT_KEYPADA,
    PT_KEYPADB,PT_KEYPADC,PT_KEYPADD,PT_NORMALDIALTONE,PT_EXTERNALDIALTONE,PT_BUSY,
    PT_RINGBACK,PT_ERRORTONE,PT_SILENCE
  } PHONE_TONE;

  typedef enum PHONE_EVENT {
    PE_DISPLAY = 0,
    PE_LAMPMODE,PE_RINGMODE,PE_RINGVOLUME,PE_HOOKSWITCH,PE_CAPSCHANGE,PE_BUTTON,
    PE_CLOSE,PE_NUMBERGATHERED,PE_DIALING,PE_ANSWER,PE_DISCONNECT,
    PE_LASTITEM = PE_DISCONNECT
  } PHONE_EVENT;

#define INTERFACEMASK (0xff0000)

#define DISPIDMASK (0xffff)

#define IDISPTAPI (0x10000)
#define IDISPTAPICALLCENTER (0x20000)
#define IDISPCALLINFO (0x10000)
#define IDISPBASICCALLCONTROL (0x20000)
#define IDISPLEGACYCALLMEDIACONTROL (0x30000)
#define IDISPAGGREGATEDMSPCALLOBJ (0x40000)
#define IDISPADDRESS (0x10000)
#define IDISPADDRESSCAPABILITIES (0x20000)
#define IDISPMEDIASUPPORT (0x30000)
#define IDISPADDRESSTRANSLATION (0x40000)
#define IDISPLEGACYADDRESSMEDIACONTROL (0x50000)
#define IDISPAGGREGATEDMSPADDRESSOBJ (0x60000)
#define IDISPPHONE (0x10000)
#define IDISPAPC (0x20000)
#define IDISPMULTITRACK (0x10000)
#define IDISPMEDIACONTROL (0x20000)
#define IDISPMEDIARECORD (0x30000)
#define IDISPMEDIAPLAYBACK (0x40000)
#define IDISPFILETRACK (0x10000)

  extern RPC_IF_HANDLE __MIDL_itf_tapi3if_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_tapi3if_0000_v0_0_s_ifspec;
#ifndef __ITTAPI_INTERFACE_DEFINED__
#define __ITTAPI_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTAPI;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTAPI : public IDispatch {
  public:
    virtual HRESULT WINAPI Initialize(void) = 0;
    virtual HRESULT WINAPI Shutdown(void) = 0;
    virtual HRESULT WINAPI get_Addresses(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateAddresses(IEnumAddress **ppEnumAddress) = 0;
    virtual HRESULT WINAPI RegisterCallNotifications(ITAddress *pAddress,VARIANT_BOOL fMonitor,VARIANT_BOOL fOwner,__LONG32 lMediaTypes,__LONG32 lCallbackInstance,__LONG32 *plRegister) = 0;
    virtual HRESULT WINAPI UnregisterNotifications(__LONG32 lRegister) = 0;
    virtual HRESULT WINAPI get_CallHubs(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateCallHubs(IEnumCallHub **ppEnumCallHub) = 0;
    virtual HRESULT WINAPI SetCallHubTracking(VARIANT pAddresses,VARIANT_BOOL bTracking) = 0;
    virtual HRESULT WINAPI EnumeratePrivateTAPIObjects(IEnumUnknown **ppEnumUnknown) = 0;
    virtual HRESULT WINAPI get_PrivateTAPIObjects(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI RegisterRequestRecipient(__LONG32 lRegistrationInstance,__LONG32 lRequestMode,VARIANT_BOOL fEnable) = 0;
    virtual HRESULT WINAPI SetAssistedTelephonyPriority(BSTR pAppFilename,VARIANT_BOOL fPriority) = 0;
    virtual HRESULT WINAPI SetApplicationPriority(BSTR pAppFilename,__LONG32 lMediaType,VARIANT_BOOL fPriority) = 0;
    virtual HRESULT WINAPI put_EventFilter(__LONG32 lFilterMask) = 0;
    virtual HRESULT WINAPI get_EventFilter(__LONG32 *plFilterMask) = 0;
  };
#else
  typedef struct ITTAPIVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTAPI *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTAPI *This);
      ULONG (WINAPI *Release)(ITTAPI *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTAPI *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTAPI *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTAPI *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTAPI *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Initialize)(ITTAPI *This);
      HRESULT (WINAPI *Shutdown)(ITTAPI *This);
      HRESULT (WINAPI *get_Addresses)(ITTAPI *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateAddresses)(ITTAPI *This,IEnumAddress **ppEnumAddress);
      HRESULT (WINAPI *RegisterCallNotifications)(ITTAPI *This,ITAddress *pAddress,VARIANT_BOOL fMonitor,VARIANT_BOOL fOwner,__LONG32 lMediaTypes,__LONG32 lCallbackInstance,__LONG32 *plRegister);
      HRESULT (WINAPI *UnregisterNotifications)(ITTAPI *This,__LONG32 lRegister);
      HRESULT (WINAPI *get_CallHubs)(ITTAPI *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateCallHubs)(ITTAPI *This,IEnumCallHub **ppEnumCallHub);
      HRESULT (WINAPI *SetCallHubTracking)(ITTAPI *This,VARIANT pAddresses,VARIANT_BOOL bTracking);
      HRESULT (WINAPI *EnumeratePrivateTAPIObjects)(ITTAPI *This,IEnumUnknown **ppEnumUnknown);
      HRESULT (WINAPI *get_PrivateTAPIObjects)(ITTAPI *This,VARIANT *pVariant);
      HRESULT (WINAPI *RegisterRequestRecipient)(ITTAPI *This,__LONG32 lRegistrationInstance,__LONG32 lRequestMode,VARIANT_BOOL fEnable);
      HRESULT (WINAPI *SetAssistedTelephonyPriority)(ITTAPI *This,BSTR pAppFilename,VARIANT_BOOL fPriority);
      HRESULT (WINAPI *SetApplicationPriority)(ITTAPI *This,BSTR pAppFilename,__LONG32 lMediaType,VARIANT_BOOL fPriority);
      HRESULT (WINAPI *put_EventFilter)(ITTAPI *This,__LONG32 lFilterMask);
      HRESULT (WINAPI *get_EventFilter)(ITTAPI *This,__LONG32 *plFilterMask);
    END_INTERFACE
  } ITTAPIVtbl;
  struct ITTAPI {
    CONST_VTBL struct ITTAPIVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTAPI_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTAPI_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTAPI_Release(This) (This)->lpVtbl->Release(This)
#define ITTAPI_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTAPI_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTAPI_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTAPI_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITTAPI_Initialize(This) (This)->lpVtbl->Initialize(This)
#define ITTAPI_Shutdown(This) (This)->lpVtbl->Shutdown(This)
#define ITTAPI_get_Addresses(This,pVariant) (This)->lpVtbl->get_Addresses(This,pVariant)
#define ITTAPI_EnumerateAddresses(This,ppEnumAddress) (This)->lpVtbl->EnumerateAddresses(This,ppEnumAddress)
#define ITTAPI_RegisterCallNotifications(This,pAddress,fMonitor,fOwner,lMediaTypes,lCallbackInstance,plRegister) (This)->lpVtbl->RegisterCallNotifications(This,pAddress,fMonitor,fOwner,lMediaTypes,lCallbackInstance,plRegister)
#define ITTAPI_UnregisterNotifications(This,lRegister) (This)->lpVtbl->UnregisterNotifications(This,lRegister)
#define ITTAPI_get_CallHubs(This,pVariant) (This)->lpVtbl->get_CallHubs(This,pVariant)
#define ITTAPI_EnumerateCallHubs(This,ppEnumCallHub) (This)->lpVtbl->EnumerateCallHubs(This,ppEnumCallHub)
#define ITTAPI_SetCallHubTracking(This,pAddresses,bTracking) (This)->lpVtbl->SetCallHubTracking(This,pAddresses,bTracking)
#define ITTAPI_EnumeratePrivateTAPIObjects(This,ppEnumUnknown) (This)->lpVtbl->EnumeratePrivateTAPIObjects(This,ppEnumUnknown)
#define ITTAPI_get_PrivateTAPIObjects(This,pVariant) (This)->lpVtbl->get_PrivateTAPIObjects(This,pVariant)
#define ITTAPI_RegisterRequestRecipient(This,lRegistrationInstance,lRequestMode,fEnable) (This)->lpVtbl->RegisterRequestRecipient(This,lRegistrationInstance,lRequestMode,fEnable)
#define ITTAPI_SetAssistedTelephonyPriority(This,pAppFilename,fPriority) (This)->lpVtbl->SetAssistedTelephonyPriority(This,pAppFilename,fPriority)
#define ITTAPI_SetApplicationPriority(This,pAppFilename,lMediaType,fPriority) (This)->lpVtbl->SetApplicationPriority(This,pAppFilename,lMediaType,fPriority)
#define ITTAPI_put_EventFilter(This,lFilterMask) (This)->lpVtbl->put_EventFilter(This,lFilterMask)
#define ITTAPI_get_EventFilter(This,plFilterMask) (This)->lpVtbl->get_EventFilter(This,plFilterMask)
#endif
#endif
  HRESULT WINAPI ITTAPI_Initialize_Proxy(ITTAPI *This);
  void __RPC_STUB ITTAPI_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_Shutdown_Proxy(ITTAPI *This);
  void __RPC_STUB ITTAPI_Shutdown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_get_Addresses_Proxy(ITTAPI *This,VARIANT *pVariant);
  void __RPC_STUB ITTAPI_get_Addresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_EnumerateAddresses_Proxy(ITTAPI *This,IEnumAddress **ppEnumAddress);
  void __RPC_STUB ITTAPI_EnumerateAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_RegisterCallNotifications_Proxy(ITTAPI *This,ITAddress *pAddress,VARIANT_BOOL fMonitor,VARIANT_BOOL fOwner,__LONG32 lMediaTypes,__LONG32 lCallbackInstance,__LONG32 *plRegister);
  void __RPC_STUB ITTAPI_RegisterCallNotifications_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_UnregisterNotifications_Proxy(ITTAPI *This,__LONG32 lRegister);
  void __RPC_STUB ITTAPI_UnregisterNotifications_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_get_CallHubs_Proxy(ITTAPI *This,VARIANT *pVariant);
  void __RPC_STUB ITTAPI_get_CallHubs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_EnumerateCallHubs_Proxy(ITTAPI *This,IEnumCallHub **ppEnumCallHub);
  void __RPC_STUB ITTAPI_EnumerateCallHubs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_SetCallHubTracking_Proxy(ITTAPI *This,VARIANT pAddresses,VARIANT_BOOL bTracking);
  void __RPC_STUB ITTAPI_SetCallHubTracking_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_EnumeratePrivateTAPIObjects_Proxy(ITTAPI *This,IEnumUnknown **ppEnumUnknown);
  void __RPC_STUB ITTAPI_EnumeratePrivateTAPIObjects_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_get_PrivateTAPIObjects_Proxy(ITTAPI *This,VARIANT *pVariant);
  void __RPC_STUB ITTAPI_get_PrivateTAPIObjects_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_RegisterRequestRecipient_Proxy(ITTAPI *This,__LONG32 lRegistrationInstance,__LONG32 lRequestMode,VARIANT_BOOL fEnable);
  void __RPC_STUB ITTAPI_RegisterRequestRecipient_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_SetAssistedTelephonyPriority_Proxy(ITTAPI *This,BSTR pAppFilename,VARIANT_BOOL fPriority);
  void __RPC_STUB ITTAPI_SetAssistedTelephonyPriority_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_SetApplicationPriority_Proxy(ITTAPI *This,BSTR pAppFilename,__LONG32 lMediaType,VARIANT_BOOL fPriority);
  void __RPC_STUB ITTAPI_SetApplicationPriority_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_put_EventFilter_Proxy(ITTAPI *This,__LONG32 lFilterMask);
  void __RPC_STUB ITTAPI_put_EventFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI_get_EventFilter_Proxy(ITTAPI *This,__LONG32 *plFilterMask);
  void __RPC_STUB ITTAPI_get_EventFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTAPI2_INTERFACE_DEFINED__
#define __ITTAPI2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTAPI2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTAPI2 : public ITTAPI {
  public:
    virtual HRESULT WINAPI get_Phones(VARIANT *pPhones) = 0;
    virtual HRESULT WINAPI EnumeratePhones(IEnumPhone **ppEnumPhone) = 0;
    virtual HRESULT WINAPI CreateEmptyCollectionObject(ITCollection2 **ppCollection) = 0;
  };
#else
  typedef struct ITTAPI2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTAPI2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTAPI2 *This);
      ULONG (WINAPI *Release)(ITTAPI2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTAPI2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTAPI2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTAPI2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTAPI2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Initialize)(ITTAPI2 *This);
      HRESULT (WINAPI *Shutdown)(ITTAPI2 *This);
      HRESULT (WINAPI *get_Addresses)(ITTAPI2 *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateAddresses)(ITTAPI2 *This,IEnumAddress **ppEnumAddress);
      HRESULT (WINAPI *RegisterCallNotifications)(ITTAPI2 *This,ITAddress *pAddress,VARIANT_BOOL fMonitor,VARIANT_BOOL fOwner,__LONG32 lMediaTypes,__LONG32 lCallbackInstance,__LONG32 *plRegister);
      HRESULT (WINAPI *UnregisterNotifications)(ITTAPI2 *This,__LONG32 lRegister);
      HRESULT (WINAPI *get_CallHubs)(ITTAPI2 *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateCallHubs)(ITTAPI2 *This,IEnumCallHub **ppEnumCallHub);
      HRESULT (WINAPI *SetCallHubTracking)(ITTAPI2 *This,VARIANT pAddresses,VARIANT_BOOL bTracking);
      HRESULT (WINAPI *EnumeratePrivateTAPIObjects)(ITTAPI2 *This,IEnumUnknown **ppEnumUnknown);
      HRESULT (WINAPI *get_PrivateTAPIObjects)(ITTAPI2 *This,VARIANT *pVariant);
      HRESULT (WINAPI *RegisterRequestRecipient)(ITTAPI2 *This,__LONG32 lRegistrationInstance,__LONG32 lRequestMode,VARIANT_BOOL fEnable);
      HRESULT (WINAPI *SetAssistedTelephonyPriority)(ITTAPI2 *This,BSTR pAppFilename,VARIANT_BOOL fPriority);
      HRESULT (WINAPI *SetApplicationPriority)(ITTAPI2 *This,BSTR pAppFilename,__LONG32 lMediaType,VARIANT_BOOL fPriority);
      HRESULT (WINAPI *put_EventFilter)(ITTAPI2 *This,__LONG32 lFilterMask);
      HRESULT (WINAPI *get_EventFilter)(ITTAPI2 *This,__LONG32 *plFilterMask);
      HRESULT (WINAPI *get_Phones)(ITTAPI2 *This,VARIANT *pPhones);
      HRESULT (WINAPI *EnumeratePhones)(ITTAPI2 *This,IEnumPhone **ppEnumPhone);
      HRESULT (WINAPI *CreateEmptyCollectionObject)(ITTAPI2 *This,ITCollection2 **ppCollection);
    END_INTERFACE
  } ITTAPI2Vtbl;
  struct ITTAPI2 {
    CONST_VTBL struct ITTAPI2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTAPI2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTAPI2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTAPI2_Release(This) (This)->lpVtbl->Release(This)
#define ITTAPI2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTAPI2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTAPI2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTAPI2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITTAPI2_Initialize(This) (This)->lpVtbl->Initialize(This)
#define ITTAPI2_Shutdown(This) (This)->lpVtbl->Shutdown(This)
#define ITTAPI2_get_Addresses(This,pVariant) (This)->lpVtbl->get_Addresses(This,pVariant)
#define ITTAPI2_EnumerateAddresses(This,ppEnumAddress) (This)->lpVtbl->EnumerateAddresses(This,ppEnumAddress)
#define ITTAPI2_RegisterCallNotifications(This,pAddress,fMonitor,fOwner,lMediaTypes,lCallbackInstance,plRegister) (This)->lpVtbl->RegisterCallNotifications(This,pAddress,fMonitor,fOwner,lMediaTypes,lCallbackInstance,plRegister)
#define ITTAPI2_UnregisterNotifications(This,lRegister) (This)->lpVtbl->UnregisterNotifications(This,lRegister)
#define ITTAPI2_get_CallHubs(This,pVariant) (This)->lpVtbl->get_CallHubs(This,pVariant)
#define ITTAPI2_EnumerateCallHubs(This,ppEnumCallHub) (This)->lpVtbl->EnumerateCallHubs(This,ppEnumCallHub)
#define ITTAPI2_SetCallHubTracking(This,pAddresses,bTracking) (This)->lpVtbl->SetCallHubTracking(This,pAddresses,bTracking)
#define ITTAPI2_EnumeratePrivateTAPIObjects(This,ppEnumUnknown) (This)->lpVtbl->EnumeratePrivateTAPIObjects(This,ppEnumUnknown)
#define ITTAPI2_get_PrivateTAPIObjects(This,pVariant) (This)->lpVtbl->get_PrivateTAPIObjects(This,pVariant)
#define ITTAPI2_RegisterRequestRecipient(This,lRegistrationInstance,lRequestMode,fEnable) (This)->lpVtbl->RegisterRequestRecipient(This,lRegistrationInstance,lRequestMode,fEnable)
#define ITTAPI2_SetAssistedTelephonyPriority(This,pAppFilename,fPriority) (This)->lpVtbl->SetAssistedTelephonyPriority(This,pAppFilename,fPriority)
#define ITTAPI2_SetApplicationPriority(This,pAppFilename,lMediaType,fPriority) (This)->lpVtbl->SetApplicationPriority(This,pAppFilename,lMediaType,fPriority)
#define ITTAPI2_put_EventFilter(This,lFilterMask) (This)->lpVtbl->put_EventFilter(This,lFilterMask)
#define ITTAPI2_get_EventFilter(This,plFilterMask) (This)->lpVtbl->get_EventFilter(This,plFilterMask)
#define ITTAPI2_get_Phones(This,pPhones) (This)->lpVtbl->get_Phones(This,pPhones)
#define ITTAPI2_EnumeratePhones(This,ppEnumPhone) (This)->lpVtbl->EnumeratePhones(This,ppEnumPhone)
#define ITTAPI2_CreateEmptyCollectionObject(This,ppCollection) (This)->lpVtbl->CreateEmptyCollectionObject(This,ppCollection)
#endif
#endif
  HRESULT WINAPI ITTAPI2_get_Phones_Proxy(ITTAPI2 *This,VARIANT *pPhones);
  void __RPC_STUB ITTAPI2_get_Phones_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI2_EnumeratePhones_Proxy(ITTAPI2 *This,IEnumPhone **ppEnumPhone);
  void __RPC_STUB ITTAPI2_EnumeratePhones_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPI2_CreateEmptyCollectionObject_Proxy(ITTAPI2 *This,ITCollection2 **ppCollection);
  void __RPC_STUB ITTAPI2_CreateEmptyCollectionObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITMediaSupport_INTERFACE_DEFINED__
#define __ITMediaSupport_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITMediaSupport;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITMediaSupport : public IDispatch {
  public:
    virtual HRESULT WINAPI get_MediaTypes(__LONG32 *plMediaTypes) = 0;
    virtual HRESULT WINAPI QueryMediaType(__LONG32 lMediaType,VARIANT_BOOL *pfSupport) = 0;
  };
#else
  typedef struct ITMediaSupportVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITMediaSupport *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITMediaSupport *This);
      ULONG (WINAPI *Release)(ITMediaSupport *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITMediaSupport *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITMediaSupport *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITMediaSupport *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITMediaSupport *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_MediaTypes)(ITMediaSupport *This,__LONG32 *plMediaTypes);
      HRESULT (WINAPI *QueryMediaType)(ITMediaSupport *This,__LONG32 lMediaType,VARIANT_BOOL *pfSupport);
    END_INTERFACE
  } ITMediaSupportVtbl;
  struct ITMediaSupport {
    CONST_VTBL struct ITMediaSupportVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITMediaSupport_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITMediaSupport_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITMediaSupport_Release(This) (This)->lpVtbl->Release(This)
#define ITMediaSupport_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITMediaSupport_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITMediaSupport_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITMediaSupport_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITMediaSupport_get_MediaTypes(This,plMediaTypes) (This)->lpVtbl->get_MediaTypes(This,plMediaTypes)
#define ITMediaSupport_QueryMediaType(This,lMediaType,pfSupport) (This)->lpVtbl->QueryMediaType(This,lMediaType,pfSupport)
#endif
#endif
  HRESULT WINAPI ITMediaSupport_get_MediaTypes_Proxy(ITMediaSupport *This,__LONG32 *plMediaTypes);
  void __RPC_STUB ITMediaSupport_get_MediaTypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMediaSupport_QueryMediaType_Proxy(ITMediaSupport *This,__LONG32 lMediaType,VARIANT_BOOL *pfSupport);
  void __RPC_STUB ITMediaSupport_QueryMediaType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITPluggableTerminalClassInfo_INTERFACE_DEFINED__
#define __ITPluggableTerminalClassInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITPluggableTerminalClassInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITPluggableTerminalClassInfo : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *pName) = 0;
    virtual HRESULT WINAPI get_Company(BSTR *pCompany) = 0;
    virtual HRESULT WINAPI get_Version(BSTR *pVersion) = 0;
    virtual HRESULT WINAPI get_TerminalClass(BSTR *pTerminalClass) = 0;
    virtual HRESULT WINAPI get_CLSID(BSTR *pCLSID) = 0;
    virtual HRESULT WINAPI get_Direction(TERMINAL_DIRECTION *pDirection) = 0;
    virtual HRESULT WINAPI get_MediaTypes(__LONG32 *pMediaTypes) = 0;
  };
#else
  typedef struct ITPluggableTerminalClassInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITPluggableTerminalClassInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITPluggableTerminalClassInfo *This);
      ULONG (WINAPI *Release)(ITPluggableTerminalClassInfo *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITPluggableTerminalClassInfo *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITPluggableTerminalClassInfo *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITPluggableTerminalClassInfo *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITPluggableTerminalClassInfo *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(ITPluggableTerminalClassInfo *This,BSTR *pName);
      HRESULT (WINAPI *get_Company)(ITPluggableTerminalClassInfo *This,BSTR *pCompany);
      HRESULT (WINAPI *get_Version)(ITPluggableTerminalClassInfo *This,BSTR *pVersion);
      HRESULT (WINAPI *get_TerminalClass)(ITPluggableTerminalClassInfo *This,BSTR *pTerminalClass);
      HRESULT (WINAPI *get_CLSID)(ITPluggableTerminalClassInfo *This,BSTR *pCLSID);
      HRESULT (WINAPI *get_Direction)(ITPluggableTerminalClassInfo *This,TERMINAL_DIRECTION *pDirection);
      HRESULT (WINAPI *get_MediaTypes)(ITPluggableTerminalClassInfo *This,__LONG32 *pMediaTypes);
    END_INTERFACE
  } ITPluggableTerminalClassInfoVtbl;
  struct ITPluggableTerminalClassInfo {
    CONST_VTBL struct ITPluggableTerminalClassInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITPluggableTerminalClassInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITPluggableTerminalClassInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITPluggableTerminalClassInfo_Release(This) (This)->lpVtbl->Release(This)
#define ITPluggableTerminalClassInfo_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITPluggableTerminalClassInfo_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITPluggableTerminalClassInfo_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITPluggableTerminalClassInfo_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITPluggableTerminalClassInfo_get_Name(This,pName) (This)->lpVtbl->get_Name(This,pName)
#define ITPluggableTerminalClassInfo_get_Company(This,pCompany) (This)->lpVtbl->get_Company(This,pCompany)
#define ITPluggableTerminalClassInfo_get_Version(This,pVersion) (This)->lpVtbl->get_Version(This,pVersion)
#define ITPluggableTerminalClassInfo_get_TerminalClass(This,pTerminalClass) (This)->lpVtbl->get_TerminalClass(This,pTerminalClass)
#define ITPluggableTerminalClassInfo_get_CLSID(This,pCLSID) (This)->lpVtbl->get_CLSID(This,pCLSID)
#define ITPluggableTerminalClassInfo_get_Direction(This,pDirection) (This)->lpVtbl->get_Direction(This,pDirection)
#define ITPluggableTerminalClassInfo_get_MediaTypes(This,pMediaTypes) (This)->lpVtbl->get_MediaTypes(This,pMediaTypes)
#endif
#endif
  HRESULT WINAPI ITPluggableTerminalClassInfo_get_Name_Proxy(ITPluggableTerminalClassInfo *This,BSTR *pName);
  void __RPC_STUB ITPluggableTerminalClassInfo_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassInfo_get_Company_Proxy(ITPluggableTerminalClassInfo *This,BSTR *pCompany);
  void __RPC_STUB ITPluggableTerminalClassInfo_get_Company_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassInfo_get_Version_Proxy(ITPluggableTerminalClassInfo *This,BSTR *pVersion);
  void __RPC_STUB ITPluggableTerminalClassInfo_get_Version_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassInfo_get_TerminalClass_Proxy(ITPluggableTerminalClassInfo *This,BSTR *pTerminalClass);
  void __RPC_STUB ITPluggableTerminalClassInfo_get_TerminalClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassInfo_get_CLSID_Proxy(ITPluggableTerminalClassInfo *This,BSTR *pCLSID);
  void __RPC_STUB ITPluggableTerminalClassInfo_get_CLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassInfo_get_Direction_Proxy(ITPluggableTerminalClassInfo *This,TERMINAL_DIRECTION *pDirection);
  void __RPC_STUB ITPluggableTerminalClassInfo_get_Direction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalClassInfo_get_MediaTypes_Proxy(ITPluggableTerminalClassInfo *This,__LONG32 *pMediaTypes);
  void __RPC_STUB ITPluggableTerminalClassInfo_get_MediaTypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITPluggableTerminalSuperclassInfo_INTERFACE_DEFINED__
#define __ITPluggableTerminalSuperclassInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITPluggableTerminalSuperclassInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITPluggableTerminalSuperclassInfo : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *pName) = 0;
    virtual HRESULT WINAPI get_CLSID(BSTR *pCLSID) = 0;
  };
#else
  typedef struct ITPluggableTerminalSuperclassInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITPluggableTerminalSuperclassInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITPluggableTerminalSuperclassInfo *This);
      ULONG (WINAPI *Release)(ITPluggableTerminalSuperclassInfo *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITPluggableTerminalSuperclassInfo *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITPluggableTerminalSuperclassInfo *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITPluggableTerminalSuperclassInfo *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITPluggableTerminalSuperclassInfo *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(ITPluggableTerminalSuperclassInfo *This,BSTR *pName);
      HRESULT (WINAPI *get_CLSID)(ITPluggableTerminalSuperclassInfo *This,BSTR *pCLSID);
    END_INTERFACE
  } ITPluggableTerminalSuperclassInfoVtbl;
  struct ITPluggableTerminalSuperclassInfo {
    CONST_VTBL struct ITPluggableTerminalSuperclassInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITPluggableTerminalSuperclassInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITPluggableTerminalSuperclassInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITPluggableTerminalSuperclassInfo_Release(This) (This)->lpVtbl->Release(This)
#define ITPluggableTerminalSuperclassInfo_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITPluggableTerminalSuperclassInfo_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITPluggableTerminalSuperclassInfo_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITPluggableTerminalSuperclassInfo_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITPluggableTerminalSuperclassInfo_get_Name(This,pName) (This)->lpVtbl->get_Name(This,pName)
#define ITPluggableTerminalSuperclassInfo_get_CLSID(This,pCLSID) (This)->lpVtbl->get_CLSID(This,pCLSID)
#endif
#endif
  HRESULT WINAPI ITPluggableTerminalSuperclassInfo_get_Name_Proxy(ITPluggableTerminalSuperclassInfo *This,BSTR *pName);
  void __RPC_STUB ITPluggableTerminalSuperclassInfo_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPluggableTerminalSuperclassInfo_get_CLSID_Proxy(ITPluggableTerminalSuperclassInfo *This,BSTR *pCLSID);
  void __RPC_STUB ITPluggableTerminalSuperclassInfo_get_CLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTerminalSupport_INTERFACE_DEFINED__
#define __ITTerminalSupport_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTerminalSupport;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTerminalSupport : public IDispatch {
  public:
    virtual HRESULT WINAPI get_StaticTerminals(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateStaticTerminals(IEnumTerminal **ppTerminalEnumerator) = 0;
    virtual HRESULT WINAPI get_DynamicTerminalClasses(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateDynamicTerminalClasses(IEnumTerminalClass **ppTerminalClassEnumerator) = 0;
    virtual HRESULT WINAPI CreateTerminal(BSTR pTerminalClass,__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal) = 0;
    virtual HRESULT WINAPI GetDefaultStaticTerminal(__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal) = 0;
  };
#else
  typedef struct ITTerminalSupportVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTerminalSupport *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTerminalSupport *This);
      ULONG (WINAPI *Release)(ITTerminalSupport *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTerminalSupport *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTerminalSupport *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTerminalSupport *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTerminalSupport *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_StaticTerminals)(ITTerminalSupport *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateStaticTerminals)(ITTerminalSupport *This,IEnumTerminal **ppTerminalEnumerator);
      HRESULT (WINAPI *get_DynamicTerminalClasses)(ITTerminalSupport *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateDynamicTerminalClasses)(ITTerminalSupport *This,IEnumTerminalClass **ppTerminalClassEnumerator);
      HRESULT (WINAPI *CreateTerminal)(ITTerminalSupport *This,BSTR pTerminalClass,__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal);
      HRESULT (WINAPI *GetDefaultStaticTerminal)(ITTerminalSupport *This,__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal);
    END_INTERFACE
  } ITTerminalSupportVtbl;
  struct ITTerminalSupport {
    CONST_VTBL struct ITTerminalSupportVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTerminalSupport_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTerminalSupport_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTerminalSupport_Release(This) (This)->lpVtbl->Release(This)
#define ITTerminalSupport_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTerminalSupport_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTerminalSupport_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTerminalSupport_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITTerminalSupport_get_StaticTerminals(This,pVariant) (This)->lpVtbl->get_StaticTerminals(This,pVariant)
#define ITTerminalSupport_EnumerateStaticTerminals(This,ppTerminalEnumerator) (This)->lpVtbl->EnumerateStaticTerminals(This,ppTerminalEnumerator)
#define ITTerminalSupport_get_DynamicTerminalClasses(This,pVariant) (This)->lpVtbl->get_DynamicTerminalClasses(This,pVariant)
#define ITTerminalSupport_EnumerateDynamicTerminalClasses(This,ppTerminalClassEnumerator) (This)->lpVtbl->EnumerateDynamicTerminalClasses(This,ppTerminalClassEnumerator)
#define ITTerminalSupport_CreateTerminal(This,pTerminalClass,lMediaType,Direction,ppTerminal) (This)->lpVtbl->CreateTerminal(This,pTerminalClass,lMediaType,Direction,ppTerminal)
#define ITTerminalSupport_GetDefaultStaticTerminal(This,lMediaType,Direction,ppTerminal) (This)->lpVtbl->GetDefaultStaticTerminal(This,lMediaType,Direction,ppTerminal)
#endif
#endif
  HRESULT WINAPI ITTerminalSupport_get_StaticTerminals_Proxy(ITTerminalSupport *This,VARIANT *pVariant);
  void __RPC_STUB ITTerminalSupport_get_StaticTerminals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalSupport_EnumerateStaticTerminals_Proxy(ITTerminalSupport *This,IEnumTerminal **ppTerminalEnumerator);
  void __RPC_STUB ITTerminalSupport_EnumerateStaticTerminals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalSupport_get_DynamicTerminalClasses_Proxy(ITTerminalSupport *This,VARIANT *pVariant);
  void __RPC_STUB ITTerminalSupport_get_DynamicTerminalClasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalSupport_EnumerateDynamicTerminalClasses_Proxy(ITTerminalSupport *This,IEnumTerminalClass **ppTerminalClassEnumerator);
  void __RPC_STUB ITTerminalSupport_EnumerateDynamicTerminalClasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalSupport_CreateTerminal_Proxy(ITTerminalSupport *This,BSTR pTerminalClass,__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal);
  void __RPC_STUB ITTerminalSupport_CreateTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalSupport_GetDefaultStaticTerminal_Proxy(ITTerminalSupport *This,__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal);
  void __RPC_STUB ITTerminalSupport_GetDefaultStaticTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTerminalSupport2_INTERFACE_DEFINED__
#define __ITTerminalSupport2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTerminalSupport2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTerminalSupport2 : public ITTerminalSupport {
  public:
    virtual HRESULT WINAPI get_PluggableSuperclasses(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumeratePluggableSuperclasses(IEnumPluggableSuperclassInfo **ppSuperclassEnumerator) = 0;
    virtual HRESULT WINAPI get_PluggableTerminalClasses(BSTR bstrTerminalSuperclass,__LONG32 lMediaType,VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumeratePluggableTerminalClasses(CLSID iidTerminalSuperclass,__LONG32 lMediaType,IEnumPluggableTerminalClassInfo **ppClassEnumerator) = 0;
  };
#else
  typedef struct ITTerminalSupport2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTerminalSupport2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTerminalSupport2 *This);
      ULONG (WINAPI *Release)(ITTerminalSupport2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTerminalSupport2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTerminalSupport2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTerminalSupport2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTerminalSupport2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_StaticTerminals)(ITTerminalSupport2 *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateStaticTerminals)(ITTerminalSupport2 *This,IEnumTerminal **ppTerminalEnumerator);
      HRESULT (WINAPI *get_DynamicTerminalClasses)(ITTerminalSupport2 *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateDynamicTerminalClasses)(ITTerminalSupport2 *This,IEnumTerminalClass **ppTerminalClassEnumerator);
      HRESULT (WINAPI *CreateTerminal)(ITTerminalSupport2 *This,BSTR pTerminalClass,__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal);
      HRESULT (WINAPI *GetDefaultStaticTerminal)(ITTerminalSupport2 *This,__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal);
      HRESULT (WINAPI *get_PluggableSuperclasses)(ITTerminalSupport2 *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumeratePluggableSuperclasses)(ITTerminalSupport2 *This,IEnumPluggableSuperclassInfo **ppSuperclassEnumerator);
      HRESULT (WINAPI *get_PluggableTerminalClasses)(ITTerminalSupport2 *This,BSTR bstrTerminalSuperclass,__LONG32 lMediaType,VARIANT *pVariant);
      HRESULT (WINAPI *EnumeratePluggableTerminalClasses)(ITTerminalSupport2 *This,CLSID iidTerminalSuperclass,__LONG32 lMediaType,IEnumPluggableTerminalClassInfo **ppClassEnumerator);
    END_INTERFACE
  } ITTerminalSupport2Vtbl;
  struct ITTerminalSupport2 {
    CONST_VTBL struct ITTerminalSupport2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTerminalSupport2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTerminalSupport2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTerminalSupport2_Release(This) (This)->lpVtbl->Release(This)
#define ITTerminalSupport2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTerminalSupport2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTerminalSupport2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTerminalSupport2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITTerminalSupport2_get_StaticTerminals(This,pVariant) (This)->lpVtbl->get_StaticTerminals(This,pVariant)
#define ITTerminalSupport2_EnumerateStaticTerminals(This,ppTerminalEnumerator) (This)->lpVtbl->EnumerateStaticTerminals(This,ppTerminalEnumerator)
#define ITTerminalSupport2_get_DynamicTerminalClasses(This,pVariant) (This)->lpVtbl->get_DynamicTerminalClasses(This,pVariant)
#define ITTerminalSupport2_EnumerateDynamicTerminalClasses(This,ppTerminalClassEnumerator) (This)->lpVtbl->EnumerateDynamicTerminalClasses(This,ppTerminalClassEnumerator)
#define ITTerminalSupport2_CreateTerminal(This,pTerminalClass,lMediaType,Direction,ppTerminal) (This)->lpVtbl->CreateTerminal(This,pTerminalClass,lMediaType,Direction,ppTerminal)
#define ITTerminalSupport2_GetDefaultStaticTerminal(This,lMediaType,Direction,ppTerminal) (This)->lpVtbl->GetDefaultStaticTerminal(This,lMediaType,Direction,ppTerminal)
#define ITTerminalSupport2_get_PluggableSuperclasses(This,pVariant) (This)->lpVtbl->get_PluggableSuperclasses(This,pVariant)
#define ITTerminalSupport2_EnumeratePluggableSuperclasses(This,ppSuperclassEnumerator) (This)->lpVtbl->EnumeratePluggableSuperclasses(This,ppSuperclassEnumerator)
#define ITTerminalSupport2_get_PluggableTerminalClasses(This,bstrTerminalSuperclass,lMediaType,pVariant) (This)->lpVtbl->get_PluggableTerminalClasses(This,bstrTerminalSuperclass,lMediaType,pVariant)
#define ITTerminalSupport2_EnumeratePluggableTerminalClasses(This,iidTerminalSuperclass,lMediaType,ppClassEnumerator) (This)->lpVtbl->EnumeratePluggableTerminalClasses(This,iidTerminalSuperclass,lMediaType,ppClassEnumerator)
#endif
#endif
  HRESULT WINAPI ITTerminalSupport2_get_PluggableSuperclasses_Proxy(ITTerminalSupport2 *This,VARIANT *pVariant);
  void __RPC_STUB ITTerminalSupport2_get_PluggableSuperclasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalSupport2_EnumeratePluggableSuperclasses_Proxy(ITTerminalSupport2 *This,IEnumPluggableSuperclassInfo **ppSuperclassEnumerator);
  void __RPC_STUB ITTerminalSupport2_EnumeratePluggableSuperclasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalSupport2_get_PluggableTerminalClasses_Proxy(ITTerminalSupport2 *This,BSTR bstrTerminalSuperclass,__LONG32 lMediaType,VARIANT *pVariant);
  void __RPC_STUB ITTerminalSupport2_get_PluggableTerminalClasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminalSupport2_EnumeratePluggableTerminalClasses_Proxy(ITTerminalSupport2 *This,CLSID iidTerminalSuperclass,__LONG32 lMediaType,IEnumPluggableTerminalClassInfo **ppClassEnumerator);
  void __RPC_STUB ITTerminalSupport2_EnumeratePluggableTerminalClasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAddress_INTERFACE_DEFINED__
#define __ITAddress_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAddress;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAddress : public IDispatch {
  public:
    virtual HRESULT WINAPI get_State(ADDRESS_STATE *pAddressState) = 0;
    virtual HRESULT WINAPI get_AddressName(BSTR *ppName) = 0;
    virtual HRESULT WINAPI get_ServiceProviderName(BSTR *ppName) = 0;
    virtual HRESULT WINAPI get_TAPIObject(ITTAPI **ppTapiObject) = 0;
    virtual HRESULT WINAPI CreateCall(BSTR pDestAddress,__LONG32 lAddressType,__LONG32 lMediaTypes,ITBasicCallControl **ppCall) = 0;
    virtual HRESULT WINAPI get_Calls(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateCalls(IEnumCall **ppCallEnum) = 0;
    virtual HRESULT WINAPI get_DialableAddress(BSTR *pDialableAddress) = 0;
    virtual HRESULT WINAPI CreateForwardInfoObject(ITForwardInformation **ppForwardInfo) = 0;
    virtual HRESULT WINAPI Forward(ITForwardInformation *pForwardInfo,ITBasicCallControl *pCall) = 0;
    virtual HRESULT WINAPI get_CurrentForwardInfo(ITForwardInformation **ppForwardInfo) = 0;
    virtual HRESULT WINAPI put_MessageWaiting(VARIANT_BOOL fMessageWaiting) = 0;
    virtual HRESULT WINAPI get_MessageWaiting(VARIANT_BOOL *pfMessageWaiting) = 0;
    virtual HRESULT WINAPI put_DoNotDisturb(VARIANT_BOOL fDoNotDisturb) = 0;
    virtual HRESULT WINAPI get_DoNotDisturb(VARIANT_BOOL *pfDoNotDisturb) = 0;
  };
#else
  typedef struct ITAddressVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAddress *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAddress *This);
      ULONG (WINAPI *Release)(ITAddress *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAddress *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAddress *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAddress *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAddress *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_State)(ITAddress *This,ADDRESS_STATE *pAddressState);
      HRESULT (WINAPI *get_AddressName)(ITAddress *This,BSTR *ppName);
      HRESULT (WINAPI *get_ServiceProviderName)(ITAddress *This,BSTR *ppName);
      HRESULT (WINAPI *get_TAPIObject)(ITAddress *This,ITTAPI **ppTapiObject);
      HRESULT (WINAPI *CreateCall)(ITAddress *This,BSTR pDestAddress,__LONG32 lAddressType,__LONG32 lMediaTypes,ITBasicCallControl **ppCall);
      HRESULT (WINAPI *get_Calls)(ITAddress *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateCalls)(ITAddress *This,IEnumCall **ppCallEnum);
      HRESULT (WINAPI *get_DialableAddress)(ITAddress *This,BSTR *pDialableAddress);
      HRESULT (WINAPI *CreateForwardInfoObject)(ITAddress *This,ITForwardInformation **ppForwardInfo);
      HRESULT (WINAPI *Forward)(ITAddress *This,ITForwardInformation *pForwardInfo,ITBasicCallControl *pCall);
      HRESULT (WINAPI *get_CurrentForwardInfo)(ITAddress *This,ITForwardInformation **ppForwardInfo);
      HRESULT (WINAPI *put_MessageWaiting)(ITAddress *This,VARIANT_BOOL fMessageWaiting);
      HRESULT (WINAPI *get_MessageWaiting)(ITAddress *This,VARIANT_BOOL *pfMessageWaiting);
      HRESULT (WINAPI *put_DoNotDisturb)(ITAddress *This,VARIANT_BOOL fDoNotDisturb);
      HRESULT (WINAPI *get_DoNotDisturb)(ITAddress *This,VARIANT_BOOL *pfDoNotDisturb);
    END_INTERFACE
  } ITAddressVtbl;
  struct ITAddress {
    CONST_VTBL struct ITAddressVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAddress_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAddress_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAddress_Release(This) (This)->lpVtbl->Release(This)
#define ITAddress_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAddress_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAddress_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAddress_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAddress_get_State(This,pAddressState) (This)->lpVtbl->get_State(This,pAddressState)
#define ITAddress_get_AddressName(This,ppName) (This)->lpVtbl->get_AddressName(This,ppName)
#define ITAddress_get_ServiceProviderName(This,ppName) (This)->lpVtbl->get_ServiceProviderName(This,ppName)
#define ITAddress_get_TAPIObject(This,ppTapiObject) (This)->lpVtbl->get_TAPIObject(This,ppTapiObject)
#define ITAddress_CreateCall(This,pDestAddress,lAddressType,lMediaTypes,ppCall) (This)->lpVtbl->CreateCall(This,pDestAddress,lAddressType,lMediaTypes,ppCall)
#define ITAddress_get_Calls(This,pVariant) (This)->lpVtbl->get_Calls(This,pVariant)
#define ITAddress_EnumerateCalls(This,ppCallEnum) (This)->lpVtbl->EnumerateCalls(This,ppCallEnum)
#define ITAddress_get_DialableAddress(This,pDialableAddress) (This)->lpVtbl->get_DialableAddress(This,pDialableAddress)
#define ITAddress_CreateForwardInfoObject(This,ppForwardInfo) (This)->lpVtbl->CreateForwardInfoObject(This,ppForwardInfo)
#define ITAddress_Forward(This,pForwardInfo,pCall) (This)->lpVtbl->Forward(This,pForwardInfo,pCall)
#define ITAddress_get_CurrentForwardInfo(This,ppForwardInfo) (This)->lpVtbl->get_CurrentForwardInfo(This,ppForwardInfo)
#define ITAddress_put_MessageWaiting(This,fMessageWaiting) (This)->lpVtbl->put_MessageWaiting(This,fMessageWaiting)
#define ITAddress_get_MessageWaiting(This,pfMessageWaiting) (This)->lpVtbl->get_MessageWaiting(This,pfMessageWaiting)
#define ITAddress_put_DoNotDisturb(This,fDoNotDisturb) (This)->lpVtbl->put_DoNotDisturb(This,fDoNotDisturb)
#define ITAddress_get_DoNotDisturb(This,pfDoNotDisturb) (This)->lpVtbl->get_DoNotDisturb(This,pfDoNotDisturb)
#endif
#endif
  HRESULT WINAPI ITAddress_get_State_Proxy(ITAddress *This,ADDRESS_STATE *pAddressState);
  void __RPC_STUB ITAddress_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_get_AddressName_Proxy(ITAddress *This,BSTR *ppName);
  void __RPC_STUB ITAddress_get_AddressName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_get_ServiceProviderName_Proxy(ITAddress *This,BSTR *ppName);
  void __RPC_STUB ITAddress_get_ServiceProviderName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_get_TAPIObject_Proxy(ITAddress *This,ITTAPI **ppTapiObject);
  void __RPC_STUB ITAddress_get_TAPIObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_CreateCall_Proxy(ITAddress *This,BSTR pDestAddress,__LONG32 lAddressType,__LONG32 lMediaTypes,ITBasicCallControl **ppCall);
  void __RPC_STUB ITAddress_CreateCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_get_Calls_Proxy(ITAddress *This,VARIANT *pVariant);
  void __RPC_STUB ITAddress_get_Calls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_EnumerateCalls_Proxy(ITAddress *This,IEnumCall **ppCallEnum);
  void __RPC_STUB ITAddress_EnumerateCalls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_get_DialableAddress_Proxy(ITAddress *This,BSTR *pDialableAddress);
  void __RPC_STUB ITAddress_get_DialableAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_CreateForwardInfoObject_Proxy(ITAddress *This,ITForwardInformation **ppForwardInfo);
  void __RPC_STUB ITAddress_CreateForwardInfoObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_Forward_Proxy(ITAddress *This,ITForwardInformation *pForwardInfo,ITBasicCallControl *pCall);
  void __RPC_STUB ITAddress_Forward_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_get_CurrentForwardInfo_Proxy(ITAddress *This,ITForwardInformation **ppForwardInfo);
  void __RPC_STUB ITAddress_get_CurrentForwardInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_put_MessageWaiting_Proxy(ITAddress *This,VARIANT_BOOL fMessageWaiting);
  void __RPC_STUB ITAddress_put_MessageWaiting_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_get_MessageWaiting_Proxy(ITAddress *This,VARIANT_BOOL *pfMessageWaiting);
  void __RPC_STUB ITAddress_get_MessageWaiting_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_put_DoNotDisturb_Proxy(ITAddress *This,VARIANT_BOOL fDoNotDisturb);
  void __RPC_STUB ITAddress_put_DoNotDisturb_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress_get_DoNotDisturb_Proxy(ITAddress *This,VARIANT_BOOL *pfDoNotDisturb);
  void __RPC_STUB ITAddress_get_DoNotDisturb_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAddress2_INTERFACE_DEFINED__
#define __ITAddress2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAddress2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAddress2 : public ITAddress {
  public:
    virtual HRESULT WINAPI get_Phones(VARIANT *pPhones) = 0;
    virtual HRESULT WINAPI EnumeratePhones(IEnumPhone **ppEnumPhone) = 0;
    virtual HRESULT WINAPI GetPhoneFromTerminal(ITTerminal *pTerminal,ITPhone **ppPhone) = 0;
    virtual HRESULT WINAPI get_PreferredPhones(VARIANT *pPhones) = 0;
    virtual HRESULT WINAPI EnumeratePreferredPhones(IEnumPhone **ppEnumPhone) = 0;
    virtual HRESULT WINAPI get_EventFilter(TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL *pEnable) = 0;
    virtual HRESULT WINAPI put_EventFilter(TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL bEnable) = 0;
    virtual HRESULT WINAPI DeviceSpecific(ITCallInfo *pCall,BYTE *pParams,DWORD dwSize) = 0;
    virtual HRESULT WINAPI DeviceSpecificVariant(ITCallInfo *pCall,VARIANT varDevSpecificByteArray) = 0;
    virtual HRESULT WINAPI NegotiateExtVersion(__LONG32 lLowVersion,__LONG32 lHighVersion,__LONG32 *plExtVersion) = 0;
  };
#else
  typedef struct ITAddress2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAddress2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAddress2 *This);
      ULONG (WINAPI *Release)(ITAddress2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAddress2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAddress2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAddress2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAddress2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_State)(ITAddress2 *This,ADDRESS_STATE *pAddressState);
      HRESULT (WINAPI *get_AddressName)(ITAddress2 *This,BSTR *ppName);
      HRESULT (WINAPI *get_ServiceProviderName)(ITAddress2 *This,BSTR *ppName);
      HRESULT (WINAPI *get_TAPIObject)(ITAddress2 *This,ITTAPI **ppTapiObject);
      HRESULT (WINAPI *CreateCall)(ITAddress2 *This,BSTR pDestAddress,__LONG32 lAddressType,__LONG32 lMediaTypes,ITBasicCallControl **ppCall);
      HRESULT (WINAPI *get_Calls)(ITAddress2 *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateCalls)(ITAddress2 *This,IEnumCall **ppCallEnum);
      HRESULT (WINAPI *get_DialableAddress)(ITAddress2 *This,BSTR *pDialableAddress);
      HRESULT (WINAPI *CreateForwardInfoObject)(ITAddress2 *This,ITForwardInformation **ppForwardInfo);
      HRESULT (WINAPI *Forward)(ITAddress2 *This,ITForwardInformation *pForwardInfo,ITBasicCallControl *pCall);
      HRESULT (WINAPI *get_CurrentForwardInfo)(ITAddress2 *This,ITForwardInformation **ppForwardInfo);
      HRESULT (WINAPI *put_MessageWaiting)(ITAddress2 *This,VARIANT_BOOL fMessageWaiting);
      HRESULT (WINAPI *get_MessageWaiting)(ITAddress2 *This,VARIANT_BOOL *pfMessageWaiting);
      HRESULT (WINAPI *put_DoNotDisturb)(ITAddress2 *This,VARIANT_BOOL fDoNotDisturb);
      HRESULT (WINAPI *get_DoNotDisturb)(ITAddress2 *This,VARIANT_BOOL *pfDoNotDisturb);
      HRESULT (WINAPI *get_Phones)(ITAddress2 *This,VARIANT *pPhones);
      HRESULT (WINAPI *EnumeratePhones)(ITAddress2 *This,IEnumPhone **ppEnumPhone);
      HRESULT (WINAPI *GetPhoneFromTerminal)(ITAddress2 *This,ITTerminal *pTerminal,ITPhone **ppPhone);
      HRESULT (WINAPI *get_PreferredPhones)(ITAddress2 *This,VARIANT *pPhones);
      HRESULT (WINAPI *EnumeratePreferredPhones)(ITAddress2 *This,IEnumPhone **ppEnumPhone);
      HRESULT (WINAPI *get_EventFilter)(ITAddress2 *This,TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL *pEnable);
      HRESULT (WINAPI *put_EventFilter)(ITAddress2 *This,TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL bEnable);
      HRESULT (WINAPI *DeviceSpecific)(ITAddress2 *This,ITCallInfo *pCall,BYTE *pParams,DWORD dwSize);
      HRESULT (WINAPI *DeviceSpecificVariant)(ITAddress2 *This,ITCallInfo *pCall,VARIANT varDevSpecificByteArray);
      HRESULT (WINAPI *NegotiateExtVersion)(ITAddress2 *This,__LONG32 lLowVersion,__LONG32 lHighVersion,__LONG32 *plExtVersion);
    END_INTERFACE
  } ITAddress2Vtbl;
  struct ITAddress2 {
    CONST_VTBL struct ITAddress2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAddress2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAddress2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAddress2_Release(This) (This)->lpVtbl->Release(This)
#define ITAddress2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAddress2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAddress2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAddress2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAddress2_get_State(This,pAddressState) (This)->lpVtbl->get_State(This,pAddressState)
#define ITAddress2_get_AddressName(This,ppName) (This)->lpVtbl->get_AddressName(This,ppName)
#define ITAddress2_get_ServiceProviderName(This,ppName) (This)->lpVtbl->get_ServiceProviderName(This,ppName)
#define ITAddress2_get_TAPIObject(This,ppTapiObject) (This)->lpVtbl->get_TAPIObject(This,ppTapiObject)
#define ITAddress2_CreateCall(This,pDestAddress,lAddressType,lMediaTypes,ppCall) (This)->lpVtbl->CreateCall(This,pDestAddress,lAddressType,lMediaTypes,ppCall)
#define ITAddress2_get_Calls(This,pVariant) (This)->lpVtbl->get_Calls(This,pVariant)
#define ITAddress2_EnumerateCalls(This,ppCallEnum) (This)->lpVtbl->EnumerateCalls(This,ppCallEnum)
#define ITAddress2_get_DialableAddress(This,pDialableAddress) (This)->lpVtbl->get_DialableAddress(This,pDialableAddress)
#define ITAddress2_CreateForwardInfoObject(This,ppForwardInfo) (This)->lpVtbl->CreateForwardInfoObject(This,ppForwardInfo)
#define ITAddress2_Forward(This,pForwardInfo,pCall) (This)->lpVtbl->Forward(This,pForwardInfo,pCall)
#define ITAddress2_get_CurrentForwardInfo(This,ppForwardInfo) (This)->lpVtbl->get_CurrentForwardInfo(This,ppForwardInfo)
#define ITAddress2_put_MessageWaiting(This,fMessageWaiting) (This)->lpVtbl->put_MessageWaiting(This,fMessageWaiting)
#define ITAddress2_get_MessageWaiting(This,pfMessageWaiting) (This)->lpVtbl->get_MessageWaiting(This,pfMessageWaiting)
#define ITAddress2_put_DoNotDisturb(This,fDoNotDisturb) (This)->lpVtbl->put_DoNotDisturb(This,fDoNotDisturb)
#define ITAddress2_get_DoNotDisturb(This,pfDoNotDisturb) (This)->lpVtbl->get_DoNotDisturb(This,pfDoNotDisturb)
#define ITAddress2_get_Phones(This,pPhones) (This)->lpVtbl->get_Phones(This,pPhones)
#define ITAddress2_EnumeratePhones(This,ppEnumPhone) (This)->lpVtbl->EnumeratePhones(This,ppEnumPhone)
#define ITAddress2_GetPhoneFromTerminal(This,pTerminal,ppPhone) (This)->lpVtbl->GetPhoneFromTerminal(This,pTerminal,ppPhone)
#define ITAddress2_get_PreferredPhones(This,pPhones) (This)->lpVtbl->get_PreferredPhones(This,pPhones)
#define ITAddress2_EnumeratePreferredPhones(This,ppEnumPhone) (This)->lpVtbl->EnumeratePreferredPhones(This,ppEnumPhone)
#define ITAddress2_get_EventFilter(This,TapiEvent,lSubEvent,pEnable) (This)->lpVtbl->get_EventFilter(This,TapiEvent,lSubEvent,pEnable)
#define ITAddress2_put_EventFilter(This,TapiEvent,lSubEvent,bEnable) (This)->lpVtbl->put_EventFilter(This,TapiEvent,lSubEvent,bEnable)
#define ITAddress2_DeviceSpecific(This,pCall,pParams,dwSize) (This)->lpVtbl->DeviceSpecific(This,pCall,pParams,dwSize)
#define ITAddress2_DeviceSpecificVariant(This,pCall,varDevSpecificByteArray) (This)->lpVtbl->DeviceSpecificVariant(This,pCall,varDevSpecificByteArray)
#define ITAddress2_NegotiateExtVersion(This,lLowVersion,lHighVersion,plExtVersion) (This)->lpVtbl->NegotiateExtVersion(This,lLowVersion,lHighVersion,plExtVersion)
#endif
#endif
  HRESULT WINAPI ITAddress2_get_Phones_Proxy(ITAddress2 *This,VARIANT *pPhones);
  void __RPC_STUB ITAddress2_get_Phones_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress2_EnumeratePhones_Proxy(ITAddress2 *This,IEnumPhone **ppEnumPhone);
  void __RPC_STUB ITAddress2_EnumeratePhones_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress2_GetPhoneFromTerminal_Proxy(ITAddress2 *This,ITTerminal *pTerminal,ITPhone **ppPhone);
  void __RPC_STUB ITAddress2_GetPhoneFromTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress2_get_PreferredPhones_Proxy(ITAddress2 *This,VARIANT *pPhones);
  void __RPC_STUB ITAddress2_get_PreferredPhones_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress2_EnumeratePreferredPhones_Proxy(ITAddress2 *This,IEnumPhone **ppEnumPhone);
  void __RPC_STUB ITAddress2_EnumeratePreferredPhones_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress2_get_EventFilter_Proxy(ITAddress2 *This,TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL *pEnable);
  void __RPC_STUB ITAddress2_get_EventFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress2_put_EventFilter_Proxy(ITAddress2 *This,TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL bEnable);
  void __RPC_STUB ITAddress2_put_EventFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress2_DeviceSpecific_Proxy(ITAddress2 *This,ITCallInfo *pCall,BYTE *pParams,DWORD dwSize);
  void __RPC_STUB ITAddress2_DeviceSpecific_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress2_DeviceSpecificVariant_Proxy(ITAddress2 *This,ITCallInfo *pCall,VARIANT varDevSpecificByteArray);
  void __RPC_STUB ITAddress2_DeviceSpecificVariant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddress2_NegotiateExtVersion_Proxy(ITAddress2 *This,__LONG32 lLowVersion,__LONG32 lHighVersion,__LONG32 *plExtVersion);
  void __RPC_STUB ITAddress2_NegotiateExtVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAddressCapabilities_INTERFACE_DEFINED__
#define __ITAddressCapabilities_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAddressCapabilities;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAddressCapabilities : public IDispatch {
  public:
    virtual HRESULT WINAPI get_AddressCapability(ADDRESS_CAPABILITY AddressCap,__LONG32 *plCapability) = 0;
    virtual HRESULT WINAPI get_AddressCapabilityString(ADDRESS_CAPABILITY_STRING AddressCapString,BSTR *ppCapabilityString) = 0;
    virtual HRESULT WINAPI get_CallTreatments(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateCallTreatments(IEnumBstr **ppEnumCallTreatment) = 0;
    virtual HRESULT WINAPI get_CompletionMessages(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateCompletionMessages(IEnumBstr **ppEnumCompletionMessage) = 0;
    virtual HRESULT WINAPI get_DeviceClasses(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateDeviceClasses(IEnumBstr **ppEnumDeviceClass) = 0;
  };
#else
  typedef struct ITAddressCapabilitiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAddressCapabilities *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAddressCapabilities *This);
      ULONG (WINAPI *Release)(ITAddressCapabilities *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAddressCapabilities *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAddressCapabilities *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAddressCapabilities *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAddressCapabilities *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_AddressCapability)(ITAddressCapabilities *This,ADDRESS_CAPABILITY AddressCap,__LONG32 *plCapability);
      HRESULT (WINAPI *get_AddressCapabilityString)(ITAddressCapabilities *This,ADDRESS_CAPABILITY_STRING AddressCapString,BSTR *ppCapabilityString);
      HRESULT (WINAPI *get_CallTreatments)(ITAddressCapabilities *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateCallTreatments)(ITAddressCapabilities *This,IEnumBstr **ppEnumCallTreatment);
      HRESULT (WINAPI *get_CompletionMessages)(ITAddressCapabilities *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateCompletionMessages)(ITAddressCapabilities *This,IEnumBstr **ppEnumCompletionMessage);
      HRESULT (WINAPI *get_DeviceClasses)(ITAddressCapabilities *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateDeviceClasses)(ITAddressCapabilities *This,IEnumBstr **ppEnumDeviceClass);
    END_INTERFACE
  } ITAddressCapabilitiesVtbl;
  struct ITAddressCapabilities {
    CONST_VTBL struct ITAddressCapabilitiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAddressCapabilities_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAddressCapabilities_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAddressCapabilities_Release(This) (This)->lpVtbl->Release(This)
#define ITAddressCapabilities_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAddressCapabilities_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAddressCapabilities_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAddressCapabilities_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAddressCapabilities_get_AddressCapability(This,AddressCap,plCapability) (This)->lpVtbl->get_AddressCapability(This,AddressCap,plCapability)
#define ITAddressCapabilities_get_AddressCapabilityString(This,AddressCapString,ppCapabilityString) (This)->lpVtbl->get_AddressCapabilityString(This,AddressCapString,ppCapabilityString)
#define ITAddressCapabilities_get_CallTreatments(This,pVariant) (This)->lpVtbl->get_CallTreatments(This,pVariant)
#define ITAddressCapabilities_EnumerateCallTreatments(This,ppEnumCallTreatment) (This)->lpVtbl->EnumerateCallTreatments(This,ppEnumCallTreatment)
#define ITAddressCapabilities_get_CompletionMessages(This,pVariant) (This)->lpVtbl->get_CompletionMessages(This,pVariant)
#define ITAddressCapabilities_EnumerateCompletionMessages(This,ppEnumCompletionMessage) (This)->lpVtbl->EnumerateCompletionMessages(This,ppEnumCompletionMessage)
#define ITAddressCapabilities_get_DeviceClasses(This,pVariant) (This)->lpVtbl->get_DeviceClasses(This,pVariant)
#define ITAddressCapabilities_EnumerateDeviceClasses(This,ppEnumDeviceClass) (This)->lpVtbl->EnumerateDeviceClasses(This,ppEnumDeviceClass)
#endif
#endif
  HRESULT WINAPI ITAddressCapabilities_get_AddressCapability_Proxy(ITAddressCapabilities *This,ADDRESS_CAPABILITY AddressCap,__LONG32 *plCapability);
  void __RPC_STUB ITAddressCapabilities_get_AddressCapability_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressCapabilities_get_AddressCapabilityString_Proxy(ITAddressCapabilities *This,ADDRESS_CAPABILITY_STRING AddressCapString,BSTR *ppCapabilityString);
  void __RPC_STUB ITAddressCapabilities_get_AddressCapabilityString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressCapabilities_get_CallTreatments_Proxy(ITAddressCapabilities *This,VARIANT *pVariant);
  void __RPC_STUB ITAddressCapabilities_get_CallTreatments_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressCapabilities_EnumerateCallTreatments_Proxy(ITAddressCapabilities *This,IEnumBstr **ppEnumCallTreatment);
  void __RPC_STUB ITAddressCapabilities_EnumerateCallTreatments_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressCapabilities_get_CompletionMessages_Proxy(ITAddressCapabilities *This,VARIANT *pVariant);
  void __RPC_STUB ITAddressCapabilities_get_CompletionMessages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressCapabilities_EnumerateCompletionMessages_Proxy(ITAddressCapabilities *This,IEnumBstr **ppEnumCompletionMessage);
  void __RPC_STUB ITAddressCapabilities_EnumerateCompletionMessages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressCapabilities_get_DeviceClasses_Proxy(ITAddressCapabilities *This,VARIANT *pVariant);
  void __RPC_STUB ITAddressCapabilities_get_DeviceClasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressCapabilities_EnumerateDeviceClasses_Proxy(ITAddressCapabilities *This,IEnumBstr **ppEnumDeviceClass);
  void __RPC_STUB ITAddressCapabilities_EnumerateDeviceClasses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITPhone_INTERFACE_DEFINED__
#define __ITPhone_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITPhone;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITPhone : public IDispatch {
  public:
    virtual HRESULT WINAPI Open(PHONE_PRIVILEGE Privilege) = 0;
    virtual HRESULT WINAPI Close(void) = 0;
    virtual HRESULT WINAPI get_Addresses(VARIANT *pAddresses) = 0;
    virtual HRESULT WINAPI EnumerateAddresses(IEnumAddress **ppEnumAddress) = 0;
    virtual HRESULT WINAPI get_PhoneCapsLong(PHONECAPS_LONG pclCap,__LONG32 *plCapability) = 0;
    virtual HRESULT WINAPI get_PhoneCapsString(PHONECAPS_STRING pcsCap,BSTR *ppCapability) = 0;
    virtual HRESULT WINAPI get_Terminals(ITAddress *pAddress,VARIANT *pTerminals) = 0;
    virtual HRESULT WINAPI EnumerateTerminals(ITAddress *pAddress,IEnumTerminal **ppEnumTerminal) = 0;
    virtual HRESULT WINAPI get_ButtonMode(__LONG32 lButtonID,PHONE_BUTTON_MODE *pButtonMode) = 0;
    virtual HRESULT WINAPI put_ButtonMode(__LONG32 lButtonID,PHONE_BUTTON_MODE ButtonMode) = 0;
    virtual HRESULT WINAPI get_ButtonFunction(__LONG32 lButtonID,PHONE_BUTTON_FUNCTION *pButtonFunction) = 0;
    virtual HRESULT WINAPI put_ButtonFunction(__LONG32 lButtonID,PHONE_BUTTON_FUNCTION ButtonFunction) = 0;
    virtual HRESULT WINAPI get_ButtonText(__LONG32 lButtonID,BSTR *ppButtonText) = 0;
    virtual HRESULT WINAPI put_ButtonText(__LONG32 lButtonID,BSTR bstrButtonText) = 0;
    virtual HRESULT WINAPI get_ButtonState(__LONG32 lButtonID,PHONE_BUTTON_STATE *pButtonState) = 0;
    virtual HRESULT WINAPI get_HookSwitchState(PHONE_HOOK_SWITCH_DEVICE HookSwitchDevice,PHONE_HOOK_SWITCH_STATE *pHookSwitchState) = 0;
    virtual HRESULT WINAPI put_HookSwitchState(PHONE_HOOK_SWITCH_DEVICE HookSwitchDevice,PHONE_HOOK_SWITCH_STATE HookSwitchState) = 0;
    virtual HRESULT WINAPI put_RingMode(__LONG32 lRingMode) = 0;
    virtual HRESULT WINAPI get_RingMode(__LONG32 *plRingMode) = 0;
    virtual HRESULT WINAPI put_RingVolume(__LONG32 lRingVolume) = 0;
    virtual HRESULT WINAPI get_RingVolume(__LONG32 *plRingVolume) = 0;
    virtual HRESULT WINAPI get_Privilege(PHONE_PRIVILEGE *pPrivilege) = 0;
    virtual HRESULT WINAPI GetPhoneCapsBuffer(PHONECAPS_BUFFER pcbCaps,DWORD *pdwSize,BYTE **ppPhoneCapsBuffer) = 0;
    virtual HRESULT WINAPI get_PhoneCapsBuffer(PHONECAPS_BUFFER pcbCaps,VARIANT *pVarBuffer) = 0;
    virtual HRESULT WINAPI get_LampMode(__LONG32 lLampID,PHONE_LAMP_MODE *pLampMode) = 0;
    virtual HRESULT WINAPI put_LampMode(__LONG32 lLampID,PHONE_LAMP_MODE LampMode) = 0;
    virtual HRESULT WINAPI get_Display(BSTR *pbstrDisplay) = 0;
    virtual HRESULT WINAPI SetDisplay(__LONG32 lRow,__LONG32 lColumn,BSTR bstrDisplay) = 0;
    virtual HRESULT WINAPI get_PreferredAddresses(VARIANT *pAddresses) = 0;
    virtual HRESULT WINAPI EnumeratePreferredAddresses(IEnumAddress **ppEnumAddress) = 0;
    virtual HRESULT WINAPI DeviceSpecific(BYTE *pParams,DWORD dwSize) = 0;
    virtual HRESULT WINAPI DeviceSpecificVariant(VARIANT varDevSpecificByteArray) = 0;
    virtual HRESULT WINAPI NegotiateExtVersion(__LONG32 lLowVersion,__LONG32 lHighVersion,__LONG32 *plExtVersion) = 0;
  };
#else
  typedef struct ITPhoneVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITPhone *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITPhone *This);
      ULONG (WINAPI *Release)(ITPhone *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITPhone *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITPhone *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITPhone *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITPhone *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Open)(ITPhone *This,PHONE_PRIVILEGE Privilege);
      HRESULT (WINAPI *Close)(ITPhone *This);
      HRESULT (WINAPI *get_Addresses)(ITPhone *This,VARIANT *pAddresses);
      HRESULT (WINAPI *EnumerateAddresses)(ITPhone *This,IEnumAddress **ppEnumAddress);
      HRESULT (WINAPI *get_PhoneCapsLong)(ITPhone *This,PHONECAPS_LONG pclCap,__LONG32 *plCapability);
      HRESULT (WINAPI *get_PhoneCapsString)(ITPhone *This,PHONECAPS_STRING pcsCap,BSTR *ppCapability);
      HRESULT (WINAPI *get_Terminals)(ITPhone *This,ITAddress *pAddress,VARIANT *pTerminals);
      HRESULT (WINAPI *EnumerateTerminals)(ITPhone *This,ITAddress *pAddress,IEnumTerminal **ppEnumTerminal);
      HRESULT (WINAPI *get_ButtonMode)(ITPhone *This,__LONG32 lButtonID,PHONE_BUTTON_MODE *pButtonMode);
      HRESULT (WINAPI *put_ButtonMode)(ITPhone *This,__LONG32 lButtonID,PHONE_BUTTON_MODE ButtonMode);
      HRESULT (WINAPI *get_ButtonFunction)(ITPhone *This,__LONG32 lButtonID,PHONE_BUTTON_FUNCTION *pButtonFunction);
      HRESULT (WINAPI *put_ButtonFunction)(ITPhone *This,__LONG32 lButtonID,PHONE_BUTTON_FUNCTION ButtonFunction);
      HRESULT (WINAPI *get_ButtonText)(ITPhone *This,__LONG32 lButtonID,BSTR *ppButtonText);
      HRESULT (WINAPI *put_ButtonText)(ITPhone *This,__LONG32 lButtonID,BSTR bstrButtonText);
      HRESULT (WINAPI *get_ButtonState)(ITPhone *This,__LONG32 lButtonID,PHONE_BUTTON_STATE *pButtonState);
      HRESULT (WINAPI *get_HookSwitchState)(ITPhone *This,PHONE_HOOK_SWITCH_DEVICE HookSwitchDevice,PHONE_HOOK_SWITCH_STATE *pHookSwitchState);
      HRESULT (WINAPI *put_HookSwitchState)(ITPhone *This,PHONE_HOOK_SWITCH_DEVICE HookSwitchDevice,PHONE_HOOK_SWITCH_STATE HookSwitchState);
      HRESULT (WINAPI *put_RingMode)(ITPhone *This,__LONG32 lRingMode);
      HRESULT (WINAPI *get_RingMode)(ITPhone *This,__LONG32 *plRingMode);
      HRESULT (WINAPI *put_RingVolume)(ITPhone *This,__LONG32 lRingVolume);
      HRESULT (WINAPI *get_RingVolume)(ITPhone *This,__LONG32 *plRingVolume);
      HRESULT (WINAPI *get_Privilege)(ITPhone *This,PHONE_PRIVILEGE *pPrivilege);
      HRESULT (WINAPI *GetPhoneCapsBuffer)(ITPhone *This,PHONECAPS_BUFFER pcbCaps,DWORD *pdwSize,BYTE **ppPhoneCapsBuffer);
      HRESULT (WINAPI *get_PhoneCapsBuffer)(ITPhone *This,PHONECAPS_BUFFER pcbCaps,VARIANT *pVarBuffer);
      HRESULT (WINAPI *get_LampMode)(ITPhone *This,__LONG32 lLampID,PHONE_LAMP_MODE *pLampMode);
      HRESULT (WINAPI *put_LampMode)(ITPhone *This,__LONG32 lLampID,PHONE_LAMP_MODE LampMode);
      HRESULT (WINAPI *get_Display)(ITPhone *This,BSTR *pbstrDisplay);
      HRESULT (WINAPI *SetDisplay)(ITPhone *This,__LONG32 lRow,__LONG32 lColumn,BSTR bstrDisplay);
      HRESULT (WINAPI *get_PreferredAddresses)(ITPhone *This,VARIANT *pAddresses);
      HRESULT (WINAPI *EnumeratePreferredAddresses)(ITPhone *This,IEnumAddress **ppEnumAddress);
      HRESULT (WINAPI *DeviceSpecific)(ITPhone *This,BYTE *pParams,DWORD dwSize);
      HRESULT (WINAPI *DeviceSpecificVariant)(ITPhone *This,VARIANT varDevSpecificByteArray);
      HRESULT (WINAPI *NegotiateExtVersion)(ITPhone *This,__LONG32 lLowVersion,__LONG32 lHighVersion,__LONG32 *plExtVersion);
    END_INTERFACE
  } ITPhoneVtbl;
  struct ITPhone {
    CONST_VTBL struct ITPhoneVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITPhone_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITPhone_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITPhone_Release(This) (This)->lpVtbl->Release(This)
#define ITPhone_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITPhone_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITPhone_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITPhone_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITPhone_Open(This,Privilege) (This)->lpVtbl->Open(This,Privilege)
#define ITPhone_Close(This) (This)->lpVtbl->Close(This)
#define ITPhone_get_Addresses(This,pAddresses) (This)->lpVtbl->get_Addresses(This,pAddresses)
#define ITPhone_EnumerateAddresses(This,ppEnumAddress) (This)->lpVtbl->EnumerateAddresses(This,ppEnumAddress)
#define ITPhone_get_PhoneCapsLong(This,pclCap,plCapability) (This)->lpVtbl->get_PhoneCapsLong(This,pclCap,plCapability)
#define ITPhone_get_PhoneCapsString(This,pcsCap,ppCapability) (This)->lpVtbl->get_PhoneCapsString(This,pcsCap,ppCapability)
#define ITPhone_get_Terminals(This,pAddress,pTerminals) (This)->lpVtbl->get_Terminals(This,pAddress,pTerminals)
#define ITPhone_EnumerateTerminals(This,pAddress,ppEnumTerminal) (This)->lpVtbl->EnumerateTerminals(This,pAddress,ppEnumTerminal)
#define ITPhone_get_ButtonMode(This,lButtonID,pButtonMode) (This)->lpVtbl->get_ButtonMode(This,lButtonID,pButtonMode)
#define ITPhone_put_ButtonMode(This,lButtonID,ButtonMode) (This)->lpVtbl->put_ButtonMode(This,lButtonID,ButtonMode)
#define ITPhone_get_ButtonFunction(This,lButtonID,pButtonFunction) (This)->lpVtbl->get_ButtonFunction(This,lButtonID,pButtonFunction)
#define ITPhone_put_ButtonFunction(This,lButtonID,ButtonFunction) (This)->lpVtbl->put_ButtonFunction(This,lButtonID,ButtonFunction)
#define ITPhone_get_ButtonText(This,lButtonID,ppButtonText) (This)->lpVtbl->get_ButtonText(This,lButtonID,ppButtonText)
#define ITPhone_put_ButtonText(This,lButtonID,bstrButtonText) (This)->lpVtbl->put_ButtonText(This,lButtonID,bstrButtonText)
#define ITPhone_get_ButtonState(This,lButtonID,pButtonState) (This)->lpVtbl->get_ButtonState(This,lButtonID,pButtonState)
#define ITPhone_get_HookSwitchState(This,HookSwitchDevice,pHookSwitchState) (This)->lpVtbl->get_HookSwitchState(This,HookSwitchDevice,pHookSwitchState)
#define ITPhone_put_HookSwitchState(This,HookSwitchDevice,HookSwitchState) (This)->lpVtbl->put_HookSwitchState(This,HookSwitchDevice,HookSwitchState)
#define ITPhone_put_RingMode(This,lRingMode) (This)->lpVtbl->put_RingMode(This,lRingMode)
#define ITPhone_get_RingMode(This,plRingMode) (This)->lpVtbl->get_RingMode(This,plRingMode)
#define ITPhone_put_RingVolume(This,lRingVolume) (This)->lpVtbl->put_RingVolume(This,lRingVolume)
#define ITPhone_get_RingVolume(This,plRingVolume) (This)->lpVtbl->get_RingVolume(This,plRingVolume)
#define ITPhone_get_Privilege(This,pPrivilege) (This)->lpVtbl->get_Privilege(This,pPrivilege)
#define ITPhone_GetPhoneCapsBuffer(This,pcbCaps,pdwSize,ppPhoneCapsBuffer) (This)->lpVtbl->GetPhoneCapsBuffer(This,pcbCaps,pdwSize,ppPhoneCapsBuffer)
#define ITPhone_get_PhoneCapsBuffer(This,pcbCaps,pVarBuffer) (This)->lpVtbl->get_PhoneCapsBuffer(This,pcbCaps,pVarBuffer)
#define ITPhone_get_LampMode(This,lLampID,pLampMode) (This)->lpVtbl->get_LampMode(This,lLampID,pLampMode)
#define ITPhone_put_LampMode(This,lLampID,LampMode) (This)->lpVtbl->put_LampMode(This,lLampID,LampMode)
#define ITPhone_get_Display(This,pbstrDisplay) (This)->lpVtbl->get_Display(This,pbstrDisplay)
#define ITPhone_SetDisplay(This,lRow,lColumn,bstrDisplay) (This)->lpVtbl->SetDisplay(This,lRow,lColumn,bstrDisplay)
#define ITPhone_get_PreferredAddresses(This,pAddresses) (This)->lpVtbl->get_PreferredAddresses(This,pAddresses)
#define ITPhone_EnumeratePreferredAddresses(This,ppEnumAddress) (This)->lpVtbl->EnumeratePreferredAddresses(This,ppEnumAddress)
#define ITPhone_DeviceSpecific(This,pParams,dwSize) (This)->lpVtbl->DeviceSpecific(This,pParams,dwSize)
#define ITPhone_DeviceSpecificVariant(This,varDevSpecificByteArray) (This)->lpVtbl->DeviceSpecificVariant(This,varDevSpecificByteArray)
#define ITPhone_NegotiateExtVersion(This,lLowVersion,lHighVersion,plExtVersion) (This)->lpVtbl->NegotiateExtVersion(This,lLowVersion,lHighVersion,plExtVersion)
#endif
#endif
  HRESULT WINAPI ITPhone_Open_Proxy(ITPhone *This,PHONE_PRIVILEGE Privilege);
  void __RPC_STUB ITPhone_Open_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_Close_Proxy(ITPhone *This);
  void __RPC_STUB ITPhone_Close_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_Addresses_Proxy(ITPhone *This,VARIANT *pAddresses);
  void __RPC_STUB ITPhone_get_Addresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_EnumerateAddresses_Proxy(ITPhone *This,IEnumAddress **ppEnumAddress);
  void __RPC_STUB ITPhone_EnumerateAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_PhoneCapsLong_Proxy(ITPhone *This,PHONECAPS_LONG pclCap,__LONG32 *plCapability);
  void __RPC_STUB ITPhone_get_PhoneCapsLong_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_PhoneCapsString_Proxy(ITPhone *This,PHONECAPS_STRING pcsCap,BSTR *ppCapability);
  void __RPC_STUB ITPhone_get_PhoneCapsString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_Terminals_Proxy(ITPhone *This,ITAddress *pAddress,VARIANT *pTerminals);
  void __RPC_STUB ITPhone_get_Terminals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_EnumerateTerminals_Proxy(ITPhone *This,ITAddress *pAddress,IEnumTerminal **ppEnumTerminal);
  void __RPC_STUB ITPhone_EnumerateTerminals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_ButtonMode_Proxy(ITPhone *This,__LONG32 lButtonID,PHONE_BUTTON_MODE *pButtonMode);
  void __RPC_STUB ITPhone_get_ButtonMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_put_ButtonMode_Proxy(ITPhone *This,__LONG32 lButtonID,PHONE_BUTTON_MODE ButtonMode);
  void __RPC_STUB ITPhone_put_ButtonMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_ButtonFunction_Proxy(ITPhone *This,__LONG32 lButtonID,PHONE_BUTTON_FUNCTION *pButtonFunction);
  void __RPC_STUB ITPhone_get_ButtonFunction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_put_ButtonFunction_Proxy(ITPhone *This,__LONG32 lButtonID,PHONE_BUTTON_FUNCTION ButtonFunction);
  void __RPC_STUB ITPhone_put_ButtonFunction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_ButtonText_Proxy(ITPhone *This,__LONG32 lButtonID,BSTR *ppButtonText);
  void __RPC_STUB ITPhone_get_ButtonText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_put_ButtonText_Proxy(ITPhone *This,__LONG32 lButtonID,BSTR bstrButtonText);
  void __RPC_STUB ITPhone_put_ButtonText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_ButtonState_Proxy(ITPhone *This,__LONG32 lButtonID,PHONE_BUTTON_STATE *pButtonState);
  void __RPC_STUB ITPhone_get_ButtonState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_HookSwitchState_Proxy(ITPhone *This,PHONE_HOOK_SWITCH_DEVICE HookSwitchDevice,PHONE_HOOK_SWITCH_STATE *pHookSwitchState);
  void __RPC_STUB ITPhone_get_HookSwitchState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_put_HookSwitchState_Proxy(ITPhone *This,PHONE_HOOK_SWITCH_DEVICE HookSwitchDevice,PHONE_HOOK_SWITCH_STATE HookSwitchState);
  void __RPC_STUB ITPhone_put_HookSwitchState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_put_RingMode_Proxy(ITPhone *This,__LONG32 lRingMode);
  void __RPC_STUB ITPhone_put_RingMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_RingMode_Proxy(ITPhone *This,__LONG32 *plRingMode);
  void __RPC_STUB ITPhone_get_RingMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_put_RingVolume_Proxy(ITPhone *This,__LONG32 lRingVolume);
  void __RPC_STUB ITPhone_put_RingVolume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_RingVolume_Proxy(ITPhone *This,__LONG32 *plRingVolume);
  void __RPC_STUB ITPhone_get_RingVolume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_Privilege_Proxy(ITPhone *This,PHONE_PRIVILEGE *pPrivilege);
  void __RPC_STUB ITPhone_get_Privilege_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_GetPhoneCapsBuffer_Proxy(ITPhone *This,PHONECAPS_BUFFER pcbCaps,DWORD *pdwSize,BYTE **ppPhoneCapsBuffer);
  void __RPC_STUB ITPhone_GetPhoneCapsBuffer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_PhoneCapsBuffer_Proxy(ITPhone *This,PHONECAPS_BUFFER pcbCaps,VARIANT *pVarBuffer);
  void __RPC_STUB ITPhone_get_PhoneCapsBuffer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_LampMode_Proxy(ITPhone *This,__LONG32 lLampID,PHONE_LAMP_MODE *pLampMode);
  void __RPC_STUB ITPhone_get_LampMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_put_LampMode_Proxy(ITPhone *This,__LONG32 lLampID,PHONE_LAMP_MODE LampMode);
  void __RPC_STUB ITPhone_put_LampMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_Display_Proxy(ITPhone *This,BSTR *pbstrDisplay);
  void __RPC_STUB ITPhone_get_Display_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_SetDisplay_Proxy(ITPhone *This,__LONG32 lRow,__LONG32 lColumn,BSTR bstrDisplay);
  void __RPC_STUB ITPhone_SetDisplay_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_get_PreferredAddresses_Proxy(ITPhone *This,VARIANT *pAddresses);
  void __RPC_STUB ITPhone_get_PreferredAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_EnumeratePreferredAddresses_Proxy(ITPhone *This,IEnumAddress **ppEnumAddress);
  void __RPC_STUB ITPhone_EnumeratePreferredAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_DeviceSpecific_Proxy(ITPhone *This,BYTE *pParams,DWORD dwSize);
  void __RPC_STUB ITPhone_DeviceSpecific_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_DeviceSpecificVariant_Proxy(ITPhone *This,VARIANT varDevSpecificByteArray);
  void __RPC_STUB ITPhone_DeviceSpecificVariant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhone_NegotiateExtVersion_Proxy(ITPhone *This,__LONG32 lLowVersion,__LONG32 lHighVersion,__LONG32 *plExtVersion);
  void __RPC_STUB ITPhone_NegotiateExtVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAutomatedPhoneControl_INTERFACE_DEFINED__
#define __ITAutomatedPhoneControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAutomatedPhoneControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAutomatedPhoneControl : public IDispatch {
  public:
    virtual HRESULT WINAPI StartTone(PHONE_TONE Tone,__LONG32 lDuration) = 0;
    virtual HRESULT WINAPI StopTone(void) = 0;
    virtual HRESULT WINAPI get_Tone(PHONE_TONE *pTone) = 0;
    virtual HRESULT WINAPI StartRinger(__LONG32 lRingMode,__LONG32 lDuration) = 0;
    virtual HRESULT WINAPI StopRinger(void) = 0;
    virtual HRESULT WINAPI get_Ringer(VARIANT_BOOL *pfRinging) = 0;
    virtual HRESULT WINAPI put_PhoneHandlingEnabled(VARIANT_BOOL fEnabled) = 0;
    virtual HRESULT WINAPI get_PhoneHandlingEnabled(VARIANT_BOOL *pfEnabled) = 0;
    virtual HRESULT WINAPI put_AutoEndOfNumberTimeout(__LONG32 lTimeout) = 0;
    virtual HRESULT WINAPI get_AutoEndOfNumberTimeout(__LONG32 *plTimeout) = 0;
    virtual HRESULT WINAPI put_AutoDialtone(VARIANT_BOOL fEnabled) = 0;
    virtual HRESULT WINAPI get_AutoDialtone(VARIANT_BOOL *pfEnabled) = 0;
    virtual HRESULT WINAPI put_AutoStopTonesOnOnHook(VARIANT_BOOL fEnabled) = 0;
    virtual HRESULT WINAPI get_AutoStopTonesOnOnHook(VARIANT_BOOL *pfEnabled) = 0;
    virtual HRESULT WINAPI put_AutoStopRingOnOffHook(VARIANT_BOOL fEnabled) = 0;
    virtual HRESULT WINAPI get_AutoStopRingOnOffHook(VARIANT_BOOL *pfEnabled) = 0;
    virtual HRESULT WINAPI put_AutoKeypadTones(VARIANT_BOOL fEnabled) = 0;
    virtual HRESULT WINAPI get_AutoKeypadTones(VARIANT_BOOL *pfEnabled) = 0;
    virtual HRESULT WINAPI put_AutoKeypadTonesMinimumDuration(__LONG32 lDuration) = 0;
    virtual HRESULT WINAPI get_AutoKeypadTonesMinimumDuration(__LONG32 *plDuration) = 0;
    virtual HRESULT WINAPI put_AutoVolumeControl(VARIANT_BOOL fEnabled) = 0;
    virtual HRESULT WINAPI get_AutoVolumeControl(VARIANT_BOOL *fEnabled) = 0;
    virtual HRESULT WINAPI put_AutoVolumeControlStep(__LONG32 lStepSize) = 0;
    virtual HRESULT WINAPI get_AutoVolumeControlStep(__LONG32 *plStepSize) = 0;
    virtual HRESULT WINAPI put_AutoVolumeControlRepeatDelay(__LONG32 lDelay) = 0;
    virtual HRESULT WINAPI get_AutoVolumeControlRepeatDelay(__LONG32 *plDelay) = 0;
    virtual HRESULT WINAPI put_AutoVolumeControlRepeatPeriod(__LONG32 lPeriod) = 0;
    virtual HRESULT WINAPI get_AutoVolumeControlRepeatPeriod(__LONG32 *plPeriod) = 0;
    virtual HRESULT WINAPI SelectCall(ITCallInfo *pCall,VARIANT_BOOL fSelectDefaultTerminals) = 0;
    virtual HRESULT WINAPI UnselectCall(ITCallInfo *pCall) = 0;
    virtual HRESULT WINAPI EnumerateSelectedCalls(IEnumCall **ppCallEnum) = 0;
    virtual HRESULT WINAPI get_SelectedCalls(VARIANT *pVariant) = 0;
  };
#else
  typedef struct ITAutomatedPhoneControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAutomatedPhoneControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAutomatedPhoneControl *This);
      ULONG (WINAPI *Release)(ITAutomatedPhoneControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAutomatedPhoneControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAutomatedPhoneControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAutomatedPhoneControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAutomatedPhoneControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *StartTone)(ITAutomatedPhoneControl *This,PHONE_TONE Tone,__LONG32 lDuration);
      HRESULT (WINAPI *StopTone)(ITAutomatedPhoneControl *This);
      HRESULT (WINAPI *get_Tone)(ITAutomatedPhoneControl *This,PHONE_TONE *pTone);
      HRESULT (WINAPI *StartRinger)(ITAutomatedPhoneControl *This,__LONG32 lRingMode,__LONG32 lDuration);
      HRESULT (WINAPI *StopRinger)(ITAutomatedPhoneControl *This);
      HRESULT (WINAPI *get_Ringer)(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfRinging);
      HRESULT (WINAPI *put_PhoneHandlingEnabled)(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
      HRESULT (WINAPI *get_PhoneHandlingEnabled)(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfEnabled);
      HRESULT (WINAPI *put_AutoEndOfNumberTimeout)(ITAutomatedPhoneControl *This,__LONG32 lTimeout);
      HRESULT (WINAPI *get_AutoEndOfNumberTimeout)(ITAutomatedPhoneControl *This,__LONG32 *plTimeout);
      HRESULT (WINAPI *put_AutoDialtone)(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
      HRESULT (WINAPI *get_AutoDialtone)(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfEnabled);
      HRESULT (WINAPI *put_AutoStopTonesOnOnHook)(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
      HRESULT (WINAPI *get_AutoStopTonesOnOnHook)(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfEnabled);
      HRESULT (WINAPI *put_AutoStopRingOnOffHook)(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
      HRESULT (WINAPI *get_AutoStopRingOnOffHook)(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfEnabled);
      HRESULT (WINAPI *put_AutoKeypadTones)(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
      HRESULT (WINAPI *get_AutoKeypadTones)(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfEnabled);
      HRESULT (WINAPI *put_AutoKeypadTonesMinimumDuration)(ITAutomatedPhoneControl *This,__LONG32 lDuration);
      HRESULT (WINAPI *get_AutoKeypadTonesMinimumDuration)(ITAutomatedPhoneControl *This,__LONG32 *plDuration);
      HRESULT (WINAPI *put_AutoVolumeControl)(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
      HRESULT (WINAPI *get_AutoVolumeControl)(ITAutomatedPhoneControl *This,VARIANT_BOOL *fEnabled);
      HRESULT (WINAPI *put_AutoVolumeControlStep)(ITAutomatedPhoneControl *This,__LONG32 lStepSize);
      HRESULT (WINAPI *get_AutoVolumeControlStep)(ITAutomatedPhoneControl *This,__LONG32 *plStepSize);
      HRESULT (WINAPI *put_AutoVolumeControlRepeatDelay)(ITAutomatedPhoneControl *This,__LONG32 lDelay);
      HRESULT (WINAPI *get_AutoVolumeControlRepeatDelay)(ITAutomatedPhoneControl *This,__LONG32 *plDelay);
      HRESULT (WINAPI *put_AutoVolumeControlRepeatPeriod)(ITAutomatedPhoneControl *This,__LONG32 lPeriod);
      HRESULT (WINAPI *get_AutoVolumeControlRepeatPeriod)(ITAutomatedPhoneControl *This,__LONG32 *plPeriod);
      HRESULT (WINAPI *SelectCall)(ITAutomatedPhoneControl *This,ITCallInfo *pCall,VARIANT_BOOL fSelectDefaultTerminals);
      HRESULT (WINAPI *UnselectCall)(ITAutomatedPhoneControl *This,ITCallInfo *pCall);
      HRESULT (WINAPI *EnumerateSelectedCalls)(ITAutomatedPhoneControl *This,IEnumCall **ppCallEnum);
      HRESULT (WINAPI *get_SelectedCalls)(ITAutomatedPhoneControl *This,VARIANT *pVariant);
    END_INTERFACE
  } ITAutomatedPhoneControlVtbl;
  struct ITAutomatedPhoneControl {
    CONST_VTBL struct ITAutomatedPhoneControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAutomatedPhoneControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAutomatedPhoneControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAutomatedPhoneControl_Release(This) (This)->lpVtbl->Release(This)
#define ITAutomatedPhoneControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAutomatedPhoneControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAutomatedPhoneControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAutomatedPhoneControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAutomatedPhoneControl_StartTone(This,Tone,lDuration) (This)->lpVtbl->StartTone(This,Tone,lDuration)
#define ITAutomatedPhoneControl_StopTone(This) (This)->lpVtbl->StopTone(This)
#define ITAutomatedPhoneControl_get_Tone(This,pTone) (This)->lpVtbl->get_Tone(This,pTone)
#define ITAutomatedPhoneControl_StartRinger(This,lRingMode,lDuration) (This)->lpVtbl->StartRinger(This,lRingMode,lDuration)
#define ITAutomatedPhoneControl_StopRinger(This) (This)->lpVtbl->StopRinger(This)
#define ITAutomatedPhoneControl_get_Ringer(This,pfRinging) (This)->lpVtbl->get_Ringer(This,pfRinging)
#define ITAutomatedPhoneControl_put_PhoneHandlingEnabled(This,fEnabled) (This)->lpVtbl->put_PhoneHandlingEnabled(This,fEnabled)
#define ITAutomatedPhoneControl_get_PhoneHandlingEnabled(This,pfEnabled) (This)->lpVtbl->get_PhoneHandlingEnabled(This,pfEnabled)
#define ITAutomatedPhoneControl_put_AutoEndOfNumberTimeout(This,lTimeout) (This)->lpVtbl->put_AutoEndOfNumberTimeout(This,lTimeout)
#define ITAutomatedPhoneControl_get_AutoEndOfNumberTimeout(This,plTimeout) (This)->lpVtbl->get_AutoEndOfNumberTimeout(This,plTimeout)
#define ITAutomatedPhoneControl_put_AutoDialtone(This,fEnabled) (This)->lpVtbl->put_AutoDialtone(This,fEnabled)
#define ITAutomatedPhoneControl_get_AutoDialtone(This,pfEnabled) (This)->lpVtbl->get_AutoDialtone(This,pfEnabled)
#define ITAutomatedPhoneControl_put_AutoStopTonesOnOnHook(This,fEnabled) (This)->lpVtbl->put_AutoStopTonesOnOnHook(This,fEnabled)
#define ITAutomatedPhoneControl_get_AutoStopTonesOnOnHook(This,pfEnabled) (This)->lpVtbl->get_AutoStopTonesOnOnHook(This,pfEnabled)
#define ITAutomatedPhoneControl_put_AutoStopRingOnOffHook(This,fEnabled) (This)->lpVtbl->put_AutoStopRingOnOffHook(This,fEnabled)
#define ITAutomatedPhoneControl_get_AutoStopRingOnOffHook(This,pfEnabled) (This)->lpVtbl->get_AutoStopRingOnOffHook(This,pfEnabled)
#define ITAutomatedPhoneControl_put_AutoKeypadTones(This,fEnabled) (This)->lpVtbl->put_AutoKeypadTones(This,fEnabled)
#define ITAutomatedPhoneControl_get_AutoKeypadTones(This,pfEnabled) (This)->lpVtbl->get_AutoKeypadTones(This,pfEnabled)
#define ITAutomatedPhoneControl_put_AutoKeypadTonesMinimumDuration(This,lDuration) (This)->lpVtbl->put_AutoKeypadTonesMinimumDuration(This,lDuration)
#define ITAutomatedPhoneControl_get_AutoKeypadTonesMinimumDuration(This,plDuration) (This)->lpVtbl->get_AutoKeypadTonesMinimumDuration(This,plDuration)
#define ITAutomatedPhoneControl_put_AutoVolumeControl(This,fEnabled) (This)->lpVtbl->put_AutoVolumeControl(This,fEnabled)
#define ITAutomatedPhoneControl_get_AutoVolumeControl(This,fEnabled) (This)->lpVtbl->get_AutoVolumeControl(This,fEnabled)
#define ITAutomatedPhoneControl_put_AutoVolumeControlStep(This,lStepSize) (This)->lpVtbl->put_AutoVolumeControlStep(This,lStepSize)
#define ITAutomatedPhoneControl_get_AutoVolumeControlStep(This,plStepSize) (This)->lpVtbl->get_AutoVolumeControlStep(This,plStepSize)
#define ITAutomatedPhoneControl_put_AutoVolumeControlRepeatDelay(This,lDelay) (This)->lpVtbl->put_AutoVolumeControlRepeatDelay(This,lDelay)
#define ITAutomatedPhoneControl_get_AutoVolumeControlRepeatDelay(This,plDelay) (This)->lpVtbl->get_AutoVolumeControlRepeatDelay(This,plDelay)
#define ITAutomatedPhoneControl_put_AutoVolumeControlRepeatPeriod(This,lPeriod) (This)->lpVtbl->put_AutoVolumeControlRepeatPeriod(This,lPeriod)
#define ITAutomatedPhoneControl_get_AutoVolumeControlRepeatPeriod(This,plPeriod) (This)->lpVtbl->get_AutoVolumeControlRepeatPeriod(This,plPeriod)
#define ITAutomatedPhoneControl_SelectCall(This,pCall,fSelectDefaultTerminals) (This)->lpVtbl->SelectCall(This,pCall,fSelectDefaultTerminals)
#define ITAutomatedPhoneControl_UnselectCall(This,pCall) (This)->lpVtbl->UnselectCall(This,pCall)
#define ITAutomatedPhoneControl_EnumerateSelectedCalls(This,ppCallEnum) (This)->lpVtbl->EnumerateSelectedCalls(This,ppCallEnum)
#define ITAutomatedPhoneControl_get_SelectedCalls(This,pVariant) (This)->lpVtbl->get_SelectedCalls(This,pVariant)
#endif
#endif
  HRESULT WINAPI ITAutomatedPhoneControl_StartTone_Proxy(ITAutomatedPhoneControl *This,PHONE_TONE Tone,__LONG32 lDuration);
  void __RPC_STUB ITAutomatedPhoneControl_StartTone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_StopTone_Proxy(ITAutomatedPhoneControl *This);
  void __RPC_STUB ITAutomatedPhoneControl_StopTone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_Tone_Proxy(ITAutomatedPhoneControl *This,PHONE_TONE *pTone);
  void __RPC_STUB ITAutomatedPhoneControl_get_Tone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_StartRinger_Proxy(ITAutomatedPhoneControl *This,__LONG32 lRingMode,__LONG32 lDuration);
  void __RPC_STUB ITAutomatedPhoneControl_StartRinger_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_StopRinger_Proxy(ITAutomatedPhoneControl *This);
  void __RPC_STUB ITAutomatedPhoneControl_StopRinger_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_Ringer_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfRinging);
  void __RPC_STUB ITAutomatedPhoneControl_get_Ringer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_put_PhoneHandlingEnabled_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_put_PhoneHandlingEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_PhoneHandlingEnabled_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_get_PhoneHandlingEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_put_AutoEndOfNumberTimeout_Proxy(ITAutomatedPhoneControl *This,__LONG32 lTimeout);
  void __RPC_STUB ITAutomatedPhoneControl_put_AutoEndOfNumberTimeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_AutoEndOfNumberTimeout_Proxy(ITAutomatedPhoneControl *This,__LONG32 *plTimeout);
  void __RPC_STUB ITAutomatedPhoneControl_get_AutoEndOfNumberTimeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_put_AutoDialtone_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_put_AutoDialtone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_AutoDialtone_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_get_AutoDialtone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_put_AutoStopTonesOnOnHook_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_put_AutoStopTonesOnOnHook_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_AutoStopTonesOnOnHook_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_get_AutoStopTonesOnOnHook_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_put_AutoStopRingOnOffHook_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_put_AutoStopRingOnOffHook_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_AutoStopRingOnOffHook_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_get_AutoStopRingOnOffHook_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_put_AutoKeypadTones_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_put_AutoKeypadTones_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_AutoKeypadTones_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL *pfEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_get_AutoKeypadTones_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_put_AutoKeypadTonesMinimumDuration_Proxy(ITAutomatedPhoneControl *This,__LONG32 lDuration);
  void __RPC_STUB ITAutomatedPhoneControl_put_AutoKeypadTonesMinimumDuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_AutoKeypadTonesMinimumDuration_Proxy(ITAutomatedPhoneControl *This,__LONG32 *plDuration);
  void __RPC_STUB ITAutomatedPhoneControl_get_AutoKeypadTonesMinimumDuration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_put_AutoVolumeControl_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL fEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_put_AutoVolumeControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_AutoVolumeControl_Proxy(ITAutomatedPhoneControl *This,VARIANT_BOOL *fEnabled);
  void __RPC_STUB ITAutomatedPhoneControl_get_AutoVolumeControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_put_AutoVolumeControlStep_Proxy(ITAutomatedPhoneControl *This,__LONG32 lStepSize);
  void __RPC_STUB ITAutomatedPhoneControl_put_AutoVolumeControlStep_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_AutoVolumeControlStep_Proxy(ITAutomatedPhoneControl *This,__LONG32 *plStepSize);
  void __RPC_STUB ITAutomatedPhoneControl_get_AutoVolumeControlStep_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_put_AutoVolumeControlRepeatDelay_Proxy(ITAutomatedPhoneControl *This,__LONG32 lDelay);
  void __RPC_STUB ITAutomatedPhoneControl_put_AutoVolumeControlRepeatDelay_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_AutoVolumeControlRepeatDelay_Proxy(ITAutomatedPhoneControl *This,__LONG32 *plDelay);
  void __RPC_STUB ITAutomatedPhoneControl_get_AutoVolumeControlRepeatDelay_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_put_AutoVolumeControlRepeatPeriod_Proxy(ITAutomatedPhoneControl *This,__LONG32 lPeriod);
  void __RPC_STUB ITAutomatedPhoneControl_put_AutoVolumeControlRepeatPeriod_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_AutoVolumeControlRepeatPeriod_Proxy(ITAutomatedPhoneControl *This,__LONG32 *plPeriod);
  void __RPC_STUB ITAutomatedPhoneControl_get_AutoVolumeControlRepeatPeriod_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_SelectCall_Proxy(ITAutomatedPhoneControl *This,ITCallInfo *pCall,VARIANT_BOOL fSelectDefaultTerminals);
  void __RPC_STUB ITAutomatedPhoneControl_SelectCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_UnselectCall_Proxy(ITAutomatedPhoneControl *This,ITCallInfo *pCall);
  void __RPC_STUB ITAutomatedPhoneControl_UnselectCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_EnumerateSelectedCalls_Proxy(ITAutomatedPhoneControl *This,IEnumCall **ppCallEnum);
  void __RPC_STUB ITAutomatedPhoneControl_EnumerateSelectedCalls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAutomatedPhoneControl_get_SelectedCalls_Proxy(ITAutomatedPhoneControl *This,VARIANT *pVariant);
  void __RPC_STUB ITAutomatedPhoneControl_get_SelectedCalls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITBasicCallControl_INTERFACE_DEFINED__
#define __ITBasicCallControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITBasicCallControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITBasicCallControl : public IDispatch {
  public:
    virtual HRESULT WINAPI Connect(VARIANT_BOOL fSync) = 0;
    virtual HRESULT WINAPI Answer(void) = 0;
    virtual HRESULT WINAPI Disconnect(DISCONNECT_CODE code) = 0;
    virtual HRESULT WINAPI Hold(VARIANT_BOOL fHold) = 0;
    virtual HRESULT WINAPI HandoffDirect(BSTR pApplicationName) = 0;
    virtual HRESULT WINAPI HandoffIndirect(__LONG32 lMediaType) = 0;
    virtual HRESULT WINAPI Conference(ITBasicCallControl *pCall,VARIANT_BOOL fSync) = 0;
    virtual HRESULT WINAPI Transfer(ITBasicCallControl *pCall,VARIANT_BOOL fSync) = 0;
    virtual HRESULT WINAPI BlindTransfer(BSTR pDestAddress) = 0;
    virtual HRESULT WINAPI SwapHold(ITBasicCallControl *pCall) = 0;
    virtual HRESULT WINAPI ParkDirect(BSTR pParkAddress) = 0;
    virtual HRESULT WINAPI ParkIndirect(BSTR *ppNonDirAddress) = 0;
    virtual HRESULT WINAPI Unpark(void) = 0;
    virtual HRESULT WINAPI SetQOS(__LONG32 lMediaType,QOS_SERVICE_LEVEL ServiceLevel) = 0;
    virtual HRESULT WINAPI Pickup(BSTR pGroupID) = 0;
    virtual HRESULT WINAPI Dial(BSTR pDestAddress) = 0;
    virtual HRESULT WINAPI Finish(FINISH_MODE finishMode) = 0;
    virtual HRESULT WINAPI RemoveFromConference(void) = 0;
  };
#else
  typedef struct ITBasicCallControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITBasicCallControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITBasicCallControl *This);
      ULONG (WINAPI *Release)(ITBasicCallControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITBasicCallControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITBasicCallControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITBasicCallControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITBasicCallControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Connect)(ITBasicCallControl *This,VARIANT_BOOL fSync);
      HRESULT (WINAPI *Answer)(ITBasicCallControl *This);
      HRESULT (WINAPI *Disconnect)(ITBasicCallControl *This,DISCONNECT_CODE code);
      HRESULT (WINAPI *Hold)(ITBasicCallControl *This,VARIANT_BOOL fHold);
      HRESULT (WINAPI *HandoffDirect)(ITBasicCallControl *This,BSTR pApplicationName);
      HRESULT (WINAPI *HandoffIndirect)(ITBasicCallControl *This,__LONG32 lMediaType);
      HRESULT (WINAPI *Conference)(ITBasicCallControl *This,ITBasicCallControl *pCall,VARIANT_BOOL fSync);
      HRESULT (WINAPI *Transfer)(ITBasicCallControl *This,ITBasicCallControl *pCall,VARIANT_BOOL fSync);
      HRESULT (WINAPI *BlindTransfer)(ITBasicCallControl *This,BSTR pDestAddress);
      HRESULT (WINAPI *SwapHold)(ITBasicCallControl *This,ITBasicCallControl *pCall);
      HRESULT (WINAPI *ParkDirect)(ITBasicCallControl *This,BSTR pParkAddress);
      HRESULT (WINAPI *ParkIndirect)(ITBasicCallControl *This,BSTR *ppNonDirAddress);
      HRESULT (WINAPI *Unpark)(ITBasicCallControl *This);
      HRESULT (WINAPI *SetQOS)(ITBasicCallControl *This,__LONG32 lMediaType,QOS_SERVICE_LEVEL ServiceLevel);
      HRESULT (WINAPI *Pickup)(ITBasicCallControl *This,BSTR pGroupID);
      HRESULT (WINAPI *Dial)(ITBasicCallControl *This,BSTR pDestAddress);
      HRESULT (WINAPI *Finish)(ITBasicCallControl *This,FINISH_MODE finishMode);
      HRESULT (WINAPI *RemoveFromConference)(ITBasicCallControl *This);
    END_INTERFACE
  } ITBasicCallControlVtbl;
  struct ITBasicCallControl {
    CONST_VTBL struct ITBasicCallControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITBasicCallControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITBasicCallControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITBasicCallControl_Release(This) (This)->lpVtbl->Release(This)
#define ITBasicCallControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITBasicCallControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITBasicCallControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITBasicCallControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITBasicCallControl_Connect(This,fSync) (This)->lpVtbl->Connect(This,fSync)
#define ITBasicCallControl_Answer(This) (This)->lpVtbl->Answer(This)
#define ITBasicCallControl_Disconnect(This,code) (This)->lpVtbl->Disconnect(This,code)
#define ITBasicCallControl_Hold(This,fHold) (This)->lpVtbl->Hold(This,fHold)
#define ITBasicCallControl_HandoffDirect(This,pApplicationName) (This)->lpVtbl->HandoffDirect(This,pApplicationName)
#define ITBasicCallControl_HandoffIndirect(This,lMediaType) (This)->lpVtbl->HandoffIndirect(This,lMediaType)
#define ITBasicCallControl_Conference(This,pCall,fSync) (This)->lpVtbl->Conference(This,pCall,fSync)
#define ITBasicCallControl_Transfer(This,pCall,fSync) (This)->lpVtbl->Transfer(This,pCall,fSync)
#define ITBasicCallControl_BlindTransfer(This,pDestAddress) (This)->lpVtbl->BlindTransfer(This,pDestAddress)
#define ITBasicCallControl_SwapHold(This,pCall) (This)->lpVtbl->SwapHold(This,pCall)
#define ITBasicCallControl_ParkDirect(This,pParkAddress) (This)->lpVtbl->ParkDirect(This,pParkAddress)
#define ITBasicCallControl_ParkIndirect(This,ppNonDirAddress) (This)->lpVtbl->ParkIndirect(This,ppNonDirAddress)
#define ITBasicCallControl_Unpark(This) (This)->lpVtbl->Unpark(This)
#define ITBasicCallControl_SetQOS(This,lMediaType,ServiceLevel) (This)->lpVtbl->SetQOS(This,lMediaType,ServiceLevel)
#define ITBasicCallControl_Pickup(This,pGroupID) (This)->lpVtbl->Pickup(This,pGroupID)
#define ITBasicCallControl_Dial(This,pDestAddress) (This)->lpVtbl->Dial(This,pDestAddress)
#define ITBasicCallControl_Finish(This,finishMode) (This)->lpVtbl->Finish(This,finishMode)
#define ITBasicCallControl_RemoveFromConference(This) (This)->lpVtbl->RemoveFromConference(This)
#endif
#endif
  HRESULT WINAPI ITBasicCallControl_Connect_Proxy(ITBasicCallControl *This,VARIANT_BOOL fSync);
  void __RPC_STUB ITBasicCallControl_Connect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_Answer_Proxy(ITBasicCallControl *This);
  void __RPC_STUB ITBasicCallControl_Answer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_Disconnect_Proxy(ITBasicCallControl *This,DISCONNECT_CODE code);
  void __RPC_STUB ITBasicCallControl_Disconnect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_Hold_Proxy(ITBasicCallControl *This,VARIANT_BOOL fHold);
  void __RPC_STUB ITBasicCallControl_Hold_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_HandoffDirect_Proxy(ITBasicCallControl *This,BSTR pApplicationName);
  void __RPC_STUB ITBasicCallControl_HandoffDirect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_HandoffIndirect_Proxy(ITBasicCallControl *This,__LONG32 lMediaType);
  void __RPC_STUB ITBasicCallControl_HandoffIndirect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_Conference_Proxy(ITBasicCallControl *This,ITBasicCallControl *pCall,VARIANT_BOOL fSync);
  void __RPC_STUB ITBasicCallControl_Conference_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_Transfer_Proxy(ITBasicCallControl *This,ITBasicCallControl *pCall,VARIANT_BOOL fSync);
  void __RPC_STUB ITBasicCallControl_Transfer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_BlindTransfer_Proxy(ITBasicCallControl *This,BSTR pDestAddress);
  void __RPC_STUB ITBasicCallControl_BlindTransfer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_SwapHold_Proxy(ITBasicCallControl *This,ITBasicCallControl *pCall);
  void __RPC_STUB ITBasicCallControl_SwapHold_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_ParkDirect_Proxy(ITBasicCallControl *This,BSTR pParkAddress);
  void __RPC_STUB ITBasicCallControl_ParkDirect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_ParkIndirect_Proxy(ITBasicCallControl *This,BSTR *ppNonDirAddress);
  void __RPC_STUB ITBasicCallControl_ParkIndirect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_Unpark_Proxy(ITBasicCallControl *This);
  void __RPC_STUB ITBasicCallControl_Unpark_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_SetQOS_Proxy(ITBasicCallControl *This,__LONG32 lMediaType,QOS_SERVICE_LEVEL ServiceLevel);
  void __RPC_STUB ITBasicCallControl_SetQOS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_Pickup_Proxy(ITBasicCallControl *This,BSTR pGroupID);
  void __RPC_STUB ITBasicCallControl_Pickup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_Dial_Proxy(ITBasicCallControl *This,BSTR pDestAddress);
  void __RPC_STUB ITBasicCallControl_Dial_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_Finish_Proxy(ITBasicCallControl *This,FINISH_MODE finishMode);
  void __RPC_STUB ITBasicCallControl_Finish_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl_RemoveFromConference_Proxy(ITBasicCallControl *This);
  void __RPC_STUB ITBasicCallControl_RemoveFromConference_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCallInfo_INTERFACE_DEFINED__
#define __ITCallInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCallInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCallInfo : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Address(ITAddress **ppAddress) = 0;
    virtual HRESULT WINAPI get_CallState(CALL_STATE *pCallState) = 0;
    virtual HRESULT WINAPI get_Privilege(CALL_PRIVILEGE *pPrivilege) = 0;
    virtual HRESULT WINAPI get_CallHub(ITCallHub **ppCallHub) = 0;
    virtual HRESULT WINAPI get_CallInfoLong(CALLINFO_LONG CallInfoLong,__LONG32 *plCallInfoLongVal) = 0;
    virtual HRESULT WINAPI put_CallInfoLong(CALLINFO_LONG CallInfoLong,__LONG32 lCallInfoLongVal) = 0;
    virtual HRESULT WINAPI get_CallInfoString(CALLINFO_STRING CallInfoString,BSTR *ppCallInfoString) = 0;
    virtual HRESULT WINAPI put_CallInfoString(CALLINFO_STRING CallInfoString,BSTR pCallInfoString) = 0;
    virtual HRESULT WINAPI get_CallInfoBuffer(CALLINFO_BUFFER CallInfoBuffer,VARIANT *ppCallInfoBuffer) = 0;
    virtual HRESULT WINAPI put_CallInfoBuffer(CALLINFO_BUFFER CallInfoBuffer,VARIANT pCallInfoBuffer) = 0;
    virtual HRESULT WINAPI GetCallInfoBuffer(CALLINFO_BUFFER CallInfoBuffer,DWORD *pdwSize,BYTE **ppCallInfoBuffer) = 0;
    virtual HRESULT WINAPI SetCallInfoBuffer(CALLINFO_BUFFER CallInfoBuffer,DWORD dwSize,BYTE *pCallInfoBuffer) = 0;
    virtual HRESULT WINAPI ReleaseUserUserInfo(void) = 0;
  };
#else
  typedef struct ITCallInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCallInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCallInfo *This);
      ULONG (WINAPI *Release)(ITCallInfo *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCallInfo *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCallInfo *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCallInfo *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCallInfo *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Address)(ITCallInfo *This,ITAddress **ppAddress);
      HRESULT (WINAPI *get_CallState)(ITCallInfo *This,CALL_STATE *pCallState);
      HRESULT (WINAPI *get_Privilege)(ITCallInfo *This,CALL_PRIVILEGE *pPrivilege);
      HRESULT (WINAPI *get_CallHub)(ITCallInfo *This,ITCallHub **ppCallHub);
      HRESULT (WINAPI *get_CallInfoLong)(ITCallInfo *This,CALLINFO_LONG CallInfoLong,__LONG32 *plCallInfoLongVal);
      HRESULT (WINAPI *put_CallInfoLong)(ITCallInfo *This,CALLINFO_LONG CallInfoLong,__LONG32 lCallInfoLongVal);
      HRESULT (WINAPI *get_CallInfoString)(ITCallInfo *This,CALLINFO_STRING CallInfoString,BSTR *ppCallInfoString);
      HRESULT (WINAPI *put_CallInfoString)(ITCallInfo *This,CALLINFO_STRING CallInfoString,BSTR pCallInfoString);
      HRESULT (WINAPI *get_CallInfoBuffer)(ITCallInfo *This,CALLINFO_BUFFER CallInfoBuffer,VARIANT *ppCallInfoBuffer);
      HRESULT (WINAPI *put_CallInfoBuffer)(ITCallInfo *This,CALLINFO_BUFFER CallInfoBuffer,VARIANT pCallInfoBuffer);
      HRESULT (WINAPI *GetCallInfoBuffer)(ITCallInfo *This,CALLINFO_BUFFER CallInfoBuffer,DWORD *pdwSize,BYTE **ppCallInfoBuffer);
      HRESULT (WINAPI *SetCallInfoBuffer)(ITCallInfo *This,CALLINFO_BUFFER CallInfoBuffer,DWORD dwSize,BYTE *pCallInfoBuffer);
      HRESULT (WINAPI *ReleaseUserUserInfo)(ITCallInfo *This);
    END_INTERFACE
  } ITCallInfoVtbl;
  struct ITCallInfo {
    CONST_VTBL struct ITCallInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCallInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCallInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCallInfo_Release(This) (This)->lpVtbl->Release(This)
#define ITCallInfo_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCallInfo_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCallInfo_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCallInfo_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCallInfo_get_Address(This,ppAddress) (This)->lpVtbl->get_Address(This,ppAddress)
#define ITCallInfo_get_CallState(This,pCallState) (This)->lpVtbl->get_CallState(This,pCallState)
#define ITCallInfo_get_Privilege(This,pPrivilege) (This)->lpVtbl->get_Privilege(This,pPrivilege)
#define ITCallInfo_get_CallHub(This,ppCallHub) (This)->lpVtbl->get_CallHub(This,ppCallHub)
#define ITCallInfo_get_CallInfoLong(This,CallInfoLong,plCallInfoLongVal) (This)->lpVtbl->get_CallInfoLong(This,CallInfoLong,plCallInfoLongVal)
#define ITCallInfo_put_CallInfoLong(This,CallInfoLong,lCallInfoLongVal) (This)->lpVtbl->put_CallInfoLong(This,CallInfoLong,lCallInfoLongVal)
#define ITCallInfo_get_CallInfoString(This,CallInfoString,ppCallInfoString) (This)->lpVtbl->get_CallInfoString(This,CallInfoString,ppCallInfoString)
#define ITCallInfo_put_CallInfoString(This,CallInfoString,pCallInfoString) (This)->lpVtbl->put_CallInfoString(This,CallInfoString,pCallInfoString)
#define ITCallInfo_get_CallInfoBuffer(This,CallInfoBuffer,ppCallInfoBuffer) (This)->lpVtbl->get_CallInfoBuffer(This,CallInfoBuffer,ppCallInfoBuffer)
#define ITCallInfo_put_CallInfoBuffer(This,CallInfoBuffer,pCallInfoBuffer) (This)->lpVtbl->put_CallInfoBuffer(This,CallInfoBuffer,pCallInfoBuffer)
#define ITCallInfo_GetCallInfoBuffer(This,CallInfoBuffer,pdwSize,ppCallInfoBuffer) (This)->lpVtbl->GetCallInfoBuffer(This,CallInfoBuffer,pdwSize,ppCallInfoBuffer)
#define ITCallInfo_SetCallInfoBuffer(This,CallInfoBuffer,dwSize,pCallInfoBuffer) (This)->lpVtbl->SetCallInfoBuffer(This,CallInfoBuffer,dwSize,pCallInfoBuffer)
#define ITCallInfo_ReleaseUserUserInfo(This) (This)->lpVtbl->ReleaseUserUserInfo(This)
#endif
#endif
  HRESULT WINAPI ITCallInfo_get_Address_Proxy(ITCallInfo *This,ITAddress **ppAddress);
  void __RPC_STUB ITCallInfo_get_Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_get_CallState_Proxy(ITCallInfo *This,CALL_STATE *pCallState);
  void __RPC_STUB ITCallInfo_get_CallState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_get_Privilege_Proxy(ITCallInfo *This,CALL_PRIVILEGE *pPrivilege);
  void __RPC_STUB ITCallInfo_get_Privilege_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_get_CallHub_Proxy(ITCallInfo *This,ITCallHub **ppCallHub);
  void __RPC_STUB ITCallInfo_get_CallHub_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_get_CallInfoLong_Proxy(ITCallInfo *This,CALLINFO_LONG CallInfoLong,__LONG32 *plCallInfoLongVal);
  void __RPC_STUB ITCallInfo_get_CallInfoLong_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_put_CallInfoLong_Proxy(ITCallInfo *This,CALLINFO_LONG CallInfoLong,__LONG32 lCallInfoLongVal);
  void __RPC_STUB ITCallInfo_put_CallInfoLong_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_get_CallInfoString_Proxy(ITCallInfo *This,CALLINFO_STRING CallInfoString,BSTR *ppCallInfoString);
  void __RPC_STUB ITCallInfo_get_CallInfoString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_put_CallInfoString_Proxy(ITCallInfo *This,CALLINFO_STRING CallInfoString,BSTR pCallInfoString);
  void __RPC_STUB ITCallInfo_put_CallInfoString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_get_CallInfoBuffer_Proxy(ITCallInfo *This,CALLINFO_BUFFER CallInfoBuffer,VARIANT *ppCallInfoBuffer);
  void __RPC_STUB ITCallInfo_get_CallInfoBuffer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_put_CallInfoBuffer_Proxy(ITCallInfo *This,CALLINFO_BUFFER CallInfoBuffer,VARIANT pCallInfoBuffer);
  void __RPC_STUB ITCallInfo_put_CallInfoBuffer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_GetCallInfoBuffer_Proxy(ITCallInfo *This,CALLINFO_BUFFER CallInfoBuffer,DWORD *pdwSize,BYTE **ppCallInfoBuffer);
  void __RPC_STUB ITCallInfo_GetCallInfoBuffer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_SetCallInfoBuffer_Proxy(ITCallInfo *This,CALLINFO_BUFFER CallInfoBuffer,DWORD dwSize,BYTE *pCallInfoBuffer);
  void __RPC_STUB ITCallInfo_SetCallInfoBuffer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo_ReleaseUserUserInfo_Proxy(ITCallInfo *This);
  void __RPC_STUB ITCallInfo_ReleaseUserUserInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCallInfo2_INTERFACE_DEFINED__
#define __ITCallInfo2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCallInfo2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCallInfo2 : public ITCallInfo {
  public:
    virtual HRESULT WINAPI get_EventFilter(TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL *pEnable) = 0;
    virtual HRESULT WINAPI put_EventFilter(TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL bEnable) = 0;
  };
#else
  typedef struct ITCallInfo2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCallInfo2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCallInfo2 *This);
      ULONG (WINAPI *Release)(ITCallInfo2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCallInfo2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCallInfo2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCallInfo2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCallInfo2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Address)(ITCallInfo2 *This,ITAddress **ppAddress);
      HRESULT (WINAPI *get_CallState)(ITCallInfo2 *This,CALL_STATE *pCallState);
      HRESULT (WINAPI *get_Privilege)(ITCallInfo2 *This,CALL_PRIVILEGE *pPrivilege);
      HRESULT (WINAPI *get_CallHub)(ITCallInfo2 *This,ITCallHub **ppCallHub);
      HRESULT (WINAPI *get_CallInfoLong)(ITCallInfo2 *This,CALLINFO_LONG CallInfoLong,__LONG32 *plCallInfoLongVal);
      HRESULT (WINAPI *put_CallInfoLong)(ITCallInfo2 *This,CALLINFO_LONG CallInfoLong,__LONG32 lCallInfoLongVal);
      HRESULT (WINAPI *get_CallInfoString)(ITCallInfo2 *This,CALLINFO_STRING CallInfoString,BSTR *ppCallInfoString);
      HRESULT (WINAPI *put_CallInfoString)(ITCallInfo2 *This,CALLINFO_STRING CallInfoString,BSTR pCallInfoString);
      HRESULT (WINAPI *get_CallInfoBuffer)(ITCallInfo2 *This,CALLINFO_BUFFER CallInfoBuffer,VARIANT *ppCallInfoBuffer);
      HRESULT (WINAPI *put_CallInfoBuffer)(ITCallInfo2 *This,CALLINFO_BUFFER CallInfoBuffer,VARIANT pCallInfoBuffer);
      HRESULT (WINAPI *GetCallInfoBuffer)(ITCallInfo2 *This,CALLINFO_BUFFER CallInfoBuffer,DWORD *pdwSize,BYTE **ppCallInfoBuffer);
      HRESULT (WINAPI *SetCallInfoBuffer)(ITCallInfo2 *This,CALLINFO_BUFFER CallInfoBuffer,DWORD dwSize,BYTE *pCallInfoBuffer);
      HRESULT (WINAPI *ReleaseUserUserInfo)(ITCallInfo2 *This);
      HRESULT (WINAPI *get_EventFilter)(ITCallInfo2 *This,TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL *pEnable);
      HRESULT (WINAPI *put_EventFilter)(ITCallInfo2 *This,TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL bEnable);
    END_INTERFACE
  } ITCallInfo2Vtbl;
  struct ITCallInfo2 {
    CONST_VTBL struct ITCallInfo2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCallInfo2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCallInfo2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCallInfo2_Release(This) (This)->lpVtbl->Release(This)
#define ITCallInfo2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCallInfo2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCallInfo2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCallInfo2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCallInfo2_get_Address(This,ppAddress) (This)->lpVtbl->get_Address(This,ppAddress)
#define ITCallInfo2_get_CallState(This,pCallState) (This)->lpVtbl->get_CallState(This,pCallState)
#define ITCallInfo2_get_Privilege(This,pPrivilege) (This)->lpVtbl->get_Privilege(This,pPrivilege)
#define ITCallInfo2_get_CallHub(This,ppCallHub) (This)->lpVtbl->get_CallHub(This,ppCallHub)
#define ITCallInfo2_get_CallInfoLong(This,CallInfoLong,plCallInfoLongVal) (This)->lpVtbl->get_CallInfoLong(This,CallInfoLong,plCallInfoLongVal)
#define ITCallInfo2_put_CallInfoLong(This,CallInfoLong,lCallInfoLongVal) (This)->lpVtbl->put_CallInfoLong(This,CallInfoLong,lCallInfoLongVal)
#define ITCallInfo2_get_CallInfoString(This,CallInfoString,ppCallInfoString) (This)->lpVtbl->get_CallInfoString(This,CallInfoString,ppCallInfoString)
#define ITCallInfo2_put_CallInfoString(This,CallInfoString,pCallInfoString) (This)->lpVtbl->put_CallInfoString(This,CallInfoString,pCallInfoString)
#define ITCallInfo2_get_CallInfoBuffer(This,CallInfoBuffer,ppCallInfoBuffer) (This)->lpVtbl->get_CallInfoBuffer(This,CallInfoBuffer,ppCallInfoBuffer)
#define ITCallInfo2_put_CallInfoBuffer(This,CallInfoBuffer,pCallInfoBuffer) (This)->lpVtbl->put_CallInfoBuffer(This,CallInfoBuffer,pCallInfoBuffer)
#define ITCallInfo2_GetCallInfoBuffer(This,CallInfoBuffer,pdwSize,ppCallInfoBuffer) (This)->lpVtbl->GetCallInfoBuffer(This,CallInfoBuffer,pdwSize,ppCallInfoBuffer)
#define ITCallInfo2_SetCallInfoBuffer(This,CallInfoBuffer,dwSize,pCallInfoBuffer) (This)->lpVtbl->SetCallInfoBuffer(This,CallInfoBuffer,dwSize,pCallInfoBuffer)
#define ITCallInfo2_ReleaseUserUserInfo(This) (This)->lpVtbl->ReleaseUserUserInfo(This)
#define ITCallInfo2_get_EventFilter(This,TapiEvent,lSubEvent,pEnable) (This)->lpVtbl->get_EventFilter(This,TapiEvent,lSubEvent,pEnable)
#define ITCallInfo2_put_EventFilter(This,TapiEvent,lSubEvent,bEnable) (This)->lpVtbl->put_EventFilter(This,TapiEvent,lSubEvent,bEnable)
#endif
#endif
  HRESULT WINAPI ITCallInfo2_get_EventFilter_Proxy(ITCallInfo2 *This,TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL *pEnable);
  void __RPC_STUB ITCallInfo2_get_EventFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfo2_put_EventFilter_Proxy(ITCallInfo2 *This,TAPI_EVENT TapiEvent,__LONG32 lSubEvent,VARIANT_BOOL bEnable);
  void __RPC_STUB ITCallInfo2_put_EventFilter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTerminal_INTERFACE_DEFINED__
#define __ITTerminal_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTerminal;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTerminal : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *ppName) = 0;
    virtual HRESULT WINAPI get_State(TERMINAL_STATE *pTerminalState) = 0;
    virtual HRESULT WINAPI get_TerminalType(TERMINAL_TYPE *pType) = 0;
    virtual HRESULT WINAPI get_TerminalClass(BSTR *ppTerminalClass) = 0;
    virtual HRESULT WINAPI get_MediaType(__LONG32 *plMediaType) = 0;
    virtual HRESULT WINAPI get_Direction(TERMINAL_DIRECTION *pDirection) = 0;
  };
#else
  typedef struct ITTerminalVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTerminal *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTerminal *This);
      ULONG (WINAPI *Release)(ITTerminal *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTerminal *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTerminal *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTerminal *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTerminal *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(ITTerminal *This,BSTR *ppName);
      HRESULT (WINAPI *get_State)(ITTerminal *This,TERMINAL_STATE *pTerminalState);
      HRESULT (WINAPI *get_TerminalType)(ITTerminal *This,TERMINAL_TYPE *pType);
      HRESULT (WINAPI *get_TerminalClass)(ITTerminal *This,BSTR *ppTerminalClass);
      HRESULT (WINAPI *get_MediaType)(ITTerminal *This,__LONG32 *plMediaType);
      HRESULT (WINAPI *get_Direction)(ITTerminal *This,TERMINAL_DIRECTION *pDirection);
    END_INTERFACE
  } ITTerminalVtbl;
  struct ITTerminal {
    CONST_VTBL struct ITTerminalVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTerminal_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTerminal_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTerminal_Release(This) (This)->lpVtbl->Release(This)
#define ITTerminal_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTerminal_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTerminal_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTerminal_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITTerminal_get_Name(This,ppName) (This)->lpVtbl->get_Name(This,ppName)
#define ITTerminal_get_State(This,pTerminalState) (This)->lpVtbl->get_State(This,pTerminalState)
#define ITTerminal_get_TerminalType(This,pType) (This)->lpVtbl->get_TerminalType(This,pType)
#define ITTerminal_get_TerminalClass(This,ppTerminalClass) (This)->lpVtbl->get_TerminalClass(This,ppTerminalClass)
#define ITTerminal_get_MediaType(This,plMediaType) (This)->lpVtbl->get_MediaType(This,plMediaType)
#define ITTerminal_get_Direction(This,pDirection) (This)->lpVtbl->get_Direction(This,pDirection)
#endif
#endif
  HRESULT WINAPI ITTerminal_get_Name_Proxy(ITTerminal *This,BSTR *ppName);
  void __RPC_STUB ITTerminal_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminal_get_State_Proxy(ITTerminal *This,TERMINAL_STATE *pTerminalState);
  void __RPC_STUB ITTerminal_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminal_get_TerminalType_Proxy(ITTerminal *This,TERMINAL_TYPE *pType);
  void __RPC_STUB ITTerminal_get_TerminalType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminal_get_TerminalClass_Proxy(ITTerminal *This,BSTR *ppTerminalClass);
  void __RPC_STUB ITTerminal_get_TerminalClass_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminal_get_MediaType_Proxy(ITTerminal *This,__LONG32 *plMediaType);
  void __RPC_STUB ITTerminal_get_MediaType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTerminal_get_Direction_Proxy(ITTerminal *This,TERMINAL_DIRECTION *pDirection);
  void __RPC_STUB ITTerminal_get_Direction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITMultiTrackTerminal_INTERFACE_DEFINED__
#define __ITMultiTrackTerminal_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITMultiTrackTerminal;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITMultiTrackTerminal : public IDispatch {
  public:
    virtual HRESULT WINAPI get_TrackTerminals(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateTrackTerminals(IEnumTerminal **ppEnumTerminal) = 0;
    virtual HRESULT WINAPI CreateTrackTerminal(__LONG32 MediaType,TERMINAL_DIRECTION TerminalDirection,ITTerminal **ppTerminal) = 0;
    virtual HRESULT WINAPI get_MediaTypesInUse(__LONG32 *plMediaTypesInUse) = 0;
    virtual HRESULT WINAPI get_DirectionsInUse(TERMINAL_DIRECTION *plDirectionsInUsed) = 0;
    virtual HRESULT WINAPI RemoveTrackTerminal(ITTerminal *pTrackTerminalToRemove) = 0;
  };
#else
  typedef struct ITMultiTrackTerminalVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITMultiTrackTerminal *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITMultiTrackTerminal *This);
      ULONG (WINAPI *Release)(ITMultiTrackTerminal *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITMultiTrackTerminal *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITMultiTrackTerminal *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITMultiTrackTerminal *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITMultiTrackTerminal *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_TrackTerminals)(ITMultiTrackTerminal *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateTrackTerminals)(ITMultiTrackTerminal *This,IEnumTerminal **ppEnumTerminal);
      HRESULT (WINAPI *CreateTrackTerminal)(ITMultiTrackTerminal *This,__LONG32 MediaType,TERMINAL_DIRECTION TerminalDirection,ITTerminal **ppTerminal);
      HRESULT (WINAPI *get_MediaTypesInUse)(ITMultiTrackTerminal *This,__LONG32 *plMediaTypesInUse);
      HRESULT (WINAPI *get_DirectionsInUse)(ITMultiTrackTerminal *This,TERMINAL_DIRECTION *plDirectionsInUsed);
      HRESULT (WINAPI *RemoveTrackTerminal)(ITMultiTrackTerminal *This,ITTerminal *pTrackTerminalToRemove);
    END_INTERFACE
  } ITMultiTrackTerminalVtbl;
  struct ITMultiTrackTerminal {
    CONST_VTBL struct ITMultiTrackTerminalVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITMultiTrackTerminal_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITMultiTrackTerminal_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITMultiTrackTerminal_Release(This) (This)->lpVtbl->Release(This)
#define ITMultiTrackTerminal_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITMultiTrackTerminal_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITMultiTrackTerminal_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITMultiTrackTerminal_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITMultiTrackTerminal_get_TrackTerminals(This,pVariant) (This)->lpVtbl->get_TrackTerminals(This,pVariant)
#define ITMultiTrackTerminal_EnumerateTrackTerminals(This,ppEnumTerminal) (This)->lpVtbl->EnumerateTrackTerminals(This,ppEnumTerminal)
#define ITMultiTrackTerminal_CreateTrackTerminal(This,MediaType,TerminalDirection,ppTerminal) (This)->lpVtbl->CreateTrackTerminal(This,MediaType,TerminalDirection,ppTerminal)
#define ITMultiTrackTerminal_get_MediaTypesInUse(This,plMediaTypesInUse) (This)->lpVtbl->get_MediaTypesInUse(This,plMediaTypesInUse)
#define ITMultiTrackTerminal_get_DirectionsInUse(This,plDirectionsInUsed) (This)->lpVtbl->get_DirectionsInUse(This,plDirectionsInUsed)
#define ITMultiTrackTerminal_RemoveTrackTerminal(This,pTrackTerminalToRemove) (This)->lpVtbl->RemoveTrackTerminal(This,pTrackTerminalToRemove)
#endif
#endif
  HRESULT WINAPI ITMultiTrackTerminal_get_TrackTerminals_Proxy(ITMultiTrackTerminal *This,VARIANT *pVariant);
  void __RPC_STUB ITMultiTrackTerminal_get_TrackTerminals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMultiTrackTerminal_EnumerateTrackTerminals_Proxy(ITMultiTrackTerminal *This,IEnumTerminal **ppEnumTerminal);
  void __RPC_STUB ITMultiTrackTerminal_EnumerateTrackTerminals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMultiTrackTerminal_CreateTrackTerminal_Proxy(ITMultiTrackTerminal *This,__LONG32 MediaType,TERMINAL_DIRECTION TerminalDirection,ITTerminal **ppTerminal);
  void __RPC_STUB ITMultiTrackTerminal_CreateTrackTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMultiTrackTerminal_get_MediaTypesInUse_Proxy(ITMultiTrackTerminal *This,__LONG32 *plMediaTypesInUse);
  void __RPC_STUB ITMultiTrackTerminal_get_MediaTypesInUse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMultiTrackTerminal_get_DirectionsInUse_Proxy(ITMultiTrackTerminal *This,TERMINAL_DIRECTION *plDirectionsInUsed);
  void __RPC_STUB ITMultiTrackTerminal_get_DirectionsInUse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMultiTrackTerminal_RemoveTrackTerminal_Proxy(ITMultiTrackTerminal *This,ITTerminal *pTrackTerminalToRemove);
  void __RPC_STUB ITMultiTrackTerminal_RemoveTrackTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef enum TERMINAL_MEDIA_STATE {
    TMS_IDLE = 0,
    TMS_ACTIVE,TMS_PAUSED,
    TMS_LASTITEM = TMS_PAUSED
  } TERMINAL_MEDIA_STATE;

  typedef enum FT_STATE_EVENT_CAUSE {
    FTEC_NORMAL = 0,
    FTEC_END_OF_FILE,FTEC_READ_ERROR,FTEC_WRITE_ERROR
  } FT_STATE_EVENT_CAUSE;

  extern RPC_IF_HANDLE __MIDL_itf_tapi3if_0433_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_tapi3if_0433_v0_0_s_ifspec;
#ifndef __ITFileTrack_INTERFACE_DEFINED__
#define __ITFileTrack_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITFileTrack;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITFileTrack : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Format(AM_MEDIA_TYPE **ppmt) = 0;
    virtual HRESULT WINAPI put_Format(const AM_MEDIA_TYPE *pmt) = 0;
    virtual HRESULT WINAPI get_ControllingTerminal(ITTerminal **ppControllingTerminal) = 0;
    virtual HRESULT WINAPI get_AudioFormatForScripting(ITScriptableAudioFormat **ppAudioFormat) = 0;
    virtual HRESULT WINAPI put_AudioFormatForScripting(ITScriptableAudioFormat *pAudioFormat) = 0;
    virtual HRESULT WINAPI get_EmptyAudioFormatForScripting(ITScriptableAudioFormat **ppAudioFormat) = 0;
  };
#else
  typedef struct ITFileTrackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITFileTrack *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITFileTrack *This);
      ULONG (WINAPI *Release)(ITFileTrack *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITFileTrack *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITFileTrack *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITFileTrack *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITFileTrack *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Format)(ITFileTrack *This,AM_MEDIA_TYPE **ppmt);
      HRESULT (WINAPI *put_Format)(ITFileTrack *This,const AM_MEDIA_TYPE *pmt);
      HRESULT (WINAPI *get_ControllingTerminal)(ITFileTrack *This,ITTerminal **ppControllingTerminal);
      HRESULT (WINAPI *get_AudioFormatForScripting)(ITFileTrack *This,ITScriptableAudioFormat **ppAudioFormat);
      HRESULT (WINAPI *put_AudioFormatForScripting)(ITFileTrack *This,ITScriptableAudioFormat *pAudioFormat);
      HRESULT (WINAPI *get_EmptyAudioFormatForScripting)(ITFileTrack *This,ITScriptableAudioFormat **ppAudioFormat);
    END_INTERFACE
  } ITFileTrackVtbl;
  struct ITFileTrack {
    CONST_VTBL struct ITFileTrackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITFileTrack_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITFileTrack_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITFileTrack_Release(This) (This)->lpVtbl->Release(This)
#define ITFileTrack_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITFileTrack_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITFileTrack_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITFileTrack_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITFileTrack_get_Format(This,ppmt) (This)->lpVtbl->get_Format(This,ppmt)
#define ITFileTrack_put_Format(This,pmt) (This)->lpVtbl->put_Format(This,pmt)
#define ITFileTrack_get_ControllingTerminal(This,ppControllingTerminal) (This)->lpVtbl->get_ControllingTerminal(This,ppControllingTerminal)
#define ITFileTrack_get_AudioFormatForScripting(This,ppAudioFormat) (This)->lpVtbl->get_AudioFormatForScripting(This,ppAudioFormat)
#define ITFileTrack_put_AudioFormatForScripting(This,pAudioFormat) (This)->lpVtbl->put_AudioFormatForScripting(This,pAudioFormat)
#define ITFileTrack_get_EmptyAudioFormatForScripting(This,ppAudioFormat) (This)->lpVtbl->get_EmptyAudioFormatForScripting(This,ppAudioFormat)
#endif
#endif
  HRESULT WINAPI ITFileTrack_get_Format_Proxy(ITFileTrack *This,AM_MEDIA_TYPE **ppmt);
  void __RPC_STUB ITFileTrack_get_Format_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFileTrack_put_Format_Proxy(ITFileTrack *This,const AM_MEDIA_TYPE *pmt);
  void __RPC_STUB ITFileTrack_put_Format_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFileTrack_get_ControllingTerminal_Proxy(ITFileTrack *This,ITTerminal **ppControllingTerminal);
  void __RPC_STUB ITFileTrack_get_ControllingTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFileTrack_get_AudioFormatForScripting_Proxy(ITFileTrack *This,ITScriptableAudioFormat **ppAudioFormat);
  void __RPC_STUB ITFileTrack_get_AudioFormatForScripting_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFileTrack_put_AudioFormatForScripting_Proxy(ITFileTrack *This,ITScriptableAudioFormat *pAudioFormat);
  void __RPC_STUB ITFileTrack_put_AudioFormatForScripting_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFileTrack_get_EmptyAudioFormatForScripting_Proxy(ITFileTrack *This,ITScriptableAudioFormat **ppAudioFormat);
  void __RPC_STUB ITFileTrack_get_EmptyAudioFormatForScripting_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITMediaPlayback_INTERFACE_DEFINED__
#define __ITMediaPlayback_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITMediaPlayback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITMediaPlayback : public IDispatch {
  public:
    virtual HRESULT WINAPI put_PlayList(VARIANTARG PlayListVariant) = 0;
    virtual HRESULT WINAPI get_PlayList(VARIANTARG *pPlayListVariant) = 0;
  };
#else
  typedef struct ITMediaPlaybackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITMediaPlayback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITMediaPlayback *This);
      ULONG (WINAPI *Release)(ITMediaPlayback *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITMediaPlayback *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITMediaPlayback *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITMediaPlayback *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITMediaPlayback *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *put_PlayList)(ITMediaPlayback *This,VARIANTARG PlayListVariant);
      HRESULT (WINAPI *get_PlayList)(ITMediaPlayback *This,VARIANTARG *pPlayListVariant);
    END_INTERFACE
  } ITMediaPlaybackVtbl;
  struct ITMediaPlayback {
    CONST_VTBL struct ITMediaPlaybackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITMediaPlayback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITMediaPlayback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITMediaPlayback_Release(This) (This)->lpVtbl->Release(This)
#define ITMediaPlayback_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITMediaPlayback_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITMediaPlayback_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITMediaPlayback_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITMediaPlayback_put_PlayList(This,PlayListVariant) (This)->lpVtbl->put_PlayList(This,PlayListVariant)
#define ITMediaPlayback_get_PlayList(This,pPlayListVariant) (This)->lpVtbl->get_PlayList(This,pPlayListVariant)
#endif
#endif
  HRESULT WINAPI ITMediaPlayback_put_PlayList_Proxy(ITMediaPlayback *This,VARIANTARG PlayListVariant);
  void __RPC_STUB ITMediaPlayback_put_PlayList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMediaPlayback_get_PlayList_Proxy(ITMediaPlayback *This,VARIANTARG *pPlayListVariant);
  void __RPC_STUB ITMediaPlayback_get_PlayList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITMediaRecord_INTERFACE_DEFINED__
#define __ITMediaRecord_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITMediaRecord;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITMediaRecord : public IDispatch {
  public:
    virtual HRESULT WINAPI put_FileName(BSTR bstrFileName) = 0;
    virtual HRESULT WINAPI get_FileName(BSTR *pbstrFileName) = 0;
  };
#else
  typedef struct ITMediaRecordVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITMediaRecord *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITMediaRecord *This);
      ULONG (WINAPI *Release)(ITMediaRecord *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITMediaRecord *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITMediaRecord *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITMediaRecord *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITMediaRecord *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *put_FileName)(ITMediaRecord *This,BSTR bstrFileName);
      HRESULT (WINAPI *get_FileName)(ITMediaRecord *This,BSTR *pbstrFileName);
    END_INTERFACE
  } ITMediaRecordVtbl;
  struct ITMediaRecord {
    CONST_VTBL struct ITMediaRecordVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITMediaRecord_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITMediaRecord_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITMediaRecord_Release(This) (This)->lpVtbl->Release(This)
#define ITMediaRecord_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITMediaRecord_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITMediaRecord_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITMediaRecord_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITMediaRecord_put_FileName(This,bstrFileName) (This)->lpVtbl->put_FileName(This,bstrFileName)
#define ITMediaRecord_get_FileName(This,pbstrFileName) (This)->lpVtbl->get_FileName(This,pbstrFileName)
#endif
#endif
  HRESULT WINAPI ITMediaRecord_put_FileName_Proxy(ITMediaRecord *This,BSTR bstrFileName);
  void __RPC_STUB ITMediaRecord_put_FileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMediaRecord_get_FileName_Proxy(ITMediaRecord *This,BSTR *pbstrFileName);
  void __RPC_STUB ITMediaRecord_get_FileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITMediaControl_INTERFACE_DEFINED__
#define __ITMediaControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITMediaControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITMediaControl : public IDispatch {
  public:
    virtual HRESULT WINAPI Start(void) = 0;
    virtual HRESULT WINAPI Stop(void) = 0;
    virtual HRESULT WINAPI Pause(void) = 0;
    virtual HRESULT WINAPI get_MediaState(TERMINAL_MEDIA_STATE *pTerminalMediaState) = 0;
  };
#else
  typedef struct ITMediaControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITMediaControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITMediaControl *This);
      ULONG (WINAPI *Release)(ITMediaControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITMediaControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITMediaControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITMediaControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITMediaControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Start)(ITMediaControl *This);
      HRESULT (WINAPI *Stop)(ITMediaControl *This);
      HRESULT (WINAPI *Pause)(ITMediaControl *This);
      HRESULT (WINAPI *get_MediaState)(ITMediaControl *This,TERMINAL_MEDIA_STATE *pTerminalMediaState);
    END_INTERFACE
  } ITMediaControlVtbl;
  struct ITMediaControl {
    CONST_VTBL struct ITMediaControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITMediaControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITMediaControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITMediaControl_Release(This) (This)->lpVtbl->Release(This)
#define ITMediaControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITMediaControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITMediaControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITMediaControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITMediaControl_Start(This) (This)->lpVtbl->Start(This)
#define ITMediaControl_Stop(This) (This)->lpVtbl->Stop(This)
#define ITMediaControl_Pause(This) (This)->lpVtbl->Pause(This)
#define ITMediaControl_get_MediaState(This,pTerminalMediaState) (This)->lpVtbl->get_MediaState(This,pTerminalMediaState)
#endif
#endif
  HRESULT WINAPI ITMediaControl_Start_Proxy(ITMediaControl *This);
  void __RPC_STUB ITMediaControl_Start_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMediaControl_Stop_Proxy(ITMediaControl *This);
  void __RPC_STUB ITMediaControl_Stop_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMediaControl_Pause_Proxy(ITMediaControl *This);
  void __RPC_STUB ITMediaControl_Pause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMediaControl_get_MediaState_Proxy(ITMediaControl *This,TERMINAL_MEDIA_STATE *pTerminalMediaState);
  void __RPC_STUB ITMediaControl_get_MediaState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITBasicAudioTerminal_INTERFACE_DEFINED__
#define __ITBasicAudioTerminal_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITBasicAudioTerminal;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITBasicAudioTerminal : public IDispatch {
  public:
    virtual HRESULT WINAPI put_Volume(__LONG32 lVolume) = 0;
    virtual HRESULT WINAPI get_Volume(__LONG32 *plVolume) = 0;
    virtual HRESULT WINAPI put_Balance(__LONG32 lBalance) = 0;
    virtual HRESULT WINAPI get_Balance(__LONG32 *plBalance) = 0;
  };
#else
  typedef struct ITBasicAudioTerminalVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITBasicAudioTerminal *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITBasicAudioTerminal *This);
      ULONG (WINAPI *Release)(ITBasicAudioTerminal *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITBasicAudioTerminal *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITBasicAudioTerminal *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITBasicAudioTerminal *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITBasicAudioTerminal *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *put_Volume)(ITBasicAudioTerminal *This,__LONG32 lVolume);
      HRESULT (WINAPI *get_Volume)(ITBasicAudioTerminal *This,__LONG32 *plVolume);
      HRESULT (WINAPI *put_Balance)(ITBasicAudioTerminal *This,__LONG32 lBalance);
      HRESULT (WINAPI *get_Balance)(ITBasicAudioTerminal *This,__LONG32 *plBalance);
    END_INTERFACE
  } ITBasicAudioTerminalVtbl;
  struct ITBasicAudioTerminal {
    CONST_VTBL struct ITBasicAudioTerminalVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITBasicAudioTerminal_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITBasicAudioTerminal_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITBasicAudioTerminal_Release(This) (This)->lpVtbl->Release(This)
#define ITBasicAudioTerminal_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITBasicAudioTerminal_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITBasicAudioTerminal_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITBasicAudioTerminal_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITBasicAudioTerminal_put_Volume(This,lVolume) (This)->lpVtbl->put_Volume(This,lVolume)
#define ITBasicAudioTerminal_get_Volume(This,plVolume) (This)->lpVtbl->get_Volume(This,plVolume)
#define ITBasicAudioTerminal_put_Balance(This,lBalance) (This)->lpVtbl->put_Balance(This,lBalance)
#define ITBasicAudioTerminal_get_Balance(This,plBalance) (This)->lpVtbl->get_Balance(This,plBalance)
#endif
#endif
  HRESULT WINAPI ITBasicAudioTerminal_put_Volume_Proxy(ITBasicAudioTerminal *This,__LONG32 lVolume);
  void __RPC_STUB ITBasicAudioTerminal_put_Volume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicAudioTerminal_get_Volume_Proxy(ITBasicAudioTerminal *This,__LONG32 *plVolume);
  void __RPC_STUB ITBasicAudioTerminal_get_Volume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicAudioTerminal_put_Balance_Proxy(ITBasicAudioTerminal *This,__LONG32 lBalance);
  void __RPC_STUB ITBasicAudioTerminal_put_Balance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicAudioTerminal_get_Balance_Proxy(ITBasicAudioTerminal *This,__LONG32 *plBalance);
  void __RPC_STUB ITBasicAudioTerminal_get_Balance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITStaticAudioTerminal_INTERFACE_DEFINED__
#define __ITStaticAudioTerminal_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITStaticAudioTerminal;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITStaticAudioTerminal : public IDispatch {
  public:
    virtual HRESULT WINAPI get_WaveId(__LONG32 *plWaveId) = 0;
  };
#else
  typedef struct ITStaticAudioTerminalVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITStaticAudioTerminal *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITStaticAudioTerminal *This);
      ULONG (WINAPI *Release)(ITStaticAudioTerminal *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITStaticAudioTerminal *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITStaticAudioTerminal *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITStaticAudioTerminal *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITStaticAudioTerminal *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_WaveId)(ITStaticAudioTerminal *This,__LONG32 *plWaveId);
    END_INTERFACE
  } ITStaticAudioTerminalVtbl;
  struct ITStaticAudioTerminal {
    CONST_VTBL struct ITStaticAudioTerminalVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITStaticAudioTerminal_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITStaticAudioTerminal_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITStaticAudioTerminal_Release(This) (This)->lpVtbl->Release(This)
#define ITStaticAudioTerminal_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITStaticAudioTerminal_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITStaticAudioTerminal_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITStaticAudioTerminal_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITStaticAudioTerminal_get_WaveId(This,plWaveId) (This)->lpVtbl->get_WaveId(This,plWaveId)
#endif
#endif
  HRESULT WINAPI ITStaticAudioTerminal_get_WaveId_Proxy(ITStaticAudioTerminal *This,__LONG32 *plWaveId);
  void __RPC_STUB ITStaticAudioTerminal_get_WaveId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCallHub_INTERFACE_DEFINED__
#define __ITCallHub_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCallHub;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCallHub : public IDispatch {
  public:
    virtual HRESULT WINAPI Clear(void) = 0;
    virtual HRESULT WINAPI EnumerateCalls(IEnumCall **ppEnumCall) = 0;
    virtual HRESULT WINAPI get_Calls(VARIANT *pCalls) = 0;
    virtual HRESULT WINAPI get_NumCalls(__LONG32 *plCalls) = 0;
    virtual HRESULT WINAPI get_State(CALLHUB_STATE *pState) = 0;
  };
#else
  typedef struct ITCallHubVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCallHub *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCallHub *This);
      ULONG (WINAPI *Release)(ITCallHub *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCallHub *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCallHub *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCallHub *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCallHub *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Clear)(ITCallHub *This);
      HRESULT (WINAPI *EnumerateCalls)(ITCallHub *This,IEnumCall **ppEnumCall);
      HRESULT (WINAPI *get_Calls)(ITCallHub *This,VARIANT *pCalls);
      HRESULT (WINAPI *get_NumCalls)(ITCallHub *This,__LONG32 *plCalls);
      HRESULT (WINAPI *get_State)(ITCallHub *This,CALLHUB_STATE *pState);
    END_INTERFACE
  } ITCallHubVtbl;
  struct ITCallHub {
    CONST_VTBL struct ITCallHubVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCallHub_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCallHub_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCallHub_Release(This) (This)->lpVtbl->Release(This)
#define ITCallHub_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCallHub_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCallHub_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCallHub_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCallHub_Clear(This) (This)->lpVtbl->Clear(This)
#define ITCallHub_EnumerateCalls(This,ppEnumCall) (This)->lpVtbl->EnumerateCalls(This,ppEnumCall)
#define ITCallHub_get_Calls(This,pCalls) (This)->lpVtbl->get_Calls(This,pCalls)
#define ITCallHub_get_NumCalls(This,plCalls) (This)->lpVtbl->get_NumCalls(This,plCalls)
#define ITCallHub_get_State(This,pState) (This)->lpVtbl->get_State(This,pState)
#endif
#endif
  HRESULT WINAPI ITCallHub_Clear_Proxy(ITCallHub *This);
  void __RPC_STUB ITCallHub_Clear_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallHub_EnumerateCalls_Proxy(ITCallHub *This,IEnumCall **ppEnumCall);
  void __RPC_STUB ITCallHub_EnumerateCalls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallHub_get_Calls_Proxy(ITCallHub *This,VARIANT *pCalls);
  void __RPC_STUB ITCallHub_get_Calls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallHub_get_NumCalls_Proxy(ITCallHub *This,__LONG32 *plCalls);
  void __RPC_STUB ITCallHub_get_NumCalls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallHub_get_State_Proxy(ITCallHub *This,CALLHUB_STATE *pState);
  void __RPC_STUB ITCallHub_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITLegacyAddressMediaControl_INTERFACE_DEFINED__
#define __ITLegacyAddressMediaControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITLegacyAddressMediaControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITLegacyAddressMediaControl : public IUnknown {
  public:
    virtual HRESULT WINAPI GetID(BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceID) = 0;
    virtual HRESULT WINAPI GetDevConfig(BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceConfig) = 0;
    virtual HRESULT WINAPI SetDevConfig(BSTR pDeviceClass,DWORD dwSize,BYTE *pDeviceConfig) = 0;
  };
#else
  typedef struct ITLegacyAddressMediaControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITLegacyAddressMediaControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITLegacyAddressMediaControl *This);
      ULONG (WINAPI *Release)(ITLegacyAddressMediaControl *This);
      HRESULT (WINAPI *GetID)(ITLegacyAddressMediaControl *This,BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceID);
      HRESULT (WINAPI *GetDevConfig)(ITLegacyAddressMediaControl *This,BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceConfig);
      HRESULT (WINAPI *SetDevConfig)(ITLegacyAddressMediaControl *This,BSTR pDeviceClass,DWORD dwSize,BYTE *pDeviceConfig);
    END_INTERFACE
  } ITLegacyAddressMediaControlVtbl;
  struct ITLegacyAddressMediaControl {
    CONST_VTBL struct ITLegacyAddressMediaControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITLegacyAddressMediaControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITLegacyAddressMediaControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITLegacyAddressMediaControl_Release(This) (This)->lpVtbl->Release(This)
#define ITLegacyAddressMediaControl_GetID(This,pDeviceClass,pdwSize,ppDeviceID) (This)->lpVtbl->GetID(This,pDeviceClass,pdwSize,ppDeviceID)
#define ITLegacyAddressMediaControl_GetDevConfig(This,pDeviceClass,pdwSize,ppDeviceConfig) (This)->lpVtbl->GetDevConfig(This,pDeviceClass,pdwSize,ppDeviceConfig)
#define ITLegacyAddressMediaControl_SetDevConfig(This,pDeviceClass,dwSize,pDeviceConfig) (This)->lpVtbl->SetDevConfig(This,pDeviceClass,dwSize,pDeviceConfig)
#endif
#endif
  HRESULT WINAPI ITLegacyAddressMediaControl_GetID_Proxy(ITLegacyAddressMediaControl *This,BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceID);
  void __RPC_STUB ITLegacyAddressMediaControl_GetID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyAddressMediaControl_GetDevConfig_Proxy(ITLegacyAddressMediaControl *This,BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceConfig);
  void __RPC_STUB ITLegacyAddressMediaControl_GetDevConfig_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyAddressMediaControl_SetDevConfig_Proxy(ITLegacyAddressMediaControl *This,BSTR pDeviceClass,DWORD dwSize,BYTE *pDeviceConfig);
  void __RPC_STUB ITLegacyAddressMediaControl_SetDevConfig_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITPrivateEvent_INTERFACE_DEFINED__
#define __ITPrivateEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITPrivateEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITPrivateEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Address(ITAddress **ppAddress) = 0;
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCallInfo) = 0;
    virtual HRESULT WINAPI get_CallHub(ITCallHub **ppCallHub) = 0;
    virtual HRESULT WINAPI get_EventCode(__LONG32 *plEventCode) = 0;
    virtual HRESULT WINAPI get_EventInterface(IDispatch **pEventInterface) = 0;
  };
#else
  typedef struct ITPrivateEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITPrivateEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITPrivateEvent *This);
      ULONG (WINAPI *Release)(ITPrivateEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITPrivateEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITPrivateEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITPrivateEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITPrivateEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Address)(ITPrivateEvent *This,ITAddress **ppAddress);
      HRESULT (WINAPI *get_Call)(ITPrivateEvent *This,ITCallInfo **ppCallInfo);
      HRESULT (WINAPI *get_CallHub)(ITPrivateEvent *This,ITCallHub **ppCallHub);
      HRESULT (WINAPI *get_EventCode)(ITPrivateEvent *This,__LONG32 *plEventCode);
      HRESULT (WINAPI *get_EventInterface)(ITPrivateEvent *This,IDispatch **pEventInterface);
    END_INTERFACE
  } ITPrivateEventVtbl;
  struct ITPrivateEvent {
    CONST_VTBL struct ITPrivateEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITPrivateEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITPrivateEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITPrivateEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITPrivateEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITPrivateEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITPrivateEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITPrivateEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITPrivateEvent_get_Address(This,ppAddress) (This)->lpVtbl->get_Address(This,ppAddress)
#define ITPrivateEvent_get_Call(This,ppCallInfo) (This)->lpVtbl->get_Call(This,ppCallInfo)
#define ITPrivateEvent_get_CallHub(This,ppCallHub) (This)->lpVtbl->get_CallHub(This,ppCallHub)
#define ITPrivateEvent_get_EventCode(This,plEventCode) (This)->lpVtbl->get_EventCode(This,plEventCode)
#define ITPrivateEvent_get_EventInterface(This,pEventInterface) (This)->lpVtbl->get_EventInterface(This,pEventInterface)
#endif
#endif
  HRESULT WINAPI ITPrivateEvent_get_Address_Proxy(ITPrivateEvent *This,ITAddress **ppAddress);
  void __RPC_STUB ITPrivateEvent_get_Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPrivateEvent_get_Call_Proxy(ITPrivateEvent *This,ITCallInfo **ppCallInfo);
  void __RPC_STUB ITPrivateEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPrivateEvent_get_CallHub_Proxy(ITPrivateEvent *This,ITCallHub **ppCallHub);
  void __RPC_STUB ITPrivateEvent_get_CallHub_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPrivateEvent_get_EventCode_Proxy(ITPrivateEvent *This,__LONG32 *plEventCode);
  void __RPC_STUB ITPrivateEvent_get_EventCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPrivateEvent_get_EventInterface_Proxy(ITPrivateEvent *This,IDispatch **pEventInterface);
  void __RPC_STUB ITPrivateEvent_get_EventInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITLegacyAddressMediaControl2_INTERFACE_DEFINED__
#define __ITLegacyAddressMediaControl2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITLegacyAddressMediaControl2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITLegacyAddressMediaControl2 : public ITLegacyAddressMediaControl {
  public:
    virtual HRESULT WINAPI ConfigDialog(HWND hwndOwner,BSTR pDeviceClass) = 0;
    virtual HRESULT WINAPI ConfigDialogEdit(HWND hwndOwner,BSTR pDeviceClass,DWORD dwSizeIn,BYTE *pDeviceConfigIn,DWORD *pdwSizeOut,BYTE **ppDeviceConfigOut) = 0;
  };
#else
  typedef struct ITLegacyAddressMediaControl2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITLegacyAddressMediaControl2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITLegacyAddressMediaControl2 *This);
      ULONG (WINAPI *Release)(ITLegacyAddressMediaControl2 *This);
      HRESULT (WINAPI *GetID)(ITLegacyAddressMediaControl2 *This,BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceID);
      HRESULT (WINAPI *GetDevConfig)(ITLegacyAddressMediaControl2 *This,BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceConfig);
      HRESULT (WINAPI *SetDevConfig)(ITLegacyAddressMediaControl2 *This,BSTR pDeviceClass,DWORD dwSize,BYTE *pDeviceConfig);
      HRESULT (WINAPI *ConfigDialog)(ITLegacyAddressMediaControl2 *This,HWND hwndOwner,BSTR pDeviceClass);
      HRESULT (WINAPI *ConfigDialogEdit)(ITLegacyAddressMediaControl2 *This,HWND hwndOwner,BSTR pDeviceClass,DWORD dwSizeIn,BYTE *pDeviceConfigIn,DWORD *pdwSizeOut,BYTE **ppDeviceConfigOut);
    END_INTERFACE
  } ITLegacyAddressMediaControl2Vtbl;
  struct ITLegacyAddressMediaControl2 {
    CONST_VTBL struct ITLegacyAddressMediaControl2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITLegacyAddressMediaControl2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITLegacyAddressMediaControl2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITLegacyAddressMediaControl2_Release(This) (This)->lpVtbl->Release(This)
#define ITLegacyAddressMediaControl2_GetID(This,pDeviceClass,pdwSize,ppDeviceID) (This)->lpVtbl->GetID(This,pDeviceClass,pdwSize,ppDeviceID)
#define ITLegacyAddressMediaControl2_GetDevConfig(This,pDeviceClass,pdwSize,ppDeviceConfig) (This)->lpVtbl->GetDevConfig(This,pDeviceClass,pdwSize,ppDeviceConfig)
#define ITLegacyAddressMediaControl2_SetDevConfig(This,pDeviceClass,dwSize,pDeviceConfig) (This)->lpVtbl->SetDevConfig(This,pDeviceClass,dwSize,pDeviceConfig)
#define ITLegacyAddressMediaControl2_ConfigDialog(This,hwndOwner,pDeviceClass) (This)->lpVtbl->ConfigDialog(This,hwndOwner,pDeviceClass)
#define ITLegacyAddressMediaControl2_ConfigDialogEdit(This,hwndOwner,pDeviceClass,dwSizeIn,pDeviceConfigIn,pdwSizeOut,ppDeviceConfigOut) (This)->lpVtbl->ConfigDialogEdit(This,hwndOwner,pDeviceClass,dwSizeIn,pDeviceConfigIn,pdwSizeOut,ppDeviceConfigOut)
#endif
#endif
  HRESULT WINAPI ITLegacyAddressMediaControl2_ConfigDialog_Proxy(ITLegacyAddressMediaControl2 *This,HWND hwndOwner,BSTR pDeviceClass);
  void __RPC_STUB ITLegacyAddressMediaControl2_ConfigDialog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyAddressMediaControl2_ConfigDialogEdit_Proxy(ITLegacyAddressMediaControl2 *This,HWND hwndOwner,BSTR pDeviceClass,DWORD dwSizeIn,BYTE *pDeviceConfigIn,DWORD *pdwSizeOut,BYTE **ppDeviceConfigOut);
  void __RPC_STUB ITLegacyAddressMediaControl2_ConfigDialogEdit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITLegacyCallMediaControl_INTERFACE_DEFINED__
#define __ITLegacyCallMediaControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITLegacyCallMediaControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITLegacyCallMediaControl : public IDispatch {
  public:
    virtual HRESULT WINAPI DetectDigits(TAPI_DIGITMODE DigitMode) = 0;
    virtual HRESULT WINAPI GenerateDigits(BSTR pDigits,TAPI_DIGITMODE DigitMode) = 0;
    virtual HRESULT WINAPI GetID(BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceID) = 0;
    virtual HRESULT WINAPI SetMediaType(__LONG32 lMediaType) = 0;
    virtual HRESULT WINAPI MonitorMedia(__LONG32 lMediaType) = 0;
  };
#else
  typedef struct ITLegacyCallMediaControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITLegacyCallMediaControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITLegacyCallMediaControl *This);
      ULONG (WINAPI *Release)(ITLegacyCallMediaControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITLegacyCallMediaControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITLegacyCallMediaControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITLegacyCallMediaControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITLegacyCallMediaControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *DetectDigits)(ITLegacyCallMediaControl *This,TAPI_DIGITMODE DigitMode);
      HRESULT (WINAPI *GenerateDigits)(ITLegacyCallMediaControl *This,BSTR pDigits,TAPI_DIGITMODE DigitMode);
      HRESULT (WINAPI *GetID)(ITLegacyCallMediaControl *This,BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceID);
      HRESULT (WINAPI *SetMediaType)(ITLegacyCallMediaControl *This,__LONG32 lMediaType);
      HRESULT (WINAPI *MonitorMedia)(ITLegacyCallMediaControl *This,__LONG32 lMediaType);
    END_INTERFACE
  } ITLegacyCallMediaControlVtbl;
  struct ITLegacyCallMediaControl {
    CONST_VTBL struct ITLegacyCallMediaControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITLegacyCallMediaControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITLegacyCallMediaControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITLegacyCallMediaControl_Release(This) (This)->lpVtbl->Release(This)
#define ITLegacyCallMediaControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITLegacyCallMediaControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITLegacyCallMediaControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITLegacyCallMediaControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITLegacyCallMediaControl_DetectDigits(This,DigitMode) (This)->lpVtbl->DetectDigits(This,DigitMode)
#define ITLegacyCallMediaControl_GenerateDigits(This,pDigits,DigitMode) (This)->lpVtbl->GenerateDigits(This,pDigits,DigitMode)
#define ITLegacyCallMediaControl_GetID(This,pDeviceClass,pdwSize,ppDeviceID) (This)->lpVtbl->GetID(This,pDeviceClass,pdwSize,ppDeviceID)
#define ITLegacyCallMediaControl_SetMediaType(This,lMediaType) (This)->lpVtbl->SetMediaType(This,lMediaType)
#define ITLegacyCallMediaControl_MonitorMedia(This,lMediaType) (This)->lpVtbl->MonitorMedia(This,lMediaType)
#endif
#endif
  HRESULT WINAPI ITLegacyCallMediaControl_DetectDigits_Proxy(ITLegacyCallMediaControl *This,TAPI_DIGITMODE DigitMode);
  void __RPC_STUB ITLegacyCallMediaControl_DetectDigits_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl_GenerateDigits_Proxy(ITLegacyCallMediaControl *This,BSTR pDigits,TAPI_DIGITMODE DigitMode);
  void __RPC_STUB ITLegacyCallMediaControl_GenerateDigits_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl_GetID_Proxy(ITLegacyCallMediaControl *This,BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceID);
  void __RPC_STUB ITLegacyCallMediaControl_GetID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl_SetMediaType_Proxy(ITLegacyCallMediaControl *This,__LONG32 lMediaType);
  void __RPC_STUB ITLegacyCallMediaControl_SetMediaType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl_MonitorMedia_Proxy(ITLegacyCallMediaControl *This,__LONG32 lMediaType);
  void __RPC_STUB ITLegacyCallMediaControl_MonitorMedia_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITLegacyCallMediaControl2_INTERFACE_DEFINED__
#define __ITLegacyCallMediaControl2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITLegacyCallMediaControl2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITLegacyCallMediaControl2 : public ITLegacyCallMediaControl {
  public:
    virtual HRESULT WINAPI GenerateDigits2(BSTR pDigits,TAPI_DIGITMODE DigitMode,__LONG32 lDuration) = 0;
    virtual HRESULT WINAPI GatherDigits(TAPI_DIGITMODE DigitMode,__LONG32 lNumDigits,BSTR pTerminationDigits,__LONG32 lFirstDigitTimeout,__LONG32 lInterDigitTimeout) = 0;
    virtual HRESULT WINAPI DetectTones(TAPI_DETECTTONE *pToneList,__LONG32 lNumTones) = 0;
    virtual HRESULT WINAPI DetectTonesByCollection(ITCollection2 *pDetectToneCollection) = 0;
    virtual HRESULT WINAPI GenerateTone(TAPI_TONEMODE ToneMode,__LONG32 lDuration) = 0;
    virtual HRESULT WINAPI GenerateCustomTones(TAPI_CUSTOMTONE *pToneList,__LONG32 lNumTones,__LONG32 lDuration) = 0;
    virtual HRESULT WINAPI GenerateCustomTonesByCollection(ITCollection2 *pCustomToneCollection,__LONG32 lDuration) = 0;
    virtual HRESULT WINAPI CreateDetectToneObject(ITDetectTone **ppDetectTone) = 0;
    virtual HRESULT WINAPI CreateCustomToneObject(ITCustomTone **ppCustomTone) = 0;
    virtual HRESULT WINAPI GetIDAsVariant(BSTR bstrDeviceClass,VARIANT *pVarDeviceID) = 0;
  };
#else
  typedef struct ITLegacyCallMediaControl2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITLegacyCallMediaControl2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITLegacyCallMediaControl2 *This);
      ULONG (WINAPI *Release)(ITLegacyCallMediaControl2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITLegacyCallMediaControl2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITLegacyCallMediaControl2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITLegacyCallMediaControl2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITLegacyCallMediaControl2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *DetectDigits)(ITLegacyCallMediaControl2 *This,TAPI_DIGITMODE DigitMode);
      HRESULT (WINAPI *GenerateDigits)(ITLegacyCallMediaControl2 *This,BSTR pDigits,TAPI_DIGITMODE DigitMode);
      HRESULT (WINAPI *GetID)(ITLegacyCallMediaControl2 *This,BSTR pDeviceClass,DWORD *pdwSize,BYTE **ppDeviceID);
      HRESULT (WINAPI *SetMediaType)(ITLegacyCallMediaControl2 *This,__LONG32 lMediaType);
      HRESULT (WINAPI *MonitorMedia)(ITLegacyCallMediaControl2 *This,__LONG32 lMediaType);
      HRESULT (WINAPI *GenerateDigits2)(ITLegacyCallMediaControl2 *This,BSTR pDigits,TAPI_DIGITMODE DigitMode,__LONG32 lDuration);
      HRESULT (WINAPI *GatherDigits)(ITLegacyCallMediaControl2 *This,TAPI_DIGITMODE DigitMode,__LONG32 lNumDigits,BSTR pTerminationDigits,__LONG32 lFirstDigitTimeout,__LONG32 lInterDigitTimeout);
      HRESULT (WINAPI *DetectTones)(ITLegacyCallMediaControl2 *This,TAPI_DETECTTONE *pToneList,__LONG32 lNumTones);
      HRESULT (WINAPI *DetectTonesByCollection)(ITLegacyCallMediaControl2 *This,ITCollection2 *pDetectToneCollection);
      HRESULT (WINAPI *GenerateTone)(ITLegacyCallMediaControl2 *This,TAPI_TONEMODE ToneMode,__LONG32 lDuration);
      HRESULT (WINAPI *GenerateCustomTones)(ITLegacyCallMediaControl2 *This,TAPI_CUSTOMTONE *pToneList,__LONG32 lNumTones,__LONG32 lDuration);
      HRESULT (WINAPI *GenerateCustomTonesByCollection)(ITLegacyCallMediaControl2 *This,ITCollection2 *pCustomToneCollection,__LONG32 lDuration);
      HRESULT (WINAPI *CreateDetectToneObject)(ITLegacyCallMediaControl2 *This,ITDetectTone **ppDetectTone);
      HRESULT (WINAPI *CreateCustomToneObject)(ITLegacyCallMediaControl2 *This,ITCustomTone **ppCustomTone);
      HRESULT (WINAPI *GetIDAsVariant)(ITLegacyCallMediaControl2 *This,BSTR bstrDeviceClass,VARIANT *pVarDeviceID);
    END_INTERFACE
  } ITLegacyCallMediaControl2Vtbl;
  struct ITLegacyCallMediaControl2 {
    CONST_VTBL struct ITLegacyCallMediaControl2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITLegacyCallMediaControl2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITLegacyCallMediaControl2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITLegacyCallMediaControl2_Release(This) (This)->lpVtbl->Release(This)
#define ITLegacyCallMediaControl2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITLegacyCallMediaControl2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITLegacyCallMediaControl2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITLegacyCallMediaControl2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITLegacyCallMediaControl2_DetectDigits(This,DigitMode) (This)->lpVtbl->DetectDigits(This,DigitMode)
#define ITLegacyCallMediaControl2_GenerateDigits(This,pDigits,DigitMode) (This)->lpVtbl->GenerateDigits(This,pDigits,DigitMode)
#define ITLegacyCallMediaControl2_GetID(This,pDeviceClass,pdwSize,ppDeviceID) (This)->lpVtbl->GetID(This,pDeviceClass,pdwSize,ppDeviceID)
#define ITLegacyCallMediaControl2_SetMediaType(This,lMediaType) (This)->lpVtbl->SetMediaType(This,lMediaType)
#define ITLegacyCallMediaControl2_MonitorMedia(This,lMediaType) (This)->lpVtbl->MonitorMedia(This,lMediaType)
#define ITLegacyCallMediaControl2_GenerateDigits2(This,pDigits,DigitMode,lDuration) (This)->lpVtbl->GenerateDigits2(This,pDigits,DigitMode,lDuration)
#define ITLegacyCallMediaControl2_GatherDigits(This,DigitMode,lNumDigits,pTerminationDigits,lFirstDigitTimeout,lInterDigitTimeout) (This)->lpVtbl->GatherDigits(This,DigitMode,lNumDigits,pTerminationDigits,lFirstDigitTimeout,lInterDigitTimeout)
#define ITLegacyCallMediaControl2_DetectTones(This,pToneList,lNumTones) (This)->lpVtbl->DetectTones(This,pToneList,lNumTones)
#define ITLegacyCallMediaControl2_DetectTonesByCollection(This,pDetectToneCollection) (This)->lpVtbl->DetectTonesByCollection(This,pDetectToneCollection)
#define ITLegacyCallMediaControl2_GenerateTone(This,ToneMode,lDuration) (This)->lpVtbl->GenerateTone(This,ToneMode,lDuration)
#define ITLegacyCallMediaControl2_GenerateCustomTones(This,pToneList,lNumTones,lDuration) (This)->lpVtbl->GenerateCustomTones(This,pToneList,lNumTones,lDuration)
#define ITLegacyCallMediaControl2_GenerateCustomTonesByCollection(This,pCustomToneCollection,lDuration) (This)->lpVtbl->GenerateCustomTonesByCollection(This,pCustomToneCollection,lDuration)
#define ITLegacyCallMediaControl2_CreateDetectToneObject(This,ppDetectTone) (This)->lpVtbl->CreateDetectToneObject(This,ppDetectTone)
#define ITLegacyCallMediaControl2_CreateCustomToneObject(This,ppCustomTone) (This)->lpVtbl->CreateCustomToneObject(This,ppCustomTone)
#define ITLegacyCallMediaControl2_GetIDAsVariant(This,bstrDeviceClass,pVarDeviceID) (This)->lpVtbl->GetIDAsVariant(This,bstrDeviceClass,pVarDeviceID)
#endif
#endif
  HRESULT WINAPI ITLegacyCallMediaControl2_GenerateDigits2_Proxy(ITLegacyCallMediaControl2 *This,BSTR pDigits,TAPI_DIGITMODE DigitMode,__LONG32 lDuration);
  void __RPC_STUB ITLegacyCallMediaControl2_GenerateDigits2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl2_GatherDigits_Proxy(ITLegacyCallMediaControl2 *This,TAPI_DIGITMODE DigitMode,__LONG32 lNumDigits,BSTR pTerminationDigits,__LONG32 lFirstDigitTimeout,__LONG32 lInterDigitTimeout);
  void __RPC_STUB ITLegacyCallMediaControl2_GatherDigits_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl2_DetectTones_Proxy(ITLegacyCallMediaControl2 *This,TAPI_DETECTTONE *pToneList,__LONG32 lNumTones);
  void __RPC_STUB ITLegacyCallMediaControl2_DetectTones_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl2_DetectTonesByCollection_Proxy(ITLegacyCallMediaControl2 *This,ITCollection2 *pDetectToneCollection);
  void __RPC_STUB ITLegacyCallMediaControl2_DetectTonesByCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl2_GenerateTone_Proxy(ITLegacyCallMediaControl2 *This,TAPI_TONEMODE ToneMode,__LONG32 lDuration);
  void __RPC_STUB ITLegacyCallMediaControl2_GenerateTone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl2_GenerateCustomTones_Proxy(ITLegacyCallMediaControl2 *This,TAPI_CUSTOMTONE *pToneList,__LONG32 lNumTones,__LONG32 lDuration);
  void __RPC_STUB ITLegacyCallMediaControl2_GenerateCustomTones_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl2_GenerateCustomTonesByCollection_Proxy(ITLegacyCallMediaControl2 *This,ITCollection2 *pCustomToneCollection,__LONG32 lDuration);
  void __RPC_STUB ITLegacyCallMediaControl2_GenerateCustomTonesByCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl2_CreateDetectToneObject_Proxy(ITLegacyCallMediaControl2 *This,ITDetectTone **ppDetectTone);
  void __RPC_STUB ITLegacyCallMediaControl2_CreateDetectToneObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl2_CreateCustomToneObject_Proxy(ITLegacyCallMediaControl2 *This,ITCustomTone **ppCustomTone);
  void __RPC_STUB ITLegacyCallMediaControl2_CreateCustomToneObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLegacyCallMediaControl2_GetIDAsVariant_Proxy(ITLegacyCallMediaControl2 *This,BSTR bstrDeviceClass,VARIANT *pVarDeviceID);
  void __RPC_STUB ITLegacyCallMediaControl2_GetIDAsVariant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITDetectTone_INTERFACE_DEFINED__
#define __ITDetectTone_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITDetectTone;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITDetectTone : public IDispatch {
  public:
    virtual HRESULT WINAPI get_AppSpecific(__LONG32 *plAppSpecific) = 0;
    virtual HRESULT WINAPI put_AppSpecific(__LONG32 lAppSpecific) = 0;
    virtual HRESULT WINAPI get_Duration(__LONG32 *plDuration) = 0;
    virtual HRESULT WINAPI put_Duration(__LONG32 lDuration) = 0;
    virtual HRESULT WINAPI get_Frequency(__LONG32 Index,__LONG32 *plFrequency) = 0;
    virtual HRESULT WINAPI put_Frequency(__LONG32 Index,__LONG32 lFrequency) = 0;
  };
#else
  typedef struct ITDetectToneVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITDetectTone *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITDetectTone *This);
      ULONG (WINAPI *Release)(ITDetectTone *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITDetectTone *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITDetectTone *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITDetectTone *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITDetectTone *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_AppSpecific)(ITDetectTone *This,__LONG32 *plAppSpecific);
      HRESULT (WINAPI *put_AppSpecific)(ITDetectTone *This,__LONG32 lAppSpecific);
      HRESULT (WINAPI *get_Duration)(ITDetectTone *This,__LONG32 *plDuration);
      HRESULT (WINAPI *put_Duration)(ITDetectTone *This,__LONG32 lDuration);
      HRESULT (WINAPI *get_Frequency)(ITDetectTone *This,__LONG32 Index,__LONG32 *plFrequency);
      HRESULT (WINAPI *put_Frequency)(ITDetectTone *This,__LONG32 Index,__LONG32 lFrequency);
    END_INTERFACE
  } ITDetectToneVtbl;
  struct ITDetectTone {
    CONST_VTBL struct ITDetectToneVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITDetectTone_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITDetectTone_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITDetectTone_Release(This) (This)->lpVtbl->Release(This)
#define ITDetectTone_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITDetectTone_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITDetectTone_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITDetectTone_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITDetectTone_get_AppSpecific(This,plAppSpecific) (This)->lpVtbl->get_AppSpecific(This,plAppSpecific)
#define ITDetectTone_put_AppSpecific(This,lAppSpecific) (This)->lpVtbl->put_AppSpecific(This,lAppSpecific)
#define ITDetectTone_get_Duration(This,plDuration) (This)->lpVtbl->get_Duration(This,plDuration)
#define ITDetectTone_put_Duration(This,lDuration) (This)->lpVtbl->put_Duration(This,lDuration)
#define ITDetectTone_get_Frequency(This,Index,plFrequency) (This)->lpVtbl->get_Frequency(This,Index,plFrequency)
#define ITDetectTone_put_Frequency(This,Index,lFrequency) (This)->lpVtbl->put_Frequency(This,Index,lFrequency)
#endif
#endif
  HRESULT WINAPI ITDetectTone_get_AppSpecific_Proxy(ITDetectTone *This,__LONG32 *plAppSpecific);
  void __RPC_STUB ITDetectTone_get_AppSpecific_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDetectTone_put_AppSpecific_Proxy(ITDetectTone *This,__LONG32 lAppSpecific);
  void __RPC_STUB ITDetectTone_put_AppSpecific_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDetectTone_get_Duration_Proxy(ITDetectTone *This,__LONG32 *plDuration);
  void __RPC_STUB ITDetectTone_get_Duration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDetectTone_put_Duration_Proxy(ITDetectTone *This,__LONG32 lDuration);
  void __RPC_STUB ITDetectTone_put_Duration_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDetectTone_get_Frequency_Proxy(ITDetectTone *This,__LONG32 Index,__LONG32 *plFrequency);
  void __RPC_STUB ITDetectTone_get_Frequency_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDetectTone_put_Frequency_Proxy(ITDetectTone *This,__LONG32 Index,__LONG32 lFrequency);
  void __RPC_STUB ITDetectTone_put_Frequency_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCustomTone_INTERFACE_DEFINED__
#define __ITCustomTone_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCustomTone;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCustomTone : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Frequency(__LONG32 *plFrequency) = 0;
    virtual HRESULT WINAPI put_Frequency(__LONG32 lFrequency) = 0;
    virtual HRESULT WINAPI get_CadenceOn(__LONG32 *plCadenceOn) = 0;
    virtual HRESULT WINAPI put_CadenceOn(__LONG32 CadenceOn) = 0;
    virtual HRESULT WINAPI get_CadenceOff(__LONG32 *plCadenceOff) = 0;
    virtual HRESULT WINAPI put_CadenceOff(__LONG32 lCadenceOff) = 0;
    virtual HRESULT WINAPI get_Volume(__LONG32 *plVolume) = 0;
    virtual HRESULT WINAPI put_Volume(__LONG32 lVolume) = 0;
  };
#else
  typedef struct ITCustomToneVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCustomTone *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCustomTone *This);
      ULONG (WINAPI *Release)(ITCustomTone *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCustomTone *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCustomTone *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCustomTone *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCustomTone *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Frequency)(ITCustomTone *This,__LONG32 *plFrequency);
      HRESULT (WINAPI *put_Frequency)(ITCustomTone *This,__LONG32 lFrequency);
      HRESULT (WINAPI *get_CadenceOn)(ITCustomTone *This,__LONG32 *plCadenceOn);
      HRESULT (WINAPI *put_CadenceOn)(ITCustomTone *This,__LONG32 CadenceOn);
      HRESULT (WINAPI *get_CadenceOff)(ITCustomTone *This,__LONG32 *plCadenceOff);
      HRESULT (WINAPI *put_CadenceOff)(ITCustomTone *This,__LONG32 lCadenceOff);
      HRESULT (WINAPI *get_Volume)(ITCustomTone *This,__LONG32 *plVolume);
      HRESULT (WINAPI *put_Volume)(ITCustomTone *This,__LONG32 lVolume);
    END_INTERFACE
  } ITCustomToneVtbl;
  struct ITCustomTone {
    CONST_VTBL struct ITCustomToneVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCustomTone_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCustomTone_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCustomTone_Release(This) (This)->lpVtbl->Release(This)
#define ITCustomTone_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCustomTone_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCustomTone_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCustomTone_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCustomTone_get_Frequency(This,plFrequency) (This)->lpVtbl->get_Frequency(This,plFrequency)
#define ITCustomTone_put_Frequency(This,lFrequency) (This)->lpVtbl->put_Frequency(This,lFrequency)
#define ITCustomTone_get_CadenceOn(This,plCadenceOn) (This)->lpVtbl->get_CadenceOn(This,plCadenceOn)
#define ITCustomTone_put_CadenceOn(This,CadenceOn) (This)->lpVtbl->put_CadenceOn(This,CadenceOn)
#define ITCustomTone_get_CadenceOff(This,plCadenceOff) (This)->lpVtbl->get_CadenceOff(This,plCadenceOff)
#define ITCustomTone_put_CadenceOff(This,lCadenceOff) (This)->lpVtbl->put_CadenceOff(This,lCadenceOff)
#define ITCustomTone_get_Volume(This,plVolume) (This)->lpVtbl->get_Volume(This,plVolume)
#define ITCustomTone_put_Volume(This,lVolume) (This)->lpVtbl->put_Volume(This,lVolume)
#endif
#endif
  HRESULT WINAPI ITCustomTone_get_Frequency_Proxy(ITCustomTone *This,__LONG32 *plFrequency);
  void __RPC_STUB ITCustomTone_get_Frequency_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCustomTone_put_Frequency_Proxy(ITCustomTone *This,__LONG32 lFrequency);
  void __RPC_STUB ITCustomTone_put_Frequency_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCustomTone_get_CadenceOn_Proxy(ITCustomTone *This,__LONG32 *plCadenceOn);
  void __RPC_STUB ITCustomTone_get_CadenceOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCustomTone_put_CadenceOn_Proxy(ITCustomTone *This,__LONG32 CadenceOn);
  void __RPC_STUB ITCustomTone_put_CadenceOn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCustomTone_get_CadenceOff_Proxy(ITCustomTone *This,__LONG32 *plCadenceOff);
  void __RPC_STUB ITCustomTone_get_CadenceOff_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCustomTone_put_CadenceOff_Proxy(ITCustomTone *This,__LONG32 lCadenceOff);
  void __RPC_STUB ITCustomTone_put_CadenceOff_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCustomTone_get_Volume_Proxy(ITCustomTone *This,__LONG32 *plVolume);
  void __RPC_STUB ITCustomTone_get_Volume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCustomTone_put_Volume_Proxy(ITCustomTone *This,__LONG32 lVolume);
  void __RPC_STUB ITCustomTone_put_Volume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumPhone_INTERFACE_DEFINED__
#define __IEnumPhone_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumPhone;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumPhone : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITPhone **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumPhone **ppEnum) = 0;
  };
#else
  typedef struct IEnumPhoneVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumPhone *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumPhone *This);
      ULONG (WINAPI *Release)(IEnumPhone *This);
      HRESULT (WINAPI *Next)(IEnumPhone *This,ULONG celt,ITPhone **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumPhone *This);
      HRESULT (WINAPI *Skip)(IEnumPhone *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumPhone *This,IEnumPhone **ppEnum);
    END_INTERFACE
  } IEnumPhoneVtbl;
  struct IEnumPhone {
    CONST_VTBL struct IEnumPhoneVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumPhone_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumPhone_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumPhone_Release(This) (This)->lpVtbl->Release(This)
#define IEnumPhone_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumPhone_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumPhone_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumPhone_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumPhone_Next_Proxy(IEnumPhone *This,ULONG celt,ITPhone **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumPhone_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPhone_Reset_Proxy(IEnumPhone *This);
  void __RPC_STUB IEnumPhone_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPhone_Skip_Proxy(IEnumPhone *This,ULONG celt);
  void __RPC_STUB IEnumPhone_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPhone_Clone_Proxy(IEnumPhone *This,IEnumPhone **ppEnum);
  void __RPC_STUB IEnumPhone_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumTerminal_INTERFACE_DEFINED__
#define __IEnumTerminal_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumTerminal;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumTerminal : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITTerminal **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumTerminal **ppEnum) = 0;
  };
#else
  typedef struct IEnumTerminalVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumTerminal *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumTerminal *This);
      ULONG (WINAPI *Release)(IEnumTerminal *This);
      HRESULT (WINAPI *Next)(IEnumTerminal *This,ULONG celt,ITTerminal **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumTerminal *This);
      HRESULT (WINAPI *Skip)(IEnumTerminal *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumTerminal *This,IEnumTerminal **ppEnum);
    END_INTERFACE
  } IEnumTerminalVtbl;
  struct IEnumTerminal {
    CONST_VTBL struct IEnumTerminalVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumTerminal_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumTerminal_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumTerminal_Release(This) (This)->lpVtbl->Release(This)
#define IEnumTerminal_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumTerminal_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumTerminal_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumTerminal_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumTerminal_Next_Proxy(IEnumTerminal *This,ULONG celt,ITTerminal **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumTerminal_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumTerminal_Reset_Proxy(IEnumTerminal *This);
  void __RPC_STUB IEnumTerminal_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumTerminal_Skip_Proxy(IEnumTerminal *This,ULONG celt);
  void __RPC_STUB IEnumTerminal_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumTerminal_Clone_Proxy(IEnumTerminal *This,IEnumTerminal **ppEnum);
  void __RPC_STUB IEnumTerminal_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumTerminalClass_INTERFACE_DEFINED__
#define __IEnumTerminalClass_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumTerminalClass;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumTerminalClass : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,GUID *pElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumTerminalClass **ppEnum) = 0;
  };
#else
  typedef struct IEnumTerminalClassVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumTerminalClass *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumTerminalClass *This);
      ULONG (WINAPI *Release)(IEnumTerminalClass *This);
      HRESULT (WINAPI *Next)(IEnumTerminalClass *This,ULONG celt,GUID *pElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumTerminalClass *This);
      HRESULT (WINAPI *Skip)(IEnumTerminalClass *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumTerminalClass *This,IEnumTerminalClass **ppEnum);
    END_INTERFACE
  } IEnumTerminalClassVtbl;
  struct IEnumTerminalClass {
    CONST_VTBL struct IEnumTerminalClassVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumTerminalClass_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumTerminalClass_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumTerminalClass_Release(This) (This)->lpVtbl->Release(This)
#define IEnumTerminalClass_Next(This,celt,pElements,pceltFetched) (This)->lpVtbl->Next(This,celt,pElements,pceltFetched)
#define IEnumTerminalClass_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumTerminalClass_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumTerminalClass_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumTerminalClass_Next_Proxy(IEnumTerminalClass *This,ULONG celt,GUID *pElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumTerminalClass_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumTerminalClass_Reset_Proxy(IEnumTerminalClass *This);
  void __RPC_STUB IEnumTerminalClass_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumTerminalClass_Skip_Proxy(IEnumTerminalClass *This,ULONG celt);
  void __RPC_STUB IEnumTerminalClass_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumTerminalClass_Clone_Proxy(IEnumTerminalClass *This,IEnumTerminalClass **ppEnum);
  void __RPC_STUB IEnumTerminalClass_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumCall_INTERFACE_DEFINED__
#define __IEnumCall_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumCall;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumCall : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITCallInfo **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumCall **ppEnum) = 0;
  };
#else
  typedef struct IEnumCallVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumCall *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumCall *This);
      ULONG (WINAPI *Release)(IEnumCall *This);
      HRESULT (WINAPI *Next)(IEnumCall *This,ULONG celt,ITCallInfo **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumCall *This);
      HRESULT (WINAPI *Skip)(IEnumCall *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumCall *This,IEnumCall **ppEnum);
    END_INTERFACE
  } IEnumCallVtbl;
  struct IEnumCall {
    CONST_VTBL struct IEnumCallVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumCall_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumCall_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumCall_Release(This) (This)->lpVtbl->Release(This)
#define IEnumCall_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumCall_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumCall_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumCall_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumCall_Next_Proxy(IEnumCall *This,ULONG celt,ITCallInfo **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumCall_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCall_Reset_Proxy(IEnumCall *This);
  void __RPC_STUB IEnumCall_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCall_Skip_Proxy(IEnumCall *This,ULONG celt);
  void __RPC_STUB IEnumCall_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCall_Clone_Proxy(IEnumCall *This,IEnumCall **ppEnum);
  void __RPC_STUB IEnumCall_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumAddress_INTERFACE_DEFINED__
#define __IEnumAddress_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumAddress;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumAddress : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITAddress **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumAddress **ppEnum) = 0;
  };
#else
  typedef struct IEnumAddressVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumAddress *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumAddress *This);
      ULONG (WINAPI *Release)(IEnumAddress *This);
      HRESULT (WINAPI *Next)(IEnumAddress *This,ULONG celt,ITAddress **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumAddress *This);
      HRESULT (WINAPI *Skip)(IEnumAddress *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumAddress *This,IEnumAddress **ppEnum);
    END_INTERFACE
  } IEnumAddressVtbl;
  struct IEnumAddress {
    CONST_VTBL struct IEnumAddressVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumAddress_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumAddress_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumAddress_Release(This) (This)->lpVtbl->Release(This)
#define IEnumAddress_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumAddress_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumAddress_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumAddress_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumAddress_Next_Proxy(IEnumAddress *This,ULONG celt,ITAddress **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumAddress_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAddress_Reset_Proxy(IEnumAddress *This);
  void __RPC_STUB IEnumAddress_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAddress_Skip_Proxy(IEnumAddress *This,ULONG celt);
  void __RPC_STUB IEnumAddress_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumAddress_Clone_Proxy(IEnumAddress *This,IEnumAddress **ppEnum);
  void __RPC_STUB IEnumAddress_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumCallHub_INTERFACE_DEFINED__
#define __IEnumCallHub_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumCallHub;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumCallHub : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITCallHub **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumCallHub **ppEnum) = 0;
  };
#else
  typedef struct IEnumCallHubVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumCallHub *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumCallHub *This);
      ULONG (WINAPI *Release)(IEnumCallHub *This);
      HRESULT (WINAPI *Next)(IEnumCallHub *This,ULONG celt,ITCallHub **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumCallHub *This);
      HRESULT (WINAPI *Skip)(IEnumCallHub *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumCallHub *This,IEnumCallHub **ppEnum);
    END_INTERFACE
  } IEnumCallHubVtbl;
  struct IEnumCallHub {
    CONST_VTBL struct IEnumCallHubVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumCallHub_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumCallHub_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumCallHub_Release(This) (This)->lpVtbl->Release(This)
#define IEnumCallHub_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumCallHub_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumCallHub_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumCallHub_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumCallHub_Next_Proxy(IEnumCallHub *This,ULONG celt,ITCallHub **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumCallHub_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCallHub_Reset_Proxy(IEnumCallHub *This);
  void __RPC_STUB IEnumCallHub_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCallHub_Skip_Proxy(IEnumCallHub *This,ULONG celt);
  void __RPC_STUB IEnumCallHub_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCallHub_Clone_Proxy(IEnumCallHub *This,IEnumCallHub **ppEnum);
  void __RPC_STUB IEnumCallHub_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumBstr_INTERFACE_DEFINED__
#define __IEnumBstr_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumBstr;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumBstr : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,BSTR *ppStrings,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumBstr **ppEnum) = 0;
  };
#else
  typedef struct IEnumBstrVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumBstr *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumBstr *This);
      ULONG (WINAPI *Release)(IEnumBstr *This);
      HRESULT (WINAPI *Next)(IEnumBstr *This,ULONG celt,BSTR *ppStrings,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumBstr *This);
      HRESULT (WINAPI *Skip)(IEnumBstr *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumBstr *This,IEnumBstr **ppEnum);
    END_INTERFACE
  } IEnumBstrVtbl;
  struct IEnumBstr {
    CONST_VTBL struct IEnumBstrVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumBstr_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumBstr_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumBstr_Release(This) (This)->lpVtbl->Release(This)
#define IEnumBstr_Next(This,celt,ppStrings,pceltFetched) (This)->lpVtbl->Next(This,celt,ppStrings,pceltFetched)
#define IEnumBstr_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumBstr_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumBstr_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumBstr_Next_Proxy(IEnumBstr *This,ULONG celt,BSTR *ppStrings,ULONG *pceltFetched);
  void __RPC_STUB IEnumBstr_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBstr_Reset_Proxy(IEnumBstr *This);
  void __RPC_STUB IEnumBstr_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBstr_Skip_Proxy(IEnumBstr *This,ULONG celt);
  void __RPC_STUB IEnumBstr_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBstr_Clone_Proxy(IEnumBstr *This,IEnumBstr **ppEnum);
  void __RPC_STUB IEnumBstr_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumPluggableTerminalClassInfo_INTERFACE_DEFINED__
#define __IEnumPluggableTerminalClassInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumPluggableTerminalClassInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumPluggableTerminalClassInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITPluggableTerminalClassInfo **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumPluggableTerminalClassInfo **ppEnum) = 0;
  };
#else
  typedef struct IEnumPluggableTerminalClassInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumPluggableTerminalClassInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumPluggableTerminalClassInfo *This);
      ULONG (WINAPI *Release)(IEnumPluggableTerminalClassInfo *This);
      HRESULT (WINAPI *Next)(IEnumPluggableTerminalClassInfo *This,ULONG celt,ITPluggableTerminalClassInfo **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumPluggableTerminalClassInfo *This);
      HRESULT (WINAPI *Skip)(IEnumPluggableTerminalClassInfo *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumPluggableTerminalClassInfo *This,IEnumPluggableTerminalClassInfo **ppEnum);
    END_INTERFACE
  } IEnumPluggableTerminalClassInfoVtbl;
  struct IEnumPluggableTerminalClassInfo {
    CONST_VTBL struct IEnumPluggableTerminalClassInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumPluggableTerminalClassInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumPluggableTerminalClassInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumPluggableTerminalClassInfo_Release(This) (This)->lpVtbl->Release(This)
#define IEnumPluggableTerminalClassInfo_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumPluggableTerminalClassInfo_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumPluggableTerminalClassInfo_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumPluggableTerminalClassInfo_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumPluggableTerminalClassInfo_Next_Proxy(IEnumPluggableTerminalClassInfo *This,ULONG celt,ITPluggableTerminalClassInfo **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumPluggableTerminalClassInfo_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPluggableTerminalClassInfo_Reset_Proxy(IEnumPluggableTerminalClassInfo *This);
  void __RPC_STUB IEnumPluggableTerminalClassInfo_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPluggableTerminalClassInfo_Skip_Proxy(IEnumPluggableTerminalClassInfo *This,ULONG celt);
  void __RPC_STUB IEnumPluggableTerminalClassInfo_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPluggableTerminalClassInfo_Clone_Proxy(IEnumPluggableTerminalClassInfo *This,IEnumPluggableTerminalClassInfo **ppEnum);
  void __RPC_STUB IEnumPluggableTerminalClassInfo_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumPluggableSuperclassInfo_INTERFACE_DEFINED__
#define __IEnumPluggableSuperclassInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumPluggableSuperclassInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumPluggableSuperclassInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITPluggableTerminalSuperclassInfo **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumPluggableSuperclassInfo **ppEnum) = 0;
  };
#else
  typedef struct IEnumPluggableSuperclassInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumPluggableSuperclassInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumPluggableSuperclassInfo *This);
      ULONG (WINAPI *Release)(IEnumPluggableSuperclassInfo *This);
      HRESULT (WINAPI *Next)(IEnumPluggableSuperclassInfo *This,ULONG celt,ITPluggableTerminalSuperclassInfo **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumPluggableSuperclassInfo *This);
      HRESULT (WINAPI *Skip)(IEnumPluggableSuperclassInfo *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumPluggableSuperclassInfo *This,IEnumPluggableSuperclassInfo **ppEnum);
    END_INTERFACE
  } IEnumPluggableSuperclassInfoVtbl;
  struct IEnumPluggableSuperclassInfo {
    CONST_VTBL struct IEnumPluggableSuperclassInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumPluggableSuperclassInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumPluggableSuperclassInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumPluggableSuperclassInfo_Release(This) (This)->lpVtbl->Release(This)
#define IEnumPluggableSuperclassInfo_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumPluggableSuperclassInfo_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumPluggableSuperclassInfo_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumPluggableSuperclassInfo_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumPluggableSuperclassInfo_Next_Proxy(IEnumPluggableSuperclassInfo *This,ULONG celt,ITPluggableTerminalSuperclassInfo **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumPluggableSuperclassInfo_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPluggableSuperclassInfo_Reset_Proxy(IEnumPluggableSuperclassInfo *This);
  void __RPC_STUB IEnumPluggableSuperclassInfo_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPluggableSuperclassInfo_Skip_Proxy(IEnumPluggableSuperclassInfo *This,ULONG celt);
  void __RPC_STUB IEnumPluggableSuperclassInfo_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumPluggableSuperclassInfo_Clone_Proxy(IEnumPluggableSuperclassInfo *This,IEnumPluggableSuperclassInfo **ppEnum);
  void __RPC_STUB IEnumPluggableSuperclassInfo_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITPhoneEvent_INTERFACE_DEFINED__
#define __ITPhoneEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITPhoneEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITPhoneEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Phone(ITPhone **ppPhone) = 0;
    virtual HRESULT WINAPI get_Event(PHONE_EVENT *pEvent) = 0;
    virtual HRESULT WINAPI get_ButtonState(PHONE_BUTTON_STATE *pState) = 0;
    virtual HRESULT WINAPI get_HookSwitchState(PHONE_HOOK_SWITCH_STATE *pState) = 0;
    virtual HRESULT WINAPI get_HookSwitchDevice(PHONE_HOOK_SWITCH_DEVICE *pDevice) = 0;
    virtual HRESULT WINAPI get_RingMode(__LONG32 *plRingMode) = 0;
    virtual HRESULT WINAPI get_ButtonLampId(__LONG32 *plButtonLampId) = 0;
    virtual HRESULT WINAPI get_NumberGathered(BSTR *ppNumber) = 0;
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCallInfo) = 0;
  };
#else
  typedef struct ITPhoneEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITPhoneEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITPhoneEvent *This);
      ULONG (WINAPI *Release)(ITPhoneEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITPhoneEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITPhoneEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITPhoneEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITPhoneEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Phone)(ITPhoneEvent *This,ITPhone **ppPhone);
      HRESULT (WINAPI *get_Event)(ITPhoneEvent *This,PHONE_EVENT *pEvent);
      HRESULT (WINAPI *get_ButtonState)(ITPhoneEvent *This,PHONE_BUTTON_STATE *pState);
      HRESULT (WINAPI *get_HookSwitchState)(ITPhoneEvent *This,PHONE_HOOK_SWITCH_STATE *pState);
      HRESULT (WINAPI *get_HookSwitchDevice)(ITPhoneEvent *This,PHONE_HOOK_SWITCH_DEVICE *pDevice);
      HRESULT (WINAPI *get_RingMode)(ITPhoneEvent *This,__LONG32 *plRingMode);
      HRESULT (WINAPI *get_ButtonLampId)(ITPhoneEvent *This,__LONG32 *plButtonLampId);
      HRESULT (WINAPI *get_NumberGathered)(ITPhoneEvent *This,BSTR *ppNumber);
      HRESULT (WINAPI *get_Call)(ITPhoneEvent *This,ITCallInfo **ppCallInfo);
    END_INTERFACE
  } ITPhoneEventVtbl;
  struct ITPhoneEvent {
    CONST_VTBL struct ITPhoneEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITPhoneEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITPhoneEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITPhoneEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITPhoneEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITPhoneEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITPhoneEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITPhoneEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITPhoneEvent_get_Phone(This,ppPhone) (This)->lpVtbl->get_Phone(This,ppPhone)
#define ITPhoneEvent_get_Event(This,pEvent) (This)->lpVtbl->get_Event(This,pEvent)
#define ITPhoneEvent_get_ButtonState(This,pState) (This)->lpVtbl->get_ButtonState(This,pState)
#define ITPhoneEvent_get_HookSwitchState(This,pState) (This)->lpVtbl->get_HookSwitchState(This,pState)
#define ITPhoneEvent_get_HookSwitchDevice(This,pDevice) (This)->lpVtbl->get_HookSwitchDevice(This,pDevice)
#define ITPhoneEvent_get_RingMode(This,plRingMode) (This)->lpVtbl->get_RingMode(This,plRingMode)
#define ITPhoneEvent_get_ButtonLampId(This,plButtonLampId) (This)->lpVtbl->get_ButtonLampId(This,plButtonLampId)
#define ITPhoneEvent_get_NumberGathered(This,ppNumber) (This)->lpVtbl->get_NumberGathered(This,ppNumber)
#define ITPhoneEvent_get_Call(This,ppCallInfo) (This)->lpVtbl->get_Call(This,ppCallInfo)
#endif
#endif
  HRESULT WINAPI ITPhoneEvent_get_Phone_Proxy(ITPhoneEvent *This,ITPhone **ppPhone);
  void __RPC_STUB ITPhoneEvent_get_Phone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhoneEvent_get_Event_Proxy(ITPhoneEvent *This,PHONE_EVENT *pEvent);
  void __RPC_STUB ITPhoneEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhoneEvent_get_ButtonState_Proxy(ITPhoneEvent *This,PHONE_BUTTON_STATE *pState);
  void __RPC_STUB ITPhoneEvent_get_ButtonState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhoneEvent_get_HookSwitchState_Proxy(ITPhoneEvent *This,PHONE_HOOK_SWITCH_STATE *pState);
  void __RPC_STUB ITPhoneEvent_get_HookSwitchState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhoneEvent_get_HookSwitchDevice_Proxy(ITPhoneEvent *This,PHONE_HOOK_SWITCH_DEVICE *pDevice);
  void __RPC_STUB ITPhoneEvent_get_HookSwitchDevice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhoneEvent_get_RingMode_Proxy(ITPhoneEvent *This,__LONG32 *plRingMode);
  void __RPC_STUB ITPhoneEvent_get_RingMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhoneEvent_get_ButtonLampId_Proxy(ITPhoneEvent *This,__LONG32 *plButtonLampId);
  void __RPC_STUB ITPhoneEvent_get_ButtonLampId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhoneEvent_get_NumberGathered_Proxy(ITPhoneEvent *This,BSTR *ppNumber);
  void __RPC_STUB ITPhoneEvent_get_NumberGathered_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhoneEvent_get_Call_Proxy(ITPhoneEvent *This,ITCallInfo **ppCallInfo);
  void __RPC_STUB ITPhoneEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCallStateEvent_INTERFACE_DEFINED__
#define __ITCallStateEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCallStateEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCallStateEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCallInfo) = 0;
    virtual HRESULT WINAPI get_State(CALL_STATE *pCallState) = 0;
    virtual HRESULT WINAPI get_Cause(CALL_STATE_EVENT_CAUSE *pCEC) = 0;
    virtual HRESULT WINAPI get_CallbackInstance(__LONG32 *plCallbackInstance) = 0;
  };
#else
  typedef struct ITCallStateEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCallStateEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCallStateEvent *This);
      ULONG (WINAPI *Release)(ITCallStateEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCallStateEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCallStateEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCallStateEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCallStateEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Call)(ITCallStateEvent *This,ITCallInfo **ppCallInfo);
      HRESULT (WINAPI *get_State)(ITCallStateEvent *This,CALL_STATE *pCallState);
      HRESULT (WINAPI *get_Cause)(ITCallStateEvent *This,CALL_STATE_EVENT_CAUSE *pCEC);
      HRESULT (WINAPI *get_CallbackInstance)(ITCallStateEvent *This,__LONG32 *plCallbackInstance);
    END_INTERFACE
  } ITCallStateEventVtbl;
  struct ITCallStateEvent {
    CONST_VTBL struct ITCallStateEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCallStateEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCallStateEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCallStateEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITCallStateEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCallStateEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCallStateEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCallStateEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCallStateEvent_get_Call(This,ppCallInfo) (This)->lpVtbl->get_Call(This,ppCallInfo)
#define ITCallStateEvent_get_State(This,pCallState) (This)->lpVtbl->get_State(This,pCallState)
#define ITCallStateEvent_get_Cause(This,pCEC) (This)->lpVtbl->get_Cause(This,pCEC)
#define ITCallStateEvent_get_CallbackInstance(This,plCallbackInstance) (This)->lpVtbl->get_CallbackInstance(This,plCallbackInstance)
#endif
#endif
  HRESULT WINAPI ITCallStateEvent_get_Call_Proxy(ITCallStateEvent *This,ITCallInfo **ppCallInfo);
  void __RPC_STUB ITCallStateEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallStateEvent_get_State_Proxy(ITCallStateEvent *This,CALL_STATE *pCallState);
  void __RPC_STUB ITCallStateEvent_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallStateEvent_get_Cause_Proxy(ITCallStateEvent *This,CALL_STATE_EVENT_CAUSE *pCEC);
  void __RPC_STUB ITCallStateEvent_get_Cause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallStateEvent_get_CallbackInstance_Proxy(ITCallStateEvent *This,__LONG32 *plCallbackInstance);
  void __RPC_STUB ITCallStateEvent_get_CallbackInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITPhoneDeviceSpecificEvent_INTERFACE_DEFINED__
#define __ITPhoneDeviceSpecificEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITPhoneDeviceSpecificEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITPhoneDeviceSpecificEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Phone(ITPhone **ppPhone) = 0;
    virtual HRESULT WINAPI get_lParam1(__LONG32 *pParam1) = 0;
    virtual HRESULT WINAPI get_lParam2(__LONG32 *pParam2) = 0;
    virtual HRESULT WINAPI get_lParam3(__LONG32 *pParam3) = 0;
  };
#else
  typedef struct ITPhoneDeviceSpecificEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITPhoneDeviceSpecificEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITPhoneDeviceSpecificEvent *This);
      ULONG (WINAPI *Release)(ITPhoneDeviceSpecificEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITPhoneDeviceSpecificEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITPhoneDeviceSpecificEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITPhoneDeviceSpecificEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITPhoneDeviceSpecificEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Phone)(ITPhoneDeviceSpecificEvent *This,ITPhone **ppPhone);
      HRESULT (WINAPI *get_lParam1)(ITPhoneDeviceSpecificEvent *This,__LONG32 *pParam1);
      HRESULT (WINAPI *get_lParam2)(ITPhoneDeviceSpecificEvent *This,__LONG32 *pParam2);
      HRESULT (WINAPI *get_lParam3)(ITPhoneDeviceSpecificEvent *This,__LONG32 *pParam3);
    END_INTERFACE
  } ITPhoneDeviceSpecificEventVtbl;
  struct ITPhoneDeviceSpecificEvent {
    CONST_VTBL struct ITPhoneDeviceSpecificEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITPhoneDeviceSpecificEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITPhoneDeviceSpecificEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITPhoneDeviceSpecificEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITPhoneDeviceSpecificEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITPhoneDeviceSpecificEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITPhoneDeviceSpecificEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITPhoneDeviceSpecificEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITPhoneDeviceSpecificEvent_get_Phone(This,ppPhone) (This)->lpVtbl->get_Phone(This,ppPhone)
#define ITPhoneDeviceSpecificEvent_get_lParam1(This,pParam1) (This)->lpVtbl->get_lParam1(This,pParam1)
#define ITPhoneDeviceSpecificEvent_get_lParam2(This,pParam2) (This)->lpVtbl->get_lParam2(This,pParam2)
#define ITPhoneDeviceSpecificEvent_get_lParam3(This,pParam3) (This)->lpVtbl->get_lParam3(This,pParam3)
#endif
#endif
  HRESULT WINAPI ITPhoneDeviceSpecificEvent_get_Phone_Proxy(ITPhoneDeviceSpecificEvent *This,ITPhone **ppPhone);
  void __RPC_STUB ITPhoneDeviceSpecificEvent_get_Phone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhoneDeviceSpecificEvent_get_lParam1_Proxy(ITPhoneDeviceSpecificEvent *This,__LONG32 *pParam1);
  void __RPC_STUB ITPhoneDeviceSpecificEvent_get_lParam1_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhoneDeviceSpecificEvent_get_lParam2_Proxy(ITPhoneDeviceSpecificEvent *This,__LONG32 *pParam2);
  void __RPC_STUB ITPhoneDeviceSpecificEvent_get_lParam2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITPhoneDeviceSpecificEvent_get_lParam3_Proxy(ITPhoneDeviceSpecificEvent *This,__LONG32 *pParam3);
  void __RPC_STUB ITPhoneDeviceSpecificEvent_get_lParam3_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCallMediaEvent_INTERFACE_DEFINED__
#define __ITCallMediaEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCallMediaEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCallMediaEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCallInfo) = 0;
    virtual HRESULT WINAPI get_Event(CALL_MEDIA_EVENT *pCallMediaEvent) = 0;
    virtual HRESULT WINAPI get_Error(HRESULT *phrError) = 0;
    virtual HRESULT WINAPI get_Terminal(ITTerminal **ppTerminal) = 0;
    virtual HRESULT WINAPI get_Stream(ITStream **ppStream) = 0;
    virtual HRESULT WINAPI get_Cause(CALL_MEDIA_EVENT_CAUSE *pCause) = 0;
  };
#else
  typedef struct ITCallMediaEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCallMediaEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCallMediaEvent *This);
      ULONG (WINAPI *Release)(ITCallMediaEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCallMediaEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCallMediaEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCallMediaEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCallMediaEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Call)(ITCallMediaEvent *This,ITCallInfo **ppCallInfo);
      HRESULT (WINAPI *get_Event)(ITCallMediaEvent *This,CALL_MEDIA_EVENT *pCallMediaEvent);
      HRESULT (WINAPI *get_Error)(ITCallMediaEvent *This,HRESULT *phrError);
      HRESULT (WINAPI *get_Terminal)(ITCallMediaEvent *This,ITTerminal **ppTerminal);
      HRESULT (WINAPI *get_Stream)(ITCallMediaEvent *This,ITStream **ppStream);
      HRESULT (WINAPI *get_Cause)(ITCallMediaEvent *This,CALL_MEDIA_EVENT_CAUSE *pCause);
    END_INTERFACE
  } ITCallMediaEventVtbl;
  struct ITCallMediaEvent {
    CONST_VTBL struct ITCallMediaEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCallMediaEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCallMediaEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCallMediaEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITCallMediaEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCallMediaEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCallMediaEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCallMediaEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCallMediaEvent_get_Call(This,ppCallInfo) (This)->lpVtbl->get_Call(This,ppCallInfo)
#define ITCallMediaEvent_get_Event(This,pCallMediaEvent) (This)->lpVtbl->get_Event(This,pCallMediaEvent)
#define ITCallMediaEvent_get_Error(This,phrError) (This)->lpVtbl->get_Error(This,phrError)
#define ITCallMediaEvent_get_Terminal(This,ppTerminal) (This)->lpVtbl->get_Terminal(This,ppTerminal)
#define ITCallMediaEvent_get_Stream(This,ppStream) (This)->lpVtbl->get_Stream(This,ppStream)
#define ITCallMediaEvent_get_Cause(This,pCause) (This)->lpVtbl->get_Cause(This,pCause)
#endif
#endif
  HRESULT WINAPI ITCallMediaEvent_get_Call_Proxy(ITCallMediaEvent *This,ITCallInfo **ppCallInfo);
  void __RPC_STUB ITCallMediaEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallMediaEvent_get_Event_Proxy(ITCallMediaEvent *This,CALL_MEDIA_EVENT *pCallMediaEvent);
  void __RPC_STUB ITCallMediaEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallMediaEvent_get_Error_Proxy(ITCallMediaEvent *This,HRESULT *phrError);
  void __RPC_STUB ITCallMediaEvent_get_Error_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallMediaEvent_get_Terminal_Proxy(ITCallMediaEvent *This,ITTerminal **ppTerminal);
  void __RPC_STUB ITCallMediaEvent_get_Terminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallMediaEvent_get_Stream_Proxy(ITCallMediaEvent *This,ITStream **ppStream);
  void __RPC_STUB ITCallMediaEvent_get_Stream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallMediaEvent_get_Cause_Proxy(ITCallMediaEvent *This,CALL_MEDIA_EVENT_CAUSE *pCause);
  void __RPC_STUB ITCallMediaEvent_get_Cause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITDigitDetectionEvent_INTERFACE_DEFINED__
#define __ITDigitDetectionEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITDigitDetectionEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITDigitDetectionEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCallInfo) = 0;
    virtual HRESULT WINAPI get_Digit(unsigned char *pucDigit) = 0;
    virtual HRESULT WINAPI get_DigitMode(TAPI_DIGITMODE *pDigitMode) = 0;
    virtual HRESULT WINAPI get_TickCount(__LONG32 *plTickCount) = 0;
    virtual HRESULT WINAPI get_CallbackInstance(__LONG32 *plCallbackInstance) = 0;
  };
#else
  typedef struct ITDigitDetectionEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITDigitDetectionEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITDigitDetectionEvent *This);
      ULONG (WINAPI *Release)(ITDigitDetectionEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITDigitDetectionEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITDigitDetectionEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITDigitDetectionEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITDigitDetectionEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Call)(ITDigitDetectionEvent *This,ITCallInfo **ppCallInfo);
      HRESULT (WINAPI *get_Digit)(ITDigitDetectionEvent *This,unsigned char *pucDigit);
      HRESULT (WINAPI *get_DigitMode)(ITDigitDetectionEvent *This,TAPI_DIGITMODE *pDigitMode);
      HRESULT (WINAPI *get_TickCount)(ITDigitDetectionEvent *This,__LONG32 *plTickCount);
      HRESULT (WINAPI *get_CallbackInstance)(ITDigitDetectionEvent *This,__LONG32 *plCallbackInstance);
    END_INTERFACE
  } ITDigitDetectionEventVtbl;
  struct ITDigitDetectionEvent {
    CONST_VTBL struct ITDigitDetectionEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITDigitDetectionEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITDigitDetectionEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITDigitDetectionEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITDigitDetectionEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITDigitDetectionEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITDigitDetectionEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITDigitDetectionEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITDigitDetectionEvent_get_Call(This,ppCallInfo) (This)->lpVtbl->get_Call(This,ppCallInfo)
#define ITDigitDetectionEvent_get_Digit(This,pucDigit) (This)->lpVtbl->get_Digit(This,pucDigit)
#define ITDigitDetectionEvent_get_DigitMode(This,pDigitMode) (This)->lpVtbl->get_DigitMode(This,pDigitMode)
#define ITDigitDetectionEvent_get_TickCount(This,plTickCount) (This)->lpVtbl->get_TickCount(This,plTickCount)
#define ITDigitDetectionEvent_get_CallbackInstance(This,plCallbackInstance) (This)->lpVtbl->get_CallbackInstance(This,plCallbackInstance)
#endif
#endif
  HRESULT WINAPI ITDigitDetectionEvent_get_Call_Proxy(ITDigitDetectionEvent *This,ITCallInfo **ppCallInfo);
  void __RPC_STUB ITDigitDetectionEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDigitDetectionEvent_get_Digit_Proxy(ITDigitDetectionEvent *This,unsigned char *pucDigit);
  void __RPC_STUB ITDigitDetectionEvent_get_Digit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDigitDetectionEvent_get_DigitMode_Proxy(ITDigitDetectionEvent *This,TAPI_DIGITMODE *pDigitMode);
  void __RPC_STUB ITDigitDetectionEvent_get_DigitMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDigitDetectionEvent_get_TickCount_Proxy(ITDigitDetectionEvent *This,__LONG32 *plTickCount);
  void __RPC_STUB ITDigitDetectionEvent_get_TickCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDigitDetectionEvent_get_CallbackInstance_Proxy(ITDigitDetectionEvent *This,__LONG32 *plCallbackInstance);
  void __RPC_STUB ITDigitDetectionEvent_get_CallbackInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITDigitGenerationEvent_INTERFACE_DEFINED__
#define __ITDigitGenerationEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITDigitGenerationEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITDigitGenerationEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCallInfo) = 0;
    virtual HRESULT WINAPI get_GenerationTermination(__LONG32 *plGenerationTermination) = 0;
    virtual HRESULT WINAPI get_TickCount(__LONG32 *plTickCount) = 0;
    virtual HRESULT WINAPI get_CallbackInstance(__LONG32 *plCallbackInstance) = 0;
  };
#else
  typedef struct ITDigitGenerationEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITDigitGenerationEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITDigitGenerationEvent *This);
      ULONG (WINAPI *Release)(ITDigitGenerationEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITDigitGenerationEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITDigitGenerationEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITDigitGenerationEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITDigitGenerationEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Call)(ITDigitGenerationEvent *This,ITCallInfo **ppCallInfo);
      HRESULT (WINAPI *get_GenerationTermination)(ITDigitGenerationEvent *This,__LONG32 *plGenerationTermination);
      HRESULT (WINAPI *get_TickCount)(ITDigitGenerationEvent *This,__LONG32 *plTickCount);
      HRESULT (WINAPI *get_CallbackInstance)(ITDigitGenerationEvent *This,__LONG32 *plCallbackInstance);
    END_INTERFACE
  } ITDigitGenerationEventVtbl;
  struct ITDigitGenerationEvent {
    CONST_VTBL struct ITDigitGenerationEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITDigitGenerationEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITDigitGenerationEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITDigitGenerationEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITDigitGenerationEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITDigitGenerationEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITDigitGenerationEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITDigitGenerationEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITDigitGenerationEvent_get_Call(This,ppCallInfo) (This)->lpVtbl->get_Call(This,ppCallInfo)
#define ITDigitGenerationEvent_get_GenerationTermination(This,plGenerationTermination) (This)->lpVtbl->get_GenerationTermination(This,plGenerationTermination)
#define ITDigitGenerationEvent_get_TickCount(This,plTickCount) (This)->lpVtbl->get_TickCount(This,plTickCount)
#define ITDigitGenerationEvent_get_CallbackInstance(This,plCallbackInstance) (This)->lpVtbl->get_CallbackInstance(This,plCallbackInstance)
#endif
#endif
  HRESULT WINAPI ITDigitGenerationEvent_get_Call_Proxy(ITDigitGenerationEvent *This,ITCallInfo **ppCallInfo);
  void __RPC_STUB ITDigitGenerationEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDigitGenerationEvent_get_GenerationTermination_Proxy(ITDigitGenerationEvent *This,__LONG32 *plGenerationTermination);
  void __RPC_STUB ITDigitGenerationEvent_get_GenerationTermination_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDigitGenerationEvent_get_TickCount_Proxy(ITDigitGenerationEvent *This,__LONG32 *plTickCount);
  void __RPC_STUB ITDigitGenerationEvent_get_TickCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDigitGenerationEvent_get_CallbackInstance_Proxy(ITDigitGenerationEvent *This,__LONG32 *plCallbackInstance);
  void __RPC_STUB ITDigitGenerationEvent_get_CallbackInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITDigitsGatheredEvent_INTERFACE_DEFINED__
#define __ITDigitsGatheredEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITDigitsGatheredEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITDigitsGatheredEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCallInfo) = 0;
    virtual HRESULT WINAPI get_Digits(BSTR *ppDigits) = 0;
    virtual HRESULT WINAPI get_GatherTermination(TAPI_GATHERTERM *pGatherTermination) = 0;
    virtual HRESULT WINAPI get_TickCount(__LONG32 *plTickCount) = 0;
    virtual HRESULT WINAPI get_CallbackInstance(__LONG32 *plCallbackInstance) = 0;
  };
#else
  typedef struct ITDigitsGatheredEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITDigitsGatheredEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITDigitsGatheredEvent *This);
      ULONG (WINAPI *Release)(ITDigitsGatheredEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITDigitsGatheredEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITDigitsGatheredEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITDigitsGatheredEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITDigitsGatheredEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Call)(ITDigitsGatheredEvent *This,ITCallInfo **ppCallInfo);
      HRESULT (WINAPI *get_Digits)(ITDigitsGatheredEvent *This,BSTR *ppDigits);
      HRESULT (WINAPI *get_GatherTermination)(ITDigitsGatheredEvent *This,TAPI_GATHERTERM *pGatherTermination);
      HRESULT (WINAPI *get_TickCount)(ITDigitsGatheredEvent *This,__LONG32 *plTickCount);
      HRESULT (WINAPI *get_CallbackInstance)(ITDigitsGatheredEvent *This,__LONG32 *plCallbackInstance);
    END_INTERFACE
  } ITDigitsGatheredEventVtbl;
  struct ITDigitsGatheredEvent {
    CONST_VTBL struct ITDigitsGatheredEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITDigitsGatheredEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITDigitsGatheredEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITDigitsGatheredEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITDigitsGatheredEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITDigitsGatheredEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITDigitsGatheredEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITDigitsGatheredEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITDigitsGatheredEvent_get_Call(This,ppCallInfo) (This)->lpVtbl->get_Call(This,ppCallInfo)
#define ITDigitsGatheredEvent_get_Digits(This,ppDigits) (This)->lpVtbl->get_Digits(This,ppDigits)
#define ITDigitsGatheredEvent_get_GatherTermination(This,pGatherTermination) (This)->lpVtbl->get_GatherTermination(This,pGatherTermination)
#define ITDigitsGatheredEvent_get_TickCount(This,plTickCount) (This)->lpVtbl->get_TickCount(This,plTickCount)
#define ITDigitsGatheredEvent_get_CallbackInstance(This,plCallbackInstance) (This)->lpVtbl->get_CallbackInstance(This,plCallbackInstance)
#endif
#endif
  HRESULT WINAPI ITDigitsGatheredEvent_get_Call_Proxy(ITDigitsGatheredEvent *This,ITCallInfo **ppCallInfo);
  void __RPC_STUB ITDigitsGatheredEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDigitsGatheredEvent_get_Digits_Proxy(ITDigitsGatheredEvent *This,BSTR *ppDigits);
  void __RPC_STUB ITDigitsGatheredEvent_get_Digits_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDigitsGatheredEvent_get_GatherTermination_Proxy(ITDigitsGatheredEvent *This,TAPI_GATHERTERM *pGatherTermination);
  void __RPC_STUB ITDigitsGatheredEvent_get_GatherTermination_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDigitsGatheredEvent_get_TickCount_Proxy(ITDigitsGatheredEvent *This,__LONG32 *plTickCount);
  void __RPC_STUB ITDigitsGatheredEvent_get_TickCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITDigitsGatheredEvent_get_CallbackInstance_Proxy(ITDigitsGatheredEvent *This,__LONG32 *plCallbackInstance);
  void __RPC_STUB ITDigitsGatheredEvent_get_CallbackInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITToneDetectionEvent_INTERFACE_DEFINED__
#define __ITToneDetectionEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITToneDetectionEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITToneDetectionEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCallInfo) = 0;
    virtual HRESULT WINAPI get_AppSpecific(__LONG32 *plAppSpecific) = 0;
    virtual HRESULT WINAPI get_TickCount(__LONG32 *plTickCount) = 0;
    virtual HRESULT WINAPI get_CallbackInstance(__LONG32 *plCallbackInstance) = 0;
  };
#else
  typedef struct ITToneDetectionEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITToneDetectionEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITToneDetectionEvent *This);
      ULONG (WINAPI *Release)(ITToneDetectionEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITToneDetectionEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITToneDetectionEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITToneDetectionEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITToneDetectionEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Call)(ITToneDetectionEvent *This,ITCallInfo **ppCallInfo);
      HRESULT (WINAPI *get_AppSpecific)(ITToneDetectionEvent *This,__LONG32 *plAppSpecific);
      HRESULT (WINAPI *get_TickCount)(ITToneDetectionEvent *This,__LONG32 *plTickCount);
      HRESULT (WINAPI *get_CallbackInstance)(ITToneDetectionEvent *This,__LONG32 *plCallbackInstance);
    END_INTERFACE
  } ITToneDetectionEventVtbl;
  struct ITToneDetectionEvent {
    CONST_VTBL struct ITToneDetectionEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITToneDetectionEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITToneDetectionEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITToneDetectionEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITToneDetectionEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITToneDetectionEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITToneDetectionEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITToneDetectionEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITToneDetectionEvent_get_Call(This,ppCallInfo) (This)->lpVtbl->get_Call(This,ppCallInfo)
#define ITToneDetectionEvent_get_AppSpecific(This,plAppSpecific) (This)->lpVtbl->get_AppSpecific(This,plAppSpecific)
#define ITToneDetectionEvent_get_TickCount(This,plTickCount) (This)->lpVtbl->get_TickCount(This,plTickCount)
#define ITToneDetectionEvent_get_CallbackInstance(This,plCallbackInstance) (This)->lpVtbl->get_CallbackInstance(This,plCallbackInstance)
#endif
#endif
  HRESULT WINAPI ITToneDetectionEvent_get_Call_Proxy(ITToneDetectionEvent *This,ITCallInfo **ppCallInfo);
  void __RPC_STUB ITToneDetectionEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITToneDetectionEvent_get_AppSpecific_Proxy(ITToneDetectionEvent *This,__LONG32 *plAppSpecific);
  void __RPC_STUB ITToneDetectionEvent_get_AppSpecific_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITToneDetectionEvent_get_TickCount_Proxy(ITToneDetectionEvent *This,__LONG32 *plTickCount);
  void __RPC_STUB ITToneDetectionEvent_get_TickCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITToneDetectionEvent_get_CallbackInstance_Proxy(ITToneDetectionEvent *This,__LONG32 *plCallbackInstance);
  void __RPC_STUB ITToneDetectionEvent_get_CallbackInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTAPIObjectEvent_INTERFACE_DEFINED__
#define __ITTAPIObjectEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTAPIObjectEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTAPIObjectEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_TAPIObject(ITTAPI **ppTAPIObject) = 0;
    virtual HRESULT WINAPI get_Event(TAPIOBJECT_EVENT *pEvent) = 0;
    virtual HRESULT WINAPI get_Address(ITAddress **ppAddress) = 0;
    virtual HRESULT WINAPI get_CallbackInstance(__LONG32 *plCallbackInstance) = 0;
  };
#else
  typedef struct ITTAPIObjectEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTAPIObjectEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTAPIObjectEvent *This);
      ULONG (WINAPI *Release)(ITTAPIObjectEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTAPIObjectEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTAPIObjectEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTAPIObjectEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTAPIObjectEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_TAPIObject)(ITTAPIObjectEvent *This,ITTAPI **ppTAPIObject);
      HRESULT (WINAPI *get_Event)(ITTAPIObjectEvent *This,TAPIOBJECT_EVENT *pEvent);
      HRESULT (WINAPI *get_Address)(ITTAPIObjectEvent *This,ITAddress **ppAddress);
      HRESULT (WINAPI *get_CallbackInstance)(ITTAPIObjectEvent *This,__LONG32 *plCallbackInstance);
    END_INTERFACE
  } ITTAPIObjectEventVtbl;
  struct ITTAPIObjectEvent {
    CONST_VTBL struct ITTAPIObjectEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTAPIObjectEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTAPIObjectEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTAPIObjectEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITTAPIObjectEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTAPIObjectEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTAPIObjectEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTAPIObjectEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITTAPIObjectEvent_get_TAPIObject(This,ppTAPIObject) (This)->lpVtbl->get_TAPIObject(This,ppTAPIObject)
#define ITTAPIObjectEvent_get_Event(This,pEvent) (This)->lpVtbl->get_Event(This,pEvent)
#define ITTAPIObjectEvent_get_Address(This,ppAddress) (This)->lpVtbl->get_Address(This,ppAddress)
#define ITTAPIObjectEvent_get_CallbackInstance(This,plCallbackInstance) (This)->lpVtbl->get_CallbackInstance(This,plCallbackInstance)
#endif
#endif
  HRESULT WINAPI ITTAPIObjectEvent_get_TAPIObject_Proxy(ITTAPIObjectEvent *This,ITTAPI **ppTAPIObject);
  void __RPC_STUB ITTAPIObjectEvent_get_TAPIObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPIObjectEvent_get_Event_Proxy(ITTAPIObjectEvent *This,TAPIOBJECT_EVENT *pEvent);
  void __RPC_STUB ITTAPIObjectEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPIObjectEvent_get_Address_Proxy(ITTAPIObjectEvent *This,ITAddress **ppAddress);
  void __RPC_STUB ITTAPIObjectEvent_get_Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTAPIObjectEvent_get_CallbackInstance_Proxy(ITTAPIObjectEvent *This,__LONG32 *plCallbackInstance);
  void __RPC_STUB ITTAPIObjectEvent_get_CallbackInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTAPIObjectEvent2_INTERFACE_DEFINED__
#define __ITTAPIObjectEvent2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTAPIObjectEvent2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTAPIObjectEvent2 : public ITTAPIObjectEvent {
  public:
    virtual HRESULT WINAPI get_Phone(ITPhone **ppPhone) = 0;
  };
#else
  typedef struct ITTAPIObjectEvent2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTAPIObjectEvent2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTAPIObjectEvent2 *This);
      ULONG (WINAPI *Release)(ITTAPIObjectEvent2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTAPIObjectEvent2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTAPIObjectEvent2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTAPIObjectEvent2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTAPIObjectEvent2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_TAPIObject)(ITTAPIObjectEvent2 *This,ITTAPI **ppTAPIObject);
      HRESULT (WINAPI *get_Event)(ITTAPIObjectEvent2 *This,TAPIOBJECT_EVENT *pEvent);
      HRESULT (WINAPI *get_Address)(ITTAPIObjectEvent2 *This,ITAddress **ppAddress);
      HRESULT (WINAPI *get_CallbackInstance)(ITTAPIObjectEvent2 *This,__LONG32 *plCallbackInstance);
      HRESULT (WINAPI *get_Phone)(ITTAPIObjectEvent2 *This,ITPhone **ppPhone);
    END_INTERFACE
  } ITTAPIObjectEvent2Vtbl;
  struct ITTAPIObjectEvent2 {
    CONST_VTBL struct ITTAPIObjectEvent2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTAPIObjectEvent2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTAPIObjectEvent2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTAPIObjectEvent2_Release(This) (This)->lpVtbl->Release(This)
#define ITTAPIObjectEvent2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTAPIObjectEvent2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTAPIObjectEvent2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTAPIObjectEvent2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITTAPIObjectEvent2_get_TAPIObject(This,ppTAPIObject) (This)->lpVtbl->get_TAPIObject(This,ppTAPIObject)
#define ITTAPIObjectEvent2_get_Event(This,pEvent) (This)->lpVtbl->get_Event(This,pEvent)
#define ITTAPIObjectEvent2_get_Address(This,ppAddress) (This)->lpVtbl->get_Address(This,ppAddress)
#define ITTAPIObjectEvent2_get_CallbackInstance(This,plCallbackInstance) (This)->lpVtbl->get_CallbackInstance(This,plCallbackInstance)
#define ITTAPIObjectEvent2_get_Phone(This,ppPhone) (This)->lpVtbl->get_Phone(This,ppPhone)
#endif
#endif
  HRESULT WINAPI ITTAPIObjectEvent2_get_Phone_Proxy(ITTAPIObjectEvent2 *This,ITPhone **ppPhone);
  void __RPC_STUB ITTAPIObjectEvent2_get_Phone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTAPIEventNotification_INTERFACE_DEFINED__
#define __ITTAPIEventNotification_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTAPIEventNotification;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTAPIEventNotification : public IUnknown {
  public:
    virtual HRESULT WINAPI Event(TAPI_EVENT TapiEvent,IDispatch *pEvent) = 0;
  };
#else
  typedef struct ITTAPIEventNotificationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTAPIEventNotification *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTAPIEventNotification *This);
      ULONG (WINAPI *Release)(ITTAPIEventNotification *This);
      HRESULT (WINAPI *Event)(ITTAPIEventNotification *This,TAPI_EVENT TapiEvent,IDispatch *pEvent);
    END_INTERFACE
  } ITTAPIEventNotificationVtbl;
  struct ITTAPIEventNotification {
    CONST_VTBL struct ITTAPIEventNotificationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTAPIEventNotification_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTAPIEventNotification_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTAPIEventNotification_Release(This) (This)->lpVtbl->Release(This)
#define ITTAPIEventNotification_Event(This,TapiEvent,pEvent) (This)->lpVtbl->Event(This,TapiEvent,pEvent)
#endif
#endif
  HRESULT WINAPI ITTAPIEventNotification_Event_Proxy(ITTAPIEventNotification *This,TAPI_EVENT TapiEvent,IDispatch *pEvent);
  void __RPC_STUB ITTAPIEventNotification_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCallHubEvent_INTERFACE_DEFINED__
#define __ITCallHubEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCallHubEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCallHubEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Event(CALLHUB_EVENT *pEvent) = 0;
    virtual HRESULT WINAPI get_CallHub(ITCallHub **ppCallHub) = 0;
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCall) = 0;
  };
#else
  typedef struct ITCallHubEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCallHubEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCallHubEvent *This);
      ULONG (WINAPI *Release)(ITCallHubEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCallHubEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCallHubEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCallHubEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCallHubEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Event)(ITCallHubEvent *This,CALLHUB_EVENT *pEvent);
      HRESULT (WINAPI *get_CallHub)(ITCallHubEvent *This,ITCallHub **ppCallHub);
      HRESULT (WINAPI *get_Call)(ITCallHubEvent *This,ITCallInfo **ppCall);
    END_INTERFACE
  } ITCallHubEventVtbl;
  struct ITCallHubEvent {
    CONST_VTBL struct ITCallHubEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCallHubEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCallHubEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCallHubEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITCallHubEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCallHubEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCallHubEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCallHubEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCallHubEvent_get_Event(This,pEvent) (This)->lpVtbl->get_Event(This,pEvent)
#define ITCallHubEvent_get_CallHub(This,ppCallHub) (This)->lpVtbl->get_CallHub(This,ppCallHub)
#define ITCallHubEvent_get_Call(This,ppCall) (This)->lpVtbl->get_Call(This,ppCall)
#endif
#endif
  HRESULT WINAPI ITCallHubEvent_get_Event_Proxy(ITCallHubEvent *This,CALLHUB_EVENT *pEvent);
  void __RPC_STUB ITCallHubEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallHubEvent_get_CallHub_Proxy(ITCallHubEvent *This,ITCallHub **ppCallHub);
  void __RPC_STUB ITCallHubEvent_get_CallHub_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallHubEvent_get_Call_Proxy(ITCallHubEvent *This,ITCallInfo **ppCall);
  void __RPC_STUB ITCallHubEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAddressEvent_INTERFACE_DEFINED__
#define __ITAddressEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAddressEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAddressEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Address(ITAddress **ppAddress) = 0;
    virtual HRESULT WINAPI get_Event(ADDRESS_EVENT *pEvent) = 0;
    virtual HRESULT WINAPI get_Terminal(ITTerminal **ppTerminal) = 0;
  };
#else
  typedef struct ITAddressEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAddressEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAddressEvent *This);
      ULONG (WINAPI *Release)(ITAddressEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAddressEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAddressEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAddressEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAddressEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Address)(ITAddressEvent *This,ITAddress **ppAddress);
      HRESULT (WINAPI *get_Event)(ITAddressEvent *This,ADDRESS_EVENT *pEvent);
      HRESULT (WINAPI *get_Terminal)(ITAddressEvent *This,ITTerminal **ppTerminal);
    END_INTERFACE
  } ITAddressEventVtbl;
  struct ITAddressEvent {
    CONST_VTBL struct ITAddressEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAddressEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAddressEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAddressEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITAddressEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAddressEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAddressEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAddressEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAddressEvent_get_Address(This,ppAddress) (This)->lpVtbl->get_Address(This,ppAddress)
#define ITAddressEvent_get_Event(This,pEvent) (This)->lpVtbl->get_Event(This,pEvent)
#define ITAddressEvent_get_Terminal(This,ppTerminal) (This)->lpVtbl->get_Terminal(This,ppTerminal)
#endif
#endif
  HRESULT WINAPI ITAddressEvent_get_Address_Proxy(ITAddressEvent *This,ITAddress **ppAddress);
  void __RPC_STUB ITAddressEvent_get_Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressEvent_get_Event_Proxy(ITAddressEvent *This,ADDRESS_EVENT *pEvent);
  void __RPC_STUB ITAddressEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressEvent_get_Terminal_Proxy(ITAddressEvent *This,ITTerminal **ppTerminal);
  void __RPC_STUB ITAddressEvent_get_Terminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAddressDeviceSpecificEvent_INTERFACE_DEFINED__
#define __ITAddressDeviceSpecificEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAddressDeviceSpecificEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAddressDeviceSpecificEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Address(ITAddress **ppAddress) = 0;
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCall) = 0;
    virtual HRESULT WINAPI get_lParam1(__LONG32 *pParam1) = 0;
    virtual HRESULT WINAPI get_lParam2(__LONG32 *pParam2) = 0;
    virtual HRESULT WINAPI get_lParam3(__LONG32 *pParam3) = 0;
  };
#else
  typedef struct ITAddressDeviceSpecificEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAddressDeviceSpecificEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAddressDeviceSpecificEvent *This);
      ULONG (WINAPI *Release)(ITAddressDeviceSpecificEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAddressDeviceSpecificEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAddressDeviceSpecificEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAddressDeviceSpecificEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAddressDeviceSpecificEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Address)(ITAddressDeviceSpecificEvent *This,ITAddress **ppAddress);
      HRESULT (WINAPI *get_Call)(ITAddressDeviceSpecificEvent *This,ITCallInfo **ppCall);
      HRESULT (WINAPI *get_lParam1)(ITAddressDeviceSpecificEvent *This,__LONG32 *pParam1);
      HRESULT (WINAPI *get_lParam2)(ITAddressDeviceSpecificEvent *This,__LONG32 *pParam2);
      HRESULT (WINAPI *get_lParam3)(ITAddressDeviceSpecificEvent *This,__LONG32 *pParam3);
    END_INTERFACE
  } ITAddressDeviceSpecificEventVtbl;
  struct ITAddressDeviceSpecificEvent {
    CONST_VTBL struct ITAddressDeviceSpecificEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAddressDeviceSpecificEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAddressDeviceSpecificEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAddressDeviceSpecificEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITAddressDeviceSpecificEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAddressDeviceSpecificEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAddressDeviceSpecificEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAddressDeviceSpecificEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAddressDeviceSpecificEvent_get_Address(This,ppAddress) (This)->lpVtbl->get_Address(This,ppAddress)
#define ITAddressDeviceSpecificEvent_get_Call(This,ppCall) (This)->lpVtbl->get_Call(This,ppCall)
#define ITAddressDeviceSpecificEvent_get_lParam1(This,pParam1) (This)->lpVtbl->get_lParam1(This,pParam1)
#define ITAddressDeviceSpecificEvent_get_lParam2(This,pParam2) (This)->lpVtbl->get_lParam2(This,pParam2)
#define ITAddressDeviceSpecificEvent_get_lParam3(This,pParam3) (This)->lpVtbl->get_lParam3(This,pParam3)
#endif
#endif
  HRESULT WINAPI ITAddressDeviceSpecificEvent_get_Address_Proxy(ITAddressDeviceSpecificEvent *This,ITAddress **ppAddress);
  void __RPC_STUB ITAddressDeviceSpecificEvent_get_Address_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressDeviceSpecificEvent_get_Call_Proxy(ITAddressDeviceSpecificEvent *This,ITCallInfo **ppCall);
  void __RPC_STUB ITAddressDeviceSpecificEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressDeviceSpecificEvent_get_lParam1_Proxy(ITAddressDeviceSpecificEvent *This,__LONG32 *pParam1);
  void __RPC_STUB ITAddressDeviceSpecificEvent_get_lParam1_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressDeviceSpecificEvent_get_lParam2_Proxy(ITAddressDeviceSpecificEvent *This,__LONG32 *pParam2);
  void __RPC_STUB ITAddressDeviceSpecificEvent_get_lParam2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressDeviceSpecificEvent_get_lParam3_Proxy(ITAddressDeviceSpecificEvent *This,__LONG32 *pParam3);
  void __RPC_STUB ITAddressDeviceSpecificEvent_get_lParam3_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITFileTerminalEvent_INTERFACE_DEFINED__
#define __ITFileTerminalEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITFileTerminalEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITFileTerminalEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Terminal(ITTerminal **ppTerminal) = 0;
    virtual HRESULT WINAPI get_Track(ITFileTrack **ppTrackTerminal) = 0;
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCall) = 0;
    virtual HRESULT WINAPI get_State(TERMINAL_MEDIA_STATE *pState) = 0;
    virtual HRESULT WINAPI get_Cause(FT_STATE_EVENT_CAUSE *pCause) = 0;
    virtual HRESULT WINAPI get_Error(HRESULT *phrErrorCode) = 0;
  };
#else
  typedef struct ITFileTerminalEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITFileTerminalEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITFileTerminalEvent *This);
      ULONG (WINAPI *Release)(ITFileTerminalEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITFileTerminalEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITFileTerminalEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITFileTerminalEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITFileTerminalEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Terminal)(ITFileTerminalEvent *This,ITTerminal **ppTerminal);
      HRESULT (WINAPI *get_Track)(ITFileTerminalEvent *This,ITFileTrack **ppTrackTerminal);
      HRESULT (WINAPI *get_Call)(ITFileTerminalEvent *This,ITCallInfo **ppCall);
      HRESULT (WINAPI *get_State)(ITFileTerminalEvent *This,TERMINAL_MEDIA_STATE *pState);
      HRESULT (WINAPI *get_Cause)(ITFileTerminalEvent *This,FT_STATE_EVENT_CAUSE *pCause);
      HRESULT (WINAPI *get_Error)(ITFileTerminalEvent *This,HRESULT *phrErrorCode);
    END_INTERFACE
  } ITFileTerminalEventVtbl;
  struct ITFileTerminalEvent {
    CONST_VTBL struct ITFileTerminalEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITFileTerminalEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITFileTerminalEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITFileTerminalEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITFileTerminalEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITFileTerminalEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITFileTerminalEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITFileTerminalEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITFileTerminalEvent_get_Terminal(This,ppTerminal) (This)->lpVtbl->get_Terminal(This,ppTerminal)
#define ITFileTerminalEvent_get_Track(This,ppTrackTerminal) (This)->lpVtbl->get_Track(This,ppTrackTerminal)
#define ITFileTerminalEvent_get_Call(This,ppCall) (This)->lpVtbl->get_Call(This,ppCall)
#define ITFileTerminalEvent_get_State(This,pState) (This)->lpVtbl->get_State(This,pState)
#define ITFileTerminalEvent_get_Cause(This,pCause) (This)->lpVtbl->get_Cause(This,pCause)
#define ITFileTerminalEvent_get_Error(This,phrErrorCode) (This)->lpVtbl->get_Error(This,phrErrorCode)
#endif
#endif
  HRESULT WINAPI ITFileTerminalEvent_get_Terminal_Proxy(ITFileTerminalEvent *This,ITTerminal **ppTerminal);
  void __RPC_STUB ITFileTerminalEvent_get_Terminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFileTerminalEvent_get_Track_Proxy(ITFileTerminalEvent *This,ITFileTrack **ppTrackTerminal);
  void __RPC_STUB ITFileTerminalEvent_get_Track_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFileTerminalEvent_get_Call_Proxy(ITFileTerminalEvent *This,ITCallInfo **ppCall);
  void __RPC_STUB ITFileTerminalEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFileTerminalEvent_get_State_Proxy(ITFileTerminalEvent *This,TERMINAL_MEDIA_STATE *pState);
  void __RPC_STUB ITFileTerminalEvent_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFileTerminalEvent_get_Cause_Proxy(ITFileTerminalEvent *This,FT_STATE_EVENT_CAUSE *pCause);
  void __RPC_STUB ITFileTerminalEvent_get_Cause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFileTerminalEvent_get_Error_Proxy(ITFileTerminalEvent *This,HRESULT *phrErrorCode);
  void __RPC_STUB ITFileTerminalEvent_get_Error_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTTSTerminalEvent_INTERFACE_DEFINED__
#define __ITTTSTerminalEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTTSTerminalEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTTSTerminalEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Terminal(ITTerminal **ppTerminal) = 0;
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCall) = 0;
    virtual HRESULT WINAPI get_Error(HRESULT *phrErrorCode) = 0;
  };
#else
  typedef struct ITTTSTerminalEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTTSTerminalEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTTSTerminalEvent *This);
      ULONG (WINAPI *Release)(ITTTSTerminalEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTTSTerminalEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTTSTerminalEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTTSTerminalEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTTSTerminalEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Terminal)(ITTTSTerminalEvent *This,ITTerminal **ppTerminal);
      HRESULT (WINAPI *get_Call)(ITTTSTerminalEvent *This,ITCallInfo **ppCall);
      HRESULT (WINAPI *get_Error)(ITTTSTerminalEvent *This,HRESULT *phrErrorCode);
    END_INTERFACE
  } ITTTSTerminalEventVtbl;
  struct ITTTSTerminalEvent {
    CONST_VTBL struct ITTTSTerminalEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTTSTerminalEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTTSTerminalEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTTSTerminalEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITTTSTerminalEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTTSTerminalEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTTSTerminalEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTTSTerminalEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITTTSTerminalEvent_get_Terminal(This,ppTerminal) (This)->lpVtbl->get_Terminal(This,ppTerminal)
#define ITTTSTerminalEvent_get_Call(This,ppCall) (This)->lpVtbl->get_Call(This,ppCall)
#define ITTTSTerminalEvent_get_Error(This,phrErrorCode) (This)->lpVtbl->get_Error(This,phrErrorCode)
#endif
#endif
  HRESULT WINAPI ITTTSTerminalEvent_get_Terminal_Proxy(ITTTSTerminalEvent *This,ITTerminal **ppTerminal);
  void __RPC_STUB ITTTSTerminalEvent_get_Terminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTTSTerminalEvent_get_Call_Proxy(ITTTSTerminalEvent *This,ITCallInfo **ppCall);
  void __RPC_STUB ITTTSTerminalEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTTSTerminalEvent_get_Error_Proxy(ITTTSTerminalEvent *This,HRESULT *phrErrorCode);
  void __RPC_STUB ITTTSTerminalEvent_get_Error_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITASRTerminalEvent_INTERFACE_DEFINED__
#define __ITASRTerminalEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITASRTerminalEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITASRTerminalEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Terminal(ITTerminal **ppTerminal) = 0;
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCall) = 0;
    virtual HRESULT WINAPI get_Error(HRESULT *phrErrorCode) = 0;
  };
#else
  typedef struct ITASRTerminalEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITASRTerminalEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITASRTerminalEvent *This);
      ULONG (WINAPI *Release)(ITASRTerminalEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITASRTerminalEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITASRTerminalEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITASRTerminalEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITASRTerminalEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Terminal)(ITASRTerminalEvent *This,ITTerminal **ppTerminal);
      HRESULT (WINAPI *get_Call)(ITASRTerminalEvent *This,ITCallInfo **ppCall);
      HRESULT (WINAPI *get_Error)(ITASRTerminalEvent *This,HRESULT *phrErrorCode);
    END_INTERFACE
  } ITASRTerminalEventVtbl;
  struct ITASRTerminalEvent {
    CONST_VTBL struct ITASRTerminalEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITASRTerminalEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITASRTerminalEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITASRTerminalEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITASRTerminalEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITASRTerminalEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITASRTerminalEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITASRTerminalEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITASRTerminalEvent_get_Terminal(This,ppTerminal) (This)->lpVtbl->get_Terminal(This,ppTerminal)
#define ITASRTerminalEvent_get_Call(This,ppCall) (This)->lpVtbl->get_Call(This,ppCall)
#define ITASRTerminalEvent_get_Error(This,phrErrorCode) (This)->lpVtbl->get_Error(This,phrErrorCode)
#endif
#endif
  HRESULT WINAPI ITASRTerminalEvent_get_Terminal_Proxy(ITASRTerminalEvent *This,ITTerminal **ppTerminal);
  void __RPC_STUB ITASRTerminalEvent_get_Terminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITASRTerminalEvent_get_Call_Proxy(ITASRTerminalEvent *This,ITCallInfo **ppCall);
  void __RPC_STUB ITASRTerminalEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITASRTerminalEvent_get_Error_Proxy(ITASRTerminalEvent *This,HRESULT *phrErrorCode);
  void __RPC_STUB ITASRTerminalEvent_get_Error_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITToneTerminalEvent_INTERFACE_DEFINED__
#define __ITToneTerminalEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITToneTerminalEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITToneTerminalEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Terminal(ITTerminal **ppTerminal) = 0;
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCall) = 0;
    virtual HRESULT WINAPI get_Error(HRESULT *phrErrorCode) = 0;
  };
#else
  typedef struct ITToneTerminalEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITToneTerminalEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITToneTerminalEvent *This);
      ULONG (WINAPI *Release)(ITToneTerminalEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITToneTerminalEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITToneTerminalEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITToneTerminalEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITToneTerminalEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Terminal)(ITToneTerminalEvent *This,ITTerminal **ppTerminal);
      HRESULT (WINAPI *get_Call)(ITToneTerminalEvent *This,ITCallInfo **ppCall);
      HRESULT (WINAPI *get_Error)(ITToneTerminalEvent *This,HRESULT *phrErrorCode);
    END_INTERFACE
  } ITToneTerminalEventVtbl;
  struct ITToneTerminalEvent {
    CONST_VTBL struct ITToneTerminalEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITToneTerminalEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITToneTerminalEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITToneTerminalEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITToneTerminalEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITToneTerminalEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITToneTerminalEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITToneTerminalEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITToneTerminalEvent_get_Terminal(This,ppTerminal) (This)->lpVtbl->get_Terminal(This,ppTerminal)
#define ITToneTerminalEvent_get_Call(This,ppCall) (This)->lpVtbl->get_Call(This,ppCall)
#define ITToneTerminalEvent_get_Error(This,phrErrorCode) (This)->lpVtbl->get_Error(This,phrErrorCode)
#endif
#endif
  HRESULT WINAPI ITToneTerminalEvent_get_Terminal_Proxy(ITToneTerminalEvent *This,ITTerminal **ppTerminal);
  void __RPC_STUB ITToneTerminalEvent_get_Terminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITToneTerminalEvent_get_Call_Proxy(ITToneTerminalEvent *This,ITCallInfo **ppCall);
  void __RPC_STUB ITToneTerminalEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITToneTerminalEvent_get_Error_Proxy(ITToneTerminalEvent *This,HRESULT *phrErrorCode);
  void __RPC_STUB ITToneTerminalEvent_get_Error_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITQOSEvent_INTERFACE_DEFINED__
#define __ITQOSEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITQOSEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITQOSEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCall) = 0;
    virtual HRESULT WINAPI get_Event(QOS_EVENT *pQosEvent) = 0;
    virtual HRESULT WINAPI get_MediaType(__LONG32 *plMediaType) = 0;
  };
#else
  typedef struct ITQOSEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITQOSEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITQOSEvent *This);
      ULONG (WINAPI *Release)(ITQOSEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITQOSEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITQOSEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITQOSEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITQOSEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Call)(ITQOSEvent *This,ITCallInfo **ppCall);
      HRESULT (WINAPI *get_Event)(ITQOSEvent *This,QOS_EVENT *pQosEvent);
      HRESULT (WINAPI *get_MediaType)(ITQOSEvent *This,__LONG32 *plMediaType);
    END_INTERFACE
  } ITQOSEventVtbl;
  struct ITQOSEvent {
    CONST_VTBL struct ITQOSEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITQOSEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITQOSEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITQOSEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITQOSEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITQOSEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITQOSEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITQOSEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITQOSEvent_get_Call(This,ppCall) (This)->lpVtbl->get_Call(This,ppCall)
#define ITQOSEvent_get_Event(This,pQosEvent) (This)->lpVtbl->get_Event(This,pQosEvent)
#define ITQOSEvent_get_MediaType(This,plMediaType) (This)->lpVtbl->get_MediaType(This,plMediaType)
#endif
#endif
  HRESULT WINAPI ITQOSEvent_get_Call_Proxy(ITQOSEvent *This,ITCallInfo **ppCall);
  void __RPC_STUB ITQOSEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQOSEvent_get_Event_Proxy(ITQOSEvent *This,QOS_EVENT *pQosEvent);
  void __RPC_STUB ITQOSEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITQOSEvent_get_MediaType_Proxy(ITQOSEvent *This,__LONG32 *plMediaType);
  void __RPC_STUB ITQOSEvent_get_MediaType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCallInfoChangeEvent_INTERFACE_DEFINED__
#define __ITCallInfoChangeEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCallInfoChangeEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCallInfoChangeEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCall) = 0;
    virtual HRESULT WINAPI get_Cause(CALLINFOCHANGE_CAUSE *pCIC) = 0;
    virtual HRESULT WINAPI get_CallbackInstance(__LONG32 *plCallbackInstance) = 0;
  };
#else
  typedef struct ITCallInfoChangeEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCallInfoChangeEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCallInfoChangeEvent *This);
      ULONG (WINAPI *Release)(ITCallInfoChangeEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCallInfoChangeEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCallInfoChangeEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCallInfoChangeEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCallInfoChangeEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Call)(ITCallInfoChangeEvent *This,ITCallInfo **ppCall);
      HRESULT (WINAPI *get_Cause)(ITCallInfoChangeEvent *This,CALLINFOCHANGE_CAUSE *pCIC);
      HRESULT (WINAPI *get_CallbackInstance)(ITCallInfoChangeEvent *This,__LONG32 *plCallbackInstance);
    END_INTERFACE
  } ITCallInfoChangeEventVtbl;
  struct ITCallInfoChangeEvent {
    CONST_VTBL struct ITCallInfoChangeEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCallInfoChangeEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCallInfoChangeEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCallInfoChangeEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITCallInfoChangeEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCallInfoChangeEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCallInfoChangeEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCallInfoChangeEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCallInfoChangeEvent_get_Call(This,ppCall) (This)->lpVtbl->get_Call(This,ppCall)
#define ITCallInfoChangeEvent_get_Cause(This,pCIC) (This)->lpVtbl->get_Cause(This,pCIC)
#define ITCallInfoChangeEvent_get_CallbackInstance(This,plCallbackInstance) (This)->lpVtbl->get_CallbackInstance(This,plCallbackInstance)
#endif
#endif
  HRESULT WINAPI ITCallInfoChangeEvent_get_Call_Proxy(ITCallInfoChangeEvent *This,ITCallInfo **ppCall);
  void __RPC_STUB ITCallInfoChangeEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfoChangeEvent_get_Cause_Proxy(ITCallInfoChangeEvent *This,CALLINFOCHANGE_CAUSE *pCIC);
  void __RPC_STUB ITCallInfoChangeEvent_get_Cause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallInfoChangeEvent_get_CallbackInstance_Proxy(ITCallInfoChangeEvent *This,__LONG32 *plCallbackInstance);
  void __RPC_STUB ITCallInfoChangeEvent_get_CallbackInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITRequest_INTERFACE_DEFINED__
#define __ITRequest_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITRequest;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITRequest : public IDispatch {
  public:
    virtual HRESULT WINAPI MakeCall(BSTR pDestAddress,BSTR pAppName,BSTR pCalledParty,BSTR pComment) = 0;
  };
#else
  typedef struct ITRequestVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITRequest *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITRequest *This);
      ULONG (WINAPI *Release)(ITRequest *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITRequest *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITRequest *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITRequest *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITRequest *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *MakeCall)(ITRequest *This,BSTR pDestAddress,BSTR pAppName,BSTR pCalledParty,BSTR pComment);
    END_INTERFACE
  } ITRequestVtbl;
  struct ITRequest {
    CONST_VTBL struct ITRequestVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITRequest_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITRequest_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITRequest_Release(This) (This)->lpVtbl->Release(This)
#define ITRequest_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITRequest_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITRequest_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITRequest_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITRequest_MakeCall(This,pDestAddress,pAppName,pCalledParty,pComment) (This)->lpVtbl->MakeCall(This,pDestAddress,pAppName,pCalledParty,pComment)
#endif
#endif
  HRESULT WINAPI ITRequest_MakeCall_Proxy(ITRequest *This,BSTR pDestAddress,BSTR pAppName,BSTR pCalledParty,BSTR pComment);
  void __RPC_STUB ITRequest_MakeCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITRequestEvent_INTERFACE_DEFINED__
#define __ITRequestEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITRequestEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITRequestEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_RegistrationInstance(__LONG32 *plRegistrationInstance) = 0;
    virtual HRESULT WINAPI get_RequestMode(__LONG32 *plRequestMode) = 0;
    virtual HRESULT WINAPI get_DestAddress(BSTR *ppDestAddress) = 0;
    virtual HRESULT WINAPI get_AppName(BSTR *ppAppName) = 0;
    virtual HRESULT WINAPI get_CalledParty(BSTR *ppCalledParty) = 0;
    virtual HRESULT WINAPI get_Comment(BSTR *ppComment) = 0;
  };
#else
  typedef struct ITRequestEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITRequestEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITRequestEvent *This);
      ULONG (WINAPI *Release)(ITRequestEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITRequestEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITRequestEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITRequestEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITRequestEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_RegistrationInstance)(ITRequestEvent *This,__LONG32 *plRegistrationInstance);
      HRESULT (WINAPI *get_RequestMode)(ITRequestEvent *This,__LONG32 *plRequestMode);
      HRESULT (WINAPI *get_DestAddress)(ITRequestEvent *This,BSTR *ppDestAddress);
      HRESULT (WINAPI *get_AppName)(ITRequestEvent *This,BSTR *ppAppName);
      HRESULT (WINAPI *get_CalledParty)(ITRequestEvent *This,BSTR *ppCalledParty);
      HRESULT (WINAPI *get_Comment)(ITRequestEvent *This,BSTR *ppComment);
    END_INTERFACE
  } ITRequestEventVtbl;
  struct ITRequestEvent {
    CONST_VTBL struct ITRequestEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITRequestEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITRequestEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITRequestEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITRequestEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITRequestEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITRequestEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITRequestEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITRequestEvent_get_RegistrationInstance(This,plRegistrationInstance) (This)->lpVtbl->get_RegistrationInstance(This,plRegistrationInstance)
#define ITRequestEvent_get_RequestMode(This,plRequestMode) (This)->lpVtbl->get_RequestMode(This,plRequestMode)
#define ITRequestEvent_get_DestAddress(This,ppDestAddress) (This)->lpVtbl->get_DestAddress(This,ppDestAddress)
#define ITRequestEvent_get_AppName(This,ppAppName) (This)->lpVtbl->get_AppName(This,ppAppName)
#define ITRequestEvent_get_CalledParty(This,ppCalledParty) (This)->lpVtbl->get_CalledParty(This,ppCalledParty)
#define ITRequestEvent_get_Comment(This,ppComment) (This)->lpVtbl->get_Comment(This,ppComment)
#endif
#endif
  HRESULT WINAPI ITRequestEvent_get_RegistrationInstance_Proxy(ITRequestEvent *This,__LONG32 *plRegistrationInstance);
  void __RPC_STUB ITRequestEvent_get_RegistrationInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITRequestEvent_get_RequestMode_Proxy(ITRequestEvent *This,__LONG32 *plRequestMode);
  void __RPC_STUB ITRequestEvent_get_RequestMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITRequestEvent_get_DestAddress_Proxy(ITRequestEvent *This,BSTR *ppDestAddress);
  void __RPC_STUB ITRequestEvent_get_DestAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITRequestEvent_get_AppName_Proxy(ITRequestEvent *This,BSTR *ppAppName);
  void __RPC_STUB ITRequestEvent_get_AppName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITRequestEvent_get_CalledParty_Proxy(ITRequestEvent *This,BSTR *ppCalledParty);
  void __RPC_STUB ITRequestEvent_get_CalledParty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITRequestEvent_get_Comment_Proxy(ITRequestEvent *This,BSTR *ppComment);
  void __RPC_STUB ITRequestEvent_get_Comment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCollection_INTERFACE_DEFINED__
#define __ITCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCollection : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *lCount) = 0;
    virtual HRESULT WINAPI get_Item(__LONG32 Index,VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppNewEnum) = 0;
  };
#else
  typedef struct ITCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCollection *This);
      ULONG (WINAPI *Release)(ITCollection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCollection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCollection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCollection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCollection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ITCollection *This,__LONG32 *lCount);
      HRESULT (WINAPI *get_Item)(ITCollection *This,__LONG32 Index,VARIANT *pVariant);
      HRESULT (WINAPI *get__NewEnum)(ITCollection *This,IUnknown **ppNewEnum);
    END_INTERFACE
  } ITCollectionVtbl;
  struct ITCollection {
    CONST_VTBL struct ITCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCollection_Release(This) (This)->lpVtbl->Release(This)
#define ITCollection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCollection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCollection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCollection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCollection_get_Count(This,lCount) (This)->lpVtbl->get_Count(This,lCount)
#define ITCollection_get_Item(This,Index,pVariant) (This)->lpVtbl->get_Item(This,Index,pVariant)
#define ITCollection_get__NewEnum(This,ppNewEnum) (This)->lpVtbl->get__NewEnum(This,ppNewEnum)
#endif
#endif
  HRESULT WINAPI ITCollection_get_Count_Proxy(ITCollection *This,__LONG32 *lCount);
  void __RPC_STUB ITCollection_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCollection_get_Item_Proxy(ITCollection *This,__LONG32 Index,VARIANT *pVariant);
  void __RPC_STUB ITCollection_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCollection_get__NewEnum_Proxy(ITCollection *This,IUnknown **ppNewEnum);
  void __RPC_STUB ITCollection_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCollection2_INTERFACE_DEFINED__
#define __ITCollection2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCollection2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCollection2 : public ITCollection {
  public:
    virtual HRESULT WINAPI Add(__LONG32 Index,VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI Remove(__LONG32 Index) = 0;
  };
#else
  typedef struct ITCollection2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCollection2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCollection2 *This);
      ULONG (WINAPI *Release)(ITCollection2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCollection2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCollection2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCollection2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCollection2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ITCollection2 *This,__LONG32 *lCount);
      HRESULT (WINAPI *get_Item)(ITCollection2 *This,__LONG32 Index,VARIANT *pVariant);
      HRESULT (WINAPI *get__NewEnum)(ITCollection2 *This,IUnknown **ppNewEnum);
      HRESULT (WINAPI *Add)(ITCollection2 *This,__LONG32 Index,VARIANT *pVariant);
      HRESULT (WINAPI *Remove)(ITCollection2 *This,__LONG32 Index);
    END_INTERFACE
  } ITCollection2Vtbl;
  struct ITCollection2 {
    CONST_VTBL struct ITCollection2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCollection2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCollection2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCollection2_Release(This) (This)->lpVtbl->Release(This)
#define ITCollection2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCollection2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCollection2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCollection2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCollection2_get_Count(This,lCount) (This)->lpVtbl->get_Count(This,lCount)
#define ITCollection2_get_Item(This,Index,pVariant) (This)->lpVtbl->get_Item(This,Index,pVariant)
#define ITCollection2_get__NewEnum(This,ppNewEnum) (This)->lpVtbl->get__NewEnum(This,ppNewEnum)
#define ITCollection2_Add(This,Index,pVariant) (This)->lpVtbl->Add(This,Index,pVariant)
#define ITCollection2_Remove(This,Index) (This)->lpVtbl->Remove(This,Index)
#endif
#endif
  HRESULT WINAPI ITCollection2_Add_Proxy(ITCollection2 *This,__LONG32 Index,VARIANT *pVariant);
  void __RPC_STUB ITCollection2_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCollection2_Remove_Proxy(ITCollection2 *This,__LONG32 Index);
  void __RPC_STUB ITCollection2_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITForwardInformation_INTERFACE_DEFINED__
#define __ITForwardInformation_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITForwardInformation;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITForwardInformation : public IDispatch {
  public:
    virtual HRESULT WINAPI put_NumRingsNoAnswer(__LONG32 lNumRings) = 0;
    virtual HRESULT WINAPI get_NumRingsNoAnswer(__LONG32 *plNumRings) = 0;
    virtual HRESULT WINAPI SetForwardType(__LONG32 ForwardType,BSTR pDestAddress,BSTR pCallerAddress) = 0;
    virtual HRESULT WINAPI get_ForwardTypeDestination(__LONG32 ForwardType,BSTR *ppDestAddress) = 0;
    virtual HRESULT WINAPI get_ForwardTypeCaller(__LONG32 Forwardtype,BSTR *ppCallerAddress) = 0;
    virtual HRESULT WINAPI GetForwardType(__LONG32 ForwardType,BSTR *ppDestinationAddress,BSTR *ppCallerAddress) = 0;
    virtual HRESULT WINAPI Clear(void) = 0;
  };
#else
  typedef struct ITForwardInformationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITForwardInformation *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITForwardInformation *This);
      ULONG (WINAPI *Release)(ITForwardInformation *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITForwardInformation *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITForwardInformation *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITForwardInformation *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITForwardInformation *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *put_NumRingsNoAnswer)(ITForwardInformation *This,__LONG32 lNumRings);
      HRESULT (WINAPI *get_NumRingsNoAnswer)(ITForwardInformation *This,__LONG32 *plNumRings);
      HRESULT (WINAPI *SetForwardType)(ITForwardInformation *This,__LONG32 ForwardType,BSTR pDestAddress,BSTR pCallerAddress);
      HRESULT (WINAPI *get_ForwardTypeDestination)(ITForwardInformation *This,__LONG32 ForwardType,BSTR *ppDestAddress);
      HRESULT (WINAPI *get_ForwardTypeCaller)(ITForwardInformation *This,__LONG32 Forwardtype,BSTR *ppCallerAddress);
      HRESULT (WINAPI *GetForwardType)(ITForwardInformation *This,__LONG32 ForwardType,BSTR *ppDestinationAddress,BSTR *ppCallerAddress);
      HRESULT (WINAPI *Clear)(ITForwardInformation *This);
    END_INTERFACE
  } ITForwardInformationVtbl;
  struct ITForwardInformation {
    CONST_VTBL struct ITForwardInformationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITForwardInformation_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITForwardInformation_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITForwardInformation_Release(This) (This)->lpVtbl->Release(This)
#define ITForwardInformation_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITForwardInformation_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITForwardInformation_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITForwardInformation_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITForwardInformation_put_NumRingsNoAnswer(This,lNumRings) (This)->lpVtbl->put_NumRingsNoAnswer(This,lNumRings)
#define ITForwardInformation_get_NumRingsNoAnswer(This,plNumRings) (This)->lpVtbl->get_NumRingsNoAnswer(This,plNumRings)
#define ITForwardInformation_SetForwardType(This,ForwardType,pDestAddress,pCallerAddress) (This)->lpVtbl->SetForwardType(This,ForwardType,pDestAddress,pCallerAddress)
#define ITForwardInformation_get_ForwardTypeDestination(This,ForwardType,ppDestAddress) (This)->lpVtbl->get_ForwardTypeDestination(This,ForwardType,ppDestAddress)
#define ITForwardInformation_get_ForwardTypeCaller(This,Forwardtype,ppCallerAddress) (This)->lpVtbl->get_ForwardTypeCaller(This,Forwardtype,ppCallerAddress)
#define ITForwardInformation_GetForwardType(This,ForwardType,ppDestinationAddress,ppCallerAddress) (This)->lpVtbl->GetForwardType(This,ForwardType,ppDestinationAddress,ppCallerAddress)
#define ITForwardInformation_Clear(This) (This)->lpVtbl->Clear(This)
#endif
#endif
  HRESULT WINAPI ITForwardInformation_put_NumRingsNoAnswer_Proxy(ITForwardInformation *This,__LONG32 lNumRings);
  void __RPC_STUB ITForwardInformation_put_NumRingsNoAnswer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITForwardInformation_get_NumRingsNoAnswer_Proxy(ITForwardInformation *This,__LONG32 *plNumRings);
  void __RPC_STUB ITForwardInformation_get_NumRingsNoAnswer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITForwardInformation_SetForwardType_Proxy(ITForwardInformation *This,__LONG32 ForwardType,BSTR pDestAddress,BSTR pCallerAddress);
  void __RPC_STUB ITForwardInformation_SetForwardType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITForwardInformation_get_ForwardTypeDestination_Proxy(ITForwardInformation *This,__LONG32 ForwardType,BSTR *ppDestAddress);
  void __RPC_STUB ITForwardInformation_get_ForwardTypeDestination_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITForwardInformation_get_ForwardTypeCaller_Proxy(ITForwardInformation *This,__LONG32 Forwardtype,BSTR *ppCallerAddress);
  void __RPC_STUB ITForwardInformation_get_ForwardTypeCaller_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITForwardInformation_GetForwardType_Proxy(ITForwardInformation *This,__LONG32 ForwardType,BSTR *ppDestinationAddress,BSTR *ppCallerAddress);
  void __RPC_STUB ITForwardInformation_GetForwardType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITForwardInformation_Clear_Proxy(ITForwardInformation *This);
  void __RPC_STUB ITForwardInformation_Clear_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITForwardInformation2_INTERFACE_DEFINED__
#define __ITForwardInformation2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITForwardInformation2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITForwardInformation2 : public ITForwardInformation {
  public:
    virtual HRESULT WINAPI SetForwardType2(__LONG32 ForwardType,BSTR pDestAddress,__LONG32 DestAddressType,BSTR pCallerAddress,__LONG32 CallerAddressType) = 0;
    virtual HRESULT WINAPI GetForwardType2(__LONG32 ForwardType,BSTR *ppDestinationAddress,__LONG32 *pDestAddressType,BSTR *ppCallerAddress,__LONG32 *pCallerAddressType) = 0;
    virtual HRESULT WINAPI get_ForwardTypeDestinationAddressType(__LONG32 ForwardType,__LONG32 *pDestAddressType) = 0;
    virtual HRESULT WINAPI get_ForwardTypeCallerAddressType(__LONG32 Forwardtype,__LONG32 *pCallerAddressType) = 0;
  };
#else
  typedef struct ITForwardInformation2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITForwardInformation2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITForwardInformation2 *This);
      ULONG (WINAPI *Release)(ITForwardInformation2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITForwardInformation2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITForwardInformation2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITForwardInformation2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITForwardInformation2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *put_NumRingsNoAnswer)(ITForwardInformation2 *This,__LONG32 lNumRings);
      HRESULT (WINAPI *get_NumRingsNoAnswer)(ITForwardInformation2 *This,__LONG32 *plNumRings);
      HRESULT (WINAPI *SetForwardType)(ITForwardInformation2 *This,__LONG32 ForwardType,BSTR pDestAddress,BSTR pCallerAddress);
      HRESULT (WINAPI *get_ForwardTypeDestination)(ITForwardInformation2 *This,__LONG32 ForwardType,BSTR *ppDestAddress);
      HRESULT (WINAPI *get_ForwardTypeCaller)(ITForwardInformation2 *This,__LONG32 Forwardtype,BSTR *ppCallerAddress);
      HRESULT (WINAPI *GetForwardType)(ITForwardInformation2 *This,__LONG32 ForwardType,BSTR *ppDestinationAddress,BSTR *ppCallerAddress);
      HRESULT (WINAPI *Clear)(ITForwardInformation2 *This);
      HRESULT (WINAPI *SetForwardType2)(ITForwardInformation2 *This,__LONG32 ForwardType,BSTR pDestAddress,__LONG32 DestAddressType,BSTR pCallerAddress,__LONG32 CallerAddressType);
      HRESULT (WINAPI *GetForwardType2)(ITForwardInformation2 *This,__LONG32 ForwardType,BSTR *ppDestinationAddress,__LONG32 *pDestAddressType,BSTR *ppCallerAddress,__LONG32 *pCallerAddressType);
      HRESULT (WINAPI *get_ForwardTypeDestinationAddressType)(ITForwardInformation2 *This,__LONG32 ForwardType,__LONG32 *pDestAddressType);
      HRESULT (WINAPI *get_ForwardTypeCallerAddressType)(ITForwardInformation2 *This,__LONG32 Forwardtype,__LONG32 *pCallerAddressType);
    END_INTERFACE
  } ITForwardInformation2Vtbl;
  struct ITForwardInformation2 {
    CONST_VTBL struct ITForwardInformation2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITForwardInformation2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITForwardInformation2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITForwardInformation2_Release(This) (This)->lpVtbl->Release(This)
#define ITForwardInformation2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITForwardInformation2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITForwardInformation2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITForwardInformation2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITForwardInformation2_put_NumRingsNoAnswer(This,lNumRings) (This)->lpVtbl->put_NumRingsNoAnswer(This,lNumRings)
#define ITForwardInformation2_get_NumRingsNoAnswer(This,plNumRings) (This)->lpVtbl->get_NumRingsNoAnswer(This,plNumRings)
#define ITForwardInformation2_SetForwardType(This,ForwardType,pDestAddress,pCallerAddress) (This)->lpVtbl->SetForwardType(This,ForwardType,pDestAddress,pCallerAddress)
#define ITForwardInformation2_get_ForwardTypeDestination(This,ForwardType,ppDestAddress) (This)->lpVtbl->get_ForwardTypeDestination(This,ForwardType,ppDestAddress)
#define ITForwardInformation2_get_ForwardTypeCaller(This,Forwardtype,ppCallerAddress) (This)->lpVtbl->get_ForwardTypeCaller(This,Forwardtype,ppCallerAddress)
#define ITForwardInformation2_GetForwardType(This,ForwardType,ppDestinationAddress,ppCallerAddress) (This)->lpVtbl->GetForwardType(This,ForwardType,ppDestinationAddress,ppCallerAddress)
#define ITForwardInformation2_Clear(This) (This)->lpVtbl->Clear(This)
#define ITForwardInformation2_SetForwardType2(This,ForwardType,pDestAddress,DestAddressType,pCallerAddress,CallerAddressType) (This)->lpVtbl->SetForwardType2(This,ForwardType,pDestAddress,DestAddressType,pCallerAddress,CallerAddressType)
#define ITForwardInformation2_GetForwardType2(This,ForwardType,ppDestinationAddress,pDestAddressType,ppCallerAddress,pCallerAddressType) (This)->lpVtbl->GetForwardType2(This,ForwardType,ppDestinationAddress,pDestAddressType,ppCallerAddress,pCallerAddressType)
#define ITForwardInformation2_get_ForwardTypeDestinationAddressType(This,ForwardType,pDestAddressType) (This)->lpVtbl->get_ForwardTypeDestinationAddressType(This,ForwardType,pDestAddressType)
#define ITForwardInformation2_get_ForwardTypeCallerAddressType(This,Forwardtype,pCallerAddressType) (This)->lpVtbl->get_ForwardTypeCallerAddressType(This,Forwardtype,pCallerAddressType)
#endif
#endif
  HRESULT WINAPI ITForwardInformation2_SetForwardType2_Proxy(ITForwardInformation2 *This,__LONG32 ForwardType,BSTR pDestAddress,__LONG32 DestAddressType,BSTR pCallerAddress,__LONG32 CallerAddressType);
  void __RPC_STUB ITForwardInformation2_SetForwardType2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITForwardInformation2_GetForwardType2_Proxy(ITForwardInformation2 *This,__LONG32 ForwardType,BSTR *ppDestinationAddress,__LONG32 *pDestAddressType,BSTR *ppCallerAddress,__LONG32 *pCallerAddressType);
  void __RPC_STUB ITForwardInformation2_GetForwardType2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITForwardInformation2_get_ForwardTypeDestinationAddressType_Proxy(ITForwardInformation2 *This,__LONG32 ForwardType,__LONG32 *pDestAddressType);
  void __RPC_STUB ITForwardInformation2_get_ForwardTypeDestinationAddressType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITForwardInformation2_get_ForwardTypeCallerAddressType_Proxy(ITForwardInformation2 *This,__LONG32 Forwardtype,__LONG32 *pCallerAddressType);
  void __RPC_STUB ITForwardInformation2_get_ForwardTypeCallerAddressType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAddressTranslation_INTERFACE_DEFINED__
#define __ITAddressTranslation_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAddressTranslation;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAddressTranslation : public IDispatch {
  public:
    virtual HRESULT WINAPI TranslateAddress(BSTR pAddressToTranslate,__LONG32 lCard,__LONG32 lTranslateOptions,ITAddressTranslationInfo **ppTranslated) = 0;
    virtual HRESULT WINAPI TranslateDialog(TAPIHWND hwndOwner,BSTR pAddressIn) = 0;
    virtual HRESULT WINAPI EnumerateLocations(IEnumLocation **ppEnumLocation) = 0;
    virtual HRESULT WINAPI get_Locations(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateCallingCards(IEnumCallingCard **ppEnumCallingCard) = 0;
    virtual HRESULT WINAPI get_CallingCards(VARIANT *pVariant) = 0;
  };
#else
  typedef struct ITAddressTranslationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAddressTranslation *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAddressTranslation *This);
      ULONG (WINAPI *Release)(ITAddressTranslation *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAddressTranslation *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAddressTranslation *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAddressTranslation *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAddressTranslation *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *TranslateAddress)(ITAddressTranslation *This,BSTR pAddressToTranslate,__LONG32 lCard,__LONG32 lTranslateOptions,ITAddressTranslationInfo **ppTranslated);
      HRESULT (WINAPI *TranslateDialog)(ITAddressTranslation *This,TAPIHWND hwndOwner,BSTR pAddressIn);
      HRESULT (WINAPI *EnumerateLocations)(ITAddressTranslation *This,IEnumLocation **ppEnumLocation);
      HRESULT (WINAPI *get_Locations)(ITAddressTranslation *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateCallingCards)(ITAddressTranslation *This,IEnumCallingCard **ppEnumCallingCard);
      HRESULT (WINAPI *get_CallingCards)(ITAddressTranslation *This,VARIANT *pVariant);
    END_INTERFACE
  } ITAddressTranslationVtbl;
  struct ITAddressTranslation {
    CONST_VTBL struct ITAddressTranslationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAddressTranslation_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAddressTranslation_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAddressTranslation_Release(This) (This)->lpVtbl->Release(This)
#define ITAddressTranslation_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAddressTranslation_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAddressTranslation_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAddressTranslation_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAddressTranslation_TranslateAddress(This,pAddressToTranslate,lCard,lTranslateOptions,ppTranslated) (This)->lpVtbl->TranslateAddress(This,pAddressToTranslate,lCard,lTranslateOptions,ppTranslated)
#define ITAddressTranslation_TranslateDialog(This,hwndOwner,pAddressIn) (This)->lpVtbl->TranslateDialog(This,hwndOwner,pAddressIn)
#define ITAddressTranslation_EnumerateLocations(This,ppEnumLocation) (This)->lpVtbl->EnumerateLocations(This,ppEnumLocation)
#define ITAddressTranslation_get_Locations(This,pVariant) (This)->lpVtbl->get_Locations(This,pVariant)
#define ITAddressTranslation_EnumerateCallingCards(This,ppEnumCallingCard) (This)->lpVtbl->EnumerateCallingCards(This,ppEnumCallingCard)
#define ITAddressTranslation_get_CallingCards(This,pVariant) (This)->lpVtbl->get_CallingCards(This,pVariant)
#endif
#endif
  HRESULT WINAPI ITAddressTranslation_TranslateAddress_Proxy(ITAddressTranslation *This,BSTR pAddressToTranslate,__LONG32 lCard,__LONG32 lTranslateOptions,ITAddressTranslationInfo **ppTranslated);
  void __RPC_STUB ITAddressTranslation_TranslateAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressTranslation_TranslateDialog_Proxy(ITAddressTranslation *This,TAPIHWND hwndOwner,BSTR pAddressIn);
  void __RPC_STUB ITAddressTranslation_TranslateDialog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressTranslation_EnumerateLocations_Proxy(ITAddressTranslation *This,IEnumLocation **ppEnumLocation);
  void __RPC_STUB ITAddressTranslation_EnumerateLocations_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressTranslation_get_Locations_Proxy(ITAddressTranslation *This,VARIANT *pVariant);
  void __RPC_STUB ITAddressTranslation_get_Locations_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressTranslation_EnumerateCallingCards_Proxy(ITAddressTranslation *This,IEnumCallingCard **ppEnumCallingCard);
  void __RPC_STUB ITAddressTranslation_EnumerateCallingCards_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressTranslation_get_CallingCards_Proxy(ITAddressTranslation *This,VARIANT *pVariant);
  void __RPC_STUB ITAddressTranslation_get_CallingCards_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAddressTranslationInfo_INTERFACE_DEFINED__
#define __ITAddressTranslationInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAddressTranslationInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAddressTranslationInfo : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DialableString(BSTR *ppDialableString) = 0;
    virtual HRESULT WINAPI get_DisplayableString(BSTR *ppDisplayableString) = 0;
    virtual HRESULT WINAPI get_CurrentCountryCode(__LONG32 *CountryCode) = 0;
    virtual HRESULT WINAPI get_DestinationCountryCode(__LONG32 *CountryCode) = 0;
    virtual HRESULT WINAPI get_TranslationResults(__LONG32 *plResults) = 0;
  };
#else
  typedef struct ITAddressTranslationInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAddressTranslationInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAddressTranslationInfo *This);
      ULONG (WINAPI *Release)(ITAddressTranslationInfo *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAddressTranslationInfo *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAddressTranslationInfo *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAddressTranslationInfo *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAddressTranslationInfo *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DialableString)(ITAddressTranslationInfo *This,BSTR *ppDialableString);
      HRESULT (WINAPI *get_DisplayableString)(ITAddressTranslationInfo *This,BSTR *ppDisplayableString);
      HRESULT (WINAPI *get_CurrentCountryCode)(ITAddressTranslationInfo *This,__LONG32 *CountryCode);
      HRESULT (WINAPI *get_DestinationCountryCode)(ITAddressTranslationInfo *This,__LONG32 *CountryCode);
      HRESULT (WINAPI *get_TranslationResults)(ITAddressTranslationInfo *This,__LONG32 *plResults);
    END_INTERFACE
  } ITAddressTranslationInfoVtbl;
  struct ITAddressTranslationInfo {
    CONST_VTBL struct ITAddressTranslationInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAddressTranslationInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAddressTranslationInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAddressTranslationInfo_Release(This) (This)->lpVtbl->Release(This)
#define ITAddressTranslationInfo_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAddressTranslationInfo_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAddressTranslationInfo_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAddressTranslationInfo_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAddressTranslationInfo_get_DialableString(This,ppDialableString) (This)->lpVtbl->get_DialableString(This,ppDialableString)
#define ITAddressTranslationInfo_get_DisplayableString(This,ppDisplayableString) (This)->lpVtbl->get_DisplayableString(This,ppDisplayableString)
#define ITAddressTranslationInfo_get_CurrentCountryCode(This,CountryCode) (This)->lpVtbl->get_CurrentCountryCode(This,CountryCode)
#define ITAddressTranslationInfo_get_DestinationCountryCode(This,CountryCode) (This)->lpVtbl->get_DestinationCountryCode(This,CountryCode)
#define ITAddressTranslationInfo_get_TranslationResults(This,plResults) (This)->lpVtbl->get_TranslationResults(This,plResults)
#endif
#endif
  HRESULT WINAPI ITAddressTranslationInfo_get_DialableString_Proxy(ITAddressTranslationInfo *This,BSTR *ppDialableString);
  void __RPC_STUB ITAddressTranslationInfo_get_DialableString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressTranslationInfo_get_DisplayableString_Proxy(ITAddressTranslationInfo *This,BSTR *ppDisplayableString);
  void __RPC_STUB ITAddressTranslationInfo_get_DisplayableString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressTranslationInfo_get_CurrentCountryCode_Proxy(ITAddressTranslationInfo *This,__LONG32 *CountryCode);
  void __RPC_STUB ITAddressTranslationInfo_get_CurrentCountryCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressTranslationInfo_get_DestinationCountryCode_Proxy(ITAddressTranslationInfo *This,__LONG32 *CountryCode);
  void __RPC_STUB ITAddressTranslationInfo_get_DestinationCountryCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAddressTranslationInfo_get_TranslationResults_Proxy(ITAddressTranslationInfo *This,__LONG32 *plResults);
  void __RPC_STUB ITAddressTranslationInfo_get_TranslationResults_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITLocationInfo_INTERFACE_DEFINED__
#define __ITLocationInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITLocationInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITLocationInfo : public IDispatch {
  public:
    virtual HRESULT WINAPI get_PermanentLocationID(__LONG32 *plLocationID) = 0;
    virtual HRESULT WINAPI get_CountryCode(__LONG32 *plCountryCode) = 0;
    virtual HRESULT WINAPI get_CountryID(__LONG32 *plCountryID) = 0;
    virtual HRESULT WINAPI get_Options(__LONG32 *plOptions) = 0;
    virtual HRESULT WINAPI get_PreferredCardID(__LONG32 *plCardID) = 0;
    virtual HRESULT WINAPI get_LocationName(BSTR *ppLocationName) = 0;
    virtual HRESULT WINAPI get_CityCode(BSTR *ppCode) = 0;
    virtual HRESULT WINAPI get_LocalAccessCode(BSTR *ppCode) = 0;
    virtual HRESULT WINAPI get_LongDistanceAccessCode(BSTR *ppCode) = 0;
    virtual HRESULT WINAPI get_TollPrefixList(BSTR *ppTollList) = 0;
    virtual HRESULT WINAPI get_CancelCallWaitingCode(BSTR *ppCode) = 0;
  };
#else
  typedef struct ITLocationInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITLocationInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITLocationInfo *This);
      ULONG (WINAPI *Release)(ITLocationInfo *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITLocationInfo *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITLocationInfo *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITLocationInfo *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITLocationInfo *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_PermanentLocationID)(ITLocationInfo *This,__LONG32 *plLocationID);
      HRESULT (WINAPI *get_CountryCode)(ITLocationInfo *This,__LONG32 *plCountryCode);
      HRESULT (WINAPI *get_CountryID)(ITLocationInfo *This,__LONG32 *plCountryID);
      HRESULT (WINAPI *get_Options)(ITLocationInfo *This,__LONG32 *plOptions);
      HRESULT (WINAPI *get_PreferredCardID)(ITLocationInfo *This,__LONG32 *plCardID);
      HRESULT (WINAPI *get_LocationName)(ITLocationInfo *This,BSTR *ppLocationName);
      HRESULT (WINAPI *get_CityCode)(ITLocationInfo *This,BSTR *ppCode);
      HRESULT (WINAPI *get_LocalAccessCode)(ITLocationInfo *This,BSTR *ppCode);
      HRESULT (WINAPI *get_LongDistanceAccessCode)(ITLocationInfo *This,BSTR *ppCode);
      HRESULT (WINAPI *get_TollPrefixList)(ITLocationInfo *This,BSTR *ppTollList);
      HRESULT (WINAPI *get_CancelCallWaitingCode)(ITLocationInfo *This,BSTR *ppCode);
    END_INTERFACE
  } ITLocationInfoVtbl;
  struct ITLocationInfo {
    CONST_VTBL struct ITLocationInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITLocationInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITLocationInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITLocationInfo_Release(This) (This)->lpVtbl->Release(This)
#define ITLocationInfo_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITLocationInfo_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITLocationInfo_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITLocationInfo_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITLocationInfo_get_PermanentLocationID(This,plLocationID) (This)->lpVtbl->get_PermanentLocationID(This,plLocationID)
#define ITLocationInfo_get_CountryCode(This,plCountryCode) (This)->lpVtbl->get_CountryCode(This,plCountryCode)
#define ITLocationInfo_get_CountryID(This,plCountryID) (This)->lpVtbl->get_CountryID(This,plCountryID)
#define ITLocationInfo_get_Options(This,plOptions) (This)->lpVtbl->get_Options(This,plOptions)
#define ITLocationInfo_get_PreferredCardID(This,plCardID) (This)->lpVtbl->get_PreferredCardID(This,plCardID)
#define ITLocationInfo_get_LocationName(This,ppLocationName) (This)->lpVtbl->get_LocationName(This,ppLocationName)
#define ITLocationInfo_get_CityCode(This,ppCode) (This)->lpVtbl->get_CityCode(This,ppCode)
#define ITLocationInfo_get_LocalAccessCode(This,ppCode) (This)->lpVtbl->get_LocalAccessCode(This,ppCode)
#define ITLocationInfo_get_LongDistanceAccessCode(This,ppCode) (This)->lpVtbl->get_LongDistanceAccessCode(This,ppCode)
#define ITLocationInfo_get_TollPrefixList(This,ppTollList) (This)->lpVtbl->get_TollPrefixList(This,ppTollList)
#define ITLocationInfo_get_CancelCallWaitingCode(This,ppCode) (This)->lpVtbl->get_CancelCallWaitingCode(This,ppCode)
#endif
#endif
  HRESULT WINAPI ITLocationInfo_get_PermanentLocationID_Proxy(ITLocationInfo *This,__LONG32 *plLocationID);
  void __RPC_STUB ITLocationInfo_get_PermanentLocationID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLocationInfo_get_CountryCode_Proxy(ITLocationInfo *This,__LONG32 *plCountryCode);
  void __RPC_STUB ITLocationInfo_get_CountryCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLocationInfo_get_CountryID_Proxy(ITLocationInfo *This,__LONG32 *plCountryID);
  void __RPC_STUB ITLocationInfo_get_CountryID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLocationInfo_get_Options_Proxy(ITLocationInfo *This,__LONG32 *plOptions);
  void __RPC_STUB ITLocationInfo_get_Options_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLocationInfo_get_PreferredCardID_Proxy(ITLocationInfo *This,__LONG32 *plCardID);
  void __RPC_STUB ITLocationInfo_get_PreferredCardID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLocationInfo_get_LocationName_Proxy(ITLocationInfo *This,BSTR *ppLocationName);
  void __RPC_STUB ITLocationInfo_get_LocationName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLocationInfo_get_CityCode_Proxy(ITLocationInfo *This,BSTR *ppCode);
  void __RPC_STUB ITLocationInfo_get_CityCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLocationInfo_get_LocalAccessCode_Proxy(ITLocationInfo *This,BSTR *ppCode);
  void __RPC_STUB ITLocationInfo_get_LocalAccessCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLocationInfo_get_LongDistanceAccessCode_Proxy(ITLocationInfo *This,BSTR *ppCode);
  void __RPC_STUB ITLocationInfo_get_LongDistanceAccessCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLocationInfo_get_TollPrefixList_Proxy(ITLocationInfo *This,BSTR *ppTollList);
  void __RPC_STUB ITLocationInfo_get_TollPrefixList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITLocationInfo_get_CancelCallWaitingCode_Proxy(ITLocationInfo *This,BSTR *ppCode);
  void __RPC_STUB ITLocationInfo_get_CancelCallWaitingCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumLocation_INTERFACE_DEFINED__
#define __IEnumLocation_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumLocation;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumLocation : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITLocationInfo **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumLocation **ppEnum) = 0;
  };
#else
  typedef struct IEnumLocationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumLocation *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumLocation *This);
      ULONG (WINAPI *Release)(IEnumLocation *This);
      HRESULT (WINAPI *Next)(IEnumLocation *This,ULONG celt,ITLocationInfo **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumLocation *This);
      HRESULT (WINAPI *Skip)(IEnumLocation *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumLocation *This,IEnumLocation **ppEnum);
    END_INTERFACE
  } IEnumLocationVtbl;
  struct IEnumLocation {
    CONST_VTBL struct IEnumLocationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumLocation_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumLocation_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumLocation_Release(This) (This)->lpVtbl->Release(This)
#define IEnumLocation_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumLocation_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumLocation_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumLocation_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumLocation_Next_Proxy(IEnumLocation *This,ULONG celt,ITLocationInfo **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumLocation_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumLocation_Reset_Proxy(IEnumLocation *This);
  void __RPC_STUB IEnumLocation_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumLocation_Skip_Proxy(IEnumLocation *This,ULONG celt);
  void __RPC_STUB IEnumLocation_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumLocation_Clone_Proxy(IEnumLocation *This,IEnumLocation **ppEnum);
  void __RPC_STUB IEnumLocation_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCallingCard_INTERFACE_DEFINED__
#define __ITCallingCard_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCallingCard;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCallingCard : public IDispatch {
  public:
    virtual HRESULT WINAPI get_PermanentCardID(__LONG32 *plCardID) = 0;
    virtual HRESULT WINAPI get_NumberOfDigits(__LONG32 *plDigits) = 0;
    virtual HRESULT WINAPI get_Options(__LONG32 *plOptions) = 0;
    virtual HRESULT WINAPI get_CardName(BSTR *ppCardName) = 0;
    virtual HRESULT WINAPI get_SameAreaDialingRule(BSTR *ppRule) = 0;
    virtual HRESULT WINAPI get_LongDistanceDialingRule(BSTR *ppRule) = 0;
    virtual HRESULT WINAPI get_InternationalDialingRule(BSTR *ppRule) = 0;
  };
#else
  typedef struct ITCallingCardVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCallingCard *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCallingCard *This);
      ULONG (WINAPI *Release)(ITCallingCard *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCallingCard *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCallingCard *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCallingCard *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCallingCard *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_PermanentCardID)(ITCallingCard *This,__LONG32 *plCardID);
      HRESULT (WINAPI *get_NumberOfDigits)(ITCallingCard *This,__LONG32 *plDigits);
      HRESULT (WINAPI *get_Options)(ITCallingCard *This,__LONG32 *plOptions);
      HRESULT (WINAPI *get_CardName)(ITCallingCard *This,BSTR *ppCardName);
      HRESULT (WINAPI *get_SameAreaDialingRule)(ITCallingCard *This,BSTR *ppRule);
      HRESULT (WINAPI *get_LongDistanceDialingRule)(ITCallingCard *This,BSTR *ppRule);
      HRESULT (WINAPI *get_InternationalDialingRule)(ITCallingCard *This,BSTR *ppRule);
    END_INTERFACE
  } ITCallingCardVtbl;
  struct ITCallingCard {
    CONST_VTBL struct ITCallingCardVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCallingCard_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCallingCard_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCallingCard_Release(This) (This)->lpVtbl->Release(This)
#define ITCallingCard_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCallingCard_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCallingCard_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCallingCard_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCallingCard_get_PermanentCardID(This,plCardID) (This)->lpVtbl->get_PermanentCardID(This,plCardID)
#define ITCallingCard_get_NumberOfDigits(This,plDigits) (This)->lpVtbl->get_NumberOfDigits(This,plDigits)
#define ITCallingCard_get_Options(This,plOptions) (This)->lpVtbl->get_Options(This,plOptions)
#define ITCallingCard_get_CardName(This,ppCardName) (This)->lpVtbl->get_CardName(This,ppCardName)
#define ITCallingCard_get_SameAreaDialingRule(This,ppRule) (This)->lpVtbl->get_SameAreaDialingRule(This,ppRule)
#define ITCallingCard_get_LongDistanceDialingRule(This,ppRule) (This)->lpVtbl->get_LongDistanceDialingRule(This,ppRule)
#define ITCallingCard_get_InternationalDialingRule(This,ppRule) (This)->lpVtbl->get_InternationalDialingRule(This,ppRule)
#endif
#endif
  HRESULT WINAPI ITCallingCard_get_PermanentCardID_Proxy(ITCallingCard *This,__LONG32 *plCardID);
  void __RPC_STUB ITCallingCard_get_PermanentCardID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallingCard_get_NumberOfDigits_Proxy(ITCallingCard *This,__LONG32 *plDigits);
  void __RPC_STUB ITCallingCard_get_NumberOfDigits_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallingCard_get_Options_Proxy(ITCallingCard *This,__LONG32 *plOptions);
  void __RPC_STUB ITCallingCard_get_Options_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallingCard_get_CardName_Proxy(ITCallingCard *This,BSTR *ppCardName);
  void __RPC_STUB ITCallingCard_get_CardName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallingCard_get_SameAreaDialingRule_Proxy(ITCallingCard *This,BSTR *ppRule);
  void __RPC_STUB ITCallingCard_get_SameAreaDialingRule_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallingCard_get_LongDistanceDialingRule_Proxy(ITCallingCard *This,BSTR *ppRule);
  void __RPC_STUB ITCallingCard_get_LongDistanceDialingRule_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallingCard_get_InternationalDialingRule_Proxy(ITCallingCard *This,BSTR *ppRule);
  void __RPC_STUB ITCallingCard_get_InternationalDialingRule_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumCallingCard_INTERFACE_DEFINED__
#define __IEnumCallingCard_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumCallingCard;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumCallingCard : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITCallingCard **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumCallingCard **ppEnum) = 0;
  };
#else
  typedef struct IEnumCallingCardVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumCallingCard *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumCallingCard *This);
      ULONG (WINAPI *Release)(IEnumCallingCard *This);
      HRESULT (WINAPI *Next)(IEnumCallingCard *This,ULONG celt,ITCallingCard **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumCallingCard *This);
      HRESULT (WINAPI *Skip)(IEnumCallingCard *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumCallingCard *This,IEnumCallingCard **ppEnum);
    END_INTERFACE
  } IEnumCallingCardVtbl;
  struct IEnumCallingCard {
    CONST_VTBL struct IEnumCallingCardVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumCallingCard_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumCallingCard_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumCallingCard_Release(This) (This)->lpVtbl->Release(This)
#define IEnumCallingCard_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumCallingCard_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumCallingCard_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumCallingCard_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumCallingCard_Next_Proxy(IEnumCallingCard *This,ULONG celt,ITCallingCard **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumCallingCard_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCallingCard_Reset_Proxy(IEnumCallingCard *This);
  void __RPC_STUB IEnumCallingCard_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCallingCard_Skip_Proxy(IEnumCallingCard *This,ULONG celt);
  void __RPC_STUB IEnumCallingCard_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCallingCard_Clone_Proxy(IEnumCallingCard *This,IEnumCallingCard **ppEnum);
  void __RPC_STUB IEnumCallingCard_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITCallNotificationEvent_INTERFACE_DEFINED__
#define __ITCallNotificationEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCallNotificationEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCallNotificationEvent : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Call(ITCallInfo **ppCall) = 0;
    virtual HRESULT WINAPI get_Event(CALL_NOTIFICATION_EVENT *pCallNotificationEvent) = 0;
    virtual HRESULT WINAPI get_CallbackInstance(__LONG32 *plCallbackInstance) = 0;
  };
#else
  typedef struct ITCallNotificationEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCallNotificationEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCallNotificationEvent *This);
      ULONG (WINAPI *Release)(ITCallNotificationEvent *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITCallNotificationEvent *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITCallNotificationEvent *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITCallNotificationEvent *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITCallNotificationEvent *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Call)(ITCallNotificationEvent *This,ITCallInfo **ppCall);
      HRESULT (WINAPI *get_Event)(ITCallNotificationEvent *This,CALL_NOTIFICATION_EVENT *pCallNotificationEvent);
      HRESULT (WINAPI *get_CallbackInstance)(ITCallNotificationEvent *This,__LONG32 *plCallbackInstance);
    END_INTERFACE
  } ITCallNotificationEventVtbl;
  struct ITCallNotificationEvent {
    CONST_VTBL struct ITCallNotificationEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCallNotificationEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCallNotificationEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCallNotificationEvent_Release(This) (This)->lpVtbl->Release(This)
#define ITCallNotificationEvent_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITCallNotificationEvent_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITCallNotificationEvent_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITCallNotificationEvent_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITCallNotificationEvent_get_Call(This,ppCall) (This)->lpVtbl->get_Call(This,ppCall)
#define ITCallNotificationEvent_get_Event(This,pCallNotificationEvent) (This)->lpVtbl->get_Event(This,pCallNotificationEvent)
#define ITCallNotificationEvent_get_CallbackInstance(This,plCallbackInstance) (This)->lpVtbl->get_CallbackInstance(This,plCallbackInstance)
#endif
#endif
  HRESULT WINAPI ITCallNotificationEvent_get_Call_Proxy(ITCallNotificationEvent *This,ITCallInfo **ppCall);
  void __RPC_STUB ITCallNotificationEvent_get_Call_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallNotificationEvent_get_Event_Proxy(ITCallNotificationEvent *This,CALL_NOTIFICATION_EVENT *pCallNotificationEvent);
  void __RPC_STUB ITCallNotificationEvent_get_Event_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallNotificationEvent_get_CallbackInstance_Proxy(ITCallNotificationEvent *This,__LONG32 *plCallbackInstance);
  void __RPC_STUB ITCallNotificationEvent_get_CallbackInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITDispatchMapper_INTERFACE_DEFINED__
#define __ITDispatchMapper_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITDispatchMapper;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITDispatchMapper : public IDispatch {
  public:
    virtual HRESULT WINAPI QueryDispatchInterface(BSTR pIID,IDispatch *pInterfaceToMap,IDispatch **ppReturnedInterface) = 0;
  };
#else
  typedef struct ITDispatchMapperVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITDispatchMapper *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITDispatchMapper *This);
      ULONG (WINAPI *Release)(ITDispatchMapper *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITDispatchMapper *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITDispatchMapper *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITDispatchMapper *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITDispatchMapper *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *QueryDispatchInterface)(ITDispatchMapper *This,BSTR pIID,IDispatch *pInterfaceToMap,IDispatch **ppReturnedInterface);
    END_INTERFACE
  } ITDispatchMapperVtbl;
  struct ITDispatchMapper {
    CONST_VTBL struct ITDispatchMapperVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITDispatchMapper_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITDispatchMapper_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITDispatchMapper_Release(This) (This)->lpVtbl->Release(This)
#define ITDispatchMapper_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITDispatchMapper_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITDispatchMapper_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITDispatchMapper_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITDispatchMapper_QueryDispatchInterface(This,pIID,pInterfaceToMap,ppReturnedInterface) (This)->lpVtbl->QueryDispatchInterface(This,pIID,pInterfaceToMap,ppReturnedInterface)
#endif
#endif
  HRESULT WINAPI ITDispatchMapper_QueryDispatchInterface_Proxy(ITDispatchMapper *This,BSTR pIID,IDispatch *pInterfaceToMap,IDispatch **ppReturnedInterface);
  void __RPC_STUB ITDispatchMapper_QueryDispatchInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITStreamControl_INTERFACE_DEFINED__
#define __ITStreamControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITStreamControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITStreamControl : public IDispatch {
  public:
    virtual HRESULT WINAPI CreateStream(__LONG32 lMediaType,TERMINAL_DIRECTION td,ITStream **ppStream) = 0;
    virtual HRESULT WINAPI RemoveStream(ITStream *pStream) = 0;
    virtual HRESULT WINAPI EnumerateStreams(IEnumStream **ppEnumStream) = 0;
    virtual HRESULT WINAPI get_Streams(VARIANT *pVariant) = 0;
  };
#else
  typedef struct ITStreamControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITStreamControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITStreamControl *This);
      ULONG (WINAPI *Release)(ITStreamControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITStreamControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITStreamControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITStreamControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITStreamControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *CreateStream)(ITStreamControl *This,__LONG32 lMediaType,TERMINAL_DIRECTION td,ITStream **ppStream);
      HRESULT (WINAPI *RemoveStream)(ITStreamControl *This,ITStream *pStream);
      HRESULT (WINAPI *EnumerateStreams)(ITStreamControl *This,IEnumStream **ppEnumStream);
      HRESULT (WINAPI *get_Streams)(ITStreamControl *This,VARIANT *pVariant);
    END_INTERFACE
  } ITStreamControlVtbl;
  struct ITStreamControl {
    CONST_VTBL struct ITStreamControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITStreamControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITStreamControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITStreamControl_Release(This) (This)->lpVtbl->Release(This)
#define ITStreamControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITStreamControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITStreamControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITStreamControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITStreamControl_CreateStream(This,lMediaType,td,ppStream) (This)->lpVtbl->CreateStream(This,lMediaType,td,ppStream)
#define ITStreamControl_RemoveStream(This,pStream) (This)->lpVtbl->RemoveStream(This,pStream)
#define ITStreamControl_EnumerateStreams(This,ppEnumStream) (This)->lpVtbl->EnumerateStreams(This,ppEnumStream)
#define ITStreamControl_get_Streams(This,pVariant) (This)->lpVtbl->get_Streams(This,pVariant)
#endif
#endif
  HRESULT WINAPI ITStreamControl_CreateStream_Proxy(ITStreamControl *This,__LONG32 lMediaType,TERMINAL_DIRECTION td,ITStream **ppStream);
  void __RPC_STUB ITStreamControl_CreateStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStreamControl_RemoveStream_Proxy(ITStreamControl *This,ITStream *pStream);
  void __RPC_STUB ITStreamControl_RemoveStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStreamControl_EnumerateStreams_Proxy(ITStreamControl *This,IEnumStream **ppEnumStream);
  void __RPC_STUB ITStreamControl_EnumerateStreams_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStreamControl_get_Streams_Proxy(ITStreamControl *This,VARIANT *pVariant);
  void __RPC_STUB ITStreamControl_get_Streams_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITStream_INTERFACE_DEFINED__
#define __ITStream_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITStream;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITStream : public IDispatch {
  public:
    virtual HRESULT WINAPI get_MediaType(__LONG32 *plMediaType) = 0;
    virtual HRESULT WINAPI get_Direction(TERMINAL_DIRECTION *pTD) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *ppName) = 0;
    virtual HRESULT WINAPI StartStream(void) = 0;
    virtual HRESULT WINAPI PauseStream(void) = 0;
    virtual HRESULT WINAPI StopStream(void) = 0;
    virtual HRESULT WINAPI SelectTerminal(ITTerminal *pTerminal) = 0;
    virtual HRESULT WINAPI UnselectTerminal(ITTerminal *pTerminal) = 0;
    virtual HRESULT WINAPI EnumerateTerminals(IEnumTerminal **ppEnumTerminal) = 0;
    virtual HRESULT WINAPI get_Terminals(VARIANT *pTerminals) = 0;
  };
#else
  typedef struct ITStreamVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITStream *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITStream *This);
      ULONG (WINAPI *Release)(ITStream *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITStream *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITStream *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITStream *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITStream *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_MediaType)(ITStream *This,__LONG32 *plMediaType);
      HRESULT (WINAPI *get_Direction)(ITStream *This,TERMINAL_DIRECTION *pTD);
      HRESULT (WINAPI *get_Name)(ITStream *This,BSTR *ppName);
      HRESULT (WINAPI *StartStream)(ITStream *This);
      HRESULT (WINAPI *PauseStream)(ITStream *This);
      HRESULT (WINAPI *StopStream)(ITStream *This);
      HRESULT (WINAPI *SelectTerminal)(ITStream *This,ITTerminal *pTerminal);
      HRESULT (WINAPI *UnselectTerminal)(ITStream *This,ITTerminal *pTerminal);
      HRESULT (WINAPI *EnumerateTerminals)(ITStream *This,IEnumTerminal **ppEnumTerminal);
      HRESULT (WINAPI *get_Terminals)(ITStream *This,VARIANT *pTerminals);
    END_INTERFACE
  } ITStreamVtbl;
  struct ITStream {
    CONST_VTBL struct ITStreamVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITStream_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITStream_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITStream_Release(This) (This)->lpVtbl->Release(This)
#define ITStream_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITStream_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITStream_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITStream_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITStream_get_MediaType(This,plMediaType) (This)->lpVtbl->get_MediaType(This,plMediaType)
#define ITStream_get_Direction(This,pTD) (This)->lpVtbl->get_Direction(This,pTD)
#define ITStream_get_Name(This,ppName) (This)->lpVtbl->get_Name(This,ppName)
#define ITStream_StartStream(This) (This)->lpVtbl->StartStream(This)
#define ITStream_PauseStream(This) (This)->lpVtbl->PauseStream(This)
#define ITStream_StopStream(This) (This)->lpVtbl->StopStream(This)
#define ITStream_SelectTerminal(This,pTerminal) (This)->lpVtbl->SelectTerminal(This,pTerminal)
#define ITStream_UnselectTerminal(This,pTerminal) (This)->lpVtbl->UnselectTerminal(This,pTerminal)
#define ITStream_EnumerateTerminals(This,ppEnumTerminal) (This)->lpVtbl->EnumerateTerminals(This,ppEnumTerminal)
#define ITStream_get_Terminals(This,pTerminals) (This)->lpVtbl->get_Terminals(This,pTerminals)
#endif
#endif
  HRESULT WINAPI ITStream_get_MediaType_Proxy(ITStream *This,__LONG32 *plMediaType);
  void __RPC_STUB ITStream_get_MediaType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStream_get_Direction_Proxy(ITStream *This,TERMINAL_DIRECTION *pTD);
  void __RPC_STUB ITStream_get_Direction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStream_get_Name_Proxy(ITStream *This,BSTR *ppName);
  void __RPC_STUB ITStream_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStream_StartStream_Proxy(ITStream *This);
  void __RPC_STUB ITStream_StartStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStream_PauseStream_Proxy(ITStream *This);
  void __RPC_STUB ITStream_PauseStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStream_StopStream_Proxy(ITStream *This);
  void __RPC_STUB ITStream_StopStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStream_SelectTerminal_Proxy(ITStream *This,ITTerminal *pTerminal);
  void __RPC_STUB ITStream_SelectTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStream_UnselectTerminal_Proxy(ITStream *This,ITTerminal *pTerminal);
  void __RPC_STUB ITStream_UnselectTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStream_EnumerateTerminals_Proxy(ITStream *This,IEnumTerminal **ppEnumTerminal);
  void __RPC_STUB ITStream_EnumerateTerminals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStream_get_Terminals_Proxy(ITStream *This,VARIANT *pTerminals);
  void __RPC_STUB ITStream_get_Terminals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumStream_INTERFACE_DEFINED__
#define __IEnumStream_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumStream;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumStream : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITStream **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumStream **ppEnum) = 0;
  };
#else
  typedef struct IEnumStreamVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumStream *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumStream *This);
      ULONG (WINAPI *Release)(IEnumStream *This);
      HRESULT (WINAPI *Next)(IEnumStream *This,ULONG celt,ITStream **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumStream *This);
      HRESULT (WINAPI *Skip)(IEnumStream *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumStream *This,IEnumStream **ppEnum);
    END_INTERFACE
  } IEnumStreamVtbl;
  struct IEnumStream {
    CONST_VTBL struct IEnumStreamVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumStream_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumStream_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumStream_Release(This) (This)->lpVtbl->Release(This)
#define IEnumStream_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumStream_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumStream_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumStream_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumStream_Next_Proxy(IEnumStream *This,ULONG celt,ITStream **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumStream_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumStream_Reset_Proxy(IEnumStream *This);
  void __RPC_STUB IEnumStream_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumStream_Skip_Proxy(IEnumStream *This,ULONG celt);
  void __RPC_STUB IEnumStream_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumStream_Clone_Proxy(IEnumStream *This,IEnumStream **ppEnum);
  void __RPC_STUB IEnumStream_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITSubStreamControl_INTERFACE_DEFINED__
#define __ITSubStreamControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITSubStreamControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITSubStreamControl : public IDispatch {
  public:
    virtual HRESULT WINAPI CreateSubStream(ITSubStream **ppSubStream) = 0;
    virtual HRESULT WINAPI RemoveSubStream(ITSubStream *pSubStream) = 0;
    virtual HRESULT WINAPI EnumerateSubStreams(IEnumSubStream **ppEnumSubStream) = 0;
    virtual HRESULT WINAPI get_SubStreams(VARIANT *pVariant) = 0;
  };
#else
  typedef struct ITSubStreamControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITSubStreamControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITSubStreamControl *This);
      ULONG (WINAPI *Release)(ITSubStreamControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITSubStreamControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITSubStreamControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITSubStreamControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITSubStreamControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *CreateSubStream)(ITSubStreamControl *This,ITSubStream **ppSubStream);
      HRESULT (WINAPI *RemoveSubStream)(ITSubStreamControl *This,ITSubStream *pSubStream);
      HRESULT (WINAPI *EnumerateSubStreams)(ITSubStreamControl *This,IEnumSubStream **ppEnumSubStream);
      HRESULT (WINAPI *get_SubStreams)(ITSubStreamControl *This,VARIANT *pVariant);
    END_INTERFACE
  } ITSubStreamControlVtbl;
  struct ITSubStreamControl {
    CONST_VTBL struct ITSubStreamControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITSubStreamControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITSubStreamControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITSubStreamControl_Release(This) (This)->lpVtbl->Release(This)
#define ITSubStreamControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITSubStreamControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITSubStreamControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITSubStreamControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITSubStreamControl_CreateSubStream(This,ppSubStream) (This)->lpVtbl->CreateSubStream(This,ppSubStream)
#define ITSubStreamControl_RemoveSubStream(This,pSubStream) (This)->lpVtbl->RemoveSubStream(This,pSubStream)
#define ITSubStreamControl_EnumerateSubStreams(This,ppEnumSubStream) (This)->lpVtbl->EnumerateSubStreams(This,ppEnumSubStream)
#define ITSubStreamControl_get_SubStreams(This,pVariant) (This)->lpVtbl->get_SubStreams(This,pVariant)
#endif
#endif
  HRESULT WINAPI ITSubStreamControl_CreateSubStream_Proxy(ITSubStreamControl *This,ITSubStream **ppSubStream);
  void __RPC_STUB ITSubStreamControl_CreateSubStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSubStreamControl_RemoveSubStream_Proxy(ITSubStreamControl *This,ITSubStream *pSubStream);
  void __RPC_STUB ITSubStreamControl_RemoveSubStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSubStreamControl_EnumerateSubStreams_Proxy(ITSubStreamControl *This,IEnumSubStream **ppEnumSubStream);
  void __RPC_STUB ITSubStreamControl_EnumerateSubStreams_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSubStreamControl_get_SubStreams_Proxy(ITSubStreamControl *This,VARIANT *pVariant);
  void __RPC_STUB ITSubStreamControl_get_SubStreams_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITSubStream_INTERFACE_DEFINED__
#define __ITSubStream_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITSubStream;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITSubStream : public IDispatch {
  public:
    virtual HRESULT WINAPI StartSubStream(void) = 0;
    virtual HRESULT WINAPI PauseSubStream(void) = 0;
    virtual HRESULT WINAPI StopSubStream(void) = 0;
    virtual HRESULT WINAPI SelectTerminal(ITTerminal *pTerminal) = 0;
    virtual HRESULT WINAPI UnselectTerminal(ITTerminal *pTerminal) = 0;
    virtual HRESULT WINAPI EnumerateTerminals(IEnumTerminal **ppEnumTerminal) = 0;
    virtual HRESULT WINAPI get_Terminals(VARIANT *pTerminals) = 0;
    virtual HRESULT WINAPI get_Stream(ITStream **ppITStream) = 0;
  };
#else
  typedef struct ITSubStreamVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITSubStream *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITSubStream *This);
      ULONG (WINAPI *Release)(ITSubStream *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITSubStream *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITSubStream *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITSubStream *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITSubStream *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *StartSubStream)(ITSubStream *This);
      HRESULT (WINAPI *PauseSubStream)(ITSubStream *This);
      HRESULT (WINAPI *StopSubStream)(ITSubStream *This);
      HRESULT (WINAPI *SelectTerminal)(ITSubStream *This,ITTerminal *pTerminal);
      HRESULT (WINAPI *UnselectTerminal)(ITSubStream *This,ITTerminal *pTerminal);
      HRESULT (WINAPI *EnumerateTerminals)(ITSubStream *This,IEnumTerminal **ppEnumTerminal);
      HRESULT (WINAPI *get_Terminals)(ITSubStream *This,VARIANT *pTerminals);
      HRESULT (WINAPI *get_Stream)(ITSubStream *This,ITStream **ppITStream);
    END_INTERFACE
  } ITSubStreamVtbl;
  struct ITSubStream {
    CONST_VTBL struct ITSubStreamVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITSubStream_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITSubStream_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITSubStream_Release(This) (This)->lpVtbl->Release(This)
#define ITSubStream_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITSubStream_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITSubStream_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITSubStream_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITSubStream_StartSubStream(This) (This)->lpVtbl->StartSubStream(This)
#define ITSubStream_PauseSubStream(This) (This)->lpVtbl->PauseSubStream(This)
#define ITSubStream_StopSubStream(This) (This)->lpVtbl->StopSubStream(This)
#define ITSubStream_SelectTerminal(This,pTerminal) (This)->lpVtbl->SelectTerminal(This,pTerminal)
#define ITSubStream_UnselectTerminal(This,pTerminal) (This)->lpVtbl->UnselectTerminal(This,pTerminal)
#define ITSubStream_EnumerateTerminals(This,ppEnumTerminal) (This)->lpVtbl->EnumerateTerminals(This,ppEnumTerminal)
#define ITSubStream_get_Terminals(This,pTerminals) (This)->lpVtbl->get_Terminals(This,pTerminals)
#define ITSubStream_get_Stream(This,ppITStream) (This)->lpVtbl->get_Stream(This,ppITStream)
#endif
#endif
  HRESULT WINAPI ITSubStream_StartSubStream_Proxy(ITSubStream *This);
  void __RPC_STUB ITSubStream_StartSubStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSubStream_PauseSubStream_Proxy(ITSubStream *This);
  void __RPC_STUB ITSubStream_PauseSubStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSubStream_StopSubStream_Proxy(ITSubStream *This);
  void __RPC_STUB ITSubStream_StopSubStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSubStream_SelectTerminal_Proxy(ITSubStream *This,ITTerminal *pTerminal);
  void __RPC_STUB ITSubStream_SelectTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSubStream_UnselectTerminal_Proxy(ITSubStream *This,ITTerminal *pTerminal);
  void __RPC_STUB ITSubStream_UnselectTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSubStream_EnumerateTerminals_Proxy(ITSubStream *This,IEnumTerminal **ppEnumTerminal);
  void __RPC_STUB ITSubStream_EnumerateTerminals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSubStream_get_Terminals_Proxy(ITSubStream *This,VARIANT *pTerminals);
  void __RPC_STUB ITSubStream_get_Terminals_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSubStream_get_Stream_Proxy(ITSubStream *This,ITStream **ppITStream);
  void __RPC_STUB ITSubStream_get_Stream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumSubStream_INTERFACE_DEFINED__
#define __IEnumSubStream_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumSubStream;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumSubStream : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITSubStream **ppElements,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumSubStream **ppEnum) = 0;
  };
#else
  typedef struct IEnumSubStreamVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumSubStream *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumSubStream *This);
      ULONG (WINAPI *Release)(IEnumSubStream *This);
      HRESULT (WINAPI *Next)(IEnumSubStream *This,ULONG celt,ITSubStream **ppElements,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumSubStream *This);
      HRESULT (WINAPI *Skip)(IEnumSubStream *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumSubStream *This,IEnumSubStream **ppEnum);
    END_INTERFACE
  } IEnumSubStreamVtbl;
  struct IEnumSubStream {
    CONST_VTBL struct IEnumSubStreamVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumSubStream_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumSubStream_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumSubStream_Release(This) (This)->lpVtbl->Release(This)
#define IEnumSubStream_Next(This,celt,ppElements,pceltFetched) (This)->lpVtbl->Next(This,celt,ppElements,pceltFetched)
#define IEnumSubStream_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumSubStream_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumSubStream_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumSubStream_Next_Proxy(IEnumSubStream *This,ULONG celt,ITSubStream **ppElements,ULONG *pceltFetched);
  void __RPC_STUB IEnumSubStream_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumSubStream_Reset_Proxy(IEnumSubStream *This);
  void __RPC_STUB IEnumSubStream_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumSubStream_Skip_Proxy(IEnumSubStream *This,ULONG celt);
  void __RPC_STUB IEnumSubStream_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumSubStream_Clone_Proxy(IEnumSubStream *This,IEnumSubStream **ppEnum);
  void __RPC_STUB IEnumSubStream_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITLegacyWaveSupport_INTERFACE_DEFINED__
#define __ITLegacyWaveSupport_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITLegacyWaveSupport;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITLegacyWaveSupport : public IDispatch {
  public:
    virtual HRESULT WINAPI IsFullDuplex(FULLDUPLEX_SUPPORT *pSupport) = 0;
  };
#else
  typedef struct ITLegacyWaveSupportVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITLegacyWaveSupport *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITLegacyWaveSupport *This);
      ULONG (WINAPI *Release)(ITLegacyWaveSupport *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITLegacyWaveSupport *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITLegacyWaveSupport *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITLegacyWaveSupport *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITLegacyWaveSupport *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *IsFullDuplex)(ITLegacyWaveSupport *This,FULLDUPLEX_SUPPORT *pSupport);
    END_INTERFACE
  } ITLegacyWaveSupportVtbl;
  struct ITLegacyWaveSupport {
    CONST_VTBL struct ITLegacyWaveSupportVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITLegacyWaveSupport_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITLegacyWaveSupport_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITLegacyWaveSupport_Release(This) (This)->lpVtbl->Release(This)
#define ITLegacyWaveSupport_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITLegacyWaveSupport_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITLegacyWaveSupport_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITLegacyWaveSupport_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITLegacyWaveSupport_IsFullDuplex(This,pSupport) (This)->lpVtbl->IsFullDuplex(This,pSupport)
#endif
#endif
  HRESULT WINAPI ITLegacyWaveSupport_IsFullDuplex_Proxy(ITLegacyWaveSupport *This,FULLDUPLEX_SUPPORT *pSupport);
  void __RPC_STUB ITLegacyWaveSupport_IsFullDuplex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITBasicCallControl2_INTERFACE_DEFINED__
#define __ITBasicCallControl2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITBasicCallControl2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITBasicCallControl2 : public ITBasicCallControl {
  public:
    virtual HRESULT WINAPI RequestTerminal(BSTR bstrTerminalClassGUID,__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal) = 0;
    virtual HRESULT WINAPI SelectTerminalOnCall(ITTerminal *pTerminal) = 0;
    virtual HRESULT WINAPI UnselectTerminalOnCall(ITTerminal *pTerminal) = 0;
  };
#else
  typedef struct ITBasicCallControl2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITBasicCallControl2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITBasicCallControl2 *This);
      ULONG (WINAPI *Release)(ITBasicCallControl2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITBasicCallControl2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITBasicCallControl2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITBasicCallControl2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITBasicCallControl2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Connect)(ITBasicCallControl2 *This,VARIANT_BOOL fSync);
      HRESULT (WINAPI *Answer)(ITBasicCallControl2 *This);
      HRESULT (WINAPI *Disconnect)(ITBasicCallControl2 *This,DISCONNECT_CODE code);
      HRESULT (WINAPI *Hold)(ITBasicCallControl2 *This,VARIANT_BOOL fHold);
      HRESULT (WINAPI *HandoffDirect)(ITBasicCallControl2 *This,BSTR pApplicationName);
      HRESULT (WINAPI *HandoffIndirect)(ITBasicCallControl2 *This,__LONG32 lMediaType);
      HRESULT (WINAPI *Conference)(ITBasicCallControl2 *This,ITBasicCallControl *pCall,VARIANT_BOOL fSync);
      HRESULT (WINAPI *Transfer)(ITBasicCallControl2 *This,ITBasicCallControl *pCall,VARIANT_BOOL fSync);
      HRESULT (WINAPI *BlindTransfer)(ITBasicCallControl2 *This,BSTR pDestAddress);
      HRESULT (WINAPI *SwapHold)(ITBasicCallControl2 *This,ITBasicCallControl *pCall);
      HRESULT (WINAPI *ParkDirect)(ITBasicCallControl2 *This,BSTR pParkAddress);
      HRESULT (WINAPI *ParkIndirect)(ITBasicCallControl2 *This,BSTR *ppNonDirAddress);
      HRESULT (WINAPI *Unpark)(ITBasicCallControl2 *This);
      HRESULT (WINAPI *SetQOS)(ITBasicCallControl2 *This,__LONG32 lMediaType,QOS_SERVICE_LEVEL ServiceLevel);
      HRESULT (WINAPI *Pickup)(ITBasicCallControl2 *This,BSTR pGroupID);
      HRESULT (WINAPI *Dial)(ITBasicCallControl2 *This,BSTR pDestAddress);
      HRESULT (WINAPI *Finish)(ITBasicCallControl2 *This,FINISH_MODE finishMode);
      HRESULT (WINAPI *RemoveFromConference)(ITBasicCallControl2 *This);
      HRESULT (WINAPI *RequestTerminal)(ITBasicCallControl2 *This,BSTR bstrTerminalClassGUID,__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal);
      HRESULT (WINAPI *SelectTerminalOnCall)(ITBasicCallControl2 *This,ITTerminal *pTerminal);
      HRESULT (WINAPI *UnselectTerminalOnCall)(ITBasicCallControl2 *This,ITTerminal *pTerminal);
    END_INTERFACE
  } ITBasicCallControl2Vtbl;
  struct ITBasicCallControl2 {
    CONST_VTBL struct ITBasicCallControl2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITBasicCallControl2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITBasicCallControl2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITBasicCallControl2_Release(This) (This)->lpVtbl->Release(This)
#define ITBasicCallControl2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITBasicCallControl2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITBasicCallControl2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITBasicCallControl2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITBasicCallControl2_Connect(This,fSync) (This)->lpVtbl->Connect(This,fSync)
#define ITBasicCallControl2_Answer(This) (This)->lpVtbl->Answer(This)
#define ITBasicCallControl2_Disconnect(This,code) (This)->lpVtbl->Disconnect(This,code)
#define ITBasicCallControl2_Hold(This,fHold) (This)->lpVtbl->Hold(This,fHold)
#define ITBasicCallControl2_HandoffDirect(This,pApplicationName) (This)->lpVtbl->HandoffDirect(This,pApplicationName)
#define ITBasicCallControl2_HandoffIndirect(This,lMediaType) (This)->lpVtbl->HandoffIndirect(This,lMediaType)
#define ITBasicCallControl2_Conference(This,pCall,fSync) (This)->lpVtbl->Conference(This,pCall,fSync)
#define ITBasicCallControl2_Transfer(This,pCall,fSync) (This)->lpVtbl->Transfer(This,pCall,fSync)
#define ITBasicCallControl2_BlindTransfer(This,pDestAddress) (This)->lpVtbl->BlindTransfer(This,pDestAddress)
#define ITBasicCallControl2_SwapHold(This,pCall) (This)->lpVtbl->SwapHold(This,pCall)
#define ITBasicCallControl2_ParkDirect(This,pParkAddress) (This)->lpVtbl->ParkDirect(This,pParkAddress)
#define ITBasicCallControl2_ParkIndirect(This,ppNonDirAddress) (This)->lpVtbl->ParkIndirect(This,ppNonDirAddress)
#define ITBasicCallControl2_Unpark(This) (This)->lpVtbl->Unpark(This)
#define ITBasicCallControl2_SetQOS(This,lMediaType,ServiceLevel) (This)->lpVtbl->SetQOS(This,lMediaType,ServiceLevel)
#define ITBasicCallControl2_Pickup(This,pGroupID) (This)->lpVtbl->Pickup(This,pGroupID)
#define ITBasicCallControl2_Dial(This,pDestAddress) (This)->lpVtbl->Dial(This,pDestAddress)
#define ITBasicCallControl2_Finish(This,finishMode) (This)->lpVtbl->Finish(This,finishMode)
#define ITBasicCallControl2_RemoveFromConference(This) (This)->lpVtbl->RemoveFromConference(This)
#define ITBasicCallControl2_RequestTerminal(This,bstrTerminalClassGUID,lMediaType,Direction,ppTerminal) (This)->lpVtbl->RequestTerminal(This,bstrTerminalClassGUID,lMediaType,Direction,ppTerminal)
#define ITBasicCallControl2_SelectTerminalOnCall(This,pTerminal) (This)->lpVtbl->SelectTerminalOnCall(This,pTerminal)
#define ITBasicCallControl2_UnselectTerminalOnCall(This,pTerminal) (This)->lpVtbl->UnselectTerminalOnCall(This,pTerminal)
#endif
#endif
  HRESULT WINAPI ITBasicCallControl2_RequestTerminal_Proxy(ITBasicCallControl2 *This,BSTR bstrTerminalClassGUID,__LONG32 lMediaType,TERMINAL_DIRECTION Direction,ITTerminal **ppTerminal);
  void __RPC_STUB ITBasicCallControl2_RequestTerminal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl2_SelectTerminalOnCall_Proxy(ITBasicCallControl2 *This,ITTerminal *pTerminal);
  void __RPC_STUB ITBasicCallControl2_SelectTerminalOnCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITBasicCallControl2_UnselectTerminalOnCall_Proxy(ITBasicCallControl2 *This,ITTerminal *pTerminal);
  void __RPC_STUB ITBasicCallControl2_UnselectTerminalOnCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITScriptableAudioFormat_INTERFACE_DEFINED__
#define __ITScriptableAudioFormat_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITScriptableAudioFormat;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITScriptableAudioFormat : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Channels(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI put_Channels(const __LONG32 nNewVal) = 0;
    virtual HRESULT WINAPI get_SamplesPerSec(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI put_SamplesPerSec(const __LONG32 nNewVal) = 0;
    virtual HRESULT WINAPI get_AvgBytesPerSec(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI put_AvgBytesPerSec(const __LONG32 nNewVal) = 0;
    virtual HRESULT WINAPI get_BlockAlign(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI put_BlockAlign(const __LONG32 nNewVal) = 0;
    virtual HRESULT WINAPI get_BitsPerSample(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI put_BitsPerSample(const __LONG32 nNewVal) = 0;
    virtual HRESULT WINAPI get_FormatTag(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI put_FormatTag(const __LONG32 nNewVal) = 0;
  };
#else
  typedef struct ITScriptableAudioFormatVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITScriptableAudioFormat *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITScriptableAudioFormat *This);
      ULONG (WINAPI *Release)(ITScriptableAudioFormat *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITScriptableAudioFormat *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITScriptableAudioFormat *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITScriptableAudioFormat *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITScriptableAudioFormat *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Channels)(ITScriptableAudioFormat *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_Channels)(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
      HRESULT (WINAPI *get_SamplesPerSec)(ITScriptableAudioFormat *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_SamplesPerSec)(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
      HRESULT (WINAPI *get_AvgBytesPerSec)(ITScriptableAudioFormat *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_AvgBytesPerSec)(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
      HRESULT (WINAPI *get_BlockAlign)(ITScriptableAudioFormat *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_BlockAlign)(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
      HRESULT (WINAPI *get_BitsPerSample)(ITScriptableAudioFormat *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_BitsPerSample)(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
      HRESULT (WINAPI *get_FormatTag)(ITScriptableAudioFormat *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_FormatTag)(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
    END_INTERFACE
  } ITScriptableAudioFormatVtbl;
  struct ITScriptableAudioFormat {
    CONST_VTBL struct ITScriptableAudioFormatVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITScriptableAudioFormat_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITScriptableAudioFormat_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITScriptableAudioFormat_Release(This) (This)->lpVtbl->Release(This)
#define ITScriptableAudioFormat_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITScriptableAudioFormat_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITScriptableAudioFormat_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITScriptableAudioFormat_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITScriptableAudioFormat_get_Channels(This,pVal) (This)->lpVtbl->get_Channels(This,pVal)
#define ITScriptableAudioFormat_put_Channels(This,nNewVal) (This)->lpVtbl->put_Channels(This,nNewVal)
#define ITScriptableAudioFormat_get_SamplesPerSec(This,pVal) (This)->lpVtbl->get_SamplesPerSec(This,pVal)
#define ITScriptableAudioFormat_put_SamplesPerSec(This,nNewVal) (This)->lpVtbl->put_SamplesPerSec(This,nNewVal)
#define ITScriptableAudioFormat_get_AvgBytesPerSec(This,pVal) (This)->lpVtbl->get_AvgBytesPerSec(This,pVal)
#define ITScriptableAudioFormat_put_AvgBytesPerSec(This,nNewVal) (This)->lpVtbl->put_AvgBytesPerSec(This,nNewVal)
#define ITScriptableAudioFormat_get_BlockAlign(This,pVal) (This)->lpVtbl->get_BlockAlign(This,pVal)
#define ITScriptableAudioFormat_put_BlockAlign(This,nNewVal) (This)->lpVtbl->put_BlockAlign(This,nNewVal)
#define ITScriptableAudioFormat_get_BitsPerSample(This,pVal) (This)->lpVtbl->get_BitsPerSample(This,pVal)
#define ITScriptableAudioFormat_put_BitsPerSample(This,nNewVal) (This)->lpVtbl->put_BitsPerSample(This,nNewVal)
#define ITScriptableAudioFormat_get_FormatTag(This,pVal) (This)->lpVtbl->get_FormatTag(This,pVal)
#define ITScriptableAudioFormat_put_FormatTag(This,nNewVal) (This)->lpVtbl->put_FormatTag(This,nNewVal)
#endif
#endif
  HRESULT WINAPI ITScriptableAudioFormat_get_Channels_Proxy(ITScriptableAudioFormat *This,__LONG32 *pVal);
  void __RPC_STUB ITScriptableAudioFormat_get_Channels_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITScriptableAudioFormat_put_Channels_Proxy(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
  void __RPC_STUB ITScriptableAudioFormat_put_Channels_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITScriptableAudioFormat_get_SamplesPerSec_Proxy(ITScriptableAudioFormat *This,__LONG32 *pVal);
  void __RPC_STUB ITScriptableAudioFormat_get_SamplesPerSec_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITScriptableAudioFormat_put_SamplesPerSec_Proxy(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
  void __RPC_STUB ITScriptableAudioFormat_put_SamplesPerSec_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITScriptableAudioFormat_get_AvgBytesPerSec_Proxy(ITScriptableAudioFormat *This,__LONG32 *pVal);
  void __RPC_STUB ITScriptableAudioFormat_get_AvgBytesPerSec_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITScriptableAudioFormat_put_AvgBytesPerSec_Proxy(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
  void __RPC_STUB ITScriptableAudioFormat_put_AvgBytesPerSec_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITScriptableAudioFormat_get_BlockAlign_Proxy(ITScriptableAudioFormat *This,__LONG32 *pVal);
  void __RPC_STUB ITScriptableAudioFormat_get_BlockAlign_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITScriptableAudioFormat_put_BlockAlign_Proxy(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
  void __RPC_STUB ITScriptableAudioFormat_put_BlockAlign_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITScriptableAudioFormat_get_BitsPerSample_Proxy(ITScriptableAudioFormat *This,__LONG32 *pVal);
  void __RPC_STUB ITScriptableAudioFormat_get_BitsPerSample_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITScriptableAudioFormat_put_BitsPerSample_Proxy(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
  void __RPC_STUB ITScriptableAudioFormat_put_BitsPerSample_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITScriptableAudioFormat_get_FormatTag_Proxy(ITScriptableAudioFormat *This,__LONG32 *pVal);
  void __RPC_STUB ITScriptableAudioFormat_get_FormatTag_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITScriptableAudioFormat_put_FormatTag_Proxy(ITScriptableAudioFormat *This,const __LONG32 nNewVal);
  void __RPC_STUB ITScriptableAudioFormat_put_FormatTag_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_VideoWindowTerm;
  EXTERN_C const CLSID CLSID_VideoInputTerminal;
  EXTERN_C const CLSID CLSID_HandsetTerminal;
  EXTERN_C const CLSID CLSID_HeadsetTerminal;
  EXTERN_C const CLSID CLSID_SpeakerphoneTerminal;
  EXTERN_C const CLSID CLSID_MicrophoneTerminal;
  EXTERN_C const CLSID CLSID_SpeakersTerminal;
  EXTERN_C const CLSID CLSID_MediaStreamTerminal;
  EXTERN_C const CLSID CLSID_FileRecordingTerminal;
  EXTERN_C const CLSID CLSID_FileRecordingTrack;
  EXTERN_C const CLSID CLSID_FilePlaybackTerminal;

#define TAPIMEDIATYPE_AUDIO 0x8
#define TAPIMEDIATYPE_VIDEO 0x8000
#define TAPIMEDIATYPE_DATAMODEM 0x10
#define TAPIMEDIATYPE_G3FAX 0x20
#define TAPIMEDIATYPE_MULTITRACK 0x10000

  EXTERN_C const CLSID TAPIPROTOCOL_PSTN;
  EXTERN_C const CLSID TAPIPROTOCOL_H323;
  EXTERN_C const CLSID TAPIPROTOCOL_Multicast;

#define __TapiConstants_MODULE_DEFINED__

  extern RPC_IF_HANDLE __MIDL_itf_tapi3if_0499_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_tapi3if_0499_v0_0_s_ifspec;

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API HWND_UserSize(ULONG *,ULONG,HWND *);
  unsigned char *__RPC_API HWND_UserMarshal(ULONG *,unsigned char *,HWND *);
  unsigned char *__RPC_API HWND_UserUnmarshal(ULONG *,unsigned char *,HWND *);
  void __RPC_API HWND_UserFree(ULONG *,HWND *);
  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
