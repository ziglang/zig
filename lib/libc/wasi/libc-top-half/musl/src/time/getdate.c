#include <time.h>
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
#include <pthread.h>
#endif
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

int getdate_err;

struct tm *getdate(const char *s)
{
	static struct tm tmbuf;
	struct tm *ret = 0;
	char *datemsk = getenv("DATEMSK");
	FILE *f = 0;
	char fmt[100], *p;
	int cs;

#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	pthread_setcancelstate(PTHREAD_CANCEL_DEFERRED, &cs);
#endif

	if (!datemsk) {
		getdate_err = 1;
		goto out;
	}

	f = fopen(datemsk, "rbe");
	if (!f) {
		if (errno == ENOMEM) getdate_err = 6;
		else getdate_err = 2;
		goto out;
	}

	while (fgets(fmt, sizeof fmt, f)) {
		p = strptime(s, fmt, &tmbuf);
		if (p && !*p) {
			ret = &tmbuf;
			goto out;
		}
	}

	if (ferror(f)) getdate_err = 5;
	else getdate_err = 7;
out:
	if (f) fclose(f);
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	pthread_setcancelstate(cs, 0);
#endif
	return ret;
}
