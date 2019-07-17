struct semid_ds {
	struct ipc_perm sem_perm;
	time_t sem_otime;
	time_t sem_ctime;
	unsigned short sem_nsems;
	char __sem_nsems_pad[sizeof(time_t)-sizeof(short)];
	time_t __unused3;
	time_t __unused4;
};
