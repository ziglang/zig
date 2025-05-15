/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2021 ARM Ltd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef	_MACHINE_CMN600_REG_H_
#define	_MACHINE_CMN600_REG_H_

#define	CMN600_COUNTERS_N		8
#define	CMN600_UNIT_MAX			4
#define	CMN600_PMU_DEFAULT_UNITS_N	2
#define	CMN600_COMMON_PMU_EVENT_SEL	0x2000	/* rw */
#define		CMN600_COMMON_PMU_EVENT_SEL_OCC_SHIFT	32
#define		CMN600_COMMON_PMU_EVENT_SEL_OCC_MASK	(0x7UL << 32)

struct cmn600_pmc {
	void	*arg;
	int	domain;
};

int cmn600_pmc_nunits(void);
int cmn600_pmc_getunit(int unit, void **arg, int *domain);

int cmn600_pmu_intr_cb(void *arg, int (*handler)(struct trapframe *tf,
    int unit, int i));

int pmu_cmn600_alloc_localpmc(void *arg, int nodeid, int node_type,
    int *local_counter);
int pmu_cmn600_free_localpmc(void *arg, int nodeid, int node_type,
    int local_counter);
int pmu_cmn600_rev(void *arg);
uint32_t pmu_cmn600_rd4(void *arg, int nodeid, int node_type, off_t reg);
int pmu_cmn600_wr4(void *arg, int nodeid, int node_type, off_t reg,
    uint32_t val);
uint64_t pmu_cmn600_rd8(void *arg, int nodeid, int node_type, off_t reg);
int pmu_cmn600_wr8(void *arg, int nodeid, int node_type, off_t reg,
    uint64_t val);
int pmu_cmn600_set8(void *arg, int nodeid, int node_type, off_t reg,
    uint64_t val);
int pmu_cmn600_clr8(void *arg, int nodeid, int node_type, off_t reg,
    uint64_t val);
int pmu_cmn600_md8(void *arg, int nodeid, int node_type, off_t reg,
    uint64_t mask, uint64_t val);

/* Configuration master registers */
#define	POR_CFGM_NODE_INFO			0x0000	/* ro */
#define		POR_CFGM_NODE_INFO_LOGICAL_ID_MASK	0xffff00000000UL
#define		POR_CFGM_NODE_INFO_LOGICAL_ID_SHIFT	32
#define		POR_CFGM_NODE_INFO_NODE_ID_MASK		0xffff0000
#define		POR_CFGM_NODE_INFO_NODE_ID_SHIFT	16
#define		POR_CFGM_NODE_INFO_NODE_TYPE_MASK	0xffff
#define		POR_CFGM_NODE_INFO_NODE_TYPE_SHIFT	0

#define		NODE_ID_SUB_MASK		0x3
#define		NODE_ID_SUB_SHIFT		0
#define		NODE_ID_PORT_MASK		0x4
#define		NODE_ID_PORT_SHIFT		2
#define		NODE_ID_X2B_MASK		(0x3 << 3)
#define		NODE_ID_X2B_SHIFT		3
#define		NODE_ID_Y2B_MASK		(0x3 << 5)
#define		NODE_ID_Y2B_SHIFT		5
#define		NODE_ID_X3B_MASK		(0x7 << 3)
#define		NODE_ID_X3B_SHIFT		3
#define		NODE_ID_Y3B_MASK		(0x7 << 6)
#define		NODE_ID_Y3B_SHIFT		6

#define	NODE_TYPE_INVALID	0x000
#define	NODE_TYPE_DVM		0x001
#define	NODE_TYPE_CFG		0x002
#define	NODE_TYPE_DTC		0x003
#define	NODE_TYPE_HN_I		0x004
#define	NODE_TYPE_HN_F		0x005
#define	NODE_TYPE_XP		0x006
#define	NODE_TYPE_SBSX		0x007
#define	NODE_TYPE_RN_I		0x00A
#define	NODE_TYPE_RN_D		0x00D
#define	NODE_TYPE_RN_SAM	0x00F
#define	NODE_TYPE_CXRA		0x100
#define	NODE_TYPE_CXHA		0x101
#define	NODE_TYPE_CXLA		0x102

#define	POR_CFGM_PERIPH_ID_0_PERIPH_ID_1	0x0008	/* ro */
#define	POR_CFGM_PERIPH_ID_2_PERIPH_ID_3	0x0010	/* ro */
#define		POR_CFGM_PERIPH_ID_2_REV_SHIFT			4
#define		POR_CFGM_PERIPH_ID_2_REV_MASK			0xf0
#define		POR_CFGM_PERIPH_ID_2_REV_R1P0			0
#define		POR_CFGM_PERIPH_ID_2_REV_R1P1			1
#define		POR_CFGM_PERIPH_ID_2_REV_R1P2			2
#define		POR_CFGM_PERIPH_ID_2_REV_R1P3			3
#define		POR_CFGM_PERIPH_ID_2_REV_R2P0			4
#define	POR_CFGM_PERIPH_ID_4_PERIPH_ID_5	0x0018	/* ro */
#define	POR_CFGM_PERIPH_ID_6_PERIPH_ID_7	0x0020	/* ro */
#define	POR_CFGM_PERIPH_ID_32(x)		(0x0008 + ((x) * 4)) /* ro 32 */
#define	POR_CFGM_COMPONENT_ID_0_COMPONENT_ID_1	0x0028	/* ro */
#define	POR_CFGM_COMPONENT_ID_2_COMPONENT_ID_3	0x0030	/* ro */
#define	POR_CFGM_CHILD_INFO			0x0080	/* ro */
#define		POR_CFGM_CHILD_INFO_CHILD_PTR_OFFSET_MASK	0xffff0000
#define		POR_CFGM_CHILD_INFO_CHILD_PTR_OFFSET_SHIFT	16
#define		POR_CFGM_CHILD_INFO_CHILD_COUNT_MASK		0x0000ffff
#define		POR_CFGM_CHILD_INFO_CHILD_COUNT_SHIFT		0
#define	POR_CFGM_SECURE_ACCESS			0x0980	/* rw */
#define	POR_CFGM_ERRGSR0			0x3000	/* ro */
#define	POR_CFGM_ERRGSR1			0x3008	/* ro */
#define	POR_CFGM_ERRGSR2			0x3010	/* ro */
#define	POR_CFGM_ERRGSR3			0x3018	/* ro */
#define	POR_CFGM_ERRGSR4			0x3020	/* ro */
#define	POR_CFGM_ERRGSR5			0x3080	/* ro */
#define	POR_CFGM_ERRGSR6			0x3088	/* ro */
#define	POR_CFGM_ERRGSR7			0x3090	/* ro */
#define	POR_CFGM_ERRGSR8			0x3098	/* ro */
#define	POR_CFGM_ERRGSR9			0x30a0	/* ro */
#define	POR_CFGM_ERRGSR(x)			(0x3000 + ((x) * 8)) /* ro */
#define	POR_CFGM_ERRGSR0_ns			0x3100	/* ro */
#define	POR_CFGM_ERRGSR1_ns			0x3108	/* ro */
#define	POR_CFGM_ERRGSR2_ns			0x3110	/* ro */
#define	POR_CFGM_ERRGSR3_ns			0x3118	/* ro */
#define	POR_CFGM_ERRGSR4_ns			0x3120	/* ro */
#define	POR_CFGM_ERRGSR5_ns			0x3180	/* ro */
#define	POR_CFGM_ERRGSR6_ns			0x3188	/* ro */
#define	POR_CFGM_ERRGSR7_ns			0x3190	/* ro */
#define	POR_CFGM_ERRGSR8_ns			0x3198	/* ro */
#define	POR_CFGM_ERRGSR9_ns			0x31a0	/* ro */
#define	POR_CFGM_ERRGSR_ns(x)			(0x3100 + ((x) * 8)) /* ro */
#define	POR_CFGM_ERRDEVAFF			0x3fa8	/* ro */
#define	POR_CFGM_ERRDEVARCH			0x3fb8	/* ro */
#define	POR_CFGM_ERRIDR				0x3fc8	/* ro */
#define	POR_CFGM_ERRPIDR45			0x3fd0	/* ro */
#define	POR_CFGM_ERRPIDR67			0x3fd8	/* ro */
#define	POR_CFGM_ERRPIDR01			0x3fe0	/* ro */
#define	POR_CFGM_ERRPIDR23			0x3fe8	/* ro */
#define	POR_CFGM_ERRCIDR01			0x3ff0	/* ro */
#define	POR_CFGM_ERRCIDR23			0x3ff8	/* ro */
#define	POR_INFO_GLOBAL				0x0900	/* ro */
#define		POR_INFO_GLOBAL_CHIC_MODE_EN			(1UL << 49) /* CHI-C mode enable */
#define		POR_INFO_GLOBAL_R2_ENABLE			(1UL << 48) /* CMN R2 feature enable */
#define		POR_INFO_GLOBAL_RNSAM_NUM_ADD_HASHED_TGT_SHIFT	36 /* Number of additional hashed target ID's supported by the RN SAM, beyond the local HNF count */
#define		POR_INFO_GLOBAL_RNSAM_NUM_ADD_HASHED_TGT_MASK	(0x3fUL << 36)
#define		POR_INFO_GLOBAL_NUM_REMOTE_RNF_SHIFT		28 /* Number of remote RN-F devices in the system when the CML feature is enabled */
#define		POR_INFO_GLOBAL_NUM_REMOTE_RNF_MASK		(0xffUL << 28)
#define		POR_INFO_GLOBAL_FLIT_PARITY_EN			(1 << 25) /* Indicates whether parity checking is enabled in the transport layer on all flits sent on the interconnect */
#define		POR_INFO_GLOBAL_DATACHECK_EN			(1 << 24) /* Indicates whether datacheck feature is enabled for CHI DAT flit */
#define		POR_INFO_GLOBAL_PHYSICAL_ADDRESS_WIDTH_SHIFT	16 /* Physical address width */
#define		POR_INFO_GLOBAL_PHYSICAL_ADDRESS_WIDTH_MASK	(0xff << 16)
#define		POR_INFO_GLOBAL_CHI_REQ_ADDR_WIDTH_SHIFT	8 /* REQ address width */
#define		POR_INFO_GLOBAL_CHI_REQ_ADDR_WIDTH_MASK		(0xff << 8)
#define		POR_INFO_GLOBAL_CHI_REQ_RSVDC_WIDTH_SHIFT	0 /* RSVDC field width in CHI REQ flit */
#define		POR_INFO_GLOBAL_CHI_REQ_RSVDC_WIDTH_MASK	0xff

