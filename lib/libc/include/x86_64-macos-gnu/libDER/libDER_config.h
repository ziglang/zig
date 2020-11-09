/*
 * Copyright (c) 2005-2007,2011-2012,2014 Apple Inc. All Rights Reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */


/*
 * libDER_config.h - platform dependent #defines and typedefs for libDER
 *
 */
 
#ifndef	_LIB_DER_CONFIG_H_
#define _LIB_DER_CONFIG_H_

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#if defined(WIN32) && defined(__cplusplus)

#if !defined(__BEGIN_DECLS) || !defined(__END_DECLS)
#define __BEGIN_DECLS extern "C" {
#define __END_DECLS }
#endif //  __BEGIN_DECLS || __END_DECLS

#else
#include <sys/cdefs.h>
#endif // defined(WIN32) && defined(__cplusplus)

__BEGIN_DECLS

/*
 * Basic data types: unsigned 8-bit integer, unsigned 32-bit integer
 */
typedef uint8_t DERByte;
typedef uint16_t DERShort;
typedef size_t DERSize;


/* 
 * Use these #defines of you have memset, memmove, and memcmp; else
 * write your own equivalents.
 */

#define DERMemset(ptr, c, len)		memset(ptr, c, len)
#define DERMemmove(dst, src, len)	memmove(dst, src, len)
#define DERMemcmp(b1, b2, len)		memcmp(b1, b2, len)


/***
 *** Compile time options to trim size of the library. 
 ***/
 
/* enable general DER encode */
#define DER_ENCODE_ENABLE		1

/* enable general DER decode */
#define DER_DECODE_ENABLE		1

#ifndef DER_MULTIBYTE_TAGS
/* enable multibyte tag support. */
#define DER_MULTIBYTE_TAGS		1
#endif

#ifndef DER_TAG_SIZE
/* Iff DER_MULTIBYTE_TAGS is 1 this is the sizeof(DERTag) in bytes. Note that
   tags are still encoded and decoded from a minimally encoded DER
   represantation.  This value maintains compatibility with libImg4Decode/Encode.  */
#define DER_TAG_SIZE            8
#endif


/* ---------------------- Do not edit below this line ---------------------- */

/*
 * Logical representation of a tag (the encoded representation is always in
 * the minimal number of bytes). The top 3 bits encode class and method
 * The remaining bits encode the tag value.  To obtain smaller DERItemSpecs
 * sizes, choose the smallest type that fits your needs.  Most standard ASN.1
 * usage only needs single byte tags, but ocasionally custom applications
 * require a larger tag namespace.
 */
#if DER_MULTIBYTE_TAGS

#if DER_TAG_SIZE == 1
typedef uint8_t DERTag;
#elif DER_TAG_SIZE == 2
typedef uint16_t DERTag;
#elif DER_TAG_SIZE == 4
typedef uint32_t DERTag;
#elif DER_TAG_SIZE == 8
typedef uint64_t DERTag;
#else
#error DER_TAG_SIZE invalid
#endif

#else /* DER_MULTIBYTE_TAGS */
typedef DERByte DERTag;
#endif /* !DER_MULTIBYTE_TAGS */

__END_DECLS

#endif	/* _LIB_DER_CONFIG_H_ */
