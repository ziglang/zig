#include "pwf.h"
#include <pthread.h>

#define FIX(x) (pw->pw_##x = pw->pw_##x-line+buf)

static int getpw_r(const char *name, uid_t uid, struct passwd *pw, char *buf, size_t size, struct passwd **res)
{
	char *line = 0;
	size_t len = 0;
	int rv = 0;
	int cs;

	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);

	rv = __getpw_a(name, uid, pw, &line, &len, res);
	if (*res && size < len) {
		*res = 0;
		rv = ERANGE;
	}
	if (*res) {
		memcpy(buf, line, len);
		FIX(name);
		FIX(passwd);
		FIX(gecos);
		FIX(dir);
		FIX(shell);
	}
 	free(line);
	pthread_setcancelstate(cs, 0);
	if (rv) errno = rv;
	return rv;
}

int getpwnam_r(const char *name, struct passwd *pw, char *buf, size_t size, struct passwd **res)
{
	return getpw_r(name, 0, pw, buf, size, res);
}

int getpwuid_r(uid_t uid, struct passwd *pw, char *buf, size_t size, struct passwd **res)
{
	return getpw_r(0, uid, pw, buf, size, res);
}
