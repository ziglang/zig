/*	$NetBSD: hid.h,v 1.6 2020/03/11 16:05:31 msaitoh Exp $	*/
/*	$FreeBSD: src/sys/dev/usb/hid.h,v 1.7 1999/11/17 22:33:40 n_hibma Exp $ */

/*
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Lennart Augustsson (lennart@augustsson.net) at
 * Carlstedt Research & Technology.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _HIDHID_H_
#define _HIDHID_H_

#if defined(_KERNEL) || defined(_RUMPKERNEL)

enum hid_kind {
	hid_input,
	hid_output,
	hid_feature,
	hid_collection,
	hid_endcollection,
	hid_none
};

struct hid_location {
	uint32_t size;
	uint32_t count;
	uint32_t pos;
};

struct hid_item {
	/* Global */
	uint32_t _usage_page;
	int32_t logical_minimum;
	int32_t logical_maximum;
	int32_t physical_minimum;
	int32_t physical_maximum;
	uint32_t unit_exponent;
	uint32_t unit;
	uint32_t report_ID;
	/* Local */
	uint32_t usage;
	uint32_t usage_minimum;
	uint32_t usage_maximum;
	uint32_t designator_index;
	uint32_t designator_minimum;
	uint32_t designator_maximum;
	uint32_t string_index;
	uint32_t string_minimum;
	uint32_t string_maximum;
	uint32_t set_delimiter;
	/* Misc */
	uint32_t collection;
	int collevel;
	enum hid_kind kind;
	uint32_t flags;
	/* Location */
	struct hid_location loc;
	/* */
	struct hid_item *next;
};

struct hid_data *hid_start_parse(const void *, int, enum hid_kind);
void hid_end_parse(struct hid_data *);
int hid_get_item(struct hid_data *, struct hid_item *);
int hid_report_size(const void *, int, enum hid_kind, uint8_t);
int hid_locate(const void *, int, uint32_t, uint8_t, enum hid_kind,
    struct hid_location *, uint32_t *);
long hid_get_data(const u_char *, const struct hid_location *);
u_long hid_get_udata(const u_char *, const struct hid_location *);
int hid_is_collection(const void *, int, uint8_t, uint32_t);

#endif /* _KERNEL || _RUMPKERNEL */

/* Usage pages */
#define HUP_UNDEFINED		0x0000U
#define HUP_GENERIC_DESKTOP	0x0001U
#define HUP_SIMULATION		0x0002U
#define HUP_VR_CONTROLS		0x0003U
#define HUP_SPORTS_CONTROLS	0x0004U
#define HUP_GAMING_CONTROLS	0x0005U
#define HUP_KEYBOARD		0x0007U
#define HUP_LEDS		0x0008U
#define HUP_BUTTON		0x0009U
#define HUP_ORDINALS		0x000aU
#define HUP_TELEPHONY		0x000bU
#define HUP_CONSUMER		0x000cU
#define HUP_DIGITIZERS		0x000dU
#define HUP_PHYSICAL_IFACE	0x000eU
#define HUP_UNICODE		0x0010U
#define HUP_ALPHANUM_DISPLAY	0x0014U
#define HUP_MONITOR		0x0080U
#define HUP_MONITOR_ENUM_VAL	0x0081U
#define HUP_VESA_VC		0x0082U
#define HUP_VESA_CMD		0x0083U
#define HUP_POWER		0x0084U
#define HUP_BATTERY		0x0085U
#define HUP_BARCODE_SCANNER	0x008bU
#define HUP_SCALE		0x008cU
#define HUP_CAMERA_CONTROL	0x0090U
#define HUP_ARCADE		0x0091U
#define HUP_VENDOR		0x00ffU
#define HUP_FIDO		0xf1d0U
#define HUP_MICROSOFT		0xff00U
/* XXX compat */
#define HUP_APPLE		0x00ffU
#define HUP_WACOM		0xff00U

