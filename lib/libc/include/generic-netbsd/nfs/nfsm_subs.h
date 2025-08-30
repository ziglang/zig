/*	$NetBSD: nfsm_subs.h,v 1.55.4.1 2023/03/30 11:57:26 martin Exp $	*/

/*
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Rick Macklem at The University of Guelph.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)nfsm_subs.h	8.2 (Berkeley) 3/30/95
 */


#ifndef _NFS_NFSM_SUBS_H_
#define _NFS_NFSM_SUBS_H_


/*
 * These macros do strange and peculiar things to mbuf chains for
 * the assistance of the nfs code. To attempt to use them for any
 * other purpose will be dangerous. (they make weird assumptions)
 */

/*
 * First define what the actual subs. return
 */

#define	M_HASCL(m)	((m)->m_flags & M_EXT)
#define	NFSMADV(m, s)	(m)->m_data += (s)
#define	NFSMSIZ(m)	((M_HASCL(m)) ? (m)->m_ext.ext_size : \
				(((m)->m_flags & M_PKTHDR) ? MHLEN : MLEN))

/*
 * NFSv2 can only handle signed 32bit quantities and some clients
 * get confused by larger than 16bit block sizes. Limit values
 * for better compatibility.
 */
#define NFS_V2CLAMP32(x) ((x) > INT32_MAX ? INT32_MAX : (int32_t)(x))
#define NFS_V2CLAMP16(x) ((x) > INT16_MAX ? INT16_MAX : (int32_t)(x))

/*
 * Now for the macros that do the simple stuff and call the functions
 * for the hard stuff.
 * These macros use several vars. declared in nfsm_reqhead and these
 * vars. must not be used elsewhere unless you are careful not to corrupt
 * them. The vars. starting with pN and tN (N=1,2,3,..) are temporaries
 * that may be used so long as the value is not expected to retained
 * after a macro.
 * I know, this is kind of dorkey, but it makes the actual op functions
 * fairly clean and deals with the mess caused by the xdr discriminating
 * unions.
 */

#define	nfsm_build(a,c,s) \
		{ if ((s) > M_TRAILINGSPACE(mb)) { \
			struct mbuf *mb2; \
			mb2 = m_get(M_WAIT, MT_DATA); \
			MCLAIM(mb2, &nfs_mowner); \
			if ((s) > MLEN) \
				panic("build > MLEN"); \
			mb->m_next = mb2; \
			mb = mb2; \
			mb->m_len = 0; \
			bpos = mtod(mb, char *); \
		} \
		(a) = (c)(bpos); \
		mb->m_len += (s); \
		bpos += (s); }

#define nfsm_aligned(p) ALIGNED_POINTER(p,u_int32_t)

#define	nfsm_dissect(a, c, s) \
		{ t1 = mtod(md, char *) + md->m_len-dpos; \
		if (t1 >= (s) && nfsm_aligned(dpos)) { \
			(a) = (c)(dpos); \
			dpos += (s); \
		} else if ((t1 = nfsm_disct(&md, &dpos, (s), t1, &cp2)) != 0){ \
			error = t1; \
			m_freem(mrep); \
			goto nfsmout; \
		} else { \
			(a) = (c)cp2; \
		} }

#define nfsm_fhtom(n, v3) \
	      { if (v3) { \
			t2 = nfsm_rndup((n)->n_fhsize) + NFSX_UNSIGNED; \
			if (t2 <= M_TRAILINGSPACE(mb)) { \
				nfsm_build(tl, u_int32_t *, t2); \
				*tl++ = txdr_unsigned((n)->n_fhsize); \
				*(tl + ((t2>>2) - 2)) = 0; \
				memcpy(tl,(n)->n_fhp, (n)->n_fhsize); \
			} else if ((t2 = nfsm_strtmbuf(&mb, &bpos, \
				(void *)(n)->n_fhp, (n)->n_fhsize)) != 0) { \
				error = t2; \
				m_freem(mreq); \
				goto nfsmout; \
			} \
		} else { \
			nfsm_build(cp, void *, NFSX_V2FH); \
			memcpy(cp, (n)->n_fhp, NFSX_V2FH); \
		} }

