/*-
 * Data structures and definitions for SCSI Interface Modules (SIMs).
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 1997 Justin T. Gibbs.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions, and the following disclaimer,
 *    without modification, immediately at the beginning of the file.
 * 2. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _CAM_CAM_SIM_H
#define _CAM_CAM_SIM_H 1

#ifdef _KERNEL

/*
 * The sim driver creates a sim for each controller.  The sim device
 * queue is separately created in order to allow resource sharing between
 * sims.  For instance, a driver may create one sim for each channel of
 * a multi-channel controller and use the same queue for each channel.
 * In this way, the queue resources are shared across all the channels
 * of the multi-channel controller.
 */

struct cam_sim;
struct cam_devq;

typedef void (*sim_action_func)(struct cam_sim *sim, union ccb *ccb);
typedef void (*sim_poll_func)(struct cam_sim *sim);

struct cam_devq * cam_simq_alloc(uint32_t max_sim_transactions);
void		  cam_simq_free(struct cam_devq *devq);

struct cam_sim *  cam_sim_alloc(sim_action_func sim_action,
				sim_poll_func sim_poll,
				const char *sim_name,
				void *softc,
				uint32_t unit,
				struct mtx *mtx,
				int max_dev_transactions,
				int max_tagged_dev_transactions,
				struct cam_devq *queue);
struct cam_sim *  cam_sim_alloc_dev(sim_action_func sim_action,
				sim_poll_func sim_poll,
				const char *sim_name,
				void *softc,
				device_t dev,
				struct mtx *mtx,
				int max_dev_transactions,
				int max_tagged_dev_transactions,
				struct cam_devq *queue);
void		  cam_sim_free(struct cam_sim *sim, int free_devq);
void		  cam_sim_hold(struct cam_sim *sim);
void		  cam_sim_release(struct cam_sim *sim);

/* Optional sim attributes may be set with these. */
void	cam_sim_set_path(struct cam_sim *sim, uint32_t path_id);

/* Generically useful offsets into the sim private area */
#define spriv_ptr0 sim_priv.entries[0].ptr
#define spriv_ptr1 sim_priv.entries[1].ptr
#define spriv_field0 sim_priv.entries[0].field
#define spriv_field1 sim_priv.entries[1].field

/*
 * The sim driver should not access anything directly from this
 * structure.
 */
struct cam_sim {
	sim_action_func		sim_action;
	sim_poll_func		sim_poll;
	const char		*sim_name;
	void			*softc;
	struct mtx		*mtx;
	TAILQ_ENTRY(cam_sim)	links;
	uint32_t		path_id;/* The Boot device may set this to 0? */
	uint32_t		unit_number;
	uint32_t		bus_id;
	int			max_tagged_dev_openings;
	int			max_dev_openings;
	uint32_t		flags;
	struct cam_devq 	*devq;	/* Device Queue to use for this SIM */
	int			refcount; /* References to the SIM. */
};

static __inline uint32_t
cam_sim_path(const struct cam_sim *sim)
{
	return (sim->path_id);
}

static __inline const char *
cam_sim_name(const struct cam_sim *sim)
{
	return (sim->sim_name);
}

static __inline void *
cam_sim_softc(const struct cam_sim *sim)
{
	return (sim->softc);
}

static __inline uint32_t
cam_sim_unit(const struct cam_sim *sim)
{
	return (sim->unit_number);
}

static __inline uint32_t
cam_sim_bus(const struct cam_sim *sim)
{
	return (sim->bus_id);
}

static __inline bool
cam_sim_pollable(const struct cam_sim *sim)
{
	return (sim->sim_poll != NULL);
}

#endif /* _KERNEL */
#endif /* _CAM_CAM_SIM_H */