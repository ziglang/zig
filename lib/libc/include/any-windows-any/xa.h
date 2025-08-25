/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef XA_H
#define XA_H

#define XIDDATASIZE 128
#define MAXGTRIDSIZE 64
#define MAXBQUALSIZE 64

#ifndef _XID_T_DEFINED
#define _XID_T_DEFINED
struct xid_t {
  __LONG32 formatID;
  __LONG32 gtrid_length;
  __LONG32 bqual_length;
  char data[XIDDATASIZE];
};
#endif

typedef struct xid_t XID;

#ifdef _TMPROTOTYPES
extern int __cdecl ax_reg(int,XID *,__LONG32);
extern int __cdecl ax_unreg(int,__LONG32);
#else
extern int __cdecl ax_reg();
extern int __cdecl ax_unreg();
#endif

#define RMNAMESZ 32

#define MAXINFOSIZE 256

#ifndef _XA_SWITCH_T_DEFINED
#define _XA_SWITCH_T_DEFINED
struct xa_switch_t {
  char name[RMNAMESZ];
  __LONG32 flags;
  __LONG32 version;
  int (__cdecl *xa_open_entry)(char *,int,__LONG32);
  int (__cdecl *xa_close_entry)(char *,int,__LONG32);
  int (__cdecl *xa_start_entry)(XID *,int,__LONG32);
  int (__cdecl *xa_end_entry)(XID *,int,__LONG32);
  int (__cdecl *xa_rollback_entry)(XID *,int,__LONG32);
  int (__cdecl *xa_prepare_entry)(XID *,int,__LONG32);
  int (__cdecl *xa_commit_entry)(XID *,int,__LONG32);
  int (__cdecl *xa_recover_entry)(XID *,__LONG32,int,__LONG32);

  int (__cdecl *xa_forget_entry)(XID *,int,__LONG32);
  int (__cdecl *xa_complete_entry)(int *,int *,int,__LONG32);

};

typedef struct xa_switch_t xa_switch_t;
#endif

#define TMNOFLAGS __MSABI_LONG(0x00000000)
#define TMREGISTER __MSABI_LONG(0x00000001)
#define TMNOMIGRATE __MSABI_LONG(0x00000002)
#define TMUSEASYNC __MSABI_LONG(0x00000004)

#define TMASYNC __MSABI_LONG(0x80000000)
#define TMONEPHASE __MSABI_LONG(0x40000000)
#define TMFAIL __MSABI_LONG(0x20000000)
#define TMNOWAIT __MSABI_LONG(0x10000000)
#define TMRESUME __MSABI_LONG(0x08000000)
#define TMSUCCESS __MSABI_LONG(0x04000000)
#define TMSUSPEND __MSABI_LONG(0x02000000)
#define TMSTARTRSCAN __MSABI_LONG(0x01000000)
#define TMENDRSCAN __MSABI_LONG(0x00800000)
#define TMMULTIPLE __MSABI_LONG(0x00400000)
#define TMJOIN __MSABI_LONG(0x00200000)
#define TMMIGRATE __MSABI_LONG(0x00100000)

#define TM_JOIN 2
#define TM_RESUME 1
#define TM_OK 0
#define TMER_TMERR (-1)
#define TMER_INVAL (-2)
#define TMER_PROTO (-3)

#define XA_RBBASE 100
#define XA_RBROLLBACK XA_RBBASE
#define XA_RBCOMMFAIL XA_RBBASE+1
#define XA_RBDEADLOCK XA_RBBASE+2
#define XA_RBINTEGRITY XA_RBBASE+3
#define XA_RBOTHER XA_RBBASE+4
#define XA_RBPROTO XA_RBBASE+5
#define XA_RBTIMEOUT XA_RBBASE+6
#define XA_RBTRANSIENT XA_RBBASE+7
#define XA_RBEND XA_RBTRANSIENT

#define XA_NOMIGRATE 9
#define XA_HEURHAZ 8
#define XA_HEURCOM 7
#define XA_HEURRB 6
#define XA_HEURMIX 5
#define XA_RETRY 4
#define XA_RDONLY 3
#define XA_OK 0
#define XAER_ASYNC (-2)
#define XAER_RMERR (-3)
#define XAER_NOTA (-4)
#define XAER_INVAL (-5)
#define XAER_PROTO (-6)
#define XAER_RMFAIL (-7)
#define XAER_DUPID (-8)
#define XAER_OUTSIDE (-9)

typedef int (__cdecl *XA_OPEN_EPT)(char *,int,__LONG32);
typedef int (__cdecl *XA_CLOSE_EPT)(char *,int,__LONG32);
typedef int (__cdecl *XA_START_EPT)(XID *,int,__LONG32);
typedef int (__cdecl *XA_END_EPT)(XID *,int,__LONG32);
typedef int (__cdecl *XA_ROLLBACK_EPT)(XID *,int,__LONG32);
typedef int (__cdecl *XA_PREPARE_EPT)(XID *,int,__LONG32);
typedef int (__cdecl *XA_COMMIT_EPT)(XID *,int,__LONG32);
typedef int (__cdecl *XA_RECOVER_EPT)(XID *,__LONG32,int,__LONG32);
typedef int (__cdecl *XA_FORGET_EPT)(XID *,int,__LONG32);
typedef int (__cdecl *XA_COMPLETE_EPT)(int *,int *,int,__LONG32);

#endif
