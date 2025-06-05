/*
 * System call numbers.
 *
 * DO NOT EDIT-- this file is automatically @generated.
 */

#define	SYS_syscall	0
#define	SYS_exit	1
#define	SYS_fork	2
#define	SYS_read	3
#define	SYS_write	4
#define	SYS_open	5
#define	SYS_close	6
#define	SYS_wait4	7
				/* 8 is old creat */
#define	SYS_link	9
#define	SYS_unlink	10
				/* 11 is obsolete execv */
#define	SYS_chdir	12
#define	SYS_fchdir	13
#define	SYS_freebsd11_mknod	14
#define	SYS_chmod	15
#define	SYS_chown	16
#define	SYS_break	17
				/* 18 is freebsd4 getfsstat */
				/* 19 is old lseek */
#define	SYS_getpid	20
#define	SYS_mount	21
#define	SYS_unmount	22
#define	SYS_setuid	23
#define	SYS_getuid	24
#define	SYS_geteuid	25
#define	SYS_ptrace	26
#define	SYS_recvmsg	27
#define	SYS_sendmsg	28
#define	SYS_recvfrom	29
#define	SYS_accept	30
#define	SYS_getpeername	31
#define	SYS_getsockname	32
#define	SYS_access	33
#define	SYS_chflags	34
#define	SYS_fchflags	35
#define	SYS_sync	36
#define	SYS_kill	37
				/* 38 is old stat */
#define	SYS_getppid	39
				/* 40 is old lstat */
#define	SYS_dup	41
#define	SYS_freebsd10_pipe	42
#define	SYS_getegid	43
#define	SYS_profil	44
#define	SYS_ktrace	45
				/* 46 is old sigaction */
#define	SYS_getgid	47
				/* 48 is old sigprocmask */
#define	SYS_getlogin	49
#define	SYS_setlogin	50
#define	SYS_acct	51
				/* 52 is old sigpending */
#define	SYS_sigaltstack	53
#define	SYS_ioctl	54
#define	SYS_reboot	55
#define	SYS_revoke	56
#define	SYS_symlink	57
#define	SYS_readlink	58
#define	SYS_execve	59
#define	SYS_umask	60
#define	SYS_chroot	61
				/* 62 is old fstat */
				/* 63 is old getkerninfo */
				/* 64 is old getpagesize */
#define	SYS_msync	65
#define	SYS_vfork	66
				/* 67 is obsolete vread */
				/* 68 is obsolete vwrite */
#define	SYS_sbrk	69
#define	SYS_sstk	70
				/* 71 is old mmap */
#define	SYS_freebsd11_vadvise	72
#define	SYS_munmap	73
#define	SYS_mprotect	74
#define	SYS_madvise	75
				/* 76 is obsolete vhangup */
				/* 77 is obsolete vlimit */
#define	SYS_mincore	78
#define	SYS_getgroups	79
#define	SYS_setgroups	80
#define	SYS_getpgrp	81
#define	SYS_setpgid	82
#define	SYS_setitimer	83
				/* 84 is old wait */
#define	SYS_swapon	85
#define	SYS_getitimer	86
				/* 87 is old gethostname */
				/* 88 is old sethostname */
#define	SYS_getdtablesize	89
#define	SYS_dup2	90
#define	SYS_fcntl	92
#define	SYS_select	93
#define	SYS_fsync	95
#define	SYS_setpriority	96
#define	SYS_socket	97
#define	SYS_connect	98
				/* 99 is old accept */
#define	SYS_getpriority	100
				/* 101 is old send */
				/* 102 is old recv */
				/* 103 is old sigreturn */
#define	SYS_bind	104
#define	SYS_setsockopt	105
#define	SYS_listen	106
				/* 107 is obsolete vtimes */
				/* 108 is old sigvec */
				/* 109 is old sigblock */
				/* 110 is old sigsetmask */
				/* 111 is old sigsuspend */
				/* 112 is old sigstack */
				/* 113 is old recvmsg */
				/* 114 is old sendmsg */
				/* 115 is obsolete vtrace */
