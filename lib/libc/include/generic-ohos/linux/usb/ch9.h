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
#ifndef _UAPI__LINUX_USB_CH9_H
#define _UAPI__LINUX_USB_CH9_H
#include <linux/types.h>
#include <asm/byteorder.h>
#define USB_DIR_OUT 0
#define USB_DIR_IN 0x80
#define USB_TYPE_MASK (0x03 << 5)
#define USB_TYPE_STANDARD (0x00 << 5)
#define USB_TYPE_CLASS (0x01 << 5)
#define USB_TYPE_VENDOR (0x02 << 5)
#define USB_TYPE_RESERVED (0x03 << 5)
#define USB_RECIP_MASK 0x1f
#define USB_RECIP_DEVICE 0x00
#define USB_RECIP_INTERFACE 0x01
#define USB_RECIP_ENDPOINT 0x02
#define USB_RECIP_OTHER 0x03
#define USB_RECIP_PORT 0x04
#define USB_RECIP_RPIPE 0x05
#define USB_REQ_GET_STATUS 0x00
#define USB_REQ_CLEAR_FEATURE 0x01
#define USB_REQ_SET_FEATURE 0x03
#define USB_REQ_SET_ADDRESS 0x05
#define USB_REQ_GET_DESCRIPTOR 0x06
#define USB_REQ_SET_DESCRIPTOR 0x07
#define USB_REQ_GET_CONFIGURATION 0x08
#define USB_REQ_SET_CONFIGURATION 0x09
#define USB_REQ_GET_INTERFACE 0x0A
#define USB_REQ_SET_INTERFACE 0x0B
#define USB_REQ_SYNCH_FRAME 0x0C
#define USB_REQ_SET_SEL 0x30
#define USB_REQ_SET_ISOCH_DELAY 0x31
#define USB_REQ_SET_ENCRYPTION 0x0D
#define USB_REQ_GET_ENCRYPTION 0x0E
#define USB_REQ_RPIPE_ABORT 0x0E
#define USB_REQ_SET_HANDSHAKE 0x0F
#define USB_REQ_RPIPE_RESET 0x0F
#define USB_REQ_GET_HANDSHAKE 0x10
#define USB_REQ_SET_CONNECTION 0x11
#define USB_REQ_SET_SECURITY_DATA 0x12
#define USB_REQ_GET_SECURITY_DATA 0x13
#define USB_REQ_SET_WUSB_DATA 0x14
#define USB_REQ_LOOPBACK_DATA_WRITE 0x15
#define USB_REQ_LOOPBACK_DATA_READ 0x16
#define USB_REQ_SET_INTERFACE_DS 0x17
#define USB_REQ_GET_PARTNER_PDO 20
#define USB_REQ_GET_BATTERY_STATUS 21
#define USB_REQ_SET_PDO 22
#define USB_REQ_GET_VDM 23
#define USB_REQ_SEND_VDM 24
#define USB_DEVICE_SELF_POWERED 0
#define USB_DEVICE_REMOTE_WAKEUP 1
#define USB_DEVICE_TEST_MODE 2
#define USB_DEVICE_BATTERY 2
#define USB_DEVICE_B_HNP_ENABLE 3
#define USB_DEVICE_WUSB_DEVICE 3
#define USB_DEVICE_A_HNP_SUPPORT 4
#define USB_DEVICE_A_ALT_HNP_SUPPORT 5
#define USB_DEVICE_DEBUG_MODE 6
#define USB_TEST_J 1
#define USB_TEST_K 2
#define USB_TEST_SE0_NAK 3
#define USB_TEST_PACKET 4
#define USB_TEST_FORCE_ENABLE 5
#define USB_STATUS_TYPE_STANDARD 0
#define USB_STATUS_TYPE_PTM 1
#define USB_DEVICE_U1_ENABLE 48
#define USB_DEVICE_U2_ENABLE 49
#define USB_DEVICE_LTM_ENABLE 50
#define USB_INTRF_FUNC_SUSPEND 0
#define USB_INTR_FUNC_SUSPEND_OPT_MASK 0xFF00
#define USB_INTRF_FUNC_SUSPEND_LP (1 << (8 + 0))
#define USB_INTRF_FUNC_SUSPEND_RW (1 << (8 + 1))
#define USB_INTRF_STAT_FUNC_RW_CAP 1
#define USB_INTRF_STAT_FUNC_RW 2
#define USB_ENDPOINT_HALT 0
#define USB_DEV_STAT_U1_ENABLED 2
#define USB_DEV_STAT_U2_ENABLED 3
#define USB_DEV_STAT_LTM_ENABLED 4
#define USB_DEVICE_BATTERY_WAKE_MASK 40
#define USB_DEVICE_OS_IS_PD_AWARE 41
#define USB_DEVICE_POLICY_MODE 42
#define USB_PORT_PR_SWAP 43
#define USB_PORT_GOTO_MIN 44
#define USB_PORT_RETURN_POWER 45
#define USB_PORT_ACCEPT_PD_REQUEST 46
#define USB_PORT_REJECT_PD_REQUEST 47
#define USB_PORT_PORT_PD_RESET 48
#define USB_PORT_C_PORT_PD_CHANGE 49
#define USB_PORT_CABLE_PD_RESET 50
#define USB_DEVICE_CHARGING_POLICY 54
struct usb_ctrlrequest {
  __u8 bRequestType;
  __u8 bRequest;
  __le16 wValue;
  __le16 wIndex;
  __le16 wLength;
} __attribute__((packed));
#define USB_DT_DEVICE 0x01
#define USB_DT_CONFIG 0x02
#define USB_DT_STRING 0x03
#define USB_DT_INTERFACE 0x04
#define USB_DT_ENDPOINT 0x05
#define USB_DT_DEVICE_QUALIFIER 0x06
#define USB_DT_OTHER_SPEED_CONFIG 0x07
#define USB_DT_INTERFACE_POWER 0x08
#define USB_DT_OTG 0x09
#define USB_DT_DEBUG 0x0a
#define USB_DT_INTERFACE_ASSOCIATION 0x0b
#define USB_DT_SECURITY 0x0c
#define USB_DT_KEY 0x0d
#define USB_DT_ENCRYPTION_TYPE 0x0e
#define USB_DT_BOS 0x0f
#define USB_DT_DEVICE_CAPABILITY 0x10
#define USB_DT_WIRELESS_ENDPOINT_COMP 0x11
#define USB_DT_WIRE_ADAPTER 0x21
#define USB_DT_RPIPE 0x22
#define USB_DT_CS_RADIO_CONTROL 0x23
#define USB_DT_PIPE_USAGE 0x24
#define USB_DT_SS_ENDPOINT_COMP 0x30
#define USB_DT_SSP_ISOC_ENDPOINT_COMP 0x31
#define USB_DT_CS_DEVICE (USB_TYPE_CLASS | USB_DT_DEVICE)
#define USB_DT_CS_CONFIG (USB_TYPE_CLASS | USB_DT_CONFIG)
#define USB_DT_CS_STRING (USB_TYPE_CLASS | USB_DT_STRING)
#define USB_DT_CS_INTERFACE (USB_TYPE_CLASS | USB_DT_INTERFACE)
#define USB_DT_CS_ENDPOINT (USB_TYPE_CLASS | USB_DT_ENDPOINT)
struct usb_descriptor_header {
  __u8 bLength;
  __u8 bDescriptorType;
} __attribute__((packed));
struct usb_device_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __le16 bcdUSB;
  __u8 bDeviceClass;
  __u8 bDeviceSubClass;
  __u8 bDeviceProtocol;
  __u8 bMaxPacketSize0;
  __le16 idVendor;
  __le16 idProduct;
  __le16 bcdDevice;
  __u8 iManufacturer;
  __u8 iProduct;
  __u8 iSerialNumber;
  __u8 bNumConfigurations;
} __attribute__((packed));
#define USB_DT_DEVICE_SIZE 18
#define USB_CLASS_PER_INTERFACE 0
#define USB_CLASS_AUDIO 1
#define USB_CLASS_COMM 2
#define USB_CLASS_HID 3
#define USB_CLASS_PHYSICAL 5
#define USB_CLASS_STILL_IMAGE 6
#define USB_CLASS_PRINTER 7
#define USB_CLASS_MASS_STORAGE 8
#define USB_CLASS_HUB 9
#define USB_CLASS_CDC_DATA 0x0a
#define USB_CLASS_CSCID 0x0b
#define USB_CLASS_CONTENT_SEC 0x0d
#define USB_CLASS_VIDEO 0x0e
#define USB_CLASS_WIRELESS_CONTROLLER 0xe0
#define USB_CLASS_PERSONAL_HEALTHCARE 0x0f
#define USB_CLASS_AUDIO_VIDEO 0x10
#define USB_CLASS_BILLBOARD 0x11
#define USB_CLASS_USB_TYPE_C_BRIDGE 0x12
#define USB_CLASS_MISC 0xef
#define USB_CLASS_APP_SPEC 0xfe
#define USB_CLASS_VENDOR_SPEC 0xff
#define USB_SUBCLASS_VENDOR_SPEC 0xff
struct usb_config_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __le16 wTotalLength;
  __u8 bNumInterfaces;
  __u8 bConfigurationValue;
  __u8 iConfiguration;
  __u8 bmAttributes;
  __u8 bMaxPower;
} __attribute__((packed));
#define USB_DT_CONFIG_SIZE 9
#define USB_CONFIG_ATT_ONE (1 << 7)
#define USB_CONFIG_ATT_SELFPOWER (1 << 6)
#define USB_CONFIG_ATT_WAKEUP (1 << 5)
#define USB_CONFIG_ATT_BATTERY (1 << 4)
#define USB_MAX_STRING_LEN 126
struct usb_string_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __le16 wData[1];
} __attribute__((packed));
struct usb_interface_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bInterfaceNumber;
  __u8 bAlternateSetting;
  __u8 bNumEndpoints;
  __u8 bInterfaceClass;
  __u8 bInterfaceSubClass;
  __u8 bInterfaceProtocol;
  __u8 iInterface;
} __attribute__((packed));
#define USB_DT_INTERFACE_SIZE 9
struct usb_endpoint_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bEndpointAddress;
  __u8 bmAttributes;
  __le16 wMaxPacketSize;
  __u8 bInterval;
  __u8 bRefresh;
  __u8 bSynchAddress;
} __attribute__((packed));
#define USB_DT_ENDPOINT_SIZE 7
#define USB_DT_ENDPOINT_AUDIO_SIZE 9
#define USB_ENDPOINT_NUMBER_MASK 0x0f
#define USB_ENDPOINT_DIR_MASK 0x80
#define USB_ENDPOINT_XFERTYPE_MASK 0x03
#define USB_ENDPOINT_XFER_CONTROL 0
#define USB_ENDPOINT_XFER_ISOC 1
#define USB_ENDPOINT_XFER_BULK 2
#define USB_ENDPOINT_XFER_INT 3
#define USB_ENDPOINT_MAX_ADJUSTABLE 0x80
#define USB_ENDPOINT_MAXP_MASK 0x07ff
#define USB_EP_MAXP_MULT_SHIFT 11
#define USB_EP_MAXP_MULT_MASK (3 << USB_EP_MAXP_MULT_SHIFT)
#define USB_EP_MAXP_MULT(m) (((m) & USB_EP_MAXP_MULT_MASK) >> USB_EP_MAXP_MULT_SHIFT)
#define USB_ENDPOINT_INTRTYPE 0x30
#define USB_ENDPOINT_INTR_PERIODIC (0 << 4)
#define USB_ENDPOINT_INTR_NOTIFICATION (1 << 4)
#define USB_ENDPOINT_SYNCTYPE 0x0c
#define USB_ENDPOINT_SYNC_NONE (0 << 2)
#define USB_ENDPOINT_SYNC_ASYNC (1 << 2)
#define USB_ENDPOINT_SYNC_ADAPTIVE (2 << 2)
#define USB_ENDPOINT_SYNC_SYNC (3 << 2)
#define USB_ENDPOINT_USAGE_MASK 0x30
#define USB_ENDPOINT_USAGE_DATA 0x00
#define USB_ENDPOINT_USAGE_FEEDBACK 0x10
#define USB_ENDPOINT_USAGE_IMPLICIT_FB 0x20
struct usb_ssp_isoc_ep_comp_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __le16 wReseved;
  __le32 dwBytesPerInterval;
} __attribute__((packed));
#define USB_DT_SSP_ISOC_EP_COMP_SIZE 8
struct usb_ss_ep_comp_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bMaxBurst;
  __u8 bmAttributes;
  __le16 wBytesPerInterval;
} __attribute__((packed));
#define USB_DT_SS_EP_COMP_SIZE 6
#define USB_SS_MULT(p) (1 + ((p) & 0x3))
#define USB_SS_SSP_ISOC_COMP(p) ((p) & (1 << 7))
struct usb_qualifier_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __le16 bcdUSB;
  __u8 bDeviceClass;
  __u8 bDeviceSubClass;
  __u8 bDeviceProtocol;
  __u8 bMaxPacketSize0;
  __u8 bNumConfigurations;
  __u8 bRESERVED;
} __attribute__((packed));
struct usb_otg_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bmAttributes;
} __attribute__((packed));
struct usb_otg20_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bmAttributes;
  __le16 bcdOTG;
} __attribute__((packed));
#define USB_OTG_SRP (1 << 0)
#define USB_OTG_HNP (1 << 1)
#define USB_OTG_ADP (1 << 2)
#define OTG_STS_SELECTOR 0xF000
struct usb_debug_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDebugInEndpoint;
  __u8 bDebugOutEndpoint;
} __attribute__((packed));
struct usb_interface_assoc_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bFirstInterface;
  __u8 bInterfaceCount;
  __u8 bFunctionClass;
  __u8 bFunctionSubClass;
  __u8 bFunctionProtocol;
  __u8 iFunction;
} __attribute__((packed));
#define USB_DT_INTERFACE_ASSOCIATION_SIZE 8
struct usb_security_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __le16 wTotalLength;
  __u8 bNumEncryptionTypes;
} __attribute__((packed));
struct usb_key_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 tTKID[3];
  __u8 bReserved;
  __u8 bKeyData[0];
} __attribute__((packed));
struct usb_encryption_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bEncryptionType;
#define USB_ENC_TYPE_UNSECURE 0
#define USB_ENC_TYPE_WIRED 1
#define USB_ENC_TYPE_CCM_1 2
#define USB_ENC_TYPE_RSA_1 3
  __u8 bEncryptionValue;
  __u8 bAuthKeyIndex;
} __attribute__((packed));
struct usb_bos_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __le16 wTotalLength;
  __u8 bNumDeviceCaps;
} __attribute__((packed));
#define USB_DT_BOS_SIZE 5
struct usb_dev_cap_header {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDevCapabilityType;
} __attribute__((packed));
#define USB_CAP_TYPE_WIRELESS_USB 1
struct usb_wireless_cap_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDevCapabilityType;
  __u8 bmAttributes;
