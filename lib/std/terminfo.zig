//! Routines for working with terminfo files.
//! terminfo files are a semi-standardised format that contains information on
//! how to interact with hundreds of terminals.
//! e.g. you can ask "what is the escape sequence to go back a column"

// The compiled format is documented in man 5 term
// The textual format is documented in man 5 terminfo

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Enums taken from term.h

const Booleans = enum {
    auto_left_margin = 0,
    auto_right_margin = 1,
    no_esc_ctlc = 2,
    ceol_standout_glitch = 3,
    eat_newline_glitch = 4,
    erase_overstrike = 5,
    generic_type = 6,
    hard_copy = 7,
    has_meta_key = 8,
    has_status_line = 9,
    insert_null_glitch = 10,
    memory_above = 11,
    memory_below = 12,
    move_insert_mode = 13,
    move_standout_mode = 14,
    over_strike = 15,
    status_line_esc_ok = 16,
    dest_tabs_magic_smso = 17,
    tilde_glitch = 18,
    transparent_underline = 19,
    xon_xoff = 20,
    needs_xon_xoff = 21,
    prtr_silent = 22,
    hard_cursor = 23,
    non_rev_rmcup = 24,
    no_pad_char = 25,
    non_dest_scroll_region = 26,
    can_change = 27,
    back_color_erase = 28,
    hue_lightness_saturation = 29,
    col_addr_glitch = 30,
    cr_cancels_micro_mode = 31,
    has_print_wheel = 32,
    row_addr_glitch = 33,
    semi_auto_right_margin = 34,
    cpi_changes_res = 35,
    lpi_changes_res = 36,

    // internal caps

    backspaces_with_bs = 37,
    crt_no_scrolling = 38,
    no_correctly_working_cr = 39,
    gnu_has_meta_key = 40,
    linefeed_is_newline = 41,
    has_hardware_tabs = 42,
    return_does_clr_eol = 43,

    // Aliases

    pub const bw = @This().auto_left_margin;
    pub const am = @This().auto_right_margin;
    pub const bce = @This().back_color_erase;
    pub const ccc = @This().can_change;
    pub const xhp = @This().ceol_standout_glitch;
    pub const xhpa = @This().col_addr_glitch;
    pub const cpix = @This().cpi_changes_res;
    pub const crxm = @This().cr_cancels_micro_mode;
    pub const xt = @This().dest_tabs_magic_smso;
    pub const xenl = @This().eat_newline_glitch;
    pub const eo = @This().erase_overstrike;
    pub const gn = @This().generic_type;
    pub const hc = @This().hard_copy;
    pub const chts = @This().hard_cursor;
    pub const km = @This().has_meta_key;
    pub const daisy = @This().has_print_wheel;
    pub const hs = @This().has_status_line;
    pub const hls = @This().hue_lightness_saturation;
    pub const @"in" = @This().insert_null_glitch;
    pub const lpix = @This().lpi_changes_res;
    pub const da = @This().memory_above;
    pub const db = @This().memory_below;
    pub const mir = @This().move_insert_mode;
    pub const msgr = @This().move_standout_mode;
    pub const nxon = @This().needs_xon_xoff;
    pub const xsb = @This().no_esc_ctlc;
    pub const npc = @This().no_pad_char;
    pub const ndscr = @This().non_dest_scroll_region;
    pub const nrrmc = @This().non_rev_rmcup;
    pub const os = @This().over_strike;
    pub const mc5i = @This().prtr_silent;
    pub const xvpa = @This().row_addr_glitch;
    pub const sam = @This().semi_auto_right_margin;
    pub const eslok = @This().status_line_esc_ok;
    pub const hz = @This().tilde_glitch;
    pub const ul = @This().transparent_underline;
    pub const xon = @This().xon_xoff;
};

const Numbers = enum {
    columns = 0,
    init_tabs = 1,
    lines = 2,
    lines_of_memory = 3,
    magic_cookie_glitch = 4,
    padding_baud_rate = 5,
    virtual_terminal = 6,
    width_status_line = 7,
    num_labels = 8,
    label_height = 9,
    label_width = 10,
    max_attributes = 11,
    maximum_windows = 12,
    max_colors = 13,
    max_pairs = 14,
    no_color_video = 15,
    buffer_capacity = 16,
    dot_vert_spacing = 17,
    dot_horz_spacing = 18,
    max_micro_address = 19,
    max_micro_jump = 20,
    micro_col_size = 21,
    micro_line_size = 22,
    number_of_pins = 23,
    output_res_char = 24,
    output_res_line = 25,
    output_res_horz_inch = 26,
    output_res_vert_inch = 27,
    print_rate = 28,
    wide_char_size = 29,
    buttons = 30,
    bit_image_entwining = 31,
    bit_image_type = 32,

    // internal caps

    magic_cookie_glitch_ul = 33,
    carriage_return_delay = 34,
    new_line_delay = 35,
    backspace_delay = 36,
    horizontal_tab_delay = 37,
    number_of_function_keys = 38,

    // Aliases

    pub const cols = @This().columns;
    pub const it = @This().init_tabs;
    pub const lh = @This().label_height;
    pub const lw = @This().label_width;
    pub const lines = @This().lines;
    pub const lm = @This().lines_of_memory;
    pub const xmc = @This().magic_cookie_glitch;
    pub const ma = @This().max_attributes;
    pub const colors = @This().max_colors;
    pub const pairs = @This().max_pairs;
    pub const wnum = @This().maximum_windows;
    pub const ncv = @This().no_color_video;
    pub const nlab = @This().num_labels;
    pub const pb = @This().padding_baud_rate;
    pub const vt = @This().virtual_terminal;
    pub const wsl = @This().width_status_line;

    // Non-SVr4.0
    pub const bitwin = @This().bit_image_entwining;
    pub const bitype = @This().bit_image_type;
    pub const bufsz = @This().buffer_capacity;
    pub const btns = @This().buttons;
    pub const spinh = @This().dot_horz_spacing;
    pub const spinv = @This().dot_vert_spacing;
    pub const maddr = @This().max_micro_address;
    pub const mjump = @This().max_micro_jump;
    pub const mcs = @This().micro_col_size;
    pub const mls = @This().micro_line_size;
    pub const npins = @This().number_of_pins;
    pub const orc = @This().output_res_char;
    pub const orhi = @This().output_res_horz_inch;
    pub const orl = @This().output_res_line;
    pub const orvi = @This().output_res_vert_inch;
    pub const cps = @This().print_rate;
    pub const widcs = @This().wide_char_size;
};

