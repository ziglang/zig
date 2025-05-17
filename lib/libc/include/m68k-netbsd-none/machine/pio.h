/*	$NetBSD: pio.h,v 1.4 2005/12/24 22:45:35 perry Exp $	*/

/* 
 * Mach Operating System
 * Copyright (c) 1990 Carnegie-Mellon University
 * All rights reserved.  The CMU software License Agreement specifies
 * the terms and conditions for use and redistribution.
 */

#define inl(y) \
({ unsigned long _tmp__; \
	__asm volatile("inl %1, %0" : "=a" (_tmp__) : "d" ((unsigned short)(y))); \
	_tmp__; })

#define inw(y) \
({ unsigned short _tmp__; \
	__asm volatile(".byte 0x66; inl %1, %0" : "=a" (_tmp__) : "d" ((unsigned short)(y))); \
	_tmp__; })

#define inb(y) \
({ unsigned char _tmp__; \
	__asm volatile("inb %1, %0" : "=a" (_tmp__) : "d" ((unsigned short)(y))); \
	_tmp__; })


#define outl(x, y) \
{ __asm volatile("outl %0, %1" : : "a" (y) , "d" ((unsigned short)(x))); }


#define outw(x, y) \
{__asm volatile(".byte 0x66; outl %0, %1" : : "a" ((unsigned short)(y)) , "d" ((unsigned short)(x))); }


#define outb(x, y) \
{ __asm volatile("outb %0, %1" : : "a" ((unsigned char)(y)) , "d" ((unsigned short)(x))); }