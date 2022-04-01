#!/usr/bin/env python
import log_reader

def daily_date_hasher(date):
    return ((date.year, date.month, date.day))

def read_log(filename, path_guesser, date_hasher=daily_date_hasher,
             max_reads=None):
    assert callable(path_guesser)
    lr = log_reader.ApacheReader(filename)
    ret = {}
    keys = []
    for num, i in enumerate(lr):
        if max_reads and num > max_reads:
            return keys, ret
        if 'path' in i:
            if path_guesser(i['path']):
                hash = date_hasher(i['time'])
                if hash in ret:
                    ret[hash] += 1
                else:
                    ret[hash] = 1
                    keys.append(hash)
    return keys, ret

def test_daily_date_hasher():
    from datetime import datetime
    one = datetime(2007, 2, 25, 3, 10, 50)
    two = datetime(2007, 2, 25, 7, 1, 5)
    three = datetime(2007, 3, 25, 3, 10, 50)
    assert daily_date_hasher(one) == daily_date_hasher(two)
    assert daily_date_hasher(one) != daily_date_hasher(three)

def test_read_log():
    def path_guesser(path):
        return path.startswith("/viewvc")
    keys, ret = read_log("code.log", path_guesser)
    assert sum(ret.values()) == 51
    assert sorted(keys) == keys
    assert ret[(2007, 2, 25)] == 51

if __name__ == "__main__":
    import sys
    import re
    if len(sys.argv) == 3:
        max_reads = int(sys.argv[2])
    elif len(sys.argv) != 2:
        print "Usage ./parse_logs.py <logfile> [max reads]"
        sys.exit(1)
    else:
        max_reads = None

    def path_guesser(path):
        return "pypy" in path
    
    keys, ret = read_log(sys.argv[1], path_guesser, max_reads=max_reads)
    for key in keys:
        year, month, day = key
        print "%d-%d-%d, %d" % (year, month, day, ret[key])
