# -*- coding: utf-8 -*-
"""Tests for _sqlite3.py"""

from __future__ import absolute_import
import pytest
import sys
import gc

_sqlite3 = pytest.importorskip('_sqlite3')

pypy_only = pytest.mark.skipif('__pypy__' not in sys.builtin_module_names,
    reason="PyPy-only test")


@pytest.fixture
def con():
    con = _sqlite3.connect(':memory:')
    yield con
    con.close()

con2 = con # allow using two connections


def test_list_ddl(con):
    """From issue996.  Mostly just looking for lack of exceptions."""
    cursor = con.cursor()
    cursor.execute('CREATE TABLE foo (bar INTEGER)')
    result = list(cursor)
    assert result == []
    cursor.execute('INSERT INTO foo (bar) VALUES (42)')
    result = list(cursor)
    assert result == []
    cursor.execute('SELECT * FROM foo')
    result = list(cursor)
    assert result == [(42,)]

@pypy_only
def test_connect_takes_same_positional_args_as_Connection(con):
    from inspect import getfullargspec
    clsargs = getfullargspec(_sqlite3.Connection.__init__).args[1:]  # ignore self
    conargs = getfullargspec(_sqlite3.connect).args
    assert clsargs == conargs

def test_total_changes_after_close(con):
    con.close()
    with pytest.raises(_sqlite3.ProgrammingError):
        con.total_changes

def test_connection_check_init():
    class Connection(_sqlite3.Connection):
        def __init__(self, name):
            pass

    con = Connection(":memory:")
    with pytest.raises(_sqlite3.ProgrammingError) as excinfo:
        con.cursor()
    assert '__init__' in str(excinfo.value)


def test_cursor_check_init(con):
    class Cursor(_sqlite3.Cursor):
        def __init__(self, name):
            pass

    cur = Cursor(con)
    with pytest.raises(_sqlite3.ProgrammingError) as excinfo:
        cur.execute('select 1')
    assert '__init__' in str(excinfo.value)

def test_connection_after_close(con):
    with pytest.raises(TypeError):
        con()
    con.close()
    # raises ProgrammingError because should check closed before check args
    with pytest.raises(_sqlite3.ProgrammingError):
        con()

def test_cursor_iter(con):
    cur = con.cursor()
    with pytest.raises(StopIteration):
        next(cur)

    cur.execute('select 1')
    next(cur)
    with pytest.raises(StopIteration):
        next(cur)

    cur.execute('select 1')
    con.commit()
    next(cur)
    with pytest.raises(StopIteration):
        next(cur)

    cur.executemany('select 1', [])
    with pytest.raises(StopIteration):
        next(cur)

    cur.execute('select 1')
    cur.execute('create table test(ing)')
    with pytest.raises(StopIteration):
        next(cur)

    cur.execute('select 1')
    cur.execute('insert into test values(1)')
    con.commit()
    with pytest.raises(StopIteration):
        next(cur)

def test_cursor_after_close(con):
    cur = con.execute('select 1')
    cur.close()
    con.close()
    with pytest.raises(_sqlite3.ProgrammingError):
        cur.close()
    # raises ProgrammingError because should check closed before check args
    with pytest.raises(_sqlite3.ProgrammingError):
        cur.execute(1,2,3,4,5)
    with pytest.raises(_sqlite3.ProgrammingError):
        cur.executemany(1,2,3,4,5)

def test_connection_del(tmpdir):
    """For issue1325."""
    import os
    import gc
    resource = pytest.importorskip('resource')

    limit = resource.getrlimit(resource.RLIMIT_NOFILE)
    try:
        fds = 0
        while True:
            fds += 1
            resource.setrlimit(resource.RLIMIT_NOFILE, (fds, limit[1]))
            try:
                for p in os.pipe(): os.close(p)
            except OSError:
                assert fds < 100
            else:
                break

        def open_many(cleanup):
            con = []
            for i in range(3):
                con.append(_sqlite3.connect(str(tmpdir.join('test.db'))))
                if cleanup:
                    con[i] = None
                    gc.collect(); gc.collect()

        with pytest.raises(_sqlite3.OperationalError):
            open_many(False)
        gc.collect(); gc.collect()
        open_many(True)
    finally:
        resource.setrlimit(resource.RLIMIT_NOFILE, limit)

def test_on_conflict_rollback_executemany(con):
    major, minor, micro = _sqlite3.sqlite_version.split('.')[:3]
    if (int(major), int(minor), int(micro)) < (3, 2, 2):
        pytest.skip("requires sqlite3 version >= 3.2.2")
    con.execute("create table foo(x, unique(x) on conflict rollback)")
    con.execute("insert into foo(x) values (1)")
    try:
        con.executemany("insert into foo(x) values (?)", [[1]])
    except _sqlite3.DatabaseError:
        pass
    con.execute("insert into foo(x) values (2)")
    try:
        con.commit()
    except _sqlite3.OperationalError:
        pytest.fail("_sqlite3 knew nothing about the implicit ROLLBACK")

