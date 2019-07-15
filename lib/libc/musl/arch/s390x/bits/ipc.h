struct ipc_perm {
	key_t __ipc_perm_key;
	uid_t uid;
	gid_t gid;
	uid_t cuid;
	gid_t cgid;
	mode_t mode;
	unsigned short __pad1;
	unsigned short __ipc_perm_seq;
	unsigned long __pad2;
	unsigned long __pad3;
};

#define IPC_64 0x100