/* Usages, Power Device */
#define HUP_INAME		0x0001U
#define HUP_PRESENT_STATUS	0x0002U
#define HUP_CHANGED_STATUS	0x0003U
#define HUP_UPS			0x0004U
#define HUP_POWER_SUPPLY	0x0005U
#define HUP_BATTERY_SYSTEM	0x0010U
#define HUP_BATTERY_SYSTEM_ID	0x0011U
#define HUP_PD_BATTERY		0x0012U
#define HUP_BATTERY_ID		0x0013U
#define HUP_CHARGER		0x0014U
#define HUP_CHARGER_ID		0x0015U
#define HUP_POWER_CONVERTER	0x0016U
#define HUP_POWER_CONVERTER_ID	0x0017U
#define HUP_OUTLET_SYSTEM	0x0018U
#define HUP_OUTLET_SYSTEM_ID	0x0019U
#define HUP_INPUT		0x001aU
#define HUP_INPUT_ID		0x001bU
#define HUP_OUTPUT		0x001cU
#define HUP_OUTPUT_ID		0x001dU
#define HUP_FLOW		0x001eU
#define HUP_FLOW_ID		0x001fU
#define HUP_OUTLET		0x0020U
#define HUP_OUTLET_ID		0x0021U
#define HUP_GANG		0x0022U
#define HUP_GANG_ID		0x0023U
#define HUP_POWER_SUMMARY	0x0024U
#define HUP_POWER_SUMMARY_ID	0x0025U
#define HUP_VOLTAGE		0x0030U
#define HUP_CURRENT		0x0031U
#define HUP_FREQUENCY		0x0032U
#define HUP_APPARENT_POWER	0x0033U
#define HUP_ACTIVE_POWER	0x0034U
#define HUP_PERCENT_LOAD	0x0035U
#define HUP_TEMPERATURE		0x0036U
#define HUP_HUMIDITY		0x0037U
#define HUP_BADCOUNT		0x0038U
#define HUP_CONFIG_VOLTAGE	0x0040U
#define HUP_CONFIG_CURRENT	0x0041U
#define HUP_CONFIG_FREQUENCY	0x0042U
#define HUP_CONFIG_APP_POWER	0x0043U
#define HUP_CONFIG_ACT_POWER	0x0044U
#define HUP_CONFIG_PERCENT_LOAD	0x0045U
#define HUP_CONFIG_TEMPERATURE	0x0046U
#define HUP_CONFIG_HUMIDITY	0x0047U
#define HUP_SWITCHON_CONTROL	0x0050U
#define HUP_SWITCHOFF_CONTROL	0x0051U
#define HUP_TOGGLE_CONTROL	0x0052U
#define HUP_LOW_VOLT_TRANSF	0x0053U
#define HUP_HIGH_VOLT_TRANSF	0x0054U
#define HUP_DELAYBEFORE_REBOOT	0x0055U
#define HUP_DELAYBEFORE_STARTUP	0x0056U
#define HUP_DELAYBEFORE_SHUTDWN	0x0057U
#define HUP_TEST		0x0058U
#define HUP_MODULE_RESET	0x0059U
#define HUP_AUDIBLE_ALRM_CTL	0x005aU
#define HUP_PRESENT		0x0060U
#define HUP_GOOD		0x0061U
#define HUP_INTERNAL_FAILURE	0x0062U
#define HUP_PD_VOLT_OUTOF_RANGE	0x0063U
#define HUP_FREQ_OUTOFRANGE	0x0064U
#define HUP_OVERLOAD		0x0065U
#define HUP_OVERCHARGED		0x0066U
#define HUP_OVERTEMPERATURE	0x0067U
#define HUP_SHUTDOWN_REQUESTED	0x0068U
#define HUP_SHUTDOWN_IMMINENT	0x0069U
#define HUP_SWITCH_ON_OFF	0x006bU
#define HUP_SWITCHABLE		0x006cU
#define HUP_USED		0x006dU
#define HUP_BOOST		0x006eU
#define HUP_BUCK		0x006fU
#define HUP_INITIALIZED		0x0070U
#define HUP_TESTED		0x0071U
#define HUP_AWAITING_POWER	0x0072U
#define HUP_COMMUNICATION_LOST	0x0073U
#define HUP_IMANUFACTURER	0x00fdU
#define HUP_IPRODUCT		0x00feU
#define HUP_ISERIALNUMBER	0x00ffU

