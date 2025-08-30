/*	$NetBSD: reg.h,v 1.2 2001/02/23 21:23:52 reinoud Exp $	*/
#ifndef MACHINE_REG_H
#define MACHINE_REG_H

#include <sys/_types.h>

struct reg {
	unsigned int r[13];
	unsigned int r_sp;
	unsigned int r_lr;
	unsigned int r_pc;
	unsigned int r_cpsr;
};

struct fpreg {
	__uint64_t	fpr_r[32];
	__uint32_t	fpr_fpscr;
};

struct dbreg {
#define	ARM_WR_MAX	16 /* Maximum number of watchpoint registers */
	unsigned int dbg_wcr[ARM_WR_MAX]; /* Watchpoint Control Registers */
	unsigned int dbg_wvr[ARM_WR_MAX]; /* Watchpoint Value Registers */
};

#endif /* !MACHINE_REG_H */