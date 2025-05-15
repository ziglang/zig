#ifndef __tailq_hash__
#define __tailq_hash__

/* Must be powers of 2 */
#define MAX_HASH_ENTRIES 128
#define SEQ_BUCKET_SIZE 262144
/*
 * The max seq range that can be stored is
 * 64 x 262144 or 16Meg. We have one extra slot
 * for fall-over but must keep it so we never have
 * wrap in hashing over valid other entries.
 */
#define MAX_ALLOWED_SEQ_RANGE (SEQ_BUCKET_SIZE * (MAX_HASH_ENTRIES-1))

struct tailq_hash {
	struct rack_head ht[MAX_HASH_ENTRIES];
	uint32_t min;
	uint32_t max;
	uint32_t count;
};

struct rack_sendmap *
tqhash_min(struct tailq_hash *hs);

struct rack_sendmap *
tqhash_max(struct tailq_hash *hs);

int
tqhash_empty(struct tailq_hash *hs);

struct rack_sendmap *
tqhash_find(struct tailq_hash *hs, uint32_t seq);

struct rack_sendmap *
tqhash_next(struct tailq_hash *hs, struct rack_sendmap *rsm);

struct rack_sendmap *
tqhash_prev(struct tailq_hash *hs, struct rack_sendmap *rsm);

#define REMOVE_TYPE_CUMACK	1	/* Cumack moved */
#define REMOVE_TYPE_MERGE	2	/* Merging two blocks */
#define REMOVE_TYPE_FINI	3	/* The connection is over */

void
tqhash_remove(struct tailq_hash *hs, struct rack_sendmap *rsm, int type);

int
tqhash_insert(struct tailq_hash *hs, struct rack_sendmap *rsm);

void
tqhash_init(struct tailq_hash *hs);

int
tqhash_trim(struct tailq_hash *hs, uint32_t th_ack);


#define	TQHASH_FOREACH(var, head) \
	for ((var) = tqhash_min((head));		\
	     (var);					\
	     (var) = tqhash_next((head), (var)))

#define TQHASH_FOREACH_FROM(var, head, fvar)					\
	for ((var) = ((fvar) ? (fvar) : tqhash_min((head)));		\
	    (var);							\
	     (var) = tqhash_next((head), (var)))

#define	TQHASH_FOREACH_REVERSE_FROM(var, head)		\
	for ((var) = ((var) ? (var) : tqhash_max((head)));		\
	    (var);							\
	    (var) = tqhash_prev((head), (var)))


#endif