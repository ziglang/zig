#ifndef __timeb_defined
#define __timeb_defined 1

#include <bits/types/time_t.h>

/* Structure returned by the 'ftime' function.  */
struct timeb
  {
    time_t time;		/* Seconds since epoch, as from 'time'.  */
    unsigned short int millitm;	/* Additional milliseconds.  */
    short int timezone;		/* Minutes west of GMT.  */
    short int dstflag;		/* Nonzero if Daylight Savings Time used.  */
  };

#endif