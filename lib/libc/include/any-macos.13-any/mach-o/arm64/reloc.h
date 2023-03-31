/*
 * Copyright (c) 2010 Apple Computer, Inc. All rights reserved.
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

#ifndef _MACHO_ARM64_RELOC_H_
#define _MACHO_ARM64_RELOC_H_

/*
 * Relocations for arm64 are a bit different than for other architectures in
 * Mach-O: Scattered relocations are not used.  Almost all relocations produced
 * by the compiler are external relocations.  An external relocation has the
 * r_extern bit set to 1 and the r_symbolnum field contains the symbol table
 * index of the target label.
 *
 * When the assembler is generating relocations, if the target label is a local
 * label (begins with 'L'), then the previous non-local label in the same
 * section is used as the target of the external relocation.  An addend is used
 * with the distance from that non-local label to the target label.  Only when
 * there is no previous non-local label in the section is an internal
 * relocation used.
 *
 * The addend (i.e. the 4 in _foo+4) is encoded either in the instruction or
 * in the r_symbolnum of ARM64_RELOC_ADDEND.
 * For ARM64_RELOC_UNSIGNED and ARM64_RELOC_AUTHENTICATED_POINTER, the addend
 * is stored in the instruction.  ARM64_RELOC_PAGE21, ARM64_RELOC_PAGEOFF12 and
 * ARM64_RELOC_BRANCH26 must be preceded by an ARM64_RELOC_ADDEND if they need
 * an addend.  No other relocations support addends.
 *
 * The relocation types are:
 *
 *     ARM64_RELOC_UNSIGNED                 // For pointer sized fixups
 *     ARM64_RELOC_SUBTRACTOR               // must be followed by a ARM64_RELOC_UNSIGNED
 *     ARM64_RELOC_BRANCH26                 // a BL instruction with pc-relative +-128MB displacement
 *     ARM64_RELOC_PAGE21                   // pc-rel distance to page of target
 *     ARM64_RELOC_PAGEOFF12                // offset within page, scaled by r_length
 *     ARM64_RELOC_GOT_LOAD_PAGE21          // load with a pc-rel distance to page of a GOT entry
 *     ARM64_RELOC_GOT_LOAD_PAGEOFF12       // load with an offset within page, scaled by r_length, of GOT entry
 *     ARM64_RELOC_POINTER_TO_GOT           // 32-bit pc-rel (or 64-bit absolute) offset to a GOT entry
 *     ARM64_RELOC_TLVP_LOAD_PAGE21         // tlv load with a pc-rel distance to page of a GOT entry
 *     ARM64_RELOC_TLVP_LOAD_PAGEOFF12      // tlv load with an offset within page, scaled by r_length, of GOT entry
 *     ARM64_RELOC_ADDEND                   // must be followed by ARM64_RELOC_BRANCH26/ARM64_RELOC_PAGE21/ARM64_RELOC_PAGEOFF12
 *     ARM64_RELOC_AUTHENTICATED_POINTER    // 64-bit pointer with authentication
 *
 * The following are sample assembly instructions, followed by the relocation
 * and section content they generate in an object file:
 *
 *     (arm64_32 only)
 *     .long _foo
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         00 00 00 00
 *
 *     (arm64_32 only)
 *     .long _foo + 4
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         04 00 00 00
 *
 *     .quad _foo
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         00 00 00 00 00 00 00 00
 *
 *     .quad _foo + 16
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         10 00 00 00 00 00 00 00
 *
 *     .quad L1
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_prev
 *         10 00 00 00 00 00 00 00
 *         // assumes _prev is the first non-local label 0x10 bytes before L1
 *         10 00 00 00 00 00 00 00
 *
 *     (arm64_32 only)
 *     .long _foo - _bar
 *         r_type=ARM64_RELOC_SUBTRACTOR, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_bar
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         00 00 00 00
 *
 *     (arm64_32 only)
 *     .long _foo - _bar + 4
 *         r_type=ARM64_RELOC_SUBTRACTOR, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_bar
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         04 00 00 00
 *
 *     .quad _foo - _bar
 *         r_type=ARM64_RELOC_SUBTRACTOR, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_bar
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         00 00 00 00 00 00 00 00
 *
 *     .quad _foo - _bar + 4
 *         r_type=ARM64_RELOC_SUBTRACTOR, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_bar
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         04 00 00 00 00 00 00 00
 *
 *     .long _foo - .
 *         r_type=ARM64_RELOC_SUBTRACTOR, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_prev
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         f8 ff ff ff
 *         // assumes _prev is the first non-local label 0x8 bytes before this
 *         // .quad
 *
 *     .long _foo - L1
 *         r_type=ARM64_RELOC_SUBTRACTOR, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_prev
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         f8 ff ff ff
 *         // assumes _prev is the first non-local label 0x8 bytes before L1
 *
 *     .quad _foo - .
 *         r_type=ARM64_RELOC_SUBTRACTOR, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_prev
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         f8 ff ff ff ff ff ff ff
 *         // assumes _prev is the first non-local label 0x8 bytes before this
 *         // .quad
 *
 *     .quad _foo - L1
 *         r_type=ARM64_RELOC_SUBTRACTOR, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_prev
 *         r_type=ARM64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         f8 ff ff ff ff ff ff ff
 *         // assumes _prev is the first non-local label 0x8 bytes before L1
 *
 *     .long L1 - _prev
 *         // No relocations.  This is an assembly time constant.
 *         12 00 00 00 00 00 00 00
 *         // assumes _prev is the first non-local label 0x12 bytes before L1
 *
 *     .quad L1 - _prev
 *         // No relocations.  This is an assembly time constant.
 *         12 00 00 00 00 00 00 00
 *         // assumes _prev is the first non-local label 0x12 bytes before L1
 *
 *     bl _foo
 *         r_type=ARM64_RELOC_BRANCH26, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 *         0x14000000
 *
 *     bl _foo + 4
 *         r_type=ARM64_RELOC_ADDEND, r_length=2, r_extern=0, r_pcrel=0, r_symbolnum=0x000004
 *         r_type=ARM64_RELOC_BRANCH26, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 *         0x14000000
 *
 *     adrp x0, _foo@PAGE
 *         r_type=ARM64_RELOC_PAGE21, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 *         0x90000000
 *
 *     ldr x0, [x0, _foo@PAGEOFF]
 *         r_type=ARM64_RELOC_PAGEOFF12, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         0xf9400000
 *
 *     adrp x0, _foo@PAGE + 0x24
 *         r_type=ARM64_RELOC_ADDEND, r_length=2, r_extern=0, r_pcrel=0, r_symbolnum=0x000024
 *         r_type=ARM64_RELOC_PAGE21, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 *         0x90000000
 *
 *     ldr x0, [x0, _foo@PAGEOFF + 0x24]
 *         r_type=ARM64_RELOC_ADDEND, r_length=2, r_extern=0, r_pcrel=0, r_symbolnum=0x000024
 *         r_type=ARM64_RELOC_PAGEOFF12, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         0xf9400000
 *
 *     adrp x0, _foo@GOTPAGE
 *         r_type=ARM64_RELOC_GOT_LOAD_PAGE21, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 *         0x90000000
 *
 *     ldr x0, [x0, _foo@GOTPAGEOFF]
 *         r_type=ARM64_RELOC_GOT_LOAD_PAGEOFF12, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         0xf9400000
 *
 *     adrp x0, _foo@TLVPPAGE
 *         r_type=ARM64_RELOC_TLVP_LOAD_PAGE21, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 *         0x90000000
 *
 *     ldr x0, [x0, _foo@TLVPPAGEOFF]
 *         r_type=ARM64_RELOC_TLVP_LOAD_PAGEOFF12, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         0xf9400000
 *
 *     .long _foo@GOT - .
 *         r_type=ARM64_RELOC_POINTER_TO_GOT, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 *         00 00 00 00
 *
 *     (arm64_32 only)
 *     .long _foo@GOT
 *         r_type=ARM64_RELOC_POINTER_TO_GOT, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         00 00 00 00
 *
 *     .quad _foo@GOT
 *         r_type=ARM64_RELOC_POINTER_TO_GOT, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         00 00 00 00 00 00 00 00
 *
 *     (arm64e only)
 *     .quad _foo@AUTH(da,5,addr)
 *         r_type=ARM64_RELOC_AUTHENTICATED_POINTER, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         00 00 00 00 05 00 05 80
 *
 *     (arm64e only)
 *     .quad (_foo + 0x10)@AUTH(da,5,addr)
 *         r_type=ARM64_RELOC_AUTHENTICATED_POINTER, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 *         10 00 00 00 05 00 05 80
 *
 *
 */
