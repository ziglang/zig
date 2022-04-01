#ifndef _PYPY_INSTRUMENT_H
#define _PYPY_INSTRUMENT_H

RPY_EXTERN void instrument_setup();

#ifdef PYPY_INSTRUMENT
RPY_EXTERN void instrument_count(Signed);
#define PYPY_INSTRUMENT_COUNT(label) instrument_count(label)
#else
#define PYPY_INSTRUMENT_COUNT
#endif

#endif  /* _PYPY_INSTRUMENT_H */ 