#define USB_WIRELESS_P2P_DRD (1 << 1)
#define USB_WIRELESS_BEACON_MASK (3 << 2)
#define USB_WIRELESS_BEACON_SELF (1 << 2)
#define USB_WIRELESS_BEACON_DIRECTED (2 << 2)
#define USB_WIRELESS_BEACON_NONE (3 << 2)
  __le16 wPHYRates;
#define USB_WIRELESS_PHY_53 (1 << 0)
#define USB_WIRELESS_PHY_80 (1 << 1)
#define USB_WIRELESS_PHY_107 (1 << 2)
#define USB_WIRELESS_PHY_160 (1 << 3)
#define USB_WIRELESS_PHY_200 (1 << 4)
#define USB_WIRELESS_PHY_320 (1 << 5)
#define USB_WIRELESS_PHY_400 (1 << 6)
#define USB_WIRELESS_PHY_480 (1 << 7)
  __u8 bmTFITXPowerInfo;
  __u8 bmFFITXPowerInfo;
  __le16 bmBandGroup;
  __u8 bReserved;
} __attribute__((packed));
#define USB_DT_USB_WIRELESS_CAP_SIZE 11
#define USB_CAP_TYPE_EXT 2
struct usb_ext_cap_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDevCapabilityType;
  __le32 bmAttributes;