const Strings = enum {
    back_tab = 0,
    bell = 1,
    carriage_return = 2,
    change_scroll_region = 3,
    clear_all_tabs = 4,
    clear_screen = 5,
    clr_eol = 6,
    clr_eos = 7,
    column_address = 8,
    command_character = 9,
    cursor_address = 10,
    cursor_down = 11,
    cursor_home = 12,
    cursor_invisible = 13,
    cursor_left = 14,
    cursor_mem_address = 15,
    cursor_normal = 16,
    cursor_right = 17,
    cursor_to_ll = 18,
    cursor_up = 19,
    cursor_visible = 20,
    delete_character = 21,
    delete_line = 22,
    dis_status_line = 23,
    down_half_line = 24,
    enter_alt_charset_mode = 25,
    enter_blink_mode = 26,
    enter_bold_mode = 27,
    enter_ca_mode = 28,
    enter_delete_mode = 29,
    enter_dim_mode = 30,
    enter_insert_mode = 31,
    enter_secure_mode = 32,
    enter_protected_mode = 33,
    enter_reverse_mode = 34,
    enter_standout_mode = 35,
    enter_underline_mode = 36,
    erase_chars = 37,
    exit_alt_charset_mode = 38,
    exit_attribute_mode = 39,
    exit_ca_mode = 40,
    exit_delete_mode = 41,
    exit_insert_mode = 42,
    exit_standout_mode = 43,
    exit_underline_mode = 44,
    flash_screen = 45,
    form_feed = 46,
    from_status_line = 47,
    init_1string = 48,
    init_2string = 49,
    init_3string = 50,
    init_file = 51,
    insert_character = 52,
    insert_line = 53,
    insert_padding = 54,
    key_backspace = 55,
    key_catab = 56,
    key_clear = 57,
    key_ctab = 58,
    key_dc = 59,
    key_dl = 60,
    key_down = 61,
    key_eic = 62,
    key_eol = 63,
    key_eos = 64,
    key_f0 = 65,
    key_f1 = 66,
    key_f10 = 67,
    key_f2 = 68,
    key_f3 = 69,
    key_f4 = 70,
    key_f5 = 71,
    key_f6 = 72,
    key_f7 = 73,
    key_f8 = 74,
    key_f9 = 75,
    key_home = 76,
    key_ic = 77,
    key_il = 78,
    key_left = 79,
    key_ll = 80,
    key_npage = 81,
    key_ppage = 82,
    key_right = 83,
    key_sf = 84,
    key_sr = 85,
    key_stab = 86,
    key_up = 87,
    keypad_local = 88,
    keypad_xmit = 89,
    lab_f0 = 90,
    lab_f1 = 91,
    lab_f10 = 92,
    lab_f2 = 93,
    lab_f3 = 94,
    lab_f4 = 95,
    lab_f5 = 96,
    lab_f6 = 97,
    lab_f7 = 98,
    lab_f8 = 99,
    lab_f9 = 100,
    meta_off = 101,
    meta_on = 102,
    newline = 103,
    pad_char = 104,
    parm_dch = 105,
    parm_delete_line = 106,
    parm_down_cursor = 107,
    parm_ich = 108,
    parm_index = 109,
    parm_insert_line = 110,
    parm_left_cursor = 111,
    parm_right_cursor = 112,
    parm_rindex = 113,
    parm_up_cursor = 114,
    pkey_key = 115,
    pkey_local = 116,
    pkey_xmit = 117,
    print_screen = 118,
    prtr_off = 119,
    prtr_on = 120,
    repeat_char = 121,
    reset_1string = 122,
    reset_2string = 123,
    reset_3string = 124,
    reset_file = 125,
    restore_cursor = 126,
    row_address = 127,
    save_cursor = 128,
    scroll_forward = 129,
    scroll_reverse = 130,
    set_attributes = 131,
    set_tab = 132,
    set_window = 133,
    tab = 134,
    to_status_line = 135,
    underline_char = 136,
    up_half_line = 137,
    init_prog = 138,
    key_a1 = 139,
    key_a3 = 140,
    key_b2 = 141,
    key_c1 = 142,
    key_c3 = 143,
    prtr_non = 144,
    char_padding = 145,
    acs_chars = 146,
    plab_norm = 147,
    key_btab = 148,
    enter_xon_mode = 149,
    exit_xon_mode = 150,
    enter_am_mode = 151,
    exit_am_mode = 152,
    xon_character = 153,
    xoff_character = 154,
    ena_acs = 155,
    label_on = 156,
    label_off = 157,
    key_beg = 158,
    key_cancel = 159,
    key_close = 160,
    key_command = 161,
    key_copy = 162,
    key_create = 163,
    key_end = 164,
    key_enter = 165,
    key_exit = 166,
    key_find = 167,
    key_help = 168,
    key_mark = 169,
    key_message = 170,
    key_move = 171,
    key_next = 172,
    key_open = 173,
    key_options = 174,
    key_previous = 175,
    key_print = 176,
    key_redo = 177,
    key_reference = 178,
    key_refresh = 179,
    key_replace = 180,
    key_restart = 181,
    key_resume = 182,
    key_save = 183,
    key_suspend = 184,
    key_undo = 185,
    key_sbeg = 186,
    key_scancel = 187,
    key_scommand = 188,
    key_scopy = 189,
    key_screate = 190,
    key_sdc = 191,
    key_sdl = 192,
    key_select = 193,
    key_send = 194,
    key_seol = 195,
    key_sexit = 196,
    key_sfind = 197,
    key_shelp = 198,
    key_shome = 199,
    key_sic = 200,
    key_sleft = 201,
    key_smessage = 202,
    key_smove = 203,
    key_snext = 204,
    key_soptions = 205,
    key_sprevious = 206,
    key_sprint = 207,
    key_sredo = 208,
    key_sreplace = 209,
    key_sright = 210,
    key_srsume = 211,
    key_ssave = 212,
    key_ssuspend = 213,
    key_sundo = 214,
    req_for_input = 215,
    key_f11 = 216,
    key_f12 = 217,
    key_f13 = 218,
    key_f14 = 219,
    key_f15 = 220,
    key_f16 = 221,
    key_f17 = 222,
    key_f18 = 223,
    key_f19 = 224,
    key_f20 = 225,
    key_f21 = 226,
    key_f22 = 227,
    key_f23 = 228,
    key_f24 = 229,
    key_f25 = 230,
    key_f26 = 231,
    key_f27 = 232,
    key_f28 = 233,
    key_f29 = 234,
    key_f30 = 235,
    key_f31 = 236,
    key_f32 = 237,
    key_f33 = 238,
    key_f34 = 239,
    key_f35 = 240,
    key_f36 = 241,
    key_f37 = 242,
    key_f38 = 243,
    key_f39 = 244,
    key_f40 = 245,
    key_f41 = 246,
    key_f42 = 247,
    key_f43 = 248,
    key_f44 = 249,
    key_f45 = 250,
    key_f46 = 251,
    key_f47 = 252,
    key_f48 = 253,
    key_f49 = 254,
    key_f50 = 255,
    key_f51 = 256,
    key_f52 = 257,
    key_f53 = 258,
    key_f54 = 259,
    key_f55 = 260,
    key_f56 = 261,
    key_f57 = 262,
    key_f58 = 263,
    key_f59 = 264,
    key_f60 = 265,
    key_f61 = 266,
    key_f62 = 267,
    key_f63 = 268,
    clr_bol = 269,
    clear_margins = 270,
    set_left_margin = 271,
    set_right_margin = 272,
    label_format = 273,
    set_clock = 274,
    display_clock = 275,
    remove_clock = 276,
    create_window = 277,
    goto_window = 278,
    hangup = 279,
    dial_phone = 280,
    quick_dial = 281,
    tone = 282,
    pulse = 283,
    flash_hook = 284,
    fixed_pause = 285,
    wait_tone = 286,
    user0 = 287,
    user1 = 288,
    user2 = 289,
    user3 = 290,
    user4 = 291,
    user5 = 292,
    user6 = 293,
    user7 = 294,
    user8 = 295,
    user9 = 296,
    orig_pair = 297,
    orig_colors = 298,
    initialize_color = 299,
    initialize_pair = 300,
    set_color_pair = 301,
    set_foreground = 302,
    set_background = 303,
    change_char_pitch = 304,
    change_line_pitch = 305,
    change_res_horz = 306,
    change_res_vert = 307,
    define_char = 308,
    enter_doublewide_mode = 309,
    enter_draft_quality = 310,
    enter_italics_mode = 311,
    enter_leftward_mode = 312,
    enter_micro_mode = 313,
    enter_near_letter_quality = 314,
    enter_normal_quality = 315,
    enter_shadow_mode = 316,
    enter_subscript_mode = 317,
    enter_superscript_mode = 318,
    enter_upward_mode = 319,
    exit_doublewide_mode = 320,
    exit_italics_mode = 321,
    exit_leftward_mode = 322,
    exit_micro_mode = 323,
    exit_shadow_mode = 324,
    exit_subscript_mode = 325,
    exit_superscript_mode = 326,
    exit_upward_mode = 327,
    micro_column_address = 328,
    micro_down = 329,
    micro_left = 330,
    micro_right = 331,
    micro_row_address = 332,
    micro_up = 333,
    order_of_pins = 334,
    parm_down_micro = 335,
    parm_left_micro = 336,
    parm_right_micro = 337,
    parm_up_micro = 338,
    select_char_set = 339,
    set_bottom_margin = 340,
    set_bottom_margin_parm = 341,
    set_left_margin_parm = 342,
    set_right_margin_parm = 343,
    set_top_margin = 344,
    set_top_margin_parm = 345,
    start_bit_image = 346,
    start_char_set_def = 347,
    stop_bit_image = 348,
    stop_char_set_def = 349,
    subscript_characters = 350,
    superscript_characters = 351,
    these_cause_cr = 352,
    zero_motion = 353,
    char_set_names = 354,
    key_mouse = 355,
    mouse_info = 356,
    req_mouse_pos = 357,
    get_mouse = 358,
    set_a_foreground = 359,
    set_a_background = 360,
    pkey_plab = 361,
    device_type = 362,
    code_set_init = 363,
    set0_des_seq = 364,
    set1_des_seq = 365,
    set2_des_seq = 366,
    set3_des_seq = 367,
    set_lr_margin = 368,
    set_tb_margin = 369,
    bit_image_repeat = 370,
    bit_image_newline = 371,
    bit_image_carriage_return = 372,
    color_names = 373,
    define_bit_image_region = 374,
    end_bit_image_region = 375,
    set_color_band = 376,
    set_page_length = 377,
    display_pc_char = 378,
    enter_pc_charset_mode = 379,
    exit_pc_charset_mode = 380,
    enter_scancode_mode = 381,
    exit_scancode_mode = 382,
    pc_term_options = 383,
    scancode_escape = 384,
    alt_scancode_esc = 385,
    enter_horizontal_hl_mode = 386,
    enter_left_hl_mode = 387,
    enter_low_hl_mode = 388,
    enter_right_hl_mode = 389,
    enter_top_hl_mode = 390,
    enter_vertical_hl_mode = 391,
    set_a_attributes = 392,
    set_pglen_inch = 393,

    // internal caps
    termcap_init2 = 394,
    termcap_reset = 395,
    linefeed_if_not_lf = 396,
    backspace_if_not_bs = 397,
    other_non_function_keys = 398,
    arrow_key_map = 399,
    acs_ulcorner = 400,
    acs_llcorner = 401,
    acs_urcorner = 402,
    acs_lrcorner = 403,
    acs_ltee = 404,
    acs_rtee = 405,
    acs_btee = 406,
    acs_ttee = 407,
    acs_hline = 408,
    acs_vline = 409,
    acs_plus = 410,
    memory_lock = 411,
    memory_unlock = 412,
    box_chars_1 = 413,

    // Aliases

    pub const acsc = @This().acs_chars;
    pub const cbt = @This().back_tab;
    pub const bel = @This().bell;
    pub const cr = @This().carriage_return;
    pub const cpi = @This().change_char_pitch;
    pub const lpi = @This().change_line_pitch;
    pub const chr = @This().change_res_horz;
    pub const cvr = @This().change_res_vert;
    pub const csr = @This().change_scroll_region;
    pub const rmp = @This().char_padding;
    pub const tbc = @This().clear_all_tabs;
    pub const mgc = @This().clear_margins;
    pub const clear = @This().clear_screen;
    pub const el1 = @This().clr_bol;
    pub const el = @This().clr_eol;
    pub const ed = @This().clr_eos;
    pub const hpa = @This().column_address;
    pub const cmdch = @This().command_character;
    pub const cwin = @This().create_window;
    pub const cup = @This().cursor_address;
    pub const cud1 = @This().cursor_down;
    pub const home = @This().cursor_home;
    pub const civis = @This().cursor_invisible;
    pub const cub1 = @This().cursor_left;
    pub const mrcup = @This().cursor_mem_address;
    pub const cnorm = @This().cursor_normal;
    pub const cuf1 = @This().cursor_right;
    pub const ll = @This().cursor_to_ll;
    pub const cuu1 = @This().cursor_up;
    pub const cvvis = @This().cursor_visible;
    pub const defc = @This().define_char;
    pub const dch1 = @This().delete_character;
    pub const dl1 = @This().delete_line;
    pub const dial = @This().dial_phone;
    pub const dsl = @This().dis_status_line;
    pub const dclk = @This().display_clock;
    pub const hd = @This().down_half_line;
    pub const enacs = @This().ena_acs;
    pub const smacs = @This().enter_alt_charset_mode;
    pub const smam = @This().enter_am_mode;
    pub const blink = @This().enter_blink_mode;
    pub const bold = @This().enter_bold_mode;
    pub const smcup = @This().enter_ca_mode;
    pub const smdc = @This().enter_delete_mode;
    pub const dim = @This().enter_dim_mode;
    pub const swidm = @This().enter_doublewide_mode;
    pub const sdrfq = @This().enter_draft_quality;
    pub const smir = @This().enter_insert_mode;
    pub const sitm = @This().enter_italics_mode;
    pub const slm = @This().enter_leftward_mode;
    pub const smicm = @This().enter_micro_mode;
    pub const snlq = @This().enter_near_letter_quality;
    pub const snrmq = @This().enter_normal_quality;
    pub const prot = @This().enter_protected_mode;
    pub const rev = @This().enter_reverse_mode;
    pub const invis = @This().enter_secure_mode;
    pub const sshm = @This().enter_shadow_mode;
    pub const smso = @This().enter_standout_mode;
    pub const ssubm = @This().enter_subscript_mode;
    pub const ssupm = @This().enter_superscript_mode;
    pub const smul = @This().enter_underline_mode;
    pub const sum = @This().enter_upward_mode;
    pub const smxon = @This().enter_xon_mode;
    pub const ech = @This().erase_chars;
    pub const rmacs = @This().exit_alt_charset_mode;
    pub const rmam = @This().exit_am_mode;
    pub const sgr0 = @This().exit_attribute_mode;
    pub const rmcup = @This().exit_ca_mode;
    pub const rmdc = @This().exit_delete_mode;
    pub const rwidm = @This().exit_doublewide_mode;
    pub const rmir = @This().exit_insert_mode;
    pub const ritm = @This().exit_italics_mode;
    pub const rlm = @This().exit_leftward_mode;
    pub const rmicm = @This().exit_micro_mode;
    pub const rshm = @This().exit_shadow_mode;
    pub const rmso = @This().exit_standout_mode;
    pub const rsubm = @This().exit_subscript_mode;
    pub const rsupm = @This().exit_superscript_mode;
    pub const rmul = @This().exit_underline_mode;
    pub const rum = @This().exit_upward_mode;
    pub const rmxon = @This().exit_xon_mode;
    pub const pause = @This().fixed_pause;
    pub const hook = @This().flash_hook;
    pub const flash = @This().flash_screen;
    pub const ff = @This().form_feed;
    pub const fsl = @This().from_status_line;
    pub const wingo = @This().goto_window;
    pub const hup = @This().hangup;
    pub const is1 = @This().init_1string;
    pub const is2 = @This().init_2string;
    pub const is3 = @This().init_3string;
    pub const @"if" = @This().init_file;
    pub const iprog = @This().init_prog;
    pub const initc = @This().initialize_color;
    pub const initp = @This().initialize_pair;
    pub const ich1 = @This().insert_character;
    pub const il1 = @This().insert_line;
    pub const ip = @This().insert_padding;
    pub const ka1 = @This().key_a1;
    pub const ka3 = @This().key_a3;
    pub const kb2 = @This().key_b2;
    pub const kbs = @This().key_backspace;
    pub const kbeg = @This().key_beg;
    pub const kcbt = @This().key_btab;
    pub const kc1 = @This().key_c1;
    pub const kc3 = @This().key_c3;
    pub const kcan = @This().key_cancel;
    pub const ktbc = @This().key_catab;
    pub const kclr = @This().key_clear;
    pub const kclo = @This().key_close;
    pub const kcmd = @This().key_command;
    pub const kcpy = @This().key_copy;
    pub const kcrt = @This().key_create;
    pub const kctab = @This().key_ctab;
    pub const kdch1 = @This().key_dc;
    pub const kdl1 = @This().key_dl;
    pub const kcud1 = @This().key_down;
    pub const krmir = @This().key_eic;
    pub const kend = @This().key_end;
    pub const kent = @This().key_enter;
    pub const kel = @This().key_eol;
    pub const ked = @This().key_eos;
    pub const kext = @This().key_exit;
    pub const kf0 = @This().key_f0;
    pub const kf1 = @This().key_f1;
    pub const kf10 = @This().key_f10;
    pub const kf11 = @This().key_f11;
    pub const kf12 = @This().key_f12;
    pub const kf13 = @This().key_f13;
    pub const kf14 = @This().key_f14;
    pub const kf15 = @This().key_f15;
    pub const kf16 = @This().key_f16;
    pub const kf17 = @This().key_f17;
    pub const kf18 = @This().key_f18;
    pub const kf19 = @This().key_f19;
    pub const kf2 = @This().key_f2;
    pub const kf20 = @This().key_f20;
    pub const kf21 = @This().key_f21;
    pub const kf22 = @This().key_f22;
    pub const kf23 = @This().key_f23;
    pub const kf24 = @This().key_f24;
    pub const kf25 = @This().key_f25;
    pub const kf26 = @This().key_f26;
    pub const kf27 = @This().key_f27;
    pub const kf28 = @This().key_f28;
    pub const kf29 = @This().key_f29;
    pub const kf3 = @This().key_f3;
    pub const kf30 = @This().key_f30;
    pub const kf31 = @This().key_f31;
    pub const kf32 = @This().key_f32;
    pub const kf33 = @This().key_f33;
    pub const kf34 = @This().key_f34;
    pub const kf35 = @This().key_f35;
    pub const kf36 = @This().key_f36;
    pub const kf37 = @This().key_f37;
    pub const kf38 = @This().key_f38;
    pub const kf39 = @This().key_f39;
    pub const kf4 = @This().key_f4;
    pub const kf40 = @This().key_f40;
    pub const kf41 = @This().key_f41;
    pub const kf42 = @This().key_f42;
    pub const kf43 = @This().key_f43;
    pub const kf44 = @This().key_f44;
    pub const kf45 = @This().key_f45;
    pub const kf46 = @This().key_f46;
    pub const kf47 = @This().key_f47;
    pub const kf48 = @This().key_f48;
    pub const kf49 = @This().key_f49;
    pub const kf5 = @This().key_f5;
    pub const kf50 = @This().key_f50;
    pub const kf51 = @This().key_f51;
    pub const kf52 = @This().key_f52;
    pub const kf53 = @This().key_f53;
    pub const kf54 = @This().key_f54;
    pub const kf55 = @This().key_f55;
    pub const kf56 = @This().key_f56;
    pub const kf57 = @This().key_f57;
    pub const kf58 = @This().key_f58;
    pub const kf59 = @This().key_f59;
    pub const kf6 = @This().key_f6;
    pub const kf60 = @This().key_f60;
    pub const kf61 = @This().key_f61;
    pub const kf62 = @This().key_f62;
    pub const kf63 = @This().key_f63;
    pub const kf7 = @This().key_f7;
    pub const kf8 = @This().key_f8;
    pub const kf9 = @This().key_f9;
    pub const kfnd = @This().key_find;
    pub const khlp = @This().key_help;
    pub const khome = @This().key_home;
    pub const kich1 = @This().key_ic;
    pub const kil1 = @This().key_il;
    pub const kcub1 = @This().key_left;
    pub const kll = @This().key_ll;
    pub const kmrk = @This().key_mark;
    pub const kmsg = @This().key_message;
    pub const kmov = @This().key_move;
    pub const knxt = @This().key_next;
    pub const knp = @This().key_npage;
    pub const kopn = @This().key_open;
    pub const kopt = @This().key_options;
    pub const kpp = @This().key_ppage;
    pub const kprv = @This().key_previous;
    pub const kprt = @This().key_print;
    pub const krdo = @This().key_redo;
    pub const kref = @This().key_reference;
    pub const krfr = @This().key_refresh;
    pub const krpl = @This().key_replace;
    pub const krst = @This().key_restart;
    pub const kres = @This().key_resume;
    pub const kcuf1 = @This().key_right;
    pub const ksav = @This().key_save;
    pub const kBEG = @This().key_sbeg;
    pub const kCAN = @This().key_scancel;
    pub const kCMD = @This().key_scommand;
    pub const kCPY = @This().key_scopy;
    pub const kCRT = @This().key_screate;
    pub const kDC = @This().key_sdc;
    pub const kDL = @This().key_sdl;
    pub const kslt = @This().key_select;
    pub const kEND = @This().key_send;
    pub const kEOL = @This().key_seol;
    pub const kEXT = @This().key_sexit;
    pub const kind = @This().key_sf;
    pub const kFND = @This().key_sfind;
    pub const kHLP = @This().key_shelp;
    pub const kHOM = @This().key_shome;
    pub const kIC = @This().key_sic;
    pub const kLFT = @This().key_sleft;
    pub const kMSG = @This().key_smessage;
    pub const kMOV = @This().key_smove;
    pub const kNXT = @This().key_snext;
    pub const kOPT = @This().key_soptions;
    pub const kPRV = @This().key_sprevious;
    pub const kPRT = @This().key_sprint;
    pub const kri = @This().key_sr;
    pub const kRDO = @This().key_sredo;
    pub const kRPL = @This().key_sreplace;
    pub const kRIT = @This().key_sright;
    pub const kRES = @This().key_srsume;
    pub const kSAV = @This().key_ssave;
    pub const kSPD = @This().key_ssuspend;
    pub const khts = @This().key_stab;
    pub const kUND = @This().key_sundo;
    pub const kspd = @This().key_suspend;
    pub const kund = @This().key_undo;
    pub const kcuu1 = @This().key_up;
    pub const rmkx = @This().keypad_local;
    pub const smkx = @This().keypad_xmit;
    pub const lf0 = @This().lab_f0;
    pub const lf1 = @This().lab_f1;
    pub const lf10 = @This().lab_f10;
    pub const lf2 = @This().lab_f2;
    pub const lf3 = @This().lab_f3;
    pub const lf4 = @This().lab_f4;
    pub const lf5 = @This().lab_f5;
    pub const lf6 = @This().lab_f6;
    pub const lf7 = @This().lab_f7;
    pub const lf8 = @This().lab_f8;
    pub const lf9 = @This().lab_f9;
    pub const fln = @This().label_format;
    pub const rmln = @This().label_off;
    pub const smln = @This().label_on;
    pub const rmm = @This().meta_off;
    pub const smm = @This().meta_on;
    pub const mhpa = @This().micro_column_address;
    pub const mcud1 = @This().micro_down;
    pub const mcub1 = @This().micro_left;
    pub const mcuf1 = @This().micro_right;
    pub const mvpa = @This().micro_row_address;
    pub const mcuu1 = @This().micro_up;
    pub const nel = @This().newline;
    pub const porder = @This().order_of_pins;
    pub const oc = @This().orig_colors;
    pub const op = @This().orig_pair;
    pub const pad = @This().pad_char;
    pub const dch = @This().parm_dch;
    pub const dl = @This().parm_delete_line;
    pub const cud = @This().parm_down_cursor;
    pub const mcud = @This().parm_down_micro;
    pub const ich = @This().parm_ich;
    pub const indn = @This().parm_index;
    pub const il = @This().parm_insert_line;
    pub const cub = @This().parm_left_cursor;
    pub const mcub = @This().parm_left_micro;
    pub const cuf = @This().parm_right_cursor;
    pub const mcuf = @This().parm_right_micro;
    pub const rin = @This().parm_rindex;
    pub const cuu = @This().parm_up_cursor;
    pub const mcuu = @This().parm_up_micro;
    pub const pfkey = @This().pkey_key;
    pub const pfloc = @This().pkey_local;
    pub const pfx = @This().pkey_xmit;
    pub const pln = @This().plab_norm;
    pub const mc0 = @This().print_screen;
    pub const mc5p = @This().prtr_non;
    pub const mc4 = @This().prtr_off;
    pub const mc5 = @This().prtr_on;
    pub const pulse = @This().pulse;
    pub const qdial = @This().quick_dial;
    pub const rmclk = @This().remove_clock;
    pub const rep = @This().repeat_char;
    pub const rfi = @This().req_for_input;
    pub const rs1 = @This().reset_1string;
    pub const rs2 = @This().reset_2string;
    pub const rs3 = @This().reset_3string;
    pub const rf = @This().reset_file;
    pub const rc = @This().restore_cursor;
    pub const vpa = @This().row_address;
    pub const sc = @This().save_cursor;
    pub const ind = @This().scroll_forward;
    pub const ri = @This().scroll_reverse;
    pub const scs = @This().select_char_set;
    pub const sgr = @This().set_attributes;
    pub const setb = @This().set_background;
    pub const smgb = @This().set_bottom_margin;
    pub const smgbp = @This().set_bottom_margin_parm;
    pub const sclk = @This().set_clock;
    pub const scp = @This().set_color_pair;
    pub const setf = @This().set_foreground;
    pub const smgl = @This().set_left_margin;
    pub const smglp = @This().set_left_margin_parm;
    pub const smgr = @This().set_right_margin;
    pub const smgrp = @This().set_right_margin_parm;
    pub const hts = @This().set_tab;
    pub const smgt = @This().set_top_margin;
    pub const smgtp = @This().set_top_margin_parm;
    pub const wind = @This().set_window;
    pub const sbim = @This().start_bit_image;
    pub const scsd = @This().start_char_set_def;
    pub const rbim = @This().stop_bit_image;
    pub const rcsd = @This().stop_char_set_def;
    pub const subcs = @This().subscript_characters;
    pub const supcs = @This().superscript_characters;
    pub const ht = @This().tab;
    pub const docr = @This().these_cause_cr;
    pub const tsl = @This().to_status_line;
    pub const tone = @This().tone;
    pub const uc = @This().underline_char;
    pub const hu = @This().up_half_line;
    // TODO: these shadow zig primitives: https://github.com/ziglang/zig/issues/6062
    // pub const u0 = @This().user0;
    // pub const u1 = @This().user1;
    // pub const u2 = @This().user2;
    // pub const u3 = @This().user3;
    // pub const u4 = @This().user4;
    // pub const u5 = @This().user5;
    // pub const u6 = @This().user6;
    // pub const u7 = @This().user7;
    // pub const u8 = @This().user8;
    // pub const u9 = @This().user9;
    pub const wait = @This().wait_tone;
    pub const xoffc = @This().xoff_character;
    pub const xonc = @This().xon_character;
    pub const zerom = @This().zero_motion;

    // Non-SVr4.0 String
    pub const scesa = @This().alt_scancode_esc;
    pub const bicr = @This().bit_image_carriage_return;
    pub const binel = @This().bit_image_newline;
    pub const birep = @This().bit_image_repeat;
    pub const csnm = @This().char_set_names;
    pub const csin = @This().code_set_init;
    pub const colornm = @This().color_names;
    pub const defbi = @This().define_bit_image_region;
    pub const devt = @This().device_type;
    pub const dispc = @This().display_pc_char;
    pub const endbi = @This().end_bit_image_region;
    pub const smpch = @This().enter_pc_charset_mode;
    pub const smsc = @This().enter_scancode_mode;
    pub const rmpch = @This().exit_pc_charset_mode;
    pub const rmsc = @This().exit_scancode_mode;
    pub const getm = @This().get_mouse;
    pub const kmous = @This().key_mouse;
    pub const minfo = @This().mouse_info;
    pub const pctrm = @This().pc_term_options;
    pub const pfxl = @This().pkey_plab;
    pub const reqmp = @This().req_mouse_pos;
    pub const scesc = @This().scancode_escape;
    pub const s0ds = @This().set0_des_seq;
    pub const s1ds = @This().set1_des_seq;
    pub const s2ds = @This().set2_des_seq;
    pub const s3ds = @This().set3_des_seq;
    pub const setab = @This().set_a_background;
    pub const setaf = @This().set_a_foreground;
    pub const setcolor = @This().set_color_band;
    pub const smglr = @This().set_lr_margin;
    pub const slines = @This().set_page_length;
    pub const smgtb = @This().set_tb_margin;

    // XSI
    pub const ehhlm = @This().enter_horizontal_hl_mode;
    pub const elhlm = @This().enter_left_hl_mode;
    pub const elohlm = @This().enter_low_hl_mode;
    pub const erhlm = @This().enter_right_hl_mode;
    pub const ethlm = @This().enter_top_hl_mode;
    pub const evhlm = @This().enter_vertical_hl_mode;
    pub const sgr1 = @This().set_a_attributes;
    pub const slength = @This().set_pglen_inch;
};

