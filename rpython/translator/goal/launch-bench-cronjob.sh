#!/bin/bash

. /etc/profile # be sure to have the right environment, especially PATH
/usr/local/bin/python2.4 ~/projects/pypy-trunk/pypy/translator/goal/bench-cronjob.py
