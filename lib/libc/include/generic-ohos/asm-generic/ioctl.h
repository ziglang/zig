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
#ifndef _UAPI_ASM_GENERIC_IOCTL_H
#define _UAPI_ASM_GENERIC_IOCTL_H
#define _IOC_NRBITS 8
#define _IOC_TYPEBITS 8
#ifndef _IOC_SIZEBITS
#define _IOC_SIZEBITS 14
#endif
#ifndef _IOC_DIRBITS
#define _IOC_DIRBITS 2
#endif
#define _IOC_NRMASK ((1 << _IOC_NRBITS) - 1)
#define _IOC_TYPEMASK ((1 << _IOC_TYPEBITS) - 1)
#define _IOC_SIZEMASK ((1 << _IOC_SIZEBITS) - 1)
#define _IOC_DIRMASK ((1 << _IOC_DIRBITS) - 1)
#define _IOC_NRSHIFT 0
#define _IOC_TYPESHIFT (_IOC_NRSHIFT + _IOC_NRBITS)
#define _IOC_SIZESHIFT (_IOC_TYPESHIFT + _IOC_TYPEBITS)
#define _IOC_DIRSHIFT (_IOC_SIZESHIFT + _IOC_SIZEBITS)
#ifndef _IOC_NONE
#define _IOC_NONE 0U
#endif
#ifndef _IOC_WRITE
#define _IOC_WRITE 1U
#endif
#ifndef _IOC_READ
#define _IOC_READ 2U
#endif
#define _IOC(dir,type,nr,size) (((dir) << _IOC_DIRSHIFT) | ((type) << _IOC_TYPESHIFT) | ((nr) << _IOC_NRSHIFT) | ((size) << _IOC_SIZESHIFT))
#define _IOC_TYPECHECK(t) (sizeof(t))
#define _IO(type,nr) _IOC(_IOC_NONE, (type), (nr), 0)
#define _IOR(type,nr,size) _IOC(_IOC_READ, (type), (nr), (_IOC_TYPECHECK(size)))
#define _IOW(type,nr,size) _IOC(_IOC_WRITE, (type), (nr), (_IOC_TYPECHECK(size)))
#define _IOWR(type,nr,size) _IOC(_IOC_READ | _IOC_WRITE, (type), (nr), (_IOC_TYPECHECK(size)))
#define _IOR_BAD(type,nr,size) _IOC(_IOC_READ, (type), (nr), sizeof(size))
#define _IOW_BAD(type,nr,size) _IOC(_IOC_WRITE, (type), (nr), sizeof(size))
#define _IOWR_BAD(type,nr,size) _IOC(_IOC_READ | _IOC_WRITE, (type), (nr), sizeof(size))
#define _IOC_DIR(nr) (((nr) >> _IOC_DIRSHIFT) & _IOC_DIRMASK)
#define _IOC_TYPE(nr) (((nr) >> _IOC_TYPESHIFT) & _IOC_TYPEMASK)
#define _IOC_NR(nr) (((nr) >> _IOC_NRSHIFT) & _IOC_NRMASK)
#define _IOC_SIZE(nr) (((nr) >> _IOC_SIZESHIFT) & _IOC_SIZEMASK)
#define IOC_IN (_IOC_WRITE << _IOC_DIRSHIFT)
#define IOC_OUT (_IOC_READ << _IOC_DIRSHIFT)
#define IOC_INOUT ((_IOC_WRITE | _IOC_READ) << _IOC_DIRSHIFT)
#define IOCSIZE_MASK (_IOC_SIZEMASK << _IOC_SIZESHIFT)
#define IOCSIZE_SHIFT (_IOC_SIZESHIFT)
#endif