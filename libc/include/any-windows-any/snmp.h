/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_SNMP
#define _INC_SNMP

#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <pshpack4.h>

  typedef struct {
    BYTE *stream;
    UINT length;
    WINBOOL dynamic;
  } AsnOctetString;

  typedef struct {
    UINT idLength;
    UINT *ids;
  } AsnObjectIdentifier;

  typedef LONG AsnInteger32;
  typedef ULONG AsnUnsigned32;
  typedef ULARGE_INTEGER AsnCounter64;
  typedef AsnUnsigned32 AsnCounter32;
  typedef AsnUnsigned32 AsnGauge32;
  typedef AsnUnsigned32 AsnTimeticks;
  typedef AsnOctetString AsnBits;
  typedef AsnOctetString AsnSequence;
  typedef AsnOctetString AsnImplicitSequence;
  typedef AsnOctetString AsnIPAddress;
  typedef AsnOctetString AsnNetworkAddress;
  typedef AsnOctetString AsnDisplayString;
  typedef AsnOctetString AsnOpaque;

  typedef struct {
    BYTE asnType;
    union {
      AsnInteger32 number;

      AsnUnsigned32 unsigned32;
      AsnCounter64 counter64;
      AsnOctetString string;
      AsnBits bits;
      AsnObjectIdentifier object;
      AsnSequence sequence;
      AsnIPAddress address;
      AsnCounter32 counter;
      AsnGauge32 gauge;
      AsnTimeticks ticks;
      AsnOpaque arbitrary;
    } asnValue;
  } AsnAny;

  typedef AsnObjectIdentifier AsnObjectName;
  typedef AsnAny AsnObjectSyntax;

  typedef struct {
    AsnObjectName name;
    AsnObjectSyntax value;
  } SnmpVarBind;

  typedef struct {
    SnmpVarBind *list;
    UINT len;
  } SnmpVarBindList;

#include <poppack.h>

#ifndef _INC_WINSNMP
#define ASN_UNIVERSAL 0x00
#define ASN_APPLICATION 0x40
#define ASN_CONTEXT 0x80
#define ASN_PRIVATE 0xC0
#define ASN_PRIMITIVE 0x00
#define ASN_CONSTRUCTOR 0x20

#define SNMP_PDU_GET (ASN_CONTEXT | ASN_CONSTRUCTOR | 0x0)
#define SNMP_PDU_GETNEXT (ASN_CONTEXT | ASN_CONSTRUCTOR | 0x1)
#define SNMP_PDU_RESPONSE (ASN_CONTEXT | ASN_CONSTRUCTOR | 0x2)
#define SNMP_PDU_SET (ASN_CONTEXT | ASN_CONSTRUCTOR | 0x3)
#define SNMP_PDU_V1TRAP (ASN_CONTEXT | ASN_CONSTRUCTOR | 0x4)
#define SNMP_PDU_GETBULK (ASN_CONTEXT | ASN_CONSTRUCTOR | 0x5)
#define SNMP_PDU_INFORM (ASN_CONTEXT | ASN_CONSTRUCTOR | 0x6)
#define SNMP_PDU_TRAP (ASN_CONTEXT | ASN_CONSTRUCTOR | 0x7)
#endif

#define ASN_INTEGER (ASN_UNIVERSAL | ASN_PRIMITIVE | 0x02)
#define ASN_BITS (ASN_UNIVERSAL | ASN_PRIMITIVE | 0x03)
#define ASN_OCTETSTRING (ASN_UNIVERSAL | ASN_PRIMITIVE | 0x04)
#define ASN_NULL (ASN_UNIVERSAL | ASN_PRIMITIVE | 0x05)
#define ASN_OBJECTIDENTIFIER (ASN_UNIVERSAL | ASN_PRIMITIVE | 0x06)
#define ASN_INTEGER32 ASN_INTEGER

#define ASN_SEQUENCE (ASN_UNIVERSAL | ASN_CONSTRUCTOR | 0x10)
#define ASN_SEQUENCEOF ASN_SEQUENCE