#define	POR_PPU_INT_ENABLE			0x1000	/* rw */
#define	POR_PPU_INT_STATUS			0x1008	/* w1c */
#define	POR_PPU_QACTIVE_HYST			0x1010	/* rw */
#define	POR_CFGM_CHILD_POINTER_0		0x0100	/* ro */
#define	POR_CFGM_CHILD_POINTER(x)	(POR_CFGM_CHILD_POINTER_0 + ((x) * 8))
#define		POR_CFGM_CHILD_POINTER_EXT	(1 << 31)
#define		POR_CFGM_CHILD_POINTER_BASE_MASK 0x0fffffffUL

/* DN registers */
#define	POR_DN_NODE_INFO			0x0000	/* ro */
#define	POR_DN_CHILD_INFO			0x0080	/* ro */
#define	POR_DN_BUILD_INFO			0x0900	/* ro */
#define	POR_DN_SECURE_REGISTER_GROUPS_OVERRIDE	0x0980	/* rw */
#define	POR_DN_AUX_CTL				0x0a00	/* rw */
#define	POR_DN_VMF0_CTRL			0x0c00	/* rw */
#define	POR_DN_VMF0_RNF0			0x0c08	/* rw */
#define	POR_DN_VMF0_RND				0x0c10	/* rw */
#define	POR_DN_VMF0_CXRA			0x0c18	/* rw */
#define	POR_DN_VMF1_CTRL			0x0c20	/* rw */
#define	POR_DN_VMF1_RNF0			0x0c28	/* rw */
#define	POR_DN_VMF1_RND				0x0c30	/* rw */
#define	POR_DN_VMF1_CXRA			0x0c38	/* rw */
#define	POR_DN_VMF2_CTRL			0x0c40	/* rw */
#define	POR_DN_VMF2_RNF0			0x0c48	/* rw */
#define	POR_DN_VMF2_RND				0x0c50	/* rw */
#define	POR_DN_VMF2_CXRA			0x0c58	/* rw */
#define	POR_DN_VMF3_CTRL			0x0c60	/* rw */
#define	POR_DN_VMF3_RNF0			0x0c68	/* rw */
#define	POR_DN_VMF3_RND				0x0c70	/* rw */
#define	POR_DN_VMF3_CXRA			0x0c78	/* rw */
#define	POR_DN_VMF4_CTRL			0x0c80	/* rw */
#define	POR_DN_VMF4_RNF0			0x0c88	/* rw */
#define	POR_DN_VMF4_RND				0x0c90	/* rw */
#define	POR_DN_VMF4_CXRA			0x0c98	/* rw */
#define	POR_DN_VMF5_CTRL			0x0ca0	/* rw */
#define	POR_DN_VMF5_RNF0			0x0ca8	/* rw */
#define	POR_DN_VMF5_RND				0x0cb0	/* rw */
#define	POR_DN_VMF5_CXRA			0x0cb8	/* rw */
#define	POR_DN_VMF6_CTRL			0x0cc0	/* rw */
#define	POR_DN_VMF6_RNF0			0x0cc8	/* rw */
#define	POR_DN_VMF6_RND				0x0cd0	/* rw */
#define	POR_DN_VMF6_CXRA			0x0cd8	/* rw */
#define	POR_DN_VMF7_CTRL			0x0ce0	/* rw */
#define	POR_DN_VMF7_RNF0			0x0ce8	/* rw */
#define	POR_DN_VMF7_RND				0x0cf0	/* rw */
#define	POR_DN_VMF7_CXRA			0x0cf8	/* rw */
#define	POR_DN_VMF8_CTRL			0x0d00	/* rw */
#define	POR_DN_VMF8_RNF0			0x0d08	/* rw */
#define	POR_DN_VMF8_RND				0x0d10	/* rw */
#define	POR_DN_VMF8_CXRA			0x0d18	/* rw */
#define	POR_DN_VMF9_CTRL			0x0d20	/* rw */
#define	POR_DN_VMF9_RNF0			0x0d28	/* rw */
#define	POR_DN_VMF9_RND				0x0d30	/* rw */
#define	POR_DN_VMF9_CXRA			0x0d38	/* rw */
#define	POR_DN_VMF10_CTRL			0x0d40	/* rw */
#define	POR_DN_VMF10_RNF0			0x0d48	/* rw */
#define	POR_DN_VMF10_RND			0x0d50	/* rw */
#define	POR_DN_VMF10_CXRA			0x0d58	/* rw */
#define	POR_DN_VMF11_CTRL			0x0d60	/* rw */
#define	POR_DN_VMF11_RNF0			0x0d68	/* rw */
#define	POR_DN_VMF11_RND			0x0d70	/* rw */
#define	POR_DN_VMF11_CXRA			0x0d78	/* rw */
#define	POR_DN_VMF12_CTRL			0x0d80	/* rw */
#define	POR_DN_VMF12_RNF0			0x0d88	/* rw */
#define	POR_DN_VMF12_RND			0x0d90	/* rw */
#define	POR_DN_VMF12_CXRA			0x0d98	/* rw */
#define	POR_DN_VMF13_CTRL			0x0da0	/* rw */
#define	POR_DN_VMF13_RNF0			0x0da8	/* rw */
#define	POR_DN_VMF13_RND			0x0db0	/* rw */
#define	POR_DN_VMF13_CXRA			0x0db8	/* rw */
#define	POR_DN_VMF14_CTRL			0x0dc0	/* rw */
#define	POR_DN_VMF14_RNF0			0x0dc8	/* rw */
#define	POR_DN_VMF14_RND			0x0dd0	/* rw */
#define	POR_DN_VMF14_CXRA			0x0dd8	/* rw */
#define	POR_DN_VMF15_CTRL			0x0de0	/* rw */
#define	POR_DN_VMF15_RNF0			0x0de8	/* rw */
#define	POR_DN_VMF15_RND			0x0df0	/* rw */
#define	POR_DN_VMF15_CXRA			0x0df8	/* rw */
#define	POR_DN_PMU_EVENT_SEL			0x2000	/* rw */
#define		POR_DN_PMU_EVENT_SEL_OCCUP1_ID_SHIFT	32
#define		POR_DN_PMU_EVENT_SEL_OCCUP1_ID_MASK	(0xf << 32)
#define		POR_DN_PMU_EVENT_SEL_OCCUP1_ID_ALL		0
#define		POR_DN_PMU_EVENT_SEL_OCCUP1_ID_DVM_OPS		1
#define		POR_DN_PMU_EVENT_SEL_OCCUP1_ID_DVM_SYNCS	2
#define		POR_DN_PMU_EVENT_SEL_EVENT_ID3_SHIFT	24
#define		POR_DN_PMU_EVENT_SEL_EVENT_ID3_MASK	(0x3f << 24)
#define		POR_DN_PMU_EVENT_SEL_EVENT_ID2_SHIFT	16
#define		POR_DN_PMU_EVENT_SEL_EVENT_ID2_MASK	(0x3f << 16)
#define		POR_DN_PMU_EVENT_SEL_EVENT_ID1_SHIFT	8
#define		POR_DN_PMU_EVENT_SEL_EVENT_ID1_MASK	(0x3f << 8)
#define		POR_DN_PMU_EVENT_SEL_EVENT_ID0_SHIFT	0
#define		POR_DN_PMU_EVENT_SEL_EVENT_ID0_MASK	0x3f