/* Usages, Battery */
#define HUB_SMB_BATTERY_MODE	0x0001U
#define HUB_SMB_BATTERY_STATUS	0x0002U
#define HUB_SMB_ALARM_WARNING	0x0003U
#define HUB_SMB_CHARGER_MODE	0x0004U
#define HUB_SMB_CHARGER_STATUS	0x0005U
#define HUB_SMB_CHARGER_SPECINF	0x0006U
#define HUB_SMB_SELECTR_STATE	0x0007U
#define HUB_SMB_SELECTR_PRESETS	0x0008U
#define HUB_SMB_SELECTR_INFO	0x0009U
#define HUB_SMB_OPT_MFGFUNC1	0x0010U
#define HUB_SMB_OPT_MFGFUNC2	0x0011U
#define HUB_SMB_OPT_MFGFUNC3	0x0012U
#define HUB_SMB_OPT_MFGFUNC4	0x0013U
#define HUB_SMB_OPT_MFGFUNC5	0x0014U
#define HUB_CONNECTIONTOSMBUS	0x0015U
#define HUB_OUTPUT_CONNECTION	0x0016U
#define HUB_CHARGER_CONNECTION	0x0017U
#define HUB_BATTERY_INSERTION	0x0018U
#define HUB_USENEXT		0x0019U
#define HUB_OKTOUSE		0x001aU
#define HUB_BATTERY_SUPPORTED	0x001bU
#define HUB_SELECTOR_REVISION	0x001cU
#define HUB_CHARGING_INDICATOR	0x001dU
#define HUB_MANUFACTURER_ACCESS	0x0028U
#define HUB_REM_CAPACITY_LIM	0x0029U
#define HUB_REM_TIME_LIM	0x002aU
#define HUB_ATRATE		0x002bU
#define HUB_CAPACITY_MODE	0x002cU
#define HUB_BCAST_TO_CHARGER	0x002dU
#define HUB_PRIMARY_BATTERY	0x002eU
#define HUB_CHANGE_CONTROLLER	0x002fU
#define HUB_TERMINATE_CHARGE	0x0040U
#define HUB_TERMINATE_DISCHARGE	0x0041U
#define HUB_BELOW_REM_CAP_LIM	0x0042U
#define HUB_REM_TIME_LIM_EXP	0x0043U
#define HUB_CHARGING		0x0044U
#define HUB_DISCHARGING		0x0045U
#define HUB_FULLY_CHARGED	0x0046U
#define HUB_FULLY_DISCHARGED	0x0047U
#define HUB_CONDITIONING_FLAG	0x0048U
#define HUB_ATRATE_OK		0x0049U
#define HUB_SMB_ERROR_CODE	0x004aU
#define HUB_NEED_REPLACEMENT	0x004bU
#define HUB_ATRATE_TIMETOFULL	0x0060U
#define HUB_ATRATE_TIMETOEMPTY	0x0061U
#define HUB_AVERAGE_CURRENT	0x0062U
#define HUB_MAXERROR		0x0063U
#define HUB_REL_STATEOF_CHARGE	0x0064U
#define HUB_ABS_STATEOF_CHARGE	0x0065U
#define HUB_REM_CAPACITY	0x0066U
#define HUB_FULLCHARGE_CAPACITY	0x0067U
#define HUB_RUNTIMETO_EMPTY	0x0068U
#define HUB_AVERAGETIMETO_EMPTY	0x0069U
#define HUB_AVERAGETIMETO_FULL	0x006aU
#define HUB_CYCLECOUNT		0x006bU
#define HUB_BATTPACKMODEL_LEVEL	0x0080U
#define HUB_INTERNAL_CHARGE_CTL	0x0081U
#define HUB_PRIMARY_BATTERY_SUP	0x0082U
#define HUB_DESIGN_CAPACITY	0x0083U
#define HUB_SPECIFICATION_INFO	0x0084U
#define HUB_MANUFACTURER_DATE	0x0085U
#define HUB_SERIAL_NUMBER	0x0086U
#define HUB_IMANUFACTURERNAME	0x0087U
#define HUB_IDEVICENAME		0x0088U
#define HUB_IDEVICECHEMISTERY	0x0089U
#define HUB_MANUFACTURERDATA	0x008aU
#define HUB_RECHARGABLE		0x008bU
#define HUB_WARN_CAPACITY_LIM	0x008cU
#define HUB_CAPACITY_GRANUL1	0x008dU
#define HUB_CAPACITY_GRANUL2	0x008eU
#define HUB_IOEM_INFORMATION	0x008fU
#define HUB_INHIBIT_CHARGE	0x00c0U
#define HUB_ENABLE_POLLING	0x00c1U
#define HUB_RESTORE_TO_ZERO	0x00c2U
#define HUB_AC_PRESENT		0x00d0U
#define HUB_BATTERY_PRESENT	0x00d1U
#define HUB_POWER_FAIL		0x00d2U
#define HUB_ALARM_INHIBITED	0x00d3U
#define HUB_THERMISTOR_UNDRANGE	0x00d4U
#define HUB_THERMISTOR_HOT	0x00d5U
#define HUB_THERMISTOR_COLD	0x00d6U
#define HUB_THERMISTOR_OVERANGE	0x00d7U
#define HUB_BS_VOLT_OUTOF_RANGE	0x00d8U
#define HUB_BS_CURR_OUTOF_RANGE	0x00d9U
#define HUB_BS_CURR_NOT_REGULTD	0x00daU
#define HUB_BS_VOLT_NOT_REGULTD	0x00dbU
#define HUB_MASTER_MODE		0x00dcU
#define HUB_CHARGER_SELECTR_SUP	0x00f0U
#define HUB_CHARGER_SPEC	0x00f1U
#define HUB_LEVEL2		0x00f2U
#define HUB_LEVEL3		0x00f3U