#define ASN_IPADDRESS (ASN_APPLICATION | ASN_PRIMITIVE | 0x00)
#define ASN_COUNTER32 (ASN_APPLICATION | ASN_PRIMITIVE | 0x01)
#define ASN_GAUGE32 (ASN_APPLICATION | ASN_PRIMITIVE | 0x02)
#define ASN_TIMETICKS (ASN_APPLICATION | ASN_PRIMITIVE | 0x03)
#define ASN_OPAQUE (ASN_APPLICATION | ASN_PRIMITIVE | 0x04)
#define ASN_COUNTER64 (ASN_APPLICATION | ASN_PRIMITIVE | 0x06)
#define ASN_UINTEGER32 (ASN_APPLICATION | ASN_PRIMITIVE | 0x07)
#define ASN_RFC2578_UNSIGNED32 ASN_GAUGE32

#define SNMP_EXCEPTION_NOSUCHOBJECT (ASN_CONTEXT | ASN_PRIMITIVE | 0x00)
#define SNMP_EXCEPTION_NOSUCHINSTANCE (ASN_CONTEXT | ASN_PRIMITIVE | 0x01)
#define SNMP_EXCEPTION_ENDOFMIBVIEW (ASN_CONTEXT | ASN_PRIMITIVE | 0x02)

#define SNMP_EXTENSION_GET SNMP_PDU_GET
#define SNMP_EXTENSION_GET_NEXT SNMP_PDU_GETNEXT
#define SNMP_EXTENSION_GET_BULK SNMP_PDU_GETBULK
#define SNMP_EXTENSION_SET_TEST (ASN_PRIVATE | ASN_CONSTRUCTOR | 0x0)
#define SNMP_EXTENSION_SET_COMMIT SNMP_PDU_SET
#define SNMP_EXTENSION_SET_UNDO (ASN_PRIVATE | ASN_CONSTRUCTOR | 0x1)
#define SNMP_EXTENSION_SET_CLEANUP (ASN_PRIVATE | ASN_CONSTRUCTOR | 0x2)

#define SNMP_ERRORSTATUS_NOERROR 0
#define SNMP_ERRORSTATUS_TOOBIG 1
#define SNMP_ERRORSTATUS_NOSUCHNAME 2
#define SNMP_ERRORSTATUS_BADVALUE 3
#define SNMP_ERRORSTATUS_READONLY 4
#define SNMP_ERRORSTATUS_GENERR 5
#define SNMP_ERRORSTATUS_NOACCESS 6
#define SNMP_ERRORSTATUS_WRONGTYPE 7
#define SNMP_ERRORSTATUS_WRONGLENGTH 8
#define SNMP_ERRORSTATUS_WRONGENCODING 9
#define SNMP_ERRORSTATUS_WRONGVALUE 10
#define SNMP_ERRORSTATUS_NOCREATION 11
#define SNMP_ERRORSTATUS_INCONSISTENTVALUE 12
#define SNMP_ERRORSTATUS_RESOURCEUNAVAILABLE 13
#define SNMP_ERRORSTATUS_COMMITFAILED 14
#define SNMP_ERRORSTATUS_UNDOFAILED 15
#define SNMP_ERRORSTATUS_AUTHORIZATIONERROR 16
#define SNMP_ERRORSTATUS_NOTWRITABLE 17
#define SNMP_ERRORSTATUS_INCONSISTENTNAME 18

#define SNMP_GENERICTRAP_COLDSTART 0
#define SNMP_GENERICTRAP_WARMSTART 1
#define SNMP_GENERICTRAP_LINKDOWN 2
#define SNMP_GENERICTRAP_LINKUP 3
#define SNMP_GENERICTRAP_AUTHFAILURE 4
#define SNMP_GENERICTRAP_EGPNEIGHLOSS 5
#define SNMP_GENERICTRAP_ENTERSPECIFIC 6