/* Debug and trace register */
#define	POR_DT_NODE_INFO			0x0000	/* ro */
#define	POR_DT_CHILD_INFO			0x0080	/* ro */
#define	POR_DT_SECURE_ACCESS			0x0980	/* rw */
#define	POR_DT_DTC_CTL				0x0a00	/* rw */
#define		POR_DT_DTC_CTL_DT_EN			(1 << 0)
#define	POR_DT_TRIGGER_STATUS			0x0a10	/* ro */
#define	POR_DT_TRIGGER_STATUS_CLR		0x0a20	/* wo */
#define	POR_DT_TRACE_CONTROL			0x0a30	/* rw */
#define	POR_DT_TRACEID				0x0a48	/* rw */
#define	POR_DT_PMEVCNTAB			0x2000	/* rw */
#define	POR_DT_PMEVCNTCD			0x2010	/* rw */
#define	POR_DT_PMEVCNTEF			0x2020	/* rw */
#define	POR_DT_PMEVCNTGH			0x2030	/* rw */
#define	POR_DT_PMEVCNT(x)			(0x2000 + ((x) * 0x10))
#define		POR_DT_PMEVCNT_EVENCNT_SHIFT	0
#define		POR_DT_PMEVCNT_ODDCNT_SHIFT	32
#define	POR_DT_PMCCNTR				0x2040	/* rw */
#define	POR_DT_PMEVCNTSRAB			0x2050	/* rw */
#define	POR_DT_PMEVCNTSRCD			0x2060	/* rw */
#define	POR_DT_PMEVCNTSREF			0x2070	/* rw */
#define	POR_DT_PMEVCNTSRGH			0x2080	/* rw */
#define	POR_DT_PMCCNTRSR			0x2090	/* rw */
#define	POR_DT_PMCR				0x2100	/* rw */
#define		POR_DT_PMCR_OVFL_INTR_EN		(1 << 6)
#define		POR_DT_PMCR_CNTR_RST			(1 << 5)
#define		POR_DT_PMCR_CNTCFG_SHIFT		1
#define		POR_DT_PMCR_CNTCFG_MASK			(0xf << POR_DT_PMCR_CNTCFG_SHIFT)
#define		POR_DT_PMCR_PMU_EN			(1 << 0)
#define	POR_DT_PMOVSR				0x2118	/* ro */
#define	POR_DT_PMOVSR_CLR			0x2120	/* wo */
#define		POR_DT_PMOVSR_EVENT_COUNTERS	0xffUL
#define		POR_DT_PMOVSR_CYCLE_COUNTER		0x100UL
#define		POR_DT_PMOVSR_ALL			\
    (POR_DT_PMOVSR_EVENT_COUNTERS | POR_DT_PMOVSR_CYCLE_COUNTER)
#define	POR_DT_PMSSR				0x2128	/* ro */
#define	POR_DT_PMSRR				0x2130	/* wo */
#define	POR_DT_CLAIM				0x2da0	/* rw */
#define	POR_DT_DEVAFF				0x2da8	/* ro */
#define	POR_DT_LSR				0x2db0	/* ro */
#define	POR_DT_AUTHSTATUS_DEVARCH		0x2db8	/* ro */
#define	POR_DT_DEVID				0x2dc0	/* ro */
#define	POR_DT_DEVTYPE				0x2dc8	/* ro */
#define	POR_DT_PIDR45				0x2dd0	/* ro */
#define	POR_DT_PIDR67				0x2dd8	/* ro */
#define	POR_DT_PIDR01				0x2de0	/* ro */
#define	POR_DT_PIDR23				0x2de8	/* ro */
#define	POR_DT_CIDR01				0x2df0	/* ro */
#define	POR_DT_CIDR23				0x2df8	/* ro */

