#include <wchar.h>

static const unsigned char table[] = {
#include "nonspacing.h"
};

static const unsigned char wtable[] = {
#include "wide.h"
};

int wcwidth(wchar_t wc)
{
	if (wc < 0xffU)
		return (wc+1 & 0x7f) >= 0x21 ? 1 : wc ? -1 : 0;
	if ((wc & 0xfffeffffU) < 0xfffe) {
		if ((table[table[wc>>8]*32+((wc&255)>>3)]>>(wc&7))&1)
			return 0;
		if ((wtable[wtable[wc>>8]*32+((wc&255)>>3)]>>(wc&7))&1)
			return 2;
		return 1;
	}
	if ((wc & 0xfffe) == 0xfffe)
		return -1;
	if (wc-0x20000U < 0x20000)
		return 2;
	if (wc == 0xe0001 || wc-0xe0020U < 0x5f || wc-0xe0100 < 0xef)
		return 0;
	return 1;
}
