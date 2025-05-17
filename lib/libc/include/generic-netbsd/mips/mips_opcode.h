/*	$NetBSD: mips_opcode.h,v 1.26 2021/04/05 07:28:19 simonb Exp $	*/

/*-
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Ralph Campbell.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)mips_opcode.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _MIPS_MIPS_OPCODE_H_
#define	_MIPS_MIPS_OPCODE_H_

/*
 * Define the instruction formats and opcode values for the
 * MIPS instruction set.
 */

/*
 * Define the instruction formats.
 */
typedef union {
	unsigned word;

#if BYTE_ORDER == LITTLE_ENDIAN
	struct {
		unsigned imm: 16;
		unsigned rt: 5;
		unsigned rs: 5;
		unsigned op: 6;
	} IType;

	struct {
		unsigned target: 26;
		unsigned op: 6;
	} JType;

	struct {
		unsigned func: 6;
		unsigned shamt: 5;
		unsigned rd: 5;
		unsigned rt: 5;
		unsigned rs: 5;
		unsigned op: 6;
	} RType;

	struct {
		unsigned func: 6;
		unsigned fd: 5;
		unsigned fs: 5;
		unsigned ft: 5;
		unsigned fmt: 4;
		unsigned : 1;		/* always '1' */
		unsigned op: 6;		/* always '0x11' */
	} FRType;

	struct {
		unsigned func: 6;
		unsigned zero: 1;	/* always '0' */
		unsigned offset: 9;
		unsigned rt: 5;
		unsigned rs: 5;
		unsigned op: 6;
	} S3OType; /* has "special3 offset" type */

#endif
#if BYTE_ORDER == BIG_ENDIAN
	struct {
		unsigned op: 6;
		unsigned rs: 5;
		unsigned rt: 5;
		unsigned imm: 16;
	} IType;

	struct {
		unsigned op: 6;
		unsigned target: 26;
	} JType;

	struct {
		unsigned op: 6;
		unsigned rs: 5;
		unsigned rt: 5;
		unsigned rd: 5;
		unsigned shamt: 5;
		unsigned func: 6;
	} RType;

	struct {
		unsigned op: 6;		/* always '0x11' */
		unsigned : 1;		/* always '1' */
		unsigned fmt: 4;
		unsigned ft: 5;
		unsigned fs: 5;
		unsigned fd: 5;
		unsigned func: 6;
	} FRType;

	struct {
		unsigned op: 6;
		unsigned rs: 5;
		unsigned rt: 5;
		unsigned offset: 9;
		unsigned zero: 1;	/* always '0' */
		unsigned func: 6;
	} S3OType; /* has "special3 offset" type */

#endif
} InstFmt;

/*
 * Values for the 'op' field.
 */
#define	OP_SPECIAL	000
#define	OP_REGIMM	001
#define	OP_J		002
#define	OP_JAL		003
#define	OP_BEQ		004
#define	OP_BNE		005
#define	OP_BLEZ		006
#define	OP_BGTZ		007

#define	OP_ADDI		010
#define	OP_ADDIU	011
#define	OP_SLTI		012
#define	OP_SLTIU	013
#define	OP_ANDI		014
#define	OP_ORI		015
#define	OP_XORI		016
#define	OP_LUI		017

#define	OP_COP0		020
#define	OP_COP1		021
#define	OP_COP2		022
#define	OP_COP3		023
#define	OP_BEQL		024		/* MIPS-II, for r4000 port */
#define	OP_BNEL		025		/* MIPS-II, for r4000 port */
#define	OP_BLEZL	026		/* MIPS-II, for r4000 port */
#define	OP_BGTZL	027		/* MIPS-II, for r4000 port */

#define	OP_DADDI	030		/* MIPS-II, for r4000 port */
#define	OP_DADDIU	031		/* MIPS-II, for r4000 port */
#define	OP_LDL		032		/* MIPS-II, for r4000 port */
#define	OP_LDR		033		/* MIPS-II, for r4000 port */

