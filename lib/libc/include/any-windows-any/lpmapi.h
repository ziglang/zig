/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __LPMAPI_H_
#define __LPMAPI_H_

#ifdef __cplusplus
extern "C" {
#endif

#ifndef CALLBACK
#if defined(_ARM_)
#define CALLBACK
#else
#define CALLBACK __stdcall
#endif
#endif

#ifndef WINAPI
#if defined(_ARM_)
#define WINAPI
#else
#define WINAPI __stdcall
#endif
#endif

#ifndef APIENTRY
#define APIENTRY WINAPI
#endif

  typedef struct {
    USHORT obj_length;
    UCHAR obj_class;
    UCHAR obj_ctype;
  } RsvpObjHdr;

#define ObjLength(x) ((RsvpObjHdr *)x)->obj_length
#define ObjCType(x) ((RsvpObjHdr *)x)->obj_ctype
#define ObjClass(x) ((RsvpObjHdr *)x)->obj_class
#define ObjData(x) ((RsvpObjHdr *)(x)+1)

#define class_NULL 0
#define class_SESSION 1
#define class_SESSION_GROUP 2
#define class_RSVP_HOP 3
#define class_INTEGRITY 4
#define class_TIME_VALUES 5
#define class_ERROR_SPEC 6
#define class_SCOPE 7
#define class_STYLE 8
#define class_FLOWSPEC 9
#define class_IS_FLOWSPEC 9
#define class_FILTER_SPEC 10
#define class_SENDER_TEMPLATE 11
#define class_SENDER_TSPEC 12
#define class_ADSPEC 13
#define class_POLICY_DATA 14
#define class_CONFIRM 15
#define class_MAX 15

#define ctype_SESSION_ipv4 1
#define ctype_SESSION_ipv4GPI 3

#define SESSFLG_E_Police 0x01

  typedef struct {
    IN_ADDR sess_destaddr;
    UCHAR sess_protid;
    UCHAR sess_flags;
    USHORT sess_destport;
  } Session_IPv4;

  typedef struct {
    RsvpObjHdr sess_header;
    union {
      Session_IPv4 sess_ipv4;
    } sess_u;
  } RSVP_SESSION;

#define Sess4Addr sess_u.sess_ipv4.sess_destaddr
#define Sess4Port sess_u.sess_ipv4.sess_destport
#define Sess4Protocol sess_u.sess_ipv4.sess_protid
#define Sess4Flags sess_u.sess_ipv4.sess_flags

#define ctype_RSVP_HOP_ipv4 1

  typedef struct {
    IN_ADDR hop_ipaddr;
    ULONG hop_LIH;
  } Rsvp_Hop_IPv4;

  typedef struct {
    RsvpObjHdr hop_header;
    union {
      Rsvp_Hop_IPv4 hop_ipv4;
    } hop_u;
  } RSVP_HOP;

#define Hop4LIH hop_u.hop_ipv4.hop_LIH
#define Hop4Addr hop_u.hop_ipv4.hop_ipaddr

#define Opt_Share_mask 0x00000018
#define Opt_Distinct 0x00000008
#define Opt_Shared 0x00000010

#define Opt_SndSel_mask 0x00000007
#define Opt_Wildcard 0x00000001
#define Opt_Explicit 0x00000002

#define Style_is_Wildcard(p) (((p)&Opt_SndSel_mask)==Opt_Wildcard)
#define Style_is_Shared(p) (((p)&Opt_Share_mask)==Opt_Shared)

#define STYLE_WF Opt_Shared + Opt_Wildcard
#define STYLE_FF Opt_Distinct + Opt_Explicit
#define STYLE_SE Opt_Shared + Opt_Explicit

#define ctype_STYLE 1

  typedef struct {
    RsvpObjHdr style_header;
    ULONG style_word;
  } RESV_STYLE;

#define ctype_FILTER_SPEC_ipv4 1
#define ctype_FILTER_SPEC_ipv4GPI 4

  typedef struct {
    IN_ADDR filt_ipaddr;
    USHORT filt_unused;
    USHORT filt_port;
  } Filter_Spec_IPv4;

  typedef struct {
    IN_ADDR filt_ipaddr;
    ULONG filt_gpi;
  } Filter_Spec_IPv4GPI;

  typedef struct {
    RsvpObjHdr filt_header;
    union {
      Filter_Spec_IPv4 filt_ipv4;
      Filter_Spec_IPv4GPI filt_ipv4gpi;
    } filt_u;
  } FILTER_SPEC;

#define FilterSrcaddr filt_u.filt_ipv4.filt_ipaddr
#define FilterSrcport filt_u.filt_ipv4.filt_port

#define ctype_SENDER_TEMPLATE_ipv4 1
#define ctype_SENDER_TEMPLATE_ipv4GPI 4

  typedef FILTER_SPEC SENDER_TEMPLATE;

#define ctype_SCOPE_list_ipv4 1

  typedef struct {
    IN_ADDR scopl_ipaddr[1];
  } Scope_list_ipv4;

  typedef struct {
    RsvpObjHdr scopl_header;
    union {
      Scope_list_ipv4 scopl_ipv4;
    } scope_u;
  } RSVP_SCOPE;

#define Scope4Addr scope_u.scopl_ipv4.scopl_ipaddr
#define ScopeCnt(scp) ((ObjLength(scp)-sizeof(RsvpObjHdr))/sizeof(struct in_addr))
#define ScopeLen(cnt) (cnt*sizeof(struct in_addr)+sizeof(RsvpObjHdr))

#define ctype_ERROR_SPEC_ipv4 1

#define ERROR_SPECF_InPlace 0x01
#define ERROR_SPECF_NotGuilty 0x02

#define ERR_FORWARD_OK 0x8000
#define Error_Usage(x) (((x)>>12)&3)
#define ERR_Usage_globl 0x00
#define ERR_Usage_local 0x10
#define ERR_Usage_serv 0x11
#define ERR_global_mask 0x0fff

  typedef struct {
    struct in_addr errs_errnode;
    u_char errs_flags;
    UCHAR errs_code;
    USHORT errs_value;
  } Error_Spec_IPv4;

  typedef struct {
    RsvpObjHdr errs_header;
    union {
      Error_Spec_IPv4 errs_ipv4;
    } errs_u;
  } ERROR_SPEC;

#define errspec4_enode errs_u.errs_ipv4.errs_errnode
#define errspec4_code errs_u.errs_ipv4.errs_code
#define errspec4_value errs_u.errs_ipv4.errs_value
#define errspec4_flags errs_u.errs_ipv4.errs_flags

#define ctype_POLICY_DATA 1

  typedef struct {
    RsvpObjHdr PolicyObjHdr;
    USHORT usPeOffset;
    USHORT usReserved;
  } POLICY_DATA;

#define PD_HDR_LEN sizeof(POLICY_DATA)

  typedef struct {
    USHORT usPeLength;
    USHORT usPeType;
    UCHAR ucPeData[4];
  } POLICY_ELEMENT;

#define PE_HDR_LEN (2 *sizeof(USHORT))

#define GENERAL_INFO 1
#define GUARANTEED_SERV 2
#define PREDICTIVE_SERV 3
#define CONTROLLED_DELAY_SERV 4
#define CONTROLLED_LOAD_SERV 5
#define QUALITATIVE_SERV 6

  enum int_serv_wkp {
    IS_WKP_HOP_CNT = 4,IS_WKP_PATH_BW = 6,IS_WKP_MIN_LATENCY = 8,IS_WKP_COMPOSED_MTU = 10,IS_WKP_TB_TSPEC = 127,IS_WKP_Q_TSPEC = 128
  };

  typedef struct {
    UCHAR ismh_version;
    UCHAR ismh_unused;
    USHORT ismh_len32b;
  } IntServMainHdr;

#define INTSERV_VERS_MASK 0xf0
#define INTSERV_VERSION0 0
#define Intserv_Version(x) (((x)&INTSERV_VERS_MASK)>>4)
#define Intserv_Version_OK(x) (((x)->ismh_version&INTSERV_VERS_MASK)== INTSERV_VERSION0)
#define Intserv_Obj_size(x) (((IntServMainHdr *)(x))->ismh_len32b *4 + sizeof(IntServMainHdr) + sizeof(RsvpObjHdr))

#define ISSH_BREAK_BIT 0x80

  typedef struct {
    UCHAR issh_service;
    UCHAR issh_flags;
    USHORT issh_len32b;
  } IntServServiceHdr;

#define Issh_len32b(p) ((p)->issh_len32b)

#define ISPH_FLG_INV 0x80

  typedef struct {
    UCHAR isph_parm_num;
    UCHAR isph_flags;
    USHORT isph_len32b;
  } IntServParmHdr;

#define Next_Main_Hdr(p) (IntServMainHdr *)((ULONG *)(p)+1+(p)->ismh_len32b)
#define Next_Serv_Hdr(p) (IntServServiceHdr *)((ULONG *)(p)+1+(p)->issh_len32b)
#define Next_Parm_Hdr(p) (IntServParmHdr *)((ULONG *)(p)+1+(p)->isph_len32b)

  typedef struct {
    FLOAT TB_Tspec_r;
    FLOAT TB_Tspec_b;
    FLOAT TB_Tspec_p;
    ULONG TB_Tspec_m;
    ULONG TB_Tspec_M;
  } GenTspecParms;

  typedef struct {
    IntServServiceHdr gen_Tspec_serv_hdr;
    IntServParmHdr gen_Tspec_parm_hdr;
    GenTspecParms gen_Tspec_parms;
  } GenTspec;

#define gtspec_r gen_Tspec_parms.TB_Tspec_r
#define gtspec_b gen_Tspec_parms.TB_Tspec_b
#define gtspec_m gen_Tspec_parms.TB_Tspec_m
#define gtspec_M gen_Tspec_parms.TB_Tspec_M
#define gtspec_p gen_Tspec_parms.TB_Tspec_p
#define gtspec_parmno gen_Tspec_parm_hdr.isph_parm_num
#define gtspec_flags gen_Tspec_parm_hdr.isph_flags
#define gtspec_len (sizeof(GenTspec) - sizeof(IntServServiceHdr))

  typedef struct {
    ULONG TB_Tspec_M;
  } QualTspecParms;

  typedef struct {
    IntServServiceHdr qual_Tspec_serv_hdr;
    IntServParmHdr qual_Tspec_parm_hdr;
    QualTspecParms qual_Tspec_parms;
  } QualTspec;

  typedef struct {
    IntServServiceHdr Q_spec_serv_hdr;
    IntServParmHdr Q_spec_parm_hdr;
    QualTspecParms Q_spec_parms;
  } QualAppFlowSpec;

#define QAspec_M Q_spec_parms.TB_Tspec_M

  typedef struct {
    IntServMainHdr st_mh;
    union {
      GenTspec gen_stspec;
      QualTspec qual_stspec;
    } tspec_u;
  } IntServTspecBody;

#define ctype_SENDER_TSPEC 2

  typedef struct {
    RsvpObjHdr stspec_header;
    IntServTspecBody stspec_body;
  } SENDER_TSPEC;

  typedef struct {
    IntServServiceHdr CL_spec_serv_hdr;
    IntServParmHdr CL_spec_parm_hdr;
    GenTspecParms CL_spec_parms;
  } CtrlLoadFlowspec;

#define CLspec_r CL_spec_parms.TB_Tspec_r
#define CLspec_b CL_spec_parms.TB_Tspec_b
#define CLspec_p CL_spec_parms.TB_Tspec_p
#define CLspec_m CL_spec_parms.TB_Tspec_m
#define CLspec_M CL_spec_parms.TB_Tspec_M
#define CLspec_parmno CL_spec_parm_hdr.isph_parm_num
#define CLspec_flags CL_spec_parm_hdr.isph_flags
#define CLspec_len32b CL_spec_parm_hdr.isph_len32b
#define CLspec_len (sizeof(CtrlLoadFlowspec) - sizeof(IntServServiceHdr))

  enum {
    IS_GUAR_RSPEC = 130,GUAR_ADSPARM_C = 131,GUAR_ADSPARM_D = 132,GUAR_ADSPARM_Ctot = 133,GUAR_ADSPARM_Dtot = 134,GUAR_ADSPARM_Csum = 135,
    GUAR_ADSPARM_Dsum = 136
  };

  typedef struct {
    FLOAT Guar_R;
    ULONG Guar_S;
  } GuarRspec;

  typedef struct {
    IntServServiceHdr Guar_serv_hdr;
    IntServParmHdr Guar_Tspec_hdr;
    GenTspecParms Guar_Tspec_parms;
    IntServParmHdr Guar_Rspec_hdr;
    GuarRspec Guar_Rspec;
  } GuarFlowSpec;

#define Gspec_r Guar_Tspec_parms.TB_Tspec_r
#define Gspec_b Guar_Tspec_parms.TB_Tspec_b
#define Gspec_p Guar_Tspec_parms.TB_Tspec_p
#define Gspec_m Guar_Tspec_parms.TB_Tspec_m
#define Gspec_M Guar_Tspec_parms.TB_Tspec_M
#define Gspec_R Guar_Rspec.Guar_R
#define Gspec_S Guar_Rspec.Guar_S
#define Gspec_T_parmno Guar_Tspec_hdr.isph_parm_num
#define Gspec_T_flags Guar_Tspec_hdr.isph_flags
#define Gspec_R_parmno Guar_Rspec_hdr.isph_parm_num
#define Gspec_R_flags Guar_Rspec_hdr.isph_flags
#define Gspec_len (sizeof(GuarFlowSpec) - sizeof(IntServServiceHdr))

  typedef struct {
    IntServMainHdr spec_mh;
    union {
      CtrlLoadFlowspec CL_spec;
      GuarFlowSpec G_spec;
      QualAppFlowSpec Q_spec;
    } spec_u;
  } IntServFlowSpec;

#define ISmh_len32b spec_mh.ismh_len32b
#define ISmh_version spec_mh.ismh_version
#define ISmh_unused spec_mh.ismh_unused

#define ctype_FLOWSPEC_Intserv0 2

  typedef struct {
    RsvpObjHdr flow_header;
    IntServFlowSpec flow_body;
  } IS_FLOWSPEC;

  typedef struct flow_desc {
    union {
      SENDER_TSPEC *stspec;
      IS_FLOWSPEC *isflow;
    } u1;
    union {
      SENDER_TEMPLATE *stemp;
      FILTER_SPEC *fspec;
    } u2;
  } FLOW_DESC;

#define FdSenderTspec u1.stspec
#define FdIsFlowSpec u1.isflow

#define FdSenderTemplate u2.stemp
#define FdFilterSpec u2.fspec

#define ctype_ADSPEC_INTSERV 2

  typedef struct {
    IntServServiceHdr Gads_serv_hdr;
    IntServParmHdr Gads_Ctot_hdr;
    ULONG Gads_Ctot;
    IntServParmHdr Gads_Dtot_hdr;
    ULONG Gads_Dtot;
    IntServParmHdr Gads_Csum_hdr;
    ULONG Gads_Csum;
    IntServParmHdr Gads_Dsum_hdr;
    ULONG Gads_Dsum;
  } Gads_parms_t;

  typedef struct {
    IntServServiceHdr gen_parm_hdr;
    IntServParmHdr gen_parm_hopcnt_hdr;
    ULONG gen_parm_hopcnt;
    IntServParmHdr gen_parm_pathbw_hdr;
    FLOAT gen_parm_path_bw;
    IntServParmHdr gen_parm_minlat_hdr;
    ULONG gen_parm_min_latency;
    IntServParmHdr gen_parm_compmtu_hdr;
    ULONG gen_parm_composed_MTU;
  } GenAdspecParams;

  typedef struct {
    IntServMainHdr adspec_mh;
    GenAdspecParams adspec_genparms;
  } IS_ADSPEC_BODY;

#define GEN_ADSPEC_LEN (sizeof(Object_header) + sizeof(IS_adsbody_t))

  typedef struct {
    RsvpObjHdr adspec_header;
    IS_ADSPEC_BODY adspec_body;
  } ADSPEC;

#define RSVP_PATH 1
#define RSVP_RESV 2
#define RSVP_PATH_ERR 3
#define RSVP_RESV_ERR 4
#define RSVP_PATH_TEAR 5
#define RSVP_RESV_TEAR 6

#define RSVP_Err_NONE 0
#define RSVP_Erv_Nonev 0

#define RSVP_Err_ADMISSION 1

#define RSVP_Erv_Other 0
#define RSVP_Erv_DelayBnd 1
#define RSVP_Erv_Bandwidth 2
#define RSVP_Erv_MTU 3

#define RSVP_Erv_Flow_Rate 0x8001
#define RSVP_Erv_Bucket_szie 0x8002
#define RSVP_Erv_Peak_Rate 0x8003
#define RSVP_Erv_Min_Policied_size 0x8004

#define RSVP_Err_POLICY 2

#define POLICY_ERRV_NO_MORE_INFO 1
#define POLICY_ERRV_UNSUPPORTED_CREDENTIAL_TYPE 2
#define POLICY_ERRV_INSUFFICIENT_PRIVILEGES 3
#define POLICY_ERRV_EXPIRED_CREDENTIALS 4
#define POLICY_ERRV_IDENTITY_CHANGED 5

#define POLICY_ERRV_UNKNOWN 0

#define POLICY_ERRV_GLOBAL_DEF_FLOW_COUNT 1
#define POLICY_ERRV_GLOBAL_GRP_FLOW_COUNT 2
#define POLICY_ERRV_GLOBAL_USER_FLOW_COUNT 3
#define POLICY_ERRV_GLOBAL_UNAUTH_USER_FLOW_COUNT 4
#define POLICY_ERRV_SUBNET_DEF_FLOW_COUNT 5
#define POLICY_ERRV_SUBNET_GRP_FLOW_COUNT 6
#define POLICY_ERRV_SUBNET_USER_FLOW_COUNT 7
#define POLICY_ERRV_SUBNET_UNAUTH_USER_FLOW_COUNT 8

#define POLICY_ERRV_GLOBAL_DEF_FLOW_DURATION 9
#define POLICY_ERRV_GLOBAL_GRP_FLOW_DURATION 10
#define POLICY_ERRV_GLOBAL_USER_FLOW_DURATION 11
#define POLICY_ERRV_GLOBAL_UNAUTH_USER_FLOW_DURATION 12
#define POLICY_ERRV_SUBNET_DEF_FLOW_DURATION 13
#define POLICY_ERRV_SUBNET_GRP_FLOW_DURATION 14
#define POLICY_ERRV_SUBNET_USER_FLOW_DURATION 15
#define POLICY_ERRV_SUBNET_UNAUTH_USER_FLOW_DURATION 16

#define POLICY_ERRV_GLOBAL_DEF_FLOW_RATE 17
#define POLICY_ERRV_GLOBAL_GRP_FLOW_RATE 18
#define POLICY_ERRV_GLOBAL_USER_FLOW_RATE 19
#define POLICY_ERRV_GLOBAL_UNAUTH_USER_FLOW_RATE 20
#define POLICY_ERRV_SUBNET_DEF_FLOW_RATE 21
#define POLICY_ERRV_SUBNET_GRP_FLOW_RATE 22
#define POLICY_ERRV_SUBNET_USER_FLOW_RATE 23
#define POLICY_ERRV_SUBNET_UNAUTH_USER_FLOW_RATE 24

#define POLICY_ERRV_GLOBAL_DEF_PEAK_RATE 25
#define POLICY_ERRV_GLOBAL_GRP_PEAK_RATE 26
#define POLICY_ERRV_GLOBAL_USER_PEAK_RATE 27
#define POLICY_ERRV_GLOBAL_UNAUTH_USER_PEAK_RATE 28
#define POLICY_ERRV_SUBNET_DEF_PEAK_RATE 29
#define POLICY_ERRV_SUBNET_GRP_PEAK_RATE 30
#define POLICY_ERRV_SUBNET_USER_PEAK_RATE 31
#define POLICY_ERRV_SUBNET_UNAUTH_USER_PEAK_RATE 32

#define POLICY_ERRV_GLOBAL_DEF_SUM_FLOW_RATE 33
#define POLICY_ERRV_GLOBAL_GRP_SUM_FLOW_RATE 34
#define POLICY_ERRV_GLOBAL_USER_SUM_FLOW_RATE 35
#define POLICY_ERRV_GLOBAL_UNAUTH_USER_SUM_FLOW_RATE 36
#define POLICY_ERRV_SUBNET_DEF_SUM_FLOW_RATE 37
#define POLICY_ERRV_SUBNET_GRP_SUM_FLOW_RATE 38
#define POLICY_ERRV_SUBNET_USER_SUM_FLOW_RATE 39
#define POLICY_ERRV_SUBNET_UNAUTH_USER_SUM_FLOW_RATE 40

#define POLICY_ERRV_GLOBAL_DEF_SUM_PEAK_RATE 41
#define POLICY_ERRV_GLOBAL_GRP_SUM_PEAK_RATE 42
#define POLICY_ERRV_GLOBAL_USER_SUM_PEAK_RATE 43
#define POLICY_ERRV_GLOBAL_UNAUTH_USER_SUM_PEAK_RATE 44
#define POLICY_ERRV_SUBNET_DEF_SUM_PEAK_RATE 45
#define POLICY_ERRV_SUBNET_GRP_SUM_PEAK_RATE 46
#define POLICY_ERRV_SUBNET_USER_SUM_PEAK_RATE 47
#define POLICY_ERRV_SUBNET_UNAUTH_USER_SUM_PEAK_RATE 48

#define POLICY_ERRV_UNKNOWN_USER 49
#define POLICY_ERRV_NO_PRIVILEGES 50
#define POLICY_ERRV_EXPIRED_USER_TOKEN 51
#define POLICY_ERRV_NO_RESOURCES 52
#define POLICY_ERRV_PRE_EMPTED 53
#define POLICY_ERRV_USER_CHANGED 54
#define POLICY_ERRV_NO_ACCEPTS 55
#define POLICY_ERRV_NO_MEMORY 56
#define POLICY_ERRV_CRAZY_FLOWSPEC 57

#define RSVP_Err_NO_PATH 3
#define RSVP_Err_NO_SENDER 4
#define RSVP_Err_BAD_STYLE 5
#define RSVP_Err_UNKNOWN_STYLE 6
#define RSVP_Err_BAD_DSTPORT 7
#define RSVP_Err_BAD_SNDPORT 8
#define RSVP_Err_AMBIG_FILTER 9
#define RSVP_Err_PREEMPTED 12
#define RSVP_Err_UNKN_OBJ_CLASS 13
#define RSVP_Err_UNKNOWN_CTYPE 14
#define RSVP_Err_API_ERROR 20
#define RSVP_Err_TC_ERROR 21

#define RSVP_Erv_Conflict_Serv 01
#define RSVP_Erv_No_Serv 02
#define RSVP_Erv_Crazy_Flowspec 03
#define RSVP_Erv_Crazy_Tspec 04

#define RSVP_Err_TC_SYS_ERROR 22

#define RSVP_Err_RSVP_SYS_ERROR 23

#define RSVP_Erv_MEMORY 1
#define RSVP_Erv_API 2

#define LPM_PE_USER_IDENTITY 2
#define LPM_PE_APP_IDENTITY 3

#define ERROR_NO_MORE_INFO 1
#define UNSUPPORTED_CREDENTIAL_TYPE 2
#define INSUFFICIENT_PRIVILEGES 3
#define EXPIRED_CREDENTIAL 4
#define IDENTITY_CHANGED 5

  typedef struct {
    USHORT usIdErrLength;
    UCHAR ucAType;
    UCHAR ucSubType;
    USHORT usReserved;
    USHORT usIdErrorValue;
    UCHAR ucIdErrData[4];
  } ID_ERROR_OBJECT;

#define ID_ERR_OBJ_HDR_LEN (sizeof(ID_ERROR_OBJECT) - 4 *sizeof(UCHAR))

  DECLARE_HANDLE(LPM_HANDLE);
  DECLARE_HANDLE(RHANDLE);

  typedef ULONG LPV;
  typedef USHORT PETYPE;

#define LPM_OK 0

  typedef int MSG_TYPE;

  typedef struct rsvpmsgobjs {
    MSG_TYPE RsvpMsgType;
    RSVP_SESSION *pRsvpSession;
    RSVP_HOP *pRsvpFromHop;
    RSVP_HOP *pRsvpToHop;
    RESV_STYLE *pResvStyle;
    RSVP_SCOPE *pRsvpScope;
    int FlowDescCount;
    FLOW_DESC *pFlowDescs;
    int PdObjectCount;
    POLICY_DATA **ppPdObjects;
    ERROR_SPEC *pErrorSpec;
    ADSPEC *pAdspec;
  } RSVP_MSG_OBJS;

  typedef void *(WINAPI *PALLOCMEM)(DWORD Size);
  typedef void (WINAPI *PFREEMEM)(void *pv);

  typedef struct policy_decision {
    LPV lpvResult;
    WORD wPolicyErrCode;
    WORD wPolicyErrValue;
  } POLICY_DECISION;

  typedef ULONG *(CALLBACK *CBADMITRESULT)(LPM_HANDLE LpmHandle,RHANDLE RequestHandle,ULONG ulPcmActionFlags,int LpmError,int PolicyDecisionsCount,POLICY_DECISION *pPolicyDecisions);
  typedef ULONG *(CALLBACK *CBGETRSVPOBJECTS)(LPM_HANDLE LpmHandle,RHANDLE RequestHandle,int LpmError,int RsvpObjectsCount,RsvpObjHdr **ppRsvpObjects);

#define INV_LPM_HANDLE 1
#define LPM_TIME_OUT 2
#define INV_REQ_HANDLE 3
#define DUP_RESULTS 4
#define INV_RESULTS 5

  typedef struct lpminitinfo {
    DWORD PcmVersionNumber;
    DWORD ResultTimeLimit;
    int ConfiguredLpmCount;
    PALLOCMEM AllocMemory;
    PFREEMEM FreeMemory;
    CBADMITRESULT PcmAdmitResultCallback;
    CBGETRSVPOBJECTS GetRsvpObjectsCallback;
  } LPM_INIT_INFO;

#define LPM_PE_ALL_TYPES 0
#define LPM_API_VERSION_1 1

#define PCM_VERSION_1 1

  ULONG WINAPI LPM_Initialize(LPM_HANDLE LpmHandle,LPM_INIT_INFO *pLpmInitInfo,DWORD *pLpmVersionNumber,PETYPE *pSupportedPeType,VOID *Reserved);
  ULONG WINAPI LPM_Deinitialize(LPM_HANDLE LpmHandle);

#define LPV_RESERVED 0
#define LPV_MIN_PRIORITY 1
#define LPV_MAX_PRIORITY 0xFF00
#define LPV_DROP_MSG 0xFFFD
#define LPV_DONT_CARE 0xFFFE
#define LPV_REJECT 0xFFFF

#define FORCE_IMMEDIATE_REFRESH 1

#define LPM_RESULT_READY 0
#define LPM_RESULT_DEFER 1

  ULONG WINAPI LPM_AdmitRsvpMsg(RHANDLE PcmReqHandle,RSVP_HOP *pRecvdIntf,RSVP_MSG_OBJS *pRsvpMsgObjs,int RcvdRsvpMsgLength,UCHAR *RcvdRsvpMsg,ULONG *pulPcmActionFlags,POLICY_DECISION *pPolicyDecisions,void *Reserved);
  ULONG WINAPI LPM_GetRsvpObjects(RHANDLE PcmReqHandle,ULONG MaxPdSize,RSVP_HOP *SendingIntfAddr,RSVP_MSG_OBJS *pRsvpMsgObjs,int *pRsvpObjectsCount,RsvpObjHdr ***pppRsvpObjects,void *Reserved);

#define RCVD_PATH_TEAR 1
#define RCVD_RESV_TEAR 2
#define ADM_CTRL_FAILED 3
#define STATE_TIMEOUT 4
#define FLOW_DURATION 5

  VOID WINAPI LPM_DeleteState(RSVP_HOP *pRcvdIfAddr,MSG_TYPE RsvpMsgType,RSVP_SESSION *pRsvpSession,RSVP_HOP *pRsvpFromHop,RESV_STYLE *pResvStyle,int FilterSpecCount,FILTER_SPEC **ppFilterSpecList,int TearDownReason);

  typedef struct lpmiptable {
    ULONG ulIfIndex;
    ULONG MediaType;
    IN_ADDR IfIpAddr;
    IN_ADDR IfNetMask;
  } LPMIPTABLE;

  WINBOOL WINAPI LPM_IpAddressTable (ULONG cIpAddrTable,LPMIPTABLE *pIpAddrTable);

#define RESOURCES_ALLOCATED 1
#define RESOURCES_MODIFIED 2

  VOID WINAPI LPM_CommitResv (RSVP_SESSION *RsvpSession,RSVP_HOP *FlowInstalledIntf,RESV_STYLE *RsvpStyle,int FilterSpecCount,FILTER_SPEC **ppFilterSpecList,IS_FLOWSPEC *pMergedFlowSpec,ULONG CommitDecision);

#ifdef __cplusplus
}
#endif
#endif
