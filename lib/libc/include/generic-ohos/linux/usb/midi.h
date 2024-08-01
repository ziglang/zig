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
#ifndef __LINUX_USB_MIDI_H
#define __LINUX_USB_MIDI_H
#include <linux/types.h>
#define USB_MS_HEADER 0x01
#define USB_MS_MIDI_IN_JACK 0x02
#define USB_MS_MIDI_OUT_JACK 0x03
#define USB_MS_ELEMENT 0x04
#define USB_MS_GENERAL 0x01
#define USB_MS_EMBEDDED 0x01
#define USB_MS_EXTERNAL 0x02
struct usb_ms_header_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDescriptorSubtype;
  __le16 bcdMSC;
  __le16 wTotalLength;
} __attribute__((packed));
#define USB_DT_MS_HEADER_SIZE 7
struct usb_midi_in_jack_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDescriptorSubtype;
  __u8 bJackType;
  __u8 bJackID;
  __u8 iJack;
} __attribute__((packed));
#define USB_DT_MIDI_IN_SIZE 6
struct usb_midi_source_pin {
  __u8 baSourceID;
  __u8 baSourcePin;
} __attribute__((packed));
struct usb_midi_out_jack_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDescriptorSubtype;
  __u8 bJackType;
  __u8 bJackID;
  __u8 bNrInputPins;
  struct usb_midi_source_pin pins[];
} __attribute__((packed));
#define USB_DT_MIDI_OUT_SIZE(p) (7 + 2 * (p))
#define DECLARE_USB_MIDI_OUT_JACK_DESCRIPTOR(p) struct usb_midi_out_jack_descriptor_ ##p { __u8 bLength; __u8 bDescriptorType; __u8 bDescriptorSubtype; __u8 bJackType; __u8 bJackID; __u8 bNrInputPins; struct usb_midi_source_pin pins[p]; __u8 iJack; \
} __attribute__((packed))
struct usb_ms_endpoint_descriptor {
  __u8 bLength;
  __u8 bDescriptorType;
  __u8 bDescriptorSubtype;
  __u8 bNumEmbMIDIJack;
  __u8 baAssocJackID[];
} __attribute__((packed));
#define USB_DT_MS_ENDPOINT_SIZE(n) (4 + (n))
#define DECLARE_USB_MS_ENDPOINT_DESCRIPTOR(n) struct usb_ms_endpoint_descriptor_ ##n { __u8 bLength; __u8 bDescriptorType; __u8 bDescriptorSubtype; __u8 bNumEmbMIDIJack; __u8 baAssocJackID[n]; \
} __attribute__((packed))
#endif