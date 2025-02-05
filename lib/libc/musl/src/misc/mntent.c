#include <stdio.h>
#include <string.h>
#include <mntent.h>
#include <errno.h>
#include <limits.h>

static char *internal_buf;
static size_t internal_bufsize;

#define SENTINEL (char *)&internal_buf

FILE *setmntent(const char *name, const char *mode)
{
	return fopen(name, mode);
}

int endmntent(FILE *f)
{
	if (f) fclose(f);
	return 1;
}

static char *unescape_ent(char *beg)
{
	char *dest = beg;
	const char *src = beg;
	while (*src) {
		const char *val;
		unsigned char cval = 0;
		if (*src != '\\') {
			*dest++ = *src++;
			continue;
		}
		if (src[1] == '\\') {
			++src;
			*dest++ = *src++;
			continue;
		}
		val = src + 1;
		for (int i = 0; i < 3; ++i) {
			if (*val >= '0' && *val <= '7') {
				cval <<= 3;
				cval += *val++ - '0';
			} else {
				break;
			}
		}
		if (cval) {
			*dest++ = cval;
			src = val;
		} else {
			*dest++ = *src++;
		}
	}
	*dest = 0;
	return beg;
}

struct mntent *getmntent_r(FILE *f, struct mntent *mnt, char *linebuf, int buflen)
{
	int n[8], use_internal = (linebuf == SENTINEL);
	size_t len, i;

	mnt->mnt_freq = 0;
	mnt->mnt_passno = 0;

	do {
		if (use_internal) {
			getline(&internal_buf, &internal_bufsize, f);
			linebuf = internal_buf;
		} else {
			fgets(linebuf, buflen, f);
		}
		if (feof(f) || ferror(f)) return 0;
		if (!strchr(linebuf, '\n')) {
			fscanf(f, "%*[^\n]%*[\n]");
			errno = ERANGE;
			return 0;
		}

		len = strlen(linebuf);
		if (len > INT_MAX) continue;
		for (i = 0; i < sizeof n / sizeof *n; i++) n[i] = len;
		sscanf(linebuf, " %n%*[^ \t]%n %n%*[^ \t]%n %n%*[^ \t]%n %n%*[^ \t]%n %d %d",
			n, n+1, n+2, n+3, n+4, n+5, n+6, n+7,
			&mnt->mnt_freq, &mnt->mnt_passno);
	} while (linebuf[n[0]] == '#' || n[1]==len);

	linebuf[n[1]] = 0;
	linebuf[n[3]] = 0;
	linebuf[n[5]] = 0;
	linebuf[n[7]] = 0;

	mnt->mnt_fsname = unescape_ent(linebuf+n[0]);
	mnt->mnt_dir = unescape_ent(linebuf+n[2]);
	mnt->mnt_type = unescape_ent(linebuf+n[4]);
	mnt->mnt_opts = unescape_ent(linebuf+n[6]);

	return mnt;
}

struct mntent *getmntent(FILE *f)
{
	static struct mntent mnt;
	return getmntent_r(f, &mnt, SENTINEL, 0);
}

int addmntent(FILE *f, const struct mntent *mnt)
{
	if (fseek(f, 0, SEEK_END)) return 1;
	return fprintf(f, "%s\t%s\t%s\t%s\t%d\t%d\n",
		mnt->mnt_fsname, mnt->mnt_dir, mnt->mnt_type, mnt->mnt_opts,
		mnt->mnt_freq, mnt->mnt_passno) < 0;
}

char *hasmntopt(const struct mntent *mnt, const char *opt)
{
	return strstr(mnt->mnt_opts, opt);
}
