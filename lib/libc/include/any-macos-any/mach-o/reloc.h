/*
 * Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
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
/*	$NetBSD: exec.h,v 1.6 1994/10/27 04:16:05 cgd Exp $	*/

/*
 * Copyright (c) 1993 Christopher G. Demetriou
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _MACHO_RELOC_H_
#define _MACHO_RELOC_H_
#include <stdint.h>

/*
 * Format of a relocation entry of a Mach-O file.  Modified from the 4.3BSD
 * format.  The modifications from the original format were changing the value
 * of the r_symbolnum field for "local" (r_extern == 0) relocation entries.
 * This modification is required to support symbols in an arbitrary number of
 * sections not just the three sections (text, data and bss) in a 4.3BSD file.
 * Also the last 4 bits have had the r_type tag added to them.
 */
struct relocation_info {
   int32_t	r_address;	/* offset in the section to what is being
				   relocated */
   uint32_t     r_symbolnum:24,	/* symbol index if r_extern == 1 or section
				   ordinal if r_extern == 0 */
		r_pcrel:1, 	/* was relocated pc relative already */
		r_length:2,	/* 0=byte, 1=word, 2=long, 3=quad */
		r_extern:1,	/* does not include value of sym referenced */
		r_type:4;	/* if not 0, machine specific relocation type */
};
#define	R_ABS	0		/* absolute relocation type for Mach-O files */

/*
 * The r_address is not really the address as it's name indicates but an offset.
 * In 4.3BSD a.out objects this offset is from the start of the "segment" for
 * which relocation entry is for (text or data).  For Mach-O object files it is
 * also an offset but from the start of the "section" for which the relocation
 * entry is for.  See comments in <mach-o/loader.h> about the r_address feild
 * in images for used with the dynamic linker.
 * 
 * In 4.3BSD a.out objects if r_extern is zero then r_symbolnum is an ordinal
 * for the segment the symbol being relocated is in.  These ordinals are the
 * symbol types N_TEXT, N_DATA, N_BSS or N_ABS.  In Mach-O object files these
 * ordinals refer to the sections in the object file in the order their section
 * structures appear in the headers of the object file they are in.  The first
 * section has the ordinal 1, the second 2, and so on.  This means that the
 * same ordinal in two different object files could refer to two different
 * sections.  And further could have still different ordinals when combined
 * by the link-editor.  The value R_ABS is used for relocation entries for
 * absolute symbols which need no further relocation.
 */

/*
 * For RISC machines some of the references are split across two instructions
 * and the instruction does not contain the complete value of the reference.
 * In these cases a second, or paired relocation entry, follows each of these
 * relocation entries, using a PAIR r_type, which contains the other part of the
 * reference not contained in the instruction.  This other part is stored in the
 * pair's r_address field.  The exact number of bits of the other part of the
 * reference store in the r_address field is dependent on the particular
 * relocation type for the particular architecture.
 */

/*
 * To make scattered loading by the link editor work correctly "local"
 * relocation entries can't be used when the item to be relocated is the value
 * of a symbol plus an offset (where the resulting expresion is outside the
 * block the link editor is moving, a blocks are divided at symbol addresses).
 * In this case. where the item is a symbol value plus offset, the link editor
 * needs to know more than just the section the symbol was defined.  What is
 * needed is the actual value of the symbol without the offset so it can do the
 * relocation correctly based on where the value of the symbol got relocated to
 * not the value of the expression (with the offset added to the symbol value).
 * So for the NeXT 2.0 release no "local" relocation entries are ever used when
 * there is a non-zero offset added to a symbol.  The "external" and "local"
 * relocation entries remain unchanged.
 *
 * The implemention is quite messy given the compatibility with the existing
 * relocation entry format.  The ASSUMPTION is that a section will never be
 * bigger than 2**24 - 1 (0x00ffffff or 16,777,215) bytes.  This assumption
 * allows the r_address (which is really an offset) to fit in 24 bits and high
 * bit of the r_address field in the relocation_info structure to indicate
 * it is really a scattered_relocation_info structure.  Since these are only
 * used in places where "local" relocation entries are used and not where
 * "external" relocation entries are used the r_extern field has been removed.
 *
 * For scattered loading to work on a RISC machine where some of the references
 * are split across two instructions the link editor needs to be assured that
 * each reference has a unique 32 bit reference (that more than one reference is
 * NOT sharing the same high 16 bits for example) so it move each referenced
 * item independent of each other.  Some compilers guarantees this but the
 * compilers don't so scattered loading can be done on those that do guarantee
 * this.
 */