#define SNMP_ACCESS_NONE 0
#define SNMP_ACCESS_NOTIFY 1
#define SNMP_ACCESS_READ_ONLY 2
#define SNMP_ACCESS_READ_WRITE 3
#define SNMP_ACCESS_READ_CREATE 4

#define SNMPAPI INT
#define SNMP_FUNC_TYPE WINAPI

#define SNMPAPI_NOERROR TRUE
#define SNMPAPI_ERROR FALSE

  WINBOOL SNMP_FUNC_TYPE SnmpExtensionInit(DWORD dwUptimeReference,HANDLE *phSubagentTrapEvent,AsnObjectIdentifier *pFirstSupportedRegion);
  WINBOOL SNMP_FUNC_TYPE SnmpExtensionInitEx(AsnObjectIdentifier *pNextSupportedRegion);
  WINBOOL SNMP_FUNC_TYPE SnmpExtensionMonitor(LPVOID pAgentMgmtData);
  WINBOOL SNMP_FUNC_TYPE SnmpExtensionQuery(BYTE bPduType,SnmpVarBindList *pVarBindList,AsnInteger32 *pErrorStatus,AsnInteger32 *pErrorIndex);
  WINBOOL SNMP_FUNC_TYPE SnmpExtensionQueryEx(UINT nRequestType,UINT nTransactionId,SnmpVarBindList *pVarBindList,AsnOctetString *pContextInfo,AsnInteger32 *pErrorStatus,AsnInteger32 *pErrorIndex);
  WINBOOL SNMP_FUNC_TYPE SnmpExtensionTrap(AsnObjectIdentifier *pEnterpriseOid,AsnInteger32 *pGenericTrapId,AsnInteger32 *pSpecificTrapId,AsnTimeticks *pTimeStamp,SnmpVarBindList *pVarBindList);
  VOID SNMP_FUNC_TYPE SnmpExtensionClose();

  typedef WINBOOL (SNMP_FUNC_TYPE *PFNSNMPEXTENSIONINIT)(DWORD dwUpTimeReference,HANDLE *phSubagentTrapEvent,AsnObjectIdentifier *pFirstSupportedRegion);
  typedef WINBOOL (SNMP_FUNC_TYPE *PFNSNMPEXTENSIONINITEX)(AsnObjectIdentifier *pNextSupportedRegion);
  typedef WINBOOL (SNMP_FUNC_TYPE *PFNSNMPEXTENSIONMONITOR)(LPVOID pAgentMgmtData);
  typedef WINBOOL (SNMP_FUNC_TYPE *PFNSNMPEXTENSIONQUERY)(BYTE bPduType,SnmpVarBindList *pVarBindList,AsnInteger32 *pErrorStatus,AsnInteger32 *pErrorIndex);
  typedef WINBOOL (SNMP_FUNC_TYPE *PFNSNMPEXTENSIONQUERYEX)(UINT nRequestType,UINT nTransactionId,SnmpVarBindList *pVarBindList,AsnOctetString *pContextInfo,AsnInteger32 *pErrorStatus,AsnInteger32 *pErrorIndex);
  typedef WINBOOL (SNMP_FUNC_TYPE *PFNSNMPEXTENSIONTRAP)(AsnObjectIdentifier *pEnterpriseOid,AsnInteger32 *pGenericTrapId,AsnInteger32 *pSpecificTrapId,AsnTimeticks *pTimeStamp,SnmpVarBindList *pVarBindList);
  typedef VOID (SNMP_FUNC_TYPE *PFNSNMPEXTENSIONCLOSE)();

  SNMPAPI SNMP_FUNC_TYPE SnmpUtilOidCpy(AsnObjectIdentifier *pOidDst,AsnObjectIdentifier *pOidSrc);
  SNMPAPI SNMP_FUNC_TYPE SnmpUtilOidAppend(AsnObjectIdentifier *pOidDst,AsnObjectIdentifier *pOidSrc);
  SNMPAPI SNMP_FUNC_TYPE SnmpUtilOidNCmp(AsnObjectIdentifier *pOid1,AsnObjectIdentifier *pOid2,UINT nSubIds);
  SNMPAPI SNMP_FUNC_TYPE SnmpUtilOidCmp(AsnObjectIdentifier *pOid1,AsnObjectIdentifier *pOid2);
  VOID SNMP_FUNC_TYPE SnmpUtilOidFree(AsnObjectIdentifier *pOid);
  SNMPAPI SNMP_FUNC_TYPE SnmpUtilOctetsCmp(AsnOctetString *pOctets1,AsnOctetString *pOctets2);
  SNMPAPI SNMP_FUNC_TYPE SnmpUtilOctetsNCmp(AsnOctetString *pOctets1,AsnOctetString *pOctets2,UINT nChars);
  SNMPAPI SNMP_FUNC_TYPE SnmpUtilOctetsCpy(AsnOctetString *pOctetsDst,AsnOctetString *pOctetsSrc);
  VOID SNMP_FUNC_TYPE SnmpUtilOctetsFree(AsnOctetString *pOctets);
  SNMPAPI SNMP_FUNC_TYPE SnmpUtilAsnAnyCpy(AsnAny *pAnyDst,AsnAny *pAnySrc);
  VOID SNMP_FUNC_TYPE SnmpUtilAsnAnyFree(AsnAny *pAny);
  SNMPAPI SNMP_FUNC_TYPE SnmpUtilVarBindCpy(SnmpVarBind *pVbDst,SnmpVarBind *pVbSrc);
  VOID SNMP_FUNC_TYPE SnmpUtilVarBindFree(SnmpVarBind *pVb);
  SNMPAPI SNMP_FUNC_TYPE SnmpUtilVarBindListCpy(SnmpVarBindList *pVblDst,SnmpVarBindList *pVblSrc);
  VOID SNMP_FUNC_TYPE SnmpUtilVarBindListFree(SnmpVarBindList *pVbl);
  VOID SNMP_FUNC_TYPE SnmpUtilMemFree(LPVOID pMem);
  LPVOID SNMP_FUNC_TYPE SnmpUtilMemAlloc(UINT nBytes);
  LPVOID SNMP_FUNC_TYPE SnmpUtilMemReAlloc(LPVOID pMem,UINT nBytes);
  LPSTR SNMP_FUNC_TYPE SnmpUtilOidToA(AsnObjectIdentifier *Oid);
  LPSTR SNMP_FUNC_TYPE SnmpUtilIdsToA(UINT *Ids,UINT IdLength);
  VOID SNMP_FUNC_TYPE SnmpUtilPrintOid(AsnObjectIdentifier *Oid);
  VOID SNMP_FUNC_TYPE SnmpUtilPrintAsnAny(AsnAny *pAny);
  DWORD SNMP_FUNC_TYPE SnmpSvcGetUptime();
  VOID SNMP_FUNC_TYPE SnmpSvcSetLogLevel(INT nLogLevel);
  VOID SNMP_FUNC_TYPE SnmpSvcSetLogType(INT nLogType);

