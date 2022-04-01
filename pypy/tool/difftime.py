import py 

_time_desc = {
         1 : 'second', 60 : 'minute', 3600 : 'hour', 86400 : 'day',
         2628000 : 'month', 31536000 : 'year', }

def worded_diff_time(ctime):
    difftime = py.std.time.time() - ctime
    keys = _time_desc.keys()
    keys.sort()
    for i, key in py.builtin.enumerate(keys):
        if key >=difftime:
            break
    l = []
    keylist = keys[:i]

    keylist.reverse()
    for key in keylist[:1]:
        div = int(difftime / key)
        if div==0:
            break
        difftime -= div * key
        plural = div > 1 and 's' or ''
        l.append('%d %s%s' %(div, _time_desc[key], plural))
    return ", ".join(l) + " ago "

_months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

def worded_time(ctime):
    tm = py.std.time.gmtime(ctime)
    return "%s %d, %d" % (_months[tm.tm_mon-1], tm.tm_mday, tm.tm_year)
