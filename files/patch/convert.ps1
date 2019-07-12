# Whole idea of this script is to document patching process for the original EXE file
# and make process of generation EXE files repeatable, and more understandable.

# This patch disable encryption on the 3 servers:
# Auth, msg and world
.\fc2bin.ps1 -Apply disable-encryption.txt

Move-Item ../steam/WIZARDRYONLINE_UNPACKED.EXE.patched ../steam/WizardryOnline_no_encryption.exe -Force
