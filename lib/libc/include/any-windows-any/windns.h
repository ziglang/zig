/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WINDNS_INCLUDED_
#define _WINDNS_INCLUDED_

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

  __MINGW_EXTENSION typedef unsigned __int64 QWORD,*PQWORD;
  typedef LONG DNS_STATUS,*PDNS_STATUS;
  typedef DWORD IP4_ADDRESS,*PIP4_ADDRESS;

#define SIZEOF_IP4_ADDRESS (4)
#define IP4_ADDRESS_STRING_LENGTH (15)
#define IP4_ADDRESS_STRING_BUFFER_LENGTH (16)

  typedef struct _IP4_ARRAY {
    DWORD AddrCount;
    IP4_ADDRESS AddrArray[1];
  } IP4_ARRAY,*PIP4_ARRAY;

  typedef union {
#ifdef _WIN64
    QWORD IP6Qword[2];
#endif
    DWORD IP6Dword[4];
    WORD IP6Word[8];
    BYTE IP6Byte[16];
#ifdef IN6_ADDR
    IN6_ADDR In6;
#endif
  } IP6_ADDRESS,*PIP6_ADDRESS;

#undef IP6_ADDRESS_STRING_LENGTH
#define IP6_ADDRESS_STRING_LENGTH (47)
#define IP6_ADDRESS_STRING_BUFFER_LENGTH (48)
#define DNS_ADDRESS_STRING_LENGTH (IP6_ADDRESS_STRING_LENGTH)

#define INLINE_WORD_FLIP(out,in) { WORD _in = (in); (out) = (_in << 8) | (_in >> 8); }
#define INLINE_HTONS(out,in) INLINE_WORD_FLIP(out,in)
#define INLINE_NTOHS(out,in) INLINE_WORD_FLIP(out,in)
#define INLINE_DWORD_FLIP(out,in) { DWORD _in = (in); (out) = ((_in << 8) & 0x00ff0000) | (_in << 24) | ((_in >> 8) & 0x0000ff00) | (_in >> 24); }
#define INLINE_NTOHL(out,in) INLINE_DWORD_FLIP(out,in)
#define INLINE_HTONL(out,in) INLINE_DWORD_FLIP(out,in)
#define INLINE_WRITE_FLIPPED_WORD(pout,in) INLINE_WORD_FLIP(*((UNALIGNED WORD *)(pout)),in)
#define INLINE_WRITE_FLIPPED_DWORD(pout,in) INLINE_DWORD_FLIP(*((UNALIGNED DWORD *)(pout)),in)

#define DNS_PORT_HOST_ORDER (0x0035)
#define DNS_PORT_NET_ORDER (0x3500)
#define DNS_RFC_MAX_UDP_PACKET_LENGTH (512)
#define DNS_MAX_NAME_LENGTH (255)
#define DNS_MAX_LABEL_LENGTH (63)
#define DNS_MAX_NAME_BUFFER_LENGTH (256)
#define DNS_MAX_LABEL_BUFFER_LENGTH (64)
#define DNS_IP4_REVERSE_DOMAIN_STRING_A ("in-addr.arpa.")
#define DNS_IP4_REVERSE_DOMAIN_STRING_W (L"in-addr.arpa.")
#define DNS_MAX_IP4_REVERSE_NAME_LENGTH (IP4_ADDRESS_STRING_LENGTH+1+sizeof(DNS_IP4_REVERSE_DOMAIN_STRING_A))
#define DNS_MAX_IP4_REVERSE_NAME_BUFFER_LENGTH (DNS_MAX_IP4_REVERSE_NAME_LENGTH + 1)
#define DNS_IP6_REVERSE_DOMAIN_STRING_A ("ip6.arpa.")
#define DNS_IP6_REVERSE_DOMAIN_STRING_W (L"ip6.arpa.")
#define DNS_MAX_IP6_REVERSE_NAME_LENGTH (64+sizeof(DNS_IP6_REVERSE_DOMAIN_STRING_A))
#define DNS_MAX_IP6_REVERSE_NAME_BUFFER_LENGTH (DNS_MAX_IP6_REVERSE_NAME_LENGTH + 1)
#define DNS_MAX_REVERSE_NAME_LENGTH DNS_MAX_IP6_REVERSE_NAME_LENGTH
#define DNS_MAX_REVERSE_NAME_BUFFER_LENGTH DNS_MAX_IP6_REVERSE_NAME_BUFFER_LENGTH

#define DNS_IP4_REVERSE_DOMAIN_STRING __MINGW_NAME_UAW(DNS_IP4_REVERSE_DOMAIN_STRING)
#define DNS_IP6_REVERSE_DOMAIN_STRING __MINGW_NAME_UAW(DNS_IP6_REVERSE_DOMAIN_STRING)

#define DNS_MAX_TEXT_STRING_LENGTH (255)

#pragma pack(1)

  typedef struct _DNS_HEADER {
    WORD Xid;
    BYTE RecursionDesired : 1;
    BYTE Truncation : 1;
    BYTE Authoritative : 1;
    BYTE Opcode : 4;
    BYTE IsResponse : 1;
    BYTE ResponseCode : 4;
    BYTE CheckingDisabled : 1;
    BYTE AuthenticatedData : 1;
    BYTE Reserved : 1;
    BYTE RecursionAvailable : 1;
    WORD QuestionCount;
    WORD AnswerCount;
    WORD NameServerCount;
    WORD AdditionalCount;
  } DNS_HEADER, *PDNS_HEADER;

  typedef struct _DNS_HEADER_EXT {
    WORD Reserved : 15;
    WORD DnssecOk : 1;
    BYTE chRcode;
    BYTE chVersion;
  } DNS_HEADER_EXT, *PDNS_HEADER_EXT;

#define DNS_HEADER_FLAGS(pHead) (*((PWORD)(pHead)+1))
#define DNS_BYTE_FLIP_HEADER_COUNTS(pHeader) { PDNS_HEADER _head = (pHeader); INLINE_HTONS(_head->Xid,_head->Xid); INLINE_HTONS(_head->QuestionCount,_head->QuestionCount); INLINE_HTONS(_head->AnswerCount,_head->AnswerCount); INLINE_HTONS(_head->NameServerCount,_head->NameServerCount); INLINE_HTONS(_head->AdditionalCount,_head->AdditionalCount); }
#define DNS_OFFSET_TO_QUESTION_NAME sizeof(DNS_HEADER)
#define DNS_COMPRESSED_QUESTION_NAME (0xC00C)
#define DNS_QUESTION_NAME_FROM_HEADER(_pHeader_) ((PCHAR)((PDNS_HEADER)(_pHeader_) + 1))
#define DNS_ANSWER_FROM_QUESTION(_pQuestion_) ((PCHAR)((PDNS_QUESTION)(_pQuestion_) + 1))

  typedef struct _DNS_WIRE_QUESTION {
    WORD QuestionType;
    WORD QuestionClass;
  } DNS_WIRE_QUESTION,*PDNS_WIRE_QUESTION;

  typedef struct _DNS_WIRE_RECORD {
    WORD RecordType;
    WORD RecordClass;
    DWORD TimeToLive;
    WORD DataLength;
  } DNS_WIRE_RECORD,*PDNS_WIRE_RECORD;

#pragma pack()

#define DNS_OPCODE_QUERY 0
#define DNS_OPCODE_IQUERY 1
#define DNS_OPCODE_SERVER_STATUS 2
#define DNS_OPCODE_UNKNOWN 3
#define DNS_OPCODE_NOTIFY 4
#define DNS_OPCODE_UPDATE 5

#define DNS_RCODE_NOERROR 0
#define DNS_RCODE_FORMERR 1
#define DNS_RCODE_SERVFAIL 2
#define DNS_RCODE_NXDOMAIN 3
#define DNS_RCODE_NOTIMPL 4
#define DNS_RCODE_REFUSED 5
#define DNS_RCODE_YXDOMAIN 6
#define DNS_RCODE_YXRRSET 7
#define DNS_RCODE_NXRRSET 8
#define DNS_RCODE_NOTAUTH 9
#define DNS_RCODE_NOTZONE 10
#define DNS_RCODE_MAX 15
#define DNS_RCODE_BADVERS 16
#define DNS_RCODE_BADSIG 16
#define DNS_RCODE_BADKEY 17
#define DNS_RCODE_BADTIME 18
#define DNS_RCODE_NO_ERROR DNS_RCODE_NOERROR
#define DNS_RCODE_FORMAT_ERROR DNS_RCODE_FORMERR
#define DNS_RCODE_SERVER_FAILURE DNS_RCODE_SERVFAIL
#define DNS_RCODE_NAME_ERROR DNS_RCODE_NXDOMAIN
#define DNS_RCODE_NOT_IMPLEMENTED DNS_RCODE_NOTIMPL

#define DNS_CLASS_INTERNET 0x0001
#define DNS_CLASS_CSNET 0x0002
#define DNS_CLASS_CHAOS 0x0003
#define DNS_CLASS_HESIOD 0x0004
#define DNS_CLASS_NONE 0x00fe
#define DNS_CLASS_ALL 0x00ff
#define DNS_CLASS_ANY 0x00ff
#define DNS_CLASS_UNICAST_RESPONSE 0x8000