#define nfsm_srvfhtom(f, v3) \
		{ if (v3) { \
			nfsm_build(tl, u_int32_t *, NFSX_UNSIGNED + \
			    NFSRVFH_SIZE(f)); \
			*tl++ = txdr_unsigned(NFSRVFH_SIZE(f)); \
			memcpy(tl, NFSRVFH_DATA(f), NFSRVFH_SIZE(f)); \
		} else { \
			KASSERT(NFSRVFH_SIZE(f) == NFSX_V2FH); \
			nfsm_build(cp, void *, NFSX_V2FH); \
			memcpy(cp, NFSRVFH_DATA(f), NFSX_V2FH); \
		} }

#define nfsm_srvpostop_fh(f) \
		{ nfsm_build(tl, u_int32_t *, \
		    2 * NFSX_UNSIGNED + NFSRVFH_SIZE(f)); \
		*tl++ = nfs_true; \
		*tl++ = txdr_unsigned(NFSRVFH_SIZE(f)); \
		memcpy(tl, NFSRVFH_DATA(f), NFSRVFH_SIZE(f)); \
		}

/*
 * nfsm_mtofh: dissect a "resulted obj" part of create-like operations
 * like mkdir.
 *
 * for nfsv3, dissect post_op_fh3 and following post_op_attr.
 * for nfsv2, dissect fhandle and following fattr.
 *
 * d: (IN) the vnode of the parent directory.
 * v: (OUT) the corresponding vnode (we allocate one if needed)
 * v3: (IN) true for nfsv3.
 * f: (OUT) true if we got valid filehandle.  always true for nfsv2.
 */

#define nfsm_mtofh(d, v, v3, f) \
		{ struct nfsnode *ttnp; nfsfh_t *ttfhp; int ttfhsize; \
		int hasattr = 0; \
		if (v3) { \
			nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
			(f) = fxdr_unsigned(int, *tl); \
		} else { \
			(f) = 1; \
			hasattr = 1; \
		} \
		if (f) { \
			nfsm_getfh(ttfhp, ttfhsize, (v3)); \
			if ((t1 = nfs_nget((d)->v_mount, ttfhp, ttfhsize, \
				&ttnp)) != 0) { \
				error = t1; \
				m_freem(mrep); \
				goto nfsmout; \
			} \
			(v) = NFSTOV(ttnp); \
		} \
		if (v3) { \
			nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
			if (f) \
				hasattr = fxdr_unsigned(int, *tl); \
			else if (fxdr_unsigned(int, *tl)) \
				nfsm_adv(NFSX_V3FATTR); \
		} \
		if (f && hasattr) \
			nfsm_loadattr((v), (struct vattr *)0, 0); \
		}

/*
 * nfsm_getfh: dissect a filehandle.
 *
 * f: (OUT) a filehandle.
 * s: (OUT) size of the filehandle in bytes.
 * v3: (IN) true if nfsv3.
 */

#define nfsm_getfh(f, s, v3) \
		{ if (v3) { \
			nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
			if (((s) = fxdr_unsigned(int, *tl)) <= 0 || \
				(s) > NFSX_V3FHMAX) { \
				m_freem(mrep); \
				error = EBADRPC; \
				goto nfsmout; \
			} \
		} else \
			(s) = NFSX_V2FH; \
		nfsm_dissect((f), nfsfh_t *, nfsm_rndup(s)); }

#define	nfsm_loadattr(v, a, flags) \
		{ struct vnode *ttvp = (v); \
		if ((t1 = nfsm_loadattrcache(&ttvp, &md, &dpos, (a), (flags))) \
		    != 0) { \
			error = t1; \
			m_freem(mrep); \
			goto nfsmout; \
		} \
		(v) = ttvp; }

