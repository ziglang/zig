/*	$NetBSD: clnt.h,v 1.24 2016/01/23 02:34:09 dholland Exp $	*/

/*
 * Sun RPC is a product of Sun Microsystems, Inc. and is provided for
 * unrestricted use provided that this legend is included on all tape
 * media and as a part of the software program in whole or part.  Users
 * may copy or modify Sun RPC without charge, but are not authorized
 * to license or distribute it to anyone else except as part of a product or
 * program developed by the user.
 * 
 * SUN RPC IS PROVIDED AS IS WITH NO WARRANTIES OF ANY KIND INCLUDING THE
 * WARRANTIES OF DESIGN, MERCHANTIBILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE, OR ARISING FROM A COURSE OF DEALING, USAGE OR TRADE PRACTICE.
 * 
 * Sun RPC is provided with no support and without any obligation on the
 * part of Sun Microsystems, Inc. to assist in its use, correction,
 * modification or enhancement.
 * 
 * SUN MICROSYSTEMS, INC. SHALL HAVE NO LIABILITY WITH RESPECT TO THE
 * INFRINGEMENT OF COPYRIGHTS, TRADE SECRETS OR ANY PATENTS BY SUN RPC
 * OR ANY PART THEREOF.
 * 
 * In no event will Sun Microsystems, Inc. be liable for any lost revenue
 * or profits or other special, indirect and consequential damages, even if
 * Sun has been advised of the possibility of such damages.
 * 
 * Sun Microsystems, Inc.
 * 2550 Garcia Avenue
 * Mountain View, California  94043
 *
 *	from: @(#)clnt.h 1.31 94/04/29 SMI
 *	@(#)clnt.h	2.1 88/07/29 4.0 RPCSRC
 */

/*
 * clnt.h - Client side remote procedure call interface.
 *
 * Copyright (C) 1984, Sun Microsystems, Inc.
 */

#ifndef _RPC_CLNT_H_
#define _RPC_CLNT_H_
#include <sys/cdefs.h>

#include <rpc/rpc_com.h>

/*
 * Well-known IPV6 RPC broadcast address.
 */
#define RPCB_MULTICAST_ADDR "ff02::202"

/*
 * Rpc calls return an enum clnt_stat.  This should be looked at more,
 * since each implementation is required to live with this (implementation
 * independent) list of errors.
 */
enum clnt_stat {
	RPC_SUCCESS=0,			/* call succeeded */
	/*
	 * local errors
	 */
	RPC_CANTENCODEARGS=1,		/* can't encode arguments */
	RPC_CANTDECODERES=2,		/* can't decode results */
	RPC_CANTSEND=3,			/* failure in sending call */
	RPC_CANTRECV=4,			/* failure in receiving result */
	RPC_TIMEDOUT=5,			/* call timed out */
	/*
	 * remote errors
	 */
	RPC_VERSMISMATCH=6,		/* rpc versions not compatible */
	RPC_AUTHERROR=7,		/* authentication error */
	RPC_PROGUNAVAIL=8,		/* program not available */
	RPC_PROGVERSMISMATCH=9,		/* program version mismatched */
	RPC_PROCUNAVAIL=10,		/* procedure unavailable */
	RPC_CANTDECODEARGS=11,		/* decode arguments error */
	RPC_SYSTEMERROR=12,		/* generic "other problem" */

	/*
	 * rpc_call & clnt_create errors
	 */
	RPC_UNKNOWNHOST=13,		/* unknown host name */
	RPC_UNKNOWNPROTO=17,		/* unknown protocol */
	RPC_UNKNOWNADDR = 19,		/* Remote address unknown */
	RPC_NOBROADCAST = 21,		/* Broadcasting not supported */

	/*
	 * rpcbind errors
	 */
	RPC_RPCBFAILURE=14,		/* the pmapper failed in its call */
#define RPC_PMAPFAILURE RPC_RPCBFAILURE
	RPC_PROGNOTREGISTERED=15,	/* remote program is not registered */
	RPC_N2AXLATEFAILURE = 22,	/* name -> addr translation failed */