def test_statement_arg_checking(con):
    with pytest.raises(TypeError) as e:
        con(123)
    with pytest.raises(TypeError) as e:
        con.execute(123)
    with pytest.raises(TypeError) as e:
        con.executemany(123, 123)
    with pytest.raises(ValueError) as e:
        con.executescript(123)
    assert str(e.value).startswith('script argument must be unicode')

def test_statement_param_checking(con):
    con.execute('create table foo(x)')
    con.execute('insert into foo(x) values (?)', [2])
    con.execute('insert into foo(x) values (?)', (2,))
    class seq(object):
        def __len__(self):
            return 1
        def __getitem__(self, key):
            return 2
    con.execute('insert into foo(x) values (?)', seq())
    del seq.__len__
    with pytest.raises(_sqlite3.ProgrammingError):
        con.execute('insert into foo(x) values (?)', seq())
    with pytest.raises(_sqlite3.ProgrammingError):
        con.execute('insert into foo(x) values (?)', {2:2})
    with pytest.raises(ValueError) as e:
        con.execute('insert into foo(x) values (?)', 2)
    assert str(e.value) == 'parameters are of unsupported type'

def test_explicit_begin(con):
    con.execute('BEGIN')
    with pytest.raises(_sqlite3.OperationalError):
        con.execute('BEGIN ')
    con.commit()
    con.execute('BEGIN')
    con.commit()

def test_row_factory_use(con):
    con.row_factory = 42
    con.execute('select 1')

def test_returning_blob_must_own_memory(con):
    con.create_function("returnblob", 0, lambda: memoryview(b"blob"))
    cur = con.execute("select returnblob()")
    val = cur.fetchone()[0]
    assert isinstance(val, bytes)

def test_function_arg_str_null_char(con):
    con.create_function("strlen", 1, lambda a: len(a))
    cur = con.execute("select strlen(?)", ["x\0y"])
    val = cur.fetchone()[0]
    assert val == 3


def test_description_after_fetchall(con):
    cur = con.cursor()
    assert cur.description is None
    cur.execute("select 42").fetchall()
    assert cur.description is not None

def test_executemany_lastrowid(con):
    cur = con.cursor()
    cur.execute("create table test(a)")
    cur.executemany("insert into test values (?)", [[1], [2], [3]])
    assert cur.lastrowid == 0
    # issue 2682
    cur.execute('''insert
                into test
                values (?)
                ''', (1, ))
    assert cur.lastrowid
    cur.execute('''insert\t into test values (?) ''', (1, ))
    assert cur.lastrowid

def test_authorizer_bad_value(con):
    def authorizer_cb(action, arg1, arg2, dbname, source):
        return 42
    con.set_authorizer(authorizer_cb)
    with pytest.raises(_sqlite3.OperationalError) as e:
        con.execute('select 123')
    major, minor, micro = _sqlite3.sqlite_version.split('.')[:3]
    if (int(major), int(minor), int(micro)) >= (3, 6, 14):
        assert str(e.value) == 'authorizer malfunction'
    else:
        assert str(e.value) == \
            ("illegal return value (1) from the authorization function - "
                "should be SQLITE_OK, SQLITE_IGNORE, or SQLITE_DENY")

def test_issue1573(con):
    cur = con.cursor()
    cur.execute(u'SELECT 1 as méil')
    assert cur.description[0][0] == u"méil"

def test_adapter_exception(con):
    def cast(obj):
        raise ZeroDivisionError

    _sqlite3.register_adapter(int, cast)
    try:
        cur = con.cursor()
        with pytest.raises(ZeroDivisionError):
            cur.execute("select ?", (4,))
    finally:
        del _sqlite3.adapters[(int, _sqlite3.PrepareProtocol)]

def test_null_character(con):
    if not hasattr(_sqlite3, '_ffi') and sys.version_info < (2, 7, 9):
        pytest.skip("_sqlite3 too old")
    with pytest.raises(ValueError) as excinfo:
        con("\0select 1")
    assert str(excinfo.value) == "the query contains a null character"
    with pytest.raises(ValueError) as excinfo:
        con("select 1\0")
    assert str(excinfo.value) == "the query contains a null character"
    cur = con.cursor()
    with pytest.raises(ValueError) as excinfo:
        cur.execute("\0select 2")
    assert str(excinfo.value) == "the query contains a null character"
    with pytest.raises(ValueError) as excinfo:
        cur.execute("select 2\0")
    assert str(excinfo.value) == "the query contains a null character"

