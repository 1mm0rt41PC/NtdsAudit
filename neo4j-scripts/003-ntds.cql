CALL db.clearQueryCaches;

RETURN 'Init' AS `003-ntds.cql`;
Call {
MATCH (u:User)
	SET
		u.owned                = FALSE,
		u.pwdNtHash            = '<NO NTHASH>',
		u.pwdClearText         = '<NO NTHASH>',
		u.pwdClearTextB64      = '<NO NTHASH>',
		u.pwdBadWord           = FALSE,
		u.pwdLength            = -1,
		u.tier0PathCount       = 0,
		u.tier0Path            = '',
		u.weakAclPath          = '',
		u.weakAclPathCount     = 0,
		u.canGenericAllOnTier0 = False,
		u.memberOf             = '',
		u.pwdHIBP              = FALSE
}  IN TRANSACTIONS OF 500 ROWS;


RETURN 'Create a fields that contains all groups that users is MemberOf' AS `003-ntds.cql`;
// Create a fields that contains all groups that users is MemberOf
MATCH p=(u:User)-[:MemberOf]->(g:Group)
WITH LAST(NODES(p)).name AS groupName,u
WITH COLLECT(groupName) AS memberOf,u
SET u.memberOf=apoc.text.join(memberOf, ' / ');


// Load all hashes
RETURN 'Load all hashes' AS `003-ntds.cql`;
MATCH (d:Domain) WHERE d.domainsid IS NOT NULL
WITH d.domainsid AS domainSid
LOAD CSV WITH HEADERS FROM 'file:///secretsdump.csv' AS row
WITH row,domainSid
WHERE
	row IS NOT NULL AND row.sid IS NOT NULL
WITH (domainSid+"-"+row.sid) AS userSID, row
MATCH (u:User{objectid:userSID})
SET
	u.owned            = toBoolean(row.pwned),
	u.pwdNtHash        = row.nthash,
	u.pwdBadWord       = toBoolean(row.HasBannedWord),
	u.pwdLength        = toInteger(row.len),
	u.pwdHIBP          = toBoolean(row.isPublicLeak),
	u.pwdClearText     = row.b64pass,
	u.pwdClearTextB64  = row.b64pass
RETURN COUNT(u) AS `Nb hash loaded`;

// Define cleartext password
MATCH (u:User) WHERE u.pwdClearTextB64 <> "" AND u.pwdClearTextB64 IS NOT NULL AND u.pwdClearTextB64<>"<NO NTHASH>" SET u.pwdClearText=apoc.text.base64Decode(u.pwdClearTextB64);

// Password not found
MATCH (u:User)
WHERE u.pwdNtHash<>'<NO NTHASH>' AND u.pwdNtHash IS NOT NULL AND (u.pwdClearText='' OR u.pwdClearText IS NULL)
SET
	u.owned=false,
	u.pwdLength=-1,
	u.pwdClearText='<NOT FOUND>',
	u.pwdClearTextB64='<NOT FOUND>';

// Custom text for empty password
MATCH (u:User{pwdNtHash:'31D6CFE0D16AE931B73C59D7E0C089C0'})
SET
	u.owned=true,
	u.pwdLength=0,
	u.pwdClearText='<EMPTY PASSWORD>',
	u.pwdClearTextB64='<EMPTY PASSWORD>';

// Fix bad name
MATCH (u) WHERE u.name IS NULL AND u.samaccountname IS NOT NULL SET u.name = u.samaccountname RETURN COUNT(u) AS `Nb object with SAN without NAME`;
MATCH (u) WHERE u.name IS NULL SET u.name = u.objectid RETURN COUNT(u) AS `Nb object without NAME`;


