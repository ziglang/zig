#include <pthread.h>
#include <byteswap.h>
#include <string.h>
#include <unistd.h>
#include "pwf.h"
#include "nscd.h"

static char *itoa(char *p, uint32_t x)
{
	// number of digits in a uint32_t + NUL
	p += 11;
	*--p = 0;
	do {
		*--p = '0' + x % 10;
		x /= 10;
	} while (x);
	return p;
}

int __getgr_a(const char *name, gid_t gid, struct group *gr, char **buf, size_t *size, char ***mem, size_t *nmem, struct group **res)
{
	FILE *f;
	int rv = 0;
	int cs;

	*res = 0;

	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);
	f = fopen("/etc/group", "rbe");
	if (!f) {
		rv = errno;
		goto done;
	}

	while (!(rv = __getgrent_a(f, gr, buf, size, mem, nmem, res)) && *res) {
		if (name && !strcmp(name, (*res)->gr_name)
		|| !name && (*res)->gr_gid == gid) {
			break;
		}
	}
	fclose(f);

	if (!*res && (rv == 0 || rv == ENOENT || rv == ENOTDIR)) {
		int32_t req = name ? GETGRBYNAME : GETGRBYGID;
		int32_t i;
		const char *key;
		int32_t groupbuf[GR_LEN] = {0};
		size_t len = 0;
		size_t grlist_len = 0;
		char gidbuf[11] = {0};
		int swap = 0;
		char *ptr;

		if (name) {
			key = name;
		} else {
			if (gid < 0 || gid > UINT32_MAX) {
				rv = 0;
				goto done;
			}
			key = itoa(gidbuf, gid);
		}

		f = __nscd_query(req, key, groupbuf, sizeof groupbuf, &swap);
		if (!f) { rv = errno; goto done; }

		if (!groupbuf[GRFOUND]) { rv = 0; goto cleanup_f; }

		if (!groupbuf[GRNAMELEN] || !groupbuf[GRPASSWDLEN]) {
			rv = EIO;
			goto cleanup_f;
		}

		if (groupbuf[GRNAMELEN] > SIZE_MAX - groupbuf[GRPASSWDLEN]) {
			rv = ENOMEM;
			goto cleanup_f;
		}
		len = groupbuf[GRNAMELEN] + groupbuf[GRPASSWDLEN];

		for (i = 0; i < groupbuf[GRMEMCNT]; i++) {
			uint32_t name_len;
			if (fread(&name_len, sizeof name_len, 1, f) < 1) {
				rv = ferror(f) ? errno : EIO;
				goto cleanup_f;
			}
			if (swap) {
				name_len = bswap_32(name_len);
			}
			if (name_len > SIZE_MAX - grlist_len
			|| name_len > SIZE_MAX - len) {
				rv = ENOMEM;
				goto cleanup_f;
			}
			len += name_len;
			grlist_len += name_len;
		}

		if (len > *size || !*buf) {
			char *tmp = realloc(*buf, len);
			if (!tmp) {
				rv = errno;
				goto cleanup_f;
			}
			*buf = tmp;
			*size = len;
		}

		if (!fread(*buf, len, 1, f)) {
			rv = ferror(f) ? errno : EIO;
			goto cleanup_f;
		}

		if (groupbuf[GRMEMCNT] + 1 > *nmem) {
			if (groupbuf[GRMEMCNT] + 1 > SIZE_MAX/sizeof(char*)) {
				rv = ENOMEM;
				goto cleanup_f;
			}
			char **tmp = realloc(*mem, (groupbuf[GRMEMCNT]+1)*sizeof(char*));
			if (!tmp) {
				rv = errno;
				goto cleanup_f;
			}
			*mem = tmp;
			*nmem = groupbuf[GRMEMCNT] + 1;
		}

		if (groupbuf[GRMEMCNT]) {
			mem[0][0] = *buf + groupbuf[GRNAMELEN] + groupbuf[GRPASSWDLEN];
			for (ptr = mem[0][0], i = 0; ptr != mem[0][0]+grlist_len; ptr++)
				if (!*ptr) mem[0][++i] = ptr+1;
			mem[0][i] = 0;

			if (i != groupbuf[GRMEMCNT]) {
				rv = EIO;
				goto cleanup_f;
			}
		} else {
			mem[0][0] = 0;
		}

		gr->gr_name = *buf;
		gr->gr_passwd = gr->gr_name + groupbuf[GRNAMELEN];
		gr->gr_gid = groupbuf[GRGID];
		gr->gr_mem = *mem;

		if (gr->gr_passwd[-1]
		|| gr->gr_passwd[groupbuf[GRPASSWDLEN]-1]) {
			rv = EIO;
			goto cleanup_f;
		}

		if (name && strcmp(name, gr->gr_name)
		|| !name && gid != gr->gr_gid) {
			rv = EIO;
			goto cleanup_f;
		}

		*res = gr;

cleanup_f:
		fclose(f);
		goto done;
	}

done:
	pthread_setcancelstate(cs, 0);
	if (rv) errno = rv;
	return rv;
}