/* HN-F registers */
#define	POR_HNF_NODE_INFO			0x0000	/* ro */
#define	POR_HNF_CHILD_INFO			0x0080	/* ro */
#define	POR_HNF_SECURE_REGISTER_GROUPS_OVERRIDE	0x0980	/* rw */
#define	POR_HNF_UNIT_INFO			0x0900	/* ro */
#define	POR_HNF_CFG_CTL				0x0a00	/* rw */
#define	POR_HNF_AUX_CTL				0x0a08	/* rw */
#define	POR_HNF_R2_AUX_CTL			0x0a10	/* rw */
#define	POR_HNF_PPU_PWPR			0x1000	/* rw */
#define	POR_HNF_PPU_PWSR			0x1008	/* ro */
#define	POR_HNF_PPU_MISR			0x1014	/* ro */
#define	POR_HNF_PPU_IDR0			0x1fb0	/* ro */
#define	POR_HNF_PPU_IDR1			0x1fb4	/* ro */
#define	POR_HNF_PPU_IIDR			0x1fc8	/* ro */
#define	POR_HNF_PPU_AIDR			0x1fcc	/* ro */
#define	POR_HNF_PPU_DYN_RET_THRESHOLD		0x1100	/* rw */
#define	POR_HNF_QOS_BAND			0x0a80	/* ro */
#define	POR_HNF_QOS_RESERVATION			0x0a88	/* rw */
#define	POR_HNF_RN_STARVATION			0x0a90	/* rw */
#define	POR_HNF_ERRFR				0x3000	/* ro */
#define	POR_HNF_ERRCTLR				0x3008	/* rw */
#define	POR_HNF_ERRSTATUS			0x3010	/* w1c */
#define	POR_HNF_ERRADDR				0x3018	/* rw */
#define	POR_HNF_ERRMISC				0x3020	/* rw */
#define	POR_HNF_ERR_INJ				0x3030	/* rw */
#define	POR_HNF_BYTE_PAR_ERR_INJ		0x3038	/* wo */
#define	POR_HNF_ERRFR_NS			0x3100	/* ro */
#define	POR_HNF_ERRCTLR_NS			0x3108	/* rw */
#define	POR_HNF_ERRSTATUS_NS			0x3110	/* w1c */
#define	POR_HNF_ERRADDR_NS			0x3118	/* rw */
#define	POR_HNF_ERRMISC_NS			0x3120	/* rw */
#define	POR_HNF_SLC_LOCK_WAYS			0x0c00	/* rw */
#define	POR_HNF_SLC_LOCK_BASE0			0x0c08	/* rw */
#define	POR_HNF_SLC_LOCK_BASE1			0x0c10	/* rw */
#define	POR_HNF_SLC_LOCK_BASE2			0x0c18	/* rw */
#define	POR_HNF_SLC_LOCK_BASE3			0x0c20	/* rw */
#define	POR_HNF_RNF_REGION_VEC1			0x0c28	/* rw */
#define	POR_HNF_RNI_REGION_VEC			0x0c30	/* rw */
#define	POR_HNF_RNF_REGION_VEC			0x0c38	/* rw */
#define	POR_HNF_RND_REGION_VEC			0x0c40	/* rw */
#define	POR_HNF_SLCWAY_PARTITION0_RNF_VEC	0x0c48	/* rw */
#define	POR_HNF_SLCWAY_PARTITION1_RNF_VEC	0x0c50	/* rw */
#define	POR_HNF_SLCWAY_PARTITION2_RNF_VEC	0x0c58	/* rw */
#define	POR_HNF_SLCWAY_PARTITION3_RNF_VEC	0x0c60	/* rw */
#define	POR_HNF_SLCWAY_PARTITION0_RNF_VEC1	0x0cb0	/* rw */
#define	POR_HNF_SLCWAY_PARTITION1_RNF_VEC1	0x0cb8	/* rw */
#define	POR_HNF_SLCWAY_PARTITION2_RNF_VEC1	0x0cc0	/* rw */
#define	POR_HNF_SLCWAY_PARTITION3_RNF_VEC1	0x0cc8	/* rw */
#define	POR_HNF_SLCWAY_PARTITION0_RNI_VEC	0x0c68	/* rw */
#define	POR_HNF_SLCWAY_PARTITION1_RNI_VEC	0x0c70	/* rw */
#define	POR_HNF_SLCWAY_PARTITION2_RNI_VEC	0x0c78	/* rw */
#define	POR_HNF_SLCWAY_PARTITION3_RNI_VEC	0x0c80	/* rw */
#define	POR_HNF_SLCWAY_PARTITION0_RND_VEC	0x0c88	/* rw */
#define	POR_HNF_SLCWAY_PARTITION1_RND_VEC	0x0c90	/* rw */
#define	POR_HNF_SLCWAY_PARTITION2_RND_VEC	0x0c98	/* rw */
#define	POR_HNF_SLCWAY_PARTITION3_RND_VEC	0x0ca0	/* rw */
#define	POR_HNF_RN_REGION_LOCK			0x0ca8	/* rw */
#define	POR_HNF_SAM_CONTROL			0x0d00	/* rw */
#define	POR_HNF_SAM_MEMREGION0			0x0d08	/* rw */
#define	POR_HNF_SAM_MEMREGION1			0x0d10	/* rw */
#define	POR_HNF_SAM_SN_PROPERTIES		0x0d18	/* rw */
#define	POR_HNF_SAM_6SN_NODEID			0x0d20	/* rw */
#define	POR_HNF_RN_PHYS_ID(x)			(0x0d28 + 8 * (x)) /* rw */
#define	POR_HNF_RN_PHYS_ID63			0x0f90	/* rw */
#define	POR_HNF_SF_CXG_BLOCKED_WAYS		0x0f00	/* rw */
#define	POR_HNF_CML_PORT_AGGR_GRP0_ADD_MASK	0x0f10	/* rw */
#define	POR_HNF_CML_PORT_AGGR_GRP1_ADD_MASK	0x0f18	/* rw */
#define	POR_HNF_CML_PORT_AGGR_GRP0_REG		0x0f28	/* rw */
#define	POR_HNF_CML_PORT_AGGR_GRP1_REG		0x0f30	/* rw */
#define	HN_SAM_HASH_ADDR_MASK_REG		0x0f40	/* rw */
#define	HN_SAM_REGION_CMP_ADDR_MASK_REG		0x0f48	/* rw */
#define	POR_HNF_ABF_LO_ADDR			0x0f50	/* rw */
#define	POR_HNF_ABF_HI_ADDR			0x0f58	/* rw */
#define	POR_HNF_ABF_PR				0x0f60	/* rw */
#define	POR_HNF_ABF_SR				0x0f68	/* ro */
#define	POR_HNF_LDID_MAP_TABLE_REG0		0x0f98	/* rw */
#define	POR_HNF_LDID_MAP_TABLE_REG1		0x0fa0	/* rw */
#define	POR_HNF_LDID_MAP_TABLE_REG2		0x0fa8	/* rw */
#define	POR_HNF_LDID_MAP_TABLE_REG3		0x0fb0	/* rw */
#define	POR_HNF_CFG_SLCSF_DBGRD			0x0b80	/* wo */
#define	POR_HNF_SLC_CACHE_ACCESS_SLC_TAG	0x0b88	/* ro */
#define	POR_HNF_SLC_CACHE_ACCESS_SLC_DATA	0x0b90	/* ro */
#define	POR_HNF_SLC_CACHE_ACCESS_SF_TAG		0x0b98	/* ro */
#define	POR_HNF_SLC_CACHE_ACCESS_SF_TAG1	0x0ba0	/* ro */
#define	POR_HNF_SLC_CACHE_ACCESS_SF_TAG2	0x0ba8	/* ro */
#define	POR_HNF_PMU_EVENT_SEL			0x2000	/* rw */

/* HN-I registers */
#define	POR_HNI_NODE_INFO			0x0000	/* ro */
#define	POR_HNI_CHILD_INFO			0x0080	/* ro */
#define	POR_HNI_SECURE_REGISTER_GROUPS_OVERRIDE	0x0980	/* rw */
#define	POR_HNI_UNIT_INFO			0x0900	/* ro */
#define	POR_HNI_SAM_ADDRREGION0_CFG		0x0c00	/* rw */
#define	POR_HNI_SAM_ADDRREGION1_CFG		0x0c08	/* rw */
#define	POR_HNI_SAM_ADDRREGION2_CFG		0x0c10	/* rw */
#define	POR_HNI_SAM_ADDRREGION3_CFG		0x0c18	/* rw */
#define	POR_HNI_CFG_CTL				0x0a00	/* rw */
#define	POR_HNI_AUX_CTL				0x0a08	/* rw */
#define	POR_HNI_ERRFR				0x3000	/* ro */
#define	POR_HNI_ERRCTLR				0x3008	/* rw */
#define	POR_HNI_ERRSTATUS			0x3010	/* w1c */
#define	POR_HNI_ERRADDR				0x3018	/* rw */
#define	POR_HNI_ERRMISC				0x3020	/* rw */
#define	POR_HNI_ERRFR_NS			0x3100	/* ro */
#define	POR_HNI_ERRCTLR_NS			0x3108	/* rw */
#define	POR_HNI_ERRSTATUS_NS			0x3110	/* w1c */
#define	POR_HNI_ERRADDR_NS			0x3118	/* rw */
#define	POR_HNI_ERRMISC_NS			0x3120	/* rw */
#define	POR_HNI_PMU_EVENT_SEL			0x2000	/* rw */

