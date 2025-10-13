/*-
 * Copyright (c) 2009 Alan L. Cox <alc@cs.rice.edu>
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

/* Memory attribute configuration. */
#define	VM_MEMATTR_DEVICE_nGnRnE	0
#define	VM_MEMATTR_UNCACHEABLE		1
#define	VM_MEMATTR_WRITE_BACK		2
#define	VM_MEMATTR_WRITE_THROUGH	3
#define	VM_MEMATTR_DEVICE_nGnRE		4

#define	VM_MEMATTR_DEVICE		VM_MEMATTR_DEVICE_nGnRE
#define	VM_MEMATTR_DEVICE_NP		VM_MEMATTR_DEVICE_nGnRnE

#ifdef _KERNEL
/* If defined vmstat will try to use both of these in a switch statement */
#define	VM_MEMATTR_WRITE_COMBINING	VM_MEMATTR_WRITE_THROUGH
#endif

#define	VM_MEMATTR_DEFAULT	VM_MEMATTR_WRITE_BACK

#endif /* !_MACHINE_VM_H_ */