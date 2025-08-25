/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _ILOGOBJ_HXX_
#define _ILOGOBJ_HXX_

#define NCSALOG_CLSID TEXT("{FF16065F-DE82-11CF-BC0A-00AA006111E0}")
#define ODBCLOG_CLSID TEXT("{FF16065B-DE82-11CF-BC0A-00AA006111E0}")
#define ASCLOG_CLSID TEXT("{FF160657-DE82-11CF-BC0A-00AA006111E0}")
#define EXTLOG_CLSID TEXT("{FF160663-DE82-11CF-BC0A-00AA006111E0}")

#define NCSALOGUI_CLSID TEXT("{31DCAB85-BB3E-11d0-9299-00C04FB6678B}")
#define ODBCLOGUI_CLSID TEXT("{31DCAB86-BB3E-11d0-9299-00C04FB6678B}")
#define ASCLOGUI_CLSID TEXT("{31DCAB87-BB3E-11d0-9299-00C04FB6678B}")
#define EXTLOGUI_CLSID TEXT("{31DCAB88-BB3E-11d0-9299-00C04FB6678B}")

DEFINE_GUID(IID_IINETLOG_INFORMATION,0xcc557a71,0xf61a,0x11cf,0xbc,0x0f,0x00,0xaa,0x00,0x61,0x11,0xe0);
DEFINE_GUID(IID_ILogPlugin,0x08fd99d1,0xcfb6,0x11cf,0xbc,0x03,0x00,0xaa,0x00,0x61,0x11,0xe0);
DEFINE_GUID(IID_ILogPluginEx,0x3710e192,0x9c25,0x11d1,0x8b,0x9a,0x8,0x0,0x9,0xdc,0xc2,0xfa);
DEFINE_GUID(CLSID_NCSALOG,0xff16065F,0xde82,0x11cf,0xbc,0x0a,0x00,0xaa,0x00,0x61,0x11,0xe0);
DEFINE_GUID(CLSID_ODBCLOG,0xff16065B,0xde82,0x11cf,0xbc,0x0a,0x00,0xaa,0x00,0x61,0x11,0xe0);
DEFINE_GUID(CLSID_ASCLOG,0xff160657,0xde82,0x11cf,0xbc,0x0a,0x00,0xaa,0x00,0x61,0x11,0xe0);
DEFINE_GUID(CLSID_EXTLOG,0xff160663,0xde82,0x11cf,0xbc,0x0a,0x00,0xaa,0x00,0x61,0x11,0xe0);
DEFINE_GUID(IID_LOGGINGUI,0x31dcab89,0xbb3e,0x11d0,0x92,0x99,0x0,0xc0,0x4f,0xb6,0x67,0x8b);
DEFINE_GUID(IID_LOGGINGUI2,0xfae6e2a8,0xbf79,0x4ac6,0xaa,0x58,0x71,0x34,0x7c,0x92,0xd5,0x93);
DEFINE_GUID(CLSID_NCSALOGUI,0x31dcab85,0xbb3e,0x11d0,0x92,0x99,0x0,0xc0,0x4f,0xb6,0x67,0x8b);
DEFINE_GUID(CLSID_ODBCLOGUI,0x31dcab86,0xbb3e,0x11d0,0x92,0x99,0x0,0xc0,0x4f,0xb6,0x67,0x8b);
DEFINE_GUID(CLSID_ASCLOGUI,0x31dcab87,0xbb3e,0x11d0,0x92,0x99,0x0,0xc0,0x4f,0xb6,0x67,0x8b);
DEFINE_GUID(CLSID_EXTLOGUI,0x31dcab88,0xbb3e,0x11d0,0x92,0x99,0x0,0xc0,0x4f,0xb6,0x67,0x8b);
DEFINE_GUID(IID_ICLAPI_CLIENT,0x08fd99d1,0xcfb6,0x11cf,0xbc,0x03,0x00,0xaa,0x00,0x61,0x11,0xe0);
DEFINE_GUID(CLSID_InetLogInformation,0xa1f89741,0xf619,0x11cf,0xbc,0xf,0x0,0xaa,0x0,0x61,0x11,0xe0);

class IInetLogInformation : public IUnknown {
public:
  virtual LPSTR WINAPI GetSiteName(PCHAR pszSiteName,PDWORD pcbSize) = 0;
  virtual LPSTR WINAPI GetComputerName(PCHAR pszComputerName,PDWORD pcbSize) = 0;
  virtual LPSTR WINAPI GetClientHostName(PCHAR pszClientHostName,PDWORD pcbSize) = 0;
  virtual LPSTR WINAPI GetClientUserName(PCHAR pszClientUserName,PDWORD pcbSize) = 0;
  virtual LPSTR WINAPI GetServerAddress(PCHAR pszServerIPAddress,PDWORD pcbSize) = 0;
  virtual LPSTR WINAPI GetOperation(PCHAR pszOperation,PDWORD pcbSize) = 0;
  virtual LPSTR WINAPI GetTarget(PCHAR pszTarget,PDWORD pcbSize) = 0;
  virtual LPSTR WINAPI GetParameters(PCHAR pszParameters,PDWORD pcbSize) = 0;
  virtual LPSTR WINAPI GetExtraHTTPHeaders(PCHAR pszHTTPHeaders,PDWORD pcbSize) = 0;
  virtual DWORD WINAPI GetTimeForProcessing(VOID) = 0;
  virtual DWORD WINAPI GetBytesSent(VOID) = 0;
  virtual DWORD WINAPI GetBytesRecvd(VOID) = 0;
  virtual DWORD WINAPI GetWin32Status(VOID) = 0;
  virtual DWORD WINAPI GetProtocolStatus(VOID) = 0;
  virtual DWORD WINAPI GetPortNumber(VOID) = 0;
  virtual LPSTR WINAPI GetVersionString(PCHAR pszVersionString,PDWORD pcbSize) = 0;
};

class ILogPlugin : public IUnknown {
public:
  virtual HRESULT WINAPI InitializeLog(LPCSTR SiteName,LPCSTR MetabasePath,PCHAR pvIMDCOM) = 0;
  virtual HRESULT WINAPI TerminateLog(VOID) = 0;
  virtual HRESULT WINAPI LogInformation(IInetLogInformation *pLogObj) = 0;
  virtual HRESULT WINAPI SetConfig(DWORD cbSize,PBYTE Log) = 0;
  virtual HRESULT WINAPI GetConfig(DWORD cbSize,PBYTE Log) = 0;
  virtual HRESULT WINAPI QueryExtraLoggingFields(PDWORD cbSize,PCHAR szParameters) = 0;
};

class ILogUIPlugin : public IUnknown {
public:
  virtual HRESULT WINAPI OnProperties(OLECHAR *pocMachineName,OLECHAR *pocMetabasePath) = 0;
};

class ILogUIPlugin2 : public ILogUIPlugin {
public:
  virtual HRESULT WINAPI OnPropertiesEx(OLECHAR *pocMachineName,OLECHAR *pocMetabasePath,OLECHAR *pocUserName,OLECHAR *pocUserPassword) = 0;
};

#ifndef _LOGTYPE_H_
typedef struct _CUSTOM_LOG_DATA {
  LPCSTR szPropertyPath;
  PVOID pData;
} CUSTOM_LOG_DATA,*PCUSTOM_LOG_DATA;
#endif

class ILogPluginEx : public ILogPlugin {
public:
  virtual HRESULT WINAPI LogCustomInformation(DWORD cCount,PCUSTOM_LOG_DATA pCustomLogData,LPSTR szHeaderSuffix) = 0;
};
#endif
