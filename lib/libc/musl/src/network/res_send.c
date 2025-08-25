#include <resolv.h>
#include <string.h>

int __res_send(const unsigned char *msg, int msglen, unsigned char *answer, int anslen)
{
	int r;
	if (anslen < 512) {
		unsigned char buf[512];
		r = __res_send(msg, msglen, buf, sizeof buf);
		if (r >= 0) memcpy(answer, buf, r < anslen ? r : anslen);
		return r;
	}
	r = __res_msend(1, &msg, &msglen, &answer, &anslen, anslen);
	return r<0 || !anslen ? -1 : anslen;
}

weak_alias(__res_send, res_send);
