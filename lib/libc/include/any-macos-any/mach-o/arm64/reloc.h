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
 * Relocation types used in the arm64 implementation.
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