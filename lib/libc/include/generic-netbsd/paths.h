/*	$NetBSD: paths.h,v 1.43 2017/01/16 19:15:28 christos Exp $	*/

/*
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)paths.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _PATHS_H_
#define	_PATHS_H_

/*
 * Default user search path.
 * Set by login(1), rshd(8), rexecd(8)
 * Used by execvp(3) absent PATH from the environ(7)
 */
#ifdef RESCUEDIR
#define	_PATH_DEFPATH	RESCUEDIR ":/usr/bin:/bin:/usr/pkg/bin:/usr/local/bin"
#else
#define	_PATH_DEFPATH	"/usr/bin:/bin:/usr/pkg/bin:/usr/local/bin"
#endif

/*
 * All standard utilities path.
 * Set by init(8) for system programs & scripts (e.g. /etc/rc)
 * Used by ttyaction(3), whereis(1)
 */
#define	_PATH_STDPATH \
	"/usr/bin:/bin:/usr/sbin:/sbin:/usr/pkg/bin:/usr/pkg/sbin:/usr/local/bin:/usr/local/sbin"

#define	_PATH_AUDIO	"/dev/audio"
#define	_PATH_AUDIO0	"/dev/audio0"
#define	_PATH_AUDIOCTL	"/dev/audioctl"
#define	_PATH_AUDIOCTL0	"/dev/audioctl0"
#define	_PATH_BPF	"/dev/bpf"
#define	_PATH_CLOCKCTL	"/dev/clockctl"
#define	_PATH_CONSOLE	"/dev/console"
#define	_PATH_CONSTTY	"/dev/constty"
#define _PATH_CPUCTL	"/dev/cpuctl"
#define	_PATH_CSMAPPER	"/usr/share/i18n/csmapper"
#define	_PATH_DEFTAPE	"/dev/nrst0"
#define	_PATH_DEVCDB	"/var/run/dev.cdb"
#define	_PATH_DEVDB	"/var/run/dev.db"
#define	_PATH_DEVNULL	"/dev/null"
#define	_PATH_DEVZERO	"/dev/zero"
#define	_PATH_DRUM	"/dev/drum"
#define	_PATH_ESDB	"/usr/share/i18n/esdb"
#define	_PATH_FTPUSERS	"/etc/ftpusers"
#define	_PATH_GETTYTAB	"/etc/gettytab"
#define	_PATH_I18NMODULE "/usr/lib/i18n"
#define	_PATH_ICONV	"/usr/share/i18n/iconv"
#define	_PATH_KMEM	"/dev/kmem"
#define	_PATH_KSYMS	"/dev/ksyms"
#define	_PATH_KVMDB	"/var/db/kvm.db"
#define	_PATH_LOCALE	"/usr/share/locale"
#define	_PATH_MAILDIR	"/var/mail"
#define	_PATH_MAN	"/usr/share/man"
#define	_PATH_MEM	"/dev/mem"
#define	_PATH_MIXER	"/dev/mixer"
#define	_PATH_MIXER0	"/dev/mixer0"
#define	_PATH_NOLOGIN	"/etc/nologin"
#define _PATH_POWER	"/dev/power"
#define	_PATH_PRINTCAP	"/etc/printcap"
#define	_PATH_PUD	"/dev/pud"
#define	_PATH_PUFFS	"/dev/puffs"
#define	_PATH_RANDOM	"/dev/random"
#define	_PATH_SENDMAIL	"/usr/sbin/sendmail"
#define	_PATH_SHELLS	"/etc/shells"
#define	_PATH_SKEYKEYS	"/etc/skeykeys"
#define	_PATH_SOUND	"/dev/sound"
#define	_PATH_SOUND0	"/dev/sound0"
#define	_PATH_SYSMON	"/dev/sysmon"
#define	_PATH_TTY	"/dev/tty"
#define	_PATH_UNIX	"/netbsd"
#define	_PATH_URANDOM	"/dev/urandom"
#define	_PATH_VIDEO	"/dev/video"
#define	_PATH_VIDEO0	"/dev/video0"
#define	_PATH_WATCHDOG	"/dev/watchdog"

/*
 * Provide trailing slash, since mostly used for building pathnames.
 * See the __CONCAT() macro from <sys/cdefs.h> for cpp examples.
 */
#define	_PATH_DEV	"/dev/"
#define	_PATH_DEV_PTS	"/dev/pts/"
#define	_PATH_EMUL_AOUT	"/emul/aout/"
#define	_PATH_TMP	"/tmp/"
#define	_PATH_VARDB	"/var/db/"
#define	_PATH_VARRUN	"/var/run/"
#define	_PATH_VARTMP	"/var/tmp/"

/*
 * Paths that may change if RESCUEDIR is defined.
 * Used by tools in /rescue.
 */
#ifdef RESCUEDIR
#define	_PATH_BSHELL	RESCUEDIR "/sh"
#define	_PATH_CSHELL	RESCUEDIR "/csh"
#define	_PATH_VI	RESCUEDIR "/vi"
#else
#define	_PATH_BSHELL	"/bin/sh"
#define	_PATH_CSHELL	"/bin/csh"
#define	_PATH_VI	"/usr/bin/vi"
#endif

#endif /* !_PATHS_H_ */