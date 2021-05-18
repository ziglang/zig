#include <uchar.h>
#include <errno.h>
#include <wchar.h>

size_t c16rtomb(char *restrict s, char16_t c16, mbstate_t *restrict ps)
{
	static unsigned internal_state;
	if (!ps) ps = (void *)&internal_state;
	unsigned *x = (unsigned *)ps;
	wchar_t wc;

	if (!s) {
		if (*x) goto ilseq;
		return 1;
	}

	if (!*x && c16 - 0xd800u < 0x400) {
		*x = c16 - 0xd7c0 << 10;
		return 0;
	}

	if (*x) {
		if (c16 - 0xdc00u >= 0x400) goto ilseq;
		else wc = *x + c16 - 0xdc00;
		*x = 0;
	} else {
		wc = c16;
	}
	return wcrtomb(s, wc, 0);

ilseq:
	*x = 0;
	errno = EILSEQ;
	return -1;
}