#define USB_LPM_SUPPORT (1 << 1)
#define USB_BESL_SUPPORT (1 << 2)
#define USB_BESL_BASELINE_VALID (1 << 3)
#define USB_BESL_DEEP_VALID (1 << 4)
#define USB_SET_BESL_BASELINE(p) (((p) & 0xf) << 8)
#define USB_SET_BESL_DEEP(p) (((p) & 0xf) << 12)
#define USB_GET_BESL_BASELINE(p) (((p) & (0xf << 8)) >> 8)
#define USB_GET_BESL_DEEP(p) (((p) & (0xf << 12)) >> 12)
} __attribute__((packed));
#define USB_DT_USB_EXT_CAP_SIZE 7
#define USB_SS_CAP_TYPE 3
struct usb_ss_cap_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDevCapabilityType;
  __u8 bmAttributes;
#define USB_LTM_SUPPORT (1 << 1)
  __le16 wSpeedSupported;
#define USB_LOW_SPEED_OPERATION (1)
#define USB_FULL_SPEED_OPERATION (1 << 1)
#define USB_HIGH_SPEED_OPERATION (1 << 2)
#define USB_5GBPS_OPERATION (1 << 3)
  __u8 bFunctionalitySupport;
  __u8 bU1devExitLat;
  __le16 bU2DevExitLat;
} __attribute__((packed));
#define USB_DT_USB_SS_CAP_SIZE 10
#define CONTAINER_ID_TYPE 4
struct usb_ss_container_id_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDevCapabilityType;
  __u8 bReserved;
  __u8 ContainerID[16];
} __attribute__((packed));
#define USB_DT_USB_SS_CONTN_ID_SIZE 20
#define USB_SSP_CAP_TYPE 0xa
struct usb_ssp_cap_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDevCapabilityType;
  __u8 bReserved;
  __le32 bmAttributes;
