/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _STICOM_
#define _STICOM_

#include <pshpack8.h>

#define STI_UNICODE 1

#ifndef _NO_COM
#include <objbase.h>
#endif

#include <stireg.h>
#include <stierr.h>

#define DLLEXP __declspec(dllexport)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _NO_COM
  DEFINE_GUID(CLSID_Sti,0xB323F8E0,0x2E68,0x11D0,0x90,0xEA,0x00,0xAA,0x00,0x60,0xF8,0x6C);
  DEFINE_GUID(IID_IStillImageW,0x641BD880,0x2DC8,0x11D0,0x90,0xEA,0x00,0xAA,0x00,0x60,0xF8,0x6C);
  DEFINE_GUID(IID_IStillImageA,0xA7B1F740,0x1D7F,0x11D1,0xAC,0xA9,0x00,0xA0,0x24,0x38,0xAD,0x48);
  DEFINE_GUID(IID_IStiDevice,0x6CFA5A80,0x2DC8,0x11D0,0x90,0xEA,0x00,0xAA,0x00,0x60,0xF8,0x6C);
  DEFINE_GUID(GUID_DeviceArrivedLaunch,0x740d9ee6,0x70f1,0x11d1,0xad,0x10,0x0,0xa0,0x24,0x38,0xad,0x48);
  DEFINE_GUID(GUID_ScanImage,0xa6c5a715,0x8c6e,0x11d2,0x97,0x7a,0x0,0x0,0xf8,0x7a,0x92,0x6f);
  DEFINE_GUID(GUID_ScanPrintImage,0xb441f425,0x8c6e,0x11d2,0x97,0x7a,0x0,0x0,0xf8,0x7a,0x92,0x6f);
  DEFINE_GUID(GUID_ScanFaxImage,0xc00eb793,0x8c6e,0x11d2,0x97,0x7a,0x0,0x0,0xf8,0x7a,0x92,0x6f);
  DEFINE_GUID(GUID_STIUserDefined1,0xc00eb795,0x8c6e,0x11d2,0x97,0x7a,0x0,0x0,0xf8,0x7a,0x92,0x6f);
  DEFINE_GUID(GUID_STIUserDefined2,0xc77ae9c5,0x8c6e,0x11d2,0x97,0x7a,0x0,0x0,0xf8,0x7a,0x92,0x6f);
  DEFINE_GUID(GUID_STIUserDefined3,0xc77ae9c6,0x8c6e,0x11d2,0x97,0x7a,0x0,0x0,0xf8,0x7a,0x92,0x6f);
#endif

#define STI_VERSION_FLAG_MASK 0xff000000
#define STI_VERSION_FLAG_UNICODE 0x01000000

#define GET_STIVER_MAJOR(dwVersion) (HIWORD(dwVersion) & ~STI_VERSION_FLAG_MASK)
#define GET_STIVER_MINOR(dwVersion) LOWORD(dwVersion)

#define STI_VERSION_REAL 0x00000002
#define STI_VERSION_MIN_ALLOWED 0x00000002

#if defined(UNICODE)
#define STI_VERSION (STI_VERSION_REAL | STI_VERSION_FLAG_UNICODE)
#else
#define STI_VERSION (STI_VERSION_REAL)
#endif

#define STI_MAX_INTERNAL_NAME_LENGTH 128

  typedef enum _STI_DEVICE_MJ_TYPE {
    StiDeviceTypeDefault = 0,StiDeviceTypeScanner = 1,StiDeviceTypeDigitalCamera = 2,StiDeviceTypeStreamingVideo = 3
  } STI_DEVICE_MJ_TYPE;

  typedef DWORD STI_DEVICE_TYPE;

#define GET_STIDEVICE_TYPE(dwDevType) HIWORD(dwDevType)
#define GET_STIDEVICE_SUBTYPE(dwDevType) LOWORD(dwDevType)

  typedef struct _STI_DEV_CAPS {
    DWORD dwGeneric;
  } STI_DEV_CAPS,*PSTI_DEV_CAPS;

