#ifndef NSCD_H
#define NSCD_H

#include <stdint.h>

#define NSCDVERSION 2
#define GETPWBYNAME 0
#define GETPWBYUID 1
#define GETGRBYNAME 2
#define GETGRBYGID 3
#define GETINITGR 15

#define REQVERSION 0
#define REQTYPE 1
#define REQKEYLEN 2
#define REQ_LEN 3

#define PWVERSION 0
#define PWFOUND 1
#define PWNAMELEN 2
#define PWPASSWDLEN 3
#define PWUID 4
#define PWGID 5
#define PWGECOSLEN 6
#define PWDIRLEN 7
#define PWSHELLLEN 8
#define PW_LEN 9

#define GRVERSION 0
#define GRFOUND 1
#define GRNAMELEN 2
#define GRPASSWDLEN 3
#define GRGID 4
#define GRMEMCNT 5
#define GR_LEN 6

#define INITGRVERSION 0
#define INITGRFOUND 1
#define INITGRNGRPS 2
#define INITGR_LEN 3

hidden FILE *__nscd_query(int32_t req, const char *key, int32_t *buf, size_t len, int *swap);

#endif
