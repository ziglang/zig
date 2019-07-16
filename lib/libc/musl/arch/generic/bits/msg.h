struct msqid_ds {
	struct ipc_perm msg_perm;
	time_t msg_stime;
	int __unused1;
	time_t msg_rtime;
	int __unused2;
	time_t msg_ctime;
	int __unused3;
	unsigned long msg_cbytes;
	msgqnum_t msg_qnum;
	msglen_t msg_qbytes;
	pid_t msg_lspid;
	pid_t msg_lrpid;
	unsigned long __unused[2];
};
