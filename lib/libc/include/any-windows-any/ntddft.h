/*
 * ntddft.h
 *
 * Contributors:
 *   Created by Alex Ionescu
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef _NTDDFT_
#define _NTDDFT_

#ifdef __cplusplus
extern "C" {
#endif

#define FTTYPE  ((ULONG)'f')

#define FT_SECONDARY_READ           CTL_CODE(FTTYPE, 4, METHOD_OUT_DIRECT, FILE_READ_ACCESS)
#define FT_PRIMARY_READ             CTL_CODE(FTTYPE, 5, METHOD_OUT_DIRECT, FILE_READ_ACCESS)
#define FT_BALANCED_READ_MODE       CTL_CODE(FTTYPE, 6, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FT_SYNC_REDUNDANT_COPY      CTL_CODE(FTTYPE, 7, METHOD_BUFFERED, FILE_ANY_ACCESS)

#ifdef __cplusplus
}
#endif

#endif /* _NTDDFT_ */

