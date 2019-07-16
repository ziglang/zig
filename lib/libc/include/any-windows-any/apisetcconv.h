/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _APISETCCONV_
#define _APISETCCONV_

#ifndef CMAPI
#ifndef _CFGMGR32_
#define CMAPI DECLSPEC_IMPORT
#else
#define CMAPI
#endif
#endif

#ifndef CREDUIAPI
#ifndef _CREDUI_
#define CREDUIAPI DECLSPEC_IMPORT
#else
#define CREDUIAPI
#endif
#endif

#ifndef WINABLEAPI
#ifndef _USER32_
#define WINABLEAPI DECLSPEC_IMPORT
#else
#define WINABLEAPI
#endif
#endif

#ifndef WINADVAPI
#ifndef _ADVAPI32_
#define WINADVAPI DECLSPEC_IMPORT
#else
#define WINADVAPI
#endif
#endif

#ifndef WINBASEAPI
#ifndef _KERNEL32_
#define WINBASEAPI DECLSPEC_IMPORT
#else
#define WINBASEAPI
#endif
#endif

#ifndef WINUSERAPI
#ifndef _USER32_
#define WINUSERAPI DECLSPEC_IMPORT
#else
#define WINUSERAPI
#endif
#endif

#ifndef ZAWPROXYAPI
#ifndef _ZAWPROXY_
#define ZAWPROXYAPI DECLSPEC_IMPORT
#else
#define ZAWPROXYAPI
#endif
#endif

#ifndef WINCFGMGR32API
#ifndef _SETUPAPI_
#define WINCFGMGR32API DECLSPEC_IMPORT
#else
#define WINCFGMGR32API
#endif
#endif

#ifndef WINDEVQUERYAPI
#ifndef _CFGMGR32_
#define WINDEVQUERYAPI DECLSPEC_IMPORT
#else
#define WINDEVQUERYAPI
#endif
#endif

#ifndef WINSWDEVICEAPI
#ifndef _CFGMGR32_
#define WINSWDEVICEAPI DECLSPEC_IMPORT
#else
#define WINSWDEVICEAPI
#endif
#endif

#ifndef WINPATHCCHAPI
#ifndef STATIC_PATHCCH
#define WINPATHCCHAPI WINBASEAPI 
#else  
#define WINPATHCCHAPI
#endif  
#endif

#endif
