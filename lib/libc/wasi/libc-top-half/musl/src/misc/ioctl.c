#include <sys/ioctl.h>
#include <stdarg.h>
#include <errno.h>
#include <time.h>
#include <sys/time.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include "syscall.h"

#define alignof(t) offsetof(struct { char c; t x; }, x)

#define W 1
#define R 2
#define WR 3

struct ioctl_compat_map {
	int new_req, old_req;
	unsigned char old_size, dir, force_align, noffs;
	unsigned char offsets[8];
};

#define NINTH(a,b,c,d,e,f,g,h,i,...) i
#define COUNT(...) NINTH(__VA_ARGS__,8,7,6,5,4,3,2,1,0)
#define OFFS(...) COUNT(__VA_ARGS__), { __VA_ARGS__ }

/* yields a type for a struct with original size n, with a misaligned
 * timeval/timespec expanded from 32- to 64-bit. for use with ioctl
 * number producing macros; only size of result is meaningful. */
#define new_misaligned(n) struct { int i; time_t t; char c[(n)-4]; }

struct v4l2_event {
	uint32_t a;
	uint64_t b[8];
	uint32_t c[2], ts[2], d[9];
};

static const struct ioctl_compat_map compat_map[] = {
	{ SIOCGSTAMP, SIOCGSTAMP_OLD, 8, R, 0, OFFS(0, 4) },
	{ SIOCGSTAMPNS, SIOCGSTAMPNS_OLD, 8, R, 0, OFFS(0, 4) },

	/* SNDRV_TIMER_IOCTL_STATUS */
	{ _IOR('T', 0x14, char[96]), _IOR('T', 0x14, 88), 88, R, 0, OFFS(0,4) },

	/* SNDRV_PCM_IOCTL_STATUS[_EXT] */
	{ _IOR('A', 0x20, char[128]), _IOR('A', 0x20, char[108]), 108, R, 1, OFFS(4,8,12,16,52,56,60,64) },
	{ _IOWR('A', 0x24, char[128]), _IOWR('A', 0x24, char[108]), 108, WR, 1, OFFS(4,8,12,16,52,56,60,64) },

	/* SNDRV_RAWMIDI_IOCTL_STATUS */
	{ _IOWR('W', 0x20, char[48]), _IOWR('W', 0x20, char[36]), 36, WR, 1, OFFS(4,8) },

	/* SNDRV_PCM_IOCTL_SYNC_PTR - with 3 subtables */
	{ _IOWR('A', 0x23, char[136]), _IOWR('A', 0x23, char[132]), 0, WR, 1, 0 },
	{ 0, 0, 4, WR, 1, 0 }, /* snd_pcm_sync_ptr (flags only) */
	{ 0, 0, 32, WR, 1, OFFS(8,12,16,24,28) }, /* snd_pcm_mmap_status */
	{ 0, 0, 8, WR, 1, OFFS(0,4) }, /* snd_pcm_mmap_control */

	/* VIDIOC_QUERYBUF, VIDIOC_QBUF, VIDIOC_DQBUF, VIDIOC_PREPARE_BUF */
	{ _IOWR('V',  9, new_misaligned(68)), _IOWR('V',  9, char[68]), 68, WR, 1, OFFS(20, 24) },
	{ _IOWR('V', 15, new_misaligned(68)), _IOWR('V', 15, char[68]), 68, WR, 1, OFFS(20, 24) },
	{ _IOWR('V', 17, new_misaligned(68)), _IOWR('V', 17, char[68]), 68, WR, 1, OFFS(20, 24) },
	{ _IOWR('V', 93, new_misaligned(68)), _IOWR('V', 93, char[68]), 68, WR, 1, OFFS(20, 24) },

	/* VIDIOC_DQEVENT */
	{ _IOR('V', 89, new_misaligned(120)), _IOR('V', 89, struct v4l2_event), sizeof(struct v4l2_event),
	  R, 0, OFFS(offsetof(struct v4l2_event, ts[0]), offsetof(struct v4l2_event, ts[1])) },

	/* VIDIOC_OMAP3ISP_STAT_REQ */
	{ _IOWR('V', 192+6, char[32]), _IOWR('V', 192+6, char[24]), 22, WR, 0, OFFS(0,4) },

	/* PPPIOCGIDLE */
	{ _IOR('t', 63, char[16]), _IOR('t', 63, char[8]), 8, R, 0, OFFS(0,4) },

	/* PPGETTIME, PPSETTIME */
	{ _IOR('p', 0x95, char[16]), _IOR('p', 0x95, char[8]), 8, R, 0, OFFS(0,4) },
	{ _IOW('p', 0x96, char[16]), _IOW('p', 0x96, char[8]), 8, W, 0, OFFS(0,4) },

	/* LPSETTIMEOUT */
	{ _IOW(0x6, 0xf, char[16]), 0x060f, 8, W, 0, OFFS(0,4) },
};

static void convert_ioctl_struct(const struct ioctl_compat_map *map, char *old, char *new, int dir)
{
	int new_offset = 0;
	int old_offset = 0;
	int old_size = map->old_size;
	if (!(dir & map->dir)) return;
	if (!map->old_size) {
		/* offsets hard-coded for SNDRV_PCM_IOCTL_SYNC_PTR;
		 * if another exception appears this needs changing. */
		convert_ioctl_struct(map+1, old, new, dir);
		convert_ioctl_struct(map+2, old+4, new+8, dir);
		convert_ioctl_struct(map+3, old+68, new+72, dir);
		return;
	}
	for (int i=0; i < map->noffs; i++) {
		int ts_offset = map->offsets[i];
		int len = ts_offset-old_offset;
		if (dir==W) memcpy(old+old_offset, new+new_offset, len);
		else memcpy(new+new_offset, old+old_offset, len);
		new_offset += len;
		old_offset += len;
		long long new_ts;
		long old_ts;
		int align = map->force_align ? sizeof(time_t) : alignof(time_t);
		new_offset += (align-1) & -new_offset;
		if (dir==W) {
			memcpy(&new_ts, new+new_offset, sizeof new_ts);
			old_ts = new_ts;
			memcpy(old+old_offset, &old_ts, sizeof old_ts);
		} else {
			memcpy(&old_ts, old+old_offset, sizeof old_ts);
			new_ts = old_ts;
			memcpy(new+new_offset, &new_ts, sizeof new_ts);
		}
		new_offset += sizeof new_ts;
		old_offset += sizeof old_ts;
	}
	if (dir==W) memcpy(old+old_offset, new+new_offset, old_size-old_offset);
	else memcpy(new+new_offset, old+old_offset, old_size-old_offset);
}

int ioctl(int fd, int req, ...)
{
	void *arg;
	va_list ap;
	va_start(ap, req);
	arg = va_arg(ap, void *);
	va_end(ap);
	int r = __syscall(SYS_ioctl, fd, req, arg);
	if (SIOCGSTAMP != SIOCGSTAMP_OLD && req && r==-ENOTTY) {
		for (int i=0; i<sizeof compat_map/sizeof *compat_map; i++) {
			if (compat_map[i].new_req != req) continue;
			union {
				long long align;
				char buf[256];
			} u;
			convert_ioctl_struct(&compat_map[i], u.buf, arg, W);
			r = __syscall(SYS_ioctl, fd, compat_map[i].old_req, u.buf);
			if (r<0) break;
			convert_ioctl_struct(&compat_map[i], u.buf, arg, R);
			break;
		}
	}
	return __syscall_ret(r);
}