#define GET_STIDCOMMON_CAPS(dwGenericCaps) LOWORD(dwGenericCaps)
#define GET_STIVENDOR_CAPS(dwGenericCaps) HIWORD(dwGenericCaps)

#define STI_GENCAP_COMMON_MASK (DWORD)0x00ff
#define STI_GENCAP_NOTIFICATIONS 0x00000001
#define STI_GENCAP_POLLING_NEEDED 0x00000002
#define STI_GENCAP_GENERATE_ARRIVALEVENT 0x00000004
#define STI_GENCAP_AUTO_PORTSELECT 0x00000008
#define STI_GENCAP_WIA 0x00000010
#define STI_GENCAP_SUBSET 0x00000020
#define STI_HW_CONFIG_UNKNOWN 0x0001
#define STI_HW_CONFIG_SCSI 0x0002
#define STI_HW_CONFIG_USB 0x0004
#define STI_HW_CONFIG_SERIAL 0x0008
#define STI_HW_CONFIG_PARALLEL 0x0010

  typedef struct _STI_DEVICE_INFORMATIONW {
    DWORD dwSize;
    STI_DEVICE_TYPE DeviceType;
    WCHAR szDeviceInternalName[STI_MAX_INTERNAL_NAME_LENGTH];
    STI_DEV_CAPS DeviceCapabilities;
    DWORD dwHardwareConfiguration;
    LPWSTR pszVendorDescription;
    LPWSTR pszDeviceDescription;
    LPWSTR pszPortName;
    LPWSTR pszPropProvider;
    LPWSTR pszLocalName;
  } STI_DEVICE_INFORMATIONW,*PSTI_DEVICE_INFORMATIONW;

  typedef struct _STI_DEVICE_INFORMATIONA {
    DWORD dwSize;
    STI_DEVICE_TYPE DeviceType;
    CHAR szDeviceInternalName[STI_MAX_INTERNAL_NAME_LENGTH];
    STI_DEV_CAPS DeviceCapabilities;
    DWORD dwHardwareConfiguration;
    LPCSTR pszVendorDescription;
    LPCSTR pszDeviceDescription;
    LPCSTR pszPortName;
    LPCSTR pszPropProvider;
    LPCSTR pszLocalName;
  } STI_DEVICE_INFORMATIONA,*PSTI_DEVICE_INFORMATIONA;

#if defined(UNICODE) || defined(STI_UNICODE)
  typedef STI_DEVICE_INFORMATIONW STI_DEVICE_INFORMATION;
  typedef PSTI_DEVICE_INFORMATIONW PSTI_DEVICE_INFORMATION;
#else
  typedef STI_DEVICE_INFORMATIONA STI_DEVICE_INFORMATION;
  typedef PSTI_DEVICE_INFORMATIONA PSTI_DEVICE_INFORMATION;
#endif

  typedef struct _STI_WIA_DEVICE_INFORMATIONW {
    DWORD dwSize;
    STI_DEVICE_TYPE DeviceType;
    WCHAR szDeviceInternalName[STI_MAX_INTERNAL_NAME_LENGTH];
    STI_DEV_CAPS DeviceCapabilities;
    DWORD dwHardwareConfiguration;
    LPWSTR pszVendorDescription;
    LPWSTR pszDeviceDescription;
    LPWSTR pszPortName;
    LPWSTR pszPropProvider;
    LPWSTR pszLocalName;
    LPWSTR pszUiDll;
    LPWSTR pszServer;
  } STI_WIA_DEVICE_INFORMATIONW,*PSTI_WIA_DEVICE_INFORMATIONW;

  typedef struct _STI_WIA_DEVICE_INFORMATIONA {
    DWORD dwSize;
    STI_DEVICE_TYPE DeviceType;
    CHAR szDeviceInternalName[STI_MAX_INTERNAL_NAME_LENGTH];
    STI_DEV_CAPS DeviceCapabilities;
    DWORD dwHardwareConfiguration;
    LPCSTR pszVendorDescription;
    LPCSTR pszDeviceDescription;
    LPCSTR pszPortName;
    LPCSTR pszPropProvider;
    LPCSTR pszLocalName;
    LPCSTR pszUiDll;
    LPCSTR pszServer;
  } STI_WIA_DEVICE_INFORMATIONA,*PSTI_WIA_DEVICE_INFORMATIONA;

