/* Copyright (C) 1998-2023 Free Software Foundation, Inc.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _SYS_REG_H
#define _SYS_REG_H	1

/* Index into an array of 4 byte integers returned from ptrace for
   location of the users' stored general purpose registers. */

enum
{
  PT_D1 = 0,
#define PT_D1 PT_D1
  PT_D2 = 1,
#define PT_D2 PT_D2
  PT_D3 = 2,
#define PT_D3 PT_D3
  PT_D4 = 3,
#define PT_D4 PT_D4
  PT_D5 = 4,
#define PT_D5 PT_D5
  PT_D6 = 5,
#define PT_D6 PT_D6
  PT_D7 = 6,
#define PT_D7 PT_D7
  PT_A0 = 7,
#define PT_A0 PT_A0
  PT_A1 = 8,
#define PT_A1 PT_A1
  PT_A2 = 9,
#define PT_A2 PT_A2
  PT_A3 = 10,
#define PT_A3 PT_A3
  PT_A4 = 11,
#define PT_A4 PT_A4
  PT_A5 = 12,
#define PT_A5 PT_A5
  PT_A6 = 13,
#define PT_A6 PT_A6
  PT_D0 = 14,
#define PT_D0 PT_D0
  PT_USP = 15,
#define PT_USP PT_USP
  PT_ORIG_D0 = 16,
#define PT_ORIG_D0 PT_ORIG_D0
  PT_SR = 17,
#define PT_SR PT_SR
  PT_PC = 18,
#define PT_PC PT_PC

#ifdef __mcoldfire__
  PT_FP0 = 21,
  PT_FP1 = 23,
  PT_FP2 = 25,
  PT_FP3 = 27,
  PT_FP4 = 29,
  PT_FP5 = 31,
  PT_FP6 = 33,
  PT_FP7 = 35,
#else
  PT_FP0 = 21,
  PT_FP1 = 24,
  PT_FP2 = 27,
  PT_FP3 = 30,
  PT_FP4 = 33,
  PT_FP5 = 36,
  PT_FP6 = 39,
  PT_FP7 = 42,
#endif
#define PT_FP0 PT_FP0
#define PT_FP1 PT_FP1
#define PT_FP2 PT_FP2
#define PT_FP3 PT_FP3
#define PT_FP4 PT_FP4
#define PT_FP5 PT_FP5
#define PT_FP6 PT_FP6
#define PT_FP7 PT_FP7

  PT_FPCR = 45,
#define PT_FPCR PT_FPCR
  PT_FPSR = 46,
#define PT_FPSR PT_FPSR
  PT_FPIAR = 47
#define PT_FPIAR PT_FPIAR
};

#endif	/* _SYS_REG_H */