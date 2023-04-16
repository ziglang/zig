/* Definition for thread-local data handling.  Generic version.
   Copyright (C) 2002-2023 Free Software Foundation, Inc.
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

/* An architecture-specific version of this file has to defined a
   number of symbols:

     TCB_ALIGNMENT

     Alignment of THREAD_SELF (struct pthread *) and the thread
     pointer.

     TLS_TCB_AT_TP  or  TLS_DTV_AT_TP

     The presence of one of these symbols signals which variant of
     the TLS ABI is used.  There are in the moment two variants
     available:

     * the thread pointer points to a thread control block

     * the thread pointer points to the dynamic thread vector


     TLS_TCB_SIZE

     This is the size of the thread control block structure.  How
     this is actually defined depends on the ABI.  The thread control
     block could be internal descriptor of the thread library or
     just a data structure which allows finding the DTV.

     TLS_INIT_TCB_SIZE

     Similarly, but this value is only used at startup and in the
     dynamic linker itself.  There are no threads in use at that time.


     INSTALL_DTV(tcb, init_dtv)

     This macro must install the given initial DTV into the thread control
     block TCB.  The normal runtime functionality must then be able to
     use the value.


     TLS_INIT_TP(tcb)

     This macro must initialize the thread pointer to enable normal TLS
     operation.  The parameter is a pointer to the thread control block.
     ld.so calls this macro once.


     THREAD_DTV()

     This macro returns the address of the DTV of the current thread.
     This normally is done using the thread register which points
     to the dtv or the TCB (from which the DTV can found).
  */
