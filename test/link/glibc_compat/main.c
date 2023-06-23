#define _FILE_OFFSET_BITS 64
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <resolv.h>

int main() {
    /* in glibc 2.28+ and _FILE_OFFSET_BITS=64 fcntl is #define'd to fcntl64
     * Thus headers say `fcntl64` exists, but libc.so.6 (the old one)
     * disagrees, resulting in a linking error unless headers are made
     * backwards-compatible.
     *
     * Glibc 2.28+:
     *   FUNC    GLOBAL DEFAULT  UND fcntl64@GLIBC_2.28 (3):
     *
     * Glibc 2.27 or older:
     *   FUNC    GLOBAL DEFAULT  UND fcntl@GLIBC_2.2.5
     */
    printf("address to fcntl: %p\n", fcntl);

    /* The following functions became symbols of their own right with glibc
     * 2.34+. Before 2.34 resolv.h would #define res_search __res_search; and
     * __res_search is a valid symbol since the beginning of time.
     *
     * On glibc 2.34+ these symbols are linked this way:
     *   FUNC    GLOBAL DEFAULT  UND res_search@GLIBC_2.34 (2)
     *
     * Pre-glibc 2.34:
     *   FUNC    GLOBAL DEFAULT  UND __res_search@GLIBC_2.2.5 (4)
     */
    printf("address to res_search: %p\n", res_search);
    printf("address to res_nsearch: %p\n", res_nsearch);
    printf("address to res_query: %p\n", res_query);
    printf("address to res_nquery: %p\n", res_nquery);
    printf("address to res_querydomain: %p\n", res_querydomain);
    printf("address to res_nquerydomain: %p\n", res_nquerydomain);
    printf("address to dn_skipname: %p\n", dn_skipname);
    printf("address to dn_comp: %p\n", dn_comp);
    printf("address to dn_expand: %p\n", dn_expand);
}