#define DNS_RCLASS_INTERNET 0x0100
#define DNS_RCLASS_CSNET 0x0200
#define DNS_RCLASS_CHAOS 0x0300
#define DNS_RCLASS_HESIOD 0x0400
#define DNS_RCLASS_NONE 0xfe00
#define DNS_RCLASS_ALL 0xff00
#define DNS_RCLASS_ANY 0xff00
#define DNS_RCLASS_UNICAST_RESPONSE 0x0080

#define DNS_TYPE_ZERO 0x0000
#define DNS_TYPE_A 0x0001
#define DNS_TYPE_NS 0x0002
#define DNS_TYPE_MD 0x0003
#define DNS_TYPE_MF 0x0004
#define DNS_TYPE_CNAME 0x0005
#define DNS_TYPE_SOA 0x0006
#define DNS_TYPE_MB 0x0007
#define DNS_TYPE_MG 0x0008
#define DNS_TYPE_MR 0x0009
#define DNS_TYPE_NULL 0x000a
#define DNS_TYPE_WKS 0x000b
#define DNS_TYPE_PTR 0x000c
#define DNS_TYPE_HINFO 0x000d
#define DNS_TYPE_MINFO 0x000e
#define DNS_TYPE_MX 0x000f
#define DNS_TYPE_TEXT 0x0010
#define DNS_TYPE_RP 0x0011
#define DNS_TYPE_AFSDB 0x0012
#define DNS_TYPE_X25 0x0013
#define DNS_TYPE_ISDN 0x0014
#define DNS_TYPE_RT 0x0015
#define DNS_TYPE_NSAP 0x0016
#define DNS_TYPE_NSAPPTR 0x0017
#define DNS_TYPE_SIG 0x0018
#define DNS_TYPE_KEY 0x0019
#define DNS_TYPE_PX 0x001a
#define DNS_TYPE_GPOS 0x001b
#define DNS_TYPE_AAAA 0x001c
#define DNS_TYPE_LOC 0x001d
#define DNS_TYPE_NXT 0x001e
#define DNS_TYPE_EID 0x001f
#define DNS_TYPE_NIMLOC 0x0020
#define DNS_TYPE_SRV 0x0021
#define DNS_TYPE_ATMA 0x0022
#define DNS_TYPE_NAPTR 0x0023
#define DNS_TYPE_KX 0x0024
#define DNS_TYPE_CERT 0x0025
#define DNS_TYPE_A6 0x0026
#define DNS_TYPE_DNAME 0x0027
#define DNS_TYPE_SINK 0x0028
#define DNS_TYPE_OPT 0x0029
#define DNS_TYPE_DS 0x002b
#define DNS_TYPE_RRSIG 0x002e
#define DNS_TYPE_NSEC 0x002f
#define DNS_TYPE_DNSKEY 0x0030
#define DNS_TYPE_DHCID 0x0031
#define DNS_TYPE_NSEC3 0x0032
#define DNS_TYPE_NSEC3PARAM 0x0033
#define DNS_TYPE_TLSA 0x0034
#define DNS_TYPE_UINFO 0x0064
#define DNS_TYPE_UID 0x0065
#define DNS_TYPE_GID 0x0066
#define DNS_TYPE_UNSPEC 0x0067
#define DNS_TYPE_ADDRS 0x00f8
#define DNS_TYPE_TKEY 0x00f9
#define DNS_TYPE_TSIG 0x00fa
#define DNS_TYPE_IXFR 0x00fb
#define DNS_TYPE_AXFR 0x00fc
#define DNS_TYPE_MAILB 0x00fd
#define DNS_TYPE_MAILA 0x00fe
#define DNS_TYPE_ALL 0x00ff
#define DNS_TYPE_ANY 0x00ff
#define DNS_TYPE_WINS 0xff01
#define DNS_TYPE_WINSR 0xff02
#define DNS_TYPE_NBSTAT (DNS_TYPE_WINSR)

#define DNS_RTYPE_A 0x0100
#define DNS_RTYPE_NS 0x0200
#define DNS_RTYPE_MD 0x0300
#define DNS_RTYPE_MF 0x0400
#define DNS_RTYPE_CNAME 0x0500
#define DNS_RTYPE_SOA 0x0600
#define DNS_RTYPE_MB 0x0700
#define DNS_RTYPE_MG 0x0800
#define DNS_RTYPE_MR 0x0900
#define DNS_RTYPE_NULL 0x0a00
#define DNS_RTYPE_WKS 0x0b00
#define DNS_RTYPE_PTR 0x0c00
#define DNS_RTYPE_HINFO 0x0d00
#define DNS_RTYPE_MINFO 0x0e00
#define DNS_RTYPE_MX 0x0f00
#define DNS_RTYPE_TEXT 0x1000
#define DNS_RTYPE_RP 0x1100
#define DNS_RTYPE_AFSDB 0x1200
#define DNS_RTYPE_X25 0x1300
#define DNS_RTYPE_ISDN 0x1400
#define DNS_RTYPE_RT 0x1500
#define DNS_RTYPE_NSAP 0x1600
#define DNS_RTYPE_NSAPPTR 0x1700
#define DNS_RTYPE_SIG 0x1800
#define DNS_RTYPE_KEY 0x1900
#define DNS_RTYPE_PX 0x1a00
#define DNS_RTYPE_GPOS 0x1b00
#define DNS_RTYPE_AAAA 0x1c00
#define DNS_RTYPE_LOC 0x1d00
#define DNS_RTYPE_NXT 0x1e00
#define DNS_RTYPE_EID 0x1f00
#define DNS_RTYPE_NIMLOC 0x2000
#define DNS_RTYPE_SRV 0x2100
#define DNS_RTYPE_ATMA 0x2200
#define DNS_RTYPE_NAPTR 0x2300
#define DNS_RTYPE_KX 0x2400
#define DNS_RTYPE_CERT 0x2500
#define DNS_RTYPE_A6 0x2600
#define DNS_RTYPE_DNAME 0x2700
#define DNS_RTYPE_SINK 0x2800
#define DNS_RTYPE_OPT 0x2900
#define DNS_RTYPE_DS 0x2b00
#define DNS_RTYPE_RRSIG 0x2e00
#define DNS_RTYPE_NSEC 0x2f00
#define DNS_RTYPE_DNSKEY 0x3000
#define DNS_RTYPE_DHCID 0x3100
#define DNS_RTYPE_NSEC3 0x3200
#define DNS_RTYPE_NSEC3PARAM 0x3300
#define DNS_RTYPE_TLSA 0x3400
#define DNS_RTYPE_UINFO 0x6400
#define DNS_RTYPE_UID 0x6500
#define DNS_RTYPE_GID 0x6600
#define DNS_RTYPE_UNSPEC 0x6700
#define DNS_RTYPE_TKEY 0xf900
#define DNS_RTYPE_TSIG 0xfa00
#define DNS_RTYPE_IXFR 0xfb00
#define DNS_RTYPE_AXFR 0xfc00
#define DNS_RTYPE_MAILB 0xfd00
#define DNS_RTYPE_MAILA 0xfe00
#define DNS_RTYPE_ALL 0xff00
#define DNS_RTYPE_ANY 0xff00
#define DNS_RTYPE_WINS 0x01ff
#define DNS_RTYPE_WINSR 0x02ff

#ifndef ATMA_E164
#define DNS_ATMA_FORMAT_E164 1
#define DNS_ATMA_FORMAT_AESA 2
#define DNS_ATMA_MAX_ADDR_LENGTH (20)
#else
#define DNS_ATMA_FORMAT_E164 ATM_E164
#define DNS_ATMA_FORMAT_AESA ATM_AESA
#define DNS_ATMA_MAX_ADDR_LENGTH ATM_ADDR_SIZE
#endif

#define DNS_ATMA_AESA_ADDR_LENGTH (20)
#define DNS_ATMA_MAX_RECORD_LENGTH (DNS_ATMA_MAX_ADDR_LENGTH+1)

#define DNSSEC_ALGORITHM_RSAMD5 1
#define DNSSEC_ALGORITHM_RSASHA1 5
#define DNSSEC_ALGORITHM_RSASHA1_NSEC3 7
#define DNSSEC_ALGORITHM_RSASHA256 8
#define DNSSEC_ALGORITHM_RSASHA512 10
#define DNSSEC_ALGORITHM_ECDSAP256_SHA256 13
#define DNSSEC_ALGORITHM_ECDSAP384_SHA384 14
#define DNSSEC_ALGORITHM_NULL 253
#define DNSSEC_ALGORITHM_PRIVATE 254

#define DNSSEC_DIGEST_ALGORITHM_SHA1 1
#define DNSSEC_DIGEST_ALGORITHM_SHA256 2
#define DNSSEC_DIGEST_ALGORITHM_SHA384 4

#define DNSSEC_PROTOCOL_NONE 0
#define DNSSEC_PROTOCOL_TLS 1
#define DNSSEC_PROTOCOL_EMAIL 2
#define DNSSEC_PROTOCOL_DNSSEC 3
#define DNSSEC_PROTOCOL_IPSEC 4

