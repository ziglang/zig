/*	$NetBSD: common_int_fmtio.h,v 1.1 2014/07/25 21:43:13 joerg Exp $	*/

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Joerg Sonnenberger.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_COMMON_INT_FMTIO_H_
#define _SYS_COMMON_INT_FMTIO_H_

#ifndef __INTPTR_FMTd__
#error Your compiler does not provide format string macros.
#endif

/*
 * 7.8.1 Macros for format specifiers
 */

/* fprintf macros for signed integers */
#define	PRId8		__INT8_FMTd__
#define	PRId16		__INT16_FMTd__
#define	PRId32		__INT32_FMTd__
#define	PRId64		__INT64_FMTd__
#define	PRIdLEAST8	__INT_LEAST8_FMTd__
#define	PRIdLEAST16	__INT_LEAST16_FMTd__
#define	PRIdLEAST32	__INT_LEAST32_FMTd__
#define	PRIdLEAST64	__INT_LEAST64_FMTd__
#define	PRIdFAST8	__INT_FAST8_FMTd__
#define	PRIdFAST16	__INT_FAST16_FMTd__
#define	PRIdFAST32	__INT_FAST32_FMTd__
#define	PRIdFAST64	__INT_FAST64_FMTd__
#define	PRIdMAX		__INTMAX_FMTd__
#define	PRIdPTR		__INTPTR_FMTd__

#define	PRIi8		__INT8_FMTi__
#define	PRIi16		__INT16_FMTi__
#define	PRIi32		__INT32_FMTi__
#define	PRIi64		__INT64_FMTi__
#define	PRIiLEAST8	__INT_LEAST8_FMTi__
#define	PRIiLEAST16	__INT_LEAST16_FMTi__
#define	PRIiLEAST32	__INT_LEAST32_FMTi__
#define	PRIiLEAST64	__INT_LEAST64_FMTi__
#define	PRIiFAST8	__INT_FAST8_FMTi__
#define	PRIiFAST16	__INT_FAST16_FMTi__
#define	PRIiFAST32	__INT_FAST32_FMTi__
#define	PRIiFAST64	__INT_FAST64_FMTi__
#define	PRIiMAX		__INTMAX_FMTi__
#define	PRIiPTR		__INTPTR_FMTi__

/* fprintf macros for unsigned integers */

#define	PRIo8		__UINT8_FMTo__
#define	PRIo16		__UINT16_FMTo__
#define	PRIo32		__UINT32_FMTo__
#define	PRIo64		__UINT64_FMTo__
#define	PRIoLEAST8	__UINT_LEAST8_FMTo__
#define	PRIoLEAST16	__UINT_LEAST16_FMTo__
#define	PRIoLEAST32	__UINT_LEAST32_FMTo__
#define	PRIoLEAST64	__UINT_LEAST64_FMTo__
#define	PRIoFAST8	__UINT_FAST8_FMTo__
#define	PRIoFAST16	__UINT_FAST16_FMTo__
#define	PRIoFAST32	__UINT_FAST32_FMTo__
#define	PRIoFAST64	__UINT_FAST64_FMTo__
#define	PRIoMAX		__UINTMAX_FMTo__
#define	PRIoPTR		__UINTPTR_FMTo__

#define	PRIu8		__UINT8_FMTu__
#define	PRIu16		__UINT16_FMTu__
#define	PRIu32		__UINT32_FMTu__
#define	PRIu64		__UINT64_FMTu__
#define	PRIuLEAST8	__UINT_LEAST8_FMTu__
#define	PRIuLEAST16	__UINT_LEAST16_FMTu__
#define	PRIuLEAST32	__UINT_LEAST32_FMTu__
#define	PRIuLEAST64	__UINT_LEAST64_FMTu__
#define	PRIuFAST8	__UINT_FAST8_FMTu__
#define	PRIuFAST16	__UINT_FAST16_FMTu__
#define	PRIuFAST32	__UINT_FAST32_FMTu__
#define	PRIuFAST64	__UINT_FAST64_FMTu__
#define	PRIuMAX		__UINTMAX_FMTu__
#define	PRIuPTR		__UINTPTR_FMTu__

#define	PRIx8		__UINT8_FMTx__
#define	PRIx16		__UINT16_FMTx__
#define	PRIx32		__UINT32_FMTx__
#define	PRIx64		__UINT64_FMTx__
#define	PRIxLEAST8	__UINT_LEAST8_FMTx__
#define	PRIxLEAST16	__UINT_LEAST16_FMTx__
#define	PRIxLEAST32	__UINT_LEAST32_FMTx__
#define	PRIxLEAST64	__UINT_LEAST64_FMTx__
#define	PRIxFAST8	__UINT_FAST8_FMTx__
#define	PRIxFAST16	__UINT_FAST16_FMTx__
#define	PRIxFAST32	__UINT_FAST32_FMTx__
#define	PRIxFAST64	__UINT_FAST64_FMTx__
#define	PRIxMAX		__UINTMAX_FMTx__
#define	PRIxPTR		__UINTPTR_FMTx__

#define	PRIX8		__UINT8_FMTX__
#define	PRIX16		__UINT16_FMTX__
#define	PRIX32		__UINT32_FMTX__
#define	PRIX64		__UINT64_FMTX__
#define	PRIXLEAST8	__UINT_LEAST8_FMTX__
#define	PRIXLEAST16	__UINT_LEAST16_FMTX__
#define	PRIXLEAST32	__UINT_LEAST32_FMTX__
#define	PRIXLEAST64	__UINT_LEAST64_FMTX__
#define	PRIXFAST8	__UINT_FAST8_FMTX__
#define	PRIXFAST16	__UINT_FAST16_FMTX__
#define	PRIXFAST32	__UINT_FAST32_FMTX__
#define	PRIXFAST64	__UINT_FAST64_FMTX__
#define	PRIXMAX		__UINTMAX_FMTX__
#define	PRIXPTR		__UINTPTR_FMTX__