/* XP registers */
#define	POR_MXP_NODE_INFO			0x0000	/* ro */
#define	POR_MXP_DEVICE_PORT_CONNECT_INFO_P0	0x0008	/* ro */
#define	POR_MXP_DEVICE_PORT_CONNECT_INFO_P1	0x0010	/* ro */
#define	POR_MXP_MESH_PORT_CONNECT_INFO_EAST	0x0018	/* ro */
#define	POR_MXP_MESH_PORT_CONNECT_INFO_NORTH	0x0020	/* ro */
#define	POR_MXP_CHILD_INFO			0x0080	/* ro */
#define	POR_MXP_CHILD_POINTER_0			0x0100	/* ro */
#define	POR_MXP_CHILD_POINTER_1			0x0108	/* ro */
#define	POR_MXP_CHILD_POINTER_2			0x0110	/* ro */
#define	POR_MXP_CHILD_POINTER_3			0x0118	/* ro */
#define	POR_MXP_CHILD_POINTER_4			0x0120	/* ro */
#define	POR_MXP_CHILD_POINTER_5			0x0128	/* ro */
#define	POR_MXP_CHILD_POINTER_6			0x0130	/* ro */
#define	POR_MXP_CHILD_POINTER_7			0x0138	/* ro */
#define	POR_MXP_CHILD_POINTER_8			0x0140	/* ro */
#define	POR_MXP_CHILD_POINTER_9			0x0148	/* ro */
#define	POR_MXP_CHILD_POINTER_10		0x0150	/* ro */
#define	POR_MXP_CHILD_POINTER_11		0x0158	/* ro */
#define	POR_MXP_CHILD_POINTER_12		0x0160	/* ro */
#define	POR_MXP_CHILD_POINTER_13		0x0168	/* ro */
#define	POR_MXP_CHILD_POINTER_14		0x0170	/* ro */
#define	POR_MXP_CHILD_POINTER_15		0x0178	/* ro */
#define	POR_MXP_P0_INFO				0x0900	/* ro */
#define	POR_MXP_P1_INFO				0x0908	/* ro */
#define		POR_MXP_PX_INFO_DEV_TYPE_RN_I			0x01
#define		POR_MXP_PX_INFO_DEV_TYPE_RN_D			0x02
#define		POR_MXP_PX_INFO_DEV_TYPE_RN_F_CHIB		0x04
#define		POR_MXP_PX_INFO_DEV_TYPE_RN_F_CHIB_ESAM		0x05
#define		POR_MXP_PX_INFO_DEV_TYPE_RN_F_CHIA		0x06
#define		POR_MXP_PX_INFO_DEV_TYPE_RN_F_CHIA_ESAM		0x07
#define		POR_MXP_PX_INFO_DEV_TYPE_HN_T			0x08
#define		POR_MXP_PX_INFO_DEV_TYPE_HN_I			0x09
#define		POR_MXP_PX_INFO_DEV_TYPE_HN_D			0x0a
#define		POR_MXP_PX_INFO_DEV_TYPE_SN_F			0x0c
#define		POR_MXP_PX_INFO_DEV_TYPE_SBSX			0x0d
#define		POR_MXP_PX_INFO_DEV_TYPE_HN_F			0x0e
#define		POR_MXP_PX_INFO_DEV_TYPE_CXHA			0x11
#define		POR_MXP_PX_INFO_DEV_TYPE_CXRA			0x12
#define		POR_MXP_PX_INFO_DEV_TYPE_CXRH			0x13

#define	POR_MXP_SECURE_REGISTER_GROUPS_OVERRIDE	0x0980	/* rw */
#define	POR_MXP_AUX_CTL				0x0a00	/* rw */
#define	POR_MXP_P0_QOS_CONTROL			0x0a80	/* rw */
#define	POR_MXP_P0_QOS_LAT_TGT			0x0a88	/* rw */
#define	POR_MXP_P0_QOS_LAT_SCALE		0x0a90	/* rw */
#define	POR_MXP_P0_QOS_LAT_RANGE		0x0a98	/* rw */
#define	POR_MXP_P1_QOS_CONTROL			0x0aa0	/* rw */
#define	POR_MXP_P1_QOS_LAT_TGT			0x0aa8	/* rw */
#define	POR_MXP_P1_QOS_LAT_SCALE		0x0ab0	/* rw */
#define	POR_MXP_P1_QOS_LAT_RANGE		0x0ab8	/* rw */
#define	POR_MXP_PMU_EVENT_SEL			0x2000	/* rw */

#define	POR_MXP_ERRFR				0x3000	/* ro */
#define	POR_MXP_ERRCTLR				0x3008	/* rw */
#define	POR_MXP_ERRSTATUS			0x3010	/* w1c */
#define	POR_MXP_ERRMISC				0x3028	/* rw */
#define	POR_MXP_P0_BYTE_PAR_ERR_INJ		0x3030	/* wo */
#define	POR_MXP_P1_BYTE_PAR_ERR_INJ		0x3038	/* wo */
#define	POR_MXP_ERRFR_NS			0x3100	/* ro */
#define	POR_MXP_ERRCTLR_NS			0x3108	/* rw */
#define	POR_MXP_ERRSTATUS_NS			0x3110	/* w1c */
#define	POR_MXP_ERRMISC_NS			0x3128	/* rw */
#define	POR_MXP_P0_SYSCOREQ_CTL			0x1000	/* rw */
#define	POR_MXP_P1_SYSCOREQ_CTL			0x1008	/* rw */
#define	POR_MXP_P0_SYSCOACK_STATUS		0x1010	/* ro */
#define	POR_MXP_P1_SYSCOACK_STATUS		0x1018	/* ro */
#define	POR_DTM_CONTROL				0x2100	/* rw */
#define		POR_DTM_CONTROL_TRACE_NO_ATB		(1 << 3)
#define		POR_DTM_CONTROL_SAMPLE_PROFILE_ENABLE	(1 << 2)
#define		POR_DTM_CONTROL_TRACE_TAG_ENABLE	(1 << 1)
#define		POR_DTM_CONTROL_DTM_ENABLE		(1 << 0)
#define	POR_DTM_FIFO_ENTRY_READY		0x2118	/* w1c */
#define	POR_DTM_FIFO_ENTRY0_0			0x2120	/* ro */
#define	POR_DTM_FIFO_ENTRY0_1			0x2128	/* ro */
#define	POR_DTM_FIFO_ENTRY0_2			0x2130	/* ro */
#define	POR_DTM_FIFO_ENTRY1_0			0x2138	/* ro */
#define	POR_DTM_FIFO_ENTRY1_1			0x2140	/* ro */
#define	POR_DTM_FIFO_ENTRY1_2			0x2148	/* ro */
#define	POR_DTM_FIFO_ENTRY2_0			0x2150	/* ro */
#define	POR_DTM_FIFO_ENTRY2_1			0x2158	/* ro */
#define	POR_DTM_FIFO_ENTRY2_2			0x2160	/* ro */
#define	POR_DTM_FIFO_ENTRY3_0			0x2168	/* ro */
#define	POR_DTM_FIFO_ENTRY3_1			0x2170	/* ro */
#define	POR_DTM_FIFO_ENTRY3_2			0x2178	/* ro */
#define	POR_DTM_WP0_CONFIG			0x21a0	/* rw */
#define	POR_DTM_WP0_VAL				0x21a8	/* rw */
#define	POR_DTM_WP0_MASK			0x21b0	/* rw */
#define	POR_DTM_WP1_CONFIG			0x21b8	/* rw */
#define	POR_DTM_WP1_VAL				0x21c0	/* rw */
#define	POR_DTM_WP1_MASK			0x21c8	/* rw */
#define	POR_DTM_WP2_CONFIG			0x21d0	/* rw */
#define	POR_DTM_WP2_VAL				0x21d8	/* rw */
#define	POR_DTM_WP2_MASK			0x21e0	/* rw */
#define	POR_DTM_WP3_CONFIG			0x21e8	/* rw */
#define	POR_DTM_WP3_VAL				0x21f0	/* rw */
#define	POR_DTM_WP3_MASK			0x21f8	/* rw */
#define	POR_DTM_PMSICR				0x2200	/* rw */
#define	POR_DTM_PMSIRR				0x2208	/* rw */
#define	POR_DTM_PMU_CONFIG			0x2210	/* rw */
#define		POR_DTM_PMU_CONFIG_PMU_EN		(1 << 0)
#define		POR_DTM_PMU_CONFIG_VCNT_INPUT_SEL_SHIFT	32
#define		POR_DTM_PMU_CONFIG_VCNT_INPUT_SEL_WIDTH	8
#define	POR_DTM_PMEVCNT				0x2220	/* rw */
#define		POR_DTM_PMEVCNT_CNTR_WIDTH	16
#define	POR_DTM_PMEVCNTSR			0x2240	/* rw */