pub const Capabilities = struct {
    allocator: *Allocator,

    /// | separated list of terminal names
    /// Use `nameIterator` to access.
    names: [:0]const u8,

    booleans: [@typeInfo(Booleans).Enum.fields.len]bool,
    /// highest integer (available as NumberMissing) means capability missing
    // was u16 in legacy format; but upgraded to u32 in ncurses 6.1
    numbers: [@typeInfo(Numbers).Enum.fields.len]u32,

    /// 65534 means capability 'cancelled'
    /// 65535 means capability missing
    string_offsets: [@typeInfo(Strings).Enum.fields.len]u16,

    string_table: [:0]const u8,

    pub fn deinit(self: @This()) void {
        self.allocator.free(self.names);
        self.allocator.free(self.string_table);
    }

    pub fn nameIterator(self: @This()) std.mem.TokenIterator {
        return std.mem.tokenize(self.names, &[_]u8{'|'});
    }

    pub fn getBoolean(self: @This(), cap: Booleans) bool {
        return self.booleans[@enumToInt(cap)];
    }

    /// The special value that indicates that a numeric value is unknown
    pub const NumberMissing = std.math.maxInt(u32);

    pub fn getNumber(self: @This(), cap: Numbers) ?u32 {
        const n = self.numbers[@enumToInt(cap)];
        if (n == NumberMissing) return null;
        return n;
    }

    pub fn getString(self: @This(), cap: Strings) !?[:0]const u8 {
        const o = self.string_offsets[@enumToInt(cap)];
        if (o == 65535 or o == 65534) return null;
        if (o > self.string_table.len) return error.InvalidStringOffset;
        return std.mem.spanZ(self.string_table[o..:0]);
    }

    /// Reads a binary terminfo file
    /// Assumes that the magic byte has already been read
    fn readCompiledTerminfo(comptime number_size: type, allocator: *Allocator, reader: anytype) !Capabilities {
        // read header
        var name_size = try reader.readIntLittle(u16);
        var n_booleans = try reader.readIntLittle(u16);
        var n_numbers = try reader.readIntLittle(u16);
        var n_offsets = try reader.readIntLittle(u16);
        const s_string = try reader.readIntLittle(u16);

        if (name_size == 65535) {
            name_size = 0;
        }
        const names = if (name_size == 0)
            try allocator.allocWithOptions(u8, 0, null, 0)
        else blk: {
            const names = try allocator.alloc(u8, name_size);
            errdefer allocator.free(names);
            try reader.readNoEof(names);
            if (names[names.len - 1] != 0) return error.InvalidTerminfo;
            break :blk names[0 .. name_size - 1 :0];
        };
        errdefer allocator.free(names);

        if (n_booleans == 65535) {
            n_booleans = 0;
        }
        var booleans = [_]bool{false} ** @typeInfo(Booleans).Enum.fields.len;
        {
            var i: u16 = 0;
            while (i < n_booleans) : (i += 1) {
                booleans[i] = switch (try reader.readByte()) {
                    0 => false,
                    1 => true,
                    else => return error.InvalidBoolean,
                };
            }
        }

        // pad to even offset
        if ((name_size ^ n_booleans) & 1 == 1) {
            _ = try reader.readByte();
        }

        if (n_numbers == 65535) {
            n_numbers = 0;
        }
        var numbers = [_]u32{NumberMissing} ** @typeInfo(Numbers).Enum.fields.len;
        {
            var i: u16 = 0;
            while (i < n_numbers) : (i += 1) {
                const n = try reader.readIntLittle(number_size);
                numbers[i] = switch (number_size) {
                    u16 => if (n == 65535) NumberMissing else @as(u32, n),
                    u32 => n,
                    else => @compileError("invalid type for terminfo database numeric type"),
                };
            }
        }

        if (n_offsets == 65535) {
            n_offsets = 0;
        }
        var string_offsets = [_]u16{65535} ** @typeInfo(Strings).Enum.fields.len;
        {
            var i: u16 = 0;
            while (i < n_offsets) : (i += 1) {
                string_offsets[i] = try reader.readIntLittle(u16);
            }
        }

        const string_table = if (s_string == 0)
            try allocator.allocWithOptions(u8, 0, null, 0)
        else blk: {
            const string_table = try allocator.alloc(u8, s_string);
            errdefer allocator.free(string_table);
            try reader.readNoEof(string_table);
            if (string_table[string_table.len - 1] != 0) return error.InvalidTerminfo;
            break :blk string_table[0 .. s_string - 1 :0];
        };

        return Capabilities{
            .allocator = allocator,
            .names = names,
            .booleans = booleans,
            .numbers = numbers,
            .string_offsets = string_offsets,
            .string_table = string_table,
        };
    }

    fn readTextTerminfo(allocator: *Allocator, reader: anytype) !Capabilities {
        @panic("NYI");
    }

    pub fn readTerminfo(allocator: *Allocator, reader: anytype) !Capabilities {
        const magic = try reader.readBytesNoEof(2);
        switch (std.mem.readIntLittle(u16, &magic)) {
            282 => return try readCompiledTerminfo(u16, allocator, reader),
            // e.g. on an ArchLinux system dvtm-256color is in the extended format
            542 => return try readCompiledTerminfo(u32, allocator, reader),
            else => {
                var peek_reader = std.io.PeekStream(.{ .Static = 2 }, @TypeOf(reader)).init(reader);
                try peek_reader.putBack(&magic);
                return try readTextTerminfo(allocator, peek_reader.reader());
            },
        }
    }

    pub fn readTerminfoFromFile(allocator: *Allocator, fd: std.fs.File) !Capabilities {
        const reader = fd.reader();
        var bufferedReader = std.io.bufferedReader(reader);
        return try readTerminfo(allocator, bufferedReader.reader());
    }

    pub fn getTerminfo(allocator: *Allocator, path: []const u8) !Capabilities {
        const fd = try fs.cwd().openFile(path, .{});
        defer fd.close();
        return try readTerminfoFromFile(allocator, fd);
    }
};

