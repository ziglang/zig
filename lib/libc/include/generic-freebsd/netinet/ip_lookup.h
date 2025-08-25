/*
 * Copyright (C) 2012 by Darren Reed.
 *
 * See the IPFILTER.LICENCE file for details on licencing.
 *
 * $Id$
 */
#ifndef __IP_LOOKUP_H__
#define __IP_LOOKUP_H__

# define	SIOCLOOKUPADDTABLE	_IOWR('r', 60, struct iplookupop)
# define	SIOCLOOKUPDELTABLE	_IOWR('r', 61, struct iplookupop)
# define	SIOCLOOKUPSTAT		_IOWR('r', 64, struct iplookupop)
# define	SIOCLOOKUPSTATW		_IOW('r', 64, struct iplookupop)
# define	SIOCLOOKUPFLUSH		_IOWR('r', 65, struct iplookupflush)
# define	SIOCLOOKUPADDNODE	_IOWR('r', 67, struct iplookupop)
# define	SIOCLOOKUPADDNODEW	_IOW('r', 67, struct iplookupop)
# define	SIOCLOOKUPDELNODE	_IOWR('r', 68, struct iplookupop)
# define	SIOCLOOKUPDELNODEW	_IOW('r', 68, struct iplookupop)

#define	LOOKUP_POOL_MAX	(IPL_LOGSIZE)
#define	LOOKUP_POOL_SZ	(IPL_LOGSIZE + 1)

typedef	struct	iplookupop	{
	int	iplo_type;	/* IPLT_* */
	int	iplo_unit;	/* IPL_LOG* */
	u_int	iplo_arg;
	char	iplo_name[FR_GROUPLEN];
	size_t	iplo_size;	/* sizeof struct at iplo_struct */
	void	*iplo_struct;
} iplookupop_t;

#define	LOOKUP_ANON	0x80000000


typedef	struct	iplookupflush	{
	int	iplf_type;	/* IPLT_* */
	int	iplf_unit;	/* IPL_LOG* */
	u_int	iplf_arg;
	u_int	iplf_count;
	char	iplf_name[FR_GROUPLEN];
} iplookupflush_t;

typedef	struct	iplookuplink	{
	int	ipll_type;	/* IPLT_* */
	int	ipll_unit;	/* IPL_LOG* */
	u_int	ipll_num;
	char	ipll_group[FR_GROUPLEN];
} iplookuplink_t;

#define	IPLT_ALL	-1
#define	IPLT_NONE	0
#define	IPLT_POOL	1
#define	IPLT_HASH	2
#define	IPLT_DSTLIST	3


#define	IPLT_ANON	0x80000000


typedef	union	{
	struct	iplookupiterkey {
		u_char	ilik_ival;
		u_char	ilik_type;	/* IPLT_* */
		u_char	ilik_otype;
		signed char	ilik_unit;	/* IPL_LOG* */
	} ilik_unstr;
	u_32_t	ilik_key;
} iplookupiterkey_t;

typedef	struct	ipflookupiter	{
	int			ili_nitems;
	iplookupiterkey_t	ili_lkey;
	char			ili_name[FR_GROUPLEN];
	void			*ili_data;
} ipflookupiter_t;

#define	ili_key		ili_lkey.ilik_key
#define	ili_ival	ili_lkey.ilik_unstr.ilik_ival
#define	ili_unit	ili_lkey.ilik_unstr.ilik_unit
#define	ili_type	ili_lkey.ilik_unstr.ilik_type
#define	ili_otype	ili_lkey.ilik_unstr.ilik_otype

#define	IPFLOOKUPITER_LIST	0
#define	IPFLOOKUPITER_NODE	1


typedef struct ipf_lookup {
	int	ipfl_type;
	void	*(*ipfl_create)(ipf_main_softc_t *);
	void	(*ipfl_destroy)(ipf_main_softc_t *, void *);
	int	(*ipfl_init)(ipf_main_softc_t *, void *);
	void	(*ipfl_fini)(ipf_main_softc_t *, void *);
	int	(*ipfl_addr_find)(ipf_main_softc_t *, void *,
				       int, void *, u_int);
	size_t	(*ipfl_flush)(ipf_main_softc_t *, void *,
				   iplookupflush_t *);
	int	(*ipfl_iter_deref)(ipf_main_softc_t *, void *,
					int, int, void *);
	int	(*ipfl_iter_next)(ipf_main_softc_t *, void *,
				       ipftoken_t *, ipflookupiter_t *);
	int	(*ipfl_node_add)(ipf_main_softc_t *, void *,
				      iplookupop_t *, int);
	int	(*ipfl_node_del)(ipf_main_softc_t *, void *,
				      iplookupop_t *, int);
	int	(*ipfl_stats_get)(ipf_main_softc_t *, void *,
				       iplookupop_t *);
	int	(*ipfl_table_add)(ipf_main_softc_t *, void *,
				       iplookupop_t *);
	int	(*ipfl_table_del)(ipf_main_softc_t *, void *,
				       iplookupop_t *);
	int	(*ipfl_table_deref)(ipf_main_softc_t *, void *, void *);
	void	*(*ipfl_table_find)(void *, int, char *);
	void	*(*ipfl_select_add_ref)(void *, int, char *);
	int	(*ipfl_select_node)(fr_info_t *, void *, u_32_t *,
					 frdest_t *);
	void	(*ipfl_expire)(ipf_main_softc_t *, void *);
	void	(*ipfl_sync)(ipf_main_softc_t *, void *);
} ipf_lookup_t;

extern int ipf_lookup_init(void);
extern int ipf_lookup_ioctl(ipf_main_softc_t *, caddr_t, ioctlcmd_t, int, int, void *);
extern void ipf_lookup_main_unload(void);
extern void ipf_lookup_deref(ipf_main_softc_t *, int, void *);
extern void ipf_lookup_iterderef(ipf_main_softc_t *, u_32_t, void *);
extern void *ipf_lookup_res_name(ipf_main_softc_t *, int, u_int, char *,
				      lookupfunc_t *);
extern void *ipf_lookup_res_num(ipf_main_softc_t *, int, u_int, u_int,
				     lookupfunc_t *);
extern void ipf_lookup_soft_destroy(ipf_main_softc_t *, void *);
extern void *ipf_lookup_soft_create(ipf_main_softc_t *);
extern int ipf_lookup_soft_init(ipf_main_softc_t *, void *);
extern int ipf_lookup_soft_fini(ipf_main_softc_t *, void *);
extern void *ipf_lookup_find_htable(ipf_main_softc_t *, int, char *);
extern void ipf_lookup_expire(ipf_main_softc_t *);
extern void ipf_lookup_sync(ipf_main_softc_t *, void *);
#ifndef _KERNEL
extern	void	ipf_lookup_dump(ipf_main_softc_t *, void *);
#endif
#endif /* __IP_LOOKUP_H__ */