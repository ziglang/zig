#include <__header_dirent.h>
#include <__mode_t.h>

int __wasilibc_iftodt(int x) {
    switch (x) {
        case S_IFDIR: return DT_DIR;
        case S_IFCHR: return DT_CHR;
        case S_IFBLK: return DT_BLK;
        case S_IFREG: return DT_REG;
        case S_IFIFO: return DT_FIFO;
        case S_IFLNK: return DT_LNK;
#ifdef DT_SOCK
        case S_IFSOCK: return DT_SOCK;
#endif
        default: return DT_UNKNOWN;
    }
}

int __wasilibc_dttoif(int x) {
    switch (x) {
        case DT_DIR: return S_IFDIR;
        case DT_CHR: return S_IFCHR;
        case DT_BLK: return S_IFBLK;
        case DT_REG: return S_IFREG;
        case DT_FIFO: return S_IFIFO;
        case DT_LNK: return S_IFLNK;
#ifdef DT_SOCK
        case DT_SOCK: return S_IFSOCK;
#endif
        case DT_UNKNOWN:
        default:
	    return S_IFSOCK;
    }
}
