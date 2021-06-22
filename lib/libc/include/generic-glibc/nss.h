/* Copyright (C) 1996-2021 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

/* Define interface to NSS.  This is meant for the interface functions
   and for implementors of new services.  */

#ifndef _NSS_H
#define _NSS_H  1

#include <features.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>


__BEGIN_DECLS

/* Possible results of lookup using a nss_* function.  */
enum nss_status
{
  NSS_STATUS_TRYAGAIN = -2,
  NSS_STATUS_UNAVAIL,
  NSS_STATUS_NOTFOUND,
  NSS_STATUS_SUCCESS,
  NSS_STATUS_RETURN
};


/* Data structure used for the 'gethostbyname4_r' function.  */
struct gaih_addrtuple
  {
    struct gaih_addrtuple *next;
    char *name;
    int family;
    uint32_t addr[4];
    uint32_t scopeid;
  };


/* Overwrite service selection for database DBNAME using specification
   in STRING.
   This function should only be used by system programs which have to
   work around non-existing services (e.e., while booting).
   Attention: Using this function repeatedly will slowly eat up the
   whole memory since previous selection data cannot be freed.  */
extern int __nss_configure_lookup (const char *__dbname,
                                   const char *__string) __THROW;

/* NSS-related types.  */
struct __netgrent;
struct aliasent;
struct ether_addr;
struct etherent;
struct group;
struct hostent;
struct netent;
struct passwd;
struct protoent;
struct rpcent;
struct servent;
struct sgrp;
struct spwd;
struct traced_file;

/* Types of functions exported from NSS service modules.  */
typedef enum nss_status nss_endaliasent (void);
typedef enum nss_status nss_endetherent (void);
typedef enum nss_status nss_endgrent (void);
typedef enum nss_status nss_endhostent (void);
typedef enum nss_status nss_endnetent (void);
typedef enum nss_status nss_endnetgrent (struct __netgrent *);
typedef enum nss_status nss_endprotoent (void);
typedef enum nss_status nss_endpwent (void);
typedef enum nss_status nss_endrpcent (void);
typedef enum nss_status nss_endservent (void);
typedef enum nss_status nss_endsgent (void);
typedef enum nss_status nss_endspent (void);
typedef enum nss_status nss_getaliasbyname_r (const char *, struct aliasent *,
                                              char *, size_t, int *);
typedef enum nss_status nss_getaliasent_r (struct aliasent *,
                                           char *, size_t, int *);
typedef enum nss_status nss_getcanonname_r (const char *, char *, size_t,
                                            char **, int *, int *);
typedef enum nss_status nss_getetherent_r (struct etherent *,
                                           char *, size_t, int *);
typedef enum nss_status nss_getgrent_r (struct group *, char *, size_t, int *);
typedef enum nss_status nss_getgrgid_r (__gid_t, struct group *,
                                        char *, size_t, int *);
typedef enum nss_status nss_getgrnam_r (const char *, struct group *,
                                        char *, size_t, int *);
typedef enum nss_status nss_gethostbyaddr2_r (const void *, __socklen_t, int,
                                              struct hostent *, char *, size_t,
                                              int *, int *, int32_t *);
typedef enum nss_status nss_gethostbyaddr_r (const void *, __socklen_t, int,
                                             struct hostent *, char *, size_t,
                                             int *, int *);
typedef enum nss_status nss_gethostbyname2_r (const char *, int,
                                              struct hostent *, char *, size_t,
                                              int *, int *);
typedef enum nss_status nss_gethostbyname3_r (const char *, int,
                                              struct hostent *, char *, size_t,
                                              int *, int *, int32_t *,
                                              char **);
typedef enum nss_status nss_gethostbyname4_r (const char *,
                                              struct gaih_addrtuple **,
                                              char *, size_t,
                                              int *, int *, int32_t *);
typedef enum nss_status nss_gethostbyname_r (const char *, struct hostent *,
                                             char *, size_t, int *, int *);
typedef enum nss_status nss_gethostent_r (struct hostent *, char *, size_t,
                                          int *, int *);
typedef enum nss_status nss_gethostton_r (const char *, struct etherent *,
                                          char *, size_t, int *);
typedef enum nss_status nss_getnetbyaddr_r (uint32_t, int, struct netent *,
                                            char *, size_t, int *, int *);