#define USB_SSP_SUBLINK_SPEED_ATTRIBS (0x1f << 0)
#define USB_SSP_SUBLINK_SPEED_IDS (0xf << 5)
  __le16 wFunctionalitySupport;
#define USB_SSP_MIN_SUBLINK_SPEED_ATTRIBUTE_ID (0xf)
#define USB_SSP_MIN_RX_LANE_COUNT (0xf << 8)
#define USB_SSP_MIN_TX_LANE_COUNT (0xf << 12)
  __le16 wReserved;
  __le32 bmSublinkSpeedAttr[1];
#define USB_SSP_SUBLINK_SPEED_SSID (0xf)
#define USB_SSP_SUBLINK_SPEED_LSE (0x3 << 4)
#define USB_SSP_SUBLINK_SPEED_ST (0x3 << 6)
#define USB_SSP_SUBLINK_SPEED_RSVD (0x3f << 8)
#define USB_SSP_SUBLINK_SPEED_LP (0x3 << 14)
#define USB_SSP_SUBLINK_SPEED_LSM (0xff << 16)
} __attribute__((packed));
#define USB_PD_POWER_DELIVERY_CAPABILITY 0x06
#define USB_PD_BATTERY_INFO_CAPABILITY 0x07
#define USB_PD_PD_CONSUMER_PORT_CAPABILITY 0x08
#define USB_PD_PD_PROVIDER_PORT_CAPABILITY 0x09
struct usb_pd_cap_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDevCapabilityType;
  __u8 bReserved;
  __le32 bmAttributes;