	/*
	 * Misc error in the TLI library (provided for compatibility)
	 */
	RPC_TLIERROR = 20,

	/*
	 * unspecified error
	 */
	RPC_FAILED=16,

	/*
	 * asynchronous errors
	 */
	RPC_INPROGRESS = 24,
	RPC_STALERACHANDLE = 25
};


/*
 * Error info.
 */
struct rpc_err {
	enum clnt_stat re_status;
	union {
		int RE_errno;		/* related system error */
		enum auth_stat RE_why;	/* why the auth error occurred */
		struct {
			rpcvers_t low;	/* lowest version supported */
			rpcvers_t high;	/* highest version supported */
		} RE_vers;
		struct {		/* maybe meaningful if RPC_FAILED */
			int32_t s1;
			int32_t s2;
		} RE_lb;		/* life boot & debugging only */
	} ru;
#define	re_errno	ru.RE_errno
#define	re_why		ru.RE_why
#define	re_vers		ru.RE_vers
#define	re_lb		ru.RE_lb
};


/*
 * Client rpc handle.
 * Created by individual implementations
 * Client is responsible for initializing auth, see e.g. auth_none.c.
 */
typedef struct __rpc_client {
	AUTH	*cl_auth;			/* authenticator */
	const struct clnt_ops {
		/* call remote procedure */
		enum clnt_stat	(*cl_call)(struct __rpc_client *,
				    rpcproc_t, xdrproc_t, const char *,
				    xdrproc_t, caddr_t, struct timeval);
		/* abort a call */
		void		(*cl_abort)(struct __rpc_client *);
		/* get specific error code */
		void		(*cl_geterr)(struct __rpc_client *,
				    struct rpc_err *);
		/* frees results */
		bool_t		(*cl_freeres)(struct __rpc_client *,
				    xdrproc_t, caddr_t);
		/* destroy this structure */
		void		(*cl_destroy)(struct __rpc_client *);
		/* the ioctl() of rpc */
		bool_t          (*cl_control)(struct __rpc_client *,
				    unsigned int, char *);
	} *cl_ops;
	void 			*cl_private;	/* private stuff */
	char			*cl_netid;	/* network token */
	char			*cl_tp;		/* device name */
} CLIENT;


/*
 * Timers used for the pseudo-transport protocol when using datagrams
 */
struct rpc_timers {
	unsigned short	rt_srtt;	/* smoothed round-trip time */
	unsigned short	rt_deviate;	/* estimated deviation */
	unsigned long	rt_rtxcur;	/* current (backed-off) rto */
};

/*      
 * Feedback values used for possible congestion and rate control
 */
#define FEEDBACK_REXMIT1	1	/* first retransmit */
#define FEEDBACK_OK		2	/* no retransmits */    

/* Used to set version of portmapper used in broadcast */
  
#define CLCR_SET_LOWVERS	3
#define CLCR_GET_LOWVERS	4
 
#define RPCSMALLMSGSIZE 400	/* a more reasonable packet size */

/*
 * client side rpc interface ops
 *
 * Parameter types are:
 *
 */

/*
 * enum clnt_stat
 * CLNT_CALL(rh, proc, xargs, argsp, xres, resp, timeout)
 * 	CLIENT *rh;
 *	rpcproc_t proc;
 *	xdrproc_t xargs;
 *	caddr_t argsp;
 *	xdrproc_t xres;
 *	caddr_t resp;
 *	struct timeval timeout;
 */
#define	CLNT_CALL(rh, proc, xargs, argsp, xres, resp, secs)		\
	((*(rh)->cl_ops->cl_call)(rh, proc, (xdrproc_t)xargs,		\
	(const char *)(const void *)(argsp), (xdrproc_t)xres,		\
	(caddr_t)(void *)resp, secs))
#define	clnt_call(rh, proc, xargs, argsp, xres, resp, secs)		\
	((*(rh)->cl_ops->cl_call)(rh, proc, (xdrproc_t)xargs,		\
	(const char *)(const void *)(argsp), (xdrproc_t)xres,		\
	(caddr_t)(void *)resp, secs))

/*
 * void
 * CLNT_ABORT(rh);
 * 	CLIENT *rh;
 */
