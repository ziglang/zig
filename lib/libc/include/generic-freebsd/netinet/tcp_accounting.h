#ifndef __tcp_accounting_h__
#define __tcp_accounting_h__
/*
 * Return values from tcp_do_ack_accounting
 * and indexs to the into the tcp_proc_time[]
 * array.
 */
#define ACK_BEHIND	0
#define ACK_SACK	1
#define ACK_CUMACK	2
#define ACK_CUMACK_SACK	3
#define ACK_DUPACK	4
#define ACK_RWND	5
/* Added values for tracking output too  */
#define SND_BLOCKED	6
#define SND_LIMITED	7
#define SND_OUT_DATA 	8
#define SND_OUT_ACK	9
#define SND_OUT_FAIL	10
/* We also count in the counts array two added (MSS sent and ACKS In) */
#define CNT_OF_MSS_OUT 11
#define CNT_OF_ACKS_IN 12

/* for the tcpcb we add two more cycle counters */
#define CYC_HANDLE_MAP 11
#define CYC_HANDLE_ACK 12

/* #define TCP_NUM_PROC_COUNTERS 11 defined in tcp_var.h */
/* #define TCP_NUM_CNT_COUNTERS 13 defined in tcp_var.h */

#endif