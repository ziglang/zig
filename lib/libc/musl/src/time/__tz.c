#include "time_impl.h"
#include <stdint.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include "libc.h"
#include "lock.h"

long  __timezone = 0;
int   __daylight = 0;
char *__tzname[2] = { 0, 0 };

weak_alias(__timezone, timezone);
weak_alias(__daylight, daylight);
weak_alias(__tzname, tzname);

static char std_name[TZNAME_MAX+1];
static char dst_name[TZNAME_MAX+1];
const char __utc[] = "UTC";

static int dst_off;
static int r0[5], r1[5];

static const unsigned char *zi, *trans, *index, *types, *abbrevs, *abbrevs_end;
static size_t map_size;

static char old_tz_buf[32];
static char *old_tz = old_tz_buf;
static size_t old_tz_size = sizeof old_tz_buf;

static volatile int lock[1];

static int getint(const char **p)
{
	unsigned x;
	for (x=0; **p-'0'<10U; (*p)++) x = **p-'0' + 10*x;
	return x;
}

static int getoff(const char **p)
{
	int neg = 0;
	if (**p == '-') {
		++*p;
		neg = 1;
	} else if (**p == '+') {
		++*p;
	}
	int off = 3600*getint(p);
	if (**p == ':') {
		++*p;
		off += 60*getint(p);
		if (**p == ':') {
			++*p;
			off += getint(p);
		}
	}
	return neg ? -off : off;
}

static void getrule(const char **p, int rule[5])
{
	int r = rule[0] = **p;

	if (r!='M') {
		if (r=='J') ++*p;
		else rule[0] = 0;
		rule[1] = getint(p);
	} else {
		++*p; rule[1] = getint(p);
		++*p; rule[2] = getint(p);
		++*p; rule[3] = getint(p);
	}

	if (**p=='/') {
		++*p;
		rule[4] = getoff(p);
	} else {
		rule[4] = 7200;
	}
}

static void getname(char *d, const char **p)
{
	int i;
	if (**p == '<') {
		++*p;
		for (i=0; (*p)[i] && (*p)[i]!='>'; i++)
			if (i<TZNAME_MAX) d[i] = (*p)[i];
		if ((*p)[i]) ++*p;
	} else {
		for (i=0; ((*p)[i]|32)-'a'<26U; i++)
			if (i<TZNAME_MAX) d[i] = (*p)[i];
	}
	*p += i;
	d[i<TZNAME_MAX?i:TZNAME_MAX] = 0;
}

#define VEC(...) ((const unsigned char[]){__VA_ARGS__})

static uint32_t zi_read32(const unsigned char *z)
{
	return (unsigned)z[0]<<24 | z[1]<<16 | z[2]<<8 | z[3];
}

static size_t zi_dotprod(const unsigned char *z, const unsigned char *v, size_t n)
{
	size_t y;
	uint32_t x;
	for (y=0; n; n--, z+=4, v++) {
		x = zi_read32(z);
		y += x * *v;
	}
	return y;
}