/*
 * nfsm_postop_attr: process nfsv3 post_op_attr
 *
 * dissect post_op_attr.  if we got a one,
 * call nfsm_loadattrcache to update attribute cache.
 *
 * v: (IN/OUT) the corresponding vnode
 * f: (OUT) true if we got valid attribute
 * flags: (IN) flags for nfsm_loadattrcache
 */

#define	nfsm_postop_attr(v, f, flags) \
		{ struct vnode *ttvp = (v); \
		nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
		if (((f) = fxdr_unsigned(int, *tl)) != 0) { \
			if ((t1 = nfsm_loadattrcache(&ttvp, &md, &dpos, \
				(struct vattr *)0, (flags))) != 0) { \
				error = t1; \
				(f) = 0; \
				m_freem(mrep); \
				goto nfsmout; \
			} \
			(v) = ttvp; \
		} }

/*
 * nfsm_wcc_data: process nfsv3 wcc_data
 *
 * dissect pre_op_attr and then let nfsm_postop_attr dissect post_op_attr.
 *
 * v: (IN/OUT) the corresponding vnode
 * f: (IN/OUT)
 *	NFSV3_WCCRATTR	return true if we got valid post_op_attr.
 *	NFSV3_WCCCHK	return true if pre_op_attr's mtime is the same
 *			as our n_mtime.  (ie. our cache isn't stale.)
 * flags: (IN) flags for nfsm_loadattrcache
 * docheck: (IN) true if timestamp change is expected
 */

/* Used as (f) for nfsm_wcc_data() */
#define NFSV3_WCCRATTR	0
#define NFSV3_WCCCHK	1

#define	nfsm_wcc_data(v, f, flags, docheck) \
		{ int ttattrf, ttretf = 0, renewctime = 0, renewnctime = 0; \
		struct timespec ctime, mtime; \
		struct nfsnode *nfsp = VTONFS(v); \
		bool haspreopattr = false; \
		nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
		if (*tl == nfs_true) { \
			haspreopattr = true; \
			nfsm_dissect(tl, u_int32_t *, 6 * NFSX_UNSIGNED); \
			fxdr_nfsv3time(tl + 2, &mtime); \
			fxdr_nfsv3time(tl + 4, &ctime); \
			if (nfsp->n_ctime == ctime.tv_sec) \
				renewctime = 1; \
			if ((v)->v_type == VDIR) { \
				if (timespeccmp(&nfsp->n_nctime, &ctime, ==)) \
					renewnctime = 1; \
			} \
			if (f) { \
				ttretf = timespeccmp(&nfsp->n_mtime, &mtime, ==);\
			} \
		} \
		nfsm_postop_attr((v), ttattrf, (flags)); \
		nfsp = VTONFS(v); \
		if (ttattrf) { \
			if (haspreopattr && \
			    nfs_check_wccdata(nfsp, &ctime, &mtime, (docheck))) \
				renewctime = renewnctime = ttretf = 0; \
			if (renewctime) \
				nfsp->n_ctime = nfsp->n_vattr->va_ctime.tv_sec; \
			if (renewnctime) \
				nfsp->n_nctime = nfsp->n_vattr->va_ctime; \
		} \
		if (f) { \
			(f) = ttretf; \
		} else { \
			(f) = ttattrf; \
		} }