#define	OP_SPECIAL2	034		/* QED and MIPS32/MIPS64 opcodes */
#define	OP_JALX		035
#define	OP_MDMX		036
#define	OP_SPECIAL3	037

#define	OP_LB		040
#define	OP_LH		041
#define	OP_LWL		042
#define	OP_LW		043
#define	OP_LBU		044
#define	OP_LHU		045
#define	OP_LWR		046
#define	OP_LHU		045
#define	OP_LWR		046
#define	OP_LWU		047		/* MIPS-II, for r4000 port */

#define	OP_SB		050
#define	OP_SH		051
#define	OP_SWL		052
#define	OP_SW		053
#define	OP_SDL		054		/* MIPS-II, for r4000 port */
#define	OP_SDR		055		/* MIPS-II, for r4000 port */
#define	OP_SWR		056
#define	OP_CACHE	057		/* MIPS-II, for r4000 port */

#define	OP_LL		060
#define	OP_LWC0		OP_LL	/* backwards source compatibility */
#define	OP_LWC1		061
#define	OP_LWC2		062
#define	OP_PREF		063
#define	OP_LLD		064		/* MIPS-II, for r4000 port */
#define	OP_LDC1		065
#define	OP_LDC2		066
#define	OP_LD		067		/* MIPS-II, for r4000 port */
#define	OP_CVM_BBIT0	OP_LWC2
#define	OP_CVM_BBIT032	OP_LDC2

#define	OP_SC		070
#define	OP_SWC0		OP_SC	/* backwards source compatibility */
#define	OP_SWC1		071
#define	OP_SWC2		072
#define	OP_RSVD073	073
#define	OP_SCD		074		/* MIPS-II, for r4000 port */
#define	OP_SDC1		075
#define	OP_SDC2		076
#define	OP_SD		077		/* MIPS-II, for r4000 port */
#define	OP_CVM_BBIT1	OP_SWC2
#define	OP_CVM_BBIT132	OP_SDC2

/*
 * Values for the 'func' field when 'op' == OP_SPECIAL.
 */
#define	OP_SLL		000
#define	OP_SRL		002
#define	OP_SRA		003
#define	OP_SLLV		004
#define	OP_SRLV		006
#define	OP_SRAV		007

#define	OP_JR		010
#define	OP_JALR		011
#define	OP_SYSCALL	014
#define	OP_BREAK	015
#define	OP_SYNC		017		/* MIPS-II, for r4000 port */

#define	SYNC_CVM_IODBDMA	0x02
#define	SYNC_WMB	0x04
#define	SYNC_CVM_W	SYNC_WMB
#define	SYNC_CVM_WS	0x05
#define	SYNC_CVM_S	0x06
#define	SYNC_MB		0x10
#define	SYNC_ACQUIRE	0x11
#define	SYNC_RELEASE	0x12
#define	SYNC_RMB	0x13

#define	OP_MFHI		020
#define	OP_MTHI		021
#define	OP_MFLO		022
#define	OP_MTLO		023
#define	OP_DSLLV	024		/* MIPS-II, for r4000 port */
#define	OP_DSRLV	026		/* MIPS-II, for r4000 port */
#define	OP_DSRAV	027		/* MIPS-II, for r4000 port */

#define	OP_MULT		030
#define	OP_MULTU	031
#define	OP_DIV		032
#define	OP_DIVU		033
#define	OP_DMULT	034		/* MIPS-II, for r4000 port */
#define	OP_DMULTU	035		/* MIPS-II, for r4000 port */
#define	OP_DDIV		036		/* MIPS-II, for r4000 port */
#define	OP_DDIVU	037		/* MIPS-II, for r4000 port */

#define	OP_ADD		040
#define	OP_ADDU		041
#define	OP_SUB		042
#define	OP_SUBU		043
#define	OP_AND		044
#define	OP_OR		045
#define	OP_XOR		046
#define	OP_NOR		047

