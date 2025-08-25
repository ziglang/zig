/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef TSPI_H
#define TSPI_H

#include <windows.h>
#include "tapi.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef DECLARE_OPAQUE
#define DECLARE_OPAQUE(name) struct name##__ { int unused; }; typedef const struct name##__ *name
#endif

#ifndef TSPIAPI
#define TSPIAPI WINAPI
#endif

  DECLARE_OPAQUE(HDRVCALL);
  DECLARE_OPAQUE(HDRVLINE);
  DECLARE_OPAQUE(HDRVPHONE);
  DECLARE_OPAQUE(HDRVMSPLINE);
  DECLARE_OPAQUE(HDRVDIALOGINSTANCE);

  typedef HDRVCALL *LPHDRVCALL;
  typedef HDRVLINE *LPHDRVLINE;
  typedef HDRVPHONE *LPHDRVPHONE;
  typedef HDRVDIALOGINSTANCE *LPHDRVDIALOGINSTANCE;
  typedef HDRVMSPLINE *LPHDRVMSPLINE;

  DECLARE_OPAQUE(HTAPICALL);
  DECLARE_OPAQUE(HTAPILINE);
  DECLARE_OPAQUE(HTAPIPHONE);
  DECLARE_OPAQUE32(HTAPIDIALOGINSTANCE);
  DECLARE_OPAQUE32(HTAPIMSPLINE);

  typedef HTAPICALL *LPHTAPICALL;
  typedef HTAPILINE *LPHTAPILINE;
  typedef HTAPIPHONE *LPHTAPIPHONE;
  typedef HTAPIDIALOGINSTANCE *LPHTAPIDIALOGINSTANCE;
  typedef HTAPIMSPLINE *LPHTAPIMSPLINE;

  DECLARE_OPAQUE(HPROVIDER);
  typedef HPROVIDER *LPHPROVIDER;

  typedef DWORD DRV_REQUESTID;

  typedef void (CALLBACK *ASYNC_COMPLETION)(DRV_REQUESTID dwRequestID,LONG lResult);
  typedef void (CALLBACK *LINEEVENT)(HTAPILINE htLine,HTAPICALL htCall,DWORD dwMsg,DWORD_PTR dwParam1,DWORD_PTR dwParam2,DWORD_PTR dwParam3);
  typedef void (CALLBACK *PHONEEVENT)(HTAPIPHONE htPhone,DWORD dwMsg,DWORD_PTR dwParam1,DWORD_PTR dwParam2,DWORD_PTR dwParam3);
  typedef LONG (CALLBACK *TUISPIDLLCALLBACK)(DWORD_PTR dwObjectID,DWORD dwObjectType,LPVOID lpParams,DWORD dwSize);

  typedef struct tuispicreatedialoginstanceparams_tag {
    DRV_REQUESTID dwRequestID;
    HDRVDIALOGINSTANCE hdDlgInst;
    HTAPIDIALOGINSTANCE htDlgInst;
    LPCWSTR lpszUIDLLName;
    LPVOID lpParams;
    DWORD dwSize;
  } TUISPICREATEDIALOGINSTANCEPARAMS,*LPTUISPICREATEDIALOGINSTANCEPARAMS;

#define LINEQOSSTRUCT_KEY ((DWORD)'LQSK')

  typedef struct LINEQOSSERVICELEVEL_tag {
    DWORD dwMediaMode;
    DWORD dwQOSServiceLevel;
  } LINEQOSSERVICELEVEL,*LPLINEQOSSERVICELEVEL;

  typedef struct LINECALLQOSINFO_tag {
    DWORD dwKey;
    DWORD dwTotalSize;
    DWORD dwQOSRequestType;
    __C89_NAMELESS union {
      struct {
	DWORD dwNumServiceLevelEntries;
	LINEQOSSERVICELEVEL LineQOSServiceLevel[1];
      } SetQOSServiceLevel;
    };
  } LINECALLQOSINFO,*LPLINECALLQOSINFO;

  EXTERN_C const CLSID TAPIPROTOCOL_PSTN;
  EXTERN_C const CLSID TAPIPROTOCOL_H323;
  EXTERN_C const CLSID TAPIPROTOCOL_Multicast;

