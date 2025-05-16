/*
 * Copyright (C) 2025 Biswapriyo Nath
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

#ifndef _MPEG2BITS_H_
#define _MPEG2BITS_H_

#pragma pack(push)
#pragma pack(1)

#if defined(__midl) || defined(__WIDL__)
typedef struct
{
    WORD Bits;
} PID_BITS_MIDL;
#else
typedef struct
{
    WORD Reserved : 3;
    WORD ProgramId : 13;
} PID_BITS, *PPID_BITS;
#endif

#if defined(__midl) || defined(__WIDL__)
typedef struct
{
    WORD Bits;
} MPEG_HEADER_BITS_MIDL;
#else
typedef struct
{
    WORD SectionLength : 12;
    WORD Reserved : 2;
    WORD PrivateIndicator : 1;
    WORD SectionSyntaxIndicator : 1;
} MPEG_HEADER_BITS, *PMPEG_HEADER_BITS;
#endif

#if defined(__midl) || defined(__WIDL__)
typedef struct
{
    BYTE Bits;
} MPEG_HEADER_VERSION_BITS_MIDL;
#else
typedef struct
{
    BYTE CurrentNextIndicator : 1;
    BYTE VersionNumber : 5;
    BYTE Reserved : 2;
} MPEG_HEADER_VERSION_BITS, *PMPEG_HEADER_VERSION_BITS;
#endif

#pragma pack(pop)

#endif /* _MPEG2BITS_H_ */
