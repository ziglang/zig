/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef WS2DNET_H
#define WS2DNET_H

#include <winsock2.h>

#pragma pack(push,ws2dnet,1)

#define DNPROTO_NSP 1
#define DNPROTO_RAW 255

#define DN_MAXADDL 20
#define DN_ADDL 2
#define DN_MAXOPTL 16
#define DN_MAXOBJL 16
#define DN_MAXACCL 39
#define DN_MAXALIASL 128
#define DN_MAXNODEL 7

#define WS2API_DECNET_dnet_addr 1
#define WS2API_DECNET_dnet_eof 2
#define WS2API_DECNET_dnet_getacc 3
#define WS2API_DECNET_dnet_getalias 4
#define WS2API_DECNET_dnet_htoa 5
#define WS2API_DECNET_dnet_ntoa 6
#define WS2API_DECNET_getnodeadd 7
#define WS2API_DECNET_getnodebyaddr 8
#define WS2API_DECNET_getnodebyname 9
#define WS2API_DECNET_getnodename 10
#define WS2API_DECNET_MAX 10

typedef struct dn_naddr {
  unsigned short a_len;
  unsigned char a_addr[DN_MAXADDL];
} DNNADDR,*LPDNNADDR;

typedef struct sockaddr_dn {
  unsigned short sdn_family;
  unsigned char sdn_flags;
  unsigned char sdn_objnum;
  unsigned short sdn_objnamel;
  char sdn_objname[DN_MAXOBJL];
  struct dn_naddr sdn_add;
} SOCKADDRDN,*LPSOCKADDRDN;

#define sdn_nodeaddrl sdn_add.a_len
#define sdn_nodeaddr sdn_add.a_addr

#define DNOBJECT_FAL 17
#define DNOBJECT_NICE 19
#define DNOBJECT_DTERM 23
#define DNOBJECT_MIRROR 25
#define DNOBJECT_EVR 26
#define DNOBJECT_MAIL11 27
#define DNOBJECT_PHONE 29
#define DNOBJECT_CTERM 42
#define DNOBJECT_DTR 63

typedef struct nodeent_f {
  char *n_name;
  unsigned short n_addrtype;
  unsigned short n_length;
  unsigned char *n_addr;
  unsigned char *n_params;
  unsigned char n_reserved[16];
} NODEENTF,*LPNODEENTF;

typedef struct optdata_dn {
  unsigned short opt_status;
  unsigned short opt_optl;
  unsigned char opt_data[DN_MAXOPTL];
} OPTDATADN,*LPOPTDATADN;

typedef struct accessdata_dn {
  unsigned short acc_accl;
  unsigned char acc_acc[DN_MAXACCL+1];
  unsigned short acc_passl;
  unsigned char acc_pass[DN_MAXACCL+1];
  unsigned short acc_userl;
  unsigned char acc_user[DN_MAXACCL+1];
} ACCESSDATADN,*LPACCESSDATADN;

typedef struct calldata_dn {
  struct optdata_dn optdata_dn;
  struct accessdata_dn accessdata_dn;
} CALLDATADN,*LPCALLDATADN;

typedef struct dnet_accent {
  unsigned char dac_status;
  unsigned char dac_type;
  char dac_username[DN_MAXACCL+1];
  char dac_password[DN_MAXACCL+1];
} DNETACCENT,*LPDNETACCENT;

#define DN_NONE 0x00
#define DN_RO 0x01
#define DN_WO 0x02
#define DN_RW 0x03

typedef struct linkinfo_dn {
  unsigned short idn_segsize;
  unsigned char idn_linkstate;
} LINKINFODN,*LPLINKINFODN;

#define SO_LINKINFO 7
#define LL_INACTIVE 0
#define LL_CONNECTING 1
#define LL_RUNNING 2
#define LL_DISCONNECTING 3

#pragma pack(pop,ws2dnet)

struct dn_naddr *WSAAPI dnet_addr(const char *);
int WSAAPI dnet_eof(SOCKET);
struct dnet_accent *WSAAPI dnet_getacc(const struct dnet_accent *);
char *WSAAPI dnet_getalias(const char *);
char *WSAAPI dnet_htoa(const struct dn_naddr *);
char *WSAAPI dnet_ntoa(const struct dn_naddr *);
struct dn_naddr *WSAAPI getnodeadd(void);
struct nodeent_f *WSAAPI getnodebyaddr(const unsigned char *addr,int,int);
struct nodeent_f *WSAAPI getnodebyname(const char *);
char *WSAAPI getnodename(void);

typedef struct dn_naddr *(WSAAPI *LPDNETADDR)(const char *);
typedef int (WSAAPI *LPDNETEOF)(SOCKET);
typedef struct dnet_accent *(WSAAPI *LPDNETGETACC)(const struct dnet_accent *);
typedef char *(WSAAPI *LPDNETGETALIAS)(const char *);
typedef char *(WSAAPI *LPDNETHTOA)(const struct dn_naddr *);
typedef char *(WSAAPI *LPDNETNTOA)(const struct dn_naddr *);
typedef struct dn_naddr *(WSAAPI *LPGETNODEADD)(void);
typedef struct nodeent_f *(WSAAPI *LPGETNODEBYADDR)(const unsigned char *addr,int,int);
typedef struct nodeent_f *(WSAAPI *LPGETNODEBYNAME)(const char *);
typedef char *(WSAAPI *LPGETNODENAME)(void);
#endif
