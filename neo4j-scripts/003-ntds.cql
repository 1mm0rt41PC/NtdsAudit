CALL db.clearQueryCaches;

RETURN 'Init' AS `003-ntds.cql`;
MATCH (u:User)
	SET
		u.owned            = FALSE,
		u.pwdNtHash        = '?',
		u.pwdClearText     = NULL,
		u.pwdBadWord       = FALSE,
		u.pwdLength        = -1,
		u.tier0PathCount   = 0,
		u.tier0Path        = '',
		u.weakAclPath      = '',
		u.weakAclPathCount = 0,
		u.memberOf         = '',
		u.isMemberOfTier0  = FALSE,
		u.pwdHIBP          = FALSE;

RETURN 'Create a fields that contains all groups that users is MemberOf' AS `003-ntds.cql`;
// Create a fields that contains all groups that users is MemberOf
MATCH (u:User)-[:MemberOf]->(g:Group) SET u.memberOf = u.memberOf+g.samaccountname+' / ';
// Clean up the field
MATCH (u:User) WHERE u.memberOf IS NOT NULL SET u.memberOf=left(u.memberOf,size(u.memberOf)-3);


// Load all hashes
RETURN 'Load all hashes' AS `003-ntds.cql`;
MATCH (d:Domain) WHERE d.domainsid IS NOT NULL
WITH d.domainsid AS domainSid
LOAD CSV WITH HEADERS FROM 'file:///secretsdump.csv' AS row
WITH row,domainSid
WHERE
	row IS NOT NULL AND row.sid IS NOT NULL
WITH (domainSid+"-"+row.sid) AS userSID, row.nthash as nthash
MATCH (u:User{objectid:userSID})
	SET
		u.owned      = FALSE,
		u.pwdNtHash  = nthash,
		u.pwdBadWord = FALSE,
		u.pwdLength  = -1,
		u.pwdHIBP    = FALSE
RETURN COUNT(u) AS `Nb hash loaded`;


// Load pwnd hashes
RETURN 'Load pwnd hashes' AS `003-ntds.cql`;
LOAD CSV WITH HEADERS FROM 'file:///weak-hashes.csv' AS row FIELDTERMINATOR ':'
WITH row
WHERE
	row IS NOT NULL AND row.nthash IS NOT NULL
MATCH (u:User{pwdNtHash:row.nthash})
SET
	u.owned = TRUE,
	u.pwdClearText = row.b64pass;
	
	
// Load HIBP
RETURN 'Load HIBP' AS `003-ntds.cql`;
LOAD CSV FROM 'file:///hibp.csv' AS row
WITH row
WHERE
	row IS NOT NULL AND row[0] IS NOT NULL
WITH row[0] as nthash
MATCH (u:User{pwdNtHash:nthash})
SET
	u.owned          = TRUE,
	u.pwdHIBP        = TRUE
RETURN COUNT(u) AS `Nb hash found in HIBP loaded`;


// Load Bad words
RETURN 'Load Bad words' AS `003-ntds.cql`;
LOAD CSV FROM 'file:///bad-words-nt.csv' AS row
WITH row
WHERE
	row IS NOT NULL AND row[0] IS NOT NULL
WITH row[0] as nthash
MATCH (u:User{pwdNtHash:nthash})
SET
	u.owned          = TRUE,
	u.pwdBadWord     = TRUE
RETURN COUNT(u) AS `Nb hash found with banned word loaded`;



// Load Length
RETURN 'Load Length' AS `003-ntds.cql`;
LOAD CSV WITH HEADERS FROM 'file:///pass_len.csv' AS row
WITH row
WHERE
	row IS NOT NULL AND row.nthash IS NOT NULL
MATCH (u:User{pwdNtHash:row.nthash})
SET
	u.owned          = TRUE,
	u.pwdLength      = toInteger(row.len);


// Empty password
RETURN 'Set Empty password' AS `003-ntds.cql`;
MATCH (u:User{pwdNtHash:'?'})
SET
	u.owned        = TRUE,
	u.pwdNtHash    = '31D6CFE0D16AE931B73C59D7E0C089C0',
	u.pwdClearText = 'PEVNUFRZPg==',
	u.pwdLength    = 0;

// Fix bad name
MATCH (u) WHERE u.name IS NULL AND u.samaccountname IS NOT NULL SET u.name = u.samaccountname RETURN COUNT(u) AS `Nb object with SAN without NAME`;
MATCH (u) WHERE u.name IS NULL SET u.name = u.objectid RETURN COUNT(u) AS `Nb object without NAME`;

// Keep cache of critical path
RETURN 'Keep cache of critical path' AS `003-ntds.cql`;
MATCH (g) WHERE g.highvalue=True OR g.isMemberOfTier0=True
WITH g
MATCH p=(u:User{isMemberOfTier0:False})-[*1..3]->(g)
SET
	u.tier0PathCount = 0,
	u.tier0Path = ''
WITH u,g,p
WITH [rel in relationships(p) | STARTNODE(rel).name + ' -[' + type(rel)+']=> '] as relationshipLabels,u,p
WITH reduce(relPath="", relLabel in relationshipLabels | relPath + relLabel+ '')+LAST(nodes(p)).name AS relPath, u
SET
	u.tier0Path = u.tier0Path+relPath+'\n',
	u.tier0PathCount = u.tier0PathCount + 1;
//RETURN relPath;

RETURN 'Keep cache of weak ACL' AS `003-ntds.cql`;
MATCH p=(u:User)-[r]->()
WHERE LEFT(u.samaccountname,5)<>"MSOL_" AND type(r)<>"MemberOf"
SET
	u.weakAclPathCount = 0,
	u.weakAclPath = ''
WITH u,p
WITH [rel in relationships(p) | STARTNODE(rel).name + ' -[' + type(rel)+']=> '] as relationshipLabels,u,p
WITH reduce(relPath="", relLabel in relationshipLabels | relPath + relLabel+ '')+LAST(nodes(p)).name AS relPath, u
SET
	u.weakAclPath = u.weakAclPath+relPath+'\n',
	u.weakAclPathCount = u.weakAclPathCount + 1;
