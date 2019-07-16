/*
 * atsmedia.h
 *
 * Contributors:
 *   Created by Magnus Olsen.
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

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#pragma once

#ifndef _ATSCMEDIA_
#define _ATSCMEDIA_

#include <bdamedia.h>

#define BDANETWORKTYPE_ATSC DEFINE_GUIDNAMED(BDANETWORKTYPE_ATSC)
#define STATIC_BDANETWORKTYPE_ATSC						\
	0x71985F51, 0x1CA1, 0x11D3, 0x9C, 0xC8, 0x0, 0xC0, 0x4F, 0x79, 0x71, 0xE0
DEFINE_GUIDSTRUCT("71985F51-1CA1-11D3-9CC8-00C04F7971E0", BDANETWORKTYPE_ATSC);

#endif /* _ATSCMEDIA_ */

#endif /* Desktop partition.  */