static void do_tzset()
{
	char buf[NAME_MAX+25], *pathname=buf+24;
	const char *try, *s, *p;
	const unsigned char *map = 0;
	size_t i;
	static const char search[] =
		"/usr/share/zoneinfo/\0/share/zoneinfo/\0/etc/zoneinfo/\0";

	s = getenv("TZ");
	if (!s) s = "/etc/localtime";
	if (!*s) s = __utc;

	if (old_tz && !strcmp(s, old_tz)) return;

	for (i=0; i<5; i++) r0[i] = r1[i] = 0;

	if (zi) __munmap((void *)zi, map_size);

	/* Cache the old value of TZ to check if it has changed. Avoid
	 * free so as not to pull it into static programs. Growth
	 * strategy makes it so free would have minimal benefit anyway. */
	i = strlen(s);
	if (i > PATH_MAX+1) s = __utc, i = 3;
	if (i >= old_tz_size) {
		old_tz_size *= 2;
		if (i >= old_tz_size) old_tz_size = i+1;
		if (old_tz_size > PATH_MAX+2) old_tz_size = PATH_MAX+2;
		old_tz = malloc(old_tz_size);
	}
	if (old_tz) memcpy(old_tz, s, i+1);

	/* Non-suid can use an absolute tzfile pathname or a relative
	 * pathame beginning with "."; in secure mode, only the
	 * standard path will be searched. */
	if (*s == ':' || ((p=strchr(s, '/')) && !memchr(s, ',', p-s))) {
		if (*s == ':') s++;
		if (*s == '/' || *s == '.') {
			if (!libc.secure || !strcmp(s, "/etc/localtime"))
				map = __map_file(s, &map_size);
		} else {
			size_t l = strlen(s);
			if (l <= NAME_MAX && !strchr(s, '.')) {
				memcpy(pathname, s, l+1);
				pathname[l] = 0;
				for (try=search; !map && *try; try+=l+1) {
					l = strlen(try);
					memcpy(pathname-l, try, l);
					map = __map_file(pathname-l, &map_size);
				}
			}
		}
		if (!map) s = __utc;
	}
	if (map && (map_size < 44 || memcmp(map, "TZif", 4))) {
		__munmap((void *)map, map_size);
		map = 0;
		s = __utc;
	}

	zi = map;
	if (map) {
		int scale = 2;
		if (sizeof(time_t) > 4 && map[4]=='2') {
			size_t skip = zi_dotprod(zi+20, VEC(1,1,8,5,6,1), 6);
			trans = zi+skip+44+44;
			scale++;
		} else {
			trans = zi+44;
		}
		index = trans + (zi_read32(trans-12) << scale);
		types = index + zi_read32(trans-12);
		abbrevs = types + 6*zi_read32(trans-8);
		abbrevs_end = abbrevs + zi_read32(trans-4);
		if (zi[map_size-1] == '\n') {
			for (s = (const char *)zi+map_size-2; *s!='\n'; s--);
			s++;
		} else {
			const unsigned char *p;
			__tzname[0] = __tzname[1] = 0;
			__daylight = __timezone = dst_off = 0;
			for (p=types; p<abbrevs; p+=6) {
				if (!p[4] && !__tzname[0]) {
					__tzname[0] = (char *)abbrevs + p[5];
					__timezone = -zi_read32(p);
				}
				if (p[4] && !__tzname[1]) {
					__tzname[1] = (char *)abbrevs + p[5];
					dst_off = -zi_read32(p);
					__daylight = 1;
				}
			}
			if (!__tzname[0]) __tzname[0] = __tzname[1];
			if (!__tzname[0]) __tzname[0] = (char *)__utc;
			if (!__daylight) {
				__tzname[1] = __tzname[0];
				dst_off = __timezone;
			}
			return;
		}
	}

	if (!s) s = __utc;
	getname(std_name, &s);
	__tzname[0] = std_name;
	__timezone = getoff(&s);
	getname(dst_name, &s);
	__tzname[1] = dst_name;
	if (dst_name[0]) {
		__daylight = 1;
		if (*s == '+' || *s=='-' || *s-'0'<10U)
			dst_off = getoff(&s);
		else
			dst_off = __timezone - 3600;
	} else {
		__daylight = 0;
		dst_off = __timezone;
	}

	if (*s == ',') s++, getrule(&s, r0);
	if (*s == ',') s++, getrule(&s, r1);
}

/* Search zoneinfo rules to find the one that applies to the given time,
 * and determine alternate opposite-DST-status rule that may be needed. */

static size_t scan_trans(long long t, int local, size_t *alt)
{
	int scale = 3 - (trans == zi+44);
	uint64_t x;
	int off = 0;

	size_t a = 0, n = (index-trans)>>scale, m;

	if (!n) {
		if (alt) *alt = 0;
		return 0;
	}

	/* Binary search for 'most-recent rule before t'. */
	while (n > 1) {
		m = a + n/2;
		x = zi_read32(trans + (m<<scale));
		if (scale == 3) x = x<<32 | zi_read32(trans + (m<<scale) + 4);
		else x = (int32_t)x;
		if (local) off = (int32_t)zi_read32(types + 6 * index[m-1]);
		if (t - off < (int64_t)x) {
			n /= 2;
		} else {
			a = m;
			n -= n/2;
		}
	}

	/* First and last entry are special. First means to use lowest-index
	 * non-DST type. Last means to apply POSIX-style rule if available. */
	n = (index-trans)>>scale;
	if (a == n-1) return -1;
	if (a == 0) {
		x = zi_read32(trans + (a<<scale));
		if (scale == 3) x = x<<32 | zi_read32(trans + (a<<scale) + 4);
		else x = (int32_t)x;
		if (local) off = (int32_t)zi_read32(types + 6 * index[a-1]);
		if (t - off < (int64_t)x) {
			for (a=0; a<(abbrevs-types)/6; a++) {
				if (types[6*a+4] != types[4]) break;
			}
			if (a == (abbrevs-types)/6) a = 0;
			if (types[6*a+4]) {
				*alt = a;
				return 0;
			} else {
				*alt = 0;
				return a;
			}
		}
	}

	/* Try to find a neighboring opposite-DST-status rule. */
	if (alt) {
		if (a && types[6*index[a-1]+4] != types[6*index[a]+4])
			*alt = index[a-1];
		else if (a+1<n && types[6*index[a+1]+4] != types[6*index[a]+4])
			*alt = index[a+1];
		else
			*alt = index[a];
	}

	return index[a];
}