#if defined(__BIG_ENDIAN__) || defined(__LITTLE_ENDIAN__)
/*
 * The reason for the ifdef's of __BIG_ENDIAN__ and __LITTLE_ENDIAN__ are that
 * when stattered relocation entries were added the mistake of using a mask
 * against a structure that is made up of bit fields was used.  To make this
 * design work this structure must be laid out in memory the same way so the
 * mask can be applied can check the same bit each time (r_scattered).
 */
#endif /* defined(__BIG_ENDIAN__) || defined(__LITTLE_ENDIAN__) */
#define R_SCATTERED 0x80000000	/* mask to be applied to the r_address field 
				   of a relocation_info structure to tell that
				   is is really a scattered_relocation_info
				   stucture */
struct scattered_relocation_info {
#ifdef __BIG_ENDIAN__
   uint32_t	r_scattered:1,	/* 1=scattered, 0=non-scattered (see above) */
		r_pcrel:1, 	/* was relocated pc relative already */
		r_length:2,	/* 0=byte, 1=word, 2=long, 3=quad */
		r_type:4,	/* if not 0, machine specific relocation type */
   		r_address:24;	/* offset in the section to what is being
				   relocated */
   int32_t	r_value;	/* the value the item to be relocated is
				   refering to (without any offset added) */
#endif /* __BIG_ENDIAN__ */
#ifdef __LITTLE_ENDIAN__
   uint32_t
   		r_address:24,	/* offset in the section to what is being
				   relocated */
		r_type:4,	/* if not 0, machine specific relocation type */
		r_length:2,	/* 0=byte, 1=word, 2=long, 3=quad */
		r_pcrel:1, 	/* was relocated pc relative already */
		r_scattered:1;	/* 1=scattered, 0=non-scattered (see above) */
   int32_t	r_value;	/* the value the item to be relocated is
				   refering to (without any offset added) */
#endif /* __LITTLE_ENDIAN__ */
};

/*
 * Relocation types used in a generic implementation.  Relocation entries for
 * normal things use the generic relocation as discribed above and their r_type
 * is GENERIC_RELOC_VANILLA (a value of zero).
 *
 * Another type of generic relocation, GENERIC_RELOC_SECTDIFF, is to support
 * the difference of two symbols defined in different sections.  That is the
 * expression "symbol1 - symbol2 + constant" is a relocatable expression when
 * both symbols are defined in some section.  For this type of relocation the
 * both relocations entries are scattered relocation entries.  The value of
 * symbol1 is stored in the first relocation entry's r_value field and the
 * value of symbol2 is stored in the pair's r_value field.
 *
 * A special case for a prebound lazy pointer is needed to beable to set the
 * value of the lazy pointer back to its non-prebound state.  This is done
 * using the GENERIC_RELOC_PB_LA_PTR r_type.  This is a scattered relocation
 * entry where the r_value feild is the value of the lazy pointer not prebound.
 */
enum reloc_type_generic
{
    GENERIC_RELOC_VANILLA,	/* generic relocation as discribed above */
    GENERIC_RELOC_PAIR,		/* Only follows a GENERIC_RELOC_SECTDIFF */
    GENERIC_RELOC_SECTDIFF,
    GENERIC_RELOC_PB_LA_PTR,	/* prebound lazy pointer */
    GENERIC_RELOC_LOCAL_SECTDIFF,
    GENERIC_RELOC_TLV		/* thread local variables */
};

#endif /* _MACHO_RELOC_H_ */
