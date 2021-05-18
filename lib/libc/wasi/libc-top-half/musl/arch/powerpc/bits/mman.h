#define PROT_SAO       0x10

#undef MAP_NORESERVE
#define MAP_NORESERVE   0x40
#undef MAP_LOCKED
#define MAP_LOCKED	0x80

#undef MCL_CURRENT
#define MCL_CURRENT     0x2000
#undef MCL_FUTURE
#define MCL_FUTURE      0x4000
#undef MCL_ONFAULT
#define MCL_ONFAULT     0x8000