/* If full is true, set all fields, otherwise just set mode and time fields */
#define nfsm_v3attrbuild(a, full)						\
		{ if ((a)->va_mode != (mode_t)VNOVAL) {				\
			nfsm_build(tl, u_int32_t *, 2 * NFSX_UNSIGNED);		\
			*tl++ = nfs_true;					\
			*tl = txdr_unsigned((a)->va_mode);			\
		} else {							\
			nfsm_build(tl, u_int32_t *, NFSX_UNSIGNED);		\
			*tl = nfs_false;					\
		}								\
		if ((full) && (a)->va_uid != (uid_t)VNOVAL) {			\
			nfsm_build(tl, u_int32_t *, 2 * NFSX_UNSIGNED);		\
			*tl++ = nfs_true;					\
			*tl = txdr_unsigned((a)->va_uid);			\
		} else {							\
			nfsm_build(tl, u_int32_t *, NFSX_UNSIGNED);		\
			*tl = nfs_false;					\
		}								\
		if ((full) && (a)->va_gid != (gid_t)VNOVAL) {			\
			nfsm_build(tl, u_int32_t *, 2 * NFSX_UNSIGNED);		\
			*tl++ = nfs_true;					\
			*tl = txdr_unsigned((a)->va_gid);			\
		} else {							\
			nfsm_build(tl, u_int32_t *, NFSX_UNSIGNED);		\
			*tl = nfs_false;					\
		}								\
		if ((full) && (a)->va_size != VNOVAL) {				\
			nfsm_build(tl, u_int32_t *, 3 * NFSX_UNSIGNED);		\
			*tl++ = nfs_true;					\
			txdr_hyper((a)->va_size, tl);				\
		} else {							\
			nfsm_build(tl, u_int32_t *, NFSX_UNSIGNED);		\
			*tl = nfs_false;					\
		}								\
		if ((a)->va_atime.tv_sec != VNOVAL) {				\
			if ((a)->va_atime.tv_sec != time_second) {		\
				nfsm_build(tl, u_int32_t *, 3 * NFSX_UNSIGNED);	\
				*tl++ = txdr_unsigned(NFSV3SATTRTIME_TOCLIENT);	\
				txdr_nfsv3time(&(a)->va_atime, tl);		\
			} else {						\
				nfsm_build(tl, u_int32_t *, NFSX_UNSIGNED);	\
				*tl = txdr_unsigned(NFSV3SATTRTIME_TOSERVER);	\
			}							\
		} else {							\
			nfsm_build(tl, u_int32_t *, NFSX_UNSIGNED);		\
			*tl = txdr_unsigned(NFSV3SATTRTIME_DONTCHANGE);		\
		}								\
		if ((a)->va_mtime.tv_sec != VNOVAL) {				\
			if ((a)->va_mtime.tv_sec != time_second) {		\
				nfsm_build(tl, u_int32_t *, 3 * NFSX_UNSIGNED);	\
				*tl++ = txdr_unsigned(NFSV3SATTRTIME_TOCLIENT);	\
				txdr_nfsv3time(&(a)->va_mtime, tl);		\
			} else {						\
				nfsm_build(tl, u_int32_t *, NFSX_UNSIGNED);	\
				*tl = txdr_unsigned(NFSV3SATTRTIME_TOSERVER);	\
			}							\
		} else {							\
			nfsm_build(tl, u_int32_t *, NFSX_UNSIGNED);		\
			*tl = txdr_unsigned(NFSV3SATTRTIME_DONTCHANGE);		\
		}								\
		}


#define	nfsm_strsiz(s,m) \
		{ nfsm_dissect(tl,uint32_t *,NFSX_UNSIGNED); \
		if ((uint32_t)((s) = fxdr_unsigned(uint32_t,*tl)) > (m)) { \
			m_freem(mrep); \
			error = EBADRPC; \
			goto nfsmout; \
		} }

#define	nfsm_srvnamesiz(s) \
		{ nfsm_dissect(tl,uint32_t *,NFSX_UNSIGNED); \
		if ((uint32_t)((s) = fxdr_unsigned(uint32_t,*tl)) > \
		    NFS_MAXNAMLEN) \
			error = NFSERR_NAMETOL; \
		if (error) \
			nfsm_reply(0); \
		}

