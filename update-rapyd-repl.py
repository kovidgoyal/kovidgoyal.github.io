#!/usr/bin/env python
# vim:fileencoding=utf-8
# License: GPLv3 Copyright: 2016, Kovid Goyal <kovid at kovidgoyal.net>

import os, subprocess, glob

base = os.path.dirname(os.path.abspath(__file__))
repl_dir = os.path.join(base, 'rapydscript', 'repl')
rapyd_path = os.path.join(os.path.dirname(base), 'rapydscript')
tuple(map(os.remove, glob.glob(os.path.join(repl_dir, '*'))))
subprocess.check_call([os.path.join(rapyd_path, 'bin', 'web-repl-export'), repl_dir])
subprocess.check_call(['git', 'add', repl_dir])
subprocess.check_call(['git', 'commit', '-am', 'Update RapydScript REPL'])
subprocess.check_call(['git', 'push'])
