#include <wchar.h>

size_t wcsnrtombs(char *restrict dst, const wchar_t **restrict wcs, size_t wn, size_t n, mbstate_t *restrict st)
{
	size_t l, cnt=0, n2;
	char *s, buf[256];
	const wchar_t *ws = *wcs;
	const wchar_t *tmp_ws;

	if (!dst) s = buf, n = sizeof buf;
	else s = dst;

	while ( ws && n && ( (n2=wn)>=n || n2>32 ) ) {
		if (n2>=n) n2=n;
		tmp_ws = ws;
		l = wcsrtombs(s, &ws, n2, 0);
		if (!(l+1)) {
			cnt = l;
			n = 0;
			break;
		}
		if (s != buf) {
			s += l;
			n -= l;
		}
		wn = ws ? wn - (ws - tmp_ws) : 0;
		cnt += l;
	}
	if (ws) while (n && wn) {
		l = wcrtomb(s, *ws, 0);
		if ((l+1)<=1) {
			if (!l) ws = 0;
			else cnt = l;
			break;
		}
		ws++; wn--;
		/* safe - this loop runs fewer than sizeof(buf) times */
		s+=l; n-=l;
		cnt += l;
	}
	if (dst) *wcs = ws;
	return cnt;
}