#define USB_PD_CAP_BATTERY_CHARGING (1 << 1)
#define USB_PD_CAP_USB_PD (1 << 2)
#define USB_PD_CAP_PROVIDER (1 << 3)
#define USB_PD_CAP_CONSUMER (1 << 4)
#define USB_PD_CAP_CHARGING_POLICY (1 << 5)
#define USB_PD_CAP_TYPE_C_CURRENT (1 << 6)
#define USB_PD_CAP_PWR_AC (1 << 8)
#define USB_PD_CAP_PWR_BAT (1 << 9)
#define USB_PD_CAP_PWR_USE_V_BUS (1 << 14)
  __le16 bmProviderPorts;
  __le16 bmConsumerPorts;
  __le16 bcdBCVersion;
  __le16 bcdPDVersion;
  __le16 bcdUSBTypeCVersion;
} __attribute__((packed));
struct usb_pd_cap_battery_info_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDevCapabilityType;
  __u8 iBattery;
  __u8 iSerial;
  __u8 iManufacturer;
  __u8 bBatteryId;
  __u8 bReserved;
  __le32 dwChargedThreshold;
  __le32 dwWeakThreshold;
  __le32 dwBatteryDesignCapacity;
  __le32 dwBatteryLastFullchargeCapacity;
} __attribute__((packed));
struct usb_pd_cap_consumer_port_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDevCapabilityType;
  __u8 bReserved;
  __u8 bmCapabilities;