#define	SYS_gettimeofday	116
#define	SYS_getrusage	117
#define	SYS_getsockopt	118
#define	SYS_readv	120
#define	SYS_writev	121
#define	SYS_settimeofday	122
#define	SYS_fchown	123
#define	SYS_fchmod	124
				/* 125 is old recvfrom */
#define	SYS_setreuid	126
#define	SYS_setregid	127
#define	SYS_rename	128
				/* 129 is old truncate */
				/* 130 is old ftruncate */
#define	SYS_flock	131
#define	SYS_mkfifo	132
#define	SYS_sendto	133
#define	SYS_shutdown	134
#define	SYS_socketpair	135
#define	SYS_mkdir	136
#define	SYS_rmdir	137
#define	SYS_utimes	138
				/* 139 is obsolete sigreturn */
#define	SYS_adjtime	140
				/* 141 is old getpeername */
				/* 142 is old gethostid */
				/* 143 is old sethostid */
				/* 144 is old getrlimit */
				/* 145 is old setrlimit */
				/* 146 is old killpg */
#define	SYS_setsid	147
#define	SYS_quotactl	148
				/* 149 is old quota */
				/* 150 is old getsockname */
#define	SYS_nlm_syscall	154
#define	SYS_nfssvc	155
				/* 156 is old getdirentries */
				/* 157 is freebsd4 statfs */
				/* 158 is freebsd4 fstatfs */
#define	SYS_lgetfh	160
#define	SYS_getfh	161
				/* 162 is freebsd4 getdomainname */
				/* 163 is freebsd4 setdomainname */
				/* 164 is freebsd4 uname */
#define	SYS_sysarch	165
#define	SYS_rtprio	166
#define	SYS_semsys	169
#define	SYS_msgsys	170
#define	SYS_shmsys	171
				/* 173 is freebsd6 pread */
				/* 174 is freebsd6 pwrite */
#define	SYS_setfib	175
#define	SYS_ntp_adjtime	176
#define	SYS_setgid	181
#define	SYS_setegid	182
#define	SYS_seteuid	183
				/* 184 is obsolete lfs_bmapv */
				/* 185 is obsolete lfs_markv */
				/* 186 is obsolete lfs_segclean */
				/* 187 is obsolete lfs_segwait */
#define	SYS_freebsd11_stat	188
#define	SYS_freebsd11_fstat	189
#define	SYS_freebsd11_lstat	190
#define	SYS_pathconf	191
#define	SYS_fpathconf	192
#define	SYS_getrlimit	194
#define	SYS_setrlimit	195
#define	SYS_freebsd11_getdirentries	196
				/* 197 is freebsd6 mmap */
#define	SYS___syscall	198
				/* 199 is freebsd6 lseek */
				/* 200 is freebsd6 truncate */
				/* 201 is freebsd6 ftruncate */
#define	SYS___sysctl	202
#define	SYS_mlock	203
#define	SYS_munlock	204
#define	SYS_undelete	205
#define	SYS_futimes	206
#define	SYS_getpgid	207
#define	SYS_poll	209
#define	SYS_freebsd7___semctl	220
#define	SYS_semget	221
#define	SYS_semop	222
				/* 223 is obsolete semconfig */
#define	SYS_freebsd7_msgctl	224
#define	SYS_msgget	225
#define	SYS_msgsnd	226
#define	SYS_msgrcv	227
#define	SYS_shmat	228
#define	SYS_freebsd7_shmctl	229
#define	SYS_shmdt	230
#define	SYS_shmget	231
#define	SYS_clock_gettime	232
#define	SYS_clock_settime	233
#define	SYS_clock_getres	234
#define	SYS_ktimer_create	235
#define	SYS_ktimer_delete	236
#define	SYS_ktimer_settime	237
#define	SYS_ktimer_gettime	238
#define	SYS_ktimer_getoverrun	239
#define	SYS_nanosleep	240
#define	SYS_ffclock_getcounter	241
#define	SYS_ffclock_setestimate	242
#define	SYS_ffclock_getestimate	243
#define	SYS_clock_nanosleep	244
#define	SYS_clock_getcpuclockid2	247
#define	SYS_ntp_gettime	248
#define	SYS_minherit	250
#define	SYS_rfork	251
				/* 252 is obsolete openbsd_poll */
