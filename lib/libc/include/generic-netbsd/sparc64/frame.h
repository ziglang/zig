/*       $NetBSD: frame.h,v 1.15 2008/11/20 22:50:52 martin Exp $        */

#include <sparc/frame.h>

#ifndef _LOCORE
void *getframe(struct lwp *, int, int *);
#endif