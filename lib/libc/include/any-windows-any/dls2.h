/* Defines and Structures for Instrument Collection Form RIFF DLS2
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

#ifndef __WINE_INCLUDE_DLS2_H
#define __WINE_INCLUDE_DLS2_H

/*****************************************************************************
 * DLSIDs - property set
 */ 
DEFINE_GUID(DLSID_GMInHardware,       0x178f2f24,0xc364,0x11d1,0xa7,0x60,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(DLSID_GSInHardware,       0x178f2f25,0xc364,0x11d1,0xa7,0x60,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(DLSID_ManufacturersID,    0xb03e1181,0x8095,0x11d2,0xa1,0xef,0x00,0x60,0x08,0x33,0xdb,0xd8);
DEFINE_GUID(DLSID_ProductID,          0xb03e1182,0x8095,0x11d2,0xa1,0xef,0x00,0x60,0x08,0x33,0xdb,0xd8);
DEFINE_GUID(DLSID_SampleMemorySize,   0x178f2f28,0xc364,0x11d1,0xa7,0x60,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(DLSID_SupportsDLS1,       0x178f2f27,0xc364,0x11d1,0xa7,0x60,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(DLSID_SupportsDLS2,       0xf14599e5,0x4689,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(DLSID_SamplePlaybackRate, 0x2a91f713,0xa4bf,0x11d2,0xbb,0xdf,0x00,0x60,0x08,0x33,0xdb,0xd8);
DEFINE_GUID(DLSID_XGInHardware,       0x178f2f26,0xc364,0x11d1,0xa7,0x60,0x00,0x00,0xf8,0x75,0xac,0x12);

/*****************************************************************************
 * FOURCCs
 */ 
#define FOURCC_RGN2  mmioFOURCC('r','g','n','2')
#define FOURCC_LAR2  mmioFOURCC('l','a','r','2')
#define FOURCC_ART2  mmioFOURCC('a','r','t','2')
#define FOURCC_CDL   mmioFOURCC('c','d','l',' ')
#define FOURCC_DLID  mmioFOURCC('d','l','i','d')

/*****************************************************************************
 * Flags
 */
#define CONN_DST_GAIN             0x001
#define CONN_DST_KEYNUMBER        0x005

#define CONN_DST_LEFT             0x010
#define CONN_DST_RIGHT            0x011
#define CONN_DST_CENTER           0x012
#define CONN_DST_LEFTREAR         0x013
#define CONN_DST_RIGHTREAR        0x014
#define CONN_DST_LFE_CHANNEL      0x015
#define CONN_DST_CHORUS           0x080
#define CONN_DST_REVERB           0x081

#define CONN_DST_VIB_FREQUENCY    0x114
#define CONN_DST_VIB_STARTDELAY   0x115	

#define CONN_DST_EG1_DELAYTIME    0x20B
#define CONN_DST_EG1_HOLDTIME     0x20C
#define CONN_DST_EG1_SHUTDOWNTIME 0x20D

#define CONN_DST_EG2_DELAYTIME    0x30F
#define CONN_DST_EG2_HOLDTIME     0x310

#define CONN_DST_FILTER_CUTOFF    0x500
#define CONN_DST_FILTER_Q         0x501

#define CONN_SRC_POLYPRESSURE     0x007
#define CONN_SRC_CHANNELPRESSURE  0x008
#define CONN_SRC_VIBRATO          0x009
#define CONN_SRC_MONOPRESSURE     0x00A

#define CONN_SRC_CC91             0x0DB
#define CONN_SRC_CC93             0x0DD

#define CONN_TRN_CONVEX           0x002
#define CONN_TRN_SWITCH           0x003

#define DLS_CDL_AND            0x01
#define DLS_CDL_OR             0x02
#define DLS_CDL_XOR            0x03
#define DLS_CDL_ADD            0x04
#define DLS_CDL_SUBTRACT       0x05
#define DLS_CDL_MULTIPLY       0x06
#define DLS_CDL_DIVIDE         0x07
#define DLS_CDL_LOGICAL_AND    0x08
#define DLS_CDL_LOGICAL_OR     0x09
#define DLS_CDL_LT             0x0A
#define DLS_CDL_LE             0x0B
#define DLS_CDL_GT             0x0C
#define DLS_CDL_GE             0x0D
#define DLS_CDL_EQ             0x0E
#define DLS_CDL_NOT            0x0F
#define DLS_CDL_CONST          0x10
#define DLS_CDL_QUERY          0x11
#define DLS_CDL_QUERYSUPPORTED 0x12

#define F_WAVELINK_MULTICHANNEL 0x2

#define WLOOP_TYPE_RELEASE 0x1

#endif	/* __WINE_INCLUDE_DLS2_H */
