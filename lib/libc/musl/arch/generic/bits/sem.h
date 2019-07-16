struct semid_ds {
	struct ipc_perm sem_perm;
	time_t sem_otime;
	time_t __unused1;
	time_t sem_ctime;
	time_t __unused2;
#if __BYTE_ORDER == __LITTLE_ENDIAN
	unsigned short sem_nsems;
	char __sem_nsems_pad[sizeof(time_t)-sizeof(short)];
#else
	char __sem_nsems_pad[sizeof(time_t)-sizeof(short)];
	unsigned short sem_nsems;
#endif
	time_t __unused3;
	time_t __unused4;
};
