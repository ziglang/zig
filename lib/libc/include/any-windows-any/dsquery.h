/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __dsquery_h
#define __dsquery_h

DEFINE_GUID(CLSID_DsQuery,0x8a23e65e,0x31c2,0x11d0,0x89,0x1c,0x0,0xa0,0x24,0xab,0x2d,0xbb);
DEFINE_GUID(CLSID_DsFindObjects,0x83ee3fe1,0x57d9,0x11d0,0xb9,0x32,0x0,0xa0,0x24,0xab,0x2d,0xbb);
DEFINE_GUID(CLSID_DsFindPeople,0x83ee3fe2,0x57d9,0x11d0,0xb9,0x32,0x0,0xa0,0x24,0xab,0x2d,0xbb);
DEFINE_GUID(CLSID_DsFindPrinter,0xb577f070,0x7ee2,0x11d0,0x91,0x3f,0x0,0xaa,0x0,0xc1,0x6e,0x65);
DEFINE_GUID(CLSID_DsFindComputer,0x16006700,0x87ad,0x11d0,0x91,0x40,0x0,0xaa,0x0,0xc1,0x6e,0x65);
DEFINE_GUID(CLSID_DsFindVolume,0xc1b3cbf1,0x886a,0x11d0,0x91,0x40,0x0,0xaa,0x0,0xc1,0x6e,0x65);
DEFINE_GUID(CLSID_DsFindContainer,0xc1b3cbf2,0x886a,0x11d0,0x91,0x40,0x0,0xaa,0x0,0xc1,0x6e,0x65);
DEFINE_GUID(CLSID_DsFindAdvanced,0x83ee3fe3,0x57d9,0x11d0,0xb9,0x32,0x0,0xa0,0x24,0xab,0x2d,0xbb);
DEFINE_GUID(CLSID_DsFindDomainController,0x538c7b7e,0xd25e,0x11d0,0x97,0x42,0x0,0xa0,0xc9,0x6,0xaf,0x45);
DEFINE_GUID(CLSID_DsFindFrsMembers,0x94ce4b18,0xb3d3,0x11d1,0xb9,0xb4,0x0,0xc0,0x4f,0xd8,0xd5,0xb0);

#ifndef GUID_DEFS_ONLY
#define DSQPF_NOSAVE 0x00000001
#define DSQPF_SAVELOCATION 0x00000002
#define DSQPF_SHOWHIDDENOBJECTS 0x00000004
#define DSQPF_ENABLEADMINFEATURES 0x00000008
#define DSQPF_ENABLEADVANCEDFEATURES 0x00000010
#define DSQPF_HASCREDENTIALS 0x00000020
#define DSQPF_NOCHOOSECOLUMNS 0x00000040

typedef struct {
  DWORD cbStruct;
  DWORD dwFlags;
  LPWSTR pDefaultScope;
  LPWSTR pDefaultSaveLocation;
  LPWSTR pUserName;
  LPWSTR pPassword;
  LPWSTR pServer;
} DSQUERYINITPARAMS,*LPDSQUERYINITPARAMS;

#define CFSTR_DSQUERYPARAMS TEXT("DsQueryParameters")

#define DSCOLUMNPROP_ADSPATH ((LONG)(-1))
#define DSCOLUMNPROP_OBJECTCLASS ((LONG)(-2))

typedef struct {
  DWORD dwFlags;
  INT fmt;
  INT cx;
  INT idsName;
  LONG offsetProperty;
  DWORD dwReserved;
} DSCOLUMN,*LPDSCOLUMN;

typedef struct {
  DWORD cbStruct;
  DWORD dwFlags;
  HINSTANCE hInstance;
  LONG offsetQuery;
  LONG iColumns;
  DWORD dwReserved;
  DSCOLUMN aColumns[1];
} DSQUERYPARAMS,*LPDSQUERYPARAMS;

#define CFSTR_DSQUERYSCOPE TEXT("DsQueryScope")

typedef struct {
  DWORD cbStruct;
  LONG cClasses;
  DWORD offsetClass[1];
} DSQUERYCLASSLIST,*LPDSQUERYCLASSLIST;

#define DSQPM_GETCLASSLIST (CQPM_HANDLERSPECIFIC+0)
#define DSQPM_HELPTOPICS (CQPM_HANDLERSPECIFIC+1)
#endif

#endif
