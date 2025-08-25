/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef MSRemote_INCLUDED
#define MSRemote_INCLUDED

#define MS_REMOTE_PROGID "MS Remote"
#define MS_REMOTE_FILENAME "MSDAREM.DLL"
#define MS_REMOTE_WPROGID L"MS Remote"
#define MS_REMOTE_WFILENAME L"MSDAREM.DLL"

extern const CLSID CLSID_MSRemote
#if (defined MSREMOTE_INITCONSTANTS) | (defined DBINITCONSTANTS)
= { 0x27016870,0x8e02,0x11d1,{ 0x92,0x4e,0x0,0xc0,0x4f,0xbb,0xbf,0xb3 } }
#endif
;

extern const CLSID CLSID_MSRemoteSession
#if (defined MSREMOTE_INITCONSTANTS) | (defined DBINITCONSTANTS)
= { 0x27016871,0x8e02,0x11d1,{ 0x92,0x4e,0x0,0xc0,0x4f,0xbb,0xbf,0xb3 } }
#endif
;

extern const CLSID CLSID_MSRemoteCommand
#if (defined MSREMOTE_INITCONSTANTS) | (defined DBINITCONSTANTS)
= { 0x27016872,0x8e02,0x11d1,{ 0x92,0x4e,0x0,0xc0,0x4f,0xbb,0xbf,0xb3 } }
#endif
;

extern const char *PROGID_MSRemote
#if (defined MSREMOTE_INITCONSTANTS) | (defined DBINITCONSTANTS)
= MS_REMOTE_PROGID
#endif
;

extern const WCHAR *PROGID_WMSRemote
#if (defined MSREMOTE_INITCONSTANTS) | (defined DBINITCONSTANTS)
= MS_REMOTE_WPROGID
#endif
;

extern const char *PROGID_MSRemote_Version
#if (defined MSREMOTE_INITCONSTANTS) | (defined DBINITCONSTANTS)
= MS_REMOTE_PROGID ".1"
#endif
;

extern const WCHAR *PROGID_WMSRemote_Version
#if (defined MSREMOTE_INITCONSTANTS) | (defined DBINITCONSTANTS)
= MS_REMOTE_WPROGID L".1"
#endif
;
extern const GUID DBPROPSET_MSREMOTE_DBINIT
#if (defined MSREMOTE_INITCONSTANTS) | (defined DBINITCONSTANTS)
= { 0x27016873,0x8e02,0x11d1,{ 0x92,0x4e,0x0,0xc0,0x4f,0xbb,0xbf,0xb3 } }
#endif
;

#define DBPROP_MSREMOTE_SERVER 2
#define DBPROP_MSREMOTE_PROVIDER 3
#define DBPROP_MSREMOTE_HANDLER 4
#define DBPROP_MSREMOTE_DFMODE 5
#define DBPROP_MSREMOTE_INTERNET_TIMEOUT 6
#define DBPROP_MSREMOTE_TRANSACT_UPDATES 7
#define DBPROP_MSREMOTE_COMMAND_PROPERTIES 8

extern const GUID DBPROPSET_MSREMOTE_DATASOURCE
#if (defined MSREMOTE_INITCONSTANTS) | (defined DBINITCONSTANTS)
= { 0x27016874,0x8e02,0x11d1,{ 0x92,0x4e,0x0,0xc0,0x4f,0xbb,0xbf,0xb3 } }
#endif
;

#define DBPROP_MSREMOTE_CURRENT_DFMODE 2
#endif