#define	SYS_issetugid	253
#define	SYS_lchown	254
#define	SYS_aio_read	255
#define	SYS_aio_write	256
#define	SYS_lio_listio	257
#define	SYS_freebsd11_getdents	272
#define	SYS_lchmod	274
				/* 275 is obsolete netbsd_lchown */
#define	SYS_lutimes	276
				/* 277 is obsolete netbsd_msync */
#define	SYS_freebsd11_nstat	278
#define	SYS_freebsd11_nfstat	279
#define	SYS_freebsd11_nlstat	280
#define	SYS_preadv	289
#define	SYS_pwritev	290
				/* 297 is freebsd4 fhstatfs */
#define	SYS_fhopen	298
#define	SYS_freebsd11_fhstat	299
#define	SYS_modnext	300
#define	SYS_modstat	301
#define	SYS_modfnext	302
#define	SYS_modfind	303
#define	SYS_kldload	304
#define	SYS_kldunload	305
#define	SYS_kldfind	306
#define	SYS_kldnext	307
#define	SYS_kldstat	308
#define	SYS_kldfirstmod	309
#define	SYS_getsid	310
#define	SYS_setresuid	311
#define	SYS_setresgid	312
				/* 313 is obsolete signanosleep */
#define	SYS_aio_return	314
#define	SYS_aio_suspend	315
#define	SYS_aio_cancel	316
#define	SYS_aio_error	317
				/* 318 is freebsd6 aio_read */
				/* 319 is freebsd6 aio_write */
				/* 320 is freebsd6 lio_listio */
#define	SYS_yield	321
				/* 322 is obsolete thr_sleep */
				/* 323 is obsolete thr_wakeup */
#define	SYS_mlockall	324
#define	SYS_munlockall	325
#define	SYS___getcwd	326
#define	SYS_sched_setparam	327
#define	SYS_sched_getparam	328
#define	SYS_sched_setscheduler	329
#define	SYS_sched_getscheduler	330
#define	SYS_sched_yield	331
#define	SYS_sched_get_priority_max	332
#define	SYS_sched_get_priority_min	333
#define	SYS_sched_rr_get_interval	334
#define	SYS_utrace	335
				/* 336 is freebsd4 sendfile */
#define	SYS_kldsym	337
#define	SYS_jail	338
#define	SYS_nnpfs_syscall	339
#define	SYS_sigprocmask	340
#define	SYS_sigsuspend	341
				/* 342 is freebsd4 sigaction */
#define	SYS_sigpending	343
				/* 344 is freebsd4 sigreturn */
#define	SYS_sigtimedwait	345
#define	SYS_sigwaitinfo	346
#define	SYS___acl_get_file	347
#define	SYS___acl_set_file	348
#define	SYS___acl_get_fd	349
#define	SYS___acl_set_fd	350
#define	SYS___acl_delete_file	351
#define	SYS___acl_delete_fd	352
#define	SYS___acl_aclcheck_file	353
#define	SYS___acl_aclcheck_fd	354
#define	SYS_extattrctl	355
#define	SYS_extattr_set_file	356
#define	SYS_extattr_get_file	357
#define	SYS_extattr_delete_file	358
#define	SYS_aio_waitcomplete	359
#define	SYS_getresuid	360
#define	SYS_getresgid	361
#define	SYS_kqueue	362
#define	SYS_freebsd11_kevent	363
				/* 364 is obsolete __cap_get_proc */
				/* 365 is obsolete __cap_set_proc */
				/* 366 is obsolete __cap_get_fd */
				/* 367 is obsolete __cap_get_file */
				/* 368 is obsolete __cap_set_fd */
				/* 369 is obsolete __cap_set_file */
#define	SYS_extattr_set_fd	371
#define	SYS_extattr_get_fd	372
#define	SYS_extattr_delete_fd	373
#define	SYS___setugid	374
				/* 375 is obsolete nfsclnt */