/* Usages, generic desktop */
#define HUG_POINTER		0x0001U
#define HUG_MOUSE		0x0002U
#define HUG_FN_KEY		0x0003U
#define HUG_JOYSTICK		0x0004U
#define HUG_GAME_PAD		0x0005U
#define HUG_KEYBOARD		0x0006U
#define HUG_KEYPAD		0x0007U
#define HUG_X			0x0030U
#define HUG_Y			0x0031U
#define HUG_Z			0x0032U
#define HUG_RX			0x0033U
#define HUG_RY			0x0034U
#define HUG_RZ			0x0035U
#define HUG_SLIDER		0x0036U
#define HUG_DIAL		0x0037U
#define HUG_WHEEL		0x0038U
#define HUG_HAT_SWITCH		0x0039U
#define HUG_COUNTED_BUFFER	0x003aU
#define HUG_BYTE_COUNT		0x003bU
#define HUG_MOTION_WAKEUP	0x003cU
#define HUG_VX			0x0040U
#define HUG_VY			0x0041U
#define HUG_VZ			0x0042U
#define HUG_VBRX		0x0043U
#define HUG_VBRY		0x0044U
#define HUG_VBRZ		0x0045U
#define HUG_VNO			0x0046U
#define HUG_TWHEEL		0x0048U
#define HUG_SYSTEM_CONTROL	0x0080U
#define HUG_SYSTEM_POWER_DOWN	0x0081U
#define HUG_SYSTEM_SLEEP	0x0082U
#define HUG_SYSTEM_WAKEUP	0x0083U
#define HUG_SYSTEM_CONTEXT_MENU	0x0084U
#define HUG_SYSTEM_MAIN_MENU	0x0085U
#define HUG_SYSTEM_APP_MENU	0x0086U
#define HUG_SYSTEM_MENU_HELP	0x0087U
#define HUG_SYSTEM_MENU_EXIT	0x0088U
#define HUG_SYSTEM_MENU_SELECT	0x0089U
#define HUG_SYSTEM_MENU_RIGHT	0x008aU
#define HUG_SYSTEM_MENU_LEFT	0x008bU
#define HUG_SYSTEM_MENU_UP	0x008cU
#define HUG_SYSTEM_MENU_DOWN	0x008dU