#define SNMP_LOG_SILENT 0x0
#define SNMP_LOG_FATAL 0x1
#define SNMP_LOG_ERROR 0x2
#define SNMP_LOG_WARNING 0x3
#define SNMP_LOG_TRACE 0x4
#define SNMP_LOG_VERBOSE 0x5

#define SNMP_OUTPUT_TO_CONSOLE 0x1
#define SNMP_OUTPUT_TO_LOGFILE 0x2
#define SNMP_OUTPUT_TO_EVENTLOG 0x4
#define SNMP_OUTPUT_TO_DEBUGGER 0x8

  VOID WINAPIV SnmpUtilDbgPrint(INT nLogLevel,LPSTR szFormat,...);

#define SNMPDBG(_x_)

#define DEFINE_SIZEOF(Array) (sizeof(Array)/sizeof((Array)[0]))
#define DEFINE_OID(SubIdArray) {DEFINE_SIZEOF(SubIdArray),(SubIdArray)}
#define DEFINE_NULLOID() {0,NULL}
#define DEFINE_NULLOCTETS() {NULL,0,FALSE}

#define DEFAULT_SNMP_PORT_UDP 161
#define DEFAULT_SNMP_PORT_IPX 36879
#define DEFAULT_SNMPTRAP_PORT_UDP 162
#define DEFAULT_SNMPTRAP_PORT_IPX 36880

