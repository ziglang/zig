/* $NetBSD: pmf.h,v 1.25 2020/09/12 18:08:38 macallan Exp $ */

/*-
 * Copyright (c) 2007 Jared D. McNeill <jmcneill@invisible.ca>
 * All rights reserved.
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

#ifndef _SYS_PMF_H
#define _SYS_PMF_H

#if defined(_KERNEL) || defined(_KMEMUSER)

#include <sys/types.h>
#include <sys/device_if.h>

typedef enum {
	PMFE_DISPLAY_ON,
	PMFE_DISPLAY_REDUCED,
	PMFE_DISPLAY_STANDBY,
	PMFE_DISPLAY_SUSPEND,
	PMFE_DISPLAY_OFF,
	PMFE_DISPLAY_BRIGHTNESS_UP,
	PMFE_DISPLAY_BRIGHTNESS_DOWN,
	PMFE_AUDIO_VOLUME_UP,
	PMFE_AUDIO_VOLUME_DOWN,
	PMFE_AUDIO_VOLUME_TOGGLE,
	PMFE_CHASSIS_LID_CLOSE,
	PMFE_CHASSIS_LID_OPEN,
	PMFE_RADIO_ON,
	PMFE_RADIO_OFF,
	PMFE_RADIO_TOGGLE,
	PMFE_POWER_CHANGED,
	PMFE_SPEED_CHANGED,
	PMFE_THROTTLE_ENABLE,
	PMFE_THROTTLE_DISABLE,
	PMFE_KEYBOARD_BRIGHTNESS_UP,
	PMFE_KEYBOARD_BRIGHTNESS_DOWN,
	PMFE_KEYBOARD_BRIGHTNESS_TOGGLE
} pmf_generic_event_t;

struct pmf_qual {
	const device_suspensor_t	*pq_suspensor;
	devact_level_t			pq_actlvl;
};

typedef struct pmf_qual pmf_qual_t;
#endif

#if defined(_KERNEL)
extern const pmf_qual_t * const PMF_Q_NONE;
extern const pmf_qual_t * const PMF_Q_SELF;
extern const pmf_qual_t * const PMF_Q_DRVCTL;

extern const device_suspensor_t
    * const device_suspensor_self,
    * const device_suspensor_system,
    * const device_suspensor_drvctl;

void	pmf_init(void);

bool	pmf_event_inject(device_t, pmf_generic_event_t);
bool	pmf_event_register(device_t, pmf_generic_event_t,
			   void (*)(device_t), bool);
void	pmf_event_deregister(device_t, pmf_generic_event_t,
			     void (*)(device_t), bool);

bool		pmf_set_platform(const char *, const char *);
const char	*pmf_get_platform(const char *);

bool		pmf_system_resume(const pmf_qual_t *);
bool		pmf_system_bus_resume(const pmf_qual_t *);
bool		pmf_system_suspend(const pmf_qual_t *);
void		pmf_system_shutdown(int);

bool		pmf_device_register1(device_t,
		    bool (*)(device_t, const pmf_qual_t *),
		    bool (*)(device_t, const pmf_qual_t *),
		    bool (*)(device_t, int));
/* compatibility */
#define pmf_device_register(__d, __s, __r) \
	pmf_device_register1((__d), (__s), (__r), NULL)

void		pmf_device_deregister(device_t);
bool		pmf_device_suspend(device_t, const pmf_qual_t *);
bool		pmf_device_resume(device_t, const pmf_qual_t *);

bool		pmf_device_recursive_suspend(device_t, const pmf_qual_t *);
bool		pmf_device_recursive_resume(device_t, const pmf_qual_t *);
bool		pmf_device_descendants_resume(device_t, const pmf_qual_t *);
bool		pmf_device_subtree_resume(device_t, const pmf_qual_t *);

bool		pmf_device_descendants_release(device_t, const pmf_qual_t *);
bool		pmf_device_subtree_release(device_t, const pmf_qual_t *);

struct ifnet;
void		pmf_class_network_register(device_t, struct ifnet *);

bool		pmf_class_input_register(device_t);
bool		pmf_class_display_register(device_t);

void		pmf_qual_recursive_copy(pmf_qual_t *, const pmf_qual_t *);
void		pmf_self_suspensor_init(device_t, device_suspensor_t *,
		    pmf_qual_t *);

static __inline const device_suspensor_t *
pmf_qual_suspension(const pmf_qual_t *pq)
{
	return pq->pq_suspensor;
}

static __inline devact_level_t
pmf_qual_depth(const pmf_qual_t *pq)
{
	return pq->pq_actlvl;
}

static __inline bool
pmf_qual_descend_ok(const pmf_qual_t *pq)
{
	return pq->pq_actlvl == DEVACT_LEVEL_FULL;
}

#endif /* !_KERNEL */

#endif /* !_SYS_PMF_H */