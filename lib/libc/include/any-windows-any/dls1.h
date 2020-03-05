/* Defines and Structures for Instrument Collection Form RIFF DLS1
 *
 * Copyright (C) 2003-2004 Rok Mandeljc
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
 
#ifndef __WINE_INCLUDE_DLS1_H
#define __WINE_INCLUDE_DLS1_H

/*****************************************************************************
 * FOURCCs
 */
#define FOURCC_DLS   mmioFOURCC('D','L','S',' ')
#define FOURCC_DLID  mmioFOURCC('d','l','i','d')
#define FOURCC_COLH  mmioFOURCC('c','o','l','h')
#define FOURCC_WVPL  mmioFOURCC('w','v','p','l')
#define FOURCC_PTBL  mmioFOURCC('p','t','b','l')
#define FOURCC_PATH  mmioFOURCC('p','a','t','h')
#define FOURCC_wave  mmioFOURCC('w','a','v','e')
#define FOURCC_LINS  mmioFOURCC('l','i','n','s')
#define FOURCC_INS   mmioFOURCC('i','n','s',' ')
#define FOURCC_INSH  mmioFOURCC('i','n','s','h')
#define FOURCC_LRGN  mmioFOURCC('l','r','g','n')
#define FOURCC_RGN   mmioFOURCC('r','g','n',' ')
#define FOURCC_RGNH  mmioFOURCC('r','g','n','h')
#define FOURCC_LART  mmioFOURCC('l','a','r','t')
#define FOURCC_ART1  mmioFOURCC('a','r','t','1')
#define FOURCC_WLNK  mmioFOURCC('w','l','n','k')
#define FOURCC_WSMP  mmioFOURCC('w','s','m','p')
#define FOURCC_VERS  mmioFOURCC('v','e','r','s')

/*****************************************************************************
 * Flags
 */

#define CONN_DST_NONE             0x000
#define CONN_DST_ATTENUATION      0x001
#define CONN_DST_PITCH            0x003
#define CONN_DST_PAN              0x004

#define CONN_DST_LFO_FREQUENCY    0x104
#define CONN_DST_LFO_STARTDELAY   0x105

#define CONN_DST_EG1_ATTACKTIME   0x206
#define CONN_DST_EG1_DECAYTIME    0x207
#define CONN_DST_EG1_RELEASETIME  0x209
#define CONN_DST_EG1_SUSTAINLEVEL 0x20A

#define CONN_DST_EG2_ATTACKTIME   0x30A
#define CONN_DST_EG2_DECAYTIME    0x30B
#define CONN_DST_EG2_RELEASETIME  0x30D
#define CONN_DST_EG2_SUSTAINLEVEL 0x30E

#define CONN_SRC_NONE             0x000
#define CONN_SRC_LFO              0x001
#define CONN_SRC_KEYONVELOCITY    0x002
#define CONN_SRC_KEYNUMBER        0x003
#define CONN_SRC_EG1              0x004
#define CONN_SRC_EG2              0x005
#define CONN_SRC_PITCHWHEEL       0x006

#define CONN_SRC_CC1              0x081
#define CONN_SRC_CC7              0x087
#define CONN_SRC_CC10             0x08A
#define CONN_SRC_CC11             0x08B

#define CONN_TRN_NONE             0x000
#define CONN_TRN_CONCAVE          0x001

#define F_INSTRUMENT_DRUMS 0x80000000

#define F_RGN_OPTION_SELFNONEXCLUSIVE 0x1

#define F_WAVELINK_PHASE_MASTER 0x1

#define F_WSMP_NO_TRUNCATION  0x1
#define F_WSMP_NO_COMPRESSION 0x2

#define POOL_CUE_NULL 0xFFFFFFFF

#define WAVELINK_CHANNEL_LEFT  0x1
#define WAVELINK_CHANNEL_RIGHT 0x2

#define WLOOP_TYPE_FORWARD 0x0

/*****************************************************************************
 * Structures
 */

/* actual structures */
typedef struct _DLSID {
	ULONG  ulData1;
	USHORT usData2;
	USHORT usData3;
	BYTE   abData4[8];
} DLSID, *LPDLSID;

typedef struct _DLSVERSION {
	DWORD dwVersionMS;
	DWORD dwVersionLS;
} DLSVERSION, *LPDLSVERSION;

typedef struct _CONNECTION {
	USHORT usSource;
	USHORT usControl;
	USHORT usDestination;
	USHORT usTransform;
	LONG   lScale;
} CONNECTION, *LPCONNECTION;

typedef struct _CONNECTIONLIST {
	ULONG cbSize;
	ULONG cConnections;
} CONNECTIONLIST, *LPCONNECTIONLIST;

typedef struct _RGNRANGE {
	USHORT usLow;
	USHORT usHigh;
} RGNRANGE, *LPRGNRANGE;

typedef struct _MIDILOCALE {
	ULONG ulBank;
	ULONG ulInstrument;
} MIDILOCALE, *LPMIDILOCALE;

typedef struct _RGNHEADER {
	RGNRANGE RangeKey;
	RGNRANGE RangeVelocity;
	USHORT   fusOptions;
	USHORT   usKeyGroup;
} RGNHEADER, *LPRGNHEADER;

typedef struct _INSTHEADER {
	ULONG      cRegions;
	MIDILOCALE Locale;
} INSTHEADER, *LPINSTHEADER;

typedef struct _DLSHEADER {
	ULONG cInstruments;
} DLSHEADER, *LPDLSHEADER;

typedef struct _WAVELINK {
	USHORT fusOptions;
	USHORT usPhaseGroup;
	ULONG  ulChannel;
	ULONG  ulTableIndex;
} WAVELINK, *LPWAVELINK;

typedef struct _POOLCUE {
	ULONG ulOffset;
} POOLCUE, *LPPOOLCUE;

typedef struct _POOLTABLE {
	ULONG cbSize;
	ULONG cCues;
} POOLTABLE, *LPPOOLTABLE;

typedef struct _rwsmp {
	ULONG  cbSize;
	USHORT usUnityNote;
	SHORT  sFineTune;
	LONG   lAttenuation;
	ULONG  fulOptions;
	ULONG  cSampleLoops;
} WSMPL, *LPWSMPL;

typedef struct _rloop {
	ULONG cbSize;
	ULONG ulType;
	ULONG ulStart;
	ULONG ulLength;
} WLOOP, *LPWLOOP;

#endif /* __WINE_INCLUDE_DLS1_H */