#define	OP_SLT		052
#define	OP_SLTU		053
#define	OP_DADD		054		/* MIPS-II, for r4000 port */
#define	OP_DADDU	055		/* MIPS-II, for r4000 port */
#define	OP_DSUB		056		/* MIPS-II, for r4000 port */
#define	OP_DSUBU	057		/* MIPS-II, for r4000 port */

#define	OP_TGE		060		/* MIPS-II, for r4000 port */
#define	OP_TGEU		061		/* MIPS-II, for r4000 port */
#define	OP_TLT		062		/* MIPS-II, for r4000 port */
#define	OP_TLTU		063		/* MIPS-II, for r4000 port */
#define	OP_TEQ		064		/* MIPS-II, for r4000 port */
#define	OP_TNE		066		/* MIPS-II, for r4000 port */

#define	OP_DSLL		070		/* MIPS-II, for r4000 port */
#define	OP_DSRL		072		/* MIPS-II, for r4000 port */
#define	OP_DSRA		073		/* MIPS-II, for r4000 port */
#define	OP_DSLL32	074		/* MIPS-II, for r4000 port */
#define	OP_DSRL32	076		/* MIPS-II, for r4000 port */
#define	OP_DSRA32	077		/* MIPS-II, for r4000 port */

/*
 * Subvalues for SLL where the source and destination registers
 * are both zero.
 */
#define	OP_SLL_NOP	0
#define	OP_SLL_SSNOP	1
#define	OP_SLL_EHB	3
#define	OP_SLL_PAUSE	5

/*
 * Values for the 'func' field when 'op' == OP_SPECIAL2.
 */
#define	OP_MADD		000		/* QED, MIPS32/64 */
#define	OP_MADDU	001		/* QED, MIPS32/64 */
#define	OP_MUL		002		/* QED, MIPS32/64 */
#define	OP_CVM_DMUL	003		/* OCTEON */
#define	OP_MSUB		004		/* MIPS32/64 */
#define	OP_MSUBU	005		/* MIPS32/64 */
#define	OP_CVM_SAA	030		/* OCTEON */
#define	OP_CVM_SAAD	031		/* OCTEON */
#define	OP_CLZ		040		/* MIPS32/64 */
#define	OP_CLO		041		/* MIPS32/64 */
#define	OP_DCLZ		044		/* MIPS32/64 */
#define	OP_DCLO		045		/* MIPS32/64 */
#define	OP_CVM_BADDU	050		/* OCTEON */
#define	OP_CVM_SEQ	052		/* OCTEON */
#define	OP_CVM_SNE	053		/* OCTEON */
#define	OP_CVM_SEQI	056		/* OCTEON */
#define	OP_CVM_SNEI	057		/* OCTEON */
#define	OP_CVM_POP	054		/* OCTEON */
#define	OP_CVM_DPOP	055		/* OCTEON */
#define	OP_CVM_CINS	062		/* OCTEON */
#define	OP_CVM_CINS32	063		/* OCTEON */
#define	OP_CVM_EXTS	072		/* OCTEON */
#define	OP_CVM_EXTS32	073		/* OCTEON */
#define	OP_SDBBP	077		/* MIPS32/MIPS64 */

/*
 * Values for the 'func' field when 'op' == OP_SPECIAL3.
 */
#define	OP_EXT		000		/* MIPS32/64 r2 */
#define	OP_DEXTM	001		/* MIPS32/64 r2 */
#define	OP_DEXTU	002		/* MIPS32/64 r2 */
#define	OP_DEXT		003		/* MIPS32/64 r2 */
#define	OP_INS		004		/* MIPS32/64 r2 */
#define	OP_DINSM	005		/* MIPS32/64 r2 */
#define	OP_DINSU	006		/* MIPS32/64 r2 */
#define	OP_DINS		007		/* MIPS32/64 r2 */
#define	OP_LX		012		/* DSP */
#define	OP_LWLE		031		/* EVA */
#define	OP_LWRE		032		/* EVA */
#define	OP_CACHEE	033		/* EVA */
#define	OP_SBE		034		/* EVA */
#define	OP_SHE		035		/* EVA */
#define	OP_SCE		036		/* EVA */
#define	OP_SWE		037		/* EVA */
#define	OP_BSHFL	040		/* MIPS32/64 r2 */
#define	OP_SWLE		041		/* EVA */
#define	OP_SWRE		042		/* EVA */
#define	OP_PREFE	043		/* EVA */
#define	OP_DBSHFL	044		/* MIPS32/64 r2 */
#define	OP_CACHE_R6	045		/* MIPS32/64 r6 */
#define	OP_LBUE		050		/* EVA */
#define	OP_LHUE		051		/* EVA */
#define	OP_LBE		054		/* EVA */
#define	OP_LHE		055		/* EVA */
#define	OP_LLE		056		/* EVA */
#define	OP_LWE		057		/* EVA */
#define	OP_RDHWR	073		/* MIPS32/64 r2 */