#define SNMP_MAX_OID_LEN 128

#define SNMP_MEM_ALLOC_ERROR 1
#define SNMP_BERAPI_INVALID_LENGTH 10
#define SNMP_BERAPI_INVALID_TAG 11
#define SNMP_BERAPI_OVERFLOW 12
#define SNMP_BERAPI_SHORT_BUFFER 13
#define SNMP_BERAPI_INVALID_OBJELEM 14
#define SNMP_PDUAPI_UNRECOGNIZED_PDU 20
#define SNMP_PDUAPI_INVALID_ES 21
#define SNMP_PDUAPI_INVALID_GT 22
#define SNMP_AUTHAPI_INVALID_VERSION 30
#define SNMP_AUTHAPI_INVALID_MSG_TYPE 31
#define SNMP_AUTHAPI_TRIV_AUTH_FAILED 32

#ifndef SNMPSTRICT

#define SNMP_oidcpy SnmpUtilOidCpy
#define SNMP_oidappend SnmpUtilOidAppend
#define SNMP_oidncmp SnmpUtilOidNCmp
#define SNMP_oidcmp SnmpUtilOidCmp
#define SNMP_oidfree SnmpUtilOidFree

#define SNMP_CopyVarBindList SnmpUtilVarBindListCpy
#define SNMP_FreeVarBindList SnmpUtilVarBindListFree
#define SNMP_CopyVarBind SnmpUtilVarBindCpy
#define SNMP_FreeVarBind SnmpUtilVarBindFree

#define SNMP_printany SnmpUtilPrintAsnAny

#define SNMP_free SnmpUtilMemFree
#define SNMP_malloc SnmpUtilMemAlloc
#define SNMP_realloc SnmpUtilMemReAlloc

#define SNMP_DBG_free SnmpUtilMemFree
#define SNMP_DBG_malloc SnmpUtilMemAlloc
#define SNMP_DBG_realloc SnmpUtilMemReAlloc

#define ASN_RFC1155_IPADDRESS ASN_IPADDRESS
#define ASN_RFC1155_COUNTER ASN_COUNTER32
#define ASN_RFC1155_GAUGE ASN_GAUGE32
#define ASN_RFC1155_TIMETICKS ASN_TIMETICKS
#define ASN_RFC1155_OPAQUE ASN_OPAQUE
#define ASN_RFC1213_DISPSTRING ASN_OCTETSTRING

#define ASN_RFC1157_GETREQUEST SNMP_PDU_GET
#define ASN_RFC1157_GETNEXTREQUEST SNMP_PDU_GETNEXT
#define ASN_RFC1157_GETRESPONSE SNMP_PDU_RESPONSE
#define ASN_RFC1157_SETREQUEST SNMP_PDU_SET
#define ASN_RFC1157_TRAP SNMP_PDU_V1TRAP

#define ASN_CONTEXTSPECIFIC ASN_CONTEXT
#define ASN_PRIMATIVE ASN_PRIMITIVE

#define RFC1157VarBindList SnmpVarBindList
#define RFC1157VarBind SnmpVarBind
#define AsnInteger AsnInteger32
#define AsnCounter AsnCounter32
#define AsnGauge AsnGauge32
#define ASN_UNSIGNED32 ASN_UINTEGER32
#endif

#ifdef __cplusplus
}
#endif

#endif /* _INC_SNMP */

