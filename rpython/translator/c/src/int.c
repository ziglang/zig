#include "singleheader.h"
#include <src/int.h>
#include <src/support.h>
#include <src/exception.h>

/* adjusted from intobject.c, Python 2.3.3 */

long long op_llong_mul_ovf(long long a, long long b)
{
    double doubled_longprod;	/* (double)longprod */
    double doubleprod;		/* (double)a * (double)b */
    long long longprod;

    longprod = a * b;
    doubleprod = (double)a * (double)b;
    doubled_longprod = (double)longprod;

    /* Fast path for normal case:  small multiplicands, and no info
       is lost in either method. */
    if (doubled_longprod == doubleprod)
	return longprod;

    /* Somebody somewhere lost info.  Close enough, or way off?  Note
       that a != 0 and b != 0 (else doubled_longprod == doubleprod == 0).
       The difference either is or isn't significant compared to the
       true value (of which doubleprod is a good approximation).
    */
    {
	const double diff = doubled_longprod - doubleprod;
	const double absdiff = diff >= 0.0 ? diff : -diff;
	const double absprod = doubleprod >= 0.0 ? doubleprod :
	    -doubleprod;
	/* absdiff/absprod <= 1/32 iff
	   32 * absdiff <= absprod -- 5 good bits is "close enough" */
	if (32.0 * absdiff <= absprod)
	    return longprod;

	FAIL_OVF("integer multiplication");
	return -1;
    }
}

