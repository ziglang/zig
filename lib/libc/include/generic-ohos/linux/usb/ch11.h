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
#ifndef __LINUX_CH11_H
#define __LINUX_CH11_H
#include <linux/types.h>
#define USB_MAXCHILDREN 31
#define USB_SS_MAXPORTS 15
#define USB_RT_HUB (USB_TYPE_CLASS | USB_RECIP_DEVICE)
#define USB_RT_PORT (USB_TYPE_CLASS | USB_RECIP_OTHER)
#define HUB_PORT_STATUS 0
#define HUB_PORT_PD_STATUS 1
#define HUB_EXT_PORT_STATUS 2
#define HUB_CLEAR_TT_BUFFER 8
#define HUB_RESET_TT 9
#define HUB_GET_TT_STATE 10
#define HUB_STOP_TT 11
#define HUB_SET_DEPTH 12
#define HUB_GET_PORT_ERR_COUNT 13
#define C_HUB_LOCAL_POWER 0
#define C_HUB_OVER_CURRENT 1
#define USB_PORT_FEAT_CONNECTION 0
#define USB_PORT_FEAT_ENABLE 1
#define USB_PORT_FEAT_SUSPEND 2
#define USB_PORT_FEAT_OVER_CURRENT 3
#define USB_PORT_FEAT_RESET 4
#define USB_PORT_FEAT_L1 5
#define USB_PORT_FEAT_POWER 8
#define USB_PORT_FEAT_LOWSPEED 9
#define USB_PORT_FEAT_C_CONNECTION 16
#define USB_PORT_FEAT_C_ENABLE 17
#define USB_PORT_FEAT_C_SUSPEND 18
#define USB_PORT_FEAT_C_OVER_CURRENT 19
#define USB_PORT_FEAT_C_RESET 20
#define USB_PORT_FEAT_TEST 21
#define USB_PORT_FEAT_INDICATOR 22
#define USB_PORT_FEAT_C_PORT_L1 23
#define USB_PORT_FEAT_LINK_STATE 5
#define USB_PORT_FEAT_U1_TIMEOUT 23
#define USB_PORT_FEAT_U2_TIMEOUT 24
#define USB_PORT_FEAT_C_PORT_LINK_STATE 25
#define USB_PORT_FEAT_C_PORT_CONFIG_ERROR 26
#define USB_PORT_FEAT_REMOTE_WAKE_MASK 27
#define USB_PORT_FEAT_BH_PORT_RESET 28
#define USB_PORT_FEAT_C_BH_PORT_RESET 29
#define USB_PORT_FEAT_FORCE_LINKPM_ACCEPT 30
#define USB_PORT_LPM_TIMEOUT(p) (((p) & 0xff) << 8)
#define USB_PORT_FEAT_REMOTE_WAKE_CONNECT (1 << 8)
#define USB_PORT_FEAT_REMOTE_WAKE_DISCONNECT (1 << 9)
#define USB_PORT_FEAT_REMOTE_WAKE_OVER_CURRENT (1 << 10)
struct usb_port_status {
  __le16 wPortStatus;
  __le16 wPortChange;
  __le32 dwExtPortStatus;
} __attribute__((packed));
#define USB_PORT_STAT_CONNECTION 0x0001
#define USB_PORT_STAT_ENABLE 0x0002
#define USB_PORT_STAT_SUSPEND 0x0004
#define USB_PORT_STAT_OVERCURRENT 0x0008
#define USB_PORT_STAT_RESET 0x0010
#define USB_PORT_STAT_L1 0x0020
#define USB_PORT_STAT_POWER 0x0100
#define USB_PORT_STAT_LOW_SPEED 0x0200
#define USB_PORT_STAT_HIGH_SPEED 0x0400
#define USB_PORT_STAT_TEST 0x0800
#define USB_PORT_STAT_INDICATOR 0x1000
#define USB_PORT_STAT_LINK_STATE 0x01e0
#define USB_SS_PORT_STAT_POWER 0x0200
#define USB_SS_PORT_STAT_SPEED 0x1c00
#define USB_PORT_STAT_SPEED_5GBPS 0x0000
#define USB_SS_PORT_STAT_MASK (USB_PORT_STAT_CONNECTION | USB_PORT_STAT_ENABLE | USB_PORT_STAT_OVERCURRENT | USB_PORT_STAT_RESET)
#define USB_SS_PORT_LS_U0 0x0000
#define USB_SS_PORT_LS_U1 0x0020
#define USB_SS_PORT_LS_U2 0x0040
#define USB_SS_PORT_LS_U3 0x0060
#define USB_SS_PORT_LS_SS_DISABLED 0x0080
#define USB_SS_PORT_LS_RX_DETECT 0x00a0
#define USB_SS_PORT_LS_SS_INACTIVE 0x00c0
#define USB_SS_PORT_LS_POLLING 0x00e0
#define USB_SS_PORT_LS_RECOVERY 0x0100
#define USB_SS_PORT_LS_HOT_RESET 0x0120
#define USB_SS_PORT_LS_COMP_MOD 0x0140
#define USB_SS_PORT_LS_LOOPBACK 0x0160
#define USB_PORT_STAT_C_CONNECTION 0x0001
#define USB_PORT_STAT_C_ENABLE 0x0002
#define USB_PORT_STAT_C_SUSPEND 0x0004
#define USB_PORT_STAT_C_OVERCURRENT 0x0008
#define USB_PORT_STAT_C_RESET 0x0010
#define USB_PORT_STAT_C_L1 0x0020
#define USB_PORT_STAT_C_BH_RESET 0x0020
#define USB_PORT_STAT_C_LINK_STATE 0x0040
#define USB_PORT_STAT_C_CONFIG_ERROR 0x0080
#define USB_EXT_PORT_STAT_RX_SPEED_ID 0x0000000f
#define USB_EXT_PORT_STAT_TX_SPEED_ID 0x000000f0
#define USB_EXT_PORT_STAT_RX_LANES 0x00000f00
#define USB_EXT_PORT_STAT_TX_LANES 0x0000f000
#define USB_EXT_PORT_RX_LANES(p) (((p) & USB_EXT_PORT_STAT_RX_LANES) >> 8)
#define USB_EXT_PORT_TX_LANES(p) (((p) & USB_EXT_PORT_STAT_TX_LANES) >> 12)
#define HUB_CHAR_LPSM 0x0003
#define HUB_CHAR_COMMON_LPSM 0x0000
#define HUB_CHAR_INDV_PORT_LPSM 0x0001
#define HUB_CHAR_NO_LPSM 0x0002
#define HUB_CHAR_COMPOUND 0x0004
#define HUB_CHAR_OCPM 0x0018
#define HUB_CHAR_COMMON_OCPM 0x0000
#define HUB_CHAR_INDV_PORT_OCPM 0x0008
#define HUB_CHAR_NO_OCPM 0x0010
#define HUB_CHAR_TTTT 0x0060
#define HUB_CHAR_PORTIND 0x0080
struct usb_hub_status {
  __le16 wHubStatus;
  __le16 wHubChange;
} __attribute__((packed));
#define HUB_STATUS_LOCAL_POWER 0x0001
#define HUB_STATUS_OVERCURRENT 0x0002
#define HUB_CHANGE_LOCAL_POWER 0x0001
#define HUB_CHANGE_OVERCURRENT 0x0002
#define USB_DT_HUB (USB_TYPE_CLASS | 0x09)
#define USB_DT_SS_HUB (USB_TYPE_CLASS | 0x0a)
#define USB_DT_HUB_NONVAR_SIZE 7
#define USB_DT_SS_HUB_SIZE 12
#define USB_HUB_PR_FS 0
#define USB_HUB_PR_HS_NO_TT 0
#define USB_HUB_PR_HS_SINGLE_TT 1
#define USB_HUB_PR_HS_MULTI_TT 2
#define USB_HUB_PR_SS 3
struct usb_hub_descriptor {
  __u8 bDescLength;
  __u8 bDescriptorType;
  __u8 bNbrPorts;
  __le16 wHubCharacteristics;
  __u8 bPwrOn2PwrGood;
  __u8 bHubContrCurrent;
  union {
    struct {
      __u8 DeviceRemovable[(USB_MAXCHILDREN + 1 + 7) / 8];
      __u8 PortPwrCtrlMask[(USB_MAXCHILDREN + 1 + 7) / 8];
    } __attribute__((packed)) hs;
    struct {
      __u8 bHubHdrDecLat;
      __le16 wHubDelay;
      __le16 DeviceRemovable;
    } __attribute__((packed)) ss;
  } u;
} __attribute__((packed));
#define HUB_LED_AUTO 0
#define HUB_LED_AMBER 1
#define HUB_LED_GREEN 2
#define HUB_LED_OFF 3
enum hub_led_mode {
  INDICATOR_AUTO = 0,
  INDICATOR_CYCLE,
  INDICATOR_GREEN_BLINK,
  INDICATOR_GREEN_BLINK_OFF,
  INDICATOR_AMBER_BLINK,
  INDICATOR_AMBER_BLINK_OFF,
  INDICATOR_ALT_BLINK,
  INDICATOR_ALT_BLINK_OFF
} __attribute__((packed));
#define HUB_TTTT_8_BITS 0x00
#define HUB_TTTT_16_BITS 0x20
#define HUB_TTTT_24_BITS 0x40
#define HUB_TTTT_32_BITS 0x60
#endif