#if defined(UNICODE) || defined(STI_UNICODE)
  typedef STI_WIA_DEVICE_INFORMATIONW STI_WIA_DEVICE_INFORMATION;
  typedef PSTI_WIA_DEVICE_INFORMATIONW PSTI_WIA_DEVICE_INFORMATION;
#else
  typedef STI_WIA_DEVICE_INFORMATIONA STI_WIA_DEVICE_INFORMATION;
  typedef PSTI_WIA_DEVICE_INFORMATIONA PSTI_WIA_DEVICE_INFORMATION;
#endif

#define STI_DEVSTATUS_ONLINE_STATE 0x0001
#define STI_DEVSTATUS_EVENTS_STATE 0x0002

#define STI_ONLINESTATE_OPERATIONAL 0x00000001
#define STI_ONLINESTATE_PENDING 0x00000002
#define STI_ONLINESTATE_ERROR 0x00000004
#define STI_ONLINESTATE_PAUSED 0x00000008
#define STI_ONLINESTATE_PAPER_JAM 0x00000010
#define STI_ONLINESTATE_PAPER_PROBLEM 0x00000020
#define STI_ONLINESTATE_OFFLINE 0x00000040
#define STI_ONLINESTATE_IO_ACTIVE 0x00000080
#define STI_ONLINESTATE_BUSY 0x00000100
#define STI_ONLINESTATE_TRANSFERRING 0x00000200
#define STI_ONLINESTATE_INITIALIZING 0x00000400
#define STI_ONLINESTATE_WARMING_UP 0x00000800
#define STI_ONLINESTATE_USER_INTERVENTION 0x00001000
#define STI_ONLINESTATE_POWER_SAVE 0x00002000

#define STI_EVENTHANDLING_ENABLED 0x00000001
#define STI_EVENTHANDLING_POLLING 0x00000002
#define STI_EVENTHANDLING_PENDING 0x00000004

  typedef struct _STI_DEVICE_STATUS {
    DWORD dwSize;
    DWORD StatusMask;
    DWORD dwOnlineState;
    DWORD dwHardwareStatusCode;
    DWORD dwEventHandlingState;
    DWORD dwPollingInterval;
  } STI_DEVICE_STATUS,*PSTI_DEVICE_STATUS;

#define STI_DIAGCODE_HWPRESENCE 0x00000001

  typedef struct _ERROR_INFOW {
    DWORD dwSize;
    DWORD dwGenericError;
    DWORD dwVendorError;
    WCHAR szExtendedErrorText[255];
  } STI_ERROR_INFOW,*PSTI_ERROR_INFOW;

  typedef struct _ERROR_INFOA {
    DWORD dwSize;
    DWORD dwGenericError;
    DWORD dwVendorError;
    CHAR szExtendedErrorText[255];
  } STI_ERROR_INFOA,*PSTI_ERROR_INFOA;

#if defined(UNICODE) || defined(STI_UNICODE)
  typedef STI_ERROR_INFOW STI_ERROR_INFO;
#else
  typedef STI_ERROR_INFOA STI_ERROR_INFO;
#endif

  typedef STI_ERROR_INFO *PSTI_ERROR_INFO;

  typedef struct _STI_DIAG {
    DWORD dwSize;
    DWORD dwBasicDiagCode;
    DWORD dwVendorDiagCode;
    DWORD dwStatusMask;
    STI_ERROR_INFO sErrorInfo;
  } STI_DIAG,*LPSTI_DIAG;

  typedef STI_DIAG DIAG;
  typedef LPSTI_DIAG LPDIAG;

