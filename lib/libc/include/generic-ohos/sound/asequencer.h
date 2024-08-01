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
#ifndef _UAPI__SOUND_ASEQUENCER_H
#define _UAPI__SOUND_ASEQUENCER_H
#include <sound/asound.h>
#define SNDRV_SEQ_VERSION SNDRV_PROTOCOL_VERSION(1, 0, 2)
#define SNDRV_SEQ_EVENT_SYSTEM 0
#define SNDRV_SEQ_EVENT_RESULT 1
#define SNDRV_SEQ_EVENT_NOTE 5
#define SNDRV_SEQ_EVENT_NOTEON 6
#define SNDRV_SEQ_EVENT_NOTEOFF 7
#define SNDRV_SEQ_EVENT_KEYPRESS 8
#define SNDRV_SEQ_EVENT_CONTROLLER 10
#define SNDRV_SEQ_EVENT_PGMCHANGE 11
#define SNDRV_SEQ_EVENT_CHANPRESS 12
#define SNDRV_SEQ_EVENT_PITCHBEND 13
#define SNDRV_SEQ_EVENT_CONTROL14 14
#define SNDRV_SEQ_EVENT_NONREGPARAM 15
#define SNDRV_SEQ_EVENT_REGPARAM 16
#define SNDRV_SEQ_EVENT_SONGPOS 20
#define SNDRV_SEQ_EVENT_SONGSEL 21
#define SNDRV_SEQ_EVENT_QFRAME 22
#define SNDRV_SEQ_EVENT_TIMESIGN 23
#define SNDRV_SEQ_EVENT_KEYSIGN 24
#define SNDRV_SEQ_EVENT_START 30
#define SNDRV_SEQ_EVENT_CONTINUE 31
#define SNDRV_SEQ_EVENT_STOP 32
#define SNDRV_SEQ_EVENT_SETPOS_TICK 33
#define SNDRV_SEQ_EVENT_SETPOS_TIME 34
#define SNDRV_SEQ_EVENT_TEMPO 35
#define SNDRV_SEQ_EVENT_CLOCK 36
#define SNDRV_SEQ_EVENT_TICK 37
#define SNDRV_SEQ_EVENT_QUEUE_SKEW 38
#define SNDRV_SEQ_EVENT_TUNE_REQUEST 40
#define SNDRV_SEQ_EVENT_RESET 41
#define SNDRV_SEQ_EVENT_SENSING 42
#define SNDRV_SEQ_EVENT_ECHO 50
#define SNDRV_SEQ_EVENT_OSS 51
#define SNDRV_SEQ_EVENT_CLIENT_START 60
#define SNDRV_SEQ_EVENT_CLIENT_EXIT 61
#define SNDRV_SEQ_EVENT_CLIENT_CHANGE 62
#define SNDRV_SEQ_EVENT_PORT_START 63
#define SNDRV_SEQ_EVENT_PORT_EXIT 64
#define SNDRV_SEQ_EVENT_PORT_CHANGE 65
#define SNDRV_SEQ_EVENT_PORT_SUBSCRIBED 66
#define SNDRV_SEQ_EVENT_PORT_UNSUBSCRIBED 67
#define SNDRV_SEQ_EVENT_USR0 90
#define SNDRV_SEQ_EVENT_USR1 91
#define SNDRV_SEQ_EVENT_USR2 92
#define SNDRV_SEQ_EVENT_USR3 93
#define SNDRV_SEQ_EVENT_USR4 94
#define SNDRV_SEQ_EVENT_USR5 95
#define SNDRV_SEQ_EVENT_USR6 96
#define SNDRV_SEQ_EVENT_USR7 97
#define SNDRV_SEQ_EVENT_USR8 98
#define SNDRV_SEQ_EVENT_USR9 99
#define SNDRV_SEQ_EVENT_SYSEX 130
#define SNDRV_SEQ_EVENT_BOUNCE 131
#define SNDRV_SEQ_EVENT_USR_VAR0 135
#define SNDRV_SEQ_EVENT_USR_VAR1 136
#define SNDRV_SEQ_EVENT_USR_VAR2 137
#define SNDRV_SEQ_EVENT_USR_VAR3 138
#define SNDRV_SEQ_EVENT_USR_VAR4 139
#define SNDRV_SEQ_EVENT_KERNEL_ERROR 150
#define SNDRV_SEQ_EVENT_KERNEL_QUOTE 151
#define SNDRV_SEQ_EVENT_NONE 255
typedef unsigned char snd_seq_event_type_t;
struct snd_seq_addr {
  unsigned char client;
  unsigned char port;
};
struct snd_seq_connect {
  struct snd_seq_addr sender;
  struct snd_seq_addr dest;
};
#define SNDRV_SEQ_ADDRESS_UNKNOWN 253
#define SNDRV_SEQ_ADDRESS_SUBSCRIBERS 254
#define SNDRV_SEQ_ADDRESS_BROADCAST 255
#define SNDRV_SEQ_QUEUE_DIRECT 253
#define SNDRV_SEQ_TIME_STAMP_TICK (0 << 0)
#define SNDRV_SEQ_TIME_STAMP_REAL (1 << 0)
#define SNDRV_SEQ_TIME_STAMP_MASK (1 << 0)
#define SNDRV_SEQ_TIME_MODE_ABS (0 << 1)
#define SNDRV_SEQ_TIME_MODE_REL (1 << 1)
#define SNDRV_SEQ_TIME_MODE_MASK (1 << 1)
#define SNDRV_SEQ_EVENT_LENGTH_FIXED (0 << 2)
#define SNDRV_SEQ_EVENT_LENGTH_VARIABLE (1 << 2)
#define SNDRV_SEQ_EVENT_LENGTH_VARUSR (2 << 2)
#define SNDRV_SEQ_EVENT_LENGTH_MASK (3 << 2)
#define SNDRV_SEQ_PRIORITY_NORMAL (0 << 4)
#define SNDRV_SEQ_PRIORITY_HIGH (1 << 4)
#define SNDRV_SEQ_PRIORITY_MASK (1 << 4)
struct snd_seq_ev_note {
  unsigned char channel;
  unsigned char note;
  unsigned char velocity;
  unsigned char off_velocity;
  unsigned int duration;
};
struct snd_seq_ev_ctrl {
  unsigned char channel;
  unsigned char unused1, unused2, unused3;
  unsigned int param;
  signed int value;
};
struct snd_seq_ev_raw8 {
  unsigned char d[12];
};
struct snd_seq_ev_raw32 {
  unsigned int d[3];
};
struct snd_seq_ev_ext {
  unsigned int len;
  void * ptr;
} __attribute__((packed));
struct snd_seq_result {
  int event;
  int result;
};
struct snd_seq_real_time {
  unsigned int tv_sec;
  unsigned int tv_nsec;
};
typedef unsigned int snd_seq_tick_time_t;
union snd_seq_timestamp {
  snd_seq_tick_time_t tick;
  struct snd_seq_real_time time;
};
struct snd_seq_queue_skew {
  unsigned int value;
  unsigned int base;
};
struct snd_seq_ev_queue_control {
  unsigned char queue;
  unsigned char pad[3];
  union {
    signed int value;
    union snd_seq_timestamp time;
    unsigned int position;
    struct snd_seq_queue_skew skew;
    unsigned int d32[2];
    unsigned char d8[8];
  } param;
};
struct snd_seq_ev_quote {
  struct snd_seq_addr origin;
  unsigned short value;
  struct snd_seq_event * event;
} __attribute__((packed));
struct snd_seq_event {
  snd_seq_event_type_t type;
  unsigned char flags;
  char tag;
  unsigned char queue;
  union snd_seq_timestamp time;
  struct snd_seq_addr source;
  struct snd_seq_addr dest;
  union {
    struct snd_seq_ev_note note;
    struct snd_seq_ev_ctrl control;
    struct snd_seq_ev_raw8 raw8;
    struct snd_seq_ev_raw32 raw32;
    struct snd_seq_ev_ext ext;
    struct snd_seq_ev_queue_control queue;
    union snd_seq_timestamp time;
    struct snd_seq_addr addr;
    struct snd_seq_connect connect;
    struct snd_seq_result result;
    struct snd_seq_ev_quote quote;
  } data;
};
struct snd_seq_event_bounce {
  int err;
  struct snd_seq_event event;
};
struct snd_seq_system_info {
  int queues;
  int clients;
  int ports;
  int channels;
  int cur_clients;
  int cur_queues;
  char reserved[24];
};
struct snd_seq_running_info {
  unsigned char client;
  unsigned char big_endian;
  unsigned char cpu_mode;
  unsigned char pad;
  unsigned char reserved[12];
};
#define SNDRV_SEQ_CLIENT_SYSTEM 0
#define SNDRV_SEQ_CLIENT_DUMMY 14
#define SNDRV_SEQ_CLIENT_OSS 15
typedef int __bitwise snd_seq_client_type_t;
#define NO_CLIENT ((__force snd_seq_client_type_t) 0)
#define USER_CLIENT ((__force snd_seq_client_type_t) 1)
#define KERNEL_CLIENT ((__force snd_seq_client_type_t) 2)
#define SNDRV_SEQ_FILTER_BROADCAST (1 << 0)
#define SNDRV_SEQ_FILTER_MULTICAST (1 << 1)
#define SNDRV_SEQ_FILTER_BOUNCE (1 << 2)
#define SNDRV_SEQ_FILTER_USE_EVENT (1 << 31)
struct snd_seq_client_info {
  int client;
  snd_seq_client_type_t type;
  char name[64];
  unsigned int filter;
  unsigned char multicast_filter[8];
  unsigned char event_filter[32];
  int num_ports;
  int event_lost;
  int card;
  int pid;
  char reserved[56];
};
struct snd_seq_client_pool {
  int client;
  int output_pool;
  int input_pool;
  int output_room;
  int output_free;
  int input_free;
  char reserved[64];
};
#define SNDRV_SEQ_REMOVE_INPUT (1 << 0)
#define SNDRV_SEQ_REMOVE_OUTPUT (1 << 1)
#define SNDRV_SEQ_REMOVE_DEST (1 << 2)
#define SNDRV_SEQ_REMOVE_DEST_CHANNEL (1 << 3)
#define SNDRV_SEQ_REMOVE_TIME_BEFORE (1 << 4)
#define SNDRV_SEQ_REMOVE_TIME_AFTER (1 << 5)
#define SNDRV_SEQ_REMOVE_TIME_TICK (1 << 6)
#define SNDRV_SEQ_REMOVE_EVENT_TYPE (1 << 7)
#define SNDRV_SEQ_REMOVE_IGNORE_OFF (1 << 8)
#define SNDRV_SEQ_REMOVE_TAG_MATCH (1 << 9)
struct snd_seq_remove_events {
  unsigned int remove_mode;
  union snd_seq_timestamp time;
  unsigned char queue;
  struct snd_seq_addr dest;
  unsigned char channel;
  int type;
  char tag;
  int reserved[10];
};
#define SNDRV_SEQ_PORT_SYSTEM_TIMER 0
#define SNDRV_SEQ_PORT_SYSTEM_ANNOUNCE 1
#define SNDRV_SEQ_PORT_CAP_READ (1 << 0)
#define SNDRV_SEQ_PORT_CAP_WRITE (1 << 1)
#define SNDRV_SEQ_PORT_CAP_SYNC_READ (1 << 2)
#define SNDRV_SEQ_PORT_CAP_SYNC_WRITE (1 << 3)
#define SNDRV_SEQ_PORT_CAP_DUPLEX (1 << 4)
#define SNDRV_SEQ_PORT_CAP_SUBS_READ (1 << 5)
#define SNDRV_SEQ_PORT_CAP_SUBS_WRITE (1 << 6)
#define SNDRV_SEQ_PORT_CAP_NO_EXPORT (1 << 7)
#define SNDRV_SEQ_PORT_TYPE_SPECIFIC (1 << 0)
#define SNDRV_SEQ_PORT_TYPE_MIDI_GENERIC (1 << 1)
#define SNDRV_SEQ_PORT_TYPE_MIDI_GM (1 << 2)
#define SNDRV_SEQ_PORT_TYPE_MIDI_GS (1 << 3)
#define SNDRV_SEQ_PORT_TYPE_MIDI_XG (1 << 4)
#define SNDRV_SEQ_PORT_TYPE_MIDI_MT32 (1 << 5)
#define SNDRV_SEQ_PORT_TYPE_MIDI_GM2 (1 << 6)
#define SNDRV_SEQ_PORT_TYPE_SYNTH (1 << 10)
#define SNDRV_SEQ_PORT_TYPE_DIRECT_SAMPLE (1 << 11)
#define SNDRV_SEQ_PORT_TYPE_SAMPLE (1 << 12)
#define SNDRV_SEQ_PORT_TYPE_HARDWARE (1 << 16)
#define SNDRV_SEQ_PORT_TYPE_SOFTWARE (1 << 17)
#define SNDRV_SEQ_PORT_TYPE_SYNTHESIZER (1 << 18)
#define SNDRV_SEQ_PORT_TYPE_PORT (1 << 19)
#define SNDRV_SEQ_PORT_TYPE_APPLICATION (1 << 20)
#define SNDRV_SEQ_PORT_FLG_GIVEN_PORT (1 << 0)
#define SNDRV_SEQ_PORT_FLG_TIMESTAMP (1 << 1)
#define SNDRV_SEQ_PORT_FLG_TIME_REAL (1 << 2)
struct snd_seq_port_info {
  struct snd_seq_addr addr;
  char name[64];
  unsigned int capability;
  unsigned int type;
  int midi_channels;
  int midi_voices;
  int synth_voices;
  int read_use;
  int write_use;
  void * kernel;
  unsigned int flags;
  unsigned char time_queue;
  char reserved[59];
};
#define SNDRV_SEQ_QUEUE_FLG_SYNC (1 << 0)
struct snd_seq_queue_info {
  int queue;
  int owner;
  unsigned locked : 1;
  char name[64];
  unsigned int flags;
  char reserved[60];
};
struct snd_seq_queue_status {
  int queue;
  int events;
  snd_seq_tick_time_t tick;
  struct snd_seq_real_time time;
  int running;
  int flags;
  char reserved[64];
};
struct snd_seq_queue_tempo {
  int queue;
  unsigned int tempo;
  int ppq;
  unsigned int skew_value;
  unsigned int skew_base;
  char reserved[24];
};
#define SNDRV_SEQ_TIMER_ALSA 0
#define SNDRV_SEQ_TIMER_MIDI_CLOCK 1
#define SNDRV_SEQ_TIMER_MIDI_TICK 2
struct snd_seq_queue_timer {
  int queue;
  int type;
  union {
    struct {
      struct snd_timer_id id;
      unsigned int resolution;
    } alsa;
  } u;
  char reserved[64];
};
struct snd_seq_queue_client {
  int queue;
  int client;
  int used;
  char reserved[64];
};
#define SNDRV_SEQ_PORT_SUBS_EXCLUSIVE (1 << 0)
#define SNDRV_SEQ_PORT_SUBS_TIMESTAMP (1 << 1)
#define SNDRV_SEQ_PORT_SUBS_TIME_REAL (1 << 2)
struct snd_seq_port_subscribe {
  struct snd_seq_addr sender;
  struct snd_seq_addr dest;
  unsigned int voices;
  unsigned int flags;
  unsigned char queue;
  unsigned char pad[3];
  char reserved[64];
};
#define SNDRV_SEQ_QUERY_SUBS_READ 0
#define SNDRV_SEQ_QUERY_SUBS_WRITE 1
struct snd_seq_query_subs {
  struct snd_seq_addr root;
  int type;
  int index;
  int num_subs;
  struct snd_seq_addr addr;
  unsigned char queue;
  unsigned int flags;
  char reserved[64];
};
#define SNDRV_SEQ_IOCTL_PVERSION _IOR('S', 0x00, int)
#define SNDRV_SEQ_IOCTL_CLIENT_ID _IOR('S', 0x01, int)
#define SNDRV_SEQ_IOCTL_SYSTEM_INFO _IOWR('S', 0x02, struct snd_seq_system_info)
#define SNDRV_SEQ_IOCTL_RUNNING_MODE _IOWR('S', 0x03, struct snd_seq_running_info)
#define SNDRV_SEQ_IOCTL_GET_CLIENT_INFO _IOWR('S', 0x10, struct snd_seq_client_info)
#define SNDRV_SEQ_IOCTL_SET_CLIENT_INFO _IOW('S', 0x11, struct snd_seq_client_info)
#define SNDRV_SEQ_IOCTL_CREATE_PORT _IOWR('S', 0x20, struct snd_seq_port_info)
#define SNDRV_SEQ_IOCTL_DELETE_PORT _IOW('S', 0x21, struct snd_seq_port_info)
#define SNDRV_SEQ_IOCTL_GET_PORT_INFO _IOWR('S', 0x22, struct snd_seq_port_info)
#define SNDRV_SEQ_IOCTL_SET_PORT_INFO _IOW('S', 0x23, struct snd_seq_port_info)
#define SNDRV_SEQ_IOCTL_SUBSCRIBE_PORT _IOW('S', 0x30, struct snd_seq_port_subscribe)
#define SNDRV_SEQ_IOCTL_UNSUBSCRIBE_PORT _IOW('S', 0x31, struct snd_seq_port_subscribe)
#define SNDRV_SEQ_IOCTL_CREATE_QUEUE _IOWR('S', 0x32, struct snd_seq_queue_info)
#define SNDRV_SEQ_IOCTL_DELETE_QUEUE _IOW('S', 0x33, struct snd_seq_queue_info)
#define SNDRV_SEQ_IOCTL_GET_QUEUE_INFO _IOWR('S', 0x34, struct snd_seq_queue_info)
#define SNDRV_SEQ_IOCTL_SET_QUEUE_INFO _IOWR('S', 0x35, struct snd_seq_queue_info)
#define SNDRV_SEQ_IOCTL_GET_NAMED_QUEUE _IOWR('S', 0x36, struct snd_seq_queue_info)
#define SNDRV_SEQ_IOCTL_GET_QUEUE_STATUS _IOWR('S', 0x40, struct snd_seq_queue_status)
#define SNDRV_SEQ_IOCTL_GET_QUEUE_TEMPO _IOWR('S', 0x41, struct snd_seq_queue_tempo)
#define SNDRV_SEQ_IOCTL_SET_QUEUE_TEMPO _IOW('S', 0x42, struct snd_seq_queue_tempo)
#define SNDRV_SEQ_IOCTL_GET_QUEUE_TIMER _IOWR('S', 0x45, struct snd_seq_queue_timer)
#define SNDRV_SEQ_IOCTL_SET_QUEUE_TIMER _IOW('S', 0x46, struct snd_seq_queue_timer)
#define SNDRV_SEQ_IOCTL_GET_QUEUE_CLIENT _IOWR('S', 0x49, struct snd_seq_queue_client)
#define SNDRV_SEQ_IOCTL_SET_QUEUE_CLIENT _IOW('S', 0x4a, struct snd_seq_queue_client)
#define SNDRV_SEQ_IOCTL_GET_CLIENT_POOL _IOWR('S', 0x4b, struct snd_seq_client_pool)
#define SNDRV_SEQ_IOCTL_SET_CLIENT_POOL _IOW('S', 0x4c, struct snd_seq_client_pool)
#define SNDRV_SEQ_IOCTL_REMOVE_EVENTS _IOW('S', 0x4e, struct snd_seq_remove_events)
#define SNDRV_SEQ_IOCTL_QUERY_SUBS _IOWR('S', 0x4f, struct snd_seq_query_subs)
#define SNDRV_SEQ_IOCTL_GET_SUBSCRIPTION _IOWR('S', 0x50, struct snd_seq_port_subscribe)
#define SNDRV_SEQ_IOCTL_QUERY_NEXT_CLIENT _IOWR('S', 0x51, struct snd_seq_client_info)
#define SNDRV_SEQ_IOCTL_QUERY_NEXT_PORT _IOWR('S', 0x52, struct snd_seq_port_info)
#endif