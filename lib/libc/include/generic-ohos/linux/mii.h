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
#ifndef _UAPI__LINUX_MII_H__
#define _UAPI__LINUX_MII_H__
#include <linux/types.h>
#include <linux/ethtool.h>
#define MII_BMCR 0x00
#define MII_BMSR 0x01
#define MII_PHYSID1 0x02
#define MII_PHYSID2 0x03
#define MII_ADVERTISE 0x04
#define MII_LPA 0x05
#define MII_EXPANSION 0x06
#define MII_CTRL1000 0x09
#define MII_STAT1000 0x0a
#define MII_MMD_CTRL 0x0d
#define MII_MMD_DATA 0x0e
#define MII_ESTATUS 0x0f
#define MII_DCOUNTER 0x12
#define MII_FCSCOUNTER 0x13
#define MII_NWAYTEST 0x14
#define MII_RERRCOUNTER 0x15
#define MII_SREVISION 0x16
#define MII_RESV1 0x17
#define MII_LBRERROR 0x18
#define MII_PHYADDR 0x19
#define MII_RESV2 0x1a
#define MII_TPISTATUS 0x1b
#define MII_NCONFIG 0x1c
#define BMCR_RESV 0x003f
#define BMCR_SPEED1000 0x0040
#define BMCR_CTST 0x0080
#define BMCR_FULLDPLX 0x0100
#define BMCR_ANRESTART 0x0200
#define BMCR_ISOLATE 0x0400
#define BMCR_PDOWN 0x0800
#define BMCR_ANENABLE 0x1000
#define BMCR_SPEED100 0x2000
#define BMCR_LOOPBACK 0x4000
#define BMCR_RESET 0x8000
#define BMCR_SPEED10 0x0000
#define BMSR_ERCAP 0x0001
#define BMSR_JCD 0x0002
#define BMSR_LSTATUS 0x0004
#define BMSR_ANEGCAPABLE 0x0008
#define BMSR_RFAULT 0x0010
#define BMSR_ANEGCOMPLETE 0x0020
#define BMSR_RESV 0x00c0
#define BMSR_ESTATEN 0x0100
#define BMSR_100HALF2 0x0200
#define BMSR_100FULL2 0x0400
#define BMSR_10HALF 0x0800
#define BMSR_10FULL 0x1000
#define BMSR_100HALF 0x2000
#define BMSR_100FULL 0x4000
#define BMSR_100BASE4 0x8000
#define ADVERTISE_SLCT 0x001f
#define ADVERTISE_CSMA 0x0001
#define ADVERTISE_10HALF 0x0020
#define ADVERTISE_1000XFULL 0x0020
#define ADVERTISE_10FULL 0x0040
#define ADVERTISE_1000XHALF 0x0040
#define ADVERTISE_100HALF 0x0080
#define ADVERTISE_1000XPAUSE 0x0080
#define ADVERTISE_100FULL 0x0100
#define ADVERTISE_1000XPSE_ASYM 0x0100
#define ADVERTISE_100BASE4 0x0200
#define ADVERTISE_PAUSE_CAP 0x0400
#define ADVERTISE_PAUSE_ASYM 0x0800
#define ADVERTISE_RESV 0x1000
#define ADVERTISE_RFAULT 0x2000
#define ADVERTISE_LPACK 0x4000
#define ADVERTISE_NPAGE 0x8000
#define ADVERTISE_FULL (ADVERTISE_100FULL | ADVERTISE_10FULL | ADVERTISE_CSMA)
#define ADVERTISE_ALL (ADVERTISE_10HALF | ADVERTISE_10FULL | ADVERTISE_100HALF | ADVERTISE_100FULL)
#define LPA_SLCT 0x001f
#define LPA_10HALF 0x0020
#define LPA_1000XFULL 0x0020
#define LPA_10FULL 0x0040
#define LPA_1000XHALF 0x0040
#define LPA_100HALF 0x0080
#define LPA_1000XPAUSE 0x0080
#define LPA_100FULL 0x0100
#define LPA_1000XPAUSE_ASYM 0x0100
#define LPA_100BASE4 0x0200
#define LPA_PAUSE_CAP 0x0400
#define LPA_PAUSE_ASYM 0x0800
#define LPA_RESV 0x1000
#define LPA_RFAULT 0x2000
#define LPA_LPACK 0x4000
#define LPA_NPAGE 0x8000
#define LPA_DUPLEX (LPA_10FULL | LPA_100FULL)
#define LPA_100 (LPA_100FULL | LPA_100HALF | LPA_100BASE4)
#define EXPANSION_NWAY 0x0001
#define EXPANSION_LCWP 0x0002
#define EXPANSION_ENABLENPAGE 0x0004
#define EXPANSION_NPCAPABLE 0x0008
#define EXPANSION_MFAULTS 0x0010
#define EXPANSION_RESV 0xffe0
#define ESTATUS_1000_XFULL 0x8000
#define ESTATUS_1000_XHALF 0x4000
#define ESTATUS_1000_TFULL 0x2000
#define ESTATUS_1000_THALF 0x1000
#define NWAYTEST_RESV1 0x00ff
#define NWAYTEST_LOOPBACK 0x0100
#define NWAYTEST_RESV2 0xfe00
#define ADVERTISE_SGMII 0x0001
#define LPA_SGMII 0x0001
#define LPA_SGMII_SPD_MASK 0x0c00
#define LPA_SGMII_FULL_DUPLEX 0x1000
#define LPA_SGMII_DPX_SPD_MASK 0x1C00
#define LPA_SGMII_10 0x0000
#define LPA_SGMII_10HALF 0x0000
#define LPA_SGMII_10FULL 0x1000
#define LPA_SGMII_100 0x0400
#define LPA_SGMII_100HALF 0x0400
#define LPA_SGMII_100FULL 0x1400
#define LPA_SGMII_1000 0x0800
#define LPA_SGMII_1000HALF 0x0800
#define LPA_SGMII_1000FULL 0x1800
#define LPA_SGMII_LINK 0x8000
#define ADVERTISE_1000FULL 0x0200
#define ADVERTISE_1000HALF 0x0100
#define CTL1000_PREFER_MASTER 0x0400
#define CTL1000_AS_MASTER 0x0800
#define CTL1000_ENABLE_MASTER 0x1000
#define LPA_1000MSFAIL 0x8000
#define LPA_1000MSRES 0x4000
#define LPA_1000LOCALRXOK 0x2000
#define LPA_1000REMRXOK 0x1000
#define LPA_1000FULL 0x0800
#define LPA_1000HALF 0x0400
#define FLOW_CTRL_TX 0x01
#define FLOW_CTRL_RX 0x02
#define MII_MMD_CTRL_DEVAD_MASK 0x1f
#define MII_MMD_CTRL_ADDR 0x0000
#define MII_MMD_CTRL_NOINCR 0x4000
#define MII_MMD_CTRL_INCR_RDWT 0x8000
#define MII_MMD_CTRL_INCR_ON_WT 0xC000
struct mii_ioctl_data {
  __u16 phy_id;
  __u16 reg_num;
  __u16 val_in;
  __u16 val_out;
};
#endif