#define	OP_BSHFL_SBH	002		/* swap bytes within halfwords */
#define	OP_BSHFL_SHD	005		/* swap halfworks within double */
#define	OP_BSHFL_SEB	020		/* sign extend byte */
#define	OP_BSHFL_SEH	030		/* sign extend halfword */

#define	OP_LX_LWX	0		/* lwx */
#define	OP_LX_LHX	4		/* lhx */
#define	OP_LX_LBUX	6		/* lbux */
#define	OP_LX_LDX	8		/* ldx */

/*
 * Values for the 'func' field when 'op' == OP_REGIMM.
 */
#define	OP_BLTZ		000
#define	OP_BGEZ		001
#define	OP_BLTZL	002		/* MIPS-II, for r4000 port */
#define	OP_BGEZL	003		/* MIPS-II, for r4000 port */

#define	OP_TGEI		010		/* MIPS-II, for r4000 port */
#define	OP_TGEIU	011		/* MIPS-II, for r4000 port */
#define	OP_TLTI		012		/* MIPS-II, for r4000 port */
#define	OP_TLTIU	013		/* MIPS-II, for r4000 port */
#define	OP_TEQI		014		/* MIPS-II, for r4000 port */
#define	OP_TNEI		016		/* MIPS-II, for r4000 port */

#define	OP_BLTZAL	020		/* MIPS-II, for r4000 port */
#define	OP_BGEZAL	021
#define	OP_BLTZALL	022
#define	OP_BGEZALL	023

/*
 * Values for the 'rs' field when 'op' == OP_COPz.
 */
#define	OP_MF		000
#define	OP_DMF		001		/* MIPS-II, for r4000 port */
#define	OP_CF		002
#define	OP_MFH		003
#define	OP_MT		004
#define	OP_DMT		005		/* MIPS-II, for r4000 port */
#define	OP_CT		006
#define	OP_MTH		007
#define	OP_BCx		010
#define	OP_MFM		013		/* MIPS32/64 r2 */
#define	OP_BCy		014

/*
 * Values for the 'rt' field when 'op' == OP_COPz.
 */
#define	COPz_BC_TF_MASK	0x01
#define	COPz_BC_TRUE	0x01
#define	COPz_BC_FALSE	0x00
#define	COPz_BCL_TF_MASK	0x02		/* MIPS-II, for r4000 port */
#define	COPz_BCL_TRUE	0x02		/* MIPS-II, for r4000 port */
#define	COPz_BCL_FALSE	0x00		/* MIPS-II, for r4000 port */

#define	INSN_LUI_P(insn)	(((insn) >> 26) == OP_LUI)
#define	INSN_LW_P(insn)		(((insn) >> 26) == OP_LW)
#define	INSN_SW_P(insn)		(((insn) >> 26) == OP_SW)
#define	INSN_LD_P(insn)		(((insn) >> 26) == OP_LD)
#define	INSN_SD_P(insn)		(((insn) >> 26) == OP_SD)

#define	INSN_LOAD_P(insn)	(INSN_LD_P(insn) || INSN_LW_P(insn))
#define	INSN_STORE_P(insn)	(INSN_SD_P(insn) || INSN_SW_P(insn))

#endif /* _MIPS_MIPS_OPCODE_H_ */