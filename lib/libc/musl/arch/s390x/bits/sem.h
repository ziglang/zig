struct semid_ds {
	struct ipc_perm sem_perm;
	time_t sem_otime;
	time_t sem_ctime;
	unsigned short __pad[3], sem_nsems;
	unsigned long __unused[2];
};
