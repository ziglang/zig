/*
 * Copyright (c) 2006 Apple Computer, Inc. All rights reserved.
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
 * Relocations for x86_64 are a bit different than for other architectures in
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
 * The addend (i.e. the 4 in _foo+4) is encoded in the instruction (Mach-O does
 * not have RELA relocations).  For PC-relative relocations, the addend is
 * stored directly in the instruction.  This is different from other Mach-O
 * architectures, which encode the addend minus the current section offset.
 * 
 * The relocation types are:
 * 
 * 	X86_64_RELOC_UNSIGNED	// for absolute addresses
 * 	X86_64_RELOC_SIGNED		// for signed 32-bit displacement
 * 	X86_64_RELOC_BRANCH		// a CALL/JMP instruction with 32-bit displacement
 * 	X86_64_RELOC_GOT_LOAD	// a MOVQ load of a GOT entry
 * 	X86_64_RELOC_GOT		// other GOT references
 * 	X86_64_RELOC_SUBTRACTOR	// must be followed by a X86_64_RELOC_UNSIGNED
 * 
 * The following are sample assembly instructions, followed by the relocation
 * and section content they generate in an object file:
 * 
 * 	call _foo
 * 		r_type=X86_64_RELOC_BRANCH, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 * 		E8 00 00 00 00
 * 
 * 	call _foo+4
 * 		r_type=X86_64_RELOC_BRANCH, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 * 		E8 04 00 00 00 
 * 
 * 	movq _foo@GOTPCREL(%rip), %rax
 * 		r_type=X86_64_RELOC_GOT_LOAD, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 * 		48 8B 05 00 00 00 00
 * 	
 * 	pushq _foo@GOTPCREL(%rip)
 * 		r_type=X86_64_RELOC_GOT, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 * 		FF 35 00 00 00 00
 * 	
 * 	movl _foo(%rip), %eax
 * 		r_type=X86_64_RELOC_SIGNED, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 * 		8B 05 00 00 00 00
 * 
 * 	movl _foo+4(%rip), %eax
 * 		r_type=X86_64_RELOC_SIGNED, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 * 		8B 05 04 00 00 00
 * 
 * 	movb  $0x12, _foo(%rip)
 * 		r_type=X86_64_RELOC_SIGNED, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 * 		C6 05 FF FF FF FF 12
 * 
 * 	movl  $0x12345678, _foo(%rip)
 * 		r_type=X86_64_RELOC_SIGNED, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_foo
 * 		C7 05 FC FF FF FF 78 56 34 12
 * 
 * 	.quad _foo
 * 		r_type=X86_64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 * 		00 00 00 00 00 00 00 00
 * 
 * 	.quad _foo+4
 * 		r_type=X86_64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 * 		04 00 00 00 00 00 00 00
 * 
 * 	.quad _foo - _bar
 * 		r_type=X86_64_RELOC_SUBTRACTOR, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_bar
 * 		r_type=X86_64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 * 		00 00 00 00 00 00 00 00
 * 
 * 	.quad _foo - _bar + 4
 * 		r_type=X86_64_RELOC_SUBTRACTOR, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_bar
 * 		r_type=X86_64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 * 		04 00 00 00 00 00 00 00
 * 	
 * 	.long _foo - _bar
 * 		r_type=X86_64_RELOC_SUBTRACTOR, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_bar
 * 		r_type=X86_64_RELOC_UNSIGNED, r_length=2, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 * 		00 00 00 00
 * 
 * 	lea L1(%rip), %rax
 * 		r_type=X86_64_RELOC_SIGNED, r_length=2, r_extern=1, r_pcrel=1, r_symbolnum=_prev
 * 		48 8d 05 12 00 00 00
 * 		// assumes _prev is the first non-local label 0x12 bytes before L1
 * 
 * 	lea L0(%rip), %rax
 * 		r_type=X86_64_RELOC_SIGNED, r_length=2, r_extern=0, r_pcrel=1, r_symbolnum=3
 * 		48 8d 05 56 00 00 00
 *		// assumes L0 is in third section and there is no previous non-local label.
 *		// The rip-relative-offset of 0x00000056 is L0-address_of_next_instruction.
 *		// address_of_next_instruction is the address of the relocation + 4.
 *
 *     add     $6,L0(%rip)
 *             r_type=X86_64_RELOC_SIGNED_1, r_length=2, r_extern=0, r_pcrel=1, r_symbolnum=3
 *		83 05 18 00 00 00 06
 *		// assumes L0 is in third section and there is no previous non-local label.
 *		// The rip-relative-offset of 0x00000018 is L0-address_of_next_instruction.
 *		// address_of_next_instruction is the address of the relocation + 4 + 1.
 *		// The +1 comes from SIGNED_1.  This is used because the relocation is not
 *		// at the end of the instruction.
 *
 * 	.quad L1
 * 		r_type=X86_64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_prev
 * 		12 00 00 00 00 00 00 00
 * 		// assumes _prev is the first non-local label 0x12 bytes before L1
 * 
 * 	.quad L0
 * 		r_type=X86_64_RELOC_UNSIGNED, r_length=3, r_extern=0, r_pcrel=0, r_symbolnum=3
 * 		56 00 00 00 00 00 00 00
 * 		// assumes L0 is in third section, has an address of 0x00000056 in .o
 * 		// file, and there is no previous non-local label
 * 
 * 	.quad _foo - .
 * 		r_type=X86_64_RELOC_SUBTRACTOR, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_prev
 * 		r_type=X86_64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 * 		EE FF FF FF FF FF FF FF
 * 		// assumes _prev is the first non-local label 0x12 bytes before this
 * 		// .quad
 * 
 * 	.quad _foo - L1
 * 		r_type=X86_64_RELOC_SUBTRACTOR, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_prev
 * 		r_type=X86_64_RELOC_UNSIGNED, r_length=3, r_extern=1, r_pcrel=0, r_symbolnum=_foo
 * 		EE FF FF FF FF FF FF FF
 * 		// assumes _prev is the first non-local label 0x12 bytes before L1
 * 
 * 	.quad L1 - _prev
 * 		// No relocations.  This is an assembly time constant.
 * 		12 00 00 00 00 00 00 00
 * 		// assumes _prev is the first non-local label 0x12 bytes before L1
 *
 *
 *
 * In final linked images, there are only two valid relocation kinds:
 *
 *     r_type=X86_64_RELOC_UNSIGNED, r_length=3, r_pcrel=0, r_extern=1, r_symbolnum=sym_index
 *	This tells dyld to add the address of a symbol to a pointer sized (8-byte)
 *  piece of data (i.e on disk the 8-byte piece of data contains the addend). The 
 *  r_symbolnum contains the index into the symbol table of the target symbol.
 *
 *     r_type=X86_64_RELOC_UNSIGNED, r_length=3, r_pcrel=0, r_extern=0, r_symbolnum=0
 * This tells dyld to adjust the pointer sized (8-byte) piece of data by the amount
 * the containing image was loaded from its base address (e.g. slide).
 *
 */ 
enum reloc_type_x86_64
{
	X86_64_RELOC_UNSIGNED,		// for absolute addresses
	X86_64_RELOC_SIGNED,		// for signed 32-bit displacement
	X86_64_RELOC_BRANCH,		// a CALL/JMP instruction with 32-bit displacement
	X86_64_RELOC_GOT_LOAD,		// a MOVQ load of a GOT entry
	X86_64_RELOC_GOT,			// other GOT references
	X86_64_RELOC_SUBTRACTOR,	// must be followed by a X86_64_RELOC_UNSIGNED
	X86_64_RELOC_SIGNED_1,		// for signed 32-bit displacement with a -1 addend
	X86_64_RELOC_SIGNED_2,		// for signed 32-bit displacement with a -2 addend
	X86_64_RELOC_SIGNED_4,		// for signed 32-bit displacement with a -4 addend
	X86_64_RELOC_TLV,		// for thread local variables
};
