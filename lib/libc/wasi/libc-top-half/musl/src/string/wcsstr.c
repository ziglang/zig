#include <wchar.h>

#define MAX(a,b) ((a)>(b)?(a):(b))
#define MIN(a,b) ((a)<(b)?(a):(b))

static wchar_t *twoway_wcsstr(const wchar_t *h, const wchar_t *n)
{
	const wchar_t *z;
	size_t l, ip, jp, k, p, ms, p0, mem, mem0;

	/* Computing length of needle */
	for (l=0; n[l] && h[l]; l++);
	if (n[l]) return 0; /* hit the end of h */

	/* Compute maximal suffix */
	ip = -1; jp = 0; k = p = 1;
	while (jp+k<l) {
		if (n[ip+k] == n[jp+k]) {
			if (k == p) {
				jp += p;
				k = 1;
			} else k++;
		} else if (n[ip+k] > n[jp+k]) {
			jp += k;
			k = 1;
			p = jp - ip;
		} else {
			ip = jp++;
			k = p = 1;
		}
	}
	ms = ip;
	p0 = p;

	/* And with the opposite comparison */
	ip = -1; jp = 0; k = p = 1;
	while (jp+k<l) {
		if (n[ip+k] == n[jp+k]) {
			if (k == p) {
				jp += p;
				k = 1;
			} else k++;
		} else if (n[ip+k] < n[jp+k]) {
			jp += k;
			k = 1;
			p = jp - ip;
		} else {
			ip = jp++;
			k = p = 1;
		}
	}
	if (ip+1 > ms+1) ms = ip;
	else p = p0;

	/* Periodic needle? */
	if (wmemcmp(n, n+p, ms+1)) {
		mem0 = 0;
		p = MAX(ms, l-ms-1) + 1;
	} else mem0 = l-p;
	mem = 0;

	/* Initialize incremental end-of-haystack pointer */
	z = h;

	/* Search loop */
	for (;;) {
		/* Update incremental end-of-haystack pointer */
		if (z-h < l) {
			/* Fast estimate for MIN(l,63) */
			size_t grow = l | 63;
			const wchar_t *z2 = wmemchr(z, 0, grow);
			if (z2) {
				z = z2;
				if (z-h < l) return 0;
			} else z += grow;
		}

		/* Compare right half */
		for (k=MAX(ms+1,mem); n[k] && n[k] == h[k]; k++);
		if (n[k]) {
			h += k-ms;
			mem = 0;
			continue;
		}
		/* Compare left half */
		for (k=ms+1; k>mem && n[k-1] == h[k-1]; k--);
		if (k <= mem) return (wchar_t *)h;
		h += p;
		mem = mem0;
	}
}

wchar_t *wcsstr(const wchar_t *restrict h, const wchar_t *restrict n)
{
	/* Return immediately on empty needle or haystack */
	if (!n[0]) return (wchar_t *)h;
	if (!h[0]) return 0;

	/* Use faster algorithms for short needles */
	h = wcschr(h, *n);
	if (!h || !n[1]) return (wchar_t *)h;
	if (!h[1]) return 0;

	return twoway_wcsstr(h, n);
}