#define TSPI_MESSAGE_BASE 500
#define LINE_NEWCALL ((__LONG32) TSPI_MESSAGE_BASE + 0)
#define LINE_CALLDEVSPECIFIC ((__LONG32) TSPI_MESSAGE_BASE + 1)
#define LINE_CALLDEVSPECIFICFEATURE ((__LONG32) TSPI_MESSAGE_BASE + 2)
#define LINE_CREATEDIALOGINSTANCE ((__LONG32) TSPI_MESSAGE_BASE + 3)
#define LINE_SENDDIALOGINSTANCEDATA ((__LONG32) TSPI_MESSAGE_BASE + 4)
#define LINE_SENDMSPDATA ((__LONG32) TSPI_MESSAGE_BASE + 5)
#define LINE_QOSINFO ((__LONG32) TSPI_MESSAGE_BASE + 6)

#define LINETSPIOPTION_NONREENTRANT 0x00000001

#define TUISPIDLL_OBJECT_LINEID __MSABI_LONG(1)
#define TUISPIDLL_OBJECT_PHONEID __MSABI_LONG(2)
#define TUISPIDLL_OBJECT_PROVIDERID __MSABI_LONG(3)
#define TUISPIDLL_OBJECT_DIALOGINSTANCE __MSABI_LONG(4)

#define PRIVATEOBJECT_NONE 0x00000001
#define PRIVATEOBJECT_CALLID 0x00000002
#define PRIVATEOBJECT_LINE 0x00000003
#define PRIVATEOBJECT_CALL 0x00000004
#define PRIVATEOBJECT_PHONE 0x00000005
#define PRIVATEOBJECT_ADDRESS 0x00000006

#define LINEQOSREQUESTTYPE_SERVICELEVEL 0x00000001

#define LINEQOSSERVICELEVEL_NEEDED 0x00000001
#define LINEQOSSERVICELEVEL_IFAVAILABLE 0x00000002
#define LINEQOSSERVICELEVEL_BESTEFFORT 0x00000003