#define DNSSEC_KEY_FLAG_NOAUTH 0x0001
#define DNSSEC_KEY_FLAG_NOCONF 0x0002
#define DNSSEC_KEY_FLAG_FLAG2 0x0004
#define DNSSEC_KEY_FLAG_EXTEND 0x0008
#define DNSSEC_KEY_FLAG_
#define DNSSEC_KEY_FLAG_FLAG4 0x0010
#define DNSSEC_KEY_FLAG_FLAG5 0x0020

#define DNSSEC_KEY_FLAG_USER 0x0000
#define DNSSEC_KEY_FLAG_ZONE 0x0040
#define DNSSEC_KEY_FLAG_HOST 0x0080
#define DNSSEC_KEY_FLAG_NTPE3 0x00c0

#define DNSSEC_KEY_FLAG_FLAG8 0x0100
#define DNSSEC_KEY_FLAG_FLAG9 0x0200
#define DNSSEC_KEY_FLAG_FLAG10 0x0400
#define DNSSEC_KEY_FLAG_FLAG11 0x0800

#define DNSSEC_KEY_FLAG_SIG0 0x0000
#define DNSSEC_KEY_FLAG_SIG1 0x1000
#define DNSSEC_KEY_FLAG_SIG2 0x2000
#define DNSSEC_KEY_FLAG_SIG3 0x3000
#define DNSSEC_KEY_FLAG_SIG4 0x4000
#define DNSSEC_KEY_FLAG_SIG5 0x5000
#define DNSSEC_KEY_FLAG_SIG6 0x6000
#define DNSSEC_KEY_FLAG_SIG7 0x7000
#define DNSSEC_KEY_FLAG_SIG8 0x8000
#define DNSSEC_KEY_FLAG_SIG9 0x9000
#define DNSSEC_KEY_FLAG_SIG10 0xa000
#define DNSSEC_KEY_FLAG_SIG11 0xb000
#define DNSSEC_KEY_FLAG_SIG12 0xc000
#define DNSSEC_KEY_FLAG_SIG13 0xd000
#define DNSSEC_KEY_FLAG_SIG14 0xe000
#define DNSSEC_KEY_FLAG_SIG15 0xf000

#define DNS_TKEY_MODE_SERVER_ASSIGN 1
#define DNS_TKEY_MODE_DIFFIE_HELLMAN 2
#define DNS_TKEY_MODE_GSS 3
#define DNS_TKEY_MODE_RESOLVER_ASSIGN 4

#define DNS_WINS_FLAG_SCOPE (0x80000000)
#define DNS_WINS_FLAG_LOCAL (0x00010000)

#define IS_WORD_ALIGNED(p) (!((UINT_PTR)(p) & (UINT_PTR)1))
#define IS_DWORD_ALIGNED(p) (!((UINT_PTR)(p) & (UINT_PTR)3))
#define IS_QWORD_ALIGNED(p) (!((UINT_PTR)(p) & (UINT_PTR)7))

  typedef enum {
    DnsConfigPrimaryDomainName_W,
    DnsConfigPrimaryDomainName_A,
    DnsConfigPrimaryDomainName_UTF8,
    DnsConfigAdapterDomainName_W,
    DnsConfigAdapterDomainName_A,
    DnsConfigAdapterDomainName_UTF8,
    DnsConfigDnsServerList,
    DnsConfigSearchList,
    DnsConfigAdapterInfo,
    DnsConfigPrimaryHostNameRegistrationEnabled,
    DnsConfigAdapterHostNameRegistrationEnabled,
    DnsConfigAddressRegistrationMaxCount,
    DnsConfigHostName_W,
    DnsConfigHostName_A,
    DnsConfigHostName_UTF8,
    DnsConfigFullHostName_W,
    DnsConfigFullHostName_A,
    DnsConfigFullHostName_UTF8,
    DnsConfigNameServer
  } DNS_CONFIG_TYPE;

