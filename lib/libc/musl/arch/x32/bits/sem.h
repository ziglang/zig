struct semid_ds {
	struct ipc_perm sem_perm;
	time_t sem_otime;
	long long __unused1;
	time_t sem_ctime;
	long long __unused2;
	unsigned short sem_nsems;
	char __sem_nsems_pad[sizeof(long long)-sizeof(short)];
	long long __unused3;
	long long __unused4;
};