#define	SYS_eaccess	376
#define	SYS_afs3_syscall	377
#define	SYS_nmount	378
				/* 379 is obsolete kse_exit */
				/* 380 is obsolete kse_wakeup */
				/* 381 is obsolete kse_create */
				/* 382 is obsolete kse_thr_interrupt */
				/* 383 is obsolete kse_release */
#define	SYS___mac_get_proc	384
#define	SYS___mac_set_proc	385
#define	SYS___mac_get_fd	386
#define	SYS___mac_get_file	387
#define	SYS___mac_set_fd	388
#define	SYS___mac_set_file	389
#define	SYS_kenv	390
#define	SYS_lchflags	391
#define	SYS_uuidgen	392
#define	SYS_sendfile	393
#define	SYS_mac_syscall	394
#define	SYS_freebsd11_getfsstat	395
#define	SYS_freebsd11_statfs	396
#define	SYS_freebsd11_fstatfs	397
#define	SYS_freebsd11_fhstatfs	398
#define	SYS_ksem_close	400
#define	SYS_ksem_post	401
#define	SYS_ksem_wait	402
#define	SYS_ksem_trywait	403
#define	SYS_ksem_init	404
#define	SYS_ksem_open	405
#define	SYS_ksem_unlink	406
#define	SYS_ksem_getvalue	407
#define	SYS_ksem_destroy	408
#define	SYS___mac_get_pid	409
#define	SYS___mac_get_link	410
#define	SYS___mac_set_link	411
#define	SYS_extattr_set_link	412
#define	SYS_extattr_get_link	413
#define	SYS_extattr_delete_link	414
#define	SYS___mac_execve	415
#define	SYS_sigaction	416
#define	SYS_sigreturn	417
#define	SYS_getcontext	421
#define	SYS_setcontext	422
#define	SYS_swapcontext	423
#define	SYS_freebsd13_swapoff	424
#define	SYS___acl_get_link	425
#define	SYS___acl_set_link	426
#define	SYS___acl_delete_link	427
#define	SYS___acl_aclcheck_link	428
#define	SYS_sigwait	429
#define	SYS_thr_create	430
#define	SYS_thr_exit	431
#define	SYS_thr_self	432
#define	SYS_thr_kill	433
#define	SYS_freebsd10__umtx_lock	434
#define	SYS_freebsd10__umtx_unlock	435
#define	SYS_jail_attach	436
#define	SYS_extattr_list_fd	437
#define	SYS_extattr_list_file	438
#define	SYS_extattr_list_link	439
				/* 440 is obsolete kse_switchin */
#define	SYS_ksem_timedwait	441
#define	SYS_thr_suspend	442
#define	SYS_thr_wake	443
#define	SYS_kldunloadf	444
#define	SYS_audit	445
#define	SYS_auditon	446
#define	SYS_getauid	447
#define	SYS_setauid	448
#define	SYS_getaudit	449
#define	SYS_setaudit	450
#define	SYS_getaudit_addr	451
#define	SYS_setaudit_addr	452
#define	SYS_auditctl	453
#define	SYS__umtx_op	454
#define	SYS_thr_new	455
#define	SYS_sigqueue	456
#define	SYS_kmq_open	457
#define	SYS_kmq_setattr	458
#define	SYS_kmq_timedreceive	459
#define	SYS_kmq_timedsend	460
#define	SYS_kmq_notify	461
#define	SYS_kmq_unlink	462
#define	SYS_abort2	463
#define	SYS_thr_set_name	464
#define	SYS_aio_fsync	465
#define	SYS_rtprio_thread	466
#define	SYS_sctp_peeloff	471
#define	SYS_sctp_generic_sendmsg	472
#define	SYS_sctp_generic_sendmsg_iov	473
#define	SYS_sctp_generic_recvmsg	474
#define	SYS_pread	475
#define	SYS_pwrite	476
#define	SYS_mmap	477
#define	SYS_lseek	478
#define	SYS_truncate	479
#define	SYS_ftruncate	480
#define	SYS_thr_kill2	481
#define	SYS_freebsd12_shm_open	482
#define	SYS_shm_unlink	483
#define	SYS_cpuset	484
#define	SYS_cpuset_setid	485
#define	SYS_cpuset_getid	486
#define	SYS_cpuset_getaffinity	487
#define	SYS_cpuset_setaffinity	488
#define	SYS_faccessat	489
#define	SYS_fchmodat	490
#define	SYS_fchownat	491
#define	SYS_fexecve	492
#define	SYS_freebsd11_fstatat	493
#define	SYS_futimesat	494
#define	SYS_linkat	495
#define	SYS_mkdirat	496
#define	SYS_mkfifoat	497
#define	SYS_freebsd11_mknodat	498
#define	SYS_openat	499
#define	SYS_readlinkat	500
#define	SYS_renameat	501
#define	SYS_symlinkat	502
#define	SYS_unlinkat	503
#define	SYS_posix_openpt	504
#define	SYS_gssd_syscall	505
#define	SYS_jail_get	506
#define	SYS_jail_set	507
#define	SYS_jail_remove	508
#define	SYS_freebsd12_closefrom	509
#define	SYS___semctl	510
#define	SYS_msgctl	511
#define	SYS_shmctl	512
#define	SYS_lpathconf	513
				/* 514 is obsolete cap_new */
