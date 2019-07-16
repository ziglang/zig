struct semid_ds {
	struct ipc_perm sem_perm;
	int __unused1;
	time_t sem_otime;
	int  __unused2;
	time_t sem_ctime;
	unsigned short __sem_nsems_pad, sem_nsems;
	long __unused3;
	long __unused4;
};
