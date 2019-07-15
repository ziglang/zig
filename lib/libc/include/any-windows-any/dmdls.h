/* DirectMusic DLS Download Definitions
 *
 *  Copyright (C) 2003-2004 Rok Mandeljc
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */
 
#ifndef __WINE_DMUSIC_DLS_H
#define __WINE_DMUSIC_DLS_H

#include <dls1.h>

/*****************************************************************************
 * Typedef definitions
 */
typedef LONG GCENT;
typedef LONG PCENT;
typedef LONG PERCENT;
typedef LONG TCENT;

typedef LONGLONG REFERENCE_TIME, *LPREFERENCE_TIME;

/*****************************************************************************
 * FOURCC definition
 */
#ifndef mmioFOURCC
typedef DWORD FOURCC;
#define mmioFOURCC(ch0,ch1,ch2,ch3) \
	((DWORD)(BYTE)(ch0) | ((DWORD)(BYTE)(ch1) << 8) | \
	((DWORD)(BYTE)(ch2) << 16) | ((DWORD)(BYTE)(ch3) << 24 ))
#endif

/*****************************************************************************
 * Flags
 */
#define DMUS_DEFAULT_SIZE_OFFSETTABLE 0x1

#define DMUS_DOWNLOADINFO_INSTRUMENT       0x1
#define DMUS_DOWNLOADINFO_WAVE             0x2
#define DMUS_DOWNLOADINFO_INSTRUMENT2      0x3
#define DMUS_DOWNLOADINFO_WAVEARTICULATION 0x4
#define DMUS_DOWNLOADINFO_STREAMINGWAVE    0x5
#define DMUS_DOWNLOADINFO_ONESHOTWAVE      0x6

#define DMUS_INSTRUMENT_GM_INSTRUMENT 0x1

#define DMUS_MIN_DATA_SIZE 0x4       

/*****************************************************************************
 * Structures
 */
/* typedef definitions */
typedef struct _DMUS_DOWNLOADINFO   DMUS_DOWNLOADINFO,   *LPDMUS_DOWNLOADINFO;
typedef struct _DMUS_OFFSETTABLE    DMUS_OFFSETTABLE,    *LPDMUS_OFFSETTABLE;
typedef struct _DMUS_INSTRUMENT     DMUS_INSTRUMENT,     *LPDMUS_INSTRUMENT;
typedef struct _DMUS_REGION         DMUS_REGION,         *LPDMUS_REGION;
typedef struct _DMUS_LFOPARAMS      DMUS_LFOPARAMS,      *LPDMUS_LFOPARAMS;
typedef struct _DMUS_VEGPARAMS      DMUS_VEGPARAMS,      *LPDMUS_VEGPARAMS;
typedef struct _DMUS_PEGPARAMS      DMUS_PEGPARAMS,      *LPDMUS_PEGPARAMS;
typedef struct _DMUS_MSCPARAMS      DMUS_MSCPARAMS,      *LPDMUS_MSCPARAMS;
typedef struct _DMUS_ARTICPARAMS    DMUS_ARTICPARAMS,    *LPDMUS_ARTICPARAMS;
typedef struct _DMUS_ARTICULATION   DMUS_ARTICULATION,   *LPDMUS_ARTICULATION;
typedef struct _DMUS_ARTICULATION2  DMUS_ARTICULATION2,  *LPDMUS_ARTICULATION2;
typedef struct _DMUS_EXTENSIONCHUNK DMUS_EXTENSIONCHUNK, *LPDMUS_EXTENSIONCHUNK;
typedef struct _DMUS_COPYRIGHT      DMUS_COPYRIGHT,      *LPDMUS_COPYRIGHT;
typedef struct _DMUS_WAVEDATA       DMUS_WAVEDATA,       *LPDMUS_WAVEDATA;
typedef struct _DMUS_WAVE           DMUS_WAVE,           *LPDMUS_WAVE;
typedef struct _DMUS_NOTERANGE      DMUS_NOTERANGE,      *LPDMUS_NOTERANGE;
typedef struct _DMUS_WAVEARTDL      DMUS_WAVEARTDL,      *LPDMUS_WAVEARTDL;
typedef struct _DMUS_WAVEDL         DMUS_WAVEDL,         *LPDMUS_WAVEDL;

