/*	$NetBSD: keyboard.h,v 1.6 1997/04/09 04:48:57 scottr Exp $	*/

/*-
 * Copyright (C) 1993	Allen K. Briggs, Chris P. Caputo,
 *			Michael L. Finch, Bradley A. Grantham, and
 *			Lawrence A. Kesteloot
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the Alice Group.
 * 4. The names of the Alice Group or any of its members may not be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE ALICE GROUP ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE ALICE GROUP BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#define ADBK_LEFT	0x3B
#define ADBK_RIGHT	0x3C
#define ADBK_UP		0x3E
#define ADBK_DOWN	0x3D
#define ADBK_PGUP	0x74
#define ADBK_PGDN	0x79
#define ADBK_HOME	0x73
#define ADBK_END	0x77
#define ADBK_CONTROL	0x36
#define ADBK_FLOWER	0x37
#define ADBK_SHIFT	0x38
#define ADBK_CAPSLOCK	0x39
#define ADBK_OPTION	0x3A
#define ADBK_F		0x03
#define ADBK_O		0x1F
#define ADBK_P		0x23
#define ADBK_Q		0x0C
#define ADBK_V		0x09
#define ADBK_1		0x12
#define ADBK_2		0x13
#define ADBK_3		0x14
#define ADBK_4		0x15
#define ADBK_5		0x17
#define ADBK_6		0x16
#define ADBK_7		0x1A
#define ADBK_8		0x1C
#define ADBK_9		0x19
#define ADBK_0		0x1D

#define ADBK_KEYVAL(key)	((key) & 0x7f)
#define ADBK_PRESS(key)		(((key) & 0x80) == 0)
#define ADBK_KEYDOWN(key)	(key)
#define ADBK_KEYUP(key)		((key) | 0x80)
#define ADBK_MODIFIER(key)	((((key) & 0x7f) == ADBK_SHIFT) || \
				 (((key) & 0x7f) == ADBK_CONTROL) || \
				 (((key) & 0x7f) == ADBK_FLOWER) || \
				 (((key) & 0x7f) == ADBK_OPTION))

#ifndef KEYBOARD_ARRAY
extern unsigned char keyboard[128][3];
#else
unsigned char keyboard[128][3] = {
		/* Scan code      Normal     Shifted     Controlled */
	{	/*   0x00, */       'a',       'A',         0x01 },
	{	/*   0x01, */       's',       'S',         0x13 },
	{	/*   0x02, */       'd',       'D',         0x04 },
	{	/*   0x03, */       'f',       'F',         0x06 },
	{	/*   0x04, */       'h',       'H',         0x08 },
	{	/*   0x05, */       'g',       'G',         0x07 },
	{	/*   0x06, */       'z',       'Z',         0x1A },
	{	/*   0x07, */       'x',       'X',         0x18 },
	{	/*   0x08, */       'c',       'C',         0x03 },
	{	/*   0x09, */       'v',       'V',         0x16 },
	{	/*   0x0A, */      0x00,      0x00,         0x00 },
	{	/*   0x0B, */       'b',       'B',         0x02 },
	{	/*   0x0C, */       'q',       'Q',         0x11 },
	{	/*   0x0D, */       'w',       'W',         0x17 },
	{	/*   0x0E, */       'e',       'E',         0x05 },
	{	/*   0x0F, */       'r',       'R',         0x12 },
	{	/*   0x10, */       'y',       'Y',         0x19 },
	{	/*   0x11, */       't',       'T',         0x14 },
	{	/*   0x12, */       '1',       '!',         0x00 },
	{	/*   0x13, */       '2',       '@',         0x00 },
	{	/*   0x14, */       '3',       '#',         0x00 },
	{	/*   0x15, */       '4',       '$',         0x00 },
	{	/*   0x16, */       '6',       '^',         0x1E },
	{	/*   0x17, */       '5',       '%',         0x00 },
	{	/*   0x18, */       '=',       '+',         0x00 },
	{	/*   0x19, */       '9',       '(',         0x00 },
	{	/*   0x1A, */       '7',       '&',         0x00 },
	{	/*   0x1B, */       '-',       '_',         0x1F },
	{	/*   0x1C, */       '8',       '*',         0x00 },
	{	/*   0x1D, */       '0',       ')',         0x00 },
	{	/*   0x1E, */       ']',       '}',         0x1D },
	{	/*   0x1F, */       'o',       'O',         0x0F },
	{	/*   0x20, */       'u',       'U',         0x15 },
	{	/*   0x21, */       '[',       '{',         0x1B },
	{	/*   0x22, */       'i',       'I',         0x09 },
	{	/*   0x23, */       'p',       'P',         0x10 },
	{	/*   0x24, */      0x0D,      0x0D,         0x0D },
	{	/*   0x25, */       'l',       'L',         0x0C },
	{	/*   0x26, */       'j',       'J',         0x0A },
	{	/*   0x27, */      '\'',       '"',         0x00 },
	{	/*   0x28, */       'k',       'K',         0x0B },
	{	/*   0x29, */       ';',       ':',         0x00 },
	{	/*   0x2A, */      '\\',       '|',         0x1C },
	{	/*   0x2B, */       ',',       '<',         0x00 },
	{	/*   0x2C, */       '/',       '?',         0x00 },
	{	/*   0x2D, */       'n',       'N',         0x0E },
	{	/*   0x2E, */       'm',       'M',         0x0D },
	{	/*   0x2F, */       '.',       '>',         0x00 },
	{	/*   0x30, */      0x09,      0x09,         0x09 },
	{	/*   0x31, */       ' ',       ' ',         0x00 },
	{	/*   0x32, */       '`',       '~',         0x00 },
	{	/*   0x33, */      0x7F,      0x7F,         0x7F }, /* Delete */
	{	/*   0x34, */      0x00,      0x00,         0x00 },
	{	/*   0x35, */      0x1B,      0x1B,         0x1B },
	{	/*   0x36, */      0x00,      0x00,         0x00 },
	{	/*   0x37, */      0x00,      0x00,         0x00 },
	{	/*   0x38, */      0x00,      0x00,         0x00 },
	{	/*   0x39, */      0x00,      0x00,         0x00 },
	{	/*   0x3A, */      0x00,      0x00,         0x00 },
	{	/*   0x3B, */       'h',      0x00,         0x00 },  /* Left */
	{	/*   0x3C, */       'l',      0x00,         0x00 },  /* Right */
	{	/*   0x3D, */       'j',      0x00,         0x00 },  /* Down */
	{	/*   0x3E, */       'k',      0x00,         0x00 },  /* Up */
	{	/*   0x3F, */      0x00,      0x00,         0x00 },
	{	/*   0x40, */      0x00,      0x00,         0x00 },
	{	/*   0x41, */       '.',       '.',         0x00 },
	{	/*   0x42, */      0x00,      0x00,         0x00 },
	{	/*   0x43, */       '*',       '*',         0x00 },
	{	/*   0x44, */      0x00,      0x00,         0x00 },
	{	/*   0x45, */       '+',       '+',         0x00 },
	{	/*   0x46, */      0x00,      0x00,         0x00 },
	{	/*   0x47, */      0x00,      0x00,         0x00 },
	{	/*   0x48, */      0x00,      0x00,         0x00 },
	{	/*   0x49, */      0x00,      0x00,         0x00 },
	{	/*   0x4A, */      0x00,      0x00,         0x00 },
	{	/*   0x4B, */       '/',       '/',         0x00 },
	{	/*   0x4C, */      0x0D,      0x0D,         0x0D },
	{	/*   0x4D, */      0x00,      0x00,         0x00 },
	{	/*   0x4E, */       '-',       '-',         0x00 },
	{	/*   0x4F, */      0x00,      0x00,         0x00 },
	{	/*   0x50, */      0x00,      0x00,         0x00 },
	{	/*   0x51, */       '=',       '=',         0x00 },
	{	/*   0x52, */       '0',       '0',         0x00 },
	{	/*   0x53, */       '1',       '1',         0x00 },
	{	/*   0x54, */       '2',       '2',         0x00 },
	{	/*   0x55, */       '3',       '3',         0x00 },
	{	/*   0x56, */       '4',       '4',         0x00 },
	{	/*   0x57, */       '5',       '5',         0x00 },
	{	/*   0x58, */       '6',       '6',         0x00 },
	{	/*   0x59, */       '7',       '7',         0x00 },
	{	/*   0x5A, */      0x00,      0x00,         0x00 },
	{	/*   0x5B, */       '8',       '8',         0x00 },
	{	/*   0x5C, */       '9',       '9',         0x00 },
	{	/*   0x5D, */      0x00,      0x00,         0x00 },
	{	/*   0x5E, */      0x00,      0x00,         0x00 },
	{	/*   0x5F, */      0x00,      0x00,         0x00 },
	{	/*   0x60, */      0x00,      0x00,         0x00 },
	{	/*   0x61, */      0x00,      0x00,         0x00 },
	{	/*   0x62, */      0x00,      0x00,         0x00 },
	{	/*   0x63, */      0x00,      0x00,         0x00 },
	{	/*   0x64, */      0x00,      0x00,         0x00 },
	{	/*   0x65, */      0x00,      0x00,         0x00 },
	{	/*   0x66, */      0x00,      0x00,         0x00 },
	{	/*   0x67, */      0x00,      0x00,         0x00 },
	{	/*   0x68, */      0x00,      0x00,         0x00 },
	{	/*   0x69, */      0x00,      0x00,         0x00 },
	{	/*   0x6A, */      0x00,      0x00,         0x00 },
	{	/*   0x6B, */      0x00,      0x00,         0x00 },
	{	/*   0x6C, */      0x00,      0x00,         0x00 },
	{	/*   0x6D, */      0x00,      0x00,         0x00 },
	{	/*   0x6E, */      0x00,      0x00,         0x00 },
	{	/*   0x6F, */      0x00,      0x00,         0x00 },
	{	/*   0x70, */      0x00,      0x00,         0x00 },
	{	/*   0x71, */      0x00,      0x00,         0x00 },
	{	/*   0x72, */      0x00,      0x00,         0x00 },
	{	/*   0x73, */      0x00,      0x00,         0x00 },
	{	/*   0x74, */      0x00,      0x00,         0x00 },
	{	/*   0x75, */      0x00,      0x00,         0x00 },
	{	/*   0x76, */      0x00,      0x00,         0x00 },
	{	/*   0x77, */      0x00,      0x00,         0x00 },
	{	/*   0x78, */      0x00,      0x00,         0x00 },
	{	/*   0x79, */      0x00,      0x00,         0x00 },
	{	/*   0x7A, */      0x00,      0x00,         0x00 },
	{	/*   0x7B, */      0x00,      0x00,         0x00 },
	{	/*   0x7C, */      0x00,      0x00,         0x00 },
	{	/*   0x7D, */      0x00,      0x00,         0x00 },
	{	/*   0x7E, */      0x00,      0x00,         0x00 },
	{	/*   0x7F, */      0x00,      0x00,         0x00 }
};
#endif /* KEYBOARD_ARRAY */