#define STI_TRACE_INFORMATION 0x00000001
#define STI_TRACE_WARNING 0x00000002
#define STI_TRACE_ERROR 0x00000004

#define STI_SUBSCRIBE_FLAG_WINDOW 0x0001

#define STI_SUBSCRIBE_FLAG_EVENT 0x0002

  typedef struct _STISUBSCRIBE {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwFilter;
    HWND hWndNotify;
    HANDLE hEvent;
    UINT uiNotificationMessage;
  } STISUBSCRIBE,*LPSTISUBSCRIBE;

#define MAX_NOTIFICATION_DATA 64

  typedef struct _STINOTIFY {
    DWORD dwSize;
    GUID guidNotificationCode;
    BYTE abNotificationData[MAX_NOTIFICATION_DATA];
  } STINOTIFY,*LPSTINOTIFY;

#define STI_ADD_DEVICE_BROADCAST_ACTION "Arrival"
#define STI_REMOVE_DEVICE_BROADCAST_ACTION "Removal"

#define STI_ADD_DEVICE_BROADCAST_STRING "STI\\" STI_ADD_DEVICE_BROADCAST_ACTION "\\%s"
#define STI_REMOVE_DEVICE_BROADCAST_STRING "STI\\" STI_REMOVE_DEVICE_BROADCAST_ACTION "\\%s"

#define STI_DEVICE_CREATE_STATUS 0x00000001
#define STI_DEVICE_CREATE_DATA 0x00000002
#define STI_DEVICE_CREATE_BOTH 0x00000003
#define STI_DEVICE_CREATE_MASK 0x0000FFFF

#define STIEDFL_ALLDEVICES 0x00000000
#define STIEDFL_ATTACHEDONLY 0x00000001

  typedef DWORD STI_RAW_CONTROL_CODE;

#define STI_RAW_RESERVED 0x1000

  struct IStillImageW;
  struct IStillImageA;
  struct IStiDevice;

  STDMETHODIMP StiCreateInstanceW(HINSTANCE hinst,DWORD dwVer,struct IStillImageW **ppSti,LPUNKNOWN punkOuter);
  STDMETHODIMP StiCreateInstanceA(HINSTANCE hinst,DWORD dwVer,struct IStillImageA **ppSti,LPUNKNOWN punkOuter);

#if defined(UNICODE) || defined(STI_UNICODE)
#define IID_IStillImage IID_IStillImageW
#define IStillImage IStillImageW
#define StiCreateInstance StiCreateInstanceW
#else
#define IID_IStillImage IID_IStillImageA
#define IStillImage IStillImageA
#define StiCreateInstance StiCreateInstanceA
#endif

  typedef struct IStiDevice *LPSTILLIMAGEDEVICE;
  typedef struct IStillImage *PSTI;
  typedef struct IStiDevice *PSTIDEVICE;
  typedef struct IStillImageA *PSTIA;
  typedef struct IStiDeviceA *PSTIDEVICEA;
  typedef struct IStillImageW *PSTIW;
  typedef struct IStiDeviceW *PSTIDEVICEW;