#define USB_PD_CAP_CONSUMER_BC (1 << 0)
#define USB_PD_CAP_CONSUMER_PD (1 << 1)
#define USB_PD_CAP_CONSUMER_TYPE_C (1 << 2)
  __le16 wMinVoltage;
  __le16 wMaxVoltage;
  __u16 wReserved;
  __le32 dwMaxOperatingPower;
  __le32 dwMaxPeakPower;
  __le32 dwMaxPeakPowerTime;
#define USB_PD_CAP_CONSUMER_UNKNOWN_PEAK_POWER_TIME 0xffff
} __attribute__((packed));
struct usb_pd_cap_provider_port_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDevCapabilityType;
  __u8 bReserved1;
  __u8 bmCapabilities;
#define USB_PD_CAP_PROVIDER_BC (1 << 0)
#define USB_PD_CAP_PROVIDER_PD (1 << 1)
#define USB_PD_CAP_PROVIDER_TYPE_C (1 << 2)
  __u8 bNumOfPDObjects;
  __u8 bReserved2;
  __le32 wPowerDataObject[];
} __attribute__((packed));
#define USB_PTM_CAP_TYPE 0xb
struct usb_ptm_cap_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDevCapabilityType;
} __attribute__((packed));
#define USB_DT_USB_PTM_ID_SIZE 3
#define USB_DT_USB_SSP_CAP_SIZE(ssac) (12 + (ssac + 1) * 4)
struct usb_wireless_ep_comp_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bMaxBurst;
  __u8 bMaxSequence;
  __le16 wMaxStreamDelay;
  __le16 wOverTheAirPacketSize;
  __u8 bOverTheAirInterval;
  __u8 bmCompAttributes;
#define USB_ENDPOINT_SWITCH_MASK 0x03
#define USB_ENDPOINT_SWITCH_NO 0
#define USB_ENDPOINT_SWITCH_SWITCH 1
#define USB_ENDPOINT_SWITCH_SCALE 2
} __attribute__((packed));
struct usb_handshake {
  __u8 bMessageNumber;
  __u8 bStatus;
  __u8 tTKID[3];
  __u8 bReserved;
  __u8 CDID[16];
  __u8 nonce[16];
  __u8 MIC[8];
} __attribute__((packed));
struct usb_connection_context {
  __u8 CHID[16];
  __u8 CDID[16];
  __u8 CK[16];
} __attribute__((packed));
enum usb_device_speed {
  USB_SPEED_UNKNOWN = 0,
  USB_SPEED_LOW,
  USB_SPEED_FULL,
  USB_SPEED_HIGH,
  USB_SPEED_WIRELESS,
  USB_SPEED_SUPER,
  USB_SPEED_SUPER_PLUS,
};
enum usb_device_state {
  USB_STATE_NOTATTACHED = 0,
  USB_STATE_ATTACHED,
  USB_STATE_POWERED,
  USB_STATE_RECONNECTING,
  USB_STATE_UNAUTHENTICATED,
  USB_STATE_DEFAULT,
  USB_STATE_ADDRESS,
  USB_STATE_CONFIGURED,
  USB_STATE_SUSPENDED
};
enum usb3_link_state {
  USB3_LPM_U0 = 0,
  USB3_LPM_U1,
  USB3_LPM_U2,
  USB3_LPM_U3
};
#define USB3_LPM_DISABLED 0x0
#define USB3_LPM_U1_MAX_TIMEOUT 0x7F
#define USB3_LPM_U2_MAX_TIMEOUT 0xFE
#define USB3_LPM_DEVICE_INITIATED 0xFF
struct usb_set_sel_req {
  __u8 u1_sel;
  __u8 u1_pel;
  __le16 u2_sel;
  __le16 u2_pel;
} __attribute__((packed));
#define USB3_LPM_MAX_U1_SEL_PEL 0xFF
#define USB3_LPM_MAX_U2_SEL_PEL 0xFFFF
#define USB_SELF_POWER_VBUS_MAX_DRAW 100
#endif