/* RN-D registers */
#define	POR_RND_NODE_INFO			0x0000	/* ro */
#define	POR_RND_CHILD_INFO			0x0080	/* ro */
#define	POR_RND_SECURE_REGISTER_GROUPS_OVERRIDE	0x0980	/* rw */
#define	POR_RND_UNIT_INFO			0x0900	/* ro */
#define	POR_RND_CFG_CTL				0x0a00	/* rw */
#define	POR_RND_AUX_CTL				0x0a08	/* rw */
#define	POR_RND_S0_PORT_CONTROL			0x0a10	/* rw */
#define	POR_RND_S1_PORT_CONTROL			0x0a18	/* rw */
#define	POR_RND_S2_PORT_CONTROL			0x0a20	/* rw */
#define	POR_RND_S0_QOS_CONTROL			0x0a80	/* rw */
#define	POR_RND_S0_QOS_LAT_TGT			0x0a88	/* rw */
#define	POR_RND_S0_QOS_LAT_SCALE		0x0a90	/* rw */
#define	POR_RND_S0_QOS_LAT_RANGE		0x0a98	/* rw */
#define	POR_RND_S1_QOS_CONTROL			0x0aa0	/* rw */
#define	POR_RND_S1_QOS_LAT_TGT			0x0aa8	/* rw */
#define	POR_RND_S1_QOS_LAT_SCALE		0x0ab0	/* rw */
#define	POR_RND_S1_QOS_LAT_RANGE		0x0ab8	/* rw */
#define	POR_RND_S2_QOS_CONTROL			0x0ac0	/* rw */
#define	POR_RND_S2_QOS_LAT_TGT			0x0ac8	/* rw */
#define	POR_RND_S2_QOS_LAT_SCALE		0x0ad0	/* rw */
#define	POR_RND_S2_QOS_LAT_RANGE		0x0ad8	/* rw */
#define	POR_RND_PMU_EVENT_SEL			0x2000	/* rw */
#define	POR_RND_SYSCOREQ_CTL			0x1000	/* rw */
#define	POR_RND_SYSCOACK_STATUS			0x1008	/* ro */

/* RN-I registers */
#define	POR_RNI_NODE_INFO			0x0000	/* ro */
#define	POR_RNI_CHILD_INFO			0x0080	/* ro */
#define	POR_RNI_SECURE_REGISTER_GROUPS_OVERRIDE	0x0980	/* rw */
#define	POR_RNI_UNIT_INFO			0x0900	/* ro */
#define	POR_RNI_CFG_CTL				0x0a00	/* rw */
#define	POR_RNI_AUX_CTL				0x0a08	/* rw */
#define	POR_RNI_S0_PORT_CONTROL			0x0a10	/* rw */
#define	POR_RNI_S1_PORT_CONTROL			0x0a18	/* rw */
#define	POR_RNI_S2_PORT_CONTROL			0x0a20	/* rw */
#define	POR_RNI_S0_QOS_CONTROL			0x0a80	/* rw */
#define	POR_RNI_S0_QOS_LAT_TGT			0x0a88	/* rw */
#define	POR_RNI_S0_QOS_LAT_SCALE		0x0a90	/* rw */
#define	POR_RNI_S0_QOS_LAT_RANGE		0x0a98	/* rw */
#define	POR_RNI_S1_QOS_CONTROL			0x0aa0	/* rw */
#define	POR_RNI_S1_QOS_LAT_TGT			0x0aa8	/* rw */
#define	POR_RNI_S1_QOS_LAT_SCALE		0x0ab0	/* rw */
#define	POR_RNI_S1_QOS_LAT_RANGE		0x0ab8	/* rw */
#define	POR_RNI_S2_QOS_CONTROL			0x0ac0	/* rw */
#define	POR_RNI_S2_QOS_LAT_TGT			0x0ac8	/* rw */
#define	POR_RNI_S2_QOS_LAT_SCALE		0x0ad0	/* rw */
#define	POR_RNI_S2_QOS_LAT_RANGE		0x0ad8	/* rw */
#define	POR_RNI_PMU_EVENT_SEL			0x2000	/* rw */

/* RN SAM registers */
#define	POR_RNSAM_NODE_INFO			0x0000	/* ro */
#define	POR_RNSAM_CHILD_INFO			0x0080	/* ro */
#define	POR_RNSAM_SECURE_REGISTER_GROUPS_OVERRIDE 0x0980 /* rw */
#define	POR_RNSAM_UNIT_INFO			0x0900	/* ro */
#define	RNSAM_STATUS				0x0c00	/* rw */
#define	NON_HASH_MEM_REGION_REG0		0x0c08	/* rw */
#define	NON_HASH_MEM_REGION_REG1		0x0c10	/* rw */
#define	NON_HASH_MEM_REGION_REG2		0x0c18	/* rw */
#define	NON_HASH_MEM_REGION_REG3		0x0c20	/* rw */
#define	NON_HASH_TGT_NODEID0			0x0c30	/* rw */
#define	NON_HASH_TGT_NODEID1			0x0c38	/* rw */
#define	NON_HASH_TGT_NODEID2			0x0c40	/* rw */
#define	SYS_CACHE_GRP_REGION0			0x0c48	/* rw */
#define	SYS_CACHE_GRP_REGION1			0x0c50	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG0		0x0c58	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG1		0x0c60	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG2		0x0c68	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG3		0x0c70	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG4		0x0c78	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG5		0x0c80	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG6		0x0c88	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG7		0x0c90	/* rw */
#define	SYS_CACHE_GRP_NONHASH_NODEID		0x0c98	/* rw */
#define	SYS_CACHE_GROUP_HN_COUNT		0x0d00	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG0		0x0d08	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG1		0x0d10	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG2		0x0d18	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG3		0x0d20	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG4		0x0d28	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG5		0x0d30	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG6		0x0d38	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG7		0x0d40	/* rw */
#define	SYS_CACHE_GRP_SN_SAM_CFG0		0x0d48	/* rw */
#define	SYS_CACHE_GRP_SN_SAM_CFG1		0x0d50	/* rw */
#define	GIC_MEM_REGION_REG			0x0d58	/* rw */
#define	SYS_CACHE_GRP_SN_ATTR			0x0d60	/* rw */
#define	SYS_CACHE_GRP_HN_CPA_EN_REG		0x0d68	/* rw */
#define	SYS_CACHE_GRP_HN_CPA_GRP_REG		0x0d70	/* rw */
#define	CML_PORT_AGGR_MODE_CTRL_REG		0x0e00	/* rw */
#define	CML_PORT_AGGR_GRP0_ADD_MASK		0x0e08	/* rw */
#define	CML_PORT_AGGR_GRP1_ADD_MASK		0x0e10	/* rw */
#define	CML_PORT_AGGR_GRP0_REG			0x0e40	/* rw */
#define	CML_PORT_AGGR_GRP1_REG			0x0e48	/* rw */
#define	SYS_CACHE_GRP_SECONDARY_REG0		0x0f00	/* rw */
#define	SYS_CACHE_GRP_SECONDARY_REG1		0x0f08	/* rw */
#define	SYS_CACHE_GRP_CAL_MODE_REG		0x0f10	/* rw */
#define	RNSAM_HASH_ADDR_MASK_REG		0x0f18	/* rw */
#define	RNSAM_REGION_CMP_ADDR_MASK_REG		0x0f20	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG8		0x0f58	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG9		0x0f60	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG10		0x0f68	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG11		0x0f70	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG12		0x0f78	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG13		0x0f80	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG14		0x0f88	/* rw */
#define	SYS_CACHE_GRP_HN_NODEID_REG15		0x0f90	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG8		0x1008	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG9		0x1010	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG10		0x1018	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG11		0x1020	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG12		0x1028	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG13		0x1030	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG14		0x1038	/* rw */
#define	SYS_CACHE_GRP_SN_NODEID_REG15		0x1040	/* rw */