#define DNS_CONFIG_FLAG_ALLOC (0x00000001)

  DNS_STATUS WINAPI DnsQueryConfig(DNS_CONFIG_TYPE Config,DWORD Flag,PWSTR pwsAdapterName,PVOID pReserved,PVOID pBuffer,PDWORD pBufferLength);

  typedef struct {
    IP4_ADDRESS IpAddress;
  } DNS_A_DATA,*PDNS_A_DATA;

  typedef struct {
    PWSTR pNameHost;
  } DNS_PTR_DATAW,*PDNS_PTR_DATAW;

  typedef struct {
    PSTR pNameHost;
  } DNS_PTR_DATAA,*PDNS_PTR_DATAA;

  typedef struct {
    PWSTR pNamePrimaryServer;
    PWSTR pNameAdministrator;
    DWORD dwSerialNo;
    DWORD dwRefresh;
    DWORD dwRetry;
    DWORD dwExpire;
    DWORD dwDefaultTtl;
  } DNS_SOA_DATAW,*PDNS_SOA_DATAW;

  typedef struct {
    PSTR pNamePrimaryServer;
    PSTR pNameAdministrator;
    DWORD dwSerialNo;
    DWORD dwRefresh;
    DWORD dwRetry;
    DWORD dwExpire;
    DWORD dwDefaultTtl;
  } DNS_SOA_DATAA,*PDNS_SOA_DATAA;

  typedef struct {
    PWSTR pNameMailbox;
    PWSTR pNameErrorsMailbox;
  } DNS_MINFO_DATAW,*PDNS_MINFO_DATAW;

  typedef struct {
    PSTR pNameMailbox;
    PSTR pNameErrorsMailbox;
  } DNS_MINFO_DATAA,*PDNS_MINFO_DATAA;

  typedef struct {
    PWSTR pNameExchange;
    WORD wPreference;
    WORD Pad;
  } DNS_MX_DATAW,*PDNS_MX_DATAW;

  typedef struct {
    PSTR pNameExchange;
    WORD wPreference;
    WORD Pad;
  } DNS_MX_DATAA,*PDNS_MX_DATAA;

  typedef struct {
    DWORD dwStringCount;
    PWSTR pStringArray[1];
  } DNS_TXT_DATAW,*PDNS_TXT_DATAW;

  typedef struct {
    DWORD dwStringCount;
    PSTR pStringArray[1];
  } DNS_TXT_DATAA,*PDNS_TXT_DATAA;

  typedef struct {
    DWORD dwByteCount;
    BYTE Data[1];
  } DNS_NULL_DATA,*PDNS_NULL_DATA;

  typedef struct {
    IP4_ADDRESS IpAddress;
    UCHAR chProtocol;
    BYTE BitMask[1];
  } DNS_WKS_DATA,*PDNS_WKS_DATA;

  typedef struct {
    IP6_ADDRESS Ip6Address;
  } DNS_AAAA_DATA,*PDNS_AAAA_DATA;

  typedef struct {
    WORD wTypeCovered;
    BYTE chAlgorithm;
    BYTE chLabelCount;
    DWORD dwOriginalTtl;
    DWORD dwExpiration;
    DWORD dwTimeSigned;
    WORD wKeyTag;
    WORD wSignatureLength;
    PWSTR pNameSigner;
    BYTE Signature[1];
  } DNS_SIG_DATAW, *PDNS_SIG_DATAW, DNS_RRSIG_DATAW, *PDNS_RRSIG_DATAW;

  typedef struct {
    WORD wTypeCovered;
    BYTE chAlgorithm;
    BYTE chLabelCount;
    DWORD dwOriginalTtl;
    DWORD dwExpiration;
    DWORD dwTimeSigned;
    WORD wKeyTag;
    WORD wSignatureLength;
    PSTR pNameSigner;
    BYTE Signature[1];
  } DNS_SIG_DATAA, *PDNS_SIG_DATAA, DNS_RRSIG_DATAA, *PDNS_RRSIG_DATAA;

  typedef struct {
    WORD wFlags;
    BYTE chProtocol;
    BYTE chAlgorithm;
    WORD wKeyLength;
    WORD wPad;
    BYTE Key[1];
  } DNS_KEY_DATA, *PDNS_KEY_DATA, DNS_DNSKEY_DATA, *PDNS_DNSKEY_DATA;

  typedef struct {
    DWORD dwByteCount;
    BYTE DHCID[1];
  } DNS_DHCID_DATA, *PDNS_DHCID_DATA;

  typedef struct {
    PWSTR pNextDomainName;
    WORD wTypeBitMapsLength;
    WORD wPad;
    BYTE TypeBitMaps[1];
  } DNS_NSEC_DATAW, *PDNS_NSEC_DATAW;

  typedef struct {
    PSTR pNextDomainName;
    WORD wTypeBitMapsLength;
    WORD wPad;
    BYTE TypeBitMaps[1];
  } DNS_NSEC_DATAA, *PDNS_NSEC_DATAA;

  typedef struct {
    BYTE chAlgorithm;
    BYTE bFlags;
    WORD wIterations;
    BYTE bSaltLength;
    BYTE bHashLength;
    WORD wTypeBitMapsLength;
    BYTE chData[1];
  } DNS_NSEC3_DATA, *PDNS_NSEC3_DATA;

  typedef struct {
    BYTE chAlgorithm;
    BYTE bFlags;
    WORD wIterations;
    BYTE bSaltLength;
    BYTE bPad[3];
    BYTE pbSalt[1];
  } DNS_NSEC3PARAM_DATA, *PDNS_NSEC3PARAM_DATA;

  typedef struct {
    BYTE bCertUsage;
    BYTE bSelector;
    BYTE bMatchingType;
    WORD bCertificateAssociationDataLength;
    BYTE bPad[3];
    BYTE bCertificateAssociationData[1];
  } DNS_TLSA_DATA, *PDNS_TLSA_DATA;

  typedef struct {
    WORD wKeyTag;
    BYTE chAlgorithm;
    BYTE chDigestType;
    WORD wDigestLength;
    WORD wPad;
    BYTE Digest[1];
  } DNS_DS_DATA, *PDNS_DS_DATA;

  typedef struct {
    WORD wDataLength;
    WORD wPad;
    BYTE Data[1];
  } DNS_OPT_DATA, *PDNS_OPT_DATA;

  typedef struct {
    WORD wVersion;
    WORD wSize;
    WORD wHorPrec;
    WORD wVerPrec;
    DWORD dwLatitude;
    DWORD dwLongitude;
    DWORD dwAltitude;
  } DNS_LOC_DATA,*PDNS_LOC_DATA;

  typedef struct {
    PWSTR pNameNext;
    WORD wNumTypes;
    WORD wTypes[1];
  } DNS_NXT_DATAW,*PDNS_NXT_DATAW;

  typedef struct {
    PSTR pNameNext;
    WORD wNumTypes;
    WORD wTypes[1];
  } DNS_NXT_DATAA,*PDNS_NXT_DATAA;

  typedef struct {
    PWSTR pNameTarget;
    WORD wPriority;
    WORD wWeight;
    WORD wPort;
    WORD Pad;
  } DNS_SRV_DATAW,*PDNS_SRV_DATAW;

  typedef struct {
    PSTR pNameTarget;
    WORD wPriority;
    WORD wWeight;
    WORD wPort;
    WORD Pad;
  } DNS_SRV_DATAA,*PDNS_SRV_DATAA;

  typedef struct {
    WORD wOrder;
    WORD wPreference;
    PWSTR pFlags;
    PWSTR pService;
    PWSTR pRegularExpression;
    PWSTR pReplacement;
  } DNS_NAPTR_DATAW, *PDNS_NAPTR_DATAW;

  typedef struct {
    WORD wOrder;
    WORD wPreference;
    PSTR pFlags;
    PSTR pService;
    PSTR pRegularExpression;
    PSTR pReplacement;
  } DNS_NAPTR_DATAA, *PDNS_NAPTR_DATAA;

  typedef struct {
    BYTE AddressType;
    BYTE Address[DNS_ATMA_MAX_ADDR_LENGTH ];
  } DNS_ATMA_DATA,*PDNS_ATMA_DATA;

  typedef struct {
    PWSTR pNameAlgorithm;
    PBYTE pAlgorithmPacket;
    PBYTE pKey;
    PBYTE pOtherData;
    DWORD dwCreateTime;
    DWORD dwExpireTime;
    WORD wMode;
    WORD wError;
    WORD wKeyLength;
    WORD wOtherLength;
    UCHAR cAlgNameLength;
    WINBOOL bPacketPointers;
  } DNS_TKEY_DATAW,*PDNS_TKEY_DATAW;

  typedef struct {
    PSTR pNameAlgorithm;
    PBYTE pAlgorithmPacket;
    PBYTE pKey;
    PBYTE pOtherData;
    DWORD dwCreateTime;
    DWORD dwExpireTime;
    WORD wMode;
    WORD wError;
    WORD wKeyLength;
    WORD wOtherLength;
    UCHAR cAlgNameLength;
    WINBOOL bPacketPointers;
  } DNS_TKEY_DATAA,*PDNS_TKEY_DATAA;

  typedef struct {
    PWSTR pNameAlgorithm;
    PBYTE pAlgorithmPacket;
    PBYTE pSignature;
    PBYTE pOtherData;
    LONGLONG i64CreateTime;
    WORD wFudgeTime;
    WORD wOriginalXid;
    WORD wError;
    WORD wSigLength;
    WORD wOtherLength;
    UCHAR cAlgNameLength;
    WINBOOL bPacketPointers;
  } DNS_TSIG_DATAW,*PDNS_TSIG_DATAW;

  typedef struct {
    PSTR pNameAlgorithm;
    PBYTE pAlgorithmPacket;
    PBYTE pSignature;
    PBYTE pOtherData;
    LONGLONG i64CreateTime;
    WORD wFudgeTime;
    WORD wOriginalXid;
    WORD wError;
    WORD wSigLength;
    WORD wOtherLength;
    UCHAR cAlgNameLength;
    WINBOOL bPacketPointers;
  } DNS_TSIG_DATAA,*PDNS_TSIG_DATAA;

  typedef struct {
    DWORD dwByteCount;
    BYTE bData[1];
  } DNS_UNKNOWN_DATA, *PDNS_UNKNOWN_DATA;

  typedef struct {
    DWORD dwMappingFlag;
    DWORD dwLookupTimeout;
    DWORD dwCacheTimeout;
    DWORD cWinsServerCount;
    IP4_ADDRESS WinsServers[1];
  } DNS_WINS_DATA,*PDNS_WINS_DATA;

  typedef struct {
    DWORD dwMappingFlag;
    DWORD dwLookupTimeout;
    DWORD dwCacheTimeout;
    PWSTR pNameResultDomain;
  } DNS_WINSR_DATAW,*PDNS_WINSR_DATAW;

  typedef struct {
    DWORD dwMappingFlag;
    DWORD dwLookupTimeout;
    DWORD dwCacheTimeout;
    PSTR pNameResultDomain;
  } DNS_WINSR_DATAA,*PDNS_WINSR_DATAA;

  __MINGW_TYPEDEF_AW(DNS_PTR_DATA)
  __MINGW_TYPEDEF_AW(PDNS_PTR_DATA)
  __MINGW_TYPEDEF_AW(DNS_SOA_DATA)
  __MINGW_TYPEDEF_AW(PDNS_SOA_DATA)
  __MINGW_TYPEDEF_AW(DNS_MINFO_DATA)
  __MINGW_TYPEDEF_AW(PDNS_MINFO_DATA)
  __MINGW_TYPEDEF_AW(DNS_MX_DATA)
  __MINGW_TYPEDEF_AW(PDNS_MX_DATA)
  __MINGW_TYPEDEF_AW(DNS_TXT_DATA)
  __MINGW_TYPEDEF_AW(PDNS_TXT_DATA)
  __MINGW_TYPEDEF_AW(DNS_SIG_DATA)
  __MINGW_TYPEDEF_AW(PDNS_SIG_DATA)
  __MINGW_TYPEDEF_AW(DNS_NXT_DATA)
  __MINGW_TYPEDEF_AW(PDNS_NXT_DATA)
  __MINGW_TYPEDEF_AW(DNS_SRV_DATA)
  __MINGW_TYPEDEF_AW(PDNS_SRV_DATA)
  __MINGW_TYPEDEF_AW(DNS_NAPTR_DATA)
  __MINGW_TYPEDEF_AW(PDNS_NAPTR_DATA)
  __MINGW_TYPEDEF_AW(DNS_RRSIG_DATA)
  __MINGW_TYPEDEF_AW(PDNS_RRSIG_DATA)
  __MINGW_TYPEDEF_AW(DNS_NSEC_DATA)
  __MINGW_TYPEDEF_AW(PDNS_NSEC_DATA)
  __MINGW_TYPEDEF_AW(DNS_TKEY_DATA)
  __MINGW_TYPEDEF_AW(PDNS_TKEY_DATA)
  __MINGW_TYPEDEF_AW(DNS_TSIG_DATA)
  __MINGW_TYPEDEF_AW(PDNS_TSIG_DATA)
  __MINGW_TYPEDEF_AW(DNS_WINSR_DATA)
  __MINGW_TYPEDEF_AW(PDNS_WINSR_DATA)