test "can parse binary format" {
    var buf: [308]u8 = undefined;
    try std.fmt.hexToBytes(&buf,
        // contents of /usr/share/terminfo/d/dumb
        "1a011800020001008200080064756d627c38302d636f6c756d6e2064756d6220" ++
        "7474790000015000ffff00000200ffffffffffffffffffffffffffffffff0400" ++
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ++
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ++
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ++
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ++
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ++
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ++
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ++
        "ffffffffffffffffffff060007000d000a000a00"
    );
    var fbs = std.io.fixedBufferStream(&buf);

    const ti = try Capabilities.readTerminfo(testing.allocator, fbs.reader());
    defer ti.deinit();

    testing.expect(ti.getBoolean(.auto_right_margin));
    testing.expect(ti.getBoolean(Booleans.am));
    testing.expect(!ti.getBoolean(Booleans.ccc));
    testing.expectEqual(@as(?u32, 80), ti.getNumber(.columns));
    testing.expectEqual(@as(?u32, 80), ti.getNumber(Numbers.cols));
    testing.expectEqual(@as(?u32, null), ti.getNumber(.buttons));
    testing.expectEqual(@as(?u32, null), ti.getNumber(Numbers.btns));
    testing.expectEqualSlices(u8, "\x07", (try ti.getString(Strings.bel)).?);
    testing.expectEqual(@as(?[:0]const u8, null), (try ti.getString(Strings.bold)));
}