/* actual structures */
struct _DMUS_DOWNLOADINFO {
	DWORD dwDLType;
	DWORD dwDLId;
	DWORD dwNumOffsetTableEntries;
	DWORD cbSize;
};

struct _DMUS_OFFSETTABLE {
	ULONG ulOffsetTable[DMUS_DEFAULT_SIZE_OFFSETTABLE];
};

struct _DMUS_INSTRUMENT {
	ULONG ulPatch;
	ULONG ulFirstRegionIdx;             
	ULONG ulGlobalArtIdx;
	ULONG ulFirstExtCkIdx;
	ULONG ulCopyrightIdx;
	ULONG ulFlags;                        
};

struct _DMUS_REGION {
	RGNRANGE RangeKey;
	RGNRANGE RangeVelocity;
	USHORT   fusOptions;
	USHORT   usKeyGroup;
	ULONG    ulRegionArtIdx;
	ULONG    ulNextRegionIdx;
	ULONG    ulFirstExtCkIdx;
	WAVELINK WaveLink;
	WSMPL    WSMP;
/* WLOOP is typedef'ed as struct _rloop in dls1.h. Changed type of
 * WLOOP[1] from WLOOP to struct _rloop for __cplusplus compat. */
	struct _rloop   WLOOP[1];
};

struct _DMUS_LFOPARAMS {
	PCENT pcFrequency;
	TCENT tcDelay;
	GCENT gcVolumeScale;
	PCENT pcPitchScale;
	GCENT gcMWToVolume;
	PCENT pcMWToPitch;
};

struct _DMUS_VEGPARAMS {
	TCENT   tcAttack;
	TCENT   tcDecay;
	PERCENT ptSustain;
	TCENT   tcRelease;
	TCENT   tcVel2Attack;
	TCENT   tcKey2Decay;
};

struct _DMUS_PEGPARAMS {
	TCENT   tcAttack;
	TCENT   tcDecay;
	PERCENT ptSustain;
	TCENT   tcRelease;
	TCENT   tcVel2Attack;
	TCENT   tcKey2Decay;
	PCENT   pcRange;
};

struct _DMUS_MSCPARAMS {
	PERCENT ptDefaultPan;
};

struct _DMUS_ARTICPARAMS {
	DMUS_LFOPARAMS LFO;
	DMUS_VEGPARAMS VolEG;
	DMUS_PEGPARAMS PitchEG;
	DMUS_MSCPARAMS Misc;
};

struct _DMUS_ARTICULATION {
	ULONG ulArt1Idx;
	ULONG ulFirstExtCkIdx;
};

struct _DMUS_ARTICULATION2 {
	ULONG ulArtIdx;
	ULONG ulFirstExtCkIdx;
	ULONG ulNextArtIdx;
};

struct _DMUS_EXTENSIONCHUNK {
	ULONG  cbSize;
	ULONG  ulNextExtCkIdx;
	FOURCC ExtCkID;                                      
	BYTE   byExtCk[DMUS_MIN_DATA_SIZE];
};

struct _DMUS_COPYRIGHT {
	ULONG cbSize;
	BYTE  byCopyright[DMUS_MIN_DATA_SIZE];
};

struct _DMUS_WAVEDATA {
	ULONG cbSize;
	BYTE  byData[DMUS_MIN_DATA_SIZE]; 
};

struct _DMUS_WAVE {
	ULONG        ulFirstExtCkIdx;
	ULONG        ulCopyrightIdx;
	ULONG        ulWaveDataIdx;
	WAVEFORMATEX WaveformatEx;
};

struct _DMUS_NOTERANGE {
	DWORD dwLowNote;
	DWORD dwHighNote;
};

struct _DMUS_WAVEARTDL {
	ULONG  ulDownloadIdIdx;
	ULONG  ulBus;
	ULONG  ulBuffers;
	ULONG  ulMasterDLId;
	USHORT usOptions;
};

struct _DMUS_WAVEDL {
	ULONG cbWaveData;
};

#endif /* __WINE_DMUSIC_DLS_H */