#define DNS_TEXT_RECORD_LENGTH(StringCount) (FIELD_OFFSET(DNS_TXT_DATA,pStringArray) + ((StringCount) *sizeof(PCHAR)))
#define DNS_NULL_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_NULL_DATA,Data) + (ByteCount))
#define DNS_WKS_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_WKS_DATA,BitMask) + (ByteCount))
#define DNS_WINS_RECORD_LENGTH(IpCount) (FIELD_OFFSET(DNS_WINS_DATA,WinsServers) + ((IpCount) *sizeof(IP4_ADDRESS)))
#define DNS_KEY_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_KEY_DATA,Key) + (ByteCount))
#define DNS_SIG_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_SIG_DATA,Signature) + (ByteCount))
#define DNS_NSEC_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_NSEC_DATA,TypeBitMaps) + (ByteCount))
#define DNS_DS_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_DS_DATA,Digest) + (ByteCount))
#define DNS_OPT_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_OPT_DATA,Data) + (ByteCount))
#define DNS_DHCID_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_DHCID_DATA,DHCID) + (ByteCount))
#define DNS_NSEC3_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_NSEC3_DATA,chData) + (ByteCount))
#define DNS_NSEC3PARAM_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_NSEC3PARAM_DATA,pbSalt) + (ByteCount))
#define DNS_TLSA_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_TLSA_DATA,bCertificateAssociationData) + (ByteCount))
#define DNS_UNKNOWN_RECORD_LENGTH(ByteCount) (FIELD_OFFSET(DNS_UNKNOWN_DATA,bData) + (ByteCount))

  typedef struct _DnsRecordFlags {
    DWORD Section : 2;
    DWORD Delete : 1;
    DWORD CharSet : 2;
    DWORD Unused : 3;
    DWORD Reserved : 24;
  } DNS_RECORD_FLAGS;

  typedef enum _DnsSection {
    DnsSectionQuestion,DnsSectionAnswer,DnsSectionAuthority,DnsSectionAddtional
  } DNS_SECTION;

#define DnsSectionZone DnsSectionQuestion
#define DnsSectionPrereq DnsSectionAnswer
#define DnsSectionUpdate DnsSectionAuthority

#define DNSREC_SECTION (0x00000003)
#define DNSREC_QUESTION (0x00000000)
#define DNSREC_ANSWER (0x00000001)
#define DNSREC_AUTHORITY (0x00000002)
#define DNSREC_ADDITIONAL (0x00000003)

#define DNSREC_ZONE (0x00000000)
#define DNSREC_PREREQ (0x00000001)
#define DNSREC_UPDATE (0x00000002)

#define DNSREC_DELETE (0x00000004)
#define DNSREC_NOEXIST (0x00000004)

  typedef struct _DnsRecordW {
    struct _DnsRecordW *pNext;
    PWSTR pName;
    WORD wType;
    WORD wDataLength;
    union {
      DWORD DW;
      DNS_RECORD_FLAGS S;
    } Flags;
    DWORD dwTtl;
    DWORD dwReserved;
    union {
      DNS_A_DATA A;
      DNS_SOA_DATAW SOA,Soa;
      DNS_PTR_DATAW PTR,Ptr,NS,Ns,CNAME,Cname,DNAME,Dname,MB,Mb,MD,Md,MF,Mf,MG,Mg,MR,Mr;
      DNS_MINFO_DATAW MINFO,Minfo,RP,Rp;
      DNS_MX_DATAW MX,Mx,AFSDB,Afsdb,RT,Rt;
      DNS_TXT_DATAW HINFO,Hinfo,ISDN,Isdn,TXT,Txt,X25;
      DNS_NULL_DATA Null;
      DNS_WKS_DATA WKS,Wks;
      DNS_AAAA_DATA AAAA;
      DNS_KEY_DATA KEY,Key;
      DNS_SIG_DATAW SIG,Sig;
      DNS_ATMA_DATA ATMA,Atma;
      DNS_NXT_DATAW NXT,Nxt;
      DNS_SRV_DATAW SRV,Srv;
      DNS_NAPTR_DATAW NAPTR,Naptr;
      DNS_OPT_DATA OPT,Opt;
      DNS_DS_DATA DS,Ds;
      DNS_RRSIG_DATAW RRSIG,Rrsig;
      DNS_NSEC_DATAW NSEC,Nsec;
      DNS_DNSKEY_DATA DNSKEY,Dnskey;
      DNS_TKEY_DATAW TKEY,Tkey;
      DNS_TSIG_DATAW TSIG,Tsig;
      DNS_WINS_DATA WINS,Wins;
      DNS_WINSR_DATAW WINSR,WinsR,NBSTAT,Nbstat;
      DNS_DHCID_DATA DHCID;
      DNS_NSEC3_DATA NSEC3,Nsec3;
      DNS_NSEC3PARAM_DATA NSEC3PARAM,Nsec3Param;
      DNS_TLSA_DATA TLSA,Tlsa;
      DNS_UNKNOWN_DATA UNKNOWN,Unknown;
      PBYTE pDataPtr;
    } Data;
  } DNS_RECORDW,*PDNS_RECORDW;

  typedef struct _DnsRecordOptW {
    struct _DnsRecordW *pNext;
    PWSTR pName;
    WORD wType;
    WORD wDataLength;
    union {
      DWORD DW;
      DNS_RECORD_FLAGS S;
    } Flags;
    DNS_HEADER_EXT ExtHeader;
    WORD wPayloadSize;
    WORD wReserved;
    union {
      DNS_OPT_DATA OPT,Opt;
    } Data;
  } DNS_RECORD_OPTW, *PDNS_RECORD_OPTW;

  typedef struct _DnsRecordA {
    struct _DnsRecordA *pNext;
    PSTR pName;
    WORD wType;
    WORD wDataLength;
    union {
      DWORD DW;
      DNS_RECORD_FLAGS S;
    } Flags;
    DWORD dwTtl;
    DWORD dwReserved;
    union {
      DNS_A_DATA A;
      DNS_SOA_DATAA SOA,Soa;
      DNS_PTR_DATAA PTR,Ptr,NS,Ns,CNAME,Cname,DNAME,Dname,MB,Mb,MD,Md,MF,Mf,MG,Mg,MR,Mr;
      DNS_MINFO_DATAA MINFO,Minfo,RP,Rp;
      DNS_MX_DATAA MX,Mx,AFSDB,Afsdb,RT,Rt;
      DNS_TXT_DATAA HINFO,Hinfo,ISDN,Isdn,TXT,Txt,X25;
      DNS_NULL_DATA Null;
      DNS_WKS_DATA WKS,Wks;
      DNS_AAAA_DATA AAAA;
      DNS_KEY_DATA KEY,Key;
      DNS_SIG_DATAA SIG,Sig;
      DNS_ATMA_DATA ATMA,Atma;
      DNS_NXT_DATAA NXT,Nxt;
      DNS_SRV_DATAA SRV,Srv;
      DNS_NAPTR_DATAA NAPTR,Naptr;
      DNS_OPT_DATA OPT,Opt;
      DNS_DS_DATA DS,Ds;
      DNS_RRSIG_DATAA RRSIG,Rrsig;
      DNS_NSEC_DATAA NSEC,Nsec;
      DNS_DNSKEY_DATA DNSKEY,Dnskey;
      DNS_TKEY_DATAA TKEY,Tkey;
      DNS_TSIG_DATAA TSIG,Tsig;
      DNS_WINS_DATA WINS,Wins;
      DNS_WINSR_DATAA WINSR,WinsR,NBSTAT,Nbstat;
      DNS_DHCID_DATA DHCID;
      DNS_NSEC3_DATA NSEC3,Nsec3;
      DNS_NSEC3PARAM_DATA NSEC3PARAM,Nsec3Param;
      DNS_TLSA_DATA TLSA,Tlsa;
      DNS_UNKNOWN_DATA UNKNOWN,Unknown;
      PBYTE pDataPtr;
    } Data;
  } DNS_RECORDA,*PDNS_RECORDA;

  typedef struct _DnsRecordOptA {
    struct _DnsRecordA *pNext;
    PSTR pName;
    WORD wType;
    WORD wDataLength;
    union {
      DWORD DW;
      DNS_RECORD_FLAGS S;
    } Flags;
    DNS_HEADER_EXT ExtHeader;
    WORD wPayloadSize;
    WORD wReserved;
    union {
      DNS_OPT_DATA OPT, Opt;
    } Data;
  } DNS_RECORD_OPTA, *PDNS_RECORD_OPTA;

#ifdef UNICODE
  typedef DNS_RECORDW DNS_RECORD, *PDNS_RECORD;
  typedef DNS_RECORD_OPTW DNS_RECORD_OPT, *PDNS_RECORD_OPT;
#else
  typedef DNS_RECORDA DNS_RECORD, *PDNS_RECORD;
  typedef DNS_RECORD_OPTA DNS_RECORD_OPT, *PDNS_RECORD_OPT;
#endif

#define DNS_RECORD_FIXED_SIZE FIELD_OFFSET(DNS_RECORD,Data)
#define SIZEOF_DNS_RECORD_HEADER DNS_RECORD_FIXED_SIZE

  typedef struct _DnsRRSet {
    PDNS_RECORD pFirstRR;
    PDNS_RECORD pLastRR;
  } DNS_RRSET,*PDNS_RRSET;

