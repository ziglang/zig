/* Versions of the 'struct stat' data structure used in compatibility xstat
   functions.  */
#define _STAT_VER_KERNEL	0
#define _STAT_VER_GLIBC2	1
#define _STAT_VER_GLIBC2_1	2
#define _STAT_VER_KERNEL64	3
#define _STAT_VER_GLIBC2_3_4	3
#define _STAT_VER_LINUX		3
#define _STAT_VER		_STAT_VER_LINUX

/* Versions of the 'xmknod' interface used in compatibility xmknod
   functions.  */
#define _MKNOD_VER_LINUX	0
#define _MKNOD_VER		_MKNOD_VER_LINUX
