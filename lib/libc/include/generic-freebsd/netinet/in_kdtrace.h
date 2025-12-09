/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2013 Mark Johnston <markj@FreeBSD.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the
 *    distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS_IN_KDTRACE_H_
#define	_SYS_IN_KDTRACE_H_

#include <sys/sdt.h>

#define	IP_PROBE(probe, arg0, arg1, arg2, arg3, arg4, arg5)		\
	SDT_PROBE6(ip, , , probe, arg0, arg1, arg2, arg3, arg4, arg5)
#define	UDP_PROBE(probe, arg0, arg1, arg2, arg3, arg4)			\
	SDT_PROBE5(udp, , , probe, arg0, arg1, arg2, arg3, arg4)
#define	UDPLITE_PROBE(probe, arg0, arg1, arg2, arg3, arg4)		\
	SDT_PROBE5(udplite, , , probe, arg0, arg1, arg2, arg3, arg4)
#define	TCP_PROBE1(probe, arg0)						\
	SDT_PROBE1(tcp, , , probe, arg0)
#define	TCP_PROBE2(probe, arg0, arg1)					\
	SDT_PROBE2(tcp, , , probe, arg0, arg1)
#define	TCP_PROBE3(probe, arg0, arg1, arg2)				\
	SDT_PROBE3(tcp, , , probe, arg0, arg1, arg2)
#define	TCP_PROBE4(probe, arg0, arg1, arg2, arg3)			\
	SDT_PROBE4(tcp, , , probe, arg0, arg1, arg2, arg3)
#define	TCP_PROBE5(probe, arg0, arg1, arg2, arg3, arg4)			\
	SDT_PROBE5(tcp, , , probe, arg0, arg1, arg2, arg3, arg4)
#define	TCP_PROBE6(probe, arg0, arg1, arg2, arg3, arg4, arg5)		\
	SDT_PROBE6(tcp, , , probe, arg0, arg1, arg2, arg3, arg4, arg5)

SDT_PROVIDER_DECLARE(ip);
SDT_PROVIDER_DECLARE(tcp);
SDT_PROVIDER_DECLARE(udp);
SDT_PROVIDER_DECLARE(udplite);

#ifdef KDTRACE_MIB_SDT
SDT_PROVIDER_DECLARE(mib);

SDT_PROBE_DECLARE(mib, ip, count, ips_total);
SDT_PROBE_DECLARE(mib, ip, count, ips_badsum);
SDT_PROBE_DECLARE(mib, ip, count, ips_tooshort);
SDT_PROBE_DECLARE(mib, ip, count, ips_toosmall);
SDT_PROBE_DECLARE(mib, ip, count, ips_badhlen);
SDT_PROBE_DECLARE(mib, ip, count, ips_badlen);
SDT_PROBE_DECLARE(mib, ip, count, ips_fragments);
SDT_PROBE_DECLARE(mib, ip, count, ips_fragdropped);
SDT_PROBE_DECLARE(mib, ip, count, ips_fragtimeout);
SDT_PROBE_DECLARE(mib, ip, count, ips_forward);
SDT_PROBE_DECLARE(mib, ip, count, ips_fastforward);
SDT_PROBE_DECLARE(mib, ip, count, ips_cantforward);
SDT_PROBE_DECLARE(mib, ip, count, ips_redirectsent);
SDT_PROBE_DECLARE(mib, ip, count, ips_noproto);
SDT_PROBE_DECLARE(mib, ip, count, ips_delivered);
SDT_PROBE_DECLARE(mib, ip, count, ips_localout);
SDT_PROBE_DECLARE(mib, ip, count, ips_odropped);
SDT_PROBE_DECLARE(mib, ip, count, ips_reassembled);
SDT_PROBE_DECLARE(mib, ip, count, ips_fragmented);
SDT_PROBE_DECLARE(mib, ip, count, ips_ofragments);
SDT_PROBE_DECLARE(mib, ip, count, ips_cantfrag);
SDT_PROBE_DECLARE(mib, ip, count, ips_badoptions);
SDT_PROBE_DECLARE(mib, ip, count, ips_noroute);
SDT_PROBE_DECLARE(mib, ip, count, ips_badvers);
SDT_PROBE_DECLARE(mib, ip, count, ips_rawout);
SDT_PROBE_DECLARE(mib, ip, count, ips_toolong);
SDT_PROBE_DECLARE(mib, ip, count, ips_notmember);
SDT_PROBE_DECLARE(mib, ip, count, ips_nogif);
SDT_PROBE_DECLARE(mib, ip, count, ips_badaddr);

