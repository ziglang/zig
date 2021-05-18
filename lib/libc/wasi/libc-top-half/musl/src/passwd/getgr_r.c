#include "pwf.h"
#include <pthread.h>

#define FIX(x) (gr->gr_##x = gr->gr_##x-line+buf)

static int getgr_r(const char *name, gid_t gid, struct group *gr, char *buf, size_t size, struct group **res)
{
	char *line = 0;
	size_t len = 0;
	char **mem = 0;
	size_t nmem = 0;
	int rv = 0;
	size_t i;
	int cs;

	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);

	rv = __getgr_a(name, gid, gr, &line, &len, &mem, &nmem, res);
	if (*res && size < len + (nmem+1)*sizeof(char *) + 32) {
		*res = 0;
		rv = ERANGE;
	}
	if (*res) {
		buf += (16-(uintptr_t)buf)%16;
		gr->gr_mem = (void *)buf;
		buf += (nmem+1)*sizeof(char *);
		memcpy(buf, line, len);
		FIX(name);
		FIX(passwd);
		for (i=0; mem[i]; i++)
			gr->gr_mem[i] = mem[i]-line+buf;
		gr->gr_mem[i] = 0;
	}
 	free(mem);
 	free(line);
	pthread_setcancelstate(cs, 0);
	if (rv) errno = rv;
	return rv;
}

int getgrnam_r(const char *name, struct group *gr, char *buf, size_t size, struct group **res)
{
	return getgr_r(name, 0, gr, buf, size, res);
}

int getgrgid_r(gid_t gid, struct group *gr, char *buf, size_t size, struct group **res)
{
	return getgr_r(0, gid, gr, buf, size, res);
}