test "can parse text format" {
    if (true) return error.SkipZigTest;

    var fbs = std.io.fixedBufferStream(
        \\#   Reconstructed via infocmp from file: /usr/share/terminfo/d/dumb
        \\dumb|80-column dumb tty,
        \\    am,
        \\    cols#80,
        \\    bel=^G, cr=\r, cud1=\n, ind=\n,
    );

    const ti = try Capabilities.readTerminfo(testing.allocator, fbs.reader());
    defer ti.deinit();

    testing.expect(ti.getBoolean(.auto_right_margin));
    testing.expect(ti.getBoolean(Booleans.am));
    testing.expect(!ti.getBoolean(Booleans.ccc));
    testing.expectEqual(@as(?u32, 80), ti.getNumber(.columns));
    testing.expectEqual(@as(?u32, 80), ti.getNumber(Numbers.cols));
    testing.expectEqual(@as(?u32, null), ti.getNumber(.buttons));
    testing.expectEqual(@as(?u32, null), ti.getNumber(Numbers.btns));
    testing.expectEqualSlices(u8, "\x07", (try ti.getString(Strings.bel)).?);
    testing.expectEqual(@as(?[:0]const u8, null), (try ti.getString(Strings.bold)));
}

const default_system_dir = "/usr/share/terminfo";

