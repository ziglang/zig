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
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */


#include <sys/types.h>
#include <sys/stat.h>

/* This definition is only used if inlining fails for this function; see
   the last page of <sys/stat.h>.  The real work is done by the `x'
   function which is passed a version number argument.  We arrange in the
   makefile that when not inlined this function is always statically
   linked; that way a dynamically-linked executable always encodes the
   version number corresponding to the data structures it uses, so the `x'
   functions in the shared library can adapt without needing to recompile
   all callers.  */

int
attribute_hidden
__mknod (const char *path, mode_t mode, dev_t dev)
{
  return __xmknod (_MKNOD_VER, path, mode, &dev);
}

weak_hidden_alias (__mknod, mknod)