#define	SYS___cap_rights_get	515
#define	SYS_cap_enter	516
#define	SYS_cap_getmode	517
#define	SYS_pdfork	518
#define	SYS_pdkill	519
#define	SYS_pdgetpid	520
#define	SYS_pselect	522
#define	SYS_getloginclass	523
#define	SYS_setloginclass	524
#define	SYS_rctl_get_racct	525
#define	SYS_rctl_get_rules	526
#define	SYS_rctl_get_limits	527
#define	SYS_rctl_add_rule	528
#define	SYS_rctl_remove_rule	529
#define	SYS_posix_fallocate	530
#define	SYS_posix_fadvise	531
#define	SYS_wait6	532
#define	SYS_cap_rights_limit	533
#define	SYS_cap_ioctls_limit	534
#define	SYS_cap_ioctls_get	535
#define	SYS_cap_fcntls_limit	536
#define	SYS_cap_fcntls_get	537
#define	SYS_bindat	538
#define	SYS_connectat	539
#define	SYS_chflagsat	540
#define	SYS_accept4	541
#define	SYS_pipe2	542
#define	SYS_aio_mlock	543
#define	SYS_procctl	544
#define	SYS_ppoll	545
#define	SYS_futimens	546
#define	SYS_utimensat	547
				/* 548 is obsolete numa_getaffinity */
				/* 549 is obsolete numa_setaffinity */
#define	SYS_fdatasync	550
#define	SYS_fstat	551
#define	SYS_fstatat	552
#define	SYS_fhstat	553
#define	SYS_getdirentries	554
#define	SYS_statfs	555
#define	SYS_fstatfs	556
#define	SYS_getfsstat	557
#define	SYS_fhstatfs	558
#define	SYS_mknodat	559
#define	SYS_kevent	560
#define	SYS_cpuset_getdomain	561
#define	SYS_cpuset_setdomain	562
#define	SYS_getrandom	563
#define	SYS_getfhat	564
#define	SYS_fhlink	565
#define	SYS_fhlinkat	566
#define	SYS_fhreadlink	567
#define	SYS_funlinkat	568
#define	SYS_copy_file_range	569
#define	SYS___sysctlbyname	570
#define	SYS_shm_open2	571
#define	SYS_shm_rename	572
#define	SYS_sigfastblock	573
#define	SYS___realpathat	574
#define	SYS_close_range	575
#define	SYS_rpctls_syscall	576
#define	SYS___specialfd	577
#define	SYS_aio_writev	578
#define	SYS_aio_readv	579
#define	SYS_fspacectl	580
#define	SYS_sched_getcpu	581
#define	SYS_swapoff	582
#define	SYS_kqueuex	583
#define	SYS_membarrier	584
#define	SYS_timerfd_create	585
#define	SYS_timerfd_gettime	586
#define	SYS_timerfd_settime	587
#define	SYS_kcmp	588
#define	SYS_getrlimitusage	589
#define	SYS_MAXSYSCALL	590