enum reloc_type_arm64
{
    ARM64_RELOC_UNSIGNED,	  // for pointers
    ARM64_RELOC_SUBTRACTOR,       // must be followed by a ARM64_RELOC_UNSIGNED
    ARM64_RELOC_BRANCH26,         // a B/BL instruction with 26-bit displacement
    ARM64_RELOC_PAGE21,           // pc-rel distance to page of target
    ARM64_RELOC_PAGEOFF12,        // offset within page, scaled by r_length
    ARM64_RELOC_GOT_LOAD_PAGE21,  // pc-rel distance to page of GOT slot
    ARM64_RELOC_GOT_LOAD_PAGEOFF12, // offset within page of GOT slot,
                                    //  scaled by r_length
    ARM64_RELOC_POINTER_TO_GOT,   // for pointers to GOT slots
    ARM64_RELOC_TLVP_LOAD_PAGE21, // pc-rel distance to page of TLVP slot
    ARM64_RELOC_TLVP_LOAD_PAGEOFF12, // offset within page of TLVP slot,
                                     //  scaled by r_length
    ARM64_RELOC_ADDEND,		  // must be followed by PAGE21 or PAGEOFF12

    // An arm64e authenticated pointer.
    //
    // Represents a pointer to a symbol (like ARM64_RELOC_UNSIGNED).
    // Additionally, the resulting pointer is signed.  The signature is
    // specified in the target location: the addend is restricted to the lower
    // 32 bits (instead of the full 64 bits for ARM64_RELOC_UNSIGNED):
    //
    //   |63|62|61-51|50-49|  48  |47     -     32|31  -  0|
    //   | 1| 0|  0  | key | addr | discriminator | addend |
    //
    // The key is one of:
    //   IA: 00 IB: 01
    //   DA: 10 DB: 11
    //
    // The discriminator field is used as extra signature diversification.
    //
    // The addr field indicates whether the target address should be blended
    // into the discriminator.
    //
    ARM64_RELOC_AUTHENTICATED_POINTER,
};

#endif /* #ifndef _MACHO_ARM64_RELOC_H_ */