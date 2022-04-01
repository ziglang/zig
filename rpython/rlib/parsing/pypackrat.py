
from rpython.rlib.parsing.tree import Nonterminal, Symbol
from rpython.rlib.parsing.makepackrat import PackratParser, BacktrackException, Status


class Parser(object):
    def NAME(self):
        return self._NAME().result
    def _NAME(self):
        _key = self._pos
        _status = self._dict_NAME.get(_key, None)
        if _status is None:
            _status = self._dict_NAME[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _result = self._regex1074651696()
            assert _status.status != _status.LEFTRECURSION
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = _exc.error
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def SPACE(self):
        return self._SPACE().result
    def _SPACE(self):
        _key = self._pos
        _status = self._dict_SPACE.get(_key, None)
        if _status is None:
            _status = self._dict_SPACE[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _result = self.__chars__(' ')
            assert _status.status != _status.LEFTRECURSION
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = _exc.error
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def COMMENT(self):
        return self._COMMENT().result
    def _COMMENT(self):
        _key = self._pos
        _status = self._dict_COMMENT.get(_key, None)
        if _status is None:
            _status = self._dict_COMMENT[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _result = self._regex528667127()
            assert _status.status != _status.LEFTRECURSION
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = _exc.error
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def IGNORE(self):
        return self._IGNORE().result
    def _IGNORE(self):
        _key = self._pos
        _status = self._dict_IGNORE.get(_key, None)
        if _status is None:
            _status = self._dict_IGNORE[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _result = self._regex1979538501()
            assert _status.status != _status.LEFTRECURSION
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = _exc.error
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def newline(self):
        return self._newline().result
    def _newline(self):
        _key = self._pos
        _status = self._dict_newline.get(_key, None)
        if _status is None:
            _status = self._dict_newline[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            while 1:
                _choice0 = self._pos
                try:
                    _call_status = self._COMMENT()
                    _result = _call_status.result
                    _error = _call_status.error
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice0
                _choice1 = self._pos
                try:
                    _result = self._regex299149370()
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice1
                    raise BacktrackException(_error)
                _result = self._regex299149370()
                break
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._newline()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def REGEX(self):
        return self._REGEX().result
    def _REGEX(self):
        _key = self._pos
        _status = self._dict_REGEX.get(_key, None)
        if _status is None:
            _status = self._dict_REGEX[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _result = self._regex1006631623()
            r = _result
            _result = (Symbol('REGEX', r, None))
            assert _status.status != _status.LEFTRECURSION
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = _exc.error
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def QUOTE(self):
        return self._QUOTE().result
    def _QUOTE(self):
        _key = self._pos
        _status = self._dict_QUOTE.get(_key, None)
        if _status is None:
            _status = self._dict_QUOTE[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _result = self._regex1124192327()
            r = _result
            _result = (Symbol('QUOTE', r, None))
            assert _status.status != _status.LEFTRECURSION
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = _exc.error
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def PYTHONCODE(self):
        return self._PYTHONCODE().result
    def _PYTHONCODE(self):
        _key = self._pos
        _status = self._dict_PYTHONCODE.get(_key, None)
        if _status is None:
            _status = self._dict_PYTHONCODE[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _result = self._regex291086639()
            r = _result
            _result = (Symbol('PYTHONCODE', r, None))
            assert _status.status != _status.LEFTRECURSION
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = _exc.error
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def EOF(self):
        return self._EOF().result
    def _EOF(self):
        _key = self._pos
        _status = self._dict_EOF.get(_key, None)
        if _status is None:
            _status = self._dict_EOF[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _choice0 = self._pos
            _stored_result1 = _result
            try:
                _result = self.__any__()
            except BacktrackException:
                self._pos = _choice0
                _result = _stored_result1
            else:
                raise BacktrackException(None)
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._EOF()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = _exc.error
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def file(self):
        return self._file().result
    def _file(self):
        _key = self._pos
        _status = self._dict_file.get(_key, None)
        if _status is None:
            _status = self._dict_file[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _all0 = []
            while 1:
                _choice1 = self._pos
                try:
                    _call_status = self._IGNORE()
                    _result = _call_status.result
                    _error = _call_status.error
                    _all0.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice1
                    break
            _result = _all0
            _call_status = self._list()
            _result = _call_status.result
            _error = self._combine_errors(_error, _call_status.error)
            _before_discard2 = _result
            _call_status = self._EOF()
            _result = _call_status.result
            _error = self._combine_errors(_error, _call_status.error)
            _result = _before_discard2
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._file()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def list(self):
        return self._list().result
    def _list(self):
        _key = self._pos
        _status = self._dict_list.get(_key, None)
        if _status is None:
            _status = self._dict_list[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _all0 = []
            _call_status = self._production()
            _result = _call_status.result
            _error = _call_status.error
            _all0.append(_result)
            while 1:
                _choice1 = self._pos
                try:
                    _call_status = self._production()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all0.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice1
                    break
            _result = _all0
            content = _result
            _result = (Nonterminal('list', content))
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._list()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def production(self):
        return self._production().result
    def _production(self):
        _key = self._pos
        _status = self._dict_production.get(_key, None)
        if _status is None:
            _status = self._dict_production[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _call_status = self._NAME()
            _result = _call_status.result
            _error = _call_status.error
            name = _result
            _all0 = []
            while 1:
                _choice1 = self._pos
                try:
                    _call_status = self._SPACE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all0.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice1
                    break
            _result = _all0
            _call_status = self._productionargs()
            _result = _call_status.result
            _error = self._combine_errors(_error, _call_status.error)
            args = _result
            _result = self.__chars__(':')
            _all2 = []
            while 1:
                _choice3 = self._pos
                try:
                    _call_status = self._IGNORE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all2.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice3
                    break
            _result = _all2
            _call_status = self._or_()
            _result = _call_status.result
            _error = self._combine_errors(_error, _call_status.error)
            what = _result
            _all4 = []
            while 1:
                _choice5 = self._pos
                try:
                    _call_status = self._IGNORE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all4.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice5
                    break
            _result = _all4
            _result = self.__chars__(';')
            _all6 = []
            while 1:
                _choice7 = self._pos
                try:
                    _call_status = self._IGNORE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all6.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice7
                    break
            _result = _all6
            _result = (Nonterminal('production', [name, args, what]))
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._production()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def productionargs(self):
        return self._productionargs().result
    def _productionargs(self):
        _key = self._pos
        _status = self._dict_productionargs.get(_key, None)
        if _status is None:
            _status = self._dict_productionargs[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            while 1:
                _choice0 = self._pos
                try:
                    _result = self.__chars__('(')
                    _all1 = []
                    while 1:
                        _choice2 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = _call_status.error
                            _all1.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice2
                            break
                    _result = _all1
                    _all3 = []
                    while 1:
                        _choice4 = self._pos
                        try:
                            _call_status = self._NAME()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _before_discard5 = _result
                            _all6 = []
                            while 1:
                                _choice7 = self._pos
                                try:
                                    _call_status = self._IGNORE()
                                    _result = _call_status.result
                                    _error = self._combine_errors(_error, _call_status.error)
                                    _all6.append(_result)
                                except BacktrackException as _exc:
                                    _error = self._combine_errors(_error, _exc.error)
                                    self._pos = _choice7
                                    break
                            _result = _all6
                            _result = self.__chars__(',')
                            _all8 = []
                            while 1:
                                _choice9 = self._pos
                                try:
                                    _call_status = self._IGNORE()
                                    _result = _call_status.result
                                    _error = self._combine_errors(_error, _call_status.error)
                                    _all8.append(_result)
                                except BacktrackException as _exc:
                                    _error = self._combine_errors(_error, _exc.error)
                                    self._pos = _choice9
                                    break
                            _result = _all8
                            _result = _before_discard5
                            _all3.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice4
                            break
                    _result = _all3
                    args = _result
                    _call_status = self._NAME()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    arg = _result
                    _all10 = []
                    while 1:
                        _choice11 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all10.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice11
                            break
                    _result = _all10
                    _result = self.__chars__(')')
                    _all12 = []
                    while 1:
                        _choice13 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all12.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice13
                            break
                    _result = _all12
                    _result = (Nonterminal('productionargs', args + [arg]))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice0
                _choice14 = self._pos
                try:
                    _result = (Nonterminal('productionargs', []))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice14
                    raise BacktrackException(_error)
                _result = (Nonterminal('productionargs', []))
                break
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._productionargs()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def or_(self):
        return self._or_().result
    def _or_(self):
        _key = self._pos
        _status = self._dict_or_.get(_key, None)
        if _status is None:
            _status = self._dict_or_[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            while 1:
                _choice0 = self._pos
                try:
                    _all1 = []
                    _call_status = self._commands()
                    _result = _call_status.result
                    _error = _call_status.error
                    _before_discard2 = _result
                    _result = self.__chars__('|')
                    _all3 = []
                    while 1:
                        _choice4 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all3.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice4
                            break
                    _result = _all3
                    _result = _before_discard2
                    _all1.append(_result)
                    while 1:
                        _choice5 = self._pos
                        try:
                            _call_status = self._commands()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _before_discard6 = _result
                            _result = self.__chars__('|')
                            _all7 = []
                            while 1:
                                _choice8 = self._pos
                                try:
                                    _call_status = self._IGNORE()
                                    _result = _call_status.result
                                    _error = self._combine_errors(_error, _call_status.error)
                                    _all7.append(_result)
                                except BacktrackException as _exc:
                                    _error = self._combine_errors(_error, _exc.error)
                                    self._pos = _choice8
                                    break
                            _result = _all7
                            _result = _before_discard6
                            _all1.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice5
                            break
                    _result = _all1
                    l = _result
                    _call_status = self._commands()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    last = _result
                    _result = (Nonterminal('or', l + [last]))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice0
                _choice9 = self._pos
                try:
                    _call_status = self._commands()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice9
                    raise BacktrackException(_error)
                _call_status = self._commands()
                _result = _call_status.result
                _error = self._combine_errors(_error, _call_status.error)
                break
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._or_()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def commands(self):
        return self._commands().result
    def _commands(self):
        _key = self._pos
        _status = self._dict_commands.get(_key, None)
        if _status is None:
            _status = self._dict_commands[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            while 1:
                _choice0 = self._pos
                try:
                    _call_status = self._command()
                    _result = _call_status.result
                    _error = _call_status.error
                    cmd = _result
                    _call_status = self._newline()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all1 = []
                    _call_status = self._command()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _before_discard2 = _result
                    _call_status = self._newline()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _result = _before_discard2
                    _all1.append(_result)
                    while 1:
                        _choice3 = self._pos
                        try:
                            _call_status = self._command()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _before_discard4 = _result
                            _call_status = self._newline()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _result = _before_discard4
                            _all1.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice3
                            break
                    _result = _all1
                    cmds = _result
                    _result = (Nonterminal('commands', [cmd] + cmds))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice0
                _choice5 = self._pos
                try:
                    _call_status = self._command()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice5
                    raise BacktrackException(_error)
                _call_status = self._command()
                _result = _call_status.result
                _error = self._combine_errors(_error, _call_status.error)
                break
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._commands()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def command(self):
        return self._command().result
    def _command(self):
        _key = self._pos
        _status = self._dict_command.get(_key, None)
        if _status is None:
            _status = self._dict_command[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _call_status = self._simplecommand()
            _result = _call_status.result
            _error = _call_status.error
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._command()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def simplecommand(self):
        return self._simplecommand().result
    def _simplecommand(self):
        _key = self._pos
        _status = self._dict_simplecommand.get(_key, None)
        if _status is None:
            _status = self._dict_simplecommand[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            while 1:
                _choice0 = self._pos
                try:
                    _call_status = self._return_()
                    _result = _call_status.result
                    _error = _call_status.error
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice0
                _choice1 = self._pos
                try:
                    _call_status = self._if_()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice1
                _choice2 = self._pos
                try:
                    _call_status = self._named_command()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice2
                _choice3 = self._pos
                try:
                    _call_status = self._repetition()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice3
                _choice4 = self._pos
                try:
                    _call_status = self._choose()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice4
                _choice5 = self._pos
                try:
                    _call_status = self._negation()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice5
                    raise BacktrackException(_error)
                _call_status = self._negation()
                _result = _call_status.result
                _error = self._combine_errors(_error, _call_status.error)
                break
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._simplecommand()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def return_(self):
        return self._return_().result
    def _return_(self):
        _key = self._pos
        _status = self._dict_return_.get(_key, None)
        if _status is None:
            _status = self._dict_return_[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _result = self.__chars__('return')
            _all0 = []
            while 1:
                _choice1 = self._pos
                try:
                    _call_status = self._SPACE()
                    _result = _call_status.result
                    _error = _call_status.error
                    _all0.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice1
                    break
            _result = _all0
            _call_status = self._PYTHONCODE()
            _result = _call_status.result
            _error = self._combine_errors(_error, _call_status.error)
            code = _result
            _all2 = []
            while 1:
                _choice3 = self._pos
                try:
                    _call_status = self._IGNORE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all2.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice3
                    break
            _result = _all2
            _result = (Nonterminal('return', [code]))
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._return_()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def if_(self):
        return self._if_().result
    def _if_(self):
        _key = self._pos
        _status = self._dict_if_.get(_key, None)
        if _status is None:
            _status = self._dict_if_[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            while 1:
                _choice0 = self._pos
                try:
                    _result = self.__chars__('do')
                    _call_status = self._newline()
                    _result = _call_status.result
                    _error = _call_status.error
                    _call_status = self._command()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    cmd = _result
                    _all1 = []
                    while 1:
                        _choice2 = self._pos
                        try:
                            _call_status = self._SPACE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all1.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice2
                            break
                    _result = _all1
                    _result = self.__chars__('if')
                    _all3 = []
                    while 1:
                        _choice4 = self._pos
                        try:
                            _call_status = self._SPACE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all3.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice4
                            break
                    _result = _all3
                    _call_status = self._PYTHONCODE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    condition = _result
                    _all5 = []
                    while 1:
                        _choice6 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all5.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice6
                            break
                    _result = _all5
                    _result = (Nonterminal('if', [cmd, condition]))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice0
                _choice7 = self._pos
                try:
                    _result = self.__chars__('if')
                    _all8 = []
                    while 1:
                        _choice9 = self._pos
                        try:
                            _call_status = self._SPACE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all8.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice9
                            break
                    _result = _all8
                    _call_status = self._PYTHONCODE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    condition = _result
                    _all10 = []
                    while 1:
                        _choice11 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all10.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice11
                            break
                    _result = _all10
                    _result = (Nonterminal('if', [condition]))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice7
                    raise BacktrackException(_error)
                _result = self.__chars__('if')
                _all12 = []
                while 1:
                    _choice13 = self._pos
                    try:
                        _call_status = self._SPACE()
                        _result = _call_status.result
                        _error = self._combine_errors(_error, _call_status.error)
                        _all12.append(_result)
                    except BacktrackException as _exc:
                        _error = self._combine_errors(_error, _exc.error)
                        self._pos = _choice13
                        break
                _result = _all12
                _call_status = self._PYTHONCODE()
                _result = _call_status.result
                _error = self._combine_errors(_error, _call_status.error)
                condition = _result
                _all14 = []
                while 1:
                    _choice15 = self._pos
                    try:
                        _call_status = self._IGNORE()
                        _result = _call_status.result
                        _error = self._combine_errors(_error, _call_status.error)
                        _all14.append(_result)
                    except BacktrackException as _exc:
                        _error = self._combine_errors(_error, _exc.error)
                        self._pos = _choice15
                        break
                _result = _all14
                _result = (Nonterminal('if', [condition]))
                break
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._if_()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def choose(self):
        return self._choose().result
    def _choose(self):
        _key = self._pos
        _status = self._dict_choose.get(_key, None)
        if _status is None:
            _status = self._dict_choose[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _result = self.__chars__('choose')
            _all0 = []
            while 1:
                _choice1 = self._pos
                try:
                    _call_status = self._SPACE()
                    _result = _call_status.result
                    _error = _call_status.error
                    _all0.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice1
                    break
            _result = _all0
            _call_status = self._NAME()
            _result = _call_status.result
            _error = self._combine_errors(_error, _call_status.error)
            name = _result
            _all2 = []
            while 1:
                _choice3 = self._pos
                try:
                    _call_status = self._SPACE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all2.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice3
                    break
            _result = _all2
            _result = self.__chars__('in')
            _all4 = []
            while 1:
                _choice5 = self._pos
                try:
                    _call_status = self._SPACE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all4.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice5
                    break
            _result = _all4
            _call_status = self._PYTHONCODE()
            _result = _call_status.result
            _error = self._combine_errors(_error, _call_status.error)
            expr = _result
            _all6 = []
            while 1:
                _choice7 = self._pos
                try:
                    _call_status = self._IGNORE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all6.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice7
                    break
            _result = _all6
            _call_status = self._commands()
            _result = _call_status.result
            _error = self._combine_errors(_error, _call_status.error)
            cmds = _result
            _result = (Nonterminal('choose', [name, expr, cmds]))
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._choose()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def commandchain(self):
        return self._commandchain().result
    def _commandchain(self):
        _key = self._pos
        _status = self._dict_commandchain.get(_key, None)
        if _status is None:
            _status = self._dict_commandchain[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _all0 = []
            _call_status = self._simplecommand()
            _result = _call_status.result
            _error = _call_status.error
            _all0.append(_result)
            while 1:
                _choice1 = self._pos
                try:
                    _call_status = self._simplecommand()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all0.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice1
                    break
            _result = _all0
            result = _result
            _result = (Nonterminal('commands', result))
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._commandchain()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def named_command(self):
        return self._named_command().result
    def _named_command(self):
        _key = self._pos
        _status = self._dict_named_command.get(_key, None)
        if _status is None:
            _status = self._dict_named_command[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _call_status = self._NAME()
            _result = _call_status.result
            _error = _call_status.error
            name = _result
            _all0 = []
            while 1:
                _choice1 = self._pos
                try:
                    _call_status = self._SPACE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all0.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice1
                    break
            _result = _all0
            _result = self.__chars__('=')
            _all2 = []
            while 1:
                _choice3 = self._pos
                try:
                    _call_status = self._SPACE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all2.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice3
                    break
            _result = _all2
            _call_status = self._command()
            _result = _call_status.result
            _error = self._combine_errors(_error, _call_status.error)
            cmd = _result
            _result = (Nonterminal('named_command', [name, cmd]))
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._named_command()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def repetition(self):
        return self._repetition().result
    def _repetition(self):
        _key = self._pos
        _status = self._dict_repetition.get(_key, None)
        if _status is None:
            _status = self._dict_repetition[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            while 1:
                _choice0 = self._pos
                try:
                    _call_status = self._enclosed()
                    _result = _call_status.result
                    _error = _call_status.error
                    what = _result
                    _all1 = []
                    while 1:
                        _choice2 = self._pos
                        try:
                            _call_status = self._SPACE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all1.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice2
                            break
                    _result = _all1
                    _result = self.__chars__('?')
                    _all3 = []
                    while 1:
                        _choice4 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all3.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice4
                            break
                    _result = _all3
                    _result = (Nonterminal('maybe', [what]))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice0
                _choice5 = self._pos
                try:
                    _call_status = self._enclosed()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    what = _result
                    _all6 = []
                    while 1:
                        _choice7 = self._pos
                        try:
                            _call_status = self._SPACE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all6.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice7
                            break
                    _result = _all6
                    while 1:
                        _choice8 = self._pos
                        try:
                            _result = self.__chars__('*')
                            break
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice8
                        _choice9 = self._pos
                        try:
                            _result = self.__chars__('+')
                            break
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice9
                            raise BacktrackException(_error)
                        _result = self.__chars__('+')
                        break
                    repetition = _result
                    _all10 = []
                    while 1:
                        _choice11 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all10.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice11
                            break
                    _result = _all10
                    _result = (Nonterminal('repetition', [repetition, what]))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice5
                    raise BacktrackException(_error)
                _call_status = self._enclosed()
                _result = _call_status.result
                _error = self._combine_errors(_error, _call_status.error)
                what = _result
                _all12 = []
                while 1:
                    _choice13 = self._pos
                    try:
                        _call_status = self._SPACE()
                        _result = _call_status.result
                        _error = self._combine_errors(_error, _call_status.error)
                        _all12.append(_result)
                    except BacktrackException as _exc:
                        _error = self._combine_errors(_error, _exc.error)
                        self._pos = _choice13
                        break
                _result = _all12
                while 1:
                    _choice14 = self._pos
                    try:
                        _result = self.__chars__('*')
                        break
                    except BacktrackException as _exc:
                        _error = self._combine_errors(_error, _exc.error)
                        self._pos = _choice14
                    _choice15 = self._pos
                    try:
                        _result = self.__chars__('+')
                        break
                    except BacktrackException as _exc:
                        _error = self._combine_errors(_error, _exc.error)
                        self._pos = _choice15
                        raise BacktrackException(_error)
                    _result = self.__chars__('+')
                    break
                repetition = _result
                _all16 = []
                while 1:
                    _choice17 = self._pos
                    try:
                        _call_status = self._IGNORE()
                        _result = _call_status.result
                        _error = self._combine_errors(_error, _call_status.error)
                        _all16.append(_result)
                    except BacktrackException as _exc:
                        _error = self._combine_errors(_error, _exc.error)
                        self._pos = _choice17
                        break
                _result = _all16
                _result = (Nonterminal('repetition', [repetition, what]))
                break
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._repetition()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def negation(self):
        return self._negation().result
    def _negation(self):
        _key = self._pos
        _status = self._dict_negation.get(_key, None)
        if _status is None:
            _status = self._dict_negation[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            while 1:
                _choice0 = self._pos
                try:
                    _result = self.__chars__('!')
                    _all1 = []
                    while 1:
                        _choice2 = self._pos
                        try:
                            _call_status = self._SPACE()
                            _result = _call_status.result
                            _error = _call_status.error
                            _all1.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice2
                            break
                    _result = _all1
                    _call_status = self._negation()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    what = _result
                    _all3 = []
                    while 1:
                        _choice4 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all3.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice4
                            break
                    _result = _all3
                    _result = (Nonterminal('negation', [what]))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice0
                _choice5 = self._pos
                try:
                    _call_status = self._enclosed()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice5
                    raise BacktrackException(_error)
                _call_status = self._enclosed()
                _result = _call_status.result
                _error = self._combine_errors(_error, _call_status.error)
                break
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._negation()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def enclosed(self):
        return self._enclosed().result
    def _enclosed(self):
        _key = self._pos
        _status = self._dict_enclosed.get(_key, None)
        if _status is None:
            _status = self._dict_enclosed[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            while 1:
                _choice0 = self._pos
                try:
                    _result = self.__chars__('<')
                    _all1 = []
                    while 1:
                        _choice2 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = _call_status.error
                            _all1.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice2
                            break
                    _result = _all1
                    _call_status = self._primary()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    what = _result
                    _all3 = []
                    while 1:
                        _choice4 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all3.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice4
                            break
                    _result = _all3
                    _result = self.__chars__('>')
                    _all5 = []
                    while 1:
                        _choice6 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all5.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice6
                            break
                    _result = _all5
                    _result = (Nonterminal('exclusive', [what]))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice0
                _choice7 = self._pos
                try:
                    _result = self.__chars__('[')
                    _all8 = []
                    while 1:
                        _choice9 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all8.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice9
                            break
                    _result = _all8
                    _call_status = self._or_()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    what = _result
                    _all10 = []
                    while 1:
                        _choice11 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all10.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice11
                            break
                    _result = _all10
                    _result = self.__chars__(']')
                    _all12 = []
                    while 1:
                        _choice13 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all12.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice13
                            break
                    _result = _all12
                    _result = (Nonterminal('ignore', [what]))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice7
                _choice14 = self._pos
                try:
                    _before_discard15 = _result
                    _result = self.__chars__('(')
                    _all16 = []
                    while 1:
                        _choice17 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all16.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice17
                            break
                    _result = _all16
                    _result = _before_discard15
                    _call_status = self._or_()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _before_discard18 = _result
                    _result = self.__chars__(')')
                    _all19 = []
                    while 1:
                        _choice20 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all19.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice20
                            break
                    _result = _all19
                    _result = _before_discard18
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice14
                _choice21 = self._pos
                try:
                    _call_status = self._primary()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice21
                    raise BacktrackException(_error)
                _call_status = self._primary()
                _result = _call_status.result
                _error = self._combine_errors(_error, _call_status.error)
                break
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._enclosed()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def primary(self):
        return self._primary().result
    def _primary(self):
        _key = self._pos
        _status = self._dict_primary.get(_key, None)
        if _status is None:
            _status = self._dict_primary[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            while 1:
                _choice0 = self._pos
                try:
                    _call_status = self._call()
                    _result = _call_status.result
                    _error = _call_status.error
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice0
                _choice1 = self._pos
                try:
                    _call_status = self._REGEX()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _before_discard2 = _result
                    _all3 = []
                    while 1:
                        _choice4 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all3.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice4
                            break
                    _result = _all3
                    _result = _before_discard2
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice1
                _choice5 = self._pos
                try:
                    _call_status = self._QUOTE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _before_discard6 = _result
                    _all7 = []
                    while 1:
                        _choice8 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all7.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice8
                            break
                    _result = _all7
                    _result = _before_discard6
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice5
                    raise BacktrackException(_error)
                _call_status = self._QUOTE()
                _result = _call_status.result
                _error = self._combine_errors(_error, _call_status.error)
                _before_discard9 = _result
                _all10 = []
                while 1:
                    _choice11 = self._pos
                    try:
                        _call_status = self._IGNORE()
                        _result = _call_status.result
                        _error = self._combine_errors(_error, _call_status.error)
                        _all10.append(_result)
                    except BacktrackException as _exc:
                        _error = self._combine_errors(_error, _exc.error)
                        self._pos = _choice11
                        break
                _result = _all10
                _result = _before_discard9
                break
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._primary()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def call(self):
        return self._call().result
    def _call(self):
        _key = self._pos
        _status = self._dict_call.get(_key, None)
        if _status is None:
            _status = self._dict_call[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            _call_status = self._NAME()
            _result = _call_status.result
            _error = _call_status.error
            x = _result
            _call_status = self._arguments()
            _result = _call_status.result
            _error = self._combine_errors(_error, _call_status.error)
            args = _result
            _all0 = []
            while 1:
                _choice1 = self._pos
                try:
                    _call_status = self._IGNORE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    _all0.append(_result)
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice1
                    break
            _result = _all0
            _result = (Nonterminal("call", [x, args]))
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._call()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def arguments(self):
        return self._arguments().result
    def _arguments(self):
        _key = self._pos
        _status = self._dict_arguments.get(_key, None)
        if _status is None:
            _status = self._dict_arguments[_key] = Status()
        else:
            _statusstatus = _status.status
            if _statusstatus == _status.NORMAL:
                self._pos = _status.pos
                return _status
            elif _statusstatus == _status.ERROR:
                raise BacktrackException(_status.error)
            elif (_statusstatus == _status.INPROGRESS or
                  _statusstatus == _status.LEFTRECURSION):
                _status.status = _status.LEFTRECURSION
                if _status.result is not None:
                    self._pos = _status.pos
                    return _status
                else:
                    raise BacktrackException(None)
            elif _statusstatus == _status.SOMESOLUTIONS:
                _status.status = _status.INPROGRESS
        _startingpos = self._pos
        try:
            _result = None
            _error = None
            while 1:
                _choice0 = self._pos
                try:
                    _result = self.__chars__('(')
                    _all1 = []
                    while 1:
                        _choice2 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = _call_status.error
                            _all1.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice2
                            break
                    _result = _all1
                    _all3 = []
                    while 1:
                        _choice4 = self._pos
                        try:
                            _call_status = self._PYTHONCODE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _before_discard5 = _result
                            _all6 = []
                            while 1:
                                _choice7 = self._pos
                                try:
                                    _call_status = self._IGNORE()
                                    _result = _call_status.result
                                    _error = self._combine_errors(_error, _call_status.error)
                                    _all6.append(_result)
                                except BacktrackException as _exc:
                                    _error = self._combine_errors(_error, _exc.error)
                                    self._pos = _choice7
                                    break
                            _result = _all6
                            _result = self.__chars__(',')
                            _all8 = []
                            while 1:
                                _choice9 = self._pos
                                try:
                                    _call_status = self._IGNORE()
                                    _result = _call_status.result
                                    _error = self._combine_errors(_error, _call_status.error)
                                    _all8.append(_result)
                                except BacktrackException as _exc:
                                    _error = self._combine_errors(_error, _exc.error)
                                    self._pos = _choice9
                                    break
                            _result = _all8
                            _result = _before_discard5
                            _all3.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice4
                            break
                    _result = _all3
                    args = _result
                    _call_status = self._PYTHONCODE()
                    _result = _call_status.result
                    _error = self._combine_errors(_error, _call_status.error)
                    last = _result
                    _result = self.__chars__(')')
                    _all10 = []
                    while 1:
                        _choice11 = self._pos
                        try:
                            _call_status = self._IGNORE()
                            _result = _call_status.result
                            _error = self._combine_errors(_error, _call_status.error)
                            _all10.append(_result)
                        except BacktrackException as _exc:
                            _error = self._combine_errors(_error, _exc.error)
                            self._pos = _choice11
                            break
                    _result = _all10
                    _result = (Nonterminal("args", args + [last]))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice0
                _choice12 = self._pos
                try:
                    _result = (Nonterminal("args", []))
                    break
                except BacktrackException as _exc:
                    _error = self._combine_errors(_error, _exc.error)
                    self._pos = _choice12
                    raise BacktrackException(_error)
                _result = (Nonterminal("args", []))
                break
            if _status.status == _status.LEFTRECURSION:
                if _status.result is not None:
                    if _status.pos >= self._pos:
                        _status.status = _status.NORMAL
                        self._pos = _status.pos
                        return _status
                _status.pos = self._pos
                _status.status = _status.SOMESOLUTIONS
                _status.result = _result
                _status.error = _error
                self._pos = _startingpos
                return self._arguments()
            _status.status = _status.NORMAL
            _status.pos = self._pos
            _status.result = _result
            _status.error = _error
            return _status
        except BacktrackException as _exc:
            _status.pos = -1
            _status.result = None
            _error = self._combine_errors(_error, _exc.error)
            _status.error = _error
            _status.status = _status.ERROR
            raise BacktrackException(_error)
    def __init__(self, inputstream):
        self._dict_NAME = {}
        self._dict_SPACE = {}
        self._dict_COMMENT = {}
        self._dict_IGNORE = {}
        self._dict_newline = {}
        self._dict_REGEX = {}
        self._dict_QUOTE = {}
        self._dict_PYTHONCODE = {}
        self._dict_EOF = {}
        self._dict_file = {}
        self._dict_list = {}
        self._dict_production = {}
        self._dict_productionargs = {}
        self._dict_or_ = {}
        self._dict_commands = {}
        self._dict_command = {}
        self._dict_simplecommand = {}
        self._dict_return_ = {}
        self._dict_if_ = {}
        self._dict_choose = {}
        self._dict_commandchain = {}
        self._dict_named_command = {}
        self._dict_repetition = {}
        self._dict_negation = {}
        self._dict_enclosed = {}
        self._dict_primary = {}
        self._dict_call = {}
        self._dict_arguments = {}
        self._pos = 0
        self._inputstream = inputstream
    def _regex299149370(self):
        _choice13 = self._pos
        _runner = self._Runner(self._inputstream, self._pos)
        _i = _runner.recognize_299149370(self._pos)
        if _runner.last_matched_state == -1:
            self._pos = _choice13
            raise BacktrackException
        _upto = _runner.last_matched_index + 1
        _pos = self._pos
        assert _pos >= 0
        assert _upto >= 0
        _result = self._inputstream[_pos: _upto]
        self._pos = _upto
        return _result
    def _regex1006631623(self):
        _choice14 = self._pos
        _runner = self._Runner(self._inputstream, self._pos)
        _i = _runner.recognize_1006631623(self._pos)
        if _runner.last_matched_state == -1:
            self._pos = _choice14
            raise BacktrackException
        _upto = _runner.last_matched_index + 1
        _pos = self._pos
        assert _pos >= 0
        assert _upto >= 0
        _result = self._inputstream[_pos: _upto]
        self._pos = _upto
        return _result
    def _regex528667127(self):
        _choice15 = self._pos
        _runner = self._Runner(self._inputstream, self._pos)
        _i = _runner.recognize_528667127(self._pos)
        if _runner.last_matched_state == -1:
            self._pos = _choice15
            raise BacktrackException
        _upto = _runner.last_matched_index + 1
        _pos = self._pos
        assert _pos >= 0
        assert _upto >= 0
        _result = self._inputstream[_pos: _upto]
        self._pos = _upto
        return _result
    def _regex291086639(self):
        _choice16 = self._pos
        _runner = self._Runner(self._inputstream, self._pos)
        _i = _runner.recognize_291086639(self._pos)
        if _runner.last_matched_state == -1:
            self._pos = _choice16
            raise BacktrackException
        _upto = _runner.last_matched_index + 1
        _pos = self._pos
        assert _pos >= 0
        assert _upto >= 0
        _result = self._inputstream[_pos: _upto]
        self._pos = _upto
        return _result
    def _regex1074651696(self):
        _choice17 = self._pos
        _runner = self._Runner(self._inputstream, self._pos)
        _i = _runner.recognize_1074651696(self._pos)
        if _runner.last_matched_state == -1:
            self._pos = _choice17
            raise BacktrackException
        _upto = _runner.last_matched_index + 1
        _pos = self._pos
        assert _pos >= 0
        assert _upto >= 0
        _result = self._inputstream[_pos: _upto]
        self._pos = _upto
        return _result
    def _regex1124192327(self):
        _choice18 = self._pos
        _runner = self._Runner(self._inputstream, self._pos)
        _i = _runner.recognize_1124192327(self._pos)
        if _runner.last_matched_state == -1:
            self._pos = _choice18
            raise BacktrackException
        _upto = _runner.last_matched_index + 1
        _pos = self._pos
        assert _pos >= 0
        assert _upto >= 0
        _result = self._inputstream[_pos: _upto]
        self._pos = _upto
        return _result
    def _regex1979538501(self):
        _choice19 = self._pos
        _runner = self._Runner(self._inputstream, self._pos)
        _i = _runner.recognize_1979538501(self._pos)
        if _runner.last_matched_state == -1:
            self._pos = _choice19
            raise BacktrackException
        _upto = _runner.last_matched_index + 1
        _pos = self._pos
        assert _pos >= 0
        assert _upto >= 0
        _result = self._inputstream[_pos: _upto]
        self._pos = _upto
        return _result
    class _Runner(object):
        def __init__(self, text, pos):
            self.text = text
            self.pos = pos
            self.last_matched_state = -1
            self.last_matched_index = -1
            self.state = -1
        def recognize_299149370(runner, i):
            #auto-generated code, don't edit
            assert i >= 0
            input = runner.text
            state = 0
            while 1:
                if state == 0:
                    runner.last_matched_index = i - 1
                    runner.last_matched_state = state
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 0
                        return i
                    if char == '\n':
                        state = 1
                    elif char == ' ':
                        state = 2
                    else:
                        break
                if state == 1:
                    runner.last_matched_index = i - 1
                    runner.last_matched_state = state
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 1
                        return i
                    if char == '\n':
                        state = 1
                        continue
                    elif char == ' ':
                        state = 1
                        continue
                    else:
                        break
                if state == 2:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 2
                        return ~i
                    if char == '\n':
                        state = 1
                        continue
                    elif char == ' ':
                        state = 2
                        continue
                    else:
                        break
                runner.last_matched_state = state
                runner.last_matched_index = i - 1
                runner.state = state
                if i == len(input):
                    return i
                else:
                    return ~i
                break
            runner.state = state
            return ~i
        def recognize_1006631623(runner, i):
            #auto-generated code, don't edit
            assert i >= 0
            input = runner.text
            state = 0
            while 1:
                if state == 0:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 0
                        return ~i
                    if char == '`':
                        state = 3
                    else:
                        break
                if state == 2:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 2
                        return ~i
                    if '\x00' <= char <= '\xff':
                        state = 3
                    else:
                        break
                if state == 3:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 3
                        return ~i
                    if char == '`':
                        state = 1
                    elif char == '\\':
                        state = 2
                        continue
                    elif ']' <= char <= '_':
                        state = 3
                        continue
                    elif '\x00' <= char <= '[':
                        state = 3
                        continue
                    elif 'a' <= char <= '\xff':
                        state = 3
                        continue
                    else:
                        break
                runner.last_matched_state = state
                runner.last_matched_index = i - 1
                runner.state = state
                if i == len(input):
                    return i
                else:
                    return ~i
                break
            runner.state = state
            return ~i
        def recognize_528667127(runner, i):
            #auto-generated code, don't edit
            assert i >= 0
            input = runner.text
            state = 0
            while 1:
                if state == 0:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 0
                        return ~i
                    if char == ' ':
                        state = 0
                        continue
                    elif char == '#':
                        state = 2
                    else:
                        break
                if state == 1:
                    runner.last_matched_index = i - 1
                    runner.last_matched_state = state
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 1
                        return i
                    if char == ' ':
                        state = 0
                        continue
                    elif char == '#':
                        state = 2
                    else:
                        break
                if state == 2:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 2
                        return ~i
                    if char == '\n':
                        state = 1
                        continue
                    elif '\x00' <= char <= '\t':
                        state = 2
                        continue
                    elif '\x0b' <= char <= '\xff':
                        state = 2
                        continue
                    else:
                        break
                runner.last_matched_state = state
                runner.last_matched_index = i - 1
                runner.state = state
                if i == len(input):
                    return i
                else:
                    return ~i
                break
            runner.state = state
            return ~i
        def recognize_291086639(runner, i):
            #auto-generated code, don't edit
            assert i >= 0
            input = runner.text
            state = 0
            while 1:
                if state == 0:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 0
                        return ~i
                    if char == '{':
                        state = 2
                    else:
                        break
                if state == 2:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 2
                        return ~i
                    if char == '}':
                        state = 1
                    elif '\x00' <= char <= '\t':
                        state = 2
                        continue
                    elif '\x0b' <= char <= '|':
                        state = 2
                        continue
                    elif '~' <= char <= '\xff':
                        state = 2
                        continue
                    else:
                        break
                runner.last_matched_state = state
                runner.last_matched_index = i - 1
                runner.state = state
                if i == len(input):
                    return i
                else:
                    return ~i
                break
            runner.state = state
            return ~i
        def recognize_1074651696(runner, i):
            #auto-generated code, don't edit
            assert i >= 0
            input = runner.text
            state = 0
            while 1:
                if state == 0:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 0
                        return ~i
                    if char == '_':
                        state = 1
                    elif 'A' <= char <= 'Z':
                        state = 1
                    elif 'a' <= char <= 'z':
                        state = 1
                    else:
                        break
                if state == 1:
                    runner.last_matched_index = i - 1
                    runner.last_matched_state = state
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 1
                        return i
                    if char == '_':
                        state = 1
                        continue
                    elif '0' <= char <= '9':
                        state = 1
                        continue
                    elif 'A' <= char <= 'Z':
                        state = 1
                        continue
                    elif 'a' <= char <= 'z':
                        state = 1
                        continue
                    else:
                        break
                runner.last_matched_state = state
                runner.last_matched_index = i - 1
                runner.state = state
                if i == len(input):
                    return i
                else:
                    return ~i
                break
            runner.state = state
            return ~i
        def recognize_1124192327(runner, i):
            #auto-generated code, don't edit
            assert i >= 0
            input = runner.text
            state = 0
            while 1:
                if state == 0:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 0
                        return ~i
                    if char == "'":
                        state = 1
                    else:
                        break
                if state == 1:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 1
                        return ~i
                    if '\x00' <= char <= '&':
                        state = 1
                        continue
                    elif '(' <= char <= '\xff':
                        state = 1
                        continue
                    elif char == "'":
                        state = 2
                    else:
                        break
                runner.last_matched_state = state
                runner.last_matched_index = i - 1
                runner.state = state
                if i == len(input):
                    return i
                else:
                    return ~i
                break
            runner.state = state
            return ~i
        def recognize_1979538501(runner, i):
            #auto-generated code, don't edit
            assert i >= 0
            input = runner.text
            state = 0
            while 1:
                if state == 0:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 0
                        return ~i
                    if char == '#':
                        state = 1
                    elif char == ' ':
                        state = 2
                    elif char == '\t':
                        state = 2
                    elif char == '\n':
                        state = 2
                    else:
                        break
                if state == 1:
                    try:
                        char = input[i]
                        i += 1
                    except IndexError:
                        runner.state = 1
                        return ~i
                    if '\x00' <= char <= '\t':
                        state = 1
                        continue
                    elif '\x0b' <= char <= '\xff':
                        state = 1
                        continue
                    elif char == '\n':
                        state = 2
                    else:
                        break
                runner.last_matched_state = state
                runner.last_matched_index = i - 1
                runner.state = state
                if i == len(input):
                    return i
                else:
                    return ~i
                break
            runner.state = state
            return ~i
class PyPackratSyntaxParser(PackratParser):
    def __init__(self, stream):
        self.init_parser(stream)
forbidden = dict.fromkeys(("__weakref__ __doc__ "
                           "__dict__ __module__").split())
initthere = "__init__" in PyPackratSyntaxParser.__dict__
for key, value in Parser.__dict__.iteritems():
    if key not in PyPackratSyntaxParser.__dict__ and key not in forbidden:
        setattr(PyPackratSyntaxParser, key, value)
PyPackratSyntaxParser.init_parser = Parser.__init__.im_func
