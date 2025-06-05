/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2009 Hudson River Trading LLC
 * Written by: John H. Baldwin <jhb@FreeBSD.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _MACHINE_VM_H_
#define	_MACHINE_VM_H_

#include <machine/specialreg.h>

/* Memory attributes. */
#define	VM_MEMATTR_UNCACHEABLE		((vm_memattr_t)PAT_UNCACHEABLE)
#define	VM_MEMATTR_WRITE_COMBINING	((vm_memattr_t)PAT_WRITE_COMBINING)
#define	VM_MEMATTR_WRITE_THROUGH	((vm_memattr_t)PAT_WRITE_THROUGH)
#define	VM_MEMATTR_WRITE_PROTECTED	((vm_memattr_t)PAT_WRITE_PROTECTED)
#define	VM_MEMATTR_WRITE_BACK		((vm_memattr_t)PAT_WRITE_BACK)
#define	VM_MEMATTR_WEAK_UNCACHEABLE	((vm_memattr_t)PAT_UNCACHED)

#define	VM_MEMATTR_DEFAULT		VM_MEMATTR_WRITE_BACK
#define	VM_MEMATTR_DEVICE		VM_MEMATTR_UNCACHEABLE

#endif /* !_MACHINE_VM_H_ */