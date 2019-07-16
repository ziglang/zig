/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_BLUETOOTHAPIS
#define _INC_BLUETOOTHAPIS

#include <_mingw.h>
#include <bthdef.h>
#include <bthsdpdef.h>

#define BLUETOOTH_MAX_NAME_SIZE 248

#ifdef __cplusplus
extern "C" {
#endif

typedef LPVOID HBLUETOOTH_DEVICE_FIND;
typedef LPVOID HBLUETOOTH_RADIO_FIND;
typedef LPVOID HBLUETOOTH_AUTHENTICATION_REGISTRATION;
typedef LPVOID HBLUETOOTH_CONTAINER_ELEMENT;

typedef struct _BLUETOOTH_ADDRESS {
  __C89_NAMELESS union {
    BTH_ADDR ullLong;
    BYTE     rgBytes[6];
  };
} BLUETOOTH_ADDRESS;

typedef struct _BLUETOOTH_COD_PAIRS {
  ULONG   ulCODMask;
  LPCWSTR pcszDescription;
} BLUETOOTH_COD_PAIRS;

typedef struct _BLUETOOTH_DEVICE_INFO {
  DWORD             dwSize;
  BLUETOOTH_ADDRESS Address;
  ULONG             ulClassofDevice;
  WINBOOL           fConnected;
  WINBOOL           fRemembered;
  WINBOOL           fAuthenticated;
  SYSTEMTIME        stLastSeen;
  SYSTEMTIME        stLastUsed;
  WCHAR             szName[BLUETOOTH_MAX_NAME_SIZE];
} BLUETOOTH_DEVICE_INFO, *PBLUETOOTH_DEVICE_INFO;

typedef struct _BLUETOOTH_DEVICE_SEARCH_PARAMS {
  DWORD     dwSize;
  WINBOOL   fReturnAuthenticated;
  WINBOOL   fReturnRemembered;
  WINBOOL   fReturnUnknown;
  WINBOOL   fReturnConnected;
  WINBOOL   fIssueInquiry;
  UCHAR     cTimeoutMultiplier;
  HANDLE    hRadio;
} BLUETOOTH_DEVICE_SEARCH_PARAMS;

typedef struct _BLUETOOTH_FIND_RADIO_PARAMS {
  DWORD dwSize;
} BLUETOOTH_FIND_RADIO_PARAMS;

typedef struct _BLUETOOTH_RADIO_INFO {
  DWORD             dwSize;
  BLUETOOTH_ADDRESS address;
  WCHAR             szName[BLUETOOTH_MAX_NAME_SIZE];
  ULONG             ulClassofDevice;
  USHORT            lmpSubversion;
  USHORT            manufacturer;
} BLUETOOTH_RADIO_INFO, *PBLUETOOTH_RADIO_INFO;

typedef enum _BLUETOOTH_AUTHENTICATION_METHOD {
  BLUETOOTH_AUTHENTICATION_METHOD_LEGACY                 = 0x1,
  BLUETOOTH_AUTHENTICATION_METHOD_OOB,
  BLUETOOTH_AUTHENTICATION_METHOD_NUMERIC_COMPARISON,
  BLUETOOTH_AUTHENTICATION_METHOD_PASSKEY_NOTIFICATION,
  BLUETOOTH_AUTHENTICATION_METHOD_PASSKEY
} BLUETOOTH_AUTHENTICATION_METHOD;

typedef enum _BLUETOOTH_IO_CAPABILITY {
  BLUETOOTH_IO_CAPABILITY_DISPLAYONLY       = 0x00,
  BLUETOOTH_IO_CAPABILITY_DISPLAYYESNO      = 0x01,
  BLUETOOTH_IO_CAPABILITY_KEYBOARDONLY      = 0x02,
  BLUETOOTH_IO_CAPABILITY_NOINPUTNOOUTPUT   = 0x03,
  BLUETOOTH_IO_CAPABILITY_UNDEFINED         = 0xff
} BLUETOOTH_IO_CAPABILITY;

typedef enum _BLUETOOTH_AUTHENTICATION_REQUIREMENTS {
  MITMProtectionNotRequired                 = 0x00,
  MITMProtectionRequired                    = 0x01,
  MITMProtectionNotRequiredBonding          = 0x02,
  MITMProtectionRequiredBonding             = 0x03,
  MITMProtectionNotRequiredGeneralBonding   = 0x04,
  MITMProtectionRequiredGeneralBonding      = 0x05,
  MITMProtectionNotDefined                  = 0xff
} BLUETOOTH_AUTHENTICATION_REQUIREMENTS;

typedef struct _BLUETOOTH_AUTHENTICATION_CALLBACK_PARAMS {
  BLUETOOTH_DEVICE_INFO                 deviceInfo;
  BLUETOOTH_AUTHENTICATION_METHOD       authenticationMethod;
  BLUETOOTH_IO_CAPABILITY               ioCapability;
  BLUETOOTH_AUTHENTICATION_REQUIREMENTS authenticationRequirements;
  __C89_NAMELESS union {
    ULONG Numeric_Value;
    ULONG Passkey;
  } ;
} BLUETOOTH_AUTHENTICATION_CALLBACK_PARAMS, *PBLUETOOTH_AUTHENTICATION_CALLBACK_PARAMS;

#define BLUETOOTH_MAX_SERVICE_NAME_SIZE 256
#define BLUETOOTH_DEVICE_NAME_SIZE 256
typedef struct _BLUETOOTH_LOCAL_SERVICE_INFO {
  BOOL              Enabled;
  BLUETOOTH_ADDRESS btAddr;
  WCHAR             szName[BLUETOOTH_MAX_SERVICE_NAME_SIZE];
  WCHAR             szDeviceString[BLUETOOTH_DEVICE_NAME_SIZE];
} BLUETOOTH_LOCAL_SERVICE_INFO;

#define BTH_MAX_PIN_SIZE 16
typedef struct _BLUETOOTH_PIN_INFO {
  UCHAR pin[BTH_MAX_PIN_SIZE];
  UCHAR pinLength;
} BLUETOOTH_PIN_INFO, *PBLUETOOTH_PIN_INFO;

typedef struct _BLUETOOTH_OOB_DATA_INFO {
  UCHAR C[16];
  UCHAR R[16];
} BLUETOOTH_OOB_DATA_INFO, *PBLUETOOTH_OOB_DATA_INFO;

typedef struct _BLUETOOTH_NUMERIC_COMPARISON_INFO {
  ULONG NumericValue;
} BLUETOOTH_NUMERIC_COMPARISON_INFO, *PBLUETOOTH_NUMERIC_COMPARISON_INFO;

typedef struct _BLUETOOTH_PASSKEY_INFO {
  ULONG passkey;
} BLUETOOTH_PASSKEY_INFO, *PBLUETOOTH_PASSKEY_INFO;

typedef struct _BLUETOOTH_AUTHENTICATE_RESPONSE {
  BLUETOOTH_ADDRESS               bthAddressRemote;
  BLUETOOTH_AUTHENTICATION_METHOD authMethod;
  __C89_NAMELESS union {
    BLUETOOTH_PIN_INFO                pinInfo;
    BLUETOOTH_OOB_DATA_INFO           oobInfo;
    BLUETOOTH_NUMERIC_COMPARISON_INFO numericCompInfo;
    BLUETOOTH_PASSKEY_INFO            passkeyInfo;
  };
  UCHAR                           negativeResponse;
} BLUETOOTH_AUTHENTICATE_RESPONSE, *PBLUETOOTH_AUTHENTICATE_RESPONSE;

typedef WINBOOL (*PFN_DEVICE_CALLBACK)(LPVOID pvParam,PBLUETOOTH_DEVICE_INFO pDevice);
typedef WINBOOL (*CALLBACK PFN_AUTHENTICATION_CALLBACK_EX)(LPVOID pvParam,PBLUETOOTH_AUTHENTICATION_CALLBACK_PARAMS pAuthCallbackParams);
typedef WINBOOL (*PFN_AUTHENTICATION_CALLBACK)(LPVOID pvParam,PBLUETOOTH_DEVICE_INFO pDevice);
typedef WINBOOL (*PFN_BLUETOOTH_ENUM_ATTRIBUTES_CALLBACK)(ULONG uAttribId,LPBYTE pValueStream,ULONG cbStreamSize,LPVOID pvParam);

typedef struct _BLUETOOTH_SELECT_DEVICE_PARAMS {
  DWORD                  dwSize;
  ULONG                  cNumOfClasses;
  BLUETOOTH_COD_PAIRS    *prgClassOfDevices;
  LPWSTR                 pszInfo;
  HWND                   hwndParent;
  BOOL                   fForceAuthentication;
  BOOL                   fShowAuthenticated;
  BOOL                   fShowRemembered;
  BOOL                   fShowUnknown;
  BOOL                   fAddNewDeviceWizard;
  BOOL                   fSkipServicesPage;
  PFN_DEVICE_CALLBACK    pfnDeviceCallback;
  LPVOID                 pvParam;
  DWORD                  cNumDevices;
  PBLUETOOTH_DEVICE_INFO pDevices;
} BLUETOOTH_SELECT_DEVICE_PARAMS;

DWORD WINAPI BluetoothAuthenticateMultipleDevices(
    HWND hwndParent,
    HANDLE hRadio,
    DWORD cDevices,
    BLUETOOTH_DEVICE_INFO *pbtdi
);

HRESULT WINAPI BluetoothAuthenticateDeviceEx(
  HWND hwndParentIn,
  HANDLE hRadioIn,
  BLUETOOTH_DEVICE_INFO *pbtdiInout,
  PBLUETOOTH_OOB_DATA_INFO pbtOobData,
  BLUETOOTH_AUTHENTICATION_REQUIREMENTS authenticationRequirement
);

WINBOOL WINAPI BluetoothDisplayDeviceProperties(
    HWND hwndParent,
    BLUETOOTH_DEVICE_INFO *pbtdi
);

WINBOOL WINAPI BluetoothEnableDiscovery(
    HANDLE hRadio,
    WINBOOL fEnabled
);

WINBOOL WINAPI BluetoothEnableIncomingConnections(
    HANDLE hRadio,
    WINBOOL fEnabled
);

DWORD WINAPI BluetoothEnumerateInstalledServices(
    HANDLE hRadio,
    BLUETOOTH_DEVICE_INFO *pbtdi,
    DWORD *pcServices,
    GUID *pGuidServices
);

WINBOOL WINAPI BluetoothFindDeviceClose(
    HBLUETOOTH_DEVICE_FIND hFind
);

HBLUETOOTH_DEVICE_FIND WINAPI BluetoothFindFirstDevice(
    BLUETOOTH_DEVICE_SEARCH_PARAMS *pbtsp,
    BLUETOOTH_DEVICE_INFO *pbtdi
);

HBLUETOOTH_RADIO_FIND WINAPI BluetoothFindFirstRadio(
  BLUETOOTH_FIND_RADIO_PARAMS *pbtfrp,
  HANDLE *phRadio
);

WINBOOL WINAPI BluetoothFindNextDevice(
    HBLUETOOTH_DEVICE_FIND hFind,
    BLUETOOTH_DEVICE_INFO *pbtdi
);

WINBOOL WINAPI BluetoothFindNextRadio(
  HBLUETOOTH_RADIO_FIND hFind,
  HANDLE *phRadio
);

WINBOOL WINAPI BluetoothFindRadioClose(
    HBLUETOOTH_RADIO_FIND hFind
);

DWORD WINAPI BluetoothGetDeviceInfo(
    HANDLE hRadio,
    BLUETOOTH_DEVICE_INFO *pbtdi
);

DWORD WINAPI BluetoothGetRadioInfo(
    HANDLE hRadio,
    PBLUETOOTH_RADIO_INFO pRadioInfo
);

WINBOOL WINAPI BluetoothIsDiscoverable(
    HANDLE hRadio
);

WINBOOL WINAPI BluetoothIsConnectable(
    HANDLE hRadio
);

DWORD WINAPI BluetoothRegisterForAuthentication(
    BLUETOOTH_DEVICE_INFO *pbtdi,
    HBLUETOOTH_AUTHENTICATION_REGISTRATION *phRegHandle,
    PFN_AUTHENTICATION_CALLBACK pfnCallback,
    PVOID pvParam
);

HRESULT WINAPI BluetoothRegisterForAuthenticationEx(
  const BLUETOOTH_DEVICE_INFO *pbtdiln,
  HBLUETOOTH_AUTHENTICATION_REGISTRATION *phRegHandleOut,
  PFN_AUTHENTICATION_CALLBACK_EX pfnCallbackIn,
  PVOID pvParam
);

DWORD WINAPI BluetoothRemoveDevice(
    BLUETOOTH_ADDRESS *pAddress
);

WINBOOL WINAPI BluetoothSdpEnumAttributes(
    LPBYTE pSDPStream,
    ULONG cbStreamSize,
    PFN_BLUETOOTH_ENUM_ATTRIBUTES_CALLBACK pfnCallback,
    LPVOID pvParam
);

DWORD WINAPI BluetoothSdpGetAttributeValue(
  LPBYTE pRecordStream,
  ULONG cbRecordLength,
  USHORT usAttributeId,
  PSDP_ELEMENT_DATA pAttributeData
);

DWORD WINAPI BluetoothSdpGetContainerElementData(
  LPBYTE pContainerStream,
  ULONG cbContainerLength,
  HBLUETOOTH_CONTAINER_ELEMENT *pElement,
  PSDP_ELEMENT_DATA pData
);

DWORD BluetoothSdpGetElementData(
  LPBYTE pSdpStream,
  ULONG cbSpdStreamLength,
  PSDP_ELEMENT_DATA pData
);

DWORD BluetoothSdpGetString(
  LPBYTE pRecordStream,
  ULONG cbRecordLength,
  PSDP_STRING_TYPE_DATA pStringData,
  USHORT usStringOffset,
  PWCHAR pszString,
  PULONG pcchStringLength
);

WINBOOL WINAPI BluetoothSelectDevices(
    BLUETOOTH_SELECT_DEVICE_PARAMS *pbtsdp
);

WINBOOL WINAPI BluetoothSelectDevicesFree(
    BLUETOOTH_SELECT_DEVICE_PARAMS *pbtsdp
);

DWORD WINAPI BluetoothSendAuthenticationResponse(
    HANDLE hRadio,
    BLUETOOTH_DEVICE_INFO *pbtdi,
    LPWSTR pszPasskey
);

HRESULT WINAPI BluetoothSendAuthenticationResponseEx(
  HANDLE hRadioIn,
  PBLUETOOTH_AUTHENTICATE_RESPONSE pauthResponse
);

DWORD WINAPI BluetoothSetLocalServiceInfo(
  HANDLE hRadioIn,
  const GUID *pClassGuid,
  ULONG ulInstance,
  const BLUETOOTH_LOCAL_SERVICE_INFO *pServiceInfoIn
);

DWORD WINAPI BluetoothSetServiceState(
    HANDLE hRadio,
    BLUETOOTH_DEVICE_INFO *pbtdi,
    GUID *pGuidService,
    DWORD dwServiceFlags
);

WINBOOL WINAPI BluetoothUnregisterAuthentication(
    HBLUETOOTH_AUTHENTICATION_REGISTRATION hRegHandle
);

DWORD WINAPI BluetoothUpdateDeviceRecord(
    BLUETOOTH_DEVICE_INFO *pbtdi
);

#ifdef __cplusplus
}
#endif

#endif /*_INC_BLUETOOTHAPIS*/

