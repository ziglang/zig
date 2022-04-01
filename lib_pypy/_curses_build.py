from cffi import FFI, VerificationError
import os
import sys

version_str = '''
    static const int NCURSES_VERSION_MAJOR;
    static const int NCURSES_VERSION_MINOR;
'''

def find_library(options):
    for library in options:
        ffi = FFI()
        ffi.cdef(version_str)
        ffi.set_source("_curses_cffi_check", version_str, libraries=[library])
        try:
            # Check that the link succeeds
            ffi.compile(verbose=1)
        except (VerificationError) as e:
            e_last = e
            continue
        else:
            return library

    # If none of the options is available, present the user a meaningful
    # error message
    raise e_last

def find_curses_dir_and_name():
    for base in ('/usr', '/usr/local'):
        if os.path.exists(os.path.join(base, 'include', 'ncursesw')):
            return base, 'ncursesw'
        if os.path.exists(os.path.join(base, 'include', 'ncurses')):
            return base, 'ncurses'
        if sys.platform == 'darwin':
            return '', None
        if os.path.exists(os.path.join(base, 'lib', 'libncursesw.so')):
            return base, 'ncursesw'
        if os.path.exists(os.path.join(base, 'lib', 'libncurses.so')):
            return base, 'ncurses'
    return '', None

base, name = find_curses_dir_and_name()
if base:
    include_dirs = [os.path.join(base, 'include', name)]
    library_dirs = [os.path.join(base, 'lib')]
    libs = [name, name.replace('ncurses', 'panel')]
    print('using {} from {}'.format(name, base))
else:
    include_dirs = []
    library_dirs = []
    libs = [find_library(['ncursesw', 'ncurses']),
                find_library(['panelw', 'panel']),
           ]
    print('using {} from general compiler paths'.format(libs[0]))

ffi = FFI()
ffi.set_source("_curses_cffi", """
#ifdef __APPLE__
/* the following define is necessary for OS X 10.6+; without it, the
   Apple-supplied ncurses.h sets NCURSES_OPAQUE to 1, and then Python
   can't get at the WINDOW flags field. */
#define NCURSES_OPAQUE 0
#endif

/* explicitly opt into this, rather than relying on _XOPEN_SOURCE */
#define NCURSES_WIDECHAR 1

/* ncurses 6 change behaviour  and makes all pointers opaque, 
  lets define backward compatibility. It doesn't harm 
  previous versions */

#define NCURSES_INTERNALS 1
#define NCURSES_REENTRANT 0
#include <ncurses.h>
#include <panel.h>
#include <term.h>

#if defined STRICT_SYSV_CURSES
#define _m_STRICT_SYSV_CURSES TRUE
#else
#define _m_STRICT_SYSV_CURSES FALSE
#endif

#if defined NCURSES_MOUSE_VERSION
#define _m_NCURSES_MOUSE_VERSION TRUE
#else
#define _m_NCURSES_MOUSE_VERSION FALSE
#endif

#if defined __NetBSD__
#define _m_NetBSD TRUE
#else
#define _m_NetBSD FALSE
#endif

int _m_ispad(WINDOW *win) {
    // <curses.h> may not have _flags (and possibly _ISPAD),
    // but for now let's assume that <ncurses.h> always has it
    return (win->_flags & _ISPAD);
}

void _m_getsyx(int *yx) {
    getsyx(yx[0], yx[1]);
}
""", libraries=libs,
     library_dirs = library_dirs,
     include_dirs=include_dirs,
)