SDT_PROBE_DECLARE(mib, ip6, count, ip6s_total);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_tooshort);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_toosmall);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_fragments);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_fragdropped);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_fragtimeout);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_fragoverflow);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_forward);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_cantforward);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_redirectsent);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_delivered);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_localout);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_odropped);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_reassembled);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_atomicfrags);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_fragmented);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_ofragments);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_cantfrag);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_badoptions);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_noroute);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_badvers);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_rawout);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_badscope);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_notmember);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_nxthist);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_m1);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_m2m);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_mext1);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_mext2m);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_exthdrtoolong);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_nogif);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_toomanyhdr);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_sources_none);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_sources_sameif);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_sources_otherif);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_sources_samescope);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_sources_otherscope);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_sources_deprecated);
SDT_PROBE_DECLARE(mib, ip6, count, ip6s_sources_rule);

SDT_PROBE_DECLARE(mib, icmp, count, icps_error);
SDT_PROBE_DECLARE(mib, icmp, count, icps_oldshort);
SDT_PROBE_DECLARE(mib, icmp, count, icps_oldicmp);
SDT_PROBE_DECLARE(mib, icmp, count, icps_outhist);
SDT_PROBE_DECLARE(mib, icmp, count, icps_badcode);
SDT_PROBE_DECLARE(mib, icmp, count, icps_tooshort);
SDT_PROBE_DECLARE(mib, icmp, count, icps_checksum);
SDT_PROBE_DECLARE(mib, icmp, count, icps_badlen);
SDT_PROBE_DECLARE(mib, icmp, count, icps_reflect);
SDT_PROBE_DECLARE(mib, icmp, count, icps_inhist);
SDT_PROBE_DECLARE(mib, icmp, count, icps_bmcastecho);
SDT_PROBE_DECLARE(mib, icmp, count, icps_bmcasttstamp);
SDT_PROBE_DECLARE(mib, icmp, count, icps_badaddr);
SDT_PROBE_DECLARE(mib, icmp, count, icps_noroute);

SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_error);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_canterror);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_toofreq);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_outhist);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_badcode);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_tooshort);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_checksum);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_badlen);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_dropped);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_reflect);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_inhist);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_nd_toomanyopt);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_odst_unreach_noroute);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_odst_unreach_admin);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_odst_unreach_beyondscope);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_odst_unreach_addr);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_odst_unreach_noport);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_opacket_too_big);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_otime_exceed_transit);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_otime_exceed_reassembly);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_oparamprob_header);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_oparamprob_nextheader);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_oparamprob_option);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_oredirect);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_ounknown);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_pmtuchg);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_nd_badopt);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_badns);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_badna);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_badrs);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_badra);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_badredirect);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_overflowdefrtr);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_overflowprfx);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_overflownndp);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_overflowredirect);
SDT_PROBE_DECLARE(mib, icmp6, count, icp6s_invlhlim);