def test_close_in_del_ordering():
    import gc
    class SQLiteBackend(object):
        success = False
        def __init__(self):
            self.connection = _sqlite3.connect(":memory:")
        def close(self):
            self.connection.close()
        def __del__(self):
            self.close()
            SQLiteBackend.success = True
        def create_db_if_needed(self):
            conn = self.connection
            cursor = conn.cursor()
            cursor.execute("""
                create table if not exists nameoftable(value text)
            """)
            cursor.close()
            conn.commit()
    SQLiteBackend().create_db_if_needed()
    gc.collect()
    gc.collect()
    assert SQLiteBackend.success

def test_locked_table(con):
    con.execute("CREATE TABLE foo(x)")
    con.execute("INSERT INTO foo(x) VALUES (?)", [42])
    cur = con.execute("SELECT * FROM foo")  # foo() is locked while cur is active
    with pytest.raises(_sqlite3.OperationalError):
        con.execute("DROP TABLE foo")

def test_cursor_close(con):
    con.execute("CREATE TABLE foo(x)")
    con.execute("INSERT INTO foo(x) VALUES (?)", [42])
    cur = con.execute("SELECT * FROM foo")
    cur.close()
    con.execute("DROP TABLE foo")  # no error

def test_cursor_del(con):
    con.execute("CREATE TABLE foo(x)")
    con.execute("INSERT INTO foo(x) VALUES (?)", [42])
    con.execute("SELECT * FROM foo")
    import gc; gc.collect()
    con.execute("DROP TABLE foo")  # no error

def test_open_path():
    class P:
        def __fspath__(self):
            return b":memory:"
    _sqlite3.connect(P())

def test_isolation_bug():
    con = _sqlite3.connect(":memory:", isolation_level=None)
    #con = _sqlite3.connect(":memory:")
    #con.isolation_level = None
    cur = con.cursor()
    cur.execute("create table foo(x);")

def test_reset_of_shared_statement(con):
    con = _sqlite3.connect(':memory:')
    c0 = con.cursor()
    c0.execute('CREATE TABLE data(n int, t int)')
    # insert two values
    c0.execute('INSERT INTO data(n, t) VALUES(?, ?)', (0, 1))
    c0.execute('INSERT INTO data(n, t) VALUES(?, ?)', (1, 2))

    c1 = con.execute('select * from data')
    list(c1) # c1's statement is no longer in use afterwards
    c2 = con.execute('select * from data')
    # the statement between c1 and c2 is shared
    assert c1._Cursor__statement is c2._Cursor__statement
    val = next(c2)
    assert val == (0, 1)
    c1 = None # make c1 unreachable
    gc.collect() # calling c1.__del__ used to reset c2._Cursor__statement!
    val = next(c2)
    assert val == (1, 2)
    with pytest.raises(StopIteration):
        next(c2)

def test_row_index_unicode(con):
    import sqlite3
    con.row_factory = sqlite3.Row
    row = con.execute("select 1 as \xff").fetchone()
    assert row["\xff"] == 1
    with pytest.raises(IndexError):
        row['\u0178']
    with pytest.raises(IndexError):
        row['\xdf']

@pytest.mark.skipif(not hasattr(_sqlite3.Connection, "backup"), reason="no backup")
class TestBackup:
    def test_target_is_connection(self, con):
        with pytest.raises(TypeError):
            con.backup(None)

    def test_target_different_self(self, con):
        with pytest.raises(ValueError):
            con.backup(con)

    def test_progress_callable(self, con, con2):
        with pytest.raises(TypeError):
            con.backup(con2, progress=34)

    def test_backup_simple(self, con, con2):
        cursor = con.cursor()
        con.execute('CREATE TABLE foo (key INTEGER)')
        con.executemany('INSERT INTO foo (key) VALUES (?)', [(3,), (4,)])
        con.commit()

        con.backup(con2)
        result = con2.execute("SELECT key FROM foo ORDER BY key").fetchall()
        assert result[0][0] == 3
        assert result[1][0] == 4

def test_reset_already_committed_statements_bug(con):
    con.execute('''CREATE TABLE COMPANY
             (ID INT PRIMARY KEY,
             A INT);''')
    con.execute("INSERT INTO COMPANY (ID, A) \
          VALUES (1, 2)")
    cursor = con.execute("SELECT id, a from COMPANY")
    con.commit()
    con.execute("DROP TABLE COMPANY")

def test_empty_statement():
    r = _sqlite3.connect(":memory:")
    cur = r.cursor()
    for sql in ["", " ", "/*comment*/"]:
        r = cur.execute(sql)
        assert r.description is None
        assert cur.fetchall() == []

def test_uninit_connection():
    con = _sqlite3.Connection.__new__(_sqlite3.Connection)
    with pytest.raises(_sqlite3.ProgrammingError):
        con.isolation_level
    with pytest.raises(_sqlite3.ProgrammingError):
        con.total_changes
    with pytest.raises(_sqlite3.ProgrammingError):
        con.in_transaction
    with pytest.raises(_sqlite3.ProgrammingError):
        con.iterdump()
    with pytest.raises(_sqlite3.ProgrammingError):
        con.close()
