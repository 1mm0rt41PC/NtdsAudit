#!/bin/bash
export SECRETDUMPS=$1
if [ -z "$SECRETDUMPS" ]; then
cat <<EOD > /dev/null
1. Dump NTDS 'secretdumps.py -history DOMAIN/DOMAINADMIN_USER:PASSWORD@IP_DC > secretdumps.txt'
secretdumps.txt should have the following format:
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


2. Dump NTDS and put it into 'hashcat -m 1000 secretdumps.txt'

3. Create a bad words list:
cat <<DICO > badwords.txt
welcome
bonjour
geneve
lausanne
password
my-corp-name
DICO

3. Call this script with:

$0 secretdumps.txt badwords.txt
EOD
fi

if ! command -v tre-agrep &> /dev/null ; then
	echo 'Please `apt install tre-agrep`'
	exit 0
fi
if ! command -v docker &> /dev/null ; then
	echo 'Please `apt install docker`'
	exit 0
fi

export BAD_WORD_FILE=$2
[ -z "$BAD_WORD_FILE" ] && export BAD_WORD_FILE="`mktemp`.badword"


export NEO4J_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export NEO4J_USER="neo4j"
export NEO4J_PASS="`ps faux | md5sum | cut -d ' ' -f1`"
export HASHCAT_PATH=/opt/hashcat/hashcat.bin
export NEO4J_DOCKER_NAME='neo4j'
alias cypher_shell="docker exec $NEO4J_DOCKER_NAME /var/lib/neo4j/bin/cypher-shell -u $NEO4J_USER -p $NEO4J_PASS -f"
export tmpFile=`mktemp`
cat <<EOD > $NEO4J_PATH/.env.docker
NEO4J_USER=$NEO4J_USER
NEO4J_PASS=$NEO4J_PASS
NEOUSER=$NEO4J_USER
NEOPWD=$NEO4J_PASS
NEOURL=bolt://127.0.0.1:7687/
EOD

mkdir -p $NEO4J_PATH/neo4j-import/
export TMP_NTDS="${tmpFile}.secretdumps"
echo 'sid,nthash' > $NEO4J_PATH/neo4j-import/secretdumps.csv
grep -Ei '^[^$]+:[a-fA-F0-9]{32}:[a-fA-F0-9]{32}:::' $SECRETDUMPS | grep -vF '_history' | grep -viF '31d6cfe0d16ae931b73c59d7e0c089c0' | tr "[:lower:]" "[:upper:]" | tee $TMP_NTDS | sed -E 's/[^\r\n]+:([0-9]+):[A-F0-9]{32}:([A-F0-9]{32}):::/\1,\2/g' >> $NEO4J_PATH/neo4j-import/secretdumps.csv
export WEAK_CLEAR_PASSWORD="${tmpFile}.weak-clear-password"
$HASHCAT_PATH -m 1000 --quiet --show --outfile-format 1 $TMP_NTDS | grep -vF 'Failed to parse hashes' | tr "[:lower:]" "[:upper:]" | sort -u > "${tmpFile}.weak-hashes"

# Cleartext password for analyze
$HASHCAT_PATH -m 1000 --quiet --show --outfile-format 1 $TMP_NTDS | grep -vF ' ' | tr "[:lower:]" "[:upper:]" > "${tmpFile}.nthash"
$HASHCAT_PATH -m 1000 --quiet --show --outfile-format 2 $TMP_NTDS | grep -vF 'Failed to parse hashes' | $HASHCAT_PATH --quiet --stdout > "${tmpFile}.clearpass"
paste -d ':' "${tmpFile}.nthash" "${tmpFile}.clearpass" > $WEAK_CLEAR_PASSWORD


(cat "${tmpFile}.clearpass" | while read line ; do
    echo -n "$line" | base64
done) > "${tmpFile}.b64"

# Keep assoc NT:Clear (in b64)
echo 'nthash:b64pass' > $NEO4J_PATH/neo4j-import/weak-hashes.csv 
paste -d ':' "${tmpFile}.nthash" "${tmpFile}.b64" >> $NEO4J_PATH/neo4j-import/weak-hashes.csv

# Password len
echo 'nthash,len' > $NEO4J_PATH/neo4j-import/pass_len.csv
cat "${tmpFile}.clearpass" | awk '{ print length }' > "${tmpFile}.len"
paste -d ',' "${tmpFile}.nthash" "${tmpFile}.len" >> $NEO4J_PATH/neo4j-import/pass_len.csv

