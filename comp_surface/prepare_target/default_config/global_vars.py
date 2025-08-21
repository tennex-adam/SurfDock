# global_vars.py: Global variables used by MaSIF -- mainly pointing to environment variables of programs used by MaSIF.
# Pablo Gainza - LPDI STI EPFL 2018-2019
# Released under an Apache License 2.0

import os 
from IPython.core.debugger import set_trace
epsilon = 1.0e-6
import sys

# TODO: Consolidate these variables at the root of the repository
# Update these paths to the respective cloned repositories
deepdock_repo_path = "/home/adam/scratch/DeepDock"
surfdock_repo_path = "/home/adam/scratch/surfdock-test"

os.environ['MSMS_BIN']= f"{surfdock_repo_path}/comp_surface/tools/transfer/APBS-3.4.1.Linux/bin/msms"
if 'MSMS_BIN' in os.environ:
   msms_bin = os.environ['MSMS_BIN']
else:
  set_trace()
  print("ERROR: MSMS_BIN not set. Variable should point to MSMS program.")
  sys.exit(1)

os.environ['PDB2PQR_BIN']=f"{surfdock_repo_path}/comp_surface/tools/transfer/pdb2pqr-linux-bin64-2.1.1/pdb2pqr"
if 'PDB2PQR_BIN' in os.environ:
   pdb2pqr_bin = os.environ['PDB2PQR_BIN']
else:
  print("ERROR: PDB2PQR_BIN not set. Variable should point to PDB2PQR_BIN program.")
  sys.exit(1)
os.environ['APBS_BIN']=f"{surfdock_repo_path}/comp_surface/tools/transfer/APBS-3.4.1.Linux/bin/apbs"
if 'APBS_BIN' in os.environ:
   apbs_bin = os.environ['APBS_BIN']
else:
  print("ERROR: APBS_BIN not set. Variable should point to APBS program.")
  sys.exit(1)
os.environ['MULTIVALUE_BIN']=f"{surfdock_repo_path}/comp_surface/tools/transfer/APBS-3.4.1.Linux/share/apbs/tools/bin/multivalue"
if 'MULTIVALUE_BIN' in os.environ:
   multivalue_bin = os.environ['MULTIVALUE_BIN']
else:
  print("ERROR: MULTIVALUE_BIN not set. Variable should point to MULTIVALUE program.")
  sys.exit(1)

class NoSolutionError(Exception):
    # global_vars.py: Global variables used by MaSIF -- mainly pointing to environment variables of programs used by MaSIF.
    # Pablo Gainza - LPDI STI EPFL 2018-2019
    # Released under an Apache License 2.0
    pass