#define LINEEQOSINFO_NOQOS 0x00000001
#define LINEEQOSINFO_ADMISSIONFAILURE 0x00000002
#define LINEEQOSINFO_POLICYFAILURE 0x00000003
#define LINEEQOSINFO_GENERICERROR 0x00000004

  LONG WINAPI TSPI_lineAccept(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,LPCSTR lpsUserUserInfo,DWORD dwSize);
  LONG WINAPI TSPI_lineAddToConference(DRV_REQUESTID dwRequestID,HDRVCALL hdConfCall,HDRVCALL hdConsultCall);
  LONG WINAPI TSPI_lineAnswer(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,LPCSTR lpsUserUserInfo,DWORD dwSize);
  LONG WINAPI TSPI_lineBlindTransfer(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,LPCWSTR lpszDestAddress,DWORD dwCountryCode);
  LONG WINAPI TSPI_lineClose(HDRVLINE hdLine);
  LONG WINAPI TSPI_lineCloseCall(HDRVCALL hdCall);
  LONG WINAPI TSPI_lineCompleteCall(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,LPDWORD lpdwCompletionID,DWORD dwCompletionMode,DWORD dwMessageID);
  LONG WINAPI TSPI_lineCompleteTransfer(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,HDRVCALL hdConsultCall,HTAPICALL htConfCall,LPHDRVCALL lphdConfCall,DWORD dwTransferMode);
  LONG WINAPI TSPI_lineConditionalMediaDetection(HDRVLINE hdLine,DWORD dwMediaModes,LPLINECALLPARAMS const lpCallParams);
  LONG WINAPI TSPI_lineDevSpecific(DRV_REQUESTID dwRequestID,HDRVLINE hdLine,DWORD dwAddressID,HDRVCALL hdCall,LPVOID lpParams,DWORD dwSize);
  LONG WINAPI TSPI_lineDevSpecificFeature(DRV_REQUESTID dwRequestID,HDRVLINE hdLine,DWORD dwFeature,LPVOID lpParams,DWORD dwSize);
  LONG WINAPI TSPI_lineDial(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,LPCWSTR lpszDestAddress,DWORD dwCountryCode);
  LONG WINAPI TSPI_lineDrop(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,LPCSTR lpsUserUserInfo,DWORD dwSize);
  LONG WINAPI TSPI_lineDropOnClose(HDRVCALL hdCall);
  LONG WINAPI TSPI_lineDropNoOwner(HDRVCALL hdCall);
  LONG WINAPI TSPI_lineForward(DRV_REQUESTID dwRequestID,HDRVLINE hdLine,DWORD bAllAddresses,DWORD dwAddressID,LPLINEFORWARDLIST const lpForwardList,DWORD dwNumRingsNoAnswer,HTAPICALL htConsultCall,LPHDRVCALL lphdConsultCall,LPLINECALLPARAMS const lpCallParams);
  LONG WINAPI TSPI_lineGatherDigits(HDRVCALL hdCall,DWORD dwEndToEndID,DWORD dwDigitModes,LPWSTR lpsDigits,DWORD dwNumDigits,LPCWSTR lpszTerminationDigits,DWORD dwFirstDigitTimeout,DWORD dwInterDigitTimeout);
  LONG WINAPI TSPI_lineGenerateDigits(HDRVCALL hdCall,DWORD dwEndToEndID,DWORD dwDigitMode,LPCWSTR lpszDigits,DWORD dwDuration);
  LONG WINAPI TSPI_lineGenerateTone(HDRVCALL hdCall,DWORD dwEndToEndID,DWORD dwToneMode,DWORD dwDuration,DWORD dwNumTones,LPLINEGENERATETONE const lpTones);
  LONG WINAPI TSPI_lineGetAddressCaps(DWORD dwDeviceID,DWORD dwAddressID,DWORD dwTSPIVersion,DWORD dwExtVersion,LPLINEADDRESSCAPS lpAddressCaps);
  LONG WINAPI TSPI_lineGetAddressID(HDRVLINE hdLine,LPDWORD lpdwAddressID,DWORD dwAddressMode,LPCWSTR lpsAddress,DWORD dwSize);
  LONG WINAPI TSPI_lineGetAddressStatus(HDRVLINE hdLine,DWORD dwAddressID,LPLINEADDRESSSTATUS lpAddressStatus);
  LONG WINAPI TSPI_lineGetCallAddressID(HDRVCALL hdCall,LPDWORD lpdwAddressID);
  LONG WINAPI TSPI_lineGetCallHubTracking(HDRVLINE hdLine,LPLINECALLHUBTRACKINGINFO lpTrackingInfo);
  LONG WINAPI TSPI_lineGetCallIDs(HDRVCALL hdCall,LPDWORD lpdwAddressID,LPDWORD lpdwCallID,LPDWORD lpdwRelatedCallID);
  LONG WINAPI TSPI_lineGetCallInfo(HDRVCALL hdCall,LPLINECALLINFO lpCallInfo);
  LONG WINAPI TSPI_lineGetCallStatus(HDRVCALL hdCall,LPLINECALLSTATUS lpCallStatus);
  LONG WINAPI TSPI_lineGetDevCaps(DWORD dwDeviceID,DWORD dwTSPIVersion,DWORD dwExtVersion,LPLINEDEVCAPS lpLineDevCaps);
  LONG WINAPI TSPI_lineGetDevConfig(DWORD dwDeviceID,LPVARSTRING lpDeviceConfig,LPCWSTR lpszDeviceClass);
  LONG WINAPI TSPI_lineGetExtensionID(DWORD dwDeviceID,DWORD dwTSPIVersion,LPLINEEXTENSIONID lpExtensionID);
  LONG WINAPI TSPI_lineGetIcon(DWORD dwDeviceID,LPCWSTR lpszDeviceClass,LPHICON lphIcon);
  LONG WINAPI TSPI_lineGetID(HDRVLINE hdLine,DWORD dwAddressID,HDRVCALL hdCall,DWORD dwSelect,LPVARSTRING lpDeviceID,LPCWSTR lpszDeviceClass,HANDLE hTargetProcess);
  LONG WINAPI TSPI_lineGetLineDevStatus(HDRVLINE hdLine,LPLINEDEVSTATUS lpLineDevStatus);
  LONG WINAPI TSPI_lineGetNumAddressIDs(HDRVLINE hdLine,LPDWORD lpdwNumAddressIDs);
  LONG WINAPI TSPI_lineHold(DRV_REQUESTID dwRequestID,HDRVCALL hdCall);
  LONG WINAPI TSPI_lineMakeCall(DRV_REQUESTID dwRequestID,HDRVLINE hdLine,HTAPICALL htCall,LPHDRVCALL lphdCall,LPCWSTR lpszDestAddress,DWORD dwCountryCode,LPLINECALLPARAMS const lpCallParams);
  LONG WINAPI TSPI_lineMonitorDigits(HDRVCALL hdCall,DWORD dwDigitModes);
  LONG WINAPI TSPI_lineMonitorMedia(HDRVCALL hdCall,DWORD dwMediaModes);
  LONG WINAPI TSPI_lineMonitorTones(HDRVCALL hdCall,DWORD dwToneListID,LPLINEMONITORTONE const lpToneList,DWORD dwNumEntries);
  LONG WINAPI TSPI_lineNegotiateExtVersion(DWORD dwDeviceID,DWORD dwTSPIVersion,DWORD dwLowVersion,DWORD dwHighVersion,LPDWORD lpdwExtVersion);
  LONG WINAPI TSPI_lineNegotiateTSPIVersion(DWORD dwDeviceID,DWORD dwLowVersion,DWORD dwHighVersion,LPDWORD lpdwTSPIVersion);
  LONG WINAPI TSPI_lineOpen(DWORD dwDeviceID,HTAPILINE htLine,LPHDRVLINE lphdLine,DWORD dwTSPIVersion,LINEEVENT lpfnEventProc);
  LONG WINAPI TSPI_linePark(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,DWORD dwParkMode,LPCWSTR lpszDirAddress,LPVARSTRING lpNonDirAddress);
  LONG WINAPI TSPI_linePickup(DRV_REQUESTID dwRequestID,HDRVLINE hdLine,DWORD dwAddressID,HTAPICALL htCall,LPHDRVCALL lphdCall,LPCWSTR lpszDestAddress,LPCWSTR lpszGroupID);
  LONG WINAPI TSPI_linePrepareAddToConference(DRV_REQUESTID dwRequestID,HDRVCALL hdConfCall,HTAPICALL htConsultCall,LPHDRVCALL lphdConsultCall,LPLINECALLPARAMS const lpCallParams);
  LONG WINAPI TSPI_lineRedirect(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,LPCWSTR lpszDestAddress,DWORD dwCountryCode);
  LONG WINAPI TSPI_lineReleaseUserUserInfo(DRV_REQUESTID dwRequestID,HDRVCALL hdCall);
  LONG WINAPI TSPI_lineRemoveFromConference(DRV_REQUESTID dwRequestID,HDRVCALL hdCall);
  LONG WINAPI TSPI_lineSecureCall(DRV_REQUESTID dwRequestID,HDRVCALL hdCall);
  LONG WINAPI TSPI_lineSelectExtVersion(HDRVLINE hdLine,DWORD dwExtVersion);
  LONG WINAPI TSPI_lineSendUserUserInfo(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,LPCSTR lpsUserUserInfo,DWORD dwSize);
  LONG WINAPI TSPI_lineSetAppSpecific(HDRVCALL hdCall,DWORD dwAppSpecific);
  LONG WINAPI TSPI_lineSetCallData(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,LPVOID lpCallData,DWORD dwSize);
  LONG WINAPI TSPI_lineSetCallHubTracking(HDRVLINE hdLine,LPLINECALLHUBTRACKINGINFO lpTrackingInfo);
  LONG WINAPI TSPI_lineSetCallParams(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,DWORD dwBearerMode,DWORD dwMinRate,DWORD dwMaxRate,LPLINEDIALPARAMS const lpDialParams);
  LONG WINAPI TSPI_lineSetCallQualityOfService(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,LPVOID lpSendingFlowspec,DWORD dwSendingFlowspecSize,LPVOID lpReceivingFlowspec,DWORD dwReceivingFlowspecSize);
  LONG WINAPI TSPI_lineSetCallTreatment(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,DWORD dwTreatment);
  LONG WINAPI TSPI_lineSetCurrentLocation(DWORD dwLocation);
  LONG WINAPI TSPI_lineSetDefaultMediaDetection(HDRVLINE hdLine,DWORD dwMediaModes);
  LONG WINAPI TSPI_lineSetDevConfig(DWORD dwDeviceID,LPVOID const lpDeviceConfig,DWORD dwSize,LPCWSTR lpszDeviceClass);
  LONG WINAPI TSPI_lineSetLineDevStatus(DRV_REQUESTID dwRequestID,HDRVLINE hdLine,DWORD dwStatusToChange,DWORD fStatus);
  LONG WINAPI TSPI_lineSetMediaControl(HDRVLINE hdLine,DWORD dwAddressID,HDRVCALL hdCall,DWORD dwSelect,LPLINEMEDIACONTROLDIGIT const lpDigitList,DWORD dwDigitNumEntries,LPLINEMEDIACONTROLMEDIA const lpMediaList,DWORD dwMediaNumEntries,LPLINEMEDIACONTROLTONE const lpToneList,DWORD dwToneNumEntries,LPLINEMEDIACONTROLCALLSTATE const lpCallStateList,DWORD dwCallStateNumEntries);
  LONG WINAPI TSPI_lineSetMediaMode(HDRVCALL hdCall,DWORD dwMediaMode);
  LONG WINAPI TSPI_lineSetStatusMessages(HDRVLINE hdLine,DWORD dwLineStates,DWORD dwAddressStates);
  LONG WINAPI TSPI_lineSetTerminal(DRV_REQUESTID dwRequestID,HDRVLINE hdLine,DWORD dwAddressID,HDRVCALL hdCall,DWORD dwSelect,DWORD dwTerminalModes,DWORD dwTerminalID,DWORD bEnable);
  LONG WINAPI TSPI_lineSetupConference(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,HDRVLINE hdLine,HTAPICALL htConfCall,LPHDRVCALL lphdConfCall,HTAPICALL htConsultCall,LPHDRVCALL lphdConsultCall,DWORD dwNumParties,LPLINECALLPARAMS const lpCallParams);
  LONG WINAPI TSPI_lineSetupTransfer(DRV_REQUESTID dwRequestID,HDRVCALL hdCall,HTAPICALL htConsultCall,LPHDRVCALL lphdConsultCall,LPLINECALLPARAMS const lpCallParams);
  LONG WINAPI TSPI_lineSwapHold(DRV_REQUESTID dwRequestID,HDRVCALL hdActiveCall,HDRVCALL hdHeldCall);
  LONG WINAPI TSPI_lineUncompleteCall(DRV_REQUESTID dwRequestID,HDRVLINE hdLine,DWORD dwCompletionID);
  LONG WINAPI TSPI_lineUnhold(DRV_REQUESTID dwRequestID,HDRVCALL hdCall);
  LONG WINAPI TSPI_lineUnpark(DRV_REQUESTID dwRequestID,HDRVLINE hdLine,DWORD dwAddressID,HTAPICALL htCall,LPHDRVCALL lphdCall,LPCWSTR lpszDestAddress);
  LONG WINAPI TSPI_phoneClose(HDRVPHONE hdPhone);
  LONG WINAPI TSPI_phoneDevSpecific(DRV_REQUESTID dwRequestID,HDRVPHONE hdPhone,LPVOID lpParams,DWORD dwSize);
  LONG WINAPI TSPI_phoneGetButtonInfo(HDRVPHONE hdPhone,DWORD dwButtonLampID,LPPHONEBUTTONINFO lpButtonInfo);
  LONG WINAPI TSPI_phoneGetData(HDRVPHONE hdPhone,DWORD dwDataID,LPVOID lpData,DWORD dwSize);
  LONG WINAPI TSPI_phoneGetDevCaps(DWORD dwDeviceID,DWORD dwTSPIVersion,DWORD dwExtVersion,LPPHONECAPS lpPhoneCaps);
  LONG WINAPI TSPI_phoneGetDisplay(HDRVPHONE hdPhone,LPVARSTRING lpDisplay);
  LONG WINAPI TSPI_phoneGetExtensionID(DWORD dwDeviceID,DWORD dwTSPIVersion,LPPHONEEXTENSIONID lpExtensionID);
  LONG WINAPI TSPI_phoneGetGain(HDRVPHONE hdPhone,DWORD dwHookSwitchDev,LPDWORD lpdwGain);
  LONG WINAPI TSPI_phoneGetHookSwitch(HDRVPHONE hdPhone,LPDWORD lpdwHookSwitchDevs);
  LONG WINAPI TSPI_phoneGetIcon(DWORD dwDeviceID,LPCWSTR lpszDeviceClass,LPHICON lphIcon);
  LONG WINAPI TSPI_phoneGetID(HDRVPHONE hdPhone,LPVARSTRING lpDeviceID,LPCWSTR lpszDeviceClass,HANDLE hTargetProcess);
  LONG WINAPI TSPI_phoneGetLamp(HDRVPHONE hdPhone,DWORD dwButtonLampID,LPDWORD lpdwLampMode);
  LONG WINAPI TSPI_phoneGetRing(HDRVPHONE hdPhone,LPDWORD lpdwRingMode,LPDWORD lpdwVolume);
  LONG WINAPI TSPI_phoneGetStatus(HDRVPHONE hdPhone,LPPHONESTATUS lpPhoneStatus);
  LONG WINAPI TSPI_phoneGetVolume(HDRVPHONE hdPhone,DWORD dwHookSwitchDev,LPDWORD lpdwVolume);
  LONG WINAPI TSPI_phoneNegotiateExtVersion(DWORD dwDeviceID,DWORD dwTSPIVersion,DWORD dwLowVersion,DWORD dwHighVersion,LPDWORD lpdwExtVersion);
  LONG WINAPI TSPI_phoneNegotiateTSPIVersion(DWORD dwDeviceID,DWORD dwLowVersion,DWORD dwHighVersion,LPDWORD lpdwTSPIVersion);
  LONG WINAPI TSPI_phoneOpen(DWORD dwDeviceID,HTAPIPHONE htPhone,LPHDRVPHONE lphdPhone,DWORD dwTSPIVersion,PHONEEVENT lpfnEventProc);
  LONG WINAPI TSPI_phoneSelectExtVersion(HDRVPHONE hdPhone,DWORD dwExtVersion);
  LONG WINAPI TSPI_phoneSetButtonInfo(DRV_REQUESTID dwRequestID,HDRVPHONE hdPhone,DWORD dwButtonLampID,LPPHONEBUTTONINFO const lpButtonInfo);
  LONG WINAPI TSPI_phoneSetData(DRV_REQUESTID dwRequestID,HDRVPHONE hdPhone,DWORD dwDataID,LPVOID const lpData,DWORD dwSize);
  LONG WINAPI TSPI_phoneSetDisplay(DRV_REQUESTID dwRequestID,HDRVPHONE hdPhone,DWORD dwRow,DWORD dwColumn,LPCWSTR lpsDisplay,DWORD dwSize);
  LONG WINAPI TSPI_phoneSetGain(DRV_REQUESTID dwRequestID,HDRVPHONE hdPhone,DWORD dwHookSwitchDev,DWORD dwGain);
  LONG WINAPI TSPI_phoneSetHookSwitch(DRV_REQUESTID dwRequestID,HDRVPHONE hdPhone,DWORD dwHookSwitchDevs,DWORD dwHookSwitchMode);
  LONG WINAPI TSPI_phoneSetLamp(DRV_REQUESTID dwRequestID,HDRVPHONE hdPhone,DWORD dwButtonLampID,DWORD dwLampMode);
  LONG WINAPI TSPI_phoneSetRing(DRV_REQUESTID dwRequestID,HDRVPHONE hdPhone,DWORD dwRingMode,DWORD dwVolume);
  LONG WINAPI TSPI_phoneSetStatusMessages(HDRVPHONE hdPhone,DWORD dwPhoneStates,DWORD dwButtonModes,DWORD dwButtonStates);
  LONG WINAPI TSPI_phoneSetVolume(DRV_REQUESTID dwRequestID,HDRVPHONE hdPhone,DWORD dwHookSwitchDev,DWORD dwVolume);
  LONG WINAPI TSPI_providerConfig(HWND hwndOwner,DWORD dwPermanentProviderID);
  LONG WINAPI TSPI_providerCreateLineDevice(DWORD_PTR dwTempID,DWORD dwDeviceID);
  LONG WINAPI TSPI_providerCreatePhoneDevice(DWORD_PTR dwTempID,DWORD dwDeviceID);
  LONG WINAPI TSPI_providerEnumDevices(DWORD dwPermanentProviderID,LPDWORD lpdwNumLines,LPDWORD lpdwNumPhones,HPROVIDER hProvider,LINEEVENT lpfnLineCreateProc,PHONEEVENT lpfnPhoneCreateProc);
  LONG WINAPI TSPI_providerFreeDialogInstance(HDRVDIALOGINSTANCE hdDlgInst);
  LONG WINAPI TSPI_providerGenericDialogData(DWORD_PTR dwObjectID,DWORD dwObjectType,LPVOID lpParams,DWORD dwSize);
  LONG WINAPI TSPI_providerInit(DWORD dwTSPIVersion,DWORD dwPermanentProviderID,DWORD dwLineDeviceIDBase,DWORD dwPhoneDeviceIDBase,DWORD_PTR dwNumLines,DWORD_PTR dwNumPhones,ASYNC_COMPLETION lpfnCompletionProc,LPDWORD lpdwTSPIOptions);
  LONG WINAPI TSPI_providerInstall(HWND hwndOwner,DWORD dwPermanentProviderID);
  LONG WINAPI TSPI_providerRemove(HWND hwndOwner,DWORD dwPermanentProviderID);
  LONG WINAPI TSPI_providerShutdown(DWORD dwTSPIVersion,DWORD dwPermanentProviderID);
  LONG WINAPI TSPI_providerUIIdentify(LPWSTR lpszUIDLLName);
  LONG WINAPI TSPI_lineMSPIdentify(DWORD dwDeviceID,GUID *pCLSID);
  LONG WINAPI TSPI_lineCreateMSPInstance(HDRVLINE hdLine,DWORD dwAddressID,HTAPIMSPLINE htMSPLine,LPHDRVMSPLINE lphdMSPLine);
  LONG WINAPI TSPI_lineCloseMSPInstance(HDRVMSPLINE hdMSPLine);
  LONG WINAPI TSPI_lineReceiveMSPData(HDRVLINE hdLine,HDRVCALL hdCall,HDRVMSPLINE hdMSPLine,LPVOID pBuffer,DWORD dwSize);
  LONG WINAPI TUISPI_lineConfigDialog(TUISPIDLLCALLBACK lpfnUIDLLCallback,DWORD dwDeviceID,HWND hwndOwner,LPCWSTR lpszDeviceClass);
  LONG WINAPI TUISPI_lineConfigDialogEdit(TUISPIDLLCALLBACK lpfnUIDLLCallback,DWORD dwDeviceID,HWND hwndOwner,LPCWSTR lpszDeviceClass,LPVOID const lpDeviceConfigIn,DWORD dwSize,LPVARSTRING lpDeviceConfigOut);
  LONG WINAPI TUISPI_phoneConfigDialog(TUISPIDLLCALLBACK lpfnUIDLLCallback,DWORD dwDeviceID,HWND hwndOwner,LPCWSTR lpszDeviceClass);
  LONG WINAPI TUISPI_providerConfig(TUISPIDLLCALLBACK lpfnUIDLLCallback,HWND hwndOwner,DWORD dwPermanentProviderID);
  LONG WINAPI TUISPI_providerGenericDialog(TUISPIDLLCALLBACK lpfnUIDLLCallback,HTAPIDIALOGINSTANCE htDlgInst,LPVOID lpParams,DWORD dwSize,HANDLE hEvent);
  LONG WINAPI TUISPI_providerGenericDialogData(HTAPIDIALOGINSTANCE htDlgInst,LPVOID lpParams,DWORD dwSize);
  LONG WINAPI TUISPI_providerInstall(TUISPIDLLCALLBACK lpfnUIDLLCallback,HWND hwndOwner,DWORD dwPermanentProviderID);
  LONG WINAPI TUISPI_providerRemove(TUISPIDLLCALLBACK lpfnUIDLLCallback,HWND hwndOwner,DWORD dwPermanentProviderID);

#ifdef __cplusplus
}
#endif
#endif
