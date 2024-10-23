struct semid_ds {
	struct ipc_perm sem_perm;
	unsigned long __sem_otime_lo;
	unsigned long __sem_ctime_lo;
#if __BYTE_ORDER == __LITTLE_ENDIAN
	unsigned short sem_nsems;
	char __sem_nsems_pad[sizeof(long)-sizeof(short)];
#else
	char __sem_nsems_pad[sizeof(long)-sizeof(short)];
	unsigned short sem_nsems;
#endif
	unsigned long __sem_otime_hi;
	unsigned long __sem_ctime_hi;
	time_t sem_otime;
	time_t sem_ctime;
};
