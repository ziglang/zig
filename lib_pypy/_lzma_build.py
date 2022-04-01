# This file is based on lzmaffi/_lzmamodule2.py from lzmaffi version 0.3.0.

# PyPy changes:
# - added __getstate__() methods that raise TypeError on pickling.
# - ported to CFFI 1.0

from cffi import FFI


ffi = FFI()

ffi.cdef("""
#define UINT64_MAX ...
#define LZMA_CONCATENATED ...
#define LZMA_CHECK_NONE ...
#define LZMA_CHECK_CRC32 ...
#define LZMA_CHECK_CRC64 ...
#define LZMA_CHECK_SHA256 ...
#define LZMA_CHECK_ID_MAX ...
#define LZMA_DELTA_TYPE_BYTE ...
#define LZMA_TELL_ANY_CHECK ...
#define LZMA_TELL_NO_CHECK ...
#define LZMA_VLI_UNKNOWN ...
#define LZMA_FILTER_LZMA1 ...
#define LZMA_FILTER_LZMA2 ...
#define LZMA_FILTER_DELTA ...
#define LZMA_FILTER_X86 ...
#define LZMA_FILTER_IA64 ...
#define LZMA_FILTER_ARM ...
#define LZMA_FILTER_ARMTHUMB ...
#define LZMA_FILTER_SPARC ...
#define LZMA_FILTER_POWERPC ...
#define LZMA_FILTERS_MAX ...
#define LZMA_STREAM_HEADER_SIZE ...
#define LZMA_MF_HC3 ...
#define LZMA_MF_HC4 ...
#define LZMA_MF_BT2 ...
#define LZMA_MF_BT3 ...
#define LZMA_MF_BT4 ...
#define LZMA_MODE_FAST ...
#define LZMA_MODE_NORMAL ...
#define LZMA_PRESET_DEFAULT ...
#define LZMA_PRESET_EXTREME ...

typedef enum { LZMA_OK, LZMA_STREAM_END, LZMA_NO_CHECK,
    LZMA_UNSUPPORTED_CHECK, LZMA_GET_CHECK,
    LZMA_MEM_ERROR, LZMA_MEMLIMIT_ERROR,
    LZMA_FORMAT_ERROR, LZMA_OPTIONS_ERROR,
    LZMA_DATA_ERROR, LZMA_BUF_ERROR,
    LZMA_PROG_ERROR, ...
} lzma_ret;

typedef enum { LZMA_RUN, LZMA_FINISH, ...} lzma_action;

typedef enum { ... } lzma_check;

typedef uint64_t lzma_vli;

typedef struct {
    void* (*alloc)(void*, size_t, size_t);
    void (*free)(void*, void*);
    void* opaque;
    ...;
} lzma_allocator;

typedef struct {
    const uint8_t *next_in;
    size_t avail_in;
    uint64_t total_in;

    uint8_t *next_out;
    size_t avail_out;
    uint64_t total_out;
    ...;
} lzma_stream;

typedef struct {
    int type;
    uint32_t dist;
    ...;
} lzma_options_delta;

typedef struct {
    uint32_t start_offset;
    ...;
} lzma_options_bcj;

typedef struct {
    uint32_t dict_size;
    uint32_t lc;
    uint32_t lp;
    uint32_t pb;
    int mode;
    uint32_t nice_len;
    int mf;
    uint32_t depth;
    ...;
} lzma_options_lzma;

typedef struct {
    lzma_vli id;
    void *options;
    ...;
} lzma_filter;

typedef struct {
    uint32_t version;
    lzma_vli backward_size;
    int check;
    ...;
} lzma_stream_flags;

typedef ... lzma_index;

typedef struct {
    uint32_t version;
    uint32_t header_size;
    int check;
    lzma_vli compressed_size;
    lzma_filter* filters;
    ...;
} lzma_block;

bool lzma_check_is_supported(int check);

// Encoder/Decoder
int lzma_auto_decoder(lzma_stream *strm, uint64_t memlimit, uint32_t flags);
int lzma_stream_decoder(lzma_stream *strm, uint64_t memlimit, uint32_t flags);
int lzma_alone_decoder(lzma_stream *strm, uint64_t memlimit);
int lzma_raw_decoder(lzma_stream *strm, const lzma_filter *filters);
int lzma_block_decoder(lzma_stream *strm, lzma_block *block);

int lzma_easy_encoder(lzma_stream *strm, uint32_t preset, int check);
int lzma_alone_encoder(lzma_stream *strm, lzma_options_lzma* options);
int lzma_raw_encoder(lzma_stream *strm, const lzma_filter *filters);
int lzma_stream_encoder(lzma_stream *strm, const lzma_filter *filters, int check);

int lzma_get_check(const lzma_stream *strm);

int lzma_code(lzma_stream *strm, int action);

void lzma_end(lzma_stream *strm);

// Extras
int lzma_stream_header_decode(lzma_stream_flags *options, const uint8_t *in);
int lzma_stream_footer_decode(lzma_stream_flags *options, const uint8_t *in);
int lzma_stream_flags_compare(const lzma_stream_flags *a,
    const lzma_stream_flags *b);

typedef enum {
    LZMA_INDEX_ITER_ANY, LZMA_INDEX_ITER_STREAM, LZMA_INDEX_ITER_BLOCK,
    LZMA_INDEX_ITER_NONEMPTY_BLOCK, ...
} lzma_index_iter_mode;

// Indexes
lzma_index* lzma_index_init(lzma_allocator *al);
void lzma_index_end(lzma_index *i, lzma_allocator *al);
int lzma_index_stream_padding(lzma_index *i, lzma_vli stream_padding);
lzma_index* lzma_index_dup(const lzma_index *i, lzma_allocator *al);
int lzma_index_cat(lzma_index *dest, lzma_index *src, lzma_allocator *al);
int lzma_index_buffer_decode(lzma_index **i, uint64_t *memlimit,
    lzma_allocator *allocator, const uint8_t *in, size_t *in_pos,
    size_t in_size);
lzma_vli lzma_index_block_count(const lzma_index *i);
lzma_vli lzma_index_stream_size(const lzma_index *i);
lzma_vli lzma_index_uncompressed_size(const lzma_index *i);
lzma_vli lzma_index_size(const lzma_index *i);
lzma_vli lzma_index_total_size(const lzma_index *i);

// Blocks
int lzma_block_header_decode(lzma_block *block, lzma_allocator *al,
    const uint8_t *in);
int lzma_block_compressed_size(lzma_block *block, lzma_vli unpadded_size);

typedef struct {
    // cffi doesn't support partial anonymous structs
    // so we write the definition in full
    struct {
        const lzma_stream_flags *flags;
        const void *reserved_ptr1;
        const void *reserved_ptr2;
        const void *reserved_ptr3;
        lzma_vli number;
        lzma_vli block_count;
        lzma_vli compressed_offset;
        lzma_vli uncompressed_offset;
        lzma_vli compressed_size;
        lzma_vli uncompressed_size;
        lzma_vli padding;
        lzma_vli reserved_vli1;
        lzma_vli reserved_vli2;
        lzma_vli reserved_vli3;
        lzma_vli reserved_vli4;
    } stream;
    struct {
        lzma_vli number_in_file;
        lzma_vli compressed_file_offset;
        lzma_vli uncompressed_file_offset;
        lzma_vli number_in_stream;
        lzma_vli compressed_stream_offset;
        lzma_vli uncompressed_stream_offset;
        lzma_vli uncompressed_size;
        lzma_vli unpadded_size;
        lzma_vli total_size;
        lzma_vli reserved_vli1;
        lzma_vli reserved_vli2;
        lzma_vli reserved_vli3;
        lzma_vli reserved_vli4;
        const void *reserved_ptr1;
        const void *reserved_ptr2;
        const void *reserved_ptr3;
        const void *reserved_ptr4;
    } block;
    ...;
} lzma_index_iter;

void lzma_index_iter_init(lzma_index_iter *iter, const lzma_index *i);
int lzma_index_iter_next(lzma_index_iter *iter, int mode);
int lzma_index_iter_locate(lzma_index_iter *iter, lzma_vli target);

// Properties
int lzma_properties_size(uint32_t *size, const lzma_filter *filter);
int lzma_properties_encode(const lzma_filter *filter, uint8_t *props);
int lzma_properties_decode(lzma_filter *filter, lzma_allocator *allocator,
    const uint8_t *props, size_t props_size);
int lzma_lzma_preset(lzma_options_lzma* options, uint32_t preset);

// Special functions
void _pylzma_stream_init(lzma_stream *strm);
void _pylzma_block_header_size_decode(uint32_t b);

void *malloc(size_t size);
void free(void *ptr);
void *realloc(void *ptr, size_t size);
""")

ffi.set_source('_lzma_cffi', """
#ifdef _MSC_VER
#define LZMA_API_STATIC
#endif
#include <lzma.h>
#include <stdlib.h>
void _pylzma_stream_init(lzma_stream *strm) {
    lzma_stream tmp = LZMA_STREAM_INIT; // macro from lzma.h
    *strm = tmp;
}

uint32_t _pylzma_block_header_size_decode(uint32_t b) {
    return lzma_block_header_size_decode(b); // macro from lzma.h
}
""",
    libraries=['lzma'])


if __name__ == '__main__':
    ffi.compile()
