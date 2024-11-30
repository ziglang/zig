#define O_CREAT        0400
#define O_EXCL        02000
#define O_NOCTTY      04000
#define O_TRUNC       01000
#define O_APPEND       0010
#define O_NONBLOCK     0200
#define O_DSYNC        0020
#define O_SYNC       040020
#define O_RSYNC      040020
#define O_DIRECTORY 0200000
#define O_NOFOLLOW  0400000
#define O_CLOEXEC  02000000

#define O_ASYNC      010000
#define O_DIRECT    0100000
#define O_LARGEFILE  020000
#define O_NOATIME  01000000
#define O_PATH    010000000
#define O_TMPFILE 020200000
#define O_NDELAY O_NONBLOCK

#define F_DUPFD  0
#define F_GETFD  1
#define F_SETFD  2
#define F_GETFL  3
#define F_SETFL  4

#define F_SETOWN 24
#define F_GETOWN 23
#define F_SETSIG 10
#define F_GETSIG 11

#define F_GETLK 33
#define F_SETLK 34
#define F_SETLKW 35

#define F_SETOWN_EX 15
#define F_GETOWN_EX 16

#define F_GETOWNER_UIDS 17