/* Usages, Digitizers */
#define HUD_UNDEFINED		0x0000U
#define HUD_DIGITIZER		0x0001U
#define HUD_PEN			0x0002U
#define HUD_TOUCH_SCREEN	0x0004U
#define HUD_TOUCHPAD		0x0005U
#define HUD_CONFIG		0x000eU
#define HUD_FINGER		0x0022U
#define HUD_TIP_PRESSURE	0x0030U
#define HUD_BARREL_PRESSURE	0x0031U
#define HUD_IN_RANGE		0x0032U
#define HUD_TOUCH		0x0033U
#define HUD_UNTOUCH		0x0034U
#define HUD_TAP			0x0035U
#define HUD_QUALITY		0x0036U
#define HUD_DATA_VALID		0x0037U
#define HUD_TRANSDUCER_INDEX	0x0038U
#define HUD_TABLET_FKEYS	0x0039U
#define HUD_PROGRAM_CHANGE_KEYS	0x003aU
#define HUD_BATTERY_STRENGTH	0x003bU
#define HUD_INVERT		0x003cU
#define HUD_X_TILT		0x003dU
#define HUD_Y_TILT		0x003eU
#define HUD_AZIMUTH		0x003fU
#define HUD_ALTITUDE		0x0040U
#define HUD_TWIST		0x0041U
#define HUD_TIP_SWITCH		0x0042U
#define HUD_SEC_TIP_SWITCH	0x0043U
#define HUD_BARREL_SWITCH	0x0044U
#define HUD_ERASER		0x0045U
#define HUD_TABLET_PICK		0x0046U
#define HUD_CONFIDENCE		0x0047U
#define HUD_WIDTH		0x0048U
#define HUD_HEIGHT		0x0049U
#define HUD_CONTACTID		0x0051U
#define HUD_INPUT_MODE		0x0052U
#define HUD_DEVICE_INDEX	0x0053U
#define HUD_CONTACTCOUNT	0x0054U
#define HUD_CONTACT_MAX		0x0055U
#define HUD_SCAN_TIME		0x0056U
#define HUD_BUTTON_TYPE		0x0059U

/* Usages, LED */
#define HUD_LED_NUM_LOCK	0x0001U
#define HUD_LED_CAPS_LOCK	0x0002U
#define HUD_LED_SCROLL_LOCK	0x0003U
#define HUD_LED_COMPOSE		0x0004U
#define HUD_LED_KANA		0x0005U

/* Usages, Consumer */
#define HUC_AC_PAN		0x0238U

/* Usages, FIDO */
#define HUF_U2FHID		0x0001U

#define HID_USAGE2(p, u) (((p) << 16) | u)
#define HID_GET_USAGE(u) ((u) & 0xffff)
#define HID_GET_USAGE_PAGE(u) (((u) >> 16) & 0xffff)

#define HCOLL_PHYSICAL		0
#define HCOLL_APPLICATION	1
#define HCOLL_LOGICAL		2

/* Bits in the input/output/feature items */
#define HIO_CONST	0x001
#define HIO_VARIABLE	0x002
#define HIO_RELATIVE	0x004
#define HIO_WRAP	0x008
#define HIO_NONLINEAR	0x010
#define HIO_NOPREF	0x020
#define HIO_NULLSTATE	0x040
#define HIO_VOLATILE	0x080
#define HIO_BUFBYTES	0x100

/* Valid values for the country codes */
#define	HCC_UNDEFINED	0x00
#define	HCC_MAX		0x23

#endif /* _HIDHID_H_ */