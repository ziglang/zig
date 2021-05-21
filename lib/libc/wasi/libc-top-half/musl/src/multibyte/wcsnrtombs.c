#include <wchar.h>
#include <limits.h>
#include <string.h>

size_t wcsnrtombs(char *restrict dst, const wchar_t **restrict wcs, size_t wn, size_t n, mbstate_t *restrict st)
{
	const wchar_t *ws = *wcs;
	size_t cnt = 0;
	if (!dst) n=0;
	while (ws && wn) {
		char tmp[MB_LEN_MAX];
		size_t l = wcrtomb(n<MB_LEN_MAX ? tmp : dst, *ws, 0);
		if (l==-1) {
			cnt = -1;
			break;
		}
		if (dst) {
			if (n<MB_LEN_MAX) {
				if (l>n) break;
				memcpy(dst, tmp, l);
			}
			dst += l;
			n -= l;
		}
		if (!*ws) {
			ws = 0;
			break;
		}
		ws++;
		wn--;
		cnt += l;
	}
	if (dst) *wcs = ws;
	return cnt;
}
