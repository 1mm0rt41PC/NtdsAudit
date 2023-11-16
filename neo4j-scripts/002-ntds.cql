CALL db.clearQueryCaches;

// Init
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

// Create a fields that contains all group that users is MemberOf
MATCH (u:User)-[:MemberOf]->(g:Group) SET u.memberOf = u.memberOf+g.samaccountname+' / ';
// Clean up the field
MATCH (u:User) WHERE u.memberOf IS NOT NULL SET u.memberOf=left(u.memberOf,size(u.memberOf)-3);

// Mark all users of critical groups => memberOf Tier0
MATCH (u:User)-[:MemberOf*..]->(g:Group)
WHERE
	   g.objectid ENDS WITH '-512'
	OR g.objectid ENDS WITH '-517'
	OR g.objectid ENDS WITH '-518'
	OR g.objectid ENDS WITH '-519'
	OR g.objectid ENDS WITH '-520'
	OR g.objectid ENDS WITH '-526'
	OR g.objectid ENDS WITH '-527'
	OR g.objectid ENDS WITH '-1101'
	OR g.objectid ENDS WITH '-S-1-5-32-544'
	OR g.objectid ENDS WITH '-S-1-5-32-548'
	OR g.objectid ENDS WITH '-S-1-5-32-574'
SET
	u.isMemberOfTier0=True,
	g.highvalue=True;


// Load all hashes
MATCH (d:Domain) WHERE d.domainsid IS NOT NULL
WITH d.domainsid AS domainSid
LOAD CSV WITH HEADERS FROM 'file:///secretdumps.csv' AS row
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
		u.pwdHIBP    = FALSE;


// Load pwnd hashes
LOAD CSV WITH HEADERS FROM 'file:///weak-hashes.csv' AS row FIELDTERMINATOR ':'
WITH row
WHERE
	row IS NOT NULL AND row.nthash IS NOT NULL
MATCH (u:User{pwdNtHash:row.nthash})
SET
	u.owned = TRUE,
	u.pwdClearText = row.b64pass;
	
	
// Load HIBP
LOAD CSV FROM 'file:///hibp.csv' AS row
WITH row
WHERE
	row IS NOT NULL AND row[0] IS NOT NULL
WITH row[0] as nthash
MATCH (u:User{pwdNtHash:nthash})
SET
	u.owned          = TRUE,
	u.pwdHIBP        = TRUE;


// Load Bad words
LOAD CSV FROM 'file:///bad-words-nt.csv' AS row
WITH row
WHERE
	row IS NOT NULL AND row[0] IS NOT NULL
WITH row[0] as nthash
MATCH (u:User{pwdNtHash:nthash})
SET
	u.owned          = TRUE,
	u.pwdBadWord     = TRUE;


// Load Length
LOAD CSV WITH HEADERS FROM 'file:///pass_len.csv' AS row
WITH row
WHERE
	row IS NOT NULL AND row.nthash IS NOT NULL
MATCH (u:User{pwdNtHash:row.nthash})
SET
	u.owned          = TRUE,
	u.pwdLength      = toInteger(row.len);


// Empty password
MATCH (u:User{pwdNtHash:'?'})
SET
	u.owned        = TRUE,
	u.pwdNtHash    = '31D6CFE0D16AE931B73C59D7E0C089C0',
	u.pwdClearText = 'PEVNUFRZPg==',
	u.pwdLength    = 0;


// Keep cache of critical path
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
