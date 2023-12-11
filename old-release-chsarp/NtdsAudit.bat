bin\NtdsAudit.exe --system input\SYSTEM -p output\hash.txt --history-hashes --dump-reversible output\clear.txt --users-csv output\Users.csv --potfile input\hashcat.potfile input\ntds.dit
pause
powershell -exec bypass -nop -File bin\genExcel.ps1
pause