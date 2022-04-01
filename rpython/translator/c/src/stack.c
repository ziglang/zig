/* Stack operation */
#include "common_header.h"
#include "structdef.h"       /* for struct pypy_threadlocal_s */
#include <src/stack.h>
#include <src/threadlocal.h>
#include <stdio.h>


/* the current stack is in the interval [end-length:end].  We assume a
   stack that grows downward here. */

/* (stored in a struct to ensure that stack_end and stack_length are
   close together; used e.g. by the ppc jit backend) */
rpy_stacktoobig_t rpy_stacktoobig = {
    NULL,             /* stack_end */
    MAX_STACK_SIZE,   /* stack_length */
    1                 /* report_error */
};

void LL_stack_set_length_fraction(double fraction)
{
	rpy_stacktoobig.stack_length = (Signed)(MAX_STACK_SIZE * fraction);
}

char LL_stack_too_big_slowpath(Signed current)
{
	Signed diff, max_stack_size;
	char *baseptr, *curptr = (char*)current;
	char *tl;
	struct pypy_threadlocal_s *tl1;

	/* The stack_end variable is updated to match the current value
	   if it is still 0 or if we later find a 'curptr' position
	   that is above it.  The real stack_end pointer is stored in
	   thread-local storage, but we try to minimize its overhead by
	   keeping a local copy in rpy_stacktoobig.stack_end. */

	OP_THREADLOCALREF_ADDR(tl);
	tl1 = (struct pypy_threadlocal_s *)tl;
	baseptr = tl1->stack_end;
	max_stack_size = rpy_stacktoobig.stack_length;
	if (baseptr == NULL) {
		/* first time we see this thread */
	}
	else {
		diff = baseptr - curptr;
		if (((Unsigned)diff) <= (Unsigned)max_stack_size) {
			/* within bounds, probably just had a thread switch */
			rpy_stacktoobig.stack_end = baseptr;
			return 0;
		}
		if (((Unsigned)-diff) <= (Unsigned)max_stack_size) {
			/* stack underflowed: the initial estimation of
			   the stack base must be revised */
		}
		else {	/* stack overflow (probably) */
			return rpy_stacktoobig.report_error;
		}
	}

	/* update the stack base pointer to the current value */
	baseptr = curptr;
	tl1->stack_end = baseptr;
	rpy_stacktoobig.stack_end = baseptr;
	return 0;
}
