/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 Alexander V. Chernikov
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef	_NET_ROUTE_NHOP_UTILS_H_
#define	_NET_ROUTE_NHOP_UTILS_H_

/* Chained hash table */
struct _cht_head {
	uint32_t	hash_size;
	uint32_t	items_count;
	void		**ptr;
};

static inline uint32_t
_cht_get_resize_size(const struct _cht_head *head)
{
	uint32_t new_size = 0;

	if ((head->items_count * 2 > head->hash_size) && (head->hash_size < 65536))
		new_size = head->hash_size * 2;
	else if ((head->items_count * 4 < head->hash_size) && head->hash_size > 16)
		new_size = head->hash_size / 2;

	return (new_size);
}

static inline int
_cht_need_resize(const struct _cht_head *head)
{

	return (_cht_get_resize_size(head) > 0);
}

#ifndef	typeof
#define	typeof	__typeof
#endif

#define	CHT_SLIST_NEED_RESIZE(_head)		\
	_cht_need_resize((const struct _cht_head *)(_head))
#define	CHT_SLIST_GET_RESIZE_BUCKETS(_head)	\
	_cht_get_resize_size((const struct _cht_head *)(_head))
#define	CHT_SLIST_GET_RESIZE_SIZE(_buckets)	((_buckets) * sizeof(void *))

#define	CHT_SLIST_DEFINE(_HNAME, _ITEM_TYPE)	\
struct _HNAME##_head {				\
	uint32_t	hash_size;		\
	uint32_t	items_count;		\
	_ITEM_TYPE	**ptr;			\
}

#define	CHT_SLIST_INIT(_head, _ptr, _num_buckets)	\
	(_head)->hash_size = _num_buckets;		\
	(_head)->items_count = 0;			\
	(_head)->ptr = _ptr;

/* Default hash method for constant-size keys */

#define	CHT_GET_BUCK(_head, _PX, _key)	_PX##_hash_key(_key) & ((_head)->hash_size - 1)
#define	CHT_GET_BUCK_OBJ(_head, _PX, _obj)	_PX##_hash_obj(_obj) & ((_head)->hash_size - 1)

#define	CHT_FIRST(_head, idx)	_CHT_FIRST((_head)->ptr, idx)
#define	_CHT_FIRST(_ptr, idx)	(_ptr)[idx]

#define	CHT_SLIST_FIND(_head, _PX, _key, _ret) do {			\
	uint32_t _buck = CHT_GET_BUCK(_head, _PX, _key);		\
	_ret = CHT_FIRST(_head, _buck);					\
	for ( ; _ret != NULL; _ret = _PX##_next(_ret)) {		\
		if (_PX##_cmp(_key, (_ret)))				\
			break;						\
	}								\
} while(0)

/*
 * hash_obj, nhop_cmp
 */
#define	CHT_SLIST_FIND_BYOBJ(_head, _PX, _obj, _ret) do {		\
	uint32_t _buck = CHT_GET_BUCK_OBJ(_head, _PX, _obj);		\
	_ret = CHT_FIRST(_head, _buck);					\
	for ( ; _ret != NULL; _ret = _PX##_next(_ret)) {		\
		if (_PX##_cmp(_obj, _ret))				\
			break;						\
	}								\
} while(0)

#define	CHT_SLIST_INSERT_HEAD(_head, _PX, _obj) do {			\
	uint32_t _buck = CHT_GET_BUCK_OBJ(_head, _PX, _obj);		\
	_PX##_next(_obj) = CHT_FIRST(_head, _buck);			\
	CHT_FIRST(_head, _buck) = _obj;					\
	(_head)->items_count++;						\
} while(0)

#define	CHT_SLIST_REMOVE(_head, _PX, _obj, _ret) do {			\
	typeof(*(_head)->ptr) _tmp;					\
	uint32_t _buck = CHT_GET_BUCK_OBJ(_head, _PX, _obj);		\
	_ret = CHT_FIRST(_head, _buck);					\
	_tmp = NULL;							\
	for ( ; _ret != NULL; _tmp = _ret, _ret = _PX##_next(_ret)) {	\
		if (_obj == _ret)					\
			break;						\
	}								\
	if (_ret != NULL) {						\
		if (_tmp == NULL)					\
			CHT_FIRST(_head, _buck) = _PX##_next(_ret);	\
		else							\
			_PX##_next(_tmp) = _PX##_next(_ret);		\
		(_head)->items_count--;					\
	}								\
} while(0)
#define	CHT_SLIST_REMOVE_BYOBJ	CHT_SLIST_REMOVE

#define	CHT_SLIST_FOREACH(_head, _PX, _x)				\
	for (uint32_t _i = 0; _i < (_head)->hash_size; _i++) {		\
		for (_x = CHT_FIRST(_head, _i); _x; _x = _PX##_next(_x))
#define	CHT_SLIST_FOREACH_END	}

#define	CHT_SLIST_FOREACH_SAFE(_head, _PX, _x, _tmp)			\
	for (uint32_t _i = 0; _i < (_head)->hash_size; _i++) {		\
		for (_x = CHT_FIRST(_head, _i); (_tmp = _PX##_next(_x), _x); _x = _tmp)
#define	CHT_SLIST_FOREACH_SAFE_END	}

#define	CHT_SLIST_RESIZE(_head, _PX, _new_void_ptr, _new_hsize)		\
	uint32_t _new_idx;						\
	typeof((_head)->ptr) _new_ptr = (void *)_new_void_ptr;		\
	typeof(*(_head)->ptr) _x, _y;					\
	for (uint32_t _old_idx = 0; _old_idx < (_head)->hash_size; _old_idx++) {\
		_x = CHT_FIRST(_head, _old_idx);			\
		_y = _x;						\
		while (_y != NULL) {					\
			_y = _PX##_next(_x);				\
			_new_idx = _PX##_hash_obj(_x) & (_new_hsize - 1);\
			_PX##_next(_x) = _CHT_FIRST(_new_ptr, _new_idx);\
			_CHT_FIRST(_new_ptr, _new_idx) = _x;		\
			_x = _y;					\
		}							\
	}								\
	(_head)->hash_size = _new_hsize;				\
	_new_void_ptr = (void *)(_head)->ptr;				\
	(_head)->ptr = _new_ptr;

/* bitmasks */

struct bitmask_head {
	uint16_t	free_off; /* index of the first potentially free block */
	uint16_t	blocks; /* number of 4/8-byte blocks in the index */
	uint32_t	items_count; /* total number of items */
	u_long		*idx;
};

size_t bitmask_get_size(uint32_t items);
uint32_t bitmask_get_resize_items(const struct bitmask_head *nh);
int bitmask_should_resize(const struct bitmask_head *bh);
void bitmask_swap(struct bitmask_head *bh, void *new_idx, uint32_t new_items, void **pidx);
void bitmask_init(struct bitmask_head *bh, void *idx, uint32_t num_items);
int bitmask_copy(const struct bitmask_head *bi, void *new_idx, uint32_t new_items);
int bitmask_alloc_idx(struct bitmask_head *bi, uint16_t *pidx);
int bitmask_free_idx(struct bitmask_head *bi, uint16_t idx);

#endif