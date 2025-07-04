/* $NetBSD: intrdefs.h,v 1.17 2020/04/25 15:26:17 bouyer Exp $ */

/* This file co-exists, and is included via machine/intrdefs.h */

#ifndef _XEN_INTRDEFS_H_
#define _XEN_INTRDEFS_H_

/* Xen IPI types */
#define XEN_IPI_HALT		0x00000001
#define XEN_IPI_SYNCH_FPU	0x00000002
#define XEN_IPI_DDB		0x00000004
#define XEN_IPI_XCALL		0x00000008
#define XEN_IPI_HVCB		0x00000010
#define XEN_IPI_GENERIC		0x00000020
#define XEN_IPI_AST		0x00000040
#define XEN_IPI_KPREEMPT	0x00000080

/* Note: IPI_KICK does not have a handler. */
#define XEN_NIPIS		8

/* The number of 'irqs' that XEN understands */
#define NUM_XEN_IRQS 		256

#define XEN_IPI_NAMES {  "halt IPI", "FPU synch IPI", \
			 "DDB IPI", "xcall IPI", \
			 "HVCB IPI", "generic IPI", \
			 "AST IPI", "kpreempt IPI" }

#endif /* _XEN_INTRDEFS_H_ */