#define nfsm_mtouio(p,s) \
		if ((s) > 0 && \
		   (t1 = nfsm_mbuftouio(&md,(p),(s),&dpos)) != 0) { \
			error = t1; \
			m_freem(mrep); \
			goto nfsmout; \
		}

#define nfsm_uiotom(p,s) \
		if ((t1 = nfsm_uiotombuf((p),&mb,(s),&bpos)) != 0) { \
			error = t1; \
			m_freem(mreq); \
			goto nfsmout; \
		}

#define	nfsm_reqhead(n,a,s) \
		mb = mreq = nfsm_reqh((n),(a),(s),&bpos)

#define nfsm_reqdone	m_freem(mrep); \
		nfsmout:

#define nfsm_rndup(a)	(((a)+3)&(~0x3))
#define nfsm_padlen(a)	(nfsm_rndup(a) - (a))

#define	nfsm_request1(v, t, p, c, rexmitp)	\
		if ((error = nfs_request((v), mreq, (t), (p), \
		   (c), &mrep, &md, &dpos, (rexmitp))) != 0) { \
			if (error & NFSERR_RETERR) \
				error &= ~NFSERR_RETERR; \
			else \
				goto nfsmout; \
		}

#define	nfsm_request(v, t, p, c)	nfsm_request1((v), (t), (p), (c), NULL)

#define	nfsm_strtom(a,s,m) \
		if ((s) > (m)) { \
			m_freem(mreq); \
			error = ENAMETOOLONG; \
			goto nfsmout; \
		} \
		t2 = nfsm_rndup(s)+NFSX_UNSIGNED; \
		if (t2 <= M_TRAILINGSPACE(mb)) { \
			nfsm_build(tl,u_int32_t *,t2); \
			*tl++ = txdr_unsigned(s); \
			*(tl+((t2>>2)-2)) = 0; \
			memcpy(tl, (const char *)(a), (s)); \
		} else if ((t2 = nfsm_strtmbuf(&mb, &bpos, (a), (s))) != 0) { \
			error = t2; \
			m_freem(mreq); \
			goto nfsmout; \
		}

#define	nfsm_srvdone \
		nfsmout: \
		return(error)

#define	nfsm_reply(s) \
		{ \
		nfsd->nd_repstat = error; \
		if (error && !(nfsd->nd_flag & ND_NFSV3)) \
		   (void) nfs_rephead(0, nfsd, slp, error, cache, &frev, \
			mrq, &mb, &bpos); \
		else \
		   (void) nfs_rephead((s), nfsd, slp, error, cache, &frev, \
			mrq, &mb, &bpos); \
		if (mrep != NULL) { \
			m_freem(mrep); \
			mrep = NULL; \
		} \
		mreq = *mrq; \
		if (error && (!(nfsd->nd_flag & ND_NFSV3) || \
			error == EBADRPC)) {\
			error = 0; \
			goto nfsmout; \
			} \
		}

#define	nfsm_writereply(s, v3) \
		{ \
		nfsd->nd_repstat = error; \
		if (error && !(v3)) \
		   (void) nfs_rephead(0, nfsd, slp, error, cache, &frev, \
			&mreq, &mb, &bpos); \
		else \
		   (void) nfs_rephead((s), nfsd, slp, error, cache, &frev, \
			&mreq, &mb, &bpos); \
		}

#define	nfsm_adv(s) \
		{ t1 = mtod(md, char *) + md->m_len - dpos; \
		if (t1 >= (s)) { \
			dpos += (s); \
		} else if ((t1 = nfs_adv(&md, &dpos, (s), t1)) != 0) { \
			error = t1; \
			m_freem(mrep); \
			goto nfsmout; \
		} }

