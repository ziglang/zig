#include <resolv.h>
#include <netdb.h>

int res_query(const char *name, int class, int type, unsigned char *dest, int len)
{
	unsigned char q[280];
	int ql = __res_mkquery(0, name, class, type, 0, 0, 0, q, sizeof q);
	if (ql < 0) return ql;
	return __res_send(q, ql, dest, len);
}

weak_alias(res_query, res_search);
