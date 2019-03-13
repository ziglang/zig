#define _GNU_SOURCE
#include "pwf.h"
#include <grp.h>
#include <string.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <byteswap.h>
#include <errno.h>
#include "nscd.h"

int getgrouplist(const char *user, gid_t gid, gid_t *groups, int *ngroups)
{
	int rv, nlim, ret = -1;
	ssize_t i, n = 1;
	struct group gr;
	struct group *res;
	FILE *f;
	int swap = 0;
	int32_t resp[INITGR_LEN];
	uint32_t *nscdbuf = 0;
	char *buf = 0;
	char **mem = 0;
	size_t nmem = 0;
	size_t size;
	nlim = *ngroups;
	if (nlim >= 1) *groups++ = gid;

	f = __nscd_query(GETINITGR, user, resp, sizeof resp, &swap);
	if (!f) goto cleanup;
	if (resp[INITGRFOUND]) {
		nscdbuf = calloc(resp[INITGRNGRPS], sizeof(uint32_t));
		if (!nscdbuf) goto cleanup;
		if (!fread(nscdbuf, sizeof(*nscdbuf)*resp[INITGRNGRPS], 1, f)) {
			if (!ferror(f)) errno = EIO;
			goto cleanup;
		}
		if (swap) {
			for (i = 0; i < resp[INITGRNGRPS]; i++)
				nscdbuf[i] = bswap_32(nscdbuf[i]);
		}
	}
	fclose(f);

	f = fopen("/etc/group", "rbe");
	if (!f && errno != ENOENT && errno != ENOTDIR)
		goto cleanup;

	if (f) {
		while (!(rv = __getgrent_a(f, &gr, &buf, &size, &mem, &nmem, &res)) && res) {
			if (nscdbuf)
				for (i=0; i < resp[INITGRNGRPS]; i++) {
					if (nscdbuf[i] == gr.gr_gid) nscdbuf[i] = gid;
				}
			for (i=0; gr.gr_mem[i] && strcmp(user, gr.gr_mem[i]); i++);
			if (!gr.gr_mem[i]) continue;
			if (++n <= nlim) *groups++ = gr.gr_gid;
		}
		if (rv) {
			errno = rv;
			goto cleanup;
		}
	}
	if (nscdbuf) {
		for(i=0; i < resp[INITGRNGRPS]; i++) {
			if (nscdbuf[i] != gid)
				if(++n <= nlim) *groups++ = nscdbuf[i];
		}
	}

	ret = n > nlim ? -1 : n;
	*ngroups = n;

cleanup:
	if (f) fclose(f);
	free(nscdbuf);
	free(buf);
	free(mem);
	return ret;
}
