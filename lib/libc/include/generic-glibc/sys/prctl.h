/* Copyright (C) 1997-2021 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _SYS_PRCTL_H
#define _SYS_PRCTL_H	1

#include <features.h>
#include <linux/prctl.h>  /*  The magic values come from here  */

/* Recent extensions to linux which may post-date the kernel headers
   we're picking up...  */

/* Memory tagging control operations (for AArch64).  */
#ifndef PR_TAGGED_ADDR_ENABLE
# define PR_TAGGED_ADDR_ENABLE	(1UL << 8)
#endif

#ifndef PR_MTE_TCF_SHIFT
# define PR_MTE_TCF_SHIFT	1
# define PR_MTE_TCF_NONE	(0UL << PR_MTE_TCF_SHIFT)
# define PR_MTE_TCF_SYNC	(1UL << PR_MTE_TCF_SHIFT)
# define PR_MTE_TCF_ASYNC	(2UL << PR_MTE_TCF_SHIFT)
# define PR_MTE_TCF_MASK	(3UL << PR_MTE_TCF_SHIFT)
# define PR_MTE_TAG_SHIFT	3
# define PR_MTE_TAG_MASK	(0xffffUL << PR_MTE_TAG_SHIFT)
#endif

__BEGIN_DECLS

/* Control process execution.  */
extern int prctl (int __option, ...) __THROW;

__END_DECLS

#endif  /* sys/prctl.h */