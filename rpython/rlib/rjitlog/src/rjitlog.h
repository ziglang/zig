
RPY_EXTERN char * jitlog_init(int);
RPY_EXTERN void jitlog_try_init_using_env(void);
RPY_EXTERN int jitlog_enabled();
RPY_EXTERN void jitlog_write_marked(char*, int);
RPY_EXTERN void jitlog_teardown();
