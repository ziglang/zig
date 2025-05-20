/*	$NetBSD: rtc.h,v 1.2 2009/03/14 14:45:55 dsl Exp $	*/

/*
 * Copyright (c) 1994 Mark Brinicombe.
 * Copyright (c) 1994 Brini.
 * All rights reserved.
 *
 * This code is derived from software written for Brini by Mark Brinicombe
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
 *	This product includes software developed by Brini.
 * 4. The name of the company nor the name of the author may be used to
 *    endorse or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRINI ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL BRINI OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * RiscBSD kernel project
 *
 * rtc.h
 *
 * Header file for RTC / CMOS stuff
 *
 * Created      : 13/10/94
 * Updated	: 15/07/2000
 *
 * Based of kate/display/iiccontrol.c
 */

/*
 * IIC addresses for RTC chip
 * Two PCF8583 chips are supported on the IIC bus
 */

#define IIC_PCF8583_MASK 0xfc
#define IIC_PCF8583_ADDR 0xa0

#define RTC_Write (IIC_PCF8583_ADDR | IIC_WRITE)
#define RTC_Read  (IIC_PCF8583_ADDR | IIC_READ)

typedef struct {
	u_char rtc_micro;
	u_char rtc_centi;
	u_char rtc_sec;
	u_char rtc_min;
	u_char rtc_hour;
	u_char rtc_day;
	u_char rtc_mon;
	u_char rtc_year;
	u_char rtc_cen;
} rtc_t;

#define RTC_ADDR_CHECKSUM	0x3f
#define RTC_ADDR_BOOTOPTS	0x90
#define RTC_ADDR_REBOOTCNT	0x91
#define RTC_ADDR_YEAR     	0xc0
#define RTC_ADDR_CENT     	0xc1

#ifdef _KERNEL
int cmos_read(int);
int cmos_write(int, int);
#endif /* _KERNEL */

/* End of rtc.h */