ffi.cdef("""
typedef ... WINDOW;
typedef ... SCREEN;
typedef unsigned long... mmask_t;
typedef unsigned char bool;
typedef unsigned long... chtype;
typedef chtype attr_t;

typedef struct
{
    short id;           /* ID to distinguish multiple devices */
    int x, y, z;        /* event coordinates (character-cell) */
    mmask_t bstate;     /* button state bits */
}
MEVENT;

static const int ERR, OK;
static const int TRUE, FALSE;
static const int KEY_MIN, KEY_MAX;
static const int KEY_CODE_YES;

static const int COLOR_BLACK;
static const int COLOR_RED;
static const int COLOR_GREEN;
static const int COLOR_YELLOW;
static const int COLOR_BLUE;
static const int COLOR_MAGENTA;
static const int COLOR_CYAN;
static const int COLOR_WHITE;

static const chtype A_ATTRIBUTES;
static const chtype A_NORMAL;
static const chtype A_STANDOUT;
static const chtype A_UNDERLINE;
static const chtype A_REVERSE;
static const chtype A_BLINK;
static const chtype A_DIM;
static const chtype A_BOLD;
static const chtype A_ALTCHARSET;
static const chtype A_INVIS;
static const chtype A_PROTECT;
static const chtype A_CHARTEXT;
static const chtype A_COLOR;

static const chtype A_HORIZONTAL;
static const chtype A_LEFT;
static const chtype A_LOW;
static const chtype A_RIGHT;
static const chtype A_TOP;
static const chtype A_VERTICAL;

static const int BUTTON1_RELEASED;
static const int BUTTON1_PRESSED;
static const int BUTTON1_CLICKED;
static const int BUTTON1_DOUBLE_CLICKED;
static const int BUTTON1_TRIPLE_CLICKED;
static const int BUTTON2_RELEASED;
static const int BUTTON2_PRESSED;
static const int BUTTON2_CLICKED;
static const int BUTTON2_DOUBLE_CLICKED;
static const int BUTTON2_TRIPLE_CLICKED;
static const int BUTTON3_RELEASED;
static const int BUTTON3_PRESSED;
static const int BUTTON3_CLICKED;
static const int BUTTON3_DOUBLE_CLICKED;
static const int BUTTON3_TRIPLE_CLICKED;
static const int BUTTON4_RELEASED;
static const int BUTTON4_PRESSED;
static const int BUTTON4_CLICKED;
static const int BUTTON4_DOUBLE_CLICKED;
static const int BUTTON4_TRIPLE_CLICKED;
static const int BUTTON_SHIFT;
static const int BUTTON_CTRL;
static const int BUTTON_ALT;
static const int ALL_MOUSE_EVENTS;
static const int REPORT_MOUSE_POSITION;

int setupterm(char *, int, int *);

extern WINDOW *stdscr;
extern int COLORS;
extern int COLOR_PAIRS;
extern int COLS;
extern int LINES;

int baudrate(void);
int beep(void);
int box(WINDOW *, chtype, chtype);
bool can_change_color(void);
int cbreak(void);
int clearok(WINDOW *, bool);
int color_content(short, short*, short*, short*);
int copywin(const WINDOW*, WINDOW*, int, int, int, int, int, int, int);
int curs_set(int);
int def_prog_mode(void);
int def_shell_mode(void);
int delay_output(int);
int delwin(WINDOW *);
WINDOW * derwin(WINDOW *, int, int, int, int);
int doupdate(void);
int echo(void);
int endwin(void);
char erasechar(void);
void filter(void);
int flash(void);
int flushinp(void);
chtype getbkgd(WINDOW *);
WINDOW * getwin(FILE *);
int halfdelay(int);
bool has_colors(void);
bool has_ic(void);
bool has_il(void);
void idcok(WINDOW *, bool);
int idlok(WINDOW *, bool);
void immedok(WINDOW *, bool);
WINDOW * initscr(void);
int init_color(short, short, short, short);
int init_pair(short, short, short);
int intrflush(WINDOW *, bool);
bool isendwin(void);
bool is_linetouched(WINDOW *, int);
bool is_wintouched(WINDOW *);
const char * keyname(int);
int keypad(WINDOW *, bool);
char killchar(void);
int leaveok(WINDOW *, bool);
char * longname(void);
int meta(WINDOW *, bool);
int mvderwin(WINDOW *, int, int);
int mvwaddch(WINDOW *, int, int, const chtype);
int mvwaddnstr(WINDOW *, int, int, const char *, int);
int mvwaddstr(WINDOW *, int, int, const char *);
int mvwchgat(WINDOW *, int, int, int, attr_t, short, const void *);
int mvwdelch(WINDOW *, int, int);
int mvwgetch(WINDOW *, int, int);
int mvwgetnstr(WINDOW *, int, int, char *, int);
int mvwin(WINDOW *, int, int);
chtype mvwinch(WINDOW *, int, int);
int mvwinnstr(WINDOW *, int, int, char *, int);
int mvwinsch(WINDOW *, int, int, chtype);
int mvwinsnstr(WINDOW *, int, int, const char *, int);
int mvwinsstr(WINDOW *, int, int, const char *);
int napms(int);
WINDOW * newpad(int, int);
WINDOW * newwin(int, int, int, int);
int nl(void);
int nocbreak(void);
int nodelay(WINDOW *, bool);
int noecho(void);
int nonl(void);
void noqiflush(void);
int noraw(void);
int notimeout(WINDOW *, bool);
int overlay(const WINDOW*, WINDOW *);
int overwrite(const WINDOW*, WINDOW *);
int pair_content(short, short*, short*);
int pechochar(WINDOW *, const chtype);
int pnoutrefresh(WINDOW*, int, int, int, int, int, int);
int prefresh(WINDOW *, int, int, int, int, int, int);
int putwin(WINDOW *, FILE *);
void qiflush(void);
int raw(void);
int redrawwin(WINDOW *);
int resetty(void);
int reset_prog_mode(void);
int reset_shell_mode(void);
int resizeterm(int, int);
int resize_term(int, int);
int savetty(void);
int scroll(WINDOW *);
int scrollok(WINDOW *, bool);
int start_color(void);
WINDOW * subpad(WINDOW *, int, int, int, int);
WINDOW * subwin(WINDOW *, int, int, int, int);
int syncok(WINDOW *, bool);
chtype termattrs(void);
char * termname(void);
int touchline(WINDOW *, int, int);
int touchwin(WINDOW *);
int typeahead(int);
int ungetch(int);
int untouchwin(WINDOW *);
void use_env(bool);
int waddch(WINDOW *, const chtype);
int waddnstr(WINDOW *, const char *, int);
int waddstr(WINDOW *, const char *);
int wattron(WINDOW *, int);
int wattroff(WINDOW *, int);
int wattrset(WINDOW *, int);
int wbkgd(WINDOW *, chtype);
void wbkgdset(WINDOW *, chtype);
int wborder(WINDOW *, chtype, chtype, chtype, chtype,
            chtype, chtype, chtype, chtype);
int wchgat(WINDOW *, int, attr_t, short, const void *);
int wclear(WINDOW *);
int wclrtobot(WINDOW *);
int wclrtoeol(WINDOW *);
void wcursyncup(WINDOW *);
int wdelch(WINDOW *);
int wdeleteln(WINDOW *);
int wechochar(WINDOW *, const chtype);
int werase(WINDOW *);
int wgetch(WINDOW *);
int wgetnstr(WINDOW *, char *, int);
int whline(WINDOW *, chtype, int);
chtype winch(WINDOW *);
int winnstr(WINDOW *, char *, int);
int winsch(WINDOW *, chtype);
int winsdelln(WINDOW *, int);
int winsertln(WINDOW *);
int winsnstr(WINDOW *, const char *, int);
int winsstr(WINDOW *, const char *);
int wmove(WINDOW *, int, int);
int wresize(WINDOW *, int, int);
int wnoutrefresh(WINDOW *);
int wredrawln(WINDOW *, int, int);
int wrefresh(WINDOW *);
int wscrl(WINDOW *, int);
int wsetscrreg(WINDOW *, int, int);
int wstandout(WINDOW *);
int wstandend(WINDOW *);
void wsyncdown(WINDOW *);
void wsyncup(WINDOW *);
void wtimeout(WINDOW *, int);
int wtouchln(WINDOW *, int, int, int);
int wvline(WINDOW *, chtype, int);
int tigetflag(char *);
int tigetnum(char *);
char * tigetstr(char *);
int putp(const char *);
char * tparm(const char *, ...);
int getattrs(const WINDOW *);
int getcurx(const WINDOW *);
int getcury(const WINDOW *);
int getbegx(const WINDOW *);
int getbegy(const WINDOW *);
int getmaxx(const WINDOW *);
int getmaxy(const WINDOW *);
int getparx(const WINDOW *);
int getpary(const WINDOW *);

int getmouse(MEVENT *);
int ungetmouse(MEVENT *);
mmask_t mousemask(mmask_t, mmask_t *);
bool wenclose(const WINDOW *, int, int);
int mouseinterval(int);

void setsyx(int y, int x);
const char *unctrl(chtype);
int use_default_colors(void);

int has_key(int);
bool is_term_resized(int, int);

#define _m_STRICT_SYSV_CURSES ...
#define _m_NCURSES_MOUSE_VERSION ...
#define _m_NetBSD ...
int _m_ispad(WINDOW *);

extern chtype acs_map[];

// For _curses_panel:

typedef ... PANEL;

WINDOW *panel_window(const PANEL *);
void update_panels(void);
int hide_panel(PANEL *);
int show_panel(PANEL *);
int del_panel(PANEL *);
int top_panel(PANEL *);
int bottom_panel(PANEL *);
PANEL *new_panel(WINDOW *);
PANEL *panel_above(const PANEL *);
PANEL *panel_below(const PANEL *);
int set_panel_userptr(PANEL *, void *);
const void *panel_userptr(const PANEL *);
int move_panel(PANEL *, int, int);
int replace_panel(PANEL *,WINDOW *);
int panel_hidden(const PANEL *);

void _m_getsyx(int *yx);
""")

if 'ncursesw' in libs:
    ffi.cdef("""
typedef int... wint_t;
int wget_wch(WINDOW *, wint_t *);
int mvwget_wch(WINDOW *, int, int, wint_t *);
int unget_wch(const wchar_t);
""")


if __name__ == "__main__":
    ffi.compile()