#define	CLNT_ABORT(rh)	((*(rh)->cl_ops->cl_abort)(rh))
#define	clnt_abort(rh)	((*(rh)->cl_ops->cl_abort)(rh))

/*
 * struct rpc_err
 * CLNT_GETERR(rh);
 * 	CLIENT *rh;
 */
#define	CLNT_GETERR(rh,errp)	((*(rh)->cl_ops->cl_geterr)(rh, errp))
#define	clnt_geterr(rh,errp)	((*(rh)->cl_ops->cl_geterr)(rh, errp))


/*
 * bool_t
 * CLNT_FREERES(rh, xres, resp);
 * 	CLIENT *rh;
 *	xdrproc_t xres;
 *	caddr_t resp;
 */
#define	CLNT_FREERES(rh,xres,resp) ((*(rh)->cl_ops->cl_freeres)(rh,xres,resp))
#define	clnt_freeres(rh,xres,resp) ((*(rh)->cl_ops->cl_freeres)(rh,xres,resp))

/*
 * bool_t
 * CLNT_CONTROL(cl, request, info)
 *      CLIENT *cl;
 *      unsigned request;
 *      char *info;
 */
#define	CLNT_CONTROL(cl,rq,in) ((*(cl)->cl_ops->cl_control)(cl,rq,in))
#define	clnt_control(cl,rq,in) ((*(cl)->cl_ops->cl_control)(cl,rq,in))

/*
 * control operations that apply to both udp and tcp transports
 */
#define CLSET_TIMEOUT		1	/* set timeout (timeval) */
#define CLGET_TIMEOUT		2	/* get timeout (timeval) */
#define CLGET_SERVER_ADDR	3	/* get server's address (sockaddr) */
#define	CLGET_FD		6	/* get connections file descriptor */
#define	CLGET_SVC_ADDR		7	/* get server's address (netbuf) */
#define	CLSET_FD_CLOSE		8	/* close fd while clnt_destroy */
#define	CLSET_FD_NCLOSE		9	/* Do not close fd while clnt_destroy */
#define	CLGET_XID 		10	/* Get xid */
#define	CLSET_XID		11	/* Set xid */
#define	CLGET_VERS		12	/* Get version number */
#define	CLSET_VERS		13	/* Set version number */
#define	CLGET_PROG		14	/* Get program number */
#define	CLSET_PROG		15	/* Set program number */
#define	CLSET_SVC_ADDR		16	/* get server's address (netbuf) */
#define	CLSET_PUSH_TIMOD	17	/* push timod if not already present */
#define	CLSET_POP_TIMOD		18	/* pop timod */
/*
 * Connectionless only control operations
 */
#define CLSET_RETRY_TIMEOUT 4   /* set retry timeout (timeval) */
#define CLGET_RETRY_TIMEOUT 5   /* get retry timeout (timeval) */

/*
 * void
 * CLNT_DESTROY(rh);
 * 	CLIENT *rh;
 */
#define	CLNT_DESTROY(rh)	((*(rh)->cl_ops->cl_destroy)(rh))
#define	clnt_destroy(rh)	((*(rh)->cl_ops->cl_destroy)(rh))


/*
 * RPCTEST is a test program which is accessible on every rpc
 * transport/port.  It is used for testing, performance evaluation,
 * and network administration.
 */

#define RPCTEST_PROGRAM		((rpcprog_t)1)
#define RPCTEST_VERSION		((rpcvers_t)1)
#define RPCTEST_NULL_PROC	((rpcproc_t)2)
#define RPCTEST_NULL_BATCH_PROC	((rpcproc_t)3)

/*
 * By convention, procedure 0 takes null arguments and returns them
 */

#define NULLPROC ((rpcproc_t)0)

/*
 * Below are the client handle creation routines for the various
 * implementations of client side rpc.  They can return NULL if a
 * creation failure occurs.             
 */     

/*
 * Generic client creation routine. Supported protocols are those that
 * belong to the nettype namespace (/etc/netconfig).
 * CLIENT *
 * clnt_create(host, prog, vers, prot);
 *	const char *host; 	-- hostname
 *	const rpcprog_t prog;	-- program number
 *	const rpcvers_t vers;	-- version number
 *	const char *prot;	-- protocol
 */