pub fn getDefaultDirs(allocator: *Allocator) ![][]const u8 {
    var dirs_dynamic = std.ArrayList([]const u8).init(allocator);
    errdefer dirs_dynamic.deinit();
    errdefer freeDefaultDirs(allocator, dirs_dynamic.items);

    if (std.os.getenv("TERMINFO")) |TERMINFO| {
        try dirs_dynamic.ensureCapacity(1);
        dirs_dynamic.appendAssumeCapacity(try std.mem.dupe(allocator, u8, std.mem.trimRight(u8, TERMINFO, &[_]u8{'/'})));
    } else {
        if (std.os.getenv("HOME")) |HOME| {
            try dirs_dynamic.ensureCapacity(1);
            dirs_dynamic.appendAssumeCapacity(try std.fs.path.join(allocator, &[_][]const u8{ HOME, ".terminfo" }));
        }

        if (std.os.getenv("TERMINFO_DIRS")) |TERMINFO_DIRS| {
            var it = std.mem.tokenize(TERMINFO_DIRS, ":");
            while (it.next()) |dir| {
                try dirs_dynamic.ensureCapacity(dirs_dynamic.items.len + 1);
                const dir_allocated = try std.mem.dupe(allocator, u8, if (dir.len == 0) default_system_dir else std.mem.trimRight(u8, dir, &[_]u8{'/'}));
                dirs_dynamic.appendAssumeCapacity(dir_allocated);
            }
        } else {
            try dirs_dynamic.ensureCapacity(dirs_dynamic.items.len + 1);
            dirs_dynamic.appendAssumeCapacity(try std.mem.dupe(allocator, u8, default_system_dir));
        }
    }
    return dirs_dynamic.toOwnedSlice();
}

