/*	$NetBSD: pte.h,v 1.9 2006/08/05 21:26:49 sanjayl Exp $	*/

#ifdef _KERNEL_OPT
#include "opt_ppcarch.h"
#endif

#if defined (PPC_OEA) || defined (PPC_OEA64_BRIDGE) || defined (PPC_OEA64)
#include <powerpc/oea/pte.h>
#endif