__BEGIN_DECLS
extern CLIENT *clnt_create(const char *, const rpcprog_t, const rpcvers_t,
				const char *);
/*
 *
 * 	const char *hostname;			-- hostname
 *	const rpcprog_t prog;			-- program number
 *	const rpcvers_t vers;			-- version number
 *	const char *nettype;			-- network type
 */

/*
 * Generic client creation routine. Supported protocols are which belong
 * to the nettype name space.
 */
extern CLIENT *clnt_create_vers(const char *, const rpcprog_t, rpcvers_t *,
				     const rpcvers_t, const rpcvers_t,
				     const char *);
/*
 *	const char *host;		-- hostname
 *	const rpcprog_t prog;		-- program number
 *	rpcvers_t *vers_out;		-- servers highest available version
 *	const rpcvers_t vers_low;	-- low version number
 *	const rpcvers_t vers_high;	-- high version number
 *	const char *nettype;		-- network type
 */


/*
 * Generic client creation routine. It takes a netconfig structure
 * instead of nettype
 */
extern CLIENT *clnt_tp_create(const char *, const rpcprog_t,
				   const rpcvers_t, const struct netconfig *);
/*
 *	const char *hostname;			-- hostname
 *	const rpcprog_t prog;			-- program number
 *	const rpcvers_t vers;			-- version number
 *	const struct netconfig *netconf; 	-- network config structure
 */

/*
 * Generic TLI create routine. Only provided for compatibility.
 */

extern CLIENT *clnt_tli_create(const int, const struct netconfig *,
				    const struct netbuf *, const rpcprog_t,
				    const rpcvers_t, const unsigned int,
				    const unsigned int);
/*
 *	const register int fd;		-- fd
 *	const struct netconfig *nconf;	-- netconfig structure
 *	const struct netbuf *svcaddr;		-- servers address
 *	const unsigned long prog;		-- program number
 *	const unsigned long vers;		-- version number
 *	const unsigned sendsz;			-- send size
 *	const unsigned recvsz;			-- recv size
 */

/*
 * Low level clnt create routine for connectionful transports, e.g. tcp.
 */
extern CLIENT *clnt_vc_create(const int, const struct netbuf *,
				   const rpcprog_t, const rpcvers_t,
				   const unsigned int, const unsigned int);
/*
 *	const int fd;				-- open file descriptor
 *	const struct netbuf *svcaddr;		-- servers address
 *	const rpcprog_t prog;			-- program number
 *	const rpcvers_t vers;			-- version number
 *	const unsigned sendsz;			-- buffer recv size
 *	const unsigned recvsz;			-- buffer send size
 */

/*
 * Low level clnt create routine for connectionless transports, e.g. udp.
 */
extern CLIENT *clnt_dg_create(const int, const struct netbuf *,
				   const rpcprog_t, const rpcvers_t,
				   const unsigned int, const unsigned int);
/*
 *	const int fd;				-- open file descriptor
 *	const struct netbuf *svcaddr;		-- servers address
 *	const rpcprog_t program;		-- program number
 *	const rpcvers_t version;		-- version number
 *	const unsigned sendsz;			-- buffer recv size
 *	const unsigned recvsz;			-- buffer send size
 */

/*
 * Memory based rpc (for speed check and testing)
 * CLIENT *
 * clnt_raw_create(prog, vers)
 *	unsigned long prog;
 *	unsigned long vers;
 */
extern CLIENT *clnt_raw_create	(rpcprog_t, rpcvers_t);

__END_DECLS


/*
 * Print why creation failed
 */
__BEGIN_DECLS
extern void clnt_pcreateerror	(const char *);		/* stderr */
extern char *clnt_spcreateerror	(const char *);		/* string */
__END_DECLS

/*
 * Like clnt_perror(), but is more verbose in its output
 */ 
__BEGIN_DECLS
extern void clnt_perrno		(enum clnt_stat);		/* stderr */
extern char *clnt_sperrno	(enum clnt_stat);		/* string */
__END_DECLS

