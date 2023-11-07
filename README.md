
[![NtdsAudit][screenshot]](https://github.com/1mm0rt41PC/NtdsAudit)

# Password Auditor
NtdsAudit is an application to assist in auditing Active Directory databases.

It provides some useful statistics relating to accounts and passwords, as shown in the following example. 

## Usage
NtdsAudit Bloodhound-Edition requires docker and hashcat.

### 1: Obtaining the required files

#### 1.A: Bloodhound
Run a Bloodhound collector of your choice:
- [Sharphound](https://github.com/BloodHoundAD/SharpHound)
- [Rusthound](https://github.com/NH-RED-TEAM/RustHound)
- [Bloodhound.py](https://github.com/dirkjanm/BloodHound.py)
- [AdExplorer ](https://learn.microsoft.com/en-us/sysinternals/downloads/adexplorer) + [ADExplorerSnapshot](https://github.com/c3c/ADExplorerSnapshot.py)

#### 1.B: Dump the domain via ntdsutils
Dump the `ntds.dit` Active Directory database, and the `SYSTEM` registry hive. These files are locked by a domain controller and as such cannot be simply copy and pasted. The recommended method of obtaining these files from a domain controller is using the builtin `ntdsutil` utility. 

* Open a command prompt (cmd.exe) as an administrator. To open a command prompt as an administrator, click Start. In Start Search, type Command Prompt. At the top of the Start menu, right-click Command Prompt, and then click Run as administrator. If the User Account Control dialog box appears, enter the appropriate credentials (if requested) and confirm that the action it displays is what you want, and then click Continue.

* At the command prompt, type the following command, and then press ENTER:

```
C:\> ntdsutil "activate instance ntds" "ifm" "create full C:\pentest" quit quit
```

Where `C:\pentest` is the path to the folder where you want the files to be created.

Then on Kali linux like extract hashes via impacket:
```bash
root@kali:~$ secretdumps.py -history -system SYSTEM -ntds ntds.dit local | grep -Ei ':[a-f0-9]{32}:[a-f0-9]{32}:::' > secretdumps.txt
xxx\azerty:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
xxx\azerty_history0:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
xxx\azerty_history1:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
xxx\azerty_history2:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
xxx\azerty_history3:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
xxx\azerty_history4:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze_history0:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze_history1:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze_history2:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze_history3:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze_history4:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
qsd:409948:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc_history0:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc_history1:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc_history2:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc_history3:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc_history4:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
computer47$:569350:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
...
```


#### 1.B Bis: Dump the domain via dcsync
```bash
root@kali:~$ secretdumps.py -history DOMAIN/DOMAINADMIN_USER:PASSWORD@IP_DC | grep -Ei ':[a-f0-9]{32}:[a-f0-9]{32}:::' > secretdumps.txt
xxx\azerty:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
xxx\azerty_history0:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
xxx\azerty_history1:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
xxx\azerty_history2:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
xxx\azerty_history3:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
xxx\azerty_history4:95140:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze_history0:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze_history1:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze_history2:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze_history3:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
aze_history4:411860:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
qsd:409948:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc_history0:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc_history1:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc_history2:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc_history3:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
wxc_history4:560774:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
computer47$:569350:aad3b435b51404eeaad3b435b51404ee:aad3b435b51404eeaad3b435b51404ee:::
...
```

#### 1.C: Cleaning files
Remove all accounts that have a dynamic password (Computers, krbtgt, MSOL_...)

```bash
root@kali:~$ grep -Ei '^[^$]+:[a-f0-9]{32}:[a-f0-9]{32}:::' secretdumps.txt | grep -viE '(krbtgt|MSOL_)' > hashcat_target.txt
```

#### 1.D: Run the glorious Hashcat
```bash
root@kali:~$ hashcat -m 1000 hashcat_target.txt ...
```

#### 2: Create a basic list of not allowed words for the corp:
```bash
root@kali:~/NtdsAudit/$ cat bad-word.txt
welcome
bonjour
geneve
lausanne
password
my-corp
```

#### 3: Place all files in the correct path
git clone this repo and put all files in `neo4j-import`
```bash
root@kali:~$ git clone https://github.com/1mm0rt41PC/NtdsAudit
root@kali:~$ cd NtdsAudit
root@kali:~/NtdsAudit/$ ll neo4j-import
-rwx------  1 root root 37233326 Nov  5 22:35 corp.lan_bloodhound.zip
-rwx------  1 root root   163436 Nov  5 23:01 secretdumps.csv
```

## Generate base CSV for Bloodhound
```bash
root@kali:~/NtdsAudit/$ bash main.sh ~/NtdsAudit/neo4j-import/secretdumps.csv ~/NtdsAudit/bad-word.txt
...
root@kali:~/NtdsAudit/$ ls output
-rwx------  1 root root 37233326 Nov  5 23:35 PasswordPolicy.xlsx
```


<!-- MARKDOWN LINKS & IMAGES -->
[screenshot]: doc/screenshot.png