#undef INTERFACE
#define INTERFACE IStillImageW
  DECLARE_INTERFACE_(IStillImageW,IUnknown) {
    STDMETHOD(QueryInterface) (THIS_ REFIID riid,LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS) PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
    STDMETHOD(Initialize) (THIS_ HINSTANCE hinst,DWORD dwVersion) PURE;
    STDMETHOD(GetDeviceList)(THIS_ DWORD dwType,DWORD dwFlags,DWORD *pdwItemsReturned,LPVOID *ppBuffer) PURE;
    STDMETHOD(GetDeviceInfo)(THIS_ LPWSTR pwszDeviceName,LPVOID *ppBuffer) PURE;
    STDMETHOD(CreateDevice) (THIS_ LPWSTR pwszDeviceName,DWORD dwMode,PSTIDEVICE *pDevice,LPUNKNOWN punkOuter) PURE;
    STDMETHOD(GetDeviceValue)(THIS_ LPWSTR pwszDeviceName,LPWSTR pValueName,LPDWORD pType,LPBYTE pData,LPDWORD cbData);
    STDMETHOD(SetDeviceValue)(THIS_ LPWSTR pwszDeviceName,LPWSTR pValueName,DWORD Type,LPBYTE pData,DWORD cbData);
    STDMETHOD(GetSTILaunchInformation)(THIS_ LPWSTR pwszDeviceName,DWORD *pdwEventCode,LPWSTR pwszEventName) PURE;
    STDMETHOD(RegisterLaunchApplication)(THIS_ LPWSTR pwszAppName,LPWSTR pwszCommandLine) PURE;
    STDMETHOD(UnregisterLaunchApplication)(THIS_ LPWSTR pwszAppName) PURE;
    STDMETHOD(EnableHwNotifications)(THIS_ LPCWSTR pwszDeviceName,WINBOOL bNewState) PURE;
    STDMETHOD(GetHwNotificationState)(THIS_ LPCWSTR pwszDeviceName,WINBOOL *pbCurrentState) PURE;
    STDMETHOD(RefreshDeviceBus)(THIS_ LPCWSTR pwszDeviceName) PURE;
    STDMETHOD(LaunchApplicationForDevice)(THIS_ LPWSTR pwszDeviceName,LPWSTR pwszAppName,LPSTINOTIFY pStiNotify);
    STDMETHOD(SetupDeviceParameters)(THIS_ PSTI_DEVICE_INFORMATIONW);
    STDMETHOD(WriteToErrorLog)(THIS_ DWORD dwMessageType,LPCWSTR pszMessage) PURE;
#ifdef NOT_IMPLEMENTED
    STIMETHOD(RegisterDeviceNotification(THIS_ LPWSTR pwszAppName,LPSUBSCRIBE lpSubscribe) PURE;
    STIMETHOD(UnregisterDeviceNotification(THIS_) PURE;
#endif
  };

  typedef struct IStillImageW *LPSTILLIMAGEW;

#undef INTERFACE
#define INTERFACE IStillImageA
  DECLARE_INTERFACE_(IStillImageA,IUnknown) {
    STDMETHOD(QueryInterface) (THIS_ REFIID riid,LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS) PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
    STDMETHOD(Initialize) (THIS_ HINSTANCE hinst,DWORD dwVersion) PURE;
    STDMETHOD(GetDeviceList)(THIS_ DWORD dwType,DWORD dwFlags,DWORD *pdwItemsReturned,LPVOID *ppBuffer) PURE;
    STDMETHOD(GetDeviceInfo)(THIS_ LPCSTR pwszDeviceName,LPVOID *ppBuffer) PURE;
    STDMETHOD(CreateDevice) (THIS_ LPCSTR pwszDeviceName,DWORD dwMode,PSTIDEVICE *pDevice,LPUNKNOWN punkOuter) PURE;
    STDMETHOD(GetDeviceValue)(THIS_ LPCSTR pwszDeviceName,LPCSTR pValueName,LPDWORD pType,LPBYTE pData,LPDWORD cbData);
    STDMETHOD(SetDeviceValue)(THIS_ LPCSTR pwszDeviceName,LPCSTR pValueName,DWORD Type,LPBYTE pData,DWORD cbData);
    STDMETHOD(GetSTILaunchInformation)(THIS_ LPSTR pwszDeviceName,DWORD *pdwEventCode,LPSTR pwszEventName) PURE;
    STDMETHOD(RegisterLaunchApplication)(THIS_ LPCSTR pwszAppName,LPCSTR pwszCommandLine) PURE;
    STDMETHOD(UnregisterLaunchApplication)(THIS_ LPCSTR pwszAppName) PURE;
    STDMETHOD(EnableHwNotifications)(THIS_ LPCSTR pwszDeviceName,WINBOOL bNewState) PURE;
    STDMETHOD(GetHwNotificationState)(THIS_ LPCSTR pwszDeviceName,WINBOOL *pbCurrentState) PURE;
    STDMETHOD(RefreshDeviceBus)(THIS_ LPCSTR pwszDeviceName) PURE;
    STDMETHOD(LaunchApplicationForDevice)(THIS_ LPCSTR pwszDeviceName,LPCSTR pwszAppName,LPSTINOTIFY pStiNotify);
    STDMETHOD(SetupDeviceParameters)(THIS_ PSTI_DEVICE_INFORMATIONA);
    STDMETHOD(WriteToErrorLog)(THIS_ DWORD dwMessageType,LPCSTR pszMessage) PURE;
#ifdef NOT_IMPLEMENTED
    STIMETHOD(RegisterDeviceNotification(THIS_ LPWSTR pwszAppName,LPSUBSCRIBE lpSubscribe) PURE;
    STIMETHOD(UnregisterDeviceNotification(THIS_) PURE;
#endif
  };

  typedef struct IStillImageA *LPSTILLIMAGEA;

#if defined(UNICODE) || defined(STI_UNICODE)
#define IStillImageVtbl IStillImageWVtbl
#else
#define IStillImageVtbl IStillImageAVtbl
#endif

  typedef struct IStillImage *LPSTILLIMAGE;

#if !defined(__cplusplus) || defined(CINTERFACE)
#define IStillImage_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IStillImage_AddRef(p) (p)->lpVtbl->AddRef(p)
#define IStillImage_Release(p) (p)->lpVtbl->Release(p)
#define IStillImage_Initialize(p,a,b) (p)->lpVtbl->Initialize(p,a,b)
#define IStillImage_GetDeviceList(p,a,b,c,d) (p)->lpVtbl->GetDeviceList(p,a,b,c,d)
#define IStillImage_GetDeviceInfo(p,a,b) (p)->lpVtbl->GetDeviceInfo(p,a,b)
#define IStillImage_CreateDevice(p,a,b,c,d) (p)->lpVtbl->CreateDevice(p,a,b,c,d)
#define IStillImage_GetDeviceValue(p,a,b,c,d,e) (p)->lpVtbl->GetDeviceValue(p,a,b,c,d,e)
#define IStillImage_SetDeviceValue(p,a,b,c,d,e) (p)->lpVtbl->SetDeviceValue(p,a,b,c,d,e)
#define IStillImage_GetSTILaunchInformation(p,a,b,c) (p)->lpVtbl->GetSTILaunchInformation(p,a,b,c)
#define IStillImage_RegisterLaunchApplication(p,a,b) (p)->lpVtbl->RegisterLaunchApplication(p,a,b)
#define IStillImage_UnregisterLaunchApplication(p,a) (p)->lpVtbl->UnregisterLaunchApplication(p,a)
#define IStillImage_EnableHwNotifications(p,a,b) (p)->lpVtbl->EnableHwNotifications(p,a,b)
#define IStillImage_GetHwNotificationState(p,a,b) (p)->lpVtbl->GetHwNotificationState(p,a,b)
#define IStillImage_RefreshDeviceBus(p,a) (p)->lpVtbl->RefreshDeviceBus(p,a)
#endif

#undef INTERFACE
#define INTERFACE IStiDevice
  DECLARE_INTERFACE_(IStiDevice,IUnknown) {
    STDMETHOD(QueryInterface) (THIS_ REFIID riid,LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS) PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
    STDMETHOD(Initialize) (THIS_ HINSTANCE hinst,LPCWSTR pwszDeviceName,DWORD dwVersion,DWORD dwMode) PURE;
    STDMETHOD(GetCapabilities) (THIS_ PSTI_DEV_CAPS pDevCaps) PURE;
    STDMETHOD(GetStatus) (THIS_ PSTI_DEVICE_STATUS pDevStatus) PURE;
    STDMETHOD(DeviceReset)(THIS) PURE;
    STDMETHOD(Diagnostic)(THIS_ LPSTI_DIAG pBuffer) PURE;
    STDMETHOD(Escape)(THIS_ STI_RAW_CONTROL_CODE EscapeFunction,LPVOID lpInData,DWORD cbInDataSize,LPVOID pOutData,DWORD dwOutDataSize,LPDWORD pdwActualData) PURE;
    STDMETHOD(GetLastError) (THIS_ LPDWORD pdwLastDeviceError) PURE;
    STDMETHOD(LockDevice) (THIS_ DWORD dwTimeOut) PURE;
    STDMETHOD(UnLockDevice) (THIS) PURE;
    STDMETHOD(RawReadData)(THIS_ LPVOID lpBuffer,LPDWORD lpdwNumberOfBytes,LPOVERLAPPED lpOverlapped) PURE;
    STDMETHOD(RawWriteData)(THIS_ LPVOID lpBuffer,DWORD nNumberOfBytes,LPOVERLAPPED lpOverlapped) PURE;
    STDMETHOD(RawReadCommand)(THIS_ LPVOID lpBuffer,LPDWORD lpdwNumberOfBytes,LPOVERLAPPED lpOverlapped) PURE;
    STDMETHOD(RawWriteCommand)(THIS_ LPVOID lpBuffer,DWORD nNumberOfBytes,LPOVERLAPPED lpOverlapped) PURE;
    STDMETHOD(Subscribe)(THIS_ LPSTISUBSCRIBE lpSubsribe) PURE;
    STDMETHOD(GetLastNotificationData)(THIS_ LPSTINOTIFY lpNotify) PURE;
    STDMETHOD(UnSubscribe)(THIS) PURE;
    STDMETHOD(GetLastErrorInfo) (THIS_ STI_ERROR_INFO *pLastErrorInfo) PURE;
  };

#if !defined(__cplusplus) || defined(CINTERFACE)
#define IStiDevice_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IStiDevice_AddRef(p) (p)->lpVtbl->AddRef(p)
#define IStiDevice_Release(p) (p)->lpVtbl->Release(p)
#define IStiDevice_Initialize(p,a,b,c,d) (p)->lpVtbl->Initialize(p,a,b,c,d)
#define IStiDevice_GetCapabilities(p,a) (p)->lpVtbl->GetCapabilities(p,a)
#define IStiDevice_GetStatus(p,a) (p)->lpVtbl->GetStatus(p,a)
#define IStiDevice_DeviceReset(p) (p)->lpVtbl->DeviceReset(p)
#define IStiDevice_LockDevice(p,a) (p)->lpVtbl->LockDevice(p,a)
#define IStiDevice_UnLockDevice(p) (p)->lpVtbl->UnLockDevice(p)
#define IStiDevice_Diagnostic(p,a) (p)->lpVtbl->Diagnostic(p,a)
#define IStiDevice_Escape(p,a,b,c,d,e,f) (p)->lpVtbl->Escape(p,a,b,c,d,e,f)
#define IStiDevice_GetLastError(p,a) (p)->lpVtbl->GetLastError(p,a)
#define IStiDevice_RawReadData(p,a,b,c) (p)->lpVtbl->RawReadData(p,a,b,c)
#define IStiDevice_RawWriteData(p,a,b,c) (p)->lpVtbl->RawWriteData(p,a,b,c)
#define IStiDevice_RawReadCommand(p,a,b,c) (p)->lpVtbl->RawReadCommand(p,a,b,c)
#define IStiDevice_RawWriteCommand(p,a,b,c) (p)->lpVtbl->RawWriteCommand(p,a,b,c)
#define IStiDevice_Subscribe(p,a) (p)->lpVtbl->Subscribe(p,a)
#define IStiDevice_GetNotificationData(p,a) (p)->lpVtbl->GetNotificationData(p,a)
#define IStiDevice_UnSubscribe(p) (p)->lpVtbl->UnSubscribe(p)
#define IStiDevice_GetLastErrorInfo(p,a) (p)->lpVtbl->GetLastErrorInfo(p,a)
#endif

#ifdef __cplusplus
};
#endif

#include <poppack.h>
#endif
