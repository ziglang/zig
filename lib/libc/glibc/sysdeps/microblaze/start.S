/* Copyright (C) 1995-2020 Free Software Foundation, Inc.

   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   In addition to the permissions in the GNU Lesser General Public
   License, the Free Software Foundation gives you unlimited
   permission to link the compiled version of this file with other
   programs, and to distribute those programs without any restriction
   coming from the use of this file. (The GNU Lesser General Public
   License restrictions do apply in other respects; for example, they
   cover modification of the file, and distribution when not linked
   into another program.)

   Note that people who make modified versions of this file are not
   obligated to grant this special exception for their modified
   versions; it is their choice whether to do so. The GNU Lesser
   General Public License gives permission to release a modified
   version without this exception; this exception also makes it
   possible to release a modified version which carries forward this
   exception.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

    .text
    .globl _start
    .type _start,@function
_start:
    /* On entry the stack contains the following args:
         r1+0 - argc
         r1+4 - argv[0]
         ...
         r1+4*(argc-1) - argv[argc-1]
         r1+4*argc - NULL
         r1+4*argc + 4 - envp[0]
         ...
         NULL
    */
    addk    r3,r0,r0
    addk    r5,r1,r0
1:
    addik   r5,r5,4
    lw      r4,r5,r0
    bneid   r4,1b
    addik   r3,r3,1
    addik   r6,r3,-1
    sw      r6,r1,r0
    addik   r7,r1,4
    addik   r1,r1,-24
#ifdef SHARED
    /* Setup PIC.  */
    mfs     r20,rpc
    addik   r20,r20,_GLOBAL_OFFSET_TABLE_+8
    lwi     r5,r20,main@GOT
    lwi     r8,r20,__libc_csu_init@GOT
    lwi     r9,r20,__libc_csu_fini@GOT
    brid    __libc_start_main@PLT
    addk    r10,r0,r0
#else
    addik   r5,r0,main
    addik   r8,r0,__libc_csu_init
    addik   r9,r0,__libc_csu_fini
    brid    __libc_start_main
    addk    r10,r0,r0
#endif

/* Define a symbol for the first piece of initialized data.  */
    .data
    .globl __data_start
__data_start:
    .long 0
    .weak data_start
    data_start = __data_start
