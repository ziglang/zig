/*	$NetBSD: vmparam.h,v 1.5 2014/04/19 12:48:42 matt Exp $	*/

#ifndef _EVBMIPS_VMPARAM_H_
#define _EVBMIPS_VMPARAM_H_

#include <mips/vmparam.h>

#define	VM_PHYSSEG_MAX		32

#undef VM_FREELIST_MAX
#define	VM_FREELIST_MAX		4
#if defined(_MIPS_PADDR_T_64BIT) || defined(_LP64)
#define	VM_FREELIST_FIRST4G	3
#endif
#if !defined(_LP64)
#define	VM_FREELIST_FIRST512M	2
#endif /* !_LP64 */
#define VM_FREELIST_ISADMA	1

#define VM_FREELIST_NORMALOK_P(lcv) \
	((lcv) == VM_FREELIST_DEFAULT || (lcv) != mips_poolpage_vmfreelist)
 
#endif	/* !_EVBMIPS_VMPARAM_H_ */