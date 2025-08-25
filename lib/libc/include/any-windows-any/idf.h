/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __IDF_H__
#define __IDF_H__

typedef struct tag_IDFHEADER {
  DWORD cbStruct;
  DWORD dwVersion;
  DWORD dwCreator;
  DWORD cbInstID;
  BYTE abInstID[1];
} IDFHEADER,*PIDFHEADER,*LPIDFHEADER;

typedef struct tag_IDFINSTINFO {
  DWORD cbStruct;
  DWORD dwManufactID;
  DWORD dwProductID;
  DWORD dwRevision;
  DWORD cbManufactASCII;
  DWORD cbManufactUNICODE;
  DWORD cbProductASCII;
  DWORD cbProductUNICODE;
  BYTE abData[1];
} IDFINSTINFO,*LPIDFINSTINFO;

typedef struct tag_IDFINSTCAPS {
  DWORD cbStruct;
  DWORD fdwFlags;
  DWORD dwBasicChannel;
  DWORD cNumChannels;
  DWORD cInstrumentPolyphony;
  DWORD cChannelPolyphony;
} IDFINSTCAPS,*PIDFINSTCAPS,*LPIDFINSTCAPS;

#define IDFINSTCAPS_F_GENERAL_MIDI 0x00000001
#define IDFINSTCAPS_F_SYSTEMEXCLUSIVE 0x00000002

typedef struct tag_IDFCHANNELHDR {
  DWORD cbStruct;
  DWORD dwGeneralMask;
  DWORD dwDrumMask;
  DWORD dwReserved;
  DWORD fdwFlags;
} IDFCHANNELHDR,*PIDFCHANNELHDR,*LPIDFCHANNELHDR;

#define IDFCHANNELHDR_F_GENERAL_MIDI 0x00000001

typedef struct tag_IDFCHANNELINFO {
  DWORD cbStruct;
  DWORD dwChannel;
  DWORD cbInitData;
  BYTE abData[];
} IDFCHANNELINFO,*PIDFCHANNELINFO,*LPIDFCHANNELINFO;

typedef struct tag_IDFPATCHMAPHDR {
  DWORD cbStruct;
  BYTE abPatchMap[128];
} IDFPATCHMAPHDR,*PIDFPATCHMAPHDR,*LPIDFPATCHMAPHDR;

typedef struct tag_IDFKEYMAPHDR {
  DWORD cbStruct;
  DWORD cNumKeyMaps;
  DWORD cbKeyMap;
} IDFKEYMAPHDR,*PIDFKEYMAPHDR,*LPIDFKEYMAPHDR;

typedef struct tag_IDFKEYMAP {
  DWORD cbStruct;
  BYTE abKeyMap[128];
} IDFKEYMAP,*PIDFKEYMAP,*LPIDFKEYMAP;

#endif
