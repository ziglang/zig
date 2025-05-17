/* zig patch: manually expanded from sysident_assym.cf */

#define	ELF_NOTE_NETBSD_NAMESZ		7
#define	ELF_NOTE_NETBSD_DESCSZ		4
#define	ELF_NOTE_TYPE_NETBSD_TAG	1
#define	ELF_NOTE_PAX_NAMESZ		4
#define	ELF_NOTE_PAX_DESCSZ		4
#define	ELF_NOTE_TYPE_PAX_TAG		3

/* zig patch: ELF_NOTE_MARCH_DESC and ELF_NOTE_MARCH_DESCSZ defined by the compiler */
#ifdef ELF_NOTE_MARCH_DESC
#define	ELF_NOTE_MARCH_NAMESZ		7
#define	ELF_NOTE_TYPE_MARCH_TAG		5
#endif

#define	ELF_NOTE_MCMODEL_NAMESZ		7
#define	ELF_NOTE_TYPE_MCMODEL_TAG	6