// Speedup path computation
RETURN 'Speedup path computation' AS `003-ntds.cql`;
MATCH (g:Group) WHERE g.highvalue=True OR g.isMemberOfTier0=True
WITH g
MATCH (u{isMemberOfTier0:False})-[r:MemberOf]->(g) SET u.isMemberOfTier0=True;
MATCH (g:Group) WHERE g.highvalue=True OR g.isMemberOfTier0=True
WITH g
MATCH (u{isMemberOfTier0:False})-[r:MemberOf]->(g) SET u.isMemberOfTier0=True;
MATCH (g:Group) WHERE g.highvalue=True OR g.isMemberOfTier0=True
WITH g
MATCH (u{isMemberOfTier0:False})-[r:MemberOf]->(g) SET u.isMemberOfTier0=True;
MATCH (g:Group) WHERE g.highvalue=True OR g.isMemberOfTier0=True
WITH g
MATCH (u{isMemberOfTier0:False})-[r:MemberOf]->(g) SET u.isMemberOfTier0=True;
MATCH (g:Group) WHERE g.highvalue=True OR g.isMemberOfTier0=True
WITH g
MATCH (u{isMemberOfTier0:False})-[r:MemberOf]->(g) SET u.isMemberOfTier0=True;
//
MATCH (g) WHERE g.highvalue=True OR g.isMemberOfTier0=True OR g.canGenericAllOnTier0=True
WITH g
MATCH (u{isMemberOfTier0:False})-[r]->(g) WHERE type(r) <> 'MemberOf' SET u.canGenericAllOnTier0=True;
MATCH (u{isMemberOfTier0:False})-[r:MemberOf]->(g:Group{canGenericAllOnTier0:True}) SET u.canGenericAllOnTier0=True;
MATCH (g) WHERE g.highvalue=True OR g.isMemberOfTier0=True OR g.canGenericAllOnTier0=True
WITH g
MATCH (u{isMemberOfTier0:False})-[r]->(g) WHERE type(r) <> 'MemberOf' SET u.canGenericAllOnTier0=True;
MATCH (u{isMemberOfTier0:False})-[r:MemberOf]->(g:Group{canGenericAllOnTier0:True}) SET u.canGenericAllOnTier0=True;
MATCH (g) WHERE g.highvalue=True OR g.isMemberOfTier0=True OR g.canGenericAllOnTier0=True
WITH g
MATCH (u{isMemberOfTier0:False})-[r]->(g) WHERE type(r) <> 'MemberOf' SET u.canGenericAllOnTier0=True;
MATCH (u{isMemberOfTier0:False})-[r:MemberOf]->(g:Group{canGenericAllOnTier0:True}) SET u.canGenericAllOnTier0=True;
MATCH (g) WHERE g.highvalue=True OR g.isMemberOfTier0=True OR g.canGenericAllOnTier0=True
WITH g
MATCH (u{isMemberOfTier0:False})-[r]->(g) WHERE type(r) <> 'MemberOf' SET u.canGenericAllOnTier0=True;
MATCH (u{isMemberOfTier0:False})-[r:MemberOf]->(g:Group{canGenericAllOnTier0:True}) SET u.canGenericAllOnTier0=True;
MATCH (g) WHERE g.highvalue=True OR g.isMemberOfTier0=True OR g.canGenericAllOnTier0=True
WITH g
MATCH (u{isMemberOfTier0:False})-[r]->(g) WHERE type(r) <> 'MemberOf' SET u.canGenericAllOnTier0=True;
MATCH (u{isMemberOfTier0:False})-[r:MemberOf]->(g:Group{canGenericAllOnTier0:True}) SET u.canGenericAllOnTier0=True;
MATCH (g) WHERE g.highvalue=True OR g.isMemberOfTier0=True OR g.canGenericAllOnTier0=True
WITH g
MATCH (u{isMemberOfTier0:False})-[r]->(g) WHERE type(r) <> 'MemberOf' SET u.canGenericAllOnTier0=True;
MATCH (u{isMemberOfTier0:False})-[r:MemberOf]->(g:Group{canGenericAllOnTier0:True}) SET u.canGenericAllOnTier0=True;


// Keep cache of critical path
RETURN 'Keep cache of critical path' AS `003-ntds.cql`;
MATCH p=(u:User{isMemberOfTier0:false,isTier0:false})-[r*1..3]->(t)
WHERE
	t.highvalue=True OR t.isMemberOfTier0=True or t.canGenericAllOnTier0=True
WITH u,p,[rel in relationships(p) | STARTNODE(rel).name + ' -[' + type(rel)+']=> '] as relationshipLabels
WITH reduce(relPath="", relLabel in relationshipLabels | relPath + relLabel+ '')+LAST(nodes(p)).name AS relPath, u
WITH count(relPath) as nbRel, collect(relPath) as relPathArray, u
SET
	u.tier0PathCount = nbRel,
	u.tier0Path = relPathArray;


RETURN 'Keep cache of weak ACL' AS `003-ntds.cql`;
MATCH p=(u:User)-[r]->(t)  
WHERE LEFT(u.samaccountname,5)<>"MSOL_" AND type(r)<>"MemberOf"
WITH u,p,[rel in relationships(p) | STARTNODE(rel).name + ' -[' + type(rel)+']=> '] as relationshipLabels
WITH reduce(relPath="", relLabel in relationshipLabels | relPath + relLabel+ '')+LAST(nodes(p)).name AS relPath, u
WITH count(relPath) as nbRel, collect(relPath) as relPathArray, u
SET
	u.weakAclPathCount = nbRel,
	u.weakAclPath = apoc.text.join(relPathArray,'\n');