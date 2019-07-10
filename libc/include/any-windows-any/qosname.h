/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define QT_1 "G711"
#define QT_2 "G723.1"
#define QT_3 "G729"
#define QT_4 "H263QCIF"
#define QT_5 "H263CIF"
#define QT_6 "H261QCIF"
#define QT_7 "H261CIF"
#define QT_8 "GSM6.10"

#define WSCINSTALL_QOS_TEMPLATE "WSCInstallQOSTemplate"
#define WSCREMOVE_QOS_TEMPLATE "WSCRemoveQOSTemplate"
#define WPUGET_QOS_TEMPLATE "WPUGetQOSTemplate"

typedef WINBOOL (WINAPI *WSC_INSTALL_QOS_TEMPLATE)(const LPGUID Guid,LPWSABUF QosName,LPQOS Qos);
typedef WINBOOL (WINAPI *WSC_REMOVE_QOS_TEMPLATE)(const LPGUID Guid,LPWSABUF QosName);
typedef WINBOOL (WINAPI *WPU_GET_QOS_TEMPLATE)(const LPGUID Guid,LPWSABUF QosName,LPQOS Qos);
