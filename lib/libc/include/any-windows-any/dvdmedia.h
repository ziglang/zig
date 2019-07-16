/*
 * Copyright (C) 2008 Maarten Lankhorst
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __DVDMEDIA_H__
#define __DVDMEDIA_H__

#define AMCONTROL_USED 0x00000001
#define AMCONTROL_PAD_TO_4x3 0x00000002
#define AMCONTROL_PAD_TO_16x9 0x00000004

typedef struct tagVIDEOINFOHEADER2 {
    RECT rcSource;
    RECT rcTarget;
    DWORD dwBitRate;
    DWORD dwBitErrorRate;
    REFERENCE_TIME AvgTimePerFrame;
    DWORD dwInterlaceFlags;
    DWORD dwCopyProtectFlags;
    DWORD dwPictAspectRatioX;
    DWORD dwPictAspectRatioY;
    union {
        DWORD dwControlFlags;
        DWORD dwReserved1;
    } DUMMYUNIONNAME;
    DWORD dwReserved2;
    BITMAPINFOHEADER bmiHeader;
} VIDEOINFOHEADER2;

typedef struct tagMPEG2VIDEOINFO {
    VIDEOINFOHEADER2 hdr;
    DWORD dwStartTimeCode;
    DWORD cbSequenceHeader;
    DWORD dwProfile;
    DWORD dwLevel;
    DWORD dwFlags;
    DWORD dwSequenceHeader[1];
} MPEG2VIDEOINFO;

#define AMINTERLACE_IsInterlaced          0x0001
#define AMINTERLACE_1FieldPerSample       0x0002
#define AMINTERLACE_Field1First           0x0004
#define AMINTERLACE_UNUSED                0x0008
#define AMINTERLACE_FieldPatField1Only    0x0000
#define AMINTERLACE_FieldPatField2Only    0x0010
#define AMINTERLACE_FieldPatBothRegular   0x0020
#define AMINTERLACE_FieldPatBothIrregular 0x0030
#define AMINTERLACE_FieldPatternMask      0x0030
#define AMINTERLACE_DisplayModeBobOnly    0x0000
#define AMINTERLACE_DisplayModeWeaveOnly  0x0040
#define AMINTERLACE_DisplayModeBobOrWeave 0x0080
#define AMINTERLACE_DisplayModeMask       0x00c0

#endif /* __DVDMEDIA_H__ */
