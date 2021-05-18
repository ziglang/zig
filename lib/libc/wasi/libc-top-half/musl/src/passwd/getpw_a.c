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

int __getpw_a(const char *name, uid_t uid, struct passwd *pw, char **buf, size_t *size, struct passwd **res)
{
	FILE *f;
	int cs;
	int rv = 0;

	*res = 0;

	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);

	f = fopen("/etc/passwd", "rbe");
	if (!f) {
		rv = errno;
		goto done;
	}

	while (!(rv = __getpwent_a(f, pw, buf, size, res)) && *res) {
		if (name && !strcmp(name, (*res)->pw_name)
		|| !name && (*res)->pw_uid == uid)
			break;
	}
	fclose(f);

	if (!*res && (rv == 0 || rv == ENOENT || rv == ENOTDIR)) {
		int32_t req = name ? GETPWBYNAME : GETPWBYUID;
		const char *key;
		int32_t passwdbuf[PW_LEN] = {0};
		size_t len = 0;
		char uidbuf[11] = {0};

		if (name) {
			key = name;
		} else {
			/* uid outside of this range can't be queried with the
			 * nscd interface, but might happen if uid_t ever
			 * happens to be a larger type (this is not true as of
			 * now)
			 */
			if(uid < 0 || uid > UINT32_MAX) {
				rv = 0;
				goto done;
			}
			key = itoa(uidbuf, uid);
		}

		f = __nscd_query(req, key, passwdbuf, sizeof passwdbuf, (int[]){0});
		if (!f) { rv = errno; goto done; }

		if(!passwdbuf[PWFOUND]) { rv = 0; goto cleanup_f; }

		/* A zero length response from nscd is invalid. We ignore
		 * invalid responses and just report an error, rather than
		 * trying to do something with them.
		 */
		if (!passwdbuf[PWNAMELEN] || !passwdbuf[PWPASSWDLEN]
		|| !passwdbuf[PWGECOSLEN] || !passwdbuf[PWDIRLEN]
		|| !passwdbuf[PWSHELLLEN]) {
			rv = EIO;
			goto cleanup_f;
		}

		if ((passwdbuf[PWNAMELEN]|passwdbuf[PWPASSWDLEN]
		     |passwdbuf[PWGECOSLEN]|passwdbuf[PWDIRLEN]
		     |passwdbuf[PWSHELLLEN]) >= SIZE_MAX/8) {
			rv = ENOMEM;
			goto cleanup_f;
		}

		len = passwdbuf[PWNAMELEN] + passwdbuf[PWPASSWDLEN]
		    + passwdbuf[PWGECOSLEN] + passwdbuf[PWDIRLEN]
		    + passwdbuf[PWSHELLLEN];

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

		pw->pw_name = *buf;
		pw->pw_passwd = pw->pw_name + passwdbuf[PWNAMELEN];
		pw->pw_gecos = pw->pw_passwd + passwdbuf[PWPASSWDLEN];
		pw->pw_dir = pw->pw_gecos + passwdbuf[PWGECOSLEN];
		pw->pw_shell = pw->pw_dir + passwdbuf[PWDIRLEN];
		pw->pw_uid = passwdbuf[PWUID];
		pw->pw_gid = passwdbuf[PWGID];

		/* Don't assume that nscd made sure to null terminate strings.
		 * It's supposed to, but malicious nscd should be ignored
		 * rather than causing a crash.
		 */
		if (pw->pw_passwd[-1] || pw->pw_gecos[-1] || pw->pw_dir[-1]
		|| pw->pw_shell[passwdbuf[PWSHELLLEN]-1]) {
			rv = EIO;
			goto cleanup_f;
		}

		if (name && strcmp(name, pw->pw_name)
		|| !name && uid != pw->pw_uid) {
			rv = EIO;
			goto cleanup_f;
		}


		*res = pw;
cleanup_f:
		fclose(f);
		goto done;
	}

done:
	pthread_setcancelstate(cs, 0);
	if (rv) errno = rv;
	return rv;
}