static int days_in_month(int m, int is_leap)
{
	if (m==2) return 28+is_leap;
	else return 30+((0xad5>>(m-1))&1);
}

/* Convert a POSIX DST rule plus year to seconds since epoch. */

static long long rule_to_secs(const int *rule, int year)
{
	int is_leap;
	long long t = __year_to_secs(year, &is_leap);
	int x, m, n, d;
	if (rule[0]!='M') {
		x = rule[1];
		if (rule[0]=='J' && (x < 60 || !is_leap)) x--;
		t += 86400 * x;
	} else {
		m = rule[1];
		n = rule[2];
		d = rule[3];
		t += __month_to_secs(m-1, is_leap);
		int wday = (int)((t + 4*86400) % (7*86400)) / 86400;
		int days = d - wday;
		if (days < 0) days += 7;
		if (n == 5 && days+28 >= days_in_month(m, is_leap)) n = 4;
		t += 86400 * (days + 7*(n-1));
	}
	t += rule[4];
	return t;
}

/* Determine the time zone in effect for a given time in seconds since the
 * epoch. It can be given in local or universal time. The results will
 * indicate whether DST is in effect at the queried time, and will give both
 * the GMT offset for the active zone/DST rule and the opposite DST. This
 * enables a caller to efficiently adjust for the case where an explicit
 * DST specification mismatches what would be in effect at the time. */

void __secs_to_zone(long long t, int local, int *isdst, long *offset, long *oppoff, const char **zonename)
{
	LOCK(lock);

	do_tzset();

	if (zi) {
		size_t alt, i = scan_trans(t, local, &alt);
		if (i != -1) {
			*isdst = types[6*i+4];
			*offset = (int32_t)zi_read32(types+6*i);
			*zonename = (const char *)abbrevs + types[6*i+5];
			if (oppoff) *oppoff = (int32_t)zi_read32(types+6*alt);
			UNLOCK(lock);
			return;
		}
	}

	if (!__daylight) goto std;

	/* FIXME: may be broken if DST changes right at year boundary?
	 * Also, this could be more efficient.*/
	long long y = t / 31556952 + 70;
	while (__year_to_secs(y, 0) > t) y--;
	while (__year_to_secs(y+1, 0) < t) y++;

	long long t0 = rule_to_secs(r0, y);
	long long t1 = rule_to_secs(r1, y);

	if (!local) {
		t0 += __timezone;
		t1 += dst_off;
	}
	if (t0 < t1) {
		if (t >= t0 && t < t1) goto dst;
		goto std;
	} else {
		if (t >= t1 && t < t0) goto std;
		goto dst;
	}
std:
	*isdst = 0;
	*offset = -__timezone;
	if (oppoff) *oppoff = -dst_off;
	*zonename = __tzname[0];
	UNLOCK(lock);
	return;
dst:
	*isdst = 1;
	*offset = -dst_off;
	if (oppoff) *oppoff = -__timezone;
	*zonename = __tzname[1];
	UNLOCK(lock);
}

static void __tzset()
{
	LOCK(lock);
	do_tzset();
	UNLOCK(lock);
}

weak_alias(__tzset, tzset);

const char *__tm_to_tzname(const struct tm *tm)
{
	const void *p = tm->__tm_zone;
	LOCK(lock);
	do_tzset();
	if (p != __utc && p != __tzname[0] && p != __tzname[1] &&
	    (!zi || (uintptr_t)p-(uintptr_t)abbrevs >= abbrevs_end - abbrevs))
		p = "";
	UNLOCK(lock);
	return p;
}