########################################################################
# Fetch weak hashes from HIBP
########################################################################
mkdir -p /opt/hibp
export HIBP_RESULTS="${tmpFile}.hibp"
mkdir -p $HIBP_RESULTS
cat "${tmpFile}.weak-hashes" | cut -c1-5 | uniq | xargs -I "{}" -P20 bash -c "[ ! -s /opt/hibp/{}.txt ] && (curl -L 'https://api.pwnedpasswords.com/range/{}?mode=ntlm' --output '/opt/hibp/{}.txt' || (sleep 2s && curl -L 'https://api.pwnedpasswords.com/range/{}?mode=ntlm' --output '/opt/hibp/{}.txt'))"
cat "${tmpFile}.weak-hashes" | xargs -I "XXX" -P50 bash -c 't="XXX";grep -q -F ${t:5} /opt/hibp/${t:0:5}.txt && (echo $t >> $HIBP_RESULTS/${t:0:5}.res)'
echo "`find $HIBP_RESULTS -iname '*.res' | wc -l` Password leaked on internet"
# Merge result into one file
cat $HIBP_RESULTS/*.res | sort -u > $NEO4J_PATH/neo4j-import/hibp.csv
rm $HIBP_RESULTS/*.res

########################################################################
# List of not allowed word
########################################################################
[ ! -s "$BAD_WORD_FILE" ] && cat <<DICO > $BAD_WORD_FILE
welcome
bonjour
geneve
lausanne
password
DICO
(
cat $BAD_WORD_FILE | xargs -I '{}' tre-agrep -i -k -I10 -E1 '{}' $WEAK_CLEAR_PASSWORD;
cat $BAD_WORD_FILE | xargs -I '{}' grep -Fai '{}' $WEAK_CLEAR_PASSWORD
) | sort -u | tee $NEO4J_PATH/neo4j-import/bad-words.csv | cut -d ':' -f1 | tr "[:lower:]" "[:upper:]" > $NEO4J_PATH/neo4j-import/bad-words-nt.csv
rm -rf ${tmpFile}.*



########################################################################
# Run docker
########################################################################
docker run --rm -d --network=host -p 127.0.0.1:7474:7474 -p 127.0.0.1:7687:7687 \
-v $NEO4J_PATH/neo4j-conf:/var/lib/neo4j/conf -v $NEO4J_PATH/neo4j-scripts:/neo4j-scripts/ \
-v $NEO4J_PATH/neo4j-import:/var/lib/neo4j/import  --name $NEO4J_DOCKER_NAME \
-e NEO4J_apoc_export_file_enabled=true \
-e NEO4J_apoc_import_file_enabled=true \
-e NEO4J_apoc_import_file_use__neo4j__config=true \
-e NEO4J_PLUGINS=\[\"apoc\"\] \
-e NEO4J_AUTH=$NEO4J_USER/$NEO4J_PASS neo4j:4.4.21
echo "Starting Neo4j..."
(docker logs -f $NEO4J_DOCKER_NAME &) | grep -q "Started."
cypher_shell /neo4j-scripts/000-prepare-neo4j.cql


if [ -z "`docker images | grep -F starhound-importer`" ]; then
	cd $NEO4J_PATH/
	if [ ! -d "$NEO4J_PATH/starhound-importer" ]; then
		git clone --recurse-submodules -j8 --depth 1 https://github.com/1mm0rt41PC/starhound-importer
	fi
	cd $NEO4J_PATH/starhound-importer
	git checkout .
	git pull
	docker build --network=host -t starhound-importer .
	cd $NEO4J_PATH/
fi
docker run --rm -it --network=host -v $NEO4J_PATH/neo4j-import:/data --env-file $NEO4J_PATH/.env.docker starhound-importer

cypher_shell /neo4j-scripts/001-fix-bloodhound-err.cql
cypher_shell /neo4j-scripts/999-warmup.cql
cypher_shell /neo4j-scripts/002-tier0-tag.cql
cypher_shell /neo4j-scripts/003-ntds.cql

cypher_shell /neo4j-scripts/010-list-users.cql
cypher_shell /neo4j-scripts/020-List-of-password-reuse.cql
cypher_shell /neo4j-scripts/030-List-of-banned-passwords.cql
cypher_shell /neo4j-scripts/040-Password-length.cql
cypher_shell /neo4j-scripts/050-Stats.cql
cypher_shell /neo4j-scripts/060-Definition.cql

mkdir -p $NEO4J_PATH/output
docker run --rm -v $NEO4J_PATH/output:/output -v $NEO4J_PATH/neo4j-import:/import:ro -v $NEO4J_PATH/:/code:ro -w /code -i python:latest bash -c "pip3 install xlsxwriter; python3 /code/excelGenerator.py"
