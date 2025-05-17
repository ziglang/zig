/*	$NetBSD: cpuframe.h,v 1.8 2021/12/05 02:53:51 msaitoh Exp $	*/

/*
 * Copyright (c) 1988 University of Utah.
 * Copyright (c) 1982, 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department.
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
 * from: Utah $Hdr: frame.h 1.8 92/12/20$
 *
 *	@(#)frame.h	8.1 (Berkeley) 6/10/93
 */

#ifndef	_M68K_CPUFRAME_H_
#define	_M68K_CPUFRAME_H_

struct frame {
	struct trapframe {
		int	tf_regs[16];
		short	tf_pad;
		short	tf_stackadj;
		u_short	tf_sr;
		u_int	tf_pc __packed;
		u_short /* BITFIELDTYPE */ tf_format:4,
			/* BITFIELDTYPE */ tf_vector:12;
	} F_t;
	union F_u {
		struct fmt2 {
			u_int	f_iaddr;
		} F_fmt2;

		struct fmt3 {
			u_int	f_ea;
		} F_fmt3;

		struct fmt4 {
			u_int	f_fa;
			u_int	f_fslw;
			/* for 060FP type 4 FP disabled frames: */
#define 		f_fea	f_fa	
#define 		f_pcfi	f_fslw
		} F_fmt4;

		struct fmt7 {
			u_int	f_ea;
			u_short	f_ssw;
			u_short	f_wb3s, f_wb2s, f_wb1s;
			u_int	f_fa;
			u_int	f_wb3a, f_wb3d;
			u_int	f_wb2a, f_wb2d;
			u_int	f_wb1a, f_wb1d;
#define				f_pd0 f_wb1d
			u_int	f_pd1, f_pd2, f_pd3;
		} F_fmt7;

		struct fmt8 {
			u_short	f_ssw;
			u_int	f_accaddr;
			u_short	f_ir0;
			u_short	f_dob;
			u_short	f_ir1;
			u_short	f_dib;
			u_short	f_ir2;
			u_short	f_irc;
			u_short	f_maskpc;
			u_short	f_iregs[15];
		} __attribute__((packed)) F_fmt8;

		struct fmt9 {
			u_int	f_iaddr;
			u_short	f_iregs[4];
		} F_fmt9;

		struct fmtA {
			u_short	f_ir0;
			u_short	f_ssw;
			u_short	f_ipsc;
			u_short	f_ipsb;
			u_int	f_dcfa;
			u_short	f_ir1, f_ir2;
			u_int	f_dob;
			u_short	f_ir3, f_ir4;
		} F_fmtA;

		struct fmtB {
			u_short	f_ir0;
			u_short	f_ssw;
			u_short	f_ipsc;
			u_short	f_ipsb;
			u_int	f_dcfa;
			u_short	f_ir1, f_ir2;
			u_int	f_dob;
			u_short	f_ir3, f_ir4;
			u_short	f_ir5, f_ir6;
			u_int	f_sba;
			u_short	f_ir7, f_ir8;
			u_int	f_dib;
			u_short	f_iregs[22];
		} F_fmtB;
	} F_u;
};

#define	f_regs		F_t.tf_regs
#define	f_stackadj	F_t.tf_stackadj
#define	f_sr		F_t.tf_sr
#define	f_pc		F_t.tf_pc
#define	f_format	F_t.tf_format
#define	f_vector	F_t.tf_vector
#define	f_fmt2		F_u.F_fmt2
#define	f_fmt3		F_u.F_fmt3
#define	f_fmt4		F_u.F_fmt4
#define	f_fmt7		F_u.F_fmt7
#define	f_fmt8		F_u.F_fmt8
#define	f_fmt9		F_u.F_fmt9
#define	f_fmtA		F_u.F_fmtA
#define	f_fmtB		F_u.F_fmtB

struct switchframe {
	u_int	sf_pc;
};

struct fpframe {
	union FPF_u1 {
		u_int	FPF_null;
		struct {
			u_char	FPF_version;
			u_char	FPF_fsize;
			u_short	FPF_res1;
		} FPF_nonnull;
	} FPF_u1;
	union FPF_u2 {
		struct fpidle {
			u_short	fpf_ccr;
			u_short	fpf_res2;
			u_int	fpf_iregs1[8];
			u_int	fpf_xops[3];
			u_int	fpf_opreg;
			u_int	fpf_biu;
		} FPF_idle;

		struct fpbusy {
			u_int	fpf_iregs[53];
		} FPF_busy;

		struct fpunimp {
			u_int	fpf_state[10];
		} FPF_unimp;
	} FPF_u2;
	u_int	fpf_regs[8*3];
	u_int	fpf_fpcr;
	u_int	fpf_fpsr;
	u_int	fpf_fpiar;
};

#define fpf_null	FPF_u1.FPF_null
#define fpf_version	FPF_u1.FPF_nonnull.FPF_version
#define fpf_fsize	FPF_u1.FPF_nonnull.FPF_fsize
#define fpf_res1	FPF_u1.FPF_nonnull.FPF_res1
#define fpf_idle	FPF_u2.FPF_idle
#define fpf_busy	FPF_u2.FPF_busy
#define fpf_unimp	FPF_u2.FPF_unimp

/* 
 * This is incompatible with the earlier one; especially, an earlier frame 
 * must not be FRESTOREd on a 060 or vv, because a frame error exception is
 * not guaranteed.
 */


struct fpframe060 {
	u_short	fpf6_excp_exp;
	u_char	fpf6_frmfmt;

	u_char	fpf6_v;

	u_long	fpf6_upper, fpf6_lower;
};

#endif	/* _M68K_CPUFRAME_H_ */