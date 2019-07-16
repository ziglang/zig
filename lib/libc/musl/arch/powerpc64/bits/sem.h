#include <endian.h>

struct semid_ds {
	struct ipc_perm sem_perm;
	time_t sem_otime;
	time_t sem_ctime;
#if __BYTE_ORDER == __BIG_ENDIAN
	unsigned short __pad[3], sem_nsems;
#else
	unsigned short sem_nsems, __pad[3];
#endif
	unsigned long __unused[2];
};
