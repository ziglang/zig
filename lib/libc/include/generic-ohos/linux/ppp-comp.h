/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _UAPI_NET_PPP_COMP_H
#define _UAPI_NET_PPP_COMP_H
#define CCP_CONFREQ 1
#define CCP_CONFACK 2
#define CCP_TERMREQ 5
#define CCP_TERMACK 6
#define CCP_RESETREQ 14
#define CCP_RESETACK 15
#define CCP_MAX_OPTION_LENGTH 32
#define CCP_CODE(dp) ((dp)[0])
#define CCP_ID(dp) ((dp)[1])
#define CCP_LENGTH(dp) (((dp)[2] << 8) + (dp)[3])
#define CCP_HDRLEN 4
#define CCP_OPT_CODE(dp) ((dp)[0])
#define CCP_OPT_LENGTH(dp) ((dp)[1])
#define CCP_OPT_MINLEN 2
#define CI_BSD_COMPRESS 21
#define CILEN_BSD_COMPRESS 3
#define BSD_NBITS(x) ((x) & 0x1F)
#define BSD_VERSION(x) ((x) >> 5)
#define BSD_CURRENT_VERSION 1
#define BSD_MAKE_OPT(v,n) (((v) << 5) | (n))
#define BSD_MIN_BITS 9
#define BSD_MAX_BITS 15
#define CI_DEFLATE 26
#define CI_DEFLATE_DRAFT 24
#define CILEN_DEFLATE 4
#define DEFLATE_MIN_SIZE 9
#define DEFLATE_MAX_SIZE 15
#define DEFLATE_METHOD_VAL 8
#define DEFLATE_SIZE(x) (((x) >> 4) + 8)
#define DEFLATE_METHOD(x) ((x) & 0x0F)
#define DEFLATE_MAKE_OPT(w) ((((w) - 8) << 4) + DEFLATE_METHOD_VAL)
#define DEFLATE_CHK_SEQUENCE 0
#define CI_MPPE 18
#define CILEN_MPPE 6
#define CI_PREDICTOR_1 1
#define CILEN_PREDICTOR_1 2
#define CI_PREDICTOR_2 2
#define CILEN_PREDICTOR_2 2
#endif