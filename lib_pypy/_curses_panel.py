"Reimplementation of the standard extension module '_curses_panel' using cffi."

from _curses import _ensure_initialised, _check_ERR, error, ffi, lib


def _call_lib(method_name, *args):
    return getattr(lib, method_name)(*args)


def _call_lib_check_ERR(method_name, *args):
    return _check_ERR(_call_lib(method_name, *args), method_name)


def _mk_no_arg_no_return(method_name):
    def _execute():
        _ensure_initialised()
        return _call_lib_check_ERR(method_name)
    _execute.__name__ = method_name
    return _execute


def _mk_no_arg_return_val(method_name):
    def _execute():
        return _call_lib(method_name)
    _execute.__name__ = method_name
    return _execute


def _mk_args_no_return(method_name):
    def _execute(*args):
        return _call_lib_check_ERR(method_name, *args)
    _execute.__name__ = method_name
    return _execute


# ____________________________________________________________


bottom_panel = _mk_no_arg_no_return("bottom_panel")
hide_panel = _mk_no_arg_no_return("hide_panel")
show_panel = _mk_no_arg_no_return("show_panel")
top_panel = _mk_no_arg_no_return("top_panel")
panel_hidden = _mk_no_arg_return_val("panel_hidden")
move_panel = _mk_args_no_return("move_panel")


_panels = []


def _add_panel(panel):
    _panels.insert(0, panel)


def _remove_panel(panel):
    _panels.remove(panel)


def _find_panel(pan):
    for panel in _panels:
        if panel._pan == pan:
            return panel
    return None


class Panel(object):
    def __init__(self, pan, window):
        self._pan = pan
        self._window = window
        _add_panel(self)

    def __del__(self):
        _remove_panel(self)
        lib.del_panel(self._pan)

    def above(self):
        pan = lib.panel_above(self._pan)
        if pan == ffi.NULL:
            return None
        return _find_panel(pan)

    def below(self):
        pan = lib.panel_below(self._pan)
        if pan == ffi.NULL:
            return None
        return _find_panel(pan)

    def window(self):
        return self._window

    def replace_panel(self, window):
        panel = _find_panel(self._pan)
        _check_ERR(lib.replace_panel(self._pan, window._win), "replace_panel")
        panel._window = window
        return None

    def set_panel_userptr(self, obj):
        code = lib.set_panel_userptr(self._pan, ffi.cast("void *", obj))
        return _check_ERR(code, "set_panel_userptr")

    def userptr(self):
        # XXX: This is probably wrong.
        obj = lib.panel_userptr(self._pan)
        if obj == ffi.NULL:
            raise error("no userptr set")
        return obj


def bottom_panel():
    _ensure_initialised()
    pan = lib.panel_above(ffi.NULL)
    if pan == ffi.NULL:
        return None
    return _find_panel(pan)


def new_panel(window):
    pan = lib.new_panel(window._win)
    return Panel(pan, window)


def panel_below():
    _ensure_initialised()
    pan = lib.panel_below(ffi.NULL)
    if pan == ffi.NULL:
        return None
    return _find_panel(pan)


def update_panels():
    _ensure_initialised()
    lib.update_panels()
    return None
