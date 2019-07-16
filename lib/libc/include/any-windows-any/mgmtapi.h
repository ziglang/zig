/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_MGMTAPI
#define _INC_MGMTAPI

#include <snmp.h>
#include <winsock.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SNMP_MGMTAPI_TIMEOUT 40
#define SNMP_MGMTAPI_SELECT_FDERRORS 41
#define SNMP_MGMTAPI_TRAP_ERRORS 42
#define SNMP_MGMTAPI_TRAP_DUPINIT 43
#define SNMP_MGMTAPI_NOTRAPS 44
#define SNMP_MGMTAPI_AGAIN 45
#define SNMP_MGMTAPI_INVALID_CTL 46
#define SNMP_MGMTAPI_INVALID_SESSION 47
#define SNMP_MGMTAPI_INVALID_BUFFER 48

#define MGMCTL_SETAGENTPORT 0x01

  typedef PVOID LPSNMP_MGR_SESSION;

  LPSNMP_MGR_SESSION SNMP_FUNC_TYPE SnmpMgrOpen(LPSTR lpAgentAddress,LPSTR lpAgentCommunity,INT nTimeOut,INT nRetries);
  WINBOOL SNMP_FUNC_TYPE SnmpMgrCtl(LPSNMP_MGR_SESSION session,DWORD dwCtlCode,LPVOID lpvInBuffer,DWORD cbInBuffer,LPVOID lpvOUTBuffer,DWORD cbOUTBuffer,LPDWORD lpcbBytesReturned);
  WINBOOL SNMP_FUNC_TYPE SnmpMgrClose(LPSNMP_MGR_SESSION session);
  SNMPAPI SNMP_FUNC_TYPE SnmpMgrRequest(LPSNMP_MGR_SESSION session,BYTE requestType,RFC1157VarBindList *variableBindings,AsnInteger *errorStatus,AsnInteger *errorIndex);
  WINBOOL SNMP_FUNC_TYPE SnmpMgrStrToOid(LPSTR string,AsnObjectIdentifier *oid);
  WINBOOL SNMP_FUNC_TYPE SnmpMgrOidToStr(AsnObjectIdentifier *oid,LPSTR *string);
  WINBOOL SNMP_FUNC_TYPE SnmpMgrTrapListen(HANDLE *phTrapAvailable);
  WINBOOL SNMP_FUNC_TYPE SnmpMgrGetTrap(AsnObjectIdentifier *enterprise,AsnNetworkAddress *IPAddress,AsnInteger *genericTrap,AsnInteger *specificTrap,AsnTimeticks *timeStamp,RFC1157VarBindList *variableBindings);
  WINBOOL SNMP_FUNC_TYPE SnmpMgrGetTrapEx(AsnObjectIdentifier *enterprise,AsnNetworkAddress *agentAddress,AsnNetworkAddress *sourceAddress,AsnInteger *genericTrap,AsnInteger *specificTrap,AsnOctetString *community,AsnTimeticks *timeStamp,RFC1157VarBindList *variableBindings);

#ifdef __cplusplus
}
#endif
#endif
