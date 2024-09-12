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
export HIBPDIR=/opt/hibp
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

mkdir -p $NEO4J_PATH/neo4j-import/


########################################################################
# List of not allowed word
########################################################################
logInfo "Creating bad-words.csv & bad-words-nt.csv"
(
cat $BAD_WORD_FILE;
cat $BAD_WORD_FILE | /opt/hashcat/hashcat.bin -a 0 -r /opt/hashcat/rules/best64.rule --stdout | grep -vE '^.{1,4}$';
cat $BAD_WORD_FILE | /opt/hashcat/hashcat.bin -a 0 -r /opt/hashcat/rules/rockyou-30000.rule --stdout | grep -vE '^.{1,4}$'
) | sort -u > $NEO4J_PATH/neo4j-import/bad-words.tmp



########################################################################
# Parse secretsdump
########################################################################
docker run --rm -it -v $NEO4J_PATH/goHashcat/:$NEO4J_PATH/goHashcat/ golang:alpine bash -c "cd $NEO4J_PATH/goHashcat/; go build -o goHashcat main.go"
logInfo "Creating secretsdump.csv"
$NEO4J_PATH/goHashcat/goHashcat $SECRETSDUMP $NEO4J_PATH/neo4j-import/hashcat.potfile neo4j-import/badwords.txt $NEO4J_PATH/neo4j-import/secretsdump.csv $HIBPDIR


# Cleanup
rm -rf $NEO4J_PATH/neo4j-import/*.tmp



########################################################################
# Run docker
########################################################################
logInfo "Starting Neo4j with credentials $NEO4J_USER:$NEO4J_PASS ..."
docker run --rm -d --network=host -p 127.0.0.1:7474:7474 -p 127.0.0.1:7687:7687 \
-v $NEO4J_PATH/neo4j-conf:/var/lib/neo4j/conf -v $NEO4J_PATH/neo4j-scripts:/neo4j-scripts/ \
-v $NEO4J_PATH/neo4j-import:/var/lib/neo4j/import  --name $NEO4J_DOCKER_NAME \
--env-file $NEO4J_PATH/.env.docker neo4j:4.4.21
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
docker run --rm -v $NEO4J_PATH/output:/output -v $NEO4J_PATH/neo4j-import:/import:ro -v $NEO4J_PATH/:/code:ro -w /code -i python:latest bash -c "pip3 install xlsxwriter; python3 /code/excelGenerator.py $1"


logInfo "Cleaning up old docker named $NEO4J_DOCKER_NAME"
docker kill $NEO4J_DOCKER_NAME 2>/dev/null
docker rm $NEO4J_DOCKER_NAME 2>/dev/null