typedef enum nss_status nss_getnetbyname_r (const char *, struct netent *,
                                            char *, size_t, int *, int *);
typedef enum nss_status nss_getnetent_r (struct netent *,
                                         char *, size_t, int *, int *);
typedef enum nss_status nss_getnetgrent_r (struct __netgrent *,
                                           char *, size_t, int *);
typedef enum nss_status nss_getntohost_r (const struct ether_addr *,
                                          struct etherent *, char *, size_t,
                                          int *);
typedef enum nss_status nss_getprotobyname_r (const char *, struct protoent *,
                                              char *, size_t, int *);
typedef enum nss_status nss_getprotobynumber_r (int, struct protoent *,
                                                char *, size_t, int *);
typedef enum nss_status nss_getprotoent_r (struct protoent *,
                                           char *, size_t, int *);
typedef enum nss_status nss_getpublickey (const char *, char *, int *);
typedef enum nss_status nss_getpwent_r (struct passwd *,
                                        char *, size_t, int *);
typedef enum nss_status nss_getpwnam_r (const char *, struct passwd *,
                                        char *, size_t, int *);
typedef enum nss_status nss_getpwuid_r (__uid_t, struct passwd *,
                                        char *, size_t, int *);
typedef enum nss_status nss_getrpcbyname_r (const char *, struct rpcent *,
                                            char *, size_t, int *);
typedef enum nss_status nss_getrpcbynumber_r (int, struct rpcent *,
                                              char *, size_t, int *);
typedef enum nss_status nss_getrpcent_r (struct rpcent *,
                                         char *, size_t, int *);
typedef enum nss_status nss_getsecretkey (const char *, char *, char *, int *);
typedef enum nss_status nss_getservbyname_r (const char *, const char *,
                                             struct servent *, char *, size_t,
                                             int *);
typedef enum nss_status nss_getservbyport_r (int, const char *,
                                             struct servent *, char *, size_t,
                                             int *);
typedef enum nss_status nss_getservent_r (struct servent *, char *, size_t,
                                          int *);
typedef enum nss_status nss_getsgent_r (struct sgrp *, char *, size_t, int *);
typedef enum nss_status nss_getsgnam_r (const char *, struct sgrp *,
                                        char *, size_t, int *);
typedef enum nss_status nss_getspent_r (struct spwd *, char *, size_t, int *);
typedef enum nss_status nss_getspnam_r (const char *, struct spwd *,
                                        char *, size_t, int *);
typedef void nss_init (void (*) (size_t, struct traced_file *));
typedef enum nss_status nss_initgroups_dyn (const char *, __gid_t, long int *,
                                            long int *, __gid_t **, long int,
                                            int *);
typedef enum nss_status nss_netname2user (char [], __uid_t *, __gid_t *,
                                          int *, __gid_t *, int *);
typedef enum nss_status nss_setaliasent (void);
typedef enum nss_status nss_setetherent (int);
typedef enum nss_status nss_setgrent (int);
typedef enum nss_status nss_sethostent (int);
typedef enum nss_status nss_setnetent (int);
typedef enum nss_status nss_setnetgrent (const char *, struct __netgrent *);
typedef enum nss_status nss_setprotoent (int);
typedef enum nss_status nss_setpwent (int);
typedef enum nss_status nss_setrpcent (int);
typedef enum nss_status nss_setservent (int);
typedef enum nss_status nss_setsgent (int);
typedef enum nss_status nss_setspent (int);

