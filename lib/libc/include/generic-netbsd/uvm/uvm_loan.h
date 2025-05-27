/*	$NetBSD: uvm_loan.h,v 1.17 2011/02/02 15:13:34 chuck Exp $	*/

/*
 * Copyright (c) 1997 Charles D. Cranor and Washington University.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * from: Id: uvm_loan.h,v 1.1.4.1 1997/12/08 16:07:14 chuck Exp
 */

#ifndef _UVM_UVM_LOAN_H_
#define _UVM_UVM_LOAN_H_

#ifdef _KERNEL

/*
 * flags for uvm_loan()
 */

#define UVM_LOAN_TOANON		0x1		/* loan to anon */
#define UVM_LOAN_TOPAGE		0x2		/* loan to page */

/*
 * loan prototypes
 */

void uvm_loan_init(void);
int uvm_loan(struct vm_map *, vaddr_t, vsize_t, void *, int);
void uvm_unloan(void *, int, int);
int uvm_loanuobjpages(struct uvm_object *, voff_t, int,
    struct vm_page **);
struct vm_page *uvm_loanbreak(struct vm_page *);
int uvm_loanbreak_anon(struct vm_anon *, struct uvm_object *);

#endif /* _KERNEL */

#endif /* _UVM_UVM_LOAN_H_ */