/* SBSX registers */
#define	POR_SBSX_NODE_INFO			0x0000	/* ro */
#define	POR_SBSX_CHILD_INFO			0x0080	/* ro */
#define	POR_SBSX_UNIT_INFO			0x0900	/* ro */
#define	POR_SBSX_AUX_CTL			0x0a08	/* rw */
#define	POR_SBSX_ERRFR				0x3000	/* ro */
#define	POR_SBSX_ERRCTLR			0x3008	/* rw */
#define	POR_SBSX_ERRSTATUS			0x3010	/* w1c */
#define	POR_SBSX_ERRADDR			0x3018	/* rw */
#define	POR_SBSX_ERRMISC			0x3020	/* rw */
#define	POR_SBSX_ERRFR_NS			0x3100	/* ro */
#define	POR_SBSX_ERRCTLR_NS			0x3108	/* rw */
#define	POR_SBSX_ERRSTATUS_NS			0x3110	/* w1c */
#define	POR_SBSX_ERRADDR_NS			0x3118	/* rw */
#define	POR_SBSX_ERRMISC_NS			0x3120	/* rw */
#define	POR_SBSX_PMU_EVENT_SEL			0x2000	/* rw */

/* CXHA registers */
#define	POR_CXG_HA_NODE_INFO			0x0000	/* ro */
#define	POR_CXG_HA_ID				0x0008	/* rw */
#define	POR_CXG_HA_CHILD_INFO			0x0080	/* ro */
#define	POR_CXG_HA_AUX_CTL			0x0a08	/* rw */
#define	POR_CXG_HA_SECURE_REGISTER_GROUPS_OVERRIDE 0x0980 /* rw */
#define	POR_CXG_HA_UNIT_INFO			0x0900	/* ro */
#define	POR_CXG_HA_RNF_RAID_TO_LDID_REG0	0x0c00	/* rw */
#define	POR_CXG_HA_RNF_RAID_TO_LDID_REG1	0x0c08	/* rw */
#define	POR_CXG_HA_RNF_RAID_TO_LDID_REG2	0x0c10	/* rw */
#define	POR_CXG_HA_RNF_RAID_TO_LDID_REG3	0x0c18	/* rw */
#define	POR_CXG_HA_RNF_RAID_TO_LDID_REG4	0x0c20	/* rw */
#define	POR_CXG_HA_RNF_RAID_TO_LDID_REG5	0x0c28	/* rw */
#define	POR_CXG_HA_RNF_RAID_TO_LDID_REG6	0x0c30	/* rw */
#define	POR_CXG_HA_RNF_RAID_TO_LDID_REG7	0x0c38	/* rw */
#define	POR_CXG_HA_AGENTID_TO_LINKID_REG0	0x0c40	/* rw */
#define	POR_CXG_HA_AGENTID_TO_LINKID_REG1	0x0c48	/* rw */
#define	POR_CXG_HA_AGENTID_TO_LINKID_REG2	0x0c50	/* rw */
#define	POR_CXG_HA_AGENTID_TO_LINKID_REG3	0x0c58	/* rw */
#define	POR_CXG_HA_AGENTID_TO_LINKID_REG4	0x0c60	/* rw */
#define	POR_CXG_HA_AGENTID_TO_LINKID_REG5	0x0c68	/* rw */
#define	POR_CXG_HA_AGENTID_TO_LINKID_REG6	0x0c70	/* rw */
#define	POR_CXG_HA_AGENTID_TO_LINKID_REG7	0x0c78	/* rw */
#define	POR_CXG_HA_AGENTID_TO_LINKID_VAL	0x0d00	/* rw */
#define	POR_CXG_HA_RNF_RAID_TO_LDID_VAL		0x0d08	/* rw */
#define	POR_CXG_HA_PMU_EVENT_SEL		0x2000	/* rw */
#define		POR_CXG_HA_PMU_EVENT_SEL_EVENT_ID3_SHIFT	24
#define		POR_CXG_HA_PMU_EVENT_SEL_EVENT_ID3_MASK		(0x3f << 24)
#define		POR_CXG_HA_PMU_EVENT_SEL_EVENT_ID2_SHIFT	16
#define		POR_CXG_HA_PMU_EVENT_SEL_EVENT_ID2_MASK		(0x3f << 16)
#define		POR_CXG_HA_PMU_EVENT_SEL_EVENT_ID1_SHIFT	8
#define		POR_CXG_HA_PMU_EVENT_SEL_EVENT_ID1_MASK		(0x3f << 8)
#define		POR_CXG_HA_PMU_EVENT_SEL_EVENT_ID0_SHIFT	0
#define		POR_CXG_HA_PMU_EVENT_SEL_EVENT_ID0_MASK		0x3f

#define	POR_CXG_HA_CXPRTCL_LINK0_CTL		0x1000	/* rw */
#define	POR_CXG_HA_CXPRTCL_LINK0_STATUS		0x1008	/* ro */
#define	POR_CXG_HA_CXPRTCL_LINK1_CTL		0x1010	/* rw */
#define	POR_CXG_HA_CXPRTCL_LINK1_STATUS		0x1018	/* ro */
#define	POR_CXG_HA_CXPRTCL_LINK2_CTL		0x1020	/* rw */
#define	POR_CXG_HA_CXPRTCL_LINK2_STATUS		0x1028	/* ro */
#define	POR_CXG_HA_ERRFR			0x3000	/* ro */
#define	POR_CXG_HA_ERRCTLR			0x3008	/* rw */
#define	POR_CXG_HA_ERRSTATUS			0x3010	/* w1c */
#define	POR_CXG_HA_ERRADDR			0x3018	/* rw */
#define	POR_CXG_HA_ERRMISC			0x3020	/* rw */
#define	POR_CXG_HA_ERRFR_NS			0x3100	/* ro */
#define	POR_CXG_HA_ERRCTLR_NS			0x3108	/* rw */
#define	POR_CXG_HA_ERRSTATUS_NS			0x3110	/* w1c */
#define	POR_CXG_HA_ERRADDR_NS			0x3118	/* rw */
#define	POR_CXG_HA_ERRMISC_NS			0x3120	/* rw */

