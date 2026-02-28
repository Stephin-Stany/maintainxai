import os
import sys

# ensure backend directory is in path and set cwd so model/CVS load correctly
script_dir = os.path.dirname(os.path.abspath(__file__))
# backend folder is a sibling of scripts directory
base = os.path.normpath(os.path.join(script_dir, '..', 'maintainx_backend'))
os.chdir(base)
sys.path.insert(0, base)

import main

# call the function directly
df = main.list_machines(limit=30)
print('returned', len(df), 'records')
print(df[:5])