SDT_PROBE_DECLARE(mib, udp, count, udps_ipackets);
SDT_PROBE_DECLARE(mib, udp, count, udps_hdrops);
SDT_PROBE_DECLARE(mib, udp, count, udps_badsum);
SDT_PROBE_DECLARE(mib, udp, count, udps_nosum);
SDT_PROBE_DECLARE(mib, udp, count, udps_badlen);
SDT_PROBE_DECLARE(mib, udp, count, udps_noport);
SDT_PROBE_DECLARE(mib, udp, count, udps_noportbcast);
SDT_PROBE_DECLARE(mib, udp, count, udps_fullsock);
SDT_PROBE_DECLARE(mib, udp, count, udps_pcbcachemiss);
SDT_PROBE_DECLARE(mib, udp, count, udps_pcbhashmiss);
SDT_PROBE_DECLARE(mib, udp, count, udps_opackets);
SDT_PROBE_DECLARE(mib, udp, count, udps_fastout);
SDT_PROBE_DECLARE(mib, udp, count, udps_noportmcast);
SDT_PROBE_DECLARE(mib, udp, count, udps_filtermcast);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_connattempt);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_accepts);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_connects);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_drops);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_conndrops);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_minmssdrops);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_closed);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_segstimed);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rttupdated);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_delack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_timeoutdrop);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rexmttimeo);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_persisttimeo);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_keeptimeo);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_keepprobe);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_keepdrops);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_progdrops);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_sndtotal);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sndpack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sndbyte);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sndrexmitpack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sndrexmitbyte);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sndrexmitbad);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sndacks);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sndprobe);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sndurg);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sndwinup);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sndctrl);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvtotal);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvpack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvbyte);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvbadsum);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvbadoff);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvreassfull);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvshort);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvduppack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvdupbyte);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvpartduppack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvpartdupbyte);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvoopack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvoobyte);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvpackafterwin);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvbyteafterwin);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvafterclose);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvwinprobe);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvdupack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvacktoomuch);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvackpack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvackbyte);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvwinupd);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_pawsdrop);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_predack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_preddat);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_pcbcachemiss);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_cachedrtt);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_cachedrttvar);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_cachedssthresh);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_usedrtt);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_usedrttvar);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_usedssthresh);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_persistdrop);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_badsyn);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_mturesent);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_listendrop);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_badrst);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_added);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_retransmitted);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_dupsyn);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_dropped);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_completed);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_bucketoverflow);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_cacheoverflow);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_reset);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_stale);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_aborted);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_badack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_unreach);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_zonefail);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_sendcookie);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_recvcookie);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_spurcookie);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sc_failcookie);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_hc_added);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_hc_bucketoverflow);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_finwait2_drops);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_sack_recovery_episode);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sack_rexmits);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sack_rexmits_tso);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sack_rexmit_bytes);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sack_rcv_blocks);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sack_send_blocks);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sack_lostrexmt);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sack_sboverflow);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_ecn_rcvce);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_ecn_rcvect0);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_ecn_rcvect1);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_ecn_shs);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_ecn_rcwnd);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_sig_rcvgoodsig);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sig_rcvbadsig);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sig_err_buildsig);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sig_err_sigopt);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_sig_err_nosigopt);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_pmtud_blackhole_activated);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_pmtud_blackhole_activated_min_mss);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_pmtud_blackhole_failed);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_tunneled_pkts);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_tunneled_errs);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_dsack_count);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_dsack_bytes);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_dsack_tlp_bytes);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_tw_recycles);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_tw_resets);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_tw_responds);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_ace_nect);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_ace_ect1);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_ace_ect0);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_ace_ce);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_ecn_sndect0);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_ecn_sndect1);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_tlpresends);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_tlpresend_bytes);

SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvghostack);
SDT_PROBE_DECLARE(mib, tcp, count, tcps_rcvacktooold);

SDT_PROBE_DECLARE(mib, ipsec, count, ips_in_polvio);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_in_nomem);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_in_inval);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_out_polvio);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_out_nosa);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_out_nomem);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_out_noroute);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_out_inval);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_out_bundlesa);

SDT_PROBE_DECLARE(mib, ipsec, count, ips_spdcache_hits);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_spdcache_misses);

SDT_PROBE_DECLARE(mib, ipsec, count, ips_clcopied);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_mbinserted);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_input_front);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_input_middle);
SDT_PROBE_DECLARE(mib, ipsec, count, ips_input_end);

SDT_PROBE_DECLARE(mib, esp, count, esps_hdrops);
SDT_PROBE_DECLARE(mib, esp, count, esps_nopf);
SDT_PROBE_DECLARE(mib, esp, count, esps_notdb);
SDT_PROBE_DECLARE(mib, esp, count, esps_badkcr);
SDT_PROBE_DECLARE(mib, esp, count, esps_qfull);
SDT_PROBE_DECLARE(mib, esp, count, esps_noxform);
SDT_PROBE_DECLARE(mib, esp, count, esps_badilen);
SDT_PROBE_DECLARE(mib, esp, count, esps_wrap);
SDT_PROBE_DECLARE(mib, esp, count, esps_badenc);
SDT_PROBE_DECLARE(mib, esp, count, esps_badauth);
SDT_PROBE_DECLARE(mib, esp, count, esps_replay);
SDT_PROBE_DECLARE(mib, esp, count, esps_input);
SDT_PROBE_DECLARE(mib, esp, count, esps_output);
SDT_PROBE_DECLARE(mib, esp, count, esps_invalid);
SDT_PROBE_DECLARE(mib, esp, count, esps_ibytes);
SDT_PROBE_DECLARE(mib, esp, count, esps_obytes);
SDT_PROBE_DECLARE(mib, esp, count, esps_toobig);
SDT_PROBE_DECLARE(mib, esp, count, esps_pdrops);
SDT_PROBE_DECLARE(mib, esp, count, esps_crypto);
SDT_PROBE_DECLARE(mib, esp, count, esps_tunnel);
SDT_PROBE_DECLARE(mib, esp, count, esps_hist);

SDT_PROBE_DECLARE(mib, ah, count, ahs_hdrops);
SDT_PROBE_DECLARE(mib, ah, count, ahs_nopf);
SDT_PROBE_DECLARE(mib, ah, count, ahs_notdb);
SDT_PROBE_DECLARE(mib, ah, count, ahs_badkcr);
SDT_PROBE_DECLARE(mib, ah, count, ahs_badauth);
SDT_PROBE_DECLARE(mib, ah, count, ahs_noxform);
SDT_PROBE_DECLARE(mib, ah, count, ahs_qfull);
SDT_PROBE_DECLARE(mib, ah, count, ahs_wrap);
SDT_PROBE_DECLARE(mib, ah, count, ahs_replay);
SDT_PROBE_DECLARE(mib, ah, count, ahs_badauthl);
SDT_PROBE_DECLARE(mib, ah, count, ahs_input);
SDT_PROBE_DECLARE(mib, ah, count, ahs_output);
SDT_PROBE_DECLARE(mib, ah, count, ahs_invalid);
SDT_PROBE_DECLARE(mib, ah, count, ahs_ibytes);
SDT_PROBE_DECLARE(mib, ah, count, ahs_obytes);
SDT_PROBE_DECLARE(mib, ah, count, ahs_toobig);
SDT_PROBE_DECLARE(mib, ah, count, ahs_pdrops);
SDT_PROBE_DECLARE(mib, ah, count, ahs_crypto);
SDT_PROBE_DECLARE(mib, ah, count, ahs_tunnel);
SDT_PROBE_DECLARE(mib, ah, count, ahs_hist);

SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_hdrops);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_nopf);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_notdb);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_badkcr);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_qfull);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_noxform);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_wrap);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_input);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_output);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_invalid);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_ibytes);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_obytes);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_toobig);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_pdrops);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_crypto);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_hist);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_threshold);
SDT_PROBE_DECLARE(mib, ipcomp, count, ipcomps_uncompr);

#endif

SDT_PROBE_DECLARE(ip, , , receive);
SDT_PROBE_DECLARE(ip, , , send);