/* CXRA registers */
#define	POR_CXG_RA_NODE_INFO			0x0000	/* ro */
#define	POR_CXG_RA_CHILD_INFO			0x0080	/* ro */
#define	POR_CXG_RA_SECURE_REGISTER_GROUPS_OVERRIDE 0x0980 /* rw */
#define	POR_CXG_RA_UNIT_INFO			0x0900	/* ro */
#define	POR_CXG_RA_CFG_CTL			0x0a00	/* rw */
#define		EN_CXLA_PMUCMD_PROP			(1 << 8)
#define	POR_CXG_RA_AUX_CTL			0x0a08	/* rw */
#define	POR_CXG_RA_SAM_ADDR_REGION_REG0		0x0da8	/* rw */
#define	POR_CXG_RA_SAM_ADDR_REGION_REG1		0x0db0	/* rw */
#define	POR_CXG_RA_SAM_ADDR_REGION_REG2		0x0db8	/* rw */
#define	POR_CXG_RA_SAM_ADDR_REGION_REG3		0x0dc0	/* rw */
#define	POR_CXG_RA_SAM_ADDR_REGION_REG4		0x0dc8	/* rw */
#define	POR_CXG_RA_SAM_ADDR_REGION_REG5		0x0dd0	/* rw */
#define	POR_CXG_RA_SAM_ADDR_REGION_REG6		0x0dd8	/* rw */
#define	POR_CXG_RA_SAM_ADDR_REGION_REG7		0x0de0	/* rw */
#define	POR_CXG_RA_SAM_MEM_REGION0_LIMIT_REG	0x0e00	/* rw */
#define	POR_CXG_RA_SAM_MEM_REGION1_LIMIT_REG	0x0e08	/* rw */
#define	POR_CXG_RA_SAM_MEM_REGION2_LIMIT_REG	0x0e10	/* rw */
#define	POR_CXG_RA_SAM_MEM_REGION3_LIMIT_REG	0x0e18	/* rw */
#define	POR_CXG_RA_SAM_MEM_REGION4_LIMIT_REG	0x0e20	/* rw */
#define	POR_CXG_RA_SAM_MEM_REGION5_LIMIT_REG	0x0e28	/* rw */
#define	POR_CXG_RA_SAM_MEM_REGION6_LIMIT_REG	0x0e30	/* rw */
#define	POR_CXG_RA_SAM_MEM_REGION7_LIMIT_REG	0x0e38	/* rw */
#define	POR_CXG_RA_AGENTID_TO_LINKID_REG0	0x0e60	/* rw */
#define	POR_CXG_RA_AGENTID_TO_LINKID_REG1	0x0e68	/* rw */
#define	POR_CXG_RA_AGENTID_TO_LINKID_REG2	0x0e70	/* rw */
#define	POR_CXG_RA_AGENTID_TO_LINKID_REG3	0x0e78	/* rw */
#define	POR_CXG_RA_AGENTID_TO_LINKID_REG4	0x0e80	/* rw */
#define	POR_CXG_RA_AGENTID_TO_LINKID_REG5	0x0e88	/* rw */
#define	POR_CXG_RA_AGENTID_TO_LINKID_REG6	0x0e90	/* rw */
#define	POR_CXG_RA_AGENTID_TO_LINKID_REG7	0x0e98	/* rw */
#define	POR_CXG_RA_RNF_LDID_TO_RAID_REG0	0x0ea0	/* rw */
#define	POR_CXG_RA_RNF_LDID_TO_RAID_REG1	0x0ea8	/* rw */
#define	POR_CXG_RA_RNF_LDID_TO_RAID_REG2	0x0eb0	/* rw */
#define	POR_CXG_RA_RNF_LDID_TO_RAID_REG3	0x0eb8	/* rw */
#define	POR_CXG_RA_RNF_LDID_TO_RAID_REG4	0x0ec0	/* rw */
#define	POR_CXG_RA_RNF_LDID_TO_RAID_REG5	0x0ec8	/* rw */
#define	POR_CXG_RA_RNF_LDID_TO_RAID_REG6	0x0ed0	/* rw */
#define	POR_CXG_RA_RNF_LDID_TO_RAID_REG7	0x0ed8	/* rw */
#define	POR_CXG_RA_RNI_LDID_TO_RAID_REG0	0x0ee0	/* rw */
#define	POR_CXG_RA_RNI_LDID_TO_RAID_REG1	0x0ee8	/* rw */
#define	POR_CXG_RA_RNI_LDID_TO_RAID_REG2	0x0ef0	/* rw */
#define	POR_CXG_RA_RNI_LDID_TO_RAID_REG3	0x0ef8	/* rw */
#define	POR_CXG_RA_RND_LDID_TO_RAID_REG0	0x0f00	/* rw */
#define	POR_CXG_RA_RND_LDID_TO_RAID_REG1	0x0f08	/* rw */
#define	POR_CXG_RA_RND_LDID_TO_RAID_REG2	0x0f10	/* rw */
#define	POR_CXG_RA_RND_LDID_TO_RAID_REG3	0x0f18	/* rw */
#define	POR_CXG_RA_AGENTID_TO_LINKID_VAL	0x0f20	/* rw */
#define	POR_CXG_RA_RNF_LDID_TO_RAID_VAL		0x0f28	/* rw */
#define	POR_CXG_RA_RNI_LDID_TO_RAID_VAL		0x0f30	/* rw */
#define	POR_CXG_RA_RND_LDID_TO_RAID_VAL		0x0f38	/* rw */
#define	POR_CXG_RA_PMU_EVENT_SEL		0x2000	/* rw */
#define	POR_CXG_RA_CXPRTCL_LINK0_CTL		0x1000	/* rw */
#define	POR_CXG_RA_CXPRTCL_LINK0_STATUS		0x1008	/* ro */
#define	POR_CXG_RA_CXPRTCL_LINK1_CTL		0x1010	/* rw */
#define	POR_CXG_RA_CXPRTCL_LINK1_STATUS		0x1018	/* ro */
#define	POR_CXG_RA_CXPRTCL_LINK2_CTL		0x1020	/* rw */
#define	POR_CXG_RA_CXPRTCL_LINK2_STATUS		0x1028	/* ro */

/* CXLA registers */
#define	POR_CXLA_NODE_INFO			0x0000	/* ro */
#define	POR_CXLA_CHILD_INFO			0x0080	/* ro */
#define	POR_CXLA_SECURE_REGISTER_GROUPS_OVERRIDE 0x0980	/* rw */
#define	POR_CXLA_UNIT_INFO			0x0900	/* ro */
#define	POR_CXLA_AUX_CTL			0x0a08	/* rw */
#define	POR_CXLA_CCIX_PROP_CAPABILITIES		0x0c00	/* ro */
#define	POR_CXLA_CCIX_PROP_CONFIGURED		0x0c08	/* rw */
#define	POR_CXLA_TX_CXS_ATTR_CAPABILITIES	0x0c10	/* ro */
#define	POR_CXLA_RX_CXS_ATTR_CAPABILITIES	0x0c18	/* ro */
#define	POR_CXLA_AGENTID_TO_LINKID_REG0		0x0c30	/* rw */
#define	POR_CXLA_AGENTID_TO_LINKID_REG1		0x0c38	/* rw */
#define	POR_CXLA_AGENTID_TO_LINKID_REG2		0x0c40	/* rw */
#define	POR_CXLA_AGENTID_TO_LINKID_REG3		0x0c48	/* rw */
#define	POR_CXLA_AGENTID_TO_LINKID_REG4		0x0c50	/* rw */
#define	POR_CXLA_AGENTID_TO_LINKID_REG5		0x0c58	/* rw */
#define	POR_CXLA_AGENTID_TO_LINKID_REG6		0x0c60	/* rw */
#define	POR_CXLA_AGENTID_TO_LINKID_REG7		0x0c68	/* rw */
#define	POR_CXLA_AGENTID_TO_LINKID_VAL		0x0c70	/* rw */
#define	POR_CXLA_LINKID_TO_PCIE_BUS_NUM		0x0c78	/* rw */
#define	POR_CXLA_PERMSG_PYLD_0_63		0x0d00	/* rw */
#define	POR_CXLA_PERMSG_PYLD_64_127		0x0d08	/* rw */
#define	POR_CXLA_PERMSG_PYLD_128_191		0x0d10	/* rw */
#define	POR_CXLA_PERMSG_PYLD_192_255		0x0d18	/* rw */
#define	POR_CXLA_PERMSG_CTL			0x0d20	/* rw */
#define	POR_CXLA_ERR_AGENT_ID			0x0d28	/* rw */
#define	POR_CXLA_PMU_EVENT_SEL			0x2000	/* rw */
#define	POR_CXLA_PMU_CONFIG			0x2210	/* rw */
#define	POR_CXLA_PMEVCNT			0x2220	/* rw */
#define	POR_CXLA_PMEVCNTSR			0x2240	/* rw */

#endif	/* _MACHINE_CMN600_REG_H_ */