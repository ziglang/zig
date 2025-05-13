
#ifndef _CRT_H_
#define _CRT_H_

/* zig patch: no HAVE_CTORS */
#define	INIT_CALL_SEQ(func)	"call " __STRING(func)

#endif