/* fscanf macros for signed integers */

#define	SCNd8		__INT8_FMTd__
#define	SCNd16		__INT16_FMTd__
#define	SCNd32		__INT32_FMTd__
#define	SCNd64		__INT64_FMTd__
#define	SCNdLEAST8	__INT_LEAST8_FMTd__
#define	SCNdLEAST16	__INT_LEAST16_FMTd__
#define	SCNdLEAST32	__INT_LEAST32_FMTd__
#define	SCNdLEAST64	__INT_LEAST64_FMTd__
#define	SCNdFAST8	__INT_FAST8_FMTd__
#define	SCNdFAST16	__INT_FAST16_FMTd__
#define	SCNdFAST32	__INT_FAST32_FMTd__
#define	SCNdFAST64	__INT_FAST64_FMTd__
#define	SCNdMAX		__INTMAX_FMTd__
#define	SCNdPTR		__INTPTR_FMTd__

#define	SCNi8		__INT8_FMTi__
#define	SCNi16		__INT16_FMTi__
#define	SCNi32		__INT32_FMTi__
#define	SCNi64		__INT64_FMTi__
#define	SCNiLEAST8	__INT_LEAST8_FMTi__
#define	SCNiLEAST16	__INT_LEAST16_FMTi__
#define	SCNiLEAST32	__INT_LEAST32_FMTi__
#define	SCNiLEAST64	__INT_LEAST64_FMTi__
#define	SCNiFAST8	__INT_FAST8_FMTi__
#define	SCNiFAST16	__INT_FAST16_FMTi__
#define	SCNiFAST32	__INT_FAST32_FMTi__
#define	SCNiFAST64	__INT_FAST64_FMTi__
#define	SCNiMAX		__INTMAX_FMTi__
#define	SCNiPTR		__INTPTR_FMTi__

/* fscanf macros for unsigned integers */

#define	SCNo8		__UINT8_FMTo__
#define	SCNo16		__UINT16_FMTo__
#define	SCNo32		__UINT32_FMTo__
#define	SCNo64		__UINT64_FMTo__
#define	SCNoLEAST8	__UINT_LEAST8_FMTo__
#define	SCNoLEAST16	__UINT_LEAST16_FMTo__
#define	SCNoLEAST32	__UINT_LEAST32_FMTo__
#define	SCNoLEAST64	__UINT_LEAST64_FMTo__
#define	SCNoFAST8	__UINT_FAST8_FMTo__
#define	SCNoFAST16	__UINT_FAST16_FMTo__
#define	SCNoFAST32	__UINT_FAST32_FMTo__
#define	SCNoFAST64	__UINT_FAST64_FMTo__
#define	SCNoMAX		__UINTMAX_FMTo__
#define	SCNoPTR		__UINTPTR_FMTo__

#define	SCNu8		__UINT8_FMTu__
#define	SCNu16		__UINT16_FMTu__
#define	SCNu32		__UINT32_FMTu__
#define	SCNu64		__UINT64_FMTu__
#define	SCNuLEAST8	__UINT_LEAST8_FMTu__
#define	SCNuLEAST16	__UINT_LEAST16_FMTu__
#define	SCNuLEAST32	__UINT_LEAST32_FMTu__
#define	SCNuLEAST64	__UINT_LEAST64_FMTu__
#define	SCNuFAST8	__UINT_FAST8_FMTu__
#define	SCNuFAST16	__UINT_FAST16_FMTu__
#define	SCNuFAST32	__UINT_FAST32_FMTu__
#define	SCNuFAST64	__UINT_FAST64_FMTu__
#define	SCNuMAX		__UINTMAX_FMTu__
#define	SCNuPTR		__UINTPTR_FMTu__

#define	SCNx8		__UINT8_FMTx__
#define	SCNx16		__UINT16_FMTx__
#define	SCNx32		__UINT32_FMTx__
#define	SCNx64		__UINT64_FMTx__
#define	SCNxLEAST8	__UINT_LEAST8_FMTx__
#define	SCNxLEAST16	__UINT_LEAST16_FMTx__
#define	SCNxLEAST32	__UINT_LEAST32_FMTx__
#define	SCNxLEAST64	__UINT_LEAST64_FMTx__
#define	SCNxFAST8	__UINT_FAST8_FMTx__
#define	SCNxFAST16	__UINT_FAST16_FMTx__
#define	SCNxFAST32	__UINT_FAST32_FMTx__
#define	SCNxFAST64	__UINT_FAST64_FMTx__
#define	SCNxMAX		__UINTMAX_FMTx__
#define	SCNxPTR		__UINTPTR_FMTx__

#define	SCNX8		__UINT8_FMTX__
#define	SCNX16		__UINT16_FMTX__
#define	SCNX32		__UINT32_FMTX__
#define	SCNX64		__UINT64_FMTX__
#define	SCNXLEAST8	__UINT_LEAST8_FMTX__
#define	SCNXLEAST16	__UINT_LEAST16_FMTX__
#define	SCNXLEAST32	__UINT_LEAST32_FMTX__
#define	SCNXLEAST64	__UINT_LEAST64_FMTX__
#define	SCNXFAST8	__UINT_FAST8_FMTX__
#define	SCNXFAST16	__UINT_FAST16_FMTX__
#define	SCNXFAST32	__UINT_FAST32_FMTX__
#define	SCNXFAST64	__UINT_FAST64_FMTX__
#define	SCNXMAX		__UINTMAX_FMTX__
#define	SCNXPTR		__UINTPTR_FMTX__

#endif /* _SYS_COMMON_INT_FMTIO_H_ */