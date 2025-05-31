#ifndef _NETINET_IN_SELSRC_H
#define _NETINET_IN_SELSRC_H

#define	IN_SELECTSRC_LEN	128
#define	IN_SCORE_SRC_MAX	8

typedef int (*in_score_src_t)(const struct in_addr *src,
                              int preference, int idx,
			      const struct in_addr *dst);

struct in_ifselsrc {
	uint32_t		iss_seqno;
	in_score_src_t		iss_score_src[IN_SCORE_SRC_MAX];
};

struct in_ifsysctl {
	struct ifnet		*isc_ifp;
	struct sysctllog	*isc_log;
	struct in_ifselsrc	*isc_selsrc;
};

enum in_category {
	IN_CATEGORY_LINKLOCAL = 0,
	IN_CATEGORY_PRIVATE,
	IN_CATEGORY_OTHER
};

struct ifaddr *in_getifa(struct ifaddr *, const struct sockaddr *);

void	*in_selsrc_domifattach(struct ifnet *ifp);
void	in_selsrc_domifdetach(struct ifnet *ifp, void *aux);

#endif /* _NETINET_IN_SELSRC_H */