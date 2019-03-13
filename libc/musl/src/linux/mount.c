#include <sys/mount.h>
#include "syscall.h"

int mount(const char *special, const char *dir, const char *fstype, unsigned long flags, const void *data)
{
	return syscall(SYS_mount, special, dir, fstype, flags, data);
}

int umount(const char *special)
{
	return syscall(SYS_umount2, special, 0);
}

int umount2(const char *special, int flags)
{
	return syscall(SYS_umount2, special, flags);
}