/* Declare all NSS functions for MODULE.  */
#define NSS_DECLARE_MODULE_FUNCTIONS(module)                            \
  extern nss_endaliasent _nss_##module##_endaliasent;                    \
  extern nss_endetherent _nss_##module##_endetherent;                    \
  extern nss_endgrent _nss_##module##_endgrent;                          \
  extern nss_endhostent _nss_##module##_endhostent;                      \
  extern nss_endnetent _nss_##module##_endnetent;                        \
  extern nss_endnetgrent _nss_##module##__endnetgrent;                   \
  extern nss_endprotoent _nss_##module##_endprotoent;                    \
  extern nss_endpwent _nss_##module##_endpwent;                          \
  extern nss_endrpcent _nss_##module##_endrpcent;                        \
  extern nss_endservent _nss_##module##_endservent;                      \
  extern nss_endsgent _nss_##module##_endsgent;                          \
  extern nss_endspent _nss_##module##_endspent;                          \
  extern nss_getaliasbyname_r _nss_##module##_getaliasbyname_r;          \
  extern nss_getaliasent_r _nss_##module##_getaliasent_r;                \
  extern nss_getcanonname_r _nss_##module##_getcanonname_r;              \
  extern nss_getetherent_r _nss_##module##_getetherent_r;                \
  extern nss_getgrent_r _nss_##module##_getgrent_r;                      \
  extern nss_getgrgid_r _nss_##module##_getgrgid_r;                      \
  extern nss_getgrnam_r _nss_##module##_getgrnam_r;                      \
  extern nss_gethostbyaddr2_r _nss_##module##_gethostbyaddr2_r;          \
  extern nss_gethostbyaddr_r _nss_##module##_gethostbyaddr_r;            \
  extern nss_gethostbyname2_r _nss_##module##_gethostbyname2_r;          \
  extern nss_gethostbyname3_r _nss_##module##_gethostbyname3_r;          \
  extern nss_gethostbyname4_r _nss_##module##_gethostbyname4_r;          \
  extern nss_gethostbyname_r _nss_##module##_gethostbyname_r;            \
  extern nss_gethostent_r _nss_##module##_gethostent_r;                  \
  extern nss_gethostton_r _nss_##module##_gethostton_r;                  \
  extern nss_getnetbyaddr_r _nss_##module##_getnetbyaddr_r;              \
  extern nss_getnetbyname_r _nss_##module##_getnetbyname_r;              \
  extern nss_getnetent_r _nss_##module##_getnetent_r;                    \
  extern nss_getnetgrent_r _nss_##module##_getnetgrent_r;                \
  extern nss_getntohost_r _nss_##module##_getntohost_r;                  \
  extern nss_getprotobyname_r _nss_##module##_getprotobyname_r;          \
  extern nss_getprotobynumber_r _nss_##module##_getprotobynumber_r;      \
  extern nss_getprotoent_r _nss_##module##_getprotoent_r;                \
  extern nss_getpublickey _nss_##module##_getpublickey;                  \
  extern nss_getpwent_r _nss_##module##_getpwent_r;                      \
  extern nss_getpwnam_r _nss_##module##_getpwnam_r;                      \
  extern nss_getpwuid_r _nss_##module##_getpwuid_r;                      \
  extern nss_getrpcbyname_r _nss_##module##_getrpcbyname_r;              \
  extern nss_getrpcbynumber_r _nss_##module##_getrpcbynumber_r;          \
  extern nss_getrpcent_r _nss_##module##_getrpcent_r;                    \
  extern nss_getsecretkey _nss_##module##_getsecretkey;                  \
  extern nss_getservbyname_r _nss_##module##_getservbyname_r;            \
  extern nss_getservbyport_r _nss_##module##_getservbyport_r;            \
  extern nss_getservent_r _nss_##module##_getservent_r;                  \
  extern nss_getsgent_r _nss_##module##_getsgent_r;                      \
  extern nss_getsgnam_r _nss_##module##_getsgnam_r;                      \
  extern nss_getspent_r _nss_##module##_getspent_r;                      \
  extern nss_getspnam_r _nss_##module##_getspnam_r;                      \
  extern nss_init _nss_##module##_init;                                  \
  extern nss_initgroups_dyn _nss_##module##_initgroups_dyn;              \
  extern nss_netname2user _nss_##module##_netname2user;                  \
  extern nss_setaliasent _nss_##module##_setaliasent;                    \
  extern nss_setetherent _nss_##module##_setetherent;                    \
  extern nss_setgrent _nss_##module##_setgrent;                          \
  extern nss_sethostent _nss_##module##_sethostent;                      \
  extern nss_setnetent _nss_##module##_setnetent;                        \
  extern nss_setnetgrent _nss_##module##_setnetgrent;                    \
  extern nss_setprotoent _nss_##module##_setprotoent;                    \
  extern nss_setpwent _nss_##module##_setpwent;                          \
  extern nss_setrpcent _nss_##module##_setrpcent;                        \
  extern nss_setservent _nss_##module##_setservent;                      \
  extern nss_setsgent _nss_##module##_setsgent;                          \
  extern nss_setspent _nss_##module##_setspent;                          \

__END_DECLS

#endif /* nss.h */