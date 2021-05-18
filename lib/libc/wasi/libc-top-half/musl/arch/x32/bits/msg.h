struct msqid_ds {
	struct ipc_perm msg_perm;
	time_t msg_stime;
	time_t msg_rtime;
	time_t msg_ctime;
	unsigned long msg_cbytes;
	long __unused1;
	msgqnum_t msg_qnum;
	long __unused2;
	msglen_t msg_qbytes;
	long __unused3;
	pid_t msg_lspid;
	pid_t msg_lrpid;
	unsigned long long __unused[2];
};