/*
 * Print an English error message, given the client error code
 */
__BEGIN_DECLS
extern void clnt_perror		(CLIENT *, const char *); 	/* stderr */
extern char *clnt_sperror	(CLIENT *, const char *);	/* string */
__END_DECLS


/* 
 * If a creation fails, the following allows the user to figure out why.
 */
struct rpc_createerr {
	enum clnt_stat cf_stat;
	struct rpc_err cf_error; /* useful when cf_stat == RPC_PMAPFAILURE */
};

__BEGIN_DECLS
extern struct rpc_createerr	*__rpc_createerr(void);
__END_DECLS
#define rpc_createerr		(*(__rpc_createerr()))

/*
 * The simplified interface:
 * enum clnt_stat
 * rpc_call(host, prognum, versnum, procnum, inproc, in, outproc, out, nettype)
 *	const char *host;
 *	const rpcprog_t prognum;
 *	const rpcvers_t versnum;
 *	const rpcproc_t procnum;
 *	const xdrproc_t inproc, outproc;
 *	const char *in;
 *	char *out;
 *	const char *nettype;
 */
__BEGIN_DECLS
extern enum clnt_stat rpc_call(const char *, const rpcprog_t,
				    const rpcvers_t, const rpcproc_t,
				    const xdrproc_t, const char *,
				    const xdrproc_t, char *, const char *);
__END_DECLS

/*
 * RPC broadcast interface
 * The call is broadcasted to all locally connected nets.
 *
 * extern enum clnt_stat
 * rpc_broadcast(prog, vers, proc, xargs, argsp, xresults, resultsp,
 *			eachresult, nettype)
 *	const rpcprog_t		prog;		-- program number
 *	const rpcvers_t		vers;		-- version number
 *	const rpcproc_t		proc;		-- procedure number
 *	const xdrproc_t	xargs;		-- xdr routine for args
 *	caddr_t		argsp;		-- pointer to args
 *	const xdrproc_t	xresults;	-- xdr routine for results
 *	caddr_t		resultsp;	-- pointer to results
 *	const resultproc_t	eachresult;	-- call with each result
 *	const char		*nettype;	-- Transport type
 *
 * For each valid response received, the procedure eachresult is called.
 * Its form is:
 *		done = eachresult(resp, raddr, nconf)
 *			bool_t done;
 *			caddr_t resp;
 *			struct netbuf *raddr;
 *			struct netconfig *nconf;
 * where resp points to the results of the call and raddr is the
 * address if the responder to the broadcast.  nconf is the transport
 * on which the response was received.
 *
 * extern enum clnt_stat
 * rpc_broadcast_exp(prog, vers, proc, xargs, argsp, xresults, resultsp,
 *			eachresult, inittime, waittime, nettype)
 *	const rpcprog_t		prog;		-- program number
 *	const rpcvers_t		vers;		-- version number
 *	const rpcproc_t		proc;		-- procedure number
 *	const xdrproc_t	xargs;		-- xdr routine for args
 *	caddr_t		argsp;		-- pointer to args
 *	const xdrproc_t	xresults;	-- xdr routine for results
 *	caddr_t		resultsp;	-- pointer to results
 *	const resultproc_t	eachresult;	-- call with each result
 *	const int 		inittime;	-- how long to wait initially
 *	const int 		waittime;	-- maximum time to wait
 *	const char		*nettype;	-- Transport type
 */

typedef bool_t (*resultproc_t)(caddr_t, ...);

__BEGIN_DECLS
extern enum clnt_stat rpc_broadcast(const rpcprog_t, const rpcvers_t,
    const rpcproc_t, const xdrproc_t, const char *, const xdrproc_t, caddr_t,
    const resultproc_t, const char *);
extern enum clnt_stat rpc_broadcast_exp(const rpcprog_t, const rpcvers_t,
    const rpcproc_t, const xdrproc_t, const char *, const xdrproc_t, caddr_t,
    const resultproc_t, const int, const int, const char *);
__END_DECLS

/* For backward compatibility */
#include <rpc/clnt_soc.h>

#endif /* !_RPC_CLNT_H_ */