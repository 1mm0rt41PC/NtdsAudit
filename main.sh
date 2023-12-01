#!/bin/bash

[ -z "$HASHCAT" ] && export HASHCAT=hashcat

if ! command -v tre-agrep &> /dev/null ; then
	echo 'Please `apt install tre-agrep`'
	exit 0
fi
if ! command -v docker &> /dev/null ; then
	echo 'Please `apt install docker`'
	exit 0
fi
if ! command -v git &> /dev/null ; then
	echo 'Please `apt install git`'
	exit 0
fi
if ! command -v curl &> /dev/null ; then
	echo 'Please `apt install curl`'
	exit 0
fi
if ! command -v $HASHCAT &> /dev/null ; then
	echo 'Please `apt install hashcat` or indicate the hashcat bin full path via `export HASHCAT=/my/path/to/hashcat.bin`'
	exit 0
fi

export NEO4J_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export NEO4J_USER="neo4j"
export NEO4J_PASS="`ps faux | md5sum | cut -d ' ' -f1`"
export NEO4J_DOCKER_NAME='neo4j'
export SECRETSDUMP=$NEO4J_PATH/neo4j-import/secretsdump.txt
export BAD_WORD_FILE=$NEO4J_PATH/neo4j-import/badwords.txt
function cypher_shell {
	logInfo "Running $1"
	docker exec $NEO4J_DOCKER_NAME /var/lib/neo4j/bin/cypher-shell -u $NEO4J_USER -p $NEO4J_PASS -f "$1"
}
function logInfo
{
	echo -e "\033[33m[`date '+%Y-%m-%d %Hh%Mm%S'`][+] $1\033[0m"
}
cat <<EOD > $NEO4J_PATH/.env.docker
NEO4J_PATH=$NEO4J_PATH
NEO4J_USER=$NEO4J_USER
NEO4J_PASS=$NEO4J_PASS
NEOUSER=$NEO4J_USER
NEOPWD=$NEO4J_PASS
NEOURL=bolt://127.0.0.1:7687/
NEO4J_apoc_export_file_enabled=true
NEO4J_apoc_import_file_enabled=true
NEO4J_apoc_import_file_use__neo4j__config=true
NEO4J_PLUGINS=["apoc"]
NEO4J_AUTH=$NEO4J_USER/$NEO4J_PASS
EOD


logInfo "Cleaning up old docker named $NEO4J_DOCKER_NAME"
docker kill $NEO4J_DOCKER_NAME 2>/dev/null
docker rm $NEO4J_DOCKER_NAME 2>/dev/null


logInfo "Creating secretsdump.csv"
mkdir -p $NEO4J_PATH/neo4j-import/
export TMP_NTDS="$NEO4J_PATH/neo4j-import/secretsdump.tmp"
echo 'sid,nthash' > $NEO4J_PATH/neo4j-import/secretsdump.csv
grep -Ei '^[^$]+:[a-fA-F0-9]{32}:[a-fA-F0-9]{32}:::' $SECRETSDUMP | grep -vF '_history' | grep -viF '31d6cfe0d16ae931b73c59d7e0c089c0' | tr "[:lower:]" "[:upper:]" | tee $TMP_NTDS | sed -E 's/[^\r\n]+:([0-9]+):[A-F0-9]{32}:([A-F0-9]{32}):::/\1,\2/g' >> $NEO4J_PATH/neo4j-import/secretsdump.csv

logInfo "Creating temp.weak-clear-password && temp.weak-hashes"
export WEAK_CLEAR_PASSWORD="$NEO4J_PATH/neo4j-import/weak-clear-password.tmp"
$HASHCAT --potfile-path=$NEO4J_PATH/neo4j-import/hashcat.potfile -m 1000 --quiet --show --outfile-format 1 $TMP_NTDS | grep -vF 'Failed to parse hashes' | tr "[:lower:]" "[:upper:]" | sort -u > "$NEO4J_PATH/neo4j-import/weak-hashes.tmp"

# Cleartext password for analyze
logInfo "Creating temp.nthash"
$HASHCAT --potfile-path=$NEO4J_PATH/neo4j-import/hashcat.potfile -m 1000 --quiet --show --outfile-format 1 $TMP_NTDS | grep -vF ' ' | tr "[:lower:]" "[:upper:]" > "$NEO4J_PATH/neo4j-import/nthash.tmp"
logInfo "Creating temp.clearpass"
$HASHCAT --potfile-path=$NEO4J_PATH/neo4j-import/hashcat.potfile -m 1000 --quiet --show --outfile-format 2 $TMP_NTDS | grep -vF 'Failed to parse hashes' | $HASHCAT --potfile-path=$NEO4J_PATH/neo4j-import/hashcat.potfile --quiet --stdout > "$NEO4J_PATH/neo4j-import/clearpass.tmp"
logInfo "Creating temp.weak-clear-password"
paste -d ':' "$NEO4J_PATH/neo4j-import/nthash.tmp" "$NEO4J_PATH/neo4j-import/clearpass.tmp" > $WEAK_CLEAR_PASSWORD

logInfo "Creating temp.clearpass.b64"
(cat "$NEO4J_PATH/neo4j-import/clearpass.tmp" | while read line ; do
    echo -n "$line" | base64
done) > "$NEO4J_PATH/neo4j-import/b64.tmp"

# Keep assoc NT:Clear (in b64)
logInfo "Creating weak-hashes.csv"
echo 'nthash:b64pass' > $NEO4J_PATH/neo4j-import/weak-hashes.csv
paste -d ':' "$NEO4J_PATH/neo4j-import/nthash.tmp" "$NEO4J_PATH/neo4j-import/b64.tmp" >> $NEO4J_PATH/neo4j-import/weak-hashes.csv

# Password len
logInfo "Creating pass_len.csv"
echo 'nthash,len' > $NEO4J_PATH/neo4j-import/pass_len.csv
cat "$NEO4J_PATH/neo4j-import/clearpass.tmp" | awk '{ print length }' > "$NEO4J_PATH/neo4j-import/len.tmp"
paste -d ',' "$NEO4J_PATH/neo4j-import/nthash.tmp" "$NEO4J_PATH/neo4j-import/len.tmp" >> $NEO4J_PATH/neo4j-import/pass_len.csv

########################################################################
# Fetch weak hashes from HIBP
########################################################################
logInfo "Grabbing hashes from HIBP"
mkdir -p /opt/hibp
export HIBP_RESULTS="$NEO4J_PATH/neo4j-import/hibp.tmp"
mkdir -p $HIBP_RESULTS
cat "$NEO4J_PATH/neo4j-import/weak-hashes.tmp" | cut -c1-5 | uniq | xargs -I "{}" -P20 bash -c "[ ! -s /opt/hibp/{}.txt ] && (curl -L 'https://api.pwnedpasswords.com/range/{}?mode=ntlm' --output '/opt/hibp/{}.txt' || (sleep 2s && curl -L 'https://api.pwnedpasswords.com/range/{}?mode=ntlm' --output '/opt/hibp/{}.txt'))"
cat "$NEO4J_PATH/neo4j-import/weak-hashes.tmp" | xargs -I "XXX" -P50 bash -c 't="XXX";grep -q -F ${t:5} /opt/hibp/${t:0:5}.txt && (echo $t >> $HIBP_RESULTS/${t:0:5}.res)'
echo "`find $HIBP_RESULTS -iname '*.res' | wc -l` Password leaked on internet"
# Merge result into one file
logInfo "Creating hibp.csv"
cat $HIBP_RESULTS/*.res | sort -u > $NEO4J_PATH/neo4j-import/hibp.csv
rm $HIBP_RESULTS/*.res

########################################################################
# List of not allowed word
########################################################################
logInfo "Creating bad-words.csv & bad-words-nt.csv"
(
cat $BAD_WORD_FILE | xargs -I '{}' tre-agrep -i -k -I10 -E1 '{}' $WEAK_CLEAR_PASSWORD;
cat $BAD_WORD_FILE | xargs -I '{}' grep -Fai '{}' $WEAK_CLEAR_PASSWORD
) | sort -u | tee $NEO4J_PATH/neo4j-import/bad-words.csv | cut -d ':' -f1 | tr "[:lower:]" "[:upper:]" > $NEO4J_PATH/neo4j-import/bad-words-nt.csv
rm -rf $NEO4J_PATH/neo4j-import/*.tmp



########################################################################
# Run docker
########################################################################
docker run --rm -d --network=host -p 127.0.0.1:7474:7474 -p 127.0.0.1:7687:7687 \
-v $NEO4J_PATH/neo4j-conf:/var/lib/neo4j/conf -v $NEO4J_PATH/neo4j-scripts:/neo4j-scripts/ \
-v $NEO4J_PATH/neo4j-import:/var/lib/neo4j/import  --name $NEO4J_DOCKER_NAME \
--env-file $NEO4J_PATH/.env.docker neo4j:4.4.21
logInfo "Starting Neo4j..."
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

logInfo 'Creating Excel'
mkdir -p $NEO4J_PATH/output
docker run --rm -v $NEO4J_PATH/output:/output -v $NEO4J_PATH/neo4j-import:/import:ro -v $NEO4J_PATH/:/code:ro -w /code -i python:latest bash -c "pip3 install xlsxwriter; python3 /code/excelGenerator.py"


logInfo "Cleaning up old docker named $NEO4J_DOCKER_NAME"
docker kill $NEO4J_DOCKER_NAME 2>/dev/null
docker rm $NEO4J_DOCKER_NAME 2>/dev/null