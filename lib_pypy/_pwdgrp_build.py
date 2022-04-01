from cffi import FFI

ffi = FFI()

ffi.set_source("_pwdgrp_cffi", """
#include <sys/types.h>
#include <pwd.h>
#include <grp.h>
""")


ffi.cdef("""

typedef int... uid_t;
typedef int... gid_t;

struct passwd {
    char *pw_name;
    char *pw_passwd;
    uid_t pw_uid;
    gid_t pw_gid;
    char *pw_gecos;
    char *pw_dir;
    char *pw_shell;
    ...;
};

struct group {
    char *gr_name;       /* group name */
    char *gr_passwd;     /* group password */
    gid_t gr_gid;        /* group ID */
    char **gr_mem;        /* group members */
};

struct passwd *getpwuid(uid_t uid);
struct passwd *getpwnam(const char *name);

struct passwd *getpwent(void);
void setpwent(void);
void endpwent(void);

struct group *getgrgid(gid_t gid);
struct group *getgrnam(const char *name);

struct group *getgrent(void);
void setgrent(void);
void endgrent(void);

""")


if __name__ == "__main__":
    ffi.compile()