#define DNS_RRSET_INIT(rrset) { PDNS_RRSET _prrset = &(rrset); _prrset->pFirstRR = NULL; _prrset->pLastRR = (PDNS_RECORD) &_prrset->pFirstRR; }
#define DNS_RRSET_ADD(rrset,pnewRR) { PDNS_RRSET _prrset = &(rrset); PDNS_RECORD _prrnew = (pnewRR); _prrset->pLastRR->pNext = _prrnew; _prrset->pLastRR = _prrnew; }
#define DNS_RRSET_TERMINATE(rrset) { PDNS_RRSET _prrset = &(rrset); _prrset->pLastRR->pNext = NULL; }

  typedef VOID (WINAPI *DNS_PROXY_COMPLETION_ROUTINE)(void *completionContext,DNS_STATUS status);

  typedef enum DNS_PROXY_INFORMATION_TYPE {
    DNS_PROXY_INFORMATION_DIRECT,
    DNS_PROXY_INFORMATION_DEFAULT_SETTINGS,
    DNS_PROXY_INFORMATION_PROXY_NAME,
    DNS_PROXY_INFORMATION_DOES_NOT_EXIST
  } DNS_PROXY_INFORMATION_TYPE;

  typedef struct DNS_PROXY_INFORMATION {
    ULONG version;
    DNS_PROXY_INFORMATION_TYPE proxyInformationType;
    PWSTR proxyName;
  } DNS_PROXY_INFORMATION;

  typedef enum _DNS_CHARSET {
    DnsCharSetUnknown,DnsCharSetUnicode,DnsCharSetUtf8,DnsCharSetAnsi
  } DNS_CHARSET;

  PDNS_RECORD WINAPI DnsRecordCopyEx(PDNS_RECORD pRecord,DNS_CHARSET CharSetIn,DNS_CHARSET CharSetOut);
  PDNS_RECORD WINAPI DnsRecordSetCopyEx(PDNS_RECORD pRecordSet,DNS_CHARSET CharSetIn,DNS_CHARSET CharSetOut);

#if defined(UNICODE)
#define DnsRecordCopy(pRR) DnsRecordCopyEx((pRR),DnsCharSetUnicode,DnsCharSetUnicode)
#define DnsRecordSetCopy(pRR) DnsRecordSetCopyEx((pRR),DnsCharSetUnicode,DnsCharSetUnicode)
#else
#define DnsRecordCopy(pRR) DnsRecordCopyEx((pRR),DnsCharSetAnsi,DnsCharSetAnsi)
#define DnsRecordSetCopy(pRR) DnsRecordSetCopyEx((pRR),DnsCharSetAnsi,DnsCharSetAnsi)
#endif

  WINBOOL WINAPI DnsRecordCompare(PDNS_RECORD pRecord1,PDNS_RECORD pRecord2);
  WINBOOL WINAPI DnsRecordSetCompare(PDNS_RECORD pRR1,PDNS_RECORD pRR2,PDNS_RECORD *ppDiff1,PDNS_RECORD *ppDiff2);
  PDNS_RECORD DnsRecordSetDetach(PDNS_RECORD pRecordList);

  typedef enum {
    DnsFreeFlat = 0,DnsFreeRecordList,DnsFreeParsedMessageFields
  } DNS_FREE_TYPE;

  VOID WINAPI DnsFree(PVOID pData,DNS_FREE_TYPE FreeType);

#define DnsFreeRecordListDeep DnsFreeRecordList

#if(_WIN32_WINNT >= 0x0501)
  #define DnsRecordListFree(p,t)  DnsFree(p,DnsFreeRecordList)
#else
  VOID WINAPI DnsRecordListFree(PDNS_RECORD pRecordList,DNS_FREE_TYPE FreeType);
#endif /* _WIN32_WINNT >= 0x0501 */

#define DNS_QUERY_STANDARD 0x00000000
#define DNS_QUERY_ACCEPT_TRUNCATED_RESPONSE 0x00000001
#define DNS_QUERY_USE_TCP_ONLY 0x00000002
#define DNS_QUERY_NO_RECURSION 0x00000004
#define DNS_QUERY_BYPASS_CACHE 0x00000008
#define DNS_QUERY_NO_WIRE_QUERY 0x00000010
#define DNS_QUERY_NO_LOCAL_NAME 0x00000020
#define DNS_QUERY_NO_HOSTS_FILE 0x00000040
#define DNS_QUERY_NO_NETBT 0x00000080
#define DNS_QUERY_WIRE_ONLY 0x00000100
#define DNS_QUERY_RETURN_MESSAGE 0x00000200
#define DNS_QUERY_MULTICAST_ONLY 0x00000400
#define DNS_QUERY_NO_MULTICAST 0x00000800
#define DNS_QUERY_TREAT_AS_FQDN 0x00001000
#define DNS_QUERY_APPEND_MULTILABEL 0x00800000
#define DNS_QUERY_ADDRCONFIG 0x00002000
#define DNS_QUERY_DUAL_ADDR 0x00004000
#define DNS_QUERY_DONT_RESET_TTL_VALUES 0x00100000
#define DNS_QUERY_DISABLE_IDN_ENCODING 0x00200000
#define DNS_QUERY_APPEND_MULTILABEL 0x00800000
#define DNS_QUERY_DNSSEC_OK 0x01000000
#define DNS_QUERY_DNSSEC_CHECKING_DISABLED 0x02000000
#define DNS_QUERY_RESERVED 0xf0000000
#define DNS_QUERY_CACHE_ONLY DNS_QUERY_NO_WIRE_QUERY

  DNS_STATUS WINAPI DnsQuery_A(PCSTR pszName,WORD wType,DWORD Options,PIP4_ARRAY aipServers,PDNS_RECORD *ppQueryResults,PVOID *pReserved);
  DNS_STATUS WINAPI DnsQuery_UTF8(PCSTR pszName,WORD wType,DWORD Options,PIP4_ARRAY aipServers,PDNS_RECORDA *ppQueryResults,PVOID *pReserved);
  DNS_STATUS WINAPI DnsQuery_W(PCWSTR pszName,WORD wType,DWORD Options,PIP4_ARRAY aipServers,PDNS_RECORD *ppQueryResults,PVOID *pReserved);

#define DnsQuery __MINGW_NAME_UAW(DnsQuery)

#if !defined (USE_PRIVATE_DNS_ADDR) || defined (MIDL_PASS) || defined (__WIDL__)
#define DNS_QUERY_REQUEST_VERSION1 0x1
#define DNS_QUERY_REQUEST_VERSION2 0x2
#endif

#define DNS_QUERY_RESULTS_VERSION1 0x1

  typedef struct _DNS_QUERY_RESULT {
    ULONG Version;
    DNS_STATUS QueryStatus;
    ULONG64 QueryOptions;
    PDNS_RECORD pQueryRecords;
    PVOID Reserved;
  } DNS_QUERY_RESULT, *PDNS_QUERY_RESULT;

  typedef VOID WINAPI DNS_QUERY_COMPLETION_ROUTINE(PVOID pQueryContext,PDNS_QUERY_RESULT pQueryResults);
  typedef DNS_QUERY_COMPLETION_ROUTINE *PDNS_QUERY_COMPLETION_ROUTINE;

#define DNS_UPDATE_SECURITY_USE_DEFAULT 0x00000000
#define DNS_UPDATE_SECURITY_OFF 0x00000010
#define DNS_UPDATE_SECURITY_ON 0x00000020
#define DNS_UPDATE_SECURITY_ONLY 0x00000100
#define DNS_UPDATE_CACHE_SECURITY_CONTEXT 0x00000200
#define DNS_UPDATE_TEST_USE_LOCAL_SYS_ACCT 0x00000400
#define DNS_UPDATE_FORCE_SECURITY_NEGO 0x00000800
#define DNS_UPDATE_TRY_ALL_MASTER_SERVERS 0x00001000
#define DNS_UPDATE_SKIP_NO_UPDATE_ADAPTERS 0x00002000
#define DNS_UPDATE_REMOTE_SERVER 0x00004000
#define DNS_UPDATE_RESERVED 0xffff0000

#define DnsAcquireContextHandle __MINGW_NAME_UAW(DnsAcquireContextHandle)
#define DnsModifyRecordsInSet __MINGW_NAME_UAW(DnsModifyRecordsInSet)
#define DnsReplaceRecordSet __MINGW_NAME_AW(DnsReplaceRecordSet)
#define DnsValidateName(p,f) __MINGW_NAME_UAW(DnsValidateName)((p),(f))
#define DnsNameCompare(n1,n2) __MINGW_NAME_UAW(DnsNameCompare)((n1),(n2))

  DNS_STATUS WINAPI DnsAcquireContextHandle_W(DWORD CredentialFlags,PVOID pCredentials,PHANDLE pContextHandle);
  DNS_STATUS WINAPI DnsAcquireContextHandle_A(DWORD CredentialFlags,PVOID pCredentials,PHANDLE pContextHandle);
  VOID WINAPI DnsReleaseContextHandle(HANDLE hContext);
  DNS_STATUS WINAPI DnsModifyRecordsInSet_W(PDNS_RECORD pAddRecords,PDNS_RECORD pDeleteRecords,DWORD Options,HANDLE hContext,PIP4_ARRAY pServerList,PVOID pReserved);
  DNS_STATUS WINAPI DnsModifyRecordsInSet_A(PDNS_RECORD pAddRecords,PDNS_RECORD pDeleteRecords,DWORD Options,HANDLE hContext,PIP4_ARRAY pServerList,PVOID pReserved);
  DNS_STATUS WINAPI DnsModifyRecordsInSet_UTF8(PDNS_RECORDA pAddRecords,PDNS_RECORDA pDeleteRecords,DWORD Options,HANDLE hContext,PIP4_ARRAY pServerList,PVOID pReserved);
  DNS_STATUS WINAPI DnsReplaceRecordSetW(PDNS_RECORD pNewSet,DWORD Options,HANDLE hContext,PIP4_ARRAY pServerList,PVOID pReserved);
  DNS_STATUS WINAPI DnsReplaceRecordSetA(PDNS_RECORD pNewSet,DWORD Options,HANDLE hContext,PIP4_ARRAY pServerList,PVOID pReserved);
  DNS_STATUS WINAPI DnsReplaceRecordSetUTF8(PDNS_RECORDA pNewSet,DWORD Options,HANDLE hContext,PIP4_ARRAY pServerList,PVOID pReserved);

  typedef enum _DNS_NAME_FORMAT {
    DnsNameDomain,
    DnsNameDomainLabel,
    DnsNameHostnameFull,
    DnsNameHostnameLabel,
    DnsNameWildcard,
    DnsNameSrvRecord,
    DnsNameValidateTld
  } DNS_NAME_FORMAT;

  DNS_STATUS DnsValidateName_UTF8(LPCSTR pszName,DNS_NAME_FORMAT Format);
  DNS_STATUS DnsValidateName_W(LPCWSTR pwszName,DNS_NAME_FORMAT Format);
  DNS_STATUS DnsValidateName_A(LPCSTR pszName,DNS_NAME_FORMAT Format);

