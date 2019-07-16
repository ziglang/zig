/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_FUNCTIONDISCOVERYKEYS
#define _INC_FUNCTIONDISCOVERYKEYS

#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

/* More magic keys at  http://msdn.microsoft.com/en-us/library/aa364697%28v=VS.85%29.aspx */

#define PNPX_DEVICECATEGORY_COMPUTER L"Computers"
#define PNPX_DEVICECATEGORY_INPUTDEVICE L"Input"
#define PNPX_DEVICECATEGORY_PRINTER L"Printers"
#define PNPX_DEVICECATEGORY_SCANNER L"Scanners"
#define PNPX_DEVICECATEGORY_FAX L"FAX"
#define PNPX_DEVICECATEGORY_MFP L"MFP"
#define PNPX_DEVICECATEGORY_CAMERA L"Cameras"
#define PNPX_DEVICECATEGORY_STORAGE L"Storage"
#define PNPX_DEVICECATEGORY_NETWORK_INFRASTRUCTURE L"NetworkInfrastructure"
#define PNPX_DEVICECATEGORY_DISPLAYS L"Displays"
#define PNPX_DEVICECATEGORY_MULTIMEDIA_DEVICE L"MediaDevices"
#define PNPX_DEVICECATEGORY_GAMING_DEVICE L"Gaming"
#define PNPX_DEVICECATEGORY_TELEPHONE L"Phones"
#define PNPX_DEVICECATEGORY_HOME_AUTOMATION_SYSTEM L"HomeAutomation"
#define PNPX_DEVICECATEGORY_HOME_SECURITY_SYSTEM L"HomeSecurity"
#define PNPX_DEVICECATEGORY_OTHER L"Other"

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_FUNCTIONDISCOVERYKEYS*/