#define nfsm_srvmtofh(nsfh) \
	{ uint32_t fhlen = NFSX_V3FH; \
		if (nfsd->nd_flag & ND_NFSV3) { \
			nfsm_dissect(tl, uint32_t *, NFSX_UNSIGNED); \
			fhlen = fxdr_unsigned(uint32_t, *tl); \
			CTASSERT(NFSX_V3FHMAX <= FHANDLE_SIZE_MAX); \
			if (fhlen > NFSX_V3FHMAX || \
			    (fhlen < FHANDLE_SIZE_MIN && fhlen > 0)) { \
				error = EBADRPC; \
				nfsm_reply(0); \
			} \
		} else { \
			CTASSERT(NFSX_V2FH >= FHANDLE_SIZE_MIN); \
			fhlen = NFSX_V2FH; \
		} \
		(nsfh)->nsfh_size = fhlen; \
		if (fhlen != 0) { \
			KASSERT(fhlen >= FHANDLE_SIZE_MIN); \
			KASSERT(fhlen <= FHANDLE_SIZE_MAX); \
			nfsm_dissect(tl, u_int32_t *, fhlen); \
			memcpy(NFSRVFH_DATA(nsfh), tl, fhlen); \
		} \
	}

#define	nfsm_clget \
		if (bp >= be) { \
			if (mp == mb) \
				mp->m_len += bp-bpos; \
			mp = m_get(M_WAIT, MT_DATA); \
			MCLAIM(mp, &nfs_mowner); \
			m_clget(mp, M_WAIT); \
			mp->m_len = NFSMSIZ(mp); \
			mp2->m_next = mp; \
			mp2 = mp; \
			bp = mtod(mp, char *); \
			be = bp+mp->m_len; \
		} \
		tl = (u_int32_t *)bp

#define	nfsm_srvfillattr(a, f) \
		nfsm_srvfattr(nfsd, (a), (f))

#define nfsm_srvwcc_data(br, b, ar, a) \
		nfsm_srvwcc(nfsd, (br), (b), (ar), (a), &mb, &bpos)

#define nfsm_srvpostop_attr(r, a) \
		nfsm_srvpostopattr(nfsd, (r), (a), &mb, &bpos)

#define nfsm_srvsattr(a) \
		{ \
		nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
		if (*tl == nfs_true) { \
			nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
			(a)->va_mode = nfstov_mode(*tl); \
		} \
		nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
		if (*tl == nfs_true) { \
			nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
			(a)->va_uid = fxdr_unsigned(uid_t, *tl); \
		} \
		nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
		if (*tl == nfs_true) { \
			nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
			(a)->va_gid = fxdr_unsigned(gid_t, *tl); \
		} \
		nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
		if (*tl == nfs_true) { \
			nfsm_dissect(tl, u_int32_t *, 2 * NFSX_UNSIGNED); \
			(a)->va_size = fxdr_hyper(tl); \
		} \
		nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
		switch (fxdr_unsigned(int, *tl)) { \
		case NFSV3SATTRTIME_TOCLIENT: \
			nfsm_dissect(tl, u_int32_t *, 2 * NFSX_UNSIGNED); \
			fxdr_nfsv3time(tl, &(a)->va_atime); \
			break; \
		case NFSV3SATTRTIME_TOSERVER: \
			getnanotime(&(a)->va_atime); \
			(a)->va_vaflags |= VA_UTIMES_NULL; \
			break; \
		}; \
		nfsm_dissect(tl, u_int32_t *, NFSX_UNSIGNED); \
		switch (fxdr_unsigned(int, *tl)) { \
		case NFSV3SATTRTIME_TOCLIENT: \
			nfsm_dissect(tl, u_int32_t *, 2 * NFSX_UNSIGNED); \
			fxdr_nfsv3time(tl, &(a)->va_mtime); \
			(a)->va_vaflags &= ~VA_UTIMES_NULL; \
			break; \
		case NFSV3SATTRTIME_TOSERVER: \
			getnanotime(&(a)->va_mtime); \
			(a)->va_vaflags |= VA_UTIMES_NULL; \
			break; \
		}; }

#endif