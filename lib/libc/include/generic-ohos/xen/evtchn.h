/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef __LINUX_PUBLIC_EVTCHN_H__
#define __LINUX_PUBLIC_EVTCHN_H__
#define IOCTL_EVTCHN_BIND_VIRQ _IOC(_IOC_NONE, 'E', 0, sizeof(struct ioctl_evtchn_bind_virq))
struct ioctl_evtchn_bind_virq {
  unsigned int virq;
};
#define IOCTL_EVTCHN_BIND_INTERDOMAIN _IOC(_IOC_NONE, 'E', 1, sizeof(struct ioctl_evtchn_bind_interdomain))
struct ioctl_evtchn_bind_interdomain {
  unsigned int remote_domain, remote_port;
};
#define IOCTL_EVTCHN_BIND_UNBOUND_PORT _IOC(_IOC_NONE, 'E', 2, sizeof(struct ioctl_evtchn_bind_unbound_port))
struct ioctl_evtchn_bind_unbound_port {
  unsigned int remote_domain;
};
#define IOCTL_EVTCHN_UNBIND _IOC(_IOC_NONE, 'E', 3, sizeof(struct ioctl_evtchn_unbind))
struct ioctl_evtchn_unbind {
  unsigned int port;
};
#define IOCTL_EVTCHN_NOTIFY _IOC(_IOC_NONE, 'E', 4, sizeof(struct ioctl_evtchn_notify))
struct ioctl_evtchn_notify {
  unsigned int port;
};
#define IOCTL_EVTCHN_RESET _IOC(_IOC_NONE, 'E', 5, 0)
#define IOCTL_EVTCHN_RESTRICT_DOMID _IOC(_IOC_NONE, 'E', 6, sizeof(struct ioctl_evtchn_restrict_domid))
struct ioctl_evtchn_restrict_domid {
  domid_t domid;
};
#endif