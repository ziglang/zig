/*-
 * Copyright 2020 M. Warner Losh <imp@FreeBSD.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef _SYS_DEVCTL_H_
#define _SYS_DEVCTL_H_

#ifdef _KERNEL
/**
 * devctl hooks.  Typically one should use the devctl_notify
 * hook to send the message.
 */

bool devctl_process_running(void);
void devctl_notify(const char *__system, const char *__subsystem,
    const char *__type, const char *__data);
struct sbuf;
void devctl_safe_quote_sb(struct sbuf *__sb, const char *__src);
typedef void send_event_f(const char *system, const char *subsystem,
    const char *type, const char *data);
void devctl_set_notify_hook(send_event_f *hook);
void devctl_unset_notify_hook(void);
#endif

#endif /* _SYS_DEVCTL_H_ */