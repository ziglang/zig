/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef LDAP_CLIENT_DEFINED
#define LDAP_CLIENT_DEFINED

#ifdef __cplusplus
extern "C" {
#endif

#ifndef BASETYPES
#include <windef.h>
#endif

#include <schnlsp.h>

#define WINLDAPAPI DECLSPEC_IMPORT

#ifndef LDAPAPI
#define LDAPAPI __cdecl
#endif

#ifndef LDAP_UNICODE
#if defined(UNICODE)
#define LDAP_UNICODE 1
#else
#define LDAP_UNICODE 0
#endif
#endif

#define LDAP_PORT 389
#define LDAP_SSL_PORT 636
#define LDAP_GC_PORT 3268
#define LDAP_SSL_GC_PORT 3269

#define LDAP_VERSION1 1
#define LDAP_VERSION2 2
#define LDAP_VERSION3 3
#define LDAP_VERSION LDAP_VERSION2

#define LDAP_BIND_CMD __MSABI_LONG(0x60)
#define LDAP_UNBIND_CMD __MSABI_LONG(0x42)
#define LDAP_SEARCH_CMD __MSABI_LONG(0x63)
#define LDAP_MODIFY_CMD __MSABI_LONG(0x66)
#define LDAP_ADD_CMD __MSABI_LONG(0x68)
#define LDAP_DELETE_CMD __MSABI_LONG(0x4a)
#define LDAP_MODRDN_CMD __MSABI_LONG(0x6c)
#define LDAP_COMPARE_CMD __MSABI_LONG(0x6e)
#define LDAP_ABANDON_CMD __MSABI_LONG(0x50)
#define LDAP_SESSION_CMD __MSABI_LONG(0x71)
#define LDAP_EXTENDED_CMD __MSABI_LONG(0x77)

#define LDAP_RES_BIND __MSABI_LONG(0x61)
#define LDAP_RES_SEARCH_ENTRY __MSABI_LONG(0x64)
#define LDAP_RES_SEARCH_RESULT __MSABI_LONG(0x65)
#define LDAP_RES_MODIFY __MSABI_LONG(0x67)
#define LDAP_RES_ADD __MSABI_LONG(0x69)
#define LDAP_RES_DELETE __MSABI_LONG(0x6b)
#define LDAP_RES_MODRDN __MSABI_LONG(0x6d)
#define LDAP_RES_COMPARE __MSABI_LONG(0x6f)
#define LDAP_RES_SESSION __MSABI_LONG(0x72)
#define LDAP_RES_REFERRAL __MSABI_LONG(0x73)
#define LDAP_RES_EXTENDED __MSABI_LONG(0x78)

#define LDAP_RES_ANY (__MSABI_LONG(-1))

#define LDAP_INVALID_CMD 0xff
#define LDAP_INVALID_RES 0xff

  typedef enum {
    LDAP_SUCCESS = 0x00,LDAP_OPERATIONS_ERROR = 0x01,LDAP_PROTOCOL_ERROR = 0x02,LDAP_TIMELIMIT_EXCEEDED = 0x03,LDAP_SIZELIMIT_EXCEEDED = 0x04,
    LDAP_COMPARE_FALSE = 0x05,LDAP_COMPARE_TRUE = 0x06,LDAP_AUTH_METHOD_NOT_SUPPORTED = 0x07,LDAP_STRONG_AUTH_REQUIRED = 0x08,LDAP_REFERRAL_V2 = 0x09,
    LDAP_PARTIAL_RESULTS = 0x09,LDAP_REFERRAL = 0x0a,LDAP_ADMIN_LIMIT_EXCEEDED = 0x0b,LDAP_UNAVAILABLE_CRIT_EXTENSION = 0x0c,
    LDAP_CONFIDENTIALITY_REQUIRED = 0x0d,LDAP_SASL_BIND_IN_PROGRESS = 0x0e,LDAP_NO_SUCH_ATTRIBUTE = 0x10,LDAP_UNDEFINED_TYPE = 0x11,
    LDAP_INAPPROPRIATE_MATCHING = 0x12,LDAP_CONSTRAINT_VIOLATION = 0x13,LDAP_ATTRIBUTE_OR_VALUE_EXISTS = 0x14,LDAP_INVALID_SYNTAX = 0x15,
    LDAP_NO_SUCH_OBJECT = 0x20,LDAP_ALIAS_PROBLEM = 0x21,LDAP_INVALID_DN_SYNTAX = 0x22,LDAP_IS_LEAF = 0x23,LDAP_ALIAS_DEREF_PROBLEM = 0x24,
    LDAP_INAPPROPRIATE_AUTH = 0x30,LDAP_INVALID_CREDENTIALS = 0x31,LDAP_INSUFFICIENT_RIGHTS = 0x32,LDAP_BUSY = 0x33,LDAP_UNAVAILABLE = 0x34,
    LDAP_UNWILLING_TO_PERFORM = 0x35,LDAP_LOOP_DETECT = 0x36,LDAP_SORT_CONTROL_MISSING = 0x3C,LDAP_OFFSET_RANGE_ERROR = 0x3D,
    LDAP_NAMING_VIOLATION = 0x40,LDAP_OBJECT_CLASS_VIOLATION = 0x41,LDAP_NOT_ALLOWED_ON_NONLEAF = 0x42,LDAP_NOT_ALLOWED_ON_RDN = 0x43,
    LDAP_ALREADY_EXISTS = 0x44,LDAP_NO_OBJECT_CLASS_MODS = 0x45,LDAP_RESULTS_TOO_LARGE = 0x46,LDAP_AFFECTS_MULTIPLE_DSAS = 0x47,
    LDAP_VIRTUAL_LIST_VIEW_ERROR = 0x4c,LDAP_OTHER = 0x50,LDAP_SERVER_DOWN = 0x51,LDAP_LOCAL_ERROR = 0x52,LDAP_ENCODING_ERROR = 0x53,
    LDAP_DECODING_ERROR = 0x54,LDAP_TIMEOUT = 0x55,LDAP_AUTH_UNKNOWN = 0x56,LDAP_FILTER_ERROR = 0x57,LDAP_USER_CANCELLED = 0x58,LDAP_PARAM_ERROR = 0x59,
    LDAP_NO_MEMORY = 0x5a,LDAP_CONNECT_ERROR = 0x5b,LDAP_NOT_SUPPORTED = 0x5c,LDAP_NO_RESULTS_RETURNED = 0x5e,LDAP_CONTROL_NOT_FOUND = 0x5d,
    LDAP_MORE_RESULTS_TO_RETURN = 0x5f,LDAP_CLIENT_LOOP = 0x60,LDAP_REFERRAL_LIMIT_EXCEEDED = 0x61
  } LDAP_RETCODE;

#define LDAP_AUTH_SIMPLE __MSABI_LONG(0x80)
#define LDAP_AUTH_SASL __MSABI_LONG(0x83)
#define LDAP_AUTH_OTHERKIND __MSABI_LONG(0x86)
#define LDAP_AUTH_SICILY (LDAP_AUTH_OTHERKIND | 0x0200)
#define LDAP_AUTH_MSN (LDAP_AUTH_OTHERKIND | 0x0800)
#define LDAP_AUTH_NTLM (LDAP_AUTH_OTHERKIND | 0x1000)
#define LDAP_AUTH_DPA (LDAP_AUTH_OTHERKIND | 0x2000)
#define LDAP_AUTH_NEGOTIATE (LDAP_AUTH_OTHERKIND | 0x0400)
#define LDAP_AUTH_SSPI LDAP_AUTH_NEGOTIATE
#define LDAP_AUTH_DIGEST (LDAP_AUTH_OTHERKIND | 0x4000)
#define LDAP_AUTH_EXTERNAL (LDAP_AUTH_OTHERKIND | 0x0020)

#define LDAP_FILTER_AND 0xa0
#define LDAP_FILTER_OR 0xa1
#define LDAP_FILTER_NOT 0xa2
#define LDAP_FILTER_EQUALITY 0xa3
#define LDAP_FILTER_SUBSTRINGS 0xa4
#define LDAP_FILTER_GE 0xa5
#define LDAP_FILTER_LE 0xa6
#define LDAP_FILTER_PRESENT 0x87
#define LDAP_FILTER_APPROX 0xa8
#define LDAP_FILTER_EXTENSIBLE 0xa9

#define LDAP_SUBSTRING_INITIAL __MSABI_LONG(0x80)
#define LDAP_SUBSTRING_ANY __MSABI_LONG(0x81)
#define LDAP_SUBSTRING_FINAL __MSABI_LONG(0x82)

#define LDAP_DEREF_NEVER 0
#define LDAP_DEREF_SEARCHING 1
#define LDAP_DEREF_FINDING 2
#define LDAP_DEREF_ALWAYS 3

#define LDAP_NO_LIMIT 0

#define LDAP_OPT_DNS 0x00000001
#define LDAP_OPT_CHASE_REFERRALS 0x00000002
#define LDAP_OPT_RETURN_REFS 0x00000004

#ifndef _WIN64
#pragma pack(push,4)
#endif

  typedef struct ldap {
    struct {
      UINT_PTR sb_sd;
      UCHAR Reserved1[(10*sizeof(ULONG))+1];
      ULONG_PTR sb_naddr;
      UCHAR Reserved2[(6*sizeof(ULONG))];
    } ld_sb;
    PCHAR ld_host;
    ULONG ld_version;
    UCHAR ld_lberoptions;
    ULONG ld_deref;
    ULONG ld_timelimit;
    ULONG ld_sizelimit;
    ULONG ld_errno;
    PCHAR ld_matched;
    PCHAR ld_error;
    ULONG ld_msgid;
    UCHAR Reserved3[(6*sizeof(ULONG))+1];
    ULONG ld_cldaptries;
    ULONG ld_cldaptimeout;
    ULONG ld_refhoplimit;
    ULONG ld_options;
  } LDAP,*PLDAP;

  typedef struct l_timeval {
    LONG tv_sec;
    LONG tv_usec;
  } LDAP_TIMEVAL,*PLDAP_TIMEVAL;

  typedef struct berval {
    ULONG bv_len;
    PCHAR bv_val;
  } LDAP_BERVAL,*PLDAP_BERVAL,BERVAL,*PBERVAL,BerValue;

  typedef struct ldapmsg {
    ULONG lm_msgid;
    ULONG lm_msgtype;
    PVOID lm_ber;
    struct ldapmsg *lm_chain;
    struct ldapmsg *lm_next;
    ULONG lm_time;

    PLDAP Connection;
    PVOID Request;
    ULONG lm_returncode;
    USHORT lm_referral;
    BOOLEAN lm_chased;
    BOOLEAN lm_eom;
    BOOLEAN ConnectionReferenced;
  } LDAPMessage,*PLDAPMessage;

  typedef struct ldapcontrolA {
    PCHAR ldctl_oid;
    struct berval ldctl_value;
    BOOLEAN ldctl_iscritical;
  } LDAPControlA,*PLDAPControlA;

  typedef struct ldapcontrolW {
    PWCHAR ldctl_oid;
    struct berval ldctl_value;
    BOOLEAN ldctl_iscritical;
  } LDAPControlW,*PLDAPControlW;

#if LDAP_UNICODE
#define LDAPControl LDAPControlW
#define PLDAPControl PLDAPControlW
#else
#define LDAPControl LDAPControlA
#define PLDAPControl PLDAPControlA
#endif

#define LDAP_CONTROL_REFERRALS_W L"1.2.840.113556.1.4.616"
#define LDAP_CONTROL_REFERRALS "1.2.840.113556.1.4.616"

#define LDAP_MOD_ADD 0x00
#define LDAP_MOD_DELETE 0x01
#define LDAP_MOD_REPLACE 0x02
#define LDAP_MOD_BVALUES 0x80

  typedef struct ldapmodW {
    ULONG mod_op;
    PWCHAR mod_type;
    union {
      PWCHAR *modv_strvals;
      struct berval **modv_bvals;
    } mod_vals;
  } LDAPModW,*PLDAPModW;

  typedef struct ldapmodA {
    ULONG mod_op;
    PCHAR mod_type;
    union {
      PCHAR *modv_strvals;
      struct berval **modv_bvals;
    } mod_vals;
  } LDAPModA,*PLDAPModA;

#if LDAP_UNICODE
#define LDAPMod LDAPModW
#define PLDAPMod PLDAPModW
#else
#define LDAPMod LDAPModA
#define PLDAPMod PLDAPModA
#endif

#ifndef _WIN64
#pragma pack(pop)
#endif

#define LDAP_IS_CLDAP(ld) ((ld)->ld_sb.sb_naddr > 0)
#define mod_values mod_vals.modv_strvals
#define mod_bvalues mod_vals.modv_bvals
#define NAME_ERROR(n) ((n & 0xf0)==0x20)

  WINLDAPAPI LDAP *LDAPAPI ldap_openW(const PWCHAR HostName,ULONG PortNumber);
  WINLDAPAPI LDAP *LDAPAPI ldap_openA(const PCHAR HostName,ULONG PortNumber);
  WINLDAPAPI LDAP *LDAPAPI ldap_initW(const PWCHAR HostName,ULONG PortNumber);
  WINLDAPAPI LDAP *LDAPAPI ldap_initA(const PCHAR HostName,ULONG PortNumber);
  WINLDAPAPI LDAP *LDAPAPI ldap_sslinitW(PWCHAR HostName,ULONG PortNumber,int secure);
  WINLDAPAPI LDAP *LDAPAPI ldap_sslinitA(PCHAR HostName,ULONG PortNumber,int secure);
  WINLDAPAPI ULONG LDAPAPI ldap_connect(LDAP *ld,struct l_timeval *timeout);

#if LDAP_UNICODE
#define ldap_open ldap_openW
#define ldap_init ldap_initW
#define ldap_sslinit ldap_sslinitW
#else
  WINLDAPAPI LDAP *LDAPAPI ldap_open(PCHAR HostName,ULONG PortNumber);
  WINLDAPAPI LDAP *LDAPAPI ldap_init(PCHAR HostName,ULONG PortNumber);
  WINLDAPAPI LDAP *LDAPAPI ldap_sslinit(PCHAR HostName,ULONG PortNumber,int secure);
#endif

  WINLDAPAPI LDAP *LDAPAPI cldap_openW(PWCHAR HostName,ULONG PortNumber);
  WINLDAPAPI LDAP *LDAPAPI cldap_openA(PCHAR HostName,ULONG PortNumber);

#if LDAP_UNICODE
#define cldap_open cldap_openW
#else
  WINLDAPAPI LDAP *LDAPAPI cldap_open(PCHAR HostName,ULONG PortNumber);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_unbind(LDAP *ld);
  WINLDAPAPI ULONG LDAPAPI ldap_unbind_s(LDAP *ld);
  WINLDAPAPI ULONG LDAPAPI ldap_get_option(LDAP *ld,int option,void *outvalue);
  WINLDAPAPI ULONG LDAPAPI ldap_get_optionW(LDAP *ld,int option,void *outvalue);
  WINLDAPAPI ULONG LDAPAPI ldap_set_option(LDAP *ld,int option,const void *invalue);
  WINLDAPAPI ULONG LDAPAPI ldap_set_optionW(LDAP *ld,int option,const void *invalue);

#if LDAP_UNICODE
#define ldap_get_option ldap_get_optionW
#define ldap_set_option ldap_set_optionW
#endif

#define LDAP_OPT_API_INFO 0x00
#define LDAP_OPT_DESC 0x01
#define LDAP_OPT_DEREF 0x02
#define LDAP_OPT_SIZELIMIT 0x03
#define LDAP_OPT_TIMELIMIT 0x04
#define LDAP_OPT_THREAD_FN_PTRS 0x05
#define LDAP_OPT_REBIND_FN 0x06
#define LDAP_OPT_REBIND_ARG 0x07
#define LDAP_OPT_REFERRALS 0x08
#define LDAP_OPT_RESTART 0x09

#define LDAP_OPT_SSL 0x0a
#define LDAP_OPT_IO_FN_PTRS 0x0b
#define LDAP_OPT_CACHE_FN_PTRS 0x0d
#define LDAP_OPT_CACHE_STRATEGY 0x0e
#define LDAP_OPT_CACHE_ENABLE 0x0f
#define LDAP_OPT_REFERRAL_HOP_LIMIT 0x10
#define LDAP_OPT_PROTOCOL_VERSION 0x11
#define LDAP_OPT_VERSION 0x11
#define LDAP_OPT_API_FEATURE_INFO 0x15

#define LDAP_OPT_HOST_NAME 0x30
#define LDAP_OPT_ERROR_NUMBER 0x31
#define LDAP_OPT_ERROR_STRING 0x32
#define LDAP_OPT_SERVER_ERROR 0x33
#define LDAP_OPT_SERVER_EXT_ERROR 0x34
#define LDAP_OPT_HOST_REACHABLE 0x3E
#define LDAP_OPT_PING_KEEP_ALIVE 0x36
#define LDAP_OPT_PING_WAIT_TIME 0x37
#define LDAP_OPT_PING_LIMIT 0x38
#define LDAP_OPT_DNSDOMAIN_NAME 0x3B
#define LDAP_OPT_GETDSNAME_FLAGS 0x3D
#define LDAP_OPT_PROMPT_CREDENTIALS 0x3F
#define LDAP_OPT_AUTO_RECONNECT 0x91
#define LDAP_OPT_SSPI_FLAGS 0x92
#define LDAP_OPT_SSL_INFO 0x93
#define LDAP_OPT_TLS LDAP_OPT_SSL
#define LDAP_OPT_TLS_INFO LDAP_OPT_SSL_INFO
#define LDAP_OPT_SIGN 0x95
#define LDAP_OPT_ENCRYPT 0x96
#define LDAP_OPT_SASL_METHOD 0x97
#define LDAP_OPT_AREC_EXCLUSIVE 0x98
#define LDAP_OPT_SECURITY_CONTEXT 0x99
#define LDAP_OPT_ROOTDSE_CACHE 0x9a
#define LDAP_OPT_TCP_KEEPALIVE 0x40
#define LDAP_OPT_FAST_CONCURRENT_BIND 0x41
#define LDAP_OPT_SEND_TIMEOUT 0x42
#define LDAP_OPT_ON ((void *) 1)
#define LDAP_OPT_OFF ((void *) 0)

#define LDAP_CHASE_SUBORDINATE_REFERRALS 0x00000020
#define LDAP_CHASE_EXTERNAL_REFERRALS 0x00000040

  WINLDAPAPI ULONG LDAPAPI ldap_simple_bindW(LDAP *ld,PWCHAR dn,PWCHAR passwd);
  WINLDAPAPI ULONG LDAPAPI ldap_simple_bindA(LDAP *ld,PCHAR dn,PCHAR passwd);
  WINLDAPAPI ULONG LDAPAPI ldap_simple_bind_sW(LDAP *ld,PWCHAR dn,PWCHAR passwd);
  WINLDAPAPI ULONG LDAPAPI ldap_simple_bind_sA(LDAP *ld,PCHAR dn,PCHAR passwd);
  WINLDAPAPI ULONG LDAPAPI ldap_bindW(LDAP *ld,PWCHAR dn,PWCHAR cred,ULONG method);
  WINLDAPAPI ULONG LDAPAPI ldap_bindA(LDAP *ld,PCHAR dn,PCHAR cred,ULONG method);
  WINLDAPAPI ULONG LDAPAPI ldap_bind_sW(LDAP *ld,PWCHAR dn,PWCHAR cred,ULONG method);
  WINLDAPAPI ULONG LDAPAPI ldap_bind_sA(LDAP *ld,PCHAR dn,PCHAR cred,ULONG method);
  WINLDAPAPI INT LDAPAPI ldap_sasl_bindA(LDAP *ExternalHandle,const PCHAR DistName,const PCHAR AuthMechanism,const BERVAL *cred,PLDAPControlA *ServerCtrls,PLDAPControlA *ClientCtrls,int *MessageNumber);
  WINLDAPAPI INT LDAPAPI ldap_sasl_bindW(LDAP *ExternalHandle,const PWCHAR DistName,const PWCHAR AuthMechanism,const BERVAL *cred,PLDAPControlW *ServerCtrls,PLDAPControlW *ClientCtrls,int *MessageNumber);
  WINLDAPAPI INT LDAPAPI ldap_sasl_bind_sA(LDAP *ExternalHandle,const PCHAR DistName,const PCHAR AuthMechanism,const BERVAL *cred,PLDAPControlA *ServerCtrls,PLDAPControlA *ClientCtrls,PBERVAL *ServerData);
  WINLDAPAPI INT LDAPAPI ldap_sasl_bind_sW(LDAP *ExternalHandle,const PWCHAR DistName,const PWCHAR AuthMechanism,const BERVAL *cred,PLDAPControlW *ServerCtrls,PLDAPControlW *ClientCtrls,PBERVAL *ServerData);

#if LDAP_UNICODE
#define ldap_simple_bind ldap_simple_bindW
#define ldap_simple_bind_s ldap_simple_bind_sW

#define ldap_bind ldap_bindW
#define ldap_bind_s ldap_bind_sW

#define ldap_sasl_bind ldap_sasl_bindW
#define ldap_sasl_bind_s ldap_sasl_bind_sW
#else

  WINLDAPAPI ULONG LDAPAPI ldap_simple_bind(LDAP *ld,const PCHAR dn,const PCHAR passwd);
  WINLDAPAPI ULONG LDAPAPI ldap_simple_bind_s(LDAP *ld,const PCHAR dn,const PCHAR passwd);
  WINLDAPAPI ULONG LDAPAPI ldap_bind(LDAP *ld,const PCHAR dn,const PCHAR cred,ULONG method);
  WINLDAPAPI ULONG LDAPAPI ldap_bind_s(LDAP *ld,const PCHAR dn,const PCHAR cred,ULONG method);

#define ldap_sasl_bind ldap_sasl_bindA
#define ldap_sasl_bind_s ldap_sasl_bind_sA
#endif

#define LDAP_SCOPE_BASE 0x00
#define LDAP_SCOPE_ONELEVEL 0x01
#define LDAP_SCOPE_SUBTREE 0x02

  WINLDAPAPI ULONG LDAPAPI ldap_searchW(LDAP *ld,const PWCHAR base,ULONG scope,const PWCHAR filter,PWCHAR attrs[],ULONG attrsonly);
  WINLDAPAPI ULONG LDAPAPI ldap_searchA(LDAP *ld,const PCHAR base,ULONG scope,const PCHAR filter,PCHAR attrs[],ULONG attrsonly);
  WINLDAPAPI ULONG LDAPAPI ldap_search_sW(LDAP *ld,const PWCHAR base,ULONG scope,const PWCHAR filter,PWCHAR attrs[],ULONG attrsonly,LDAPMessage **res);
  WINLDAPAPI ULONG LDAPAPI ldap_search_sA(LDAP *ld,const PCHAR base,ULONG scope,const PCHAR filter,PCHAR attrs[],ULONG attrsonly,LDAPMessage **res);
  WINLDAPAPI ULONG LDAPAPI ldap_search_stW(LDAP *ld,const PWCHAR base,ULONG scope,const PWCHAR filter,PWCHAR attrs[],ULONG attrsonly,struct l_timeval *timeout,LDAPMessage **res);
  WINLDAPAPI ULONG LDAPAPI ldap_search_stA(LDAP *ld,const PCHAR base,ULONG scope,const PCHAR filter,PCHAR attrs[],ULONG attrsonly,struct l_timeval *timeout,LDAPMessage **res);
  WINLDAPAPI ULONG LDAPAPI ldap_search_extW(LDAP *ld,const PWCHAR base,ULONG scope,const PWCHAR filter,PWCHAR attrs[],ULONG attrsonly,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls,ULONG TimeLimit,ULONG SizeLimit,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_search_extA(LDAP *ld,const PCHAR base,ULONG scope,const PCHAR filter,PCHAR attrs[],ULONG attrsonly,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG TimeLimit,ULONG SizeLimit,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_search_ext_sW(LDAP *ld,const PWCHAR base,ULONG scope,const PWCHAR filter,PWCHAR attrs[],ULONG attrsonly,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls,struct l_timeval *timeout,ULONG SizeLimit,LDAPMessage **res);
  WINLDAPAPI ULONG LDAPAPI ldap_search_ext_sA(LDAP *ld,const PCHAR base,ULONG scope,const PCHAR filter,PCHAR attrs[],ULONG attrsonly,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,struct l_timeval *timeout,ULONG SizeLimit,LDAPMessage **res);

#if LDAP_UNICODE
#define ldap_search ldap_searchW
#define ldap_search_s ldap_search_sW
#define ldap_search_st ldap_search_stW

#define ldap_search_ext ldap_search_extW
#define ldap_search_ext_s ldap_search_ext_sW
#else

  WINLDAPAPI ULONG LDAPAPI ldap_search(LDAP *ld,PCHAR base,ULONG scope,PCHAR filter,PCHAR attrs[],ULONG attrsonly);
  WINLDAPAPI ULONG LDAPAPI ldap_search_s(LDAP *ld,PCHAR base,ULONG scope,PCHAR filter,PCHAR attrs[],ULONG attrsonly,LDAPMessage **res);
  WINLDAPAPI ULONG LDAPAPI ldap_search_st(LDAP *ld,PCHAR base,ULONG scope,PCHAR filter,PCHAR attrs[],ULONG attrsonly,struct l_timeval *timeout,LDAPMessage **res);
  WINLDAPAPI ULONG LDAPAPI ldap_search_ext(LDAP *ld,PCHAR base,ULONG scope,PCHAR filter,PCHAR attrs[],ULONG attrsonly,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG TimeLimit,ULONG SizeLimit,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_search_ext_s(LDAP *ld,PCHAR base,ULONG scope,PCHAR filter,PCHAR attrs[],ULONG attrsonly,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,struct l_timeval *timeout,ULONG SizeLimit,LDAPMessage **res);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_check_filterW(LDAP *ld,PWCHAR SearchFilter);
  WINLDAPAPI ULONG LDAPAPI ldap_check_filterA(LDAP *ld,PCHAR SearchFilter);

#if LDAP_UNICODE
#define ldap_check_filter ldap_check_filterW
#else
#define ldap_check_filter ldap_check_filterA
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_modifyW(LDAP *ld,PWCHAR dn,LDAPModW *mods[]);
  WINLDAPAPI ULONG LDAPAPI ldap_modifyA(LDAP *ld,PCHAR dn,LDAPModA *mods[]);
  WINLDAPAPI ULONG LDAPAPI ldap_modify_sW(LDAP *ld,PWCHAR dn,LDAPModW *mods[]);
  WINLDAPAPI ULONG LDAPAPI ldap_modify_sA(LDAP *ld,PCHAR dn,LDAPModA *mods[]);
  WINLDAPAPI ULONG LDAPAPI ldap_modify_extW(LDAP *ld,const PWCHAR dn,LDAPModW *mods[],PLDAPControlW *ServerControls,PLDAPControlW *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_modify_extA(LDAP *ld,const PCHAR dn,LDAPModA *mods[],PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_modify_ext_sW(LDAP *ld,const PWCHAR dn,LDAPModW *mods[],PLDAPControlW *ServerControls,PLDAPControlW *ClientControls);
  WINLDAPAPI ULONG LDAPAPI ldap_modify_ext_sA(LDAP *ld,const PCHAR dn,LDAPModA *mods[],PLDAPControlA *ServerControls,PLDAPControlA *ClientControls);

#if LDAP_UNICODE
#define ldap_modify ldap_modifyW
#define ldap_modify_s ldap_modify_sW
#define ldap_modify_ext ldap_modify_extW
#define ldap_modify_ext_s ldap_modify_ext_sW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_modify(LDAP *ld,PCHAR dn,LDAPModA *mods[]);
  WINLDAPAPI ULONG LDAPAPI ldap_modify_s(LDAP *ld,PCHAR dn,LDAPModA *mods[]);
  WINLDAPAPI ULONG LDAPAPI ldap_modify_ext(LDAP *ld,const PCHAR dn,LDAPModA *mods[],PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_modify_ext_s(LDAP *ld,const PCHAR dn,LDAPModA *mods[],PLDAPControlA *ServerControls,PLDAPControlA *ClientControls);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_modrdn2W (LDAP *ExternalHandle,const PWCHAR DistinguishedName,const PWCHAR NewDistinguishedName,INT DeleteOldRdn);
  WINLDAPAPI ULONG LDAPAPI ldap_modrdn2A (LDAP *ExternalHandle,const PCHAR DistinguishedName,const PCHAR NewDistinguishedName,INT DeleteOldRdn);
  WINLDAPAPI ULONG LDAPAPI ldap_modrdnW (LDAP *ExternalHandle,const PWCHAR DistinguishedName,const PWCHAR NewDistinguishedName);
  WINLDAPAPI ULONG LDAPAPI ldap_modrdnA (LDAP *ExternalHandle,const PCHAR DistinguishedName,const PCHAR NewDistinguishedName);
  WINLDAPAPI ULONG LDAPAPI ldap_modrdn2_sW (LDAP *ExternalHandle,const PWCHAR DistinguishedName,const PWCHAR NewDistinguishedName,INT DeleteOldRdn);
  WINLDAPAPI ULONG LDAPAPI ldap_modrdn2_sA (LDAP *ExternalHandle,const PCHAR DistinguishedName,const PCHAR NewDistinguishedName,INT DeleteOldRdn);
  WINLDAPAPI ULONG LDAPAPI ldap_modrdn_sW (LDAP *ExternalHandle,const PWCHAR DistinguishedName,const PWCHAR NewDistinguishedName);
  WINLDAPAPI ULONG LDAPAPI ldap_modrdn_sA (LDAP *ExternalHandle,const PCHAR DistinguishedName,const PCHAR NewDistinguishedName);

#if LDAP_UNICODE
#define ldap_modrdn2 ldap_modrdn2W
#define ldap_modrdn ldap_modrdnW
#define ldap_modrdn2_s ldap_modrdn2_sW
#define ldap_modrdn_s ldap_modrdn_sW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_modrdn2 (LDAP *ExternalHandle,const PCHAR DistinguishedName,const PCHAR NewDistinguishedName,INT DeleteOldRdn);
  WINLDAPAPI ULONG LDAPAPI ldap_modrdn (LDAP *ExternalHandle,const PCHAR DistinguishedName,const PCHAR NewDistinguishedName);
  WINLDAPAPI ULONG LDAPAPI ldap_modrdn2_s (LDAP *ExternalHandle,const PCHAR DistinguishedName,const PCHAR NewDistinguishedName,INT DeleteOldRdn);
  WINLDAPAPI ULONG LDAPAPI ldap_modrdn_s (LDAP *ExternalHandle,const PCHAR DistinguishedName,const PCHAR NewDistinguishedName);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_rename_extW(LDAP *ld,const PWCHAR dn,const PWCHAR NewRDN,const PWCHAR NewParent,INT DeleteOldRdn,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_rename_extA(LDAP *ld,const PCHAR dn,const PCHAR NewRDN,const PCHAR NewParent,INT DeleteOldRdn,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_rename_ext_sW(LDAP *ld,const PWCHAR dn,const PWCHAR NewRDN,const PWCHAR NewParent,INT DeleteOldRdn,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls);
  WINLDAPAPI ULONG LDAPAPI ldap_rename_ext_sA(LDAP *ld,const PCHAR dn,const PCHAR NewRDN,const PCHAR NewParent,INT DeleteOldRdn,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls);

#if LDAP_UNICODE
#define ldap_rename ldap_rename_extW
#define ldap_rename_s ldap_rename_ext_sW
#else
#define ldap_rename ldap_rename_extA
#define ldap_rename_s ldap_rename_ext_sA
#endif

#if LDAP_UNICODE
#define ldap_rename_ext ldap_rename_extW
#define ldap_rename_ext_s ldap_rename_ext_sW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_rename_ext(LDAP *ld,const PCHAR dn,const PCHAR NewRDN,const PCHAR NewParent,INT DeleteOldRdn,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_rename_ext_s(LDAP *ld,const PCHAR dn,const PCHAR NewRDN,const PCHAR NewParent,INT DeleteOldRdn,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_addW(LDAP *ld,PWCHAR dn,LDAPModW *attrs[]);
  WINLDAPAPI ULONG LDAPAPI ldap_addA(LDAP *ld,PCHAR dn,LDAPModA *attrs[]);
  WINLDAPAPI ULONG LDAPAPI ldap_add_sW(LDAP *ld,PWCHAR dn,LDAPModW *attrs[]);
  WINLDAPAPI ULONG LDAPAPI ldap_add_sA(LDAP *ld,PCHAR dn,LDAPModA *attrs[]);
  WINLDAPAPI ULONG LDAPAPI ldap_add_extW(LDAP *ld,const PWCHAR dn,LDAPModW *attrs[],PLDAPControlW *ServerControls,PLDAPControlW *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_add_extA(LDAP *ld,const PCHAR dn,LDAPModA *attrs[],PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_add_ext_sW(LDAP *ld,const PWCHAR dn,LDAPModW *attrs[],PLDAPControlW *ServerControls,PLDAPControlW *ClientControls);
  WINLDAPAPI ULONG LDAPAPI ldap_add_ext_sA(LDAP *ld,const PCHAR dn,LDAPModA *attrs[],PLDAPControlA *ServerControls,PLDAPControlA *ClientControls);

#if LDAP_UNICODE
#define ldap_add ldap_addW
#define ldap_add_s ldap_add_sW
#define ldap_add_ext ldap_add_extW
#define ldap_add_ext_s ldap_add_ext_sW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_add(LDAP *ld,PCHAR dn,LDAPMod *attrs[]);
  WINLDAPAPI ULONG LDAPAPI ldap_add_s(LDAP *ld,PCHAR dn,LDAPMod *attrs[]);
  WINLDAPAPI ULONG LDAPAPI ldap_add_ext(LDAP *ld,const PCHAR dn,LDAPModA *attrs[],PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_add_ext_s(LDAP *ld,const PCHAR dn,LDAPModA *attrs[],PLDAPControlA *ServerControls,PLDAPControlA *ClientControls);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_compareW(LDAP *ld,const PWCHAR dn,const PWCHAR attr,PWCHAR value);
  WINLDAPAPI ULONG LDAPAPI ldap_compareA(LDAP *ld,const PCHAR dn,const PCHAR attr,PCHAR value);
  WINLDAPAPI ULONG LDAPAPI ldap_compare_sW(LDAP *ld,const PWCHAR dn,const PWCHAR attr,PWCHAR value);
  WINLDAPAPI ULONG LDAPAPI ldap_compare_sA(LDAP *ld,const PCHAR dn,const PCHAR attr,PCHAR value);

#if LDAP_UNICODE
#define ldap_compare ldap_compareW
#define ldap_compare_s ldap_compare_sW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_compare(LDAP *ld,const PCHAR dn,const PCHAR attr,PCHAR value);
  WINLDAPAPI ULONG LDAPAPI ldap_compare_s(LDAP *ld,const PCHAR dn,const PCHAR attr,PCHAR value);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_compare_extW(LDAP *ld,const PWCHAR dn,const PWCHAR Attr,const PWCHAR Value,struct berval *Data,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_compare_extA(LDAP *ld,const PCHAR dn,const PCHAR Attr,const PCHAR Value,struct berval *Data,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_compare_ext_sW(LDAP *ld,const PWCHAR dn,const PWCHAR Attr,const PWCHAR Value,struct berval *Data,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls);
  WINLDAPAPI ULONG LDAPAPI ldap_compare_ext_sA(LDAP *ld,const PCHAR dn,const PCHAR Attr,const PCHAR Value,struct berval *Data,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls);

#if LDAP_UNICODE
#define ldap_compare_ext ldap_compare_extW
#define ldap_compare_ext_s ldap_compare_ext_sW
#else

  WINLDAPAPI ULONG LDAPAPI ldap_compare_ext(LDAP *ld,const PCHAR dn,const PCHAR Attr,const PCHAR Value,struct berval *Data,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_compare_ext_s(LDAP *ld,const PCHAR dn,const PCHAR Attr,const PCHAR Value,struct berval *Data,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_deleteW(LDAP *ld,const PWCHAR dn);
  WINLDAPAPI ULONG LDAPAPI ldap_deleteA(LDAP *ld,const PCHAR dn);
  WINLDAPAPI ULONG LDAPAPI ldap_delete_sW(LDAP *ld,const PWCHAR dn);
  WINLDAPAPI ULONG LDAPAPI ldap_delete_sA(LDAP *ld,const PCHAR dn);
  WINLDAPAPI ULONG LDAPAPI ldap_delete_extW(LDAP *ld,const PWCHAR dn,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_delete_extA(LDAP *ld,const PCHAR dn,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_delete_ext_sW(LDAP *ld,const PWCHAR dn,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls);
  WINLDAPAPI ULONG LDAPAPI ldap_delete_ext_sA(LDAP *ld,const PCHAR dn,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls);

#if LDAP_UNICODE
#define ldap_delete ldap_deleteW
#define ldap_delete_ext ldap_delete_extW
#define ldap_delete_s ldap_delete_sW
#define ldap_delete_ext_s ldap_delete_ext_sW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_delete(LDAP *ld,PCHAR dn);
  WINLDAPAPI ULONG LDAPAPI ldap_delete_s(LDAP *ld,PCHAR dn);
  WINLDAPAPI ULONG LDAPAPI ldap_delete_ext(LDAP *ld,const PCHAR dn,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_delete_ext_s(LDAP *ld,const PCHAR dn,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_abandon(LDAP *ld,ULONG msgid);

#define LDAP_MSG_ONE 0
#define LDAP_MSG_ALL 1
#define LDAP_MSG_RECEIVED 2

  WINLDAPAPI ULONG LDAPAPI ldap_result(LDAP *ld,ULONG msgid,ULONG all,struct l_timeval *timeout,LDAPMessage **res);
  WINLDAPAPI ULONG LDAPAPI ldap_msgfree(LDAPMessage *res);
  WINLDAPAPI ULONG LDAPAPI ldap_result2error(LDAP *ld,LDAPMessage *res,ULONG freeit);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_resultW (LDAP *Connection,LDAPMessage *ResultMessage,ULONG *ReturnCode,PWCHAR *MatchedDNs,PWCHAR *ErrorMessage,PWCHAR **Referrals,PLDAPControlW **ServerControls,BOOLEAN Freeit);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_resultA (LDAP *Connection,LDAPMessage *ResultMessage,ULONG *ReturnCode,PCHAR *MatchedDNs,PCHAR *ErrorMessage,PCHAR **Referrals,PLDAPControlA **ServerControls,BOOLEAN Freeit);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_extended_resultA (LDAP *Connection,LDAPMessage *ResultMessage,PCHAR *ResultOID,struct berval **ResultData,BOOLEAN Freeit);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_extended_resultW (LDAP *Connection,LDAPMessage *ResultMessage,PWCHAR *ResultOID,struct berval **ResultData,BOOLEAN Freeit);
  WINLDAPAPI ULONG LDAPAPI ldap_controls_freeA (LDAPControlA **Controls);
  WINLDAPAPI ULONG LDAPAPI ldap_control_freeA (LDAPControlA *Controls);
  WINLDAPAPI ULONG LDAPAPI ldap_controls_freeW (LDAPControlW **Control);
  WINLDAPAPI ULONG LDAPAPI ldap_control_freeW (LDAPControlW *Control);
  WINLDAPAPI ULONG LDAPAPI ldap_free_controlsW (LDAPControlW **Controls);
  WINLDAPAPI ULONG LDAPAPI ldap_free_controlsA (LDAPControlA **Controls);

#if LDAP_UNICODE
#define ldap_parse_result ldap_parse_resultW
#define ldap_controls_free ldap_controls_freeW
#define ldap_control_free ldap_control_freeW
#define ldap_free_controls ldap_free_controlsW
#define ldap_parse_extended_result ldap_parse_extended_resultW
#else
#define ldap_parse_extended_result ldap_parse_extended_resultA
  WINLDAPAPI ULONG LDAPAPI ldap_parse_result (LDAP *Connection,LDAPMessage *ResultMessage,ULONG *ReturnCode,PCHAR *MatchedDNs,PCHAR *ErrorMessage,PCHAR **Referrals,PLDAPControlA **ServerControls,BOOLEAN Freeit);
  WINLDAPAPI ULONG LDAPAPI ldap_controls_free (LDAPControlA **Controls);
  WINLDAPAPI ULONG LDAPAPI ldap_control_free (LDAPControlA *Control);
  WINLDAPAPI ULONG LDAPAPI ldap_free_controls (LDAPControlA **Controls);
#endif

  WINLDAPAPI PWCHAR LDAPAPI ldap_err2stringW(ULONG err);
  WINLDAPAPI PCHAR LDAPAPI ldap_err2stringA(ULONG err);

#if LDAP_UNICODE
#define ldap_err2string ldap_err2stringW
#else
  WINLDAPAPI PCHAR LDAPAPI ldap_err2string(ULONG err);
#endif

  WINLDAPAPI void LDAPAPI ldap_perror(LDAP *ld,const PCHAR msg);
  WINLDAPAPI LDAPMessage *LDAPAPI ldap_first_entry(LDAP *ld,LDAPMessage *res);
  WINLDAPAPI LDAPMessage *LDAPAPI ldap_next_entry(LDAP *ld,LDAPMessage *entry);
  WINLDAPAPI ULONG LDAPAPI ldap_count_entries(LDAP *ld,LDAPMessage *res);

  typedef struct berelement {
    PCHAR opaque;
  } BerElement;

#define NULLBER ((BerElement *) 0)

  WINLDAPAPI PWCHAR LDAPAPI ldap_first_attributeW(LDAP *ld,LDAPMessage *entry,BerElement **ptr);
  WINLDAPAPI PCHAR LDAPAPI ldap_first_attributeA(LDAP *ld,LDAPMessage *entry,BerElement **ptr);

#if LDAP_UNICODE
#define ldap_first_attribute ldap_first_attributeW
#else
  WINLDAPAPI PCHAR LDAPAPI ldap_first_attribute(LDAP *ld,LDAPMessage *entry,BerElement **ptr);
#endif

  WINLDAPAPI PWCHAR LDAPAPI ldap_next_attributeW(LDAP *ld,LDAPMessage *entry,BerElement *ptr);
  WINLDAPAPI PCHAR LDAPAPI ldap_next_attributeA(LDAP *ld,LDAPMessage *entry,BerElement *ptr);

#if LDAP_UNICODE
#define ldap_next_attribute ldap_next_attributeW
#else
  WINLDAPAPI PCHAR LDAPAPI ldap_next_attribute(LDAP *ld,LDAPMessage *entry,BerElement *ptr);
#endif

  WINLDAPAPI PWCHAR *LDAPAPI ldap_get_valuesW(LDAP *ld,LDAPMessage *entry,const PWCHAR attr);
  WINLDAPAPI PCHAR *LDAPAPI ldap_get_valuesA(LDAP *ld,LDAPMessage *entry,const PCHAR attr);

#if LDAP_UNICODE
#define ldap_get_values ldap_get_valuesW
#else
  WINLDAPAPI PCHAR *LDAPAPI ldap_get_values(LDAP *ld,LDAPMessage *entry,const PCHAR attr);
#endif

  WINLDAPAPI struct berval **LDAPAPI ldap_get_values_lenW (LDAP *ExternalHandle,LDAPMessage *Message,const PWCHAR attr);
  WINLDAPAPI struct berval **LDAPAPI ldap_get_values_lenA (LDAP *ExternalHandle,LDAPMessage *Message,const PCHAR attr);

#if LDAP_UNICODE
#define ldap_get_values_len ldap_get_values_lenW
#else
  WINLDAPAPI struct berval **LDAPAPI ldap_get_values_len (LDAP *ExternalHandle,LDAPMessage *Message,const PCHAR attr);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_count_valuesW(PWCHAR *vals);
  WINLDAPAPI ULONG LDAPAPI ldap_count_valuesA(PCHAR *vals);

#if LDAP_UNICODE
#define ldap_count_values ldap_count_valuesW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_count_values(PCHAR *vals);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_count_values_len(struct berval **vals);
  WINLDAPAPI ULONG LDAPAPI ldap_value_freeW(PWCHAR *vals);
  WINLDAPAPI ULONG LDAPAPI ldap_value_freeA(PCHAR *vals);

#if LDAP_UNICODE
#define ldap_value_free ldap_value_freeW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_value_free(PCHAR *vals);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_value_free_len(struct berval **vals);
  WINLDAPAPI PWCHAR LDAPAPI ldap_get_dnW(LDAP *ld,LDAPMessage *entry);
  WINLDAPAPI PCHAR LDAPAPI ldap_get_dnA(LDAP *ld,LDAPMessage *entry);

#if LDAP_UNICODE
#define ldap_get_dn ldap_get_dnW
#else
  WINLDAPAPI PCHAR LDAPAPI ldap_get_dn(LDAP *ld,LDAPMessage *entry);
#endif

  WINLDAPAPI PWCHAR *LDAPAPI ldap_explode_dnW(const PWCHAR dn,ULONG notypes);
  WINLDAPAPI PCHAR *LDAPAPI ldap_explode_dnA(const PCHAR dn,ULONG notypes);

#if LDAP_UNICODE
#define ldap_explode_dn ldap_explode_dnW
#else
  WINLDAPAPI PCHAR *LDAPAPI ldap_explode_dn(const PCHAR dn,ULONG notypes);
#endif

  WINLDAPAPI PWCHAR LDAPAPI ldap_dn2ufnW(const PWCHAR dn);
  WINLDAPAPI PCHAR LDAPAPI ldap_dn2ufnA(const PCHAR dn);

#if LDAP_UNICODE
#define ldap_dn2ufn ldap_dn2ufnW
#else
  WINLDAPAPI PCHAR LDAPAPI ldap_dn2ufn(const PCHAR dn);
#endif

  WINLDAPAPI VOID LDAPAPI ldap_memfreeW(PWCHAR Block);
  WINLDAPAPI VOID LDAPAPI ldap_memfreeA(PCHAR Block);
  WINLDAPAPI VOID LDAPAPI ber_bvfree(struct berval *bv);

#if LDAP_UNICODE
#define ldap_memfree ldap_memfreeW
#else
  WINLDAPAPI VOID LDAPAPI ldap_memfree(PCHAR Block);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_ufn2dnW (const PWCHAR ufn,PWCHAR *pDn);
  WINLDAPAPI ULONG LDAPAPI ldap_ufn2dnA (const PCHAR ufn,PCHAR *pDn);

#if LDAP_UNICODE
#define ldap_ufn2dn ldap_ufn2dnW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_ufn2dn (const PCHAR ufn,PCHAR *pDn);
#endif

#define LBER_USE_DER 0x01
#define LBER_USE_INDEFINITE_LEN 0x02
#define LBER_TRANSLATE_STRINGS 0x04

#define LAPI_MAJOR_VER1 1
#define LAPI_MINOR_VER1 1

  typedef struct ldap_version_info {
    ULONG lv_size;
    ULONG lv_major;
    ULONG lv_minor;
  } LDAP_VERSION_INFO,*PLDAP_VERSION_INFO;

  WINLDAPAPI ULONG LDAPAPI ldap_startup (PLDAP_VERSION_INFO version,HANDLE *Instance);

#define LDAP_API_INFO_VERSION 1
#define LDAP_API_VERSION 2004
#define LDAP_VERSION_MIN 2
#define LDAP_VERSION_MAX 3
#define LDAP_VENDOR_NAME "Microsoft Corporation."
#define LDAP_VENDOR_NAME_W L"Microsoft Corporation."
#define LDAP_VENDOR_VERSION 510

  typedef struct ldapapiinfoA {
    int ldapai_info_version;
    int ldapai_api_version;
    int ldapai_protocol_version;
    char **ldapai_extensions;
    char *ldapai_vendor_name;
    int ldapai_vendor_version;
  } LDAPAPIInfoA;

  typedef struct ldapapiinfoW {
    int ldapai_info_version;
    int ldapai_api_version;
    int ldapai_protocol_version;
    PWCHAR *ldapai_extensions;
    PWCHAR ldapai_vendor_name;
    int ldapai_vendor_version;
  } LDAPAPIInfoW;

#define LDAP_FEATURE_INFO_VERSION 1

  typedef struct ldap_apifeature_infoA {
    int ldapaif_info_version;
    char *ldapaif_name;
    int ldapaif_version;
  } LDAPAPIFeatureInfoA;

  typedef struct ldap_apifeature_infoW {
    int ldapaif_info_version;
    PWCHAR ldapaif_name;
    int ldapaif_version;
  } LDAPAPIFeatureInfoW;

#if LDAP_UNICODE
#define LDAPAPIInfo LDAPAPIInfoW
#define LDAPAPIFeatureInfo LDAPAPIFeatureInfoW
#else
#define LDAPAPIInfo LDAPAPIInfoA
#define LDAPAPIFeatureInfo LDAPAPIFeatureInfoA
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_cleanup (HANDLE hInstance);
  WINLDAPAPI ULONG LDAPAPI ldap_escape_filter_elementW (PCHAR sourceFilterElement,ULONG sourceLength,PWCHAR destFilterElement,ULONG destLength);
  WINLDAPAPI ULONG LDAPAPI ldap_escape_filter_elementA (PCHAR sourceFilterElement,ULONG sourceLength,PCHAR destFilterElement,ULONG destLength);

#if LDAP_UNICODE
#define ldap_escape_filter_element ldap_escape_filter_elementW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_escape_filter_element (PCHAR sourceFilterElement,ULONG sourceLength,PCHAR destFilterElement,ULONG destLength);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_set_dbg_flags(ULONG NewFlags);

  typedef ULONG (LDAPAPI *DBGPRINT)(PCH Format,...);

  WINLDAPAPI VOID LDAPAPI ldap_set_dbg_routine(DBGPRINT DebugPrintRoutine);
  WINLDAPAPI int LDAPAPI LdapUTF8ToUnicode(LPCSTR lpSrcStr,int cchSrc,LPWSTR lpDestStr,int cchDest);
  WINLDAPAPI int LDAPAPI LdapUnicodeToUTF8(LPCWSTR lpSrcStr,int cchSrc,LPSTR lpDestStr,int cchDest);

#define LDAP_SERVER_SORT_OID "1.2.840.113556.1.4.473"
#define LDAP_SERVER_SORT_OID_W L"1.2.840.113556.1.4.473"
#define LDAP_SERVER_RESP_SORT_OID "1.2.840.113556.1.4.474"
#define LDAP_SERVER_RESP_SORT_OID_W L"1.2.840.113556.1.4.474"

  typedef struct ldapsearch LDAPSearch,*PLDAPSearch;

  typedef struct ldapsortkeyW {
    PWCHAR sk_attrtype;
    PWCHAR sk_matchruleoid;
    BOOLEAN sk_reverseorder;
  } LDAPSortKeyW,*PLDAPSortKeyW;

  typedef struct ldapsortkeyA {
    PCHAR sk_attrtype;
    PCHAR sk_matchruleoid;
    BOOLEAN sk_reverseorder;
  } LDAPSortKeyA,*PLDAPSortKeyA;

#if LDAP_UNICODE
#define LDAPSortKey LDAPSortKeyW
#define PLDAPSortKey PLDAPSortKeyW
#else
#define LDAPSortKey LDAPSortKeyA
#define PLDAPSortKey PLDAPSortKeyA
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_create_sort_controlA (PLDAP ExternalHandle,PLDAPSortKeyA *SortKeys,UCHAR IsCritical,PLDAPControlA *Control);
  WINLDAPAPI ULONG LDAPAPI ldap_create_sort_controlW (PLDAP ExternalHandle,PLDAPSortKeyW *SortKeys,UCHAR IsCritical,PLDAPControlW *Control);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_sort_controlA (PLDAP ExternalHandle,PLDAPControlA *Control,ULONG *Result,PCHAR *Attribute);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_sort_controlW (PLDAP ExternalHandle,PLDAPControlW *Control,ULONG *Result,PWCHAR *Attribute);

#if LDAP_UNICODE
#define ldap_create_sort_control ldap_create_sort_controlW
#define ldap_parse_sort_control ldap_parse_sort_controlW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_create_sort_control (PLDAP ExternalHandle,PLDAPSortKeyA *SortKeys,UCHAR IsCritical,PLDAPControlA *Control);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_sort_control (PLDAP ExternalHandle,PLDAPControlA *Control,ULONG *Result,PCHAR *Attribute);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_encode_sort_controlW (PLDAP ExternalHandle,PLDAPSortKeyW *SortKeys,PLDAPControlW Control,BOOLEAN Criticality);
  WINLDAPAPI ULONG LDAPAPI ldap_encode_sort_controlA (PLDAP ExternalHandle,PLDAPSortKeyA *SortKeys,PLDAPControlA Control,BOOLEAN Criticality);

#if LDAP_UNICODE
#define ldap_encode_sort_control ldap_encode_sort_controlW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_encode_sort_control (PLDAP ExternalHandle,PLDAPSortKeyA *SortKeys,PLDAPControlA Control,BOOLEAN Criticality);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_create_page_controlW(PLDAP ExternalHandle,ULONG PageSize,struct berval *Cookie,UCHAR IsCritical,PLDAPControlW *Control);
  WINLDAPAPI ULONG LDAPAPI ldap_create_page_controlA(PLDAP ExternalHandle,ULONG PageSize,struct berval *Cookie,UCHAR IsCritical,PLDAPControlA *Control);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_page_controlW (PLDAP ExternalHandle,PLDAPControlW *ServerControls,ULONG *TotalCount,struct berval **Cookie);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_page_controlA (PLDAP ExternalHandle,PLDAPControlA *ServerControls,ULONG *TotalCount,struct berval **Cookie);

#if LDAP_UNICODE
#define ldap_create_page_control ldap_create_page_controlW
#define ldap_parse_page_control ldap_parse_page_controlW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_create_page_control(PLDAP ExternalHandle,ULONG PageSize,struct berval *Cookie,UCHAR IsCritical,PLDAPControlA *Control);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_page_control (PLDAP ExternalHandle,PLDAPControlA *ServerControls,ULONG *TotalCount,struct berval **Cookie);
#endif

#define LDAP_PAGED_RESULT_OID_STRING "1.2.840.113556.1.4.319"
#define LDAP_PAGED_RESULT_OID_STRING_W L"1.2.840.113556.1.4.319"

  WINLDAPAPI PLDAPSearch LDAPAPI ldap_search_init_pageW(PLDAP ExternalHandle,const PWCHAR DistinguishedName,ULONG ScopeOfSearch,const PWCHAR SearchFilter,PWCHAR AttributeList[],ULONG AttributesOnly,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls,ULONG PageTimeLimit,ULONG TotalSizeLimit,PLDAPSortKeyW *SortKeys);
  WINLDAPAPI PLDAPSearch LDAPAPI ldap_search_init_pageA(PLDAP ExternalHandle,const PCHAR DistinguishedName,ULONG ScopeOfSearch,const PCHAR SearchFilter,PCHAR AttributeList[],ULONG AttributesOnly,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG PageTimeLimit,ULONG TotalSizeLimit,PLDAPSortKeyA *SortKeys);

#if LDAP_UNICODE
#define ldap_search_init_page ldap_search_init_pageW
#else
  WINLDAPAPI PLDAPSearch LDAPAPI ldap_search_init_page(PLDAP ExternalHandle,const PCHAR DistinguishedName,ULONG ScopeOfSearch,const PCHAR SearchFilter,PCHAR AttributeList[],ULONG AttributesOnly,PLDAPControl *ServerControls,PLDAPControl *ClientControls,ULONG PageTimeLimit,ULONG TotalSizeLimit,PLDAPSortKey *SortKeys);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_get_next_page(PLDAP ExternalHandle,PLDAPSearch SearchHandle,ULONG PageSize,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_get_next_page_s(PLDAP ExternalHandle,PLDAPSearch SearchHandle,struct l_timeval *timeout,ULONG PageSize,ULONG *TotalCount,LDAPMessage **Results);
  WINLDAPAPI ULONG LDAPAPI ldap_get_paged_count(PLDAP ExternalHandle,PLDAPSearch SearchBlock,ULONG *TotalCount,PLDAPMessage Results);
  WINLDAPAPI ULONG LDAPAPI ldap_search_abandon_page(PLDAP ExternalHandle,PLDAPSearch SearchBlock);

#define LDAP_CONTROL_VLVREQUEST "2.16.840.1.113730.3.4.9"
#define LDAP_CONTROL_VLVREQUEST_W L"2.16.840.1.113730.3.4.9"
#define LDAP_CONTROL_VLVRESPONSE "2.16.840.1.113730.3.4.10"
#define LDAP_CONTROL_VLVRESPONSE_W L"2.16.840.1.113730.3.4.10"

#define LDAP_API_FEATURE_VIRTUAL_LIST_VIEW 1001

#define LDAP_VLVINFO_VERSION 1

  typedef struct ldapvlvinfo {
    int ldvlv_version;
    ULONG ldvlv_before_count;
    ULONG ldvlv_after_count;
    ULONG ldvlv_offset;
    ULONG ldvlv_count;
    PBERVAL ldvlv_attrvalue;
    PBERVAL ldvlv_context;
    VOID *ldvlv_extradata;
  } LDAPVLVInfo,*PLDAPVLVInfo;

  WINLDAPAPI INT LDAPAPI ldap_create_vlv_controlW (PLDAP ExternalHandle,PLDAPVLVInfo VlvInfo,UCHAR IsCritical,PLDAPControlW *Control);
  WINLDAPAPI INT LDAPAPI ldap_create_vlv_controlA (PLDAP ExternalHandle,PLDAPVLVInfo VlvInfo,UCHAR IsCritical,PLDAPControlA *Control);
  WINLDAPAPI INT LDAPAPI ldap_parse_vlv_controlW (PLDAP ExternalHandle,PLDAPControlW *Control,PULONG TargetPos,PULONG ListCount,PBERVAL *Context,PINT ErrCode);
  WINLDAPAPI INT LDAPAPI ldap_parse_vlv_controlA (PLDAP ExternalHandle,PLDAPControlA *Control,PULONG TargetPos,PULONG ListCount,PBERVAL *Context,PINT ErrCode);

#if LDAP_UNICODE
#define ldap_create_vlv_control ldap_create_vlv_controlW
#define ldap_parse_vlv_control ldap_parse_vlv_controlW
#else
#define ldap_create_vlv_control ldap_create_vlv_controlA
#define ldap_parse_vlv_control ldap_parse_vlv_controlA
#endif

#define LDAP_START_TLS_OID "1.3.6.1.4.1.1466.20037"
#define LDAP_START_TLS_OID_W L"1.3.6.1.4.1.1466.20037"

  WINLDAPAPI ULONG LDAPAPI ldap_start_tls_sW(PLDAP ExternalHandle,PULONG ServerReturnValue,LDAPMessage **result,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls);
  WINLDAPAPI ULONG LDAPAPI ldap_start_tls_sA(PLDAP ExternalHandle,PULONG ServerReturnValue,LDAPMessage **result,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls);
  WINLDAPAPI BOOLEAN LDAPAPI ldap_stop_tls_s(PLDAP ExternalHandle);

#if LDAP_UNICODE
#define ldap_start_tls_s ldap_start_tls_sW
#else
#define ldap_start_tls_s ldap_start_tls_sA
#endif

#define LDAP_TTL_EXTENDED_OP_OID "1.3.6.1.4.1.1466.101.119.1"
#define LDAP_TTL_EXTENDED_OP_OID_W L"1.3.6.1.4.1.1466.101.119.1"

  WINLDAPAPI LDAPMessage *LDAPAPI ldap_first_reference(LDAP *ld,LDAPMessage *res);
  WINLDAPAPI LDAPMessage *LDAPAPI ldap_next_reference(LDAP *ld,LDAPMessage *entry);
  WINLDAPAPI ULONG LDAPAPI ldap_count_references(LDAP *ld,LDAPMessage *res);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_referenceW (LDAP *Connection,LDAPMessage *ResultMessage,PWCHAR **Referrals);
  WINLDAPAPI ULONG LDAPAPI ldap_parse_referenceA (LDAP *Connection,LDAPMessage *ResultMessage,PCHAR **Referrals);

#if LDAP_UNICODE
#define ldap_parse_reference ldap_parse_referenceW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_parse_reference (LDAP *Connection,LDAPMessage *ResultMessage,PCHAR **Referrals);
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_extended_operationW(LDAP *ld,const PWCHAR Oid,struct berval *Data,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_extended_operationA(LDAP *ld,const PCHAR Oid,struct berval *Data,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
  WINLDAPAPI ULONG LDAPAPI ldap_extended_operation_sA (LDAP *ExternalHandle,PCHAR Oid,struct berval *Data,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,PCHAR *ReturnedOid,struct berval **ReturnedData);
  WINLDAPAPI ULONG LDAPAPI ldap_extended_operation_sW (LDAP *ExternalHandle,PWCHAR Oid,struct berval *Data,PLDAPControlW *ServerControls,PLDAPControlW *ClientControls,PWCHAR *ReturnedOid,struct berval **ReturnedData);

#if LDAP_UNICODE
#define ldap_extended_operation ldap_extended_operationW
#define ldap_extended_operation_s ldap_extended_operation_sW
#else
  WINLDAPAPI ULONG LDAPAPI ldap_extended_operation(LDAP *ld,const PCHAR Oid,struct berval *Data,PLDAPControlA *ServerControls,PLDAPControlA *ClientControls,ULONG *MessageNumber);
#define ldap_extended_operation_s ldap_extended_operation_sA
#endif

  WINLDAPAPI ULONG LDAPAPI ldap_close_extended_op(LDAP *ld,ULONG MessageNumber);

#define LDAP_OPT_REFERRAL_CALLBACK 0x70

  typedef ULONG (LDAPAPI QUERYFORCONNECTION)(PLDAP PrimaryConnection,PLDAP ReferralFromConnection,PWCHAR NewDN,PCHAR HostName,ULONG PortNumber,PVOID SecAuthIdentity,PVOID CurrentUserToken,PLDAP *ConnectionToUse);
  typedef BOOLEAN (LDAPAPI NOTIFYOFNEWCONNECTION) (PLDAP PrimaryConnection,PLDAP ReferralFromConnection,PWCHAR NewDN,PCHAR HostName,PLDAP NewConnection,ULONG PortNumber,PVOID SecAuthIdentity,PVOID CurrentUser,ULONG ErrorCodeFromBind);
  typedef ULONG (LDAPAPI DEREFERENCECONNECTION)(PLDAP PrimaryConnection,PLDAP ConnectionToDereference);

  typedef struct LdapReferralCallback {
    ULONG SizeOfCallbacks;
    QUERYFORCONNECTION *QueryForConnection;
    NOTIFYOFNEWCONNECTION *NotifyRoutine;
    DEREFERENCECONNECTION *DereferenceRoutine;
  } LDAP_REFERRAL_CALLBACK,*PLDAP_REFERRAL_CALLBACK;

  WINLDAPAPI ULONG LDAPAPI LdapGetLastError(VOID);
  WINLDAPAPI ULONG LDAPAPI LdapMapErrorToWin32(ULONG LdapError);

#define LDAP_OPT_CLIENT_CERTIFICATE 0x80
#define LDAP_OPT_SERVER_CERTIFICATE 0x81
#define LDAP_OPT_REF_DEREF_CONN_PER_MSG 0x94

  typedef BOOLEAN (LDAPAPI QUERYCLIENTCERT) (PLDAP Connection,PSecPkgContext_IssuerListInfoEx trusted_CAs,PCCERT_CONTEXT *ppCertificate);
  typedef BOOLEAN (LDAPAPI VERIFYSERVERCERT) (PLDAP Connection,PCCERT_CONTEXT pServerCert);

  WINLDAPAPI LDAP *LDAPAPI ldap_conn_from_msg (LDAP *PrimaryConn,LDAPMessage *res);


#ifdef __cplusplus
}
#endif
#endif