pub fn freeDefaultDirs(allocator: *Allocator, dirs: []const []const u8) void {
    for (dirs) |d| {
        allocator.free(d);
    }
    allocator.free(dirs);
}

pub fn findTerminfo(allocator: *Allocator, term: ?[]const u8, dirs: ?[]const []const u8) !Capabilities {
    const term_ = term orelse std.os.getenv("TERM") orelse return error.UnsetTERM;
    if (std.mem.indexOfScalar(u8, term_, '/') != null) return error.InvalidTERM;

    var dirs_needs_free = false;
    const dirs_ = dirs orelse blk: {
        dirs_needs_free = true;
        break :blk try getDefaultDirs(allocator);
    };
    defer if (dirs_needs_free) freeDefaultDirs(allocator, dirs_);

    const file: std.fs.File = for (dirs_) |dir| {
        var b = blk: {
            var a = std.fs.cwd().openDir(dir, .{}) catch |e| switch (e) {
                error.FileNotFound => continue,
                else => return e,
            };
            defer a.close();
            break :blk a.openDir(term_[0..1], .{}) catch |e| switch (e) {
                // On some systems, the subdirectory is the first char's byte as hex
                // See: https://invisible-island.net/ncurses/NEWS.html#t20071117
                error.FileNotFound => {
                    var buf: [2]u8 = undefined;
                    _ = std.fmt.bufPrint(&buf, "{x:02}", .{term_[0..1]}) catch unreachable;
                    break :blk a.openDir(&buf, .{}) catch |e2| switch (e2) {
                        error.FileNotFound => continue,
                        else => return e2,
                    };
                },
                else => return e,
            };
        };
        defer b.close();

        break b.openFile(term_, .{}) catch |e| switch (e) {
            error.FileNotFound => continue,
            else => return e,
        };
    } else return error.UnknownTerminal;
    defer file.close();
    return try Capabilities.readTerminfoFromFile(allocator, file);
}