#define DNS_VALSVR_ERROR_INVALID_ADDR 0x01
#define DNS_VALSVR_ERROR_INVALID_NAME 0x02
#define DNS_VALSVR_ERROR_UNREACHABLE 0x03
#define DNS_VALSVR_ERROR_NO_RESPONSE 0x04
#define DNS_VALSVR_ERROR_NO_AUTH 0x05
#define DNS_VALSVR_ERROR_REFUSED 0x06

#define DNS_VALSVR_ERROR_NO_TCP 0x10
#define DNS_VALSVR_ERROR_UNKNOWN 0xFF

#ifdef _WS2DEF_
  DNS_STATUS DnsValidateServerStatus(PSOCKADDR server,PCWSTR queryName,PDWORD serverStatus);
#endif

  WINBOOL WINAPI DnsNameCompare_A(LPSTR pName1,LPSTR pName2);
  WINBOOL WINAPI DnsNameCompare_W(LPWSTR pName1,LPWSTR pName2);

  typedef struct _DNS_MESSAGE_BUFFER {
    DNS_HEADER MessageHead;
    CHAR MessageBody[1];
  } DNS_MESSAGE_BUFFER,*PDNS_MESSAGE_BUFFER;

  WINBOOL WINAPI DnsWriteQuestionToBuffer_W(PDNS_MESSAGE_BUFFER pDnsBuffer,PDWORD pdwBufferSize,LPWSTR pszName,WORD wType,WORD Xid,WINBOOL fRecursionDesired);
  WINBOOL WINAPI DnsWriteQuestionToBuffer_UTF8(PDNS_MESSAGE_BUFFER pDnsBuffer,LPDWORD pdwBufferSize,LPSTR pszName,WORD wType,WORD Xid,WINBOOL fRecursionDesired);
  DNS_STATUS WINAPI DnsExtractRecordsFromMessage_W(PDNS_MESSAGE_BUFFER pDnsBuffer,WORD wMessageLength,PDNS_RECORD *ppRecord);
  DNS_STATUS WINAPI DnsExtractRecordsFromMessage_UTF8(PDNS_MESSAGE_BUFFER pDnsBuffer,WORD wMessageLength,PDNS_RECORDA *ppRecord);

  DWORD WINAPI DnsGetProxyInformation(PCWSTR hostName,DNS_PROXY_INFORMATION *proxyInformation,DNS_PROXY_INFORMATION *defaultProxyInformation,DNS_PROXY_COMPLETION_ROUTINE completionRoutine,void *completionContext);
  VOID WINAPI DnsFreeProxyName(PWSTR proxyName);

#define DNS_CONNECTION_NAME_MAX_LENGTH 64
#define DNS_CONNECTION_PROXY_INFO_CURRENT_VERSION 1
#define DNS_CONNECTION_PROXY_INFO_SERVER_MAX_LENGTH 256
#define DNS_CONNECTION_PROXY_INFO_FRIENDLY_NAME_MAX_LENGTH 64
#define DNS_CONNECTION_PROXY_INFO_USERNAME_MAX_LENGTH 128
#define DNS_CONNECTION_PROXY_INFO_PASSWORD_MAX_LENGTH 128
#define DNS_CONNECTION_PROXY_INFO_EXCEPTION_MAX_LENGTH 1024
#define DNS_CONNECTION_PROXY_INFO_EXTRA_INFO_MAX_LENGTH 1024

  typedef enum _DNS_CONNECTION_PROXY_TYPE {
    DNS_CONNECTION_PROXY_TYPE_NULL = 0,
    DNS_CONNECTION_PROXY_TYPE_HTTP = 1,
    DNS_CONNECTION_PROXY_TYPE_WAP = 2,
    DNS_CONNECTION_PROXY_TYPE_SOCKS4 = 4,
    DNS_CONNECTION_PROXY_TYPE_SOCKS5 = 5
  } DNS_CONNECTION_PROXY_TYPE;

  typedef enum _DNS_CONNECTION_PROXY_INFO_SWITCH {
    DNS_CONNECTION_PROXY_INFO_SWITCH_CONFIG = 0,
    DNS_CONNECTION_PROXY_INFO_SWITCH_SCRIPT,
    DNS_CONNECTION_PROXY_INFO_SWITCH_WPAD
  } DNS_CONNECTION_PROXY_INFO_SWITCH;

#define DNS_CONNECTION_PROXY_INFO_FLAG_DISABLED 0x1
#define DNS_CONNECTION_PROXY_INFO_FLAG_BYPASSLOCAL 0x2

  struct _DNS_CONNECTION_PROXY_INFO_CONFIG {
    WCHAR *pwszServer;
    WCHAR *pwszUsername;
    WCHAR *pwszPassword;
    WCHAR *pwszException;
    WCHAR *pwszExtraInfo;
    WORD Port;
  };

  struct _DNS_CONNECTION_PROXY_INFO_SCRIPT {
    WCHAR *pwszScript;
    WCHAR *pwszUsername;
    WCHAR *pwszPassword;
  };

  typedef struct _DNS_CONNECTION_PROXY_INFO {
    DWORD Version;
    WCHAR *pwszFriendlyName;
    DWORD Flags;
    DNS_CONNECTION_PROXY_INFO_SWITCH Switch;
    __C89_NAMELESS union {
      struct _DNS_CONNECTION_PROXY_INFO_CONFIG Config;
      struct _DNS_CONNECTION_PROXY_INFO_SCRIPT Script;
    };
  } DNS_CONNECTION_PROXY_INFO, *PDNS_CONNECTION_PROXY_INFO;

  typedef struct _DNS_CONNECTION_PROXY_INFO_EX {
    DNS_CONNECTION_PROXY_INFO ProxyInfo;
    DWORD dwInterfaceIndex;
    WCHAR *pwszConnectionName;
    WINBOOL fDirectConfiguration;
    HANDLE hConnection;
  } DNS_CONNECTION_PROXY_INFO_EX, *PDNS_CONNECTION_PROXY_INFO_EX;

  typedef struct _DNS_CONNECTION_PROXY_ELEMENT {
    DNS_CONNECTION_PROXY_TYPE Type;
    DNS_CONNECTION_PROXY_INFO Info;
  } DNS_CONNECTION_PROXY_ELEMENT;

  typedef struct _DNS_CONNECTION_PROXY_LIST {
    DWORD cProxies;
    DNS_CONNECTION_PROXY_ELEMENT *pProxies;
  } DNS_CONNECTION_PROXY_LIST;

  typedef struct _DNS_CONNECTION_NAME {
    WCHAR wszName[DNS_CONNECTION_NAME_MAX_LENGTH + 1];
  } DNS_CONNECTION_NAME;

  typedef struct _DNS_CONNECTION_NAME_LIST {
    DWORD cNames;
    DNS_CONNECTION_NAME *pNames;
  } DNS_CONNECTION_NAME_LIST;

  DWORD DnsConnectionGetProxyInfoForHostUrl(PCWSTR pwszHostUrl,BYTE *pSelectionContext,DWORD dwSelectionContextLength,DWORD dwExplicitInterfaceIndex,DNS_CONNECTION_PROXY_INFO_EX *pProxyInfoEx);
  VOID DnsConnectionFreeProxyInfoEx(DNS_CONNECTION_PROXY_INFO_EX *pProxyInfoEx);
  DWORD DnsConnectionGetProxyInfo(PCWSTR pwszConnectionName,DNS_CONNECTION_PROXY_TYPE Type,DNS_CONNECTION_PROXY_INFO *pProxyInfo);
  VOID DnsConnectionFreeProxyInfo(DNS_CONNECTION_PROXY_INFO *pProxyInfo);
  DWORD DnsConnectionSetProxyInfo(PCWSTR pwszConnectionName,DNS_CONNECTION_PROXY_TYPE Type,const DNS_CONNECTION_PROXY_INFO *pProxyInfo);
  DWORD DnsConnectionDeleteProxyInfo(PCWSTR pwszConnectionName,DNS_CONNECTION_PROXY_TYPE Type);
  DWORD DnsConnectionGetProxyList(PCWSTR pwszConnectionName,DNS_CONNECTION_PROXY_LIST *pProxyList);
  VOID DnsConnectionFreeProxyList(DNS_CONNECTION_PROXY_LIST *pProxyList);
  DWORD DnsConnectionGetNameList(DNS_CONNECTION_NAME_LIST *pNameList);
  VOID DnsConnectionFreeNameList(DNS_CONNECTION_NAME_LIST *pNameList);

  typedef struct _DNS_CONNECTION_IFINDEX_ENTRY {
    PCWSTR pwszConnectionName;
    DWORD dwIfIndex;
  } DNS_CONNECTION_IFINDEX_ENTRY;

  typedef struct _DNS_CONNECTION_IFINDEX_LIST {
    DNS_CONNECTION_IFINDEX_ENTRY *pConnectionIfIndexEntries;
    DWORD nEntries;
  } DNS_CONNECTION_IFINDEX_LIST;

  DWORD DnsConnectionUpdateIfIndexTable(DNS_CONNECTION_IFINDEX_LIST *pConnectionIfIndexEntries);

#define DNS_CONNECTION_POLICY_ENTRY_ONDEMAND 0x00000001

  typedef struct _DNS_CONNECTION_POLICY_ENTRY {
    PCWSTR pwszHost;
    PCWSTR pwszAppId;
    DWORD cbAppSid;
    PBYTE pbAppSid;
    DWORD nConnections;
    PCWSTR *ppwszConnections;
    DWORD dwPolicyEntryFlags;
  } DNS_CONNECTION_POLICY_ENTRY, *PDNS_CONNECTION_POLICY_ENTRY;

  typedef struct _DNS_CONNECTION_POLICY_ENTRY_LIST {
    DNS_CONNECTION_POLICY_ENTRY *pPolicyEntries;
    DWORD nEntries;
  } DNS_CONNECTION_POLICY_ENTRY_LIST;

  typedef enum {
    TAG_DNS_CONNECTION_POLICY_TAG_DEFAULT = 0,
    TAG_DNS_CONNECTION_POLICY_TAG_CONNECTION_MANAGER,
    TAG_DNS_CONNECTION_POLICY_TAG_WWWPT
  } DNS_CONNECTION_POLICY_TAG;

  DWORD DnsConnectionSetPolicyEntries(DNS_CONNECTION_POLICY_TAG PolicyEntryTag,DNS_CONNECTION_POLICY_ENTRY_LIST *pPolicyEntryList);
  DWORD DnsConnectionDeletePolicyEntries(DNS_CONNECTION_POLICY_TAG PolicyEntryTag);

  typedef struct _DNS_SERVICE_INSTANCE {
    LPWSTR pszInstanceName;
    LPWSTR pszHostName;
    IP4_ADDRESS *ip4Address;
    IP6_ADDRESS *ip6Address;
    WORD wPort;
    WORD wPriority;
    WORD wWeight;
    DWORD dwPropertyCount;
    PWSTR *keys;
    PWSTR *values;
    DWORD dwInterfaceIndex;
  } DNS_SERVICE_INSTANCE, *PDNS_SERVICE_INSTANCE;

  PDNS_SERVICE_INSTANCE WINAPI DnsServiceConstructInstance(PCWSTR pServiceName,PCWSTR pHostName,PIP4_ADDRESS pIp4,PIP6_ADDRESS pIp6,WORD wPort,WORD wPriority,WORD wWeight,DWORD dwPropertiesCount,PCWSTR *keys,PCWSTR *values);
  PDNS_SERVICE_INSTANCE WINAPI DnsServiceCopyInstance(PDNS_SERVICE_INSTANCE pOrig);
  VOID WINAPI DnsServiceFreeInstance(PDNS_SERVICE_INSTANCE pInstance);

  typedef struct _DNS_SERVICE_CANCEL {
    PVOID reserved;
  } DNS_SERVICE_CANCEL, *PDNS_SERVICE_CANCEL;

  typedef VOID WINAPI DNS_SERVICE_BROWSE_CALLBACK(DWORD Status,PVOID pQueryContext,PDNS_RECORD pDnsRecord);
  typedef DNS_SERVICE_BROWSE_CALLBACK *PDNS_SERVICE_BROWSE_CALLBACK;

  typedef struct _DNS_SERVICE_BROWSE_REQUEST {
    ULONG Version;
    ULONG InterfaceIndex;
    PCWSTR QueryName;
    __C89_NAMELESS union {
      PDNS_SERVICE_BROWSE_CALLBACK pBrowseCallback;
      DNS_QUERY_COMPLETION_ROUTINE *pBrowseCallbackV2;
    };
    PVOID pQueryContext;
  } DNS_SERVICE_BROWSE_REQUEST, *PDNS_SERVICE_BROWSE_REQUEST;

  DNS_STATUS WINAPI DnsServiceBrowse(PDNS_SERVICE_BROWSE_REQUEST pRequest,PDNS_SERVICE_CANCEL pCancel);
  DNS_STATUS WINAPI DnsServiceBrowseCancel(PDNS_SERVICE_CANCEL pCancelHandle);

  typedef VOID WINAPI DNS_SERVICE_RESOLVE_COMPLETE(DWORD Status,PVOID pQueryContext,PDNS_SERVICE_INSTANCE pInstance);
  typedef DNS_SERVICE_RESOLVE_COMPLETE *PDNS_SERVICE_RESOLVE_COMPLETE;

  typedef struct _DNS_SERVICE_RESOLVE_REQUEST{
    ULONG Version;
    ULONG InterfaceIndex;
    PWSTR QueryName;
    PDNS_SERVICE_RESOLVE_COMPLETE pResolveCompletionCallback;
    PVOID pQueryContext;
  } DNS_SERVICE_RESOLVE_REQUEST, *PDNS_SERVICE_RESOLVE_REQUEST;

  DNS_STATUS WINAPI DnsServiceResolve(PDNS_SERVICE_RESOLVE_REQUEST pRequest,PDNS_SERVICE_CANCEL pCancel);
  DNS_STATUS WINAPI DnsServiceResolveCancel(PDNS_SERVICE_CANCEL pCancelHandle);

  typedef VOID WINAPI DNS_SERVICE_REGISTER_COMPLETE(DWORD Status,PVOID pQueryContext,PDNS_SERVICE_INSTANCE pInstance);
  typedef DNS_SERVICE_REGISTER_COMPLETE *PDNS_SERVICE_REGISTER_COMPLETE;

  typedef struct _DNS_SERVICE_REGISTER_REQUEST{
    ULONG Version;
    ULONG   InterfaceIndex;
    PDNS_SERVICE_INSTANCE pServiceInstance;
    PDNS_SERVICE_REGISTER_COMPLETE pRegisterCompletionCallback;
    PVOID pQueryContext;
    HANDLE hCredentials;
    WINBOOL unicastEnabled;
  } DNS_SERVICE_REGISTER_REQUEST, *PDNS_SERVICE_REGISTER_REQUEST;

  DWORD WINAPI DnsServiceRegister(PDNS_SERVICE_REGISTER_REQUEST pRequest,PDNS_SERVICE_CANCEL pCancel);
  DWORD WINAPI DnsServiceDeRegister(PDNS_SERVICE_REGISTER_REQUEST pRequest,PDNS_SERVICE_CANCEL pCancel);
  DWORD WINAPI DnsServiceRegisterCancel(PDNS_SERVICE_CANCEL pCancelHandle);

  typedef struct _MDNS_QUERY_HANDLE {
    WCHAR nameBuf[DNS_MAX_NAME_BUFFER_LENGTH];
    WORD wType;
    PVOID pSubscription;
    PVOID pWnfCallbackParams;
    ULONG stateNameData[2];
  } MDNS_QUERY_HANDLE, *PMDNS_QUERY_HANDLE;

  typedef VOID WINAPI MDNS_QUERY_CALLBACK(PVOID pQueryContext,PMDNS_QUERY_HANDLE pQueryHandle,PDNS_QUERY_RESULT pQueryResults);
  typedef MDNS_QUERY_CALLBACK *PMDNS_QUERY_CALLBACK;

  typedef struct _MDNS_QUERY_REQUEST {
    ULONG Version;
    ULONG ulRefCount;
    PCWSTR Query;
    WORD QueryType;
    ULONG64 QueryOptions;
    ULONG InterfaceIndex;
    PMDNS_QUERY_CALLBACK pQueryCallback;
    PVOID pQueryContext;
    WINBOOL fAnswerReceived;
    ULONG ulResendCount;
  } MDNS_QUERY_REQUEST, *PMDNS_QUERY_REQUEST;

  DNS_STATUS WINAPI DnsStartMulticastQuery(PMDNS_QUERY_REQUEST pQueryRequest,PMDNS_QUERY_HANDLE pHandle);
  DNS_STATUS WINAPI DnsStopMulticastQuery(PMDNS_QUERY_HANDLE pHandle);

#ifdef __cplusplus
}
#endif
#endif