SDT_PROBE_DECLARE(tcp, , , accept__established);
SDT_PROBE_DECLARE(tcp, , , accept__refused);
SDT_PROBE_DECLARE(tcp, , , connect__established);
SDT_PROBE_DECLARE(tcp, , , connect__refused);
SDT_PROBE_DECLARE(tcp, , , connect__request);
SDT_PROBE_DECLARE(tcp, , , receive);
SDT_PROBE_DECLARE(tcp, , , send);
SDT_PROBE_DECLARE(tcp, , , siftr);
SDT_PROBE_DECLARE(tcp, , , state__change);
SDT_PROBE_DECLARE(tcp, , , debug__input);
SDT_PROBE_DECLARE(tcp, , , debug__output);
SDT_PROBE_DECLARE(tcp, , , debug__user);
SDT_PROBE_DECLARE(tcp, , , debug__drop);
SDT_PROBE_DECLARE(tcp, , , receive__autoresize);

SDT_PROBE_DECLARE(udp, , , receive);
SDT_PROBE_DECLARE(udp, , , send);

SDT_PROBE_DECLARE(udplite, , , receive);
SDT_PROBE_DECLARE(udplite, , , send);

/*
 * These constants originate from the 4.4BSD sys/protosw.h.  They lost
 * their initial purpose in 2c37256e5a59, when single pr_usrreq method
 * was split into multiple methods.  However, they were used by TCPDEBUG,
 * a feature barely used, but it kept them in the tree for many years.
 * In 5d06879adb95 DTrace probes started to use them.  Note that they
 * are not documented in dtrace_tcp(4), so they are likely to be
 * eventually renamed to something better and extended/trimmed.
 */
#define	PRU_ATTACH		0	/* attach protocol to up */
#define	PRU_DETACH		1	/* detach protocol from up */
#define	PRU_BIND		2	/* bind socket to address */
#define	PRU_LISTEN		3	/* listen for connection */
#define	PRU_CONNECT		4	/* establish connection to peer */
#define	PRU_ACCEPT		5	/* accept connection from peer */
#define	PRU_DISCONNECT		6	/* disconnect from peer */
#define	PRU_SHUTDOWN		7	/* won't send any more data */
#define	PRU_RCVD		8	/* have taken data; more room now */
#define	PRU_SEND		9	/* send this data */
#define	PRU_ABORT		10	/* abort (fast DISCONNECT, DETATCH) */
#define	PRU_CONTROL		11	/* control operations on protocol */
#define	PRU_SENSE		12	/* return status into m */
#define	PRU_RCVOOB		13	/* retrieve out of band data */
#define	PRU_SENDOOB		14	/* send out of band data */
#define	PRU_SOCKADDR		15	/* fetch socket's address */
#define	PRU_PEERADDR		16	/* fetch peer's address */
#define	PRU_CONNECT2		17	/* connect two sockets */
/* begin for protocols internal use */
#define	PRU_FASTTIMO		18	/* 200ms timeout */
#define	PRU_SLOWTIMO		19	/* 500ms timeout */
#define	PRU_PROTORCV		20	/* receive from below */
#define	PRU_PROTOSEND		21	/* send to below */
/* end for protocol's internal use */
#define PRU_SEND_EOF		22	/* send and close */
#define	PRU_SOSETLABEL		23	/* MAC label change */
#define	PRU_CLOSE		24	/* socket close */
#define	PRU_FLUSH		25	/* flush the socket */
#define	PRU_NREQ		25

#ifdef PRUREQUESTS
const char *prurequests[] = {
	"ATTACH",	"DETACH",	"BIND",		"LISTEN",
	"CONNECT",	"ACCEPT",	"DISCONNECT",	"SHUTDOWN",
	"RCVD",		"SEND",		"ABORT",	"CONTROL",
	"SENSE",	"RCVOOB",	"SENDOOB",	"SOCKADDR",
	"PEERADDR",	"CONNECT2",	"FASTTIMO",	"SLOWTIMO",
	"PROTORCV",	"PROTOSEND",	"SEND_EOF",	"SOSETLABEL",
	"CLOSE",	"FLUSH",
};
#endif

#endif