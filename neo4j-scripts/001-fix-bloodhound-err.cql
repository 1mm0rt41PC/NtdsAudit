CALL db.clearQueryCaches;

// Fix tipo in bloodhound
MATCH (c) WHERE c.samaccoutname IS NOT NULL SET c.samaccountname=toUpper(c.samaccoutname);
MATCH (c) WHERE c.samaccoutname IS NOT NULL SET c.samaccoutname=NULL;
MATCH (c:Computer) WHERE c.name IS NULL SET c.name=replace(c.samaccountname,'$','')+'.'+c.domain;
// Fix group naming
MATCH (g:Group) WHERE g.name IS NULL SET g.name=(CASE WHEN g.samaccountname IS NULL THEN g.objectid ELSE g.samaccountname END);
MATCH (g:Group) WHERE g.samaccountname IS NULL SET g.samaccountname=SPLIT(g.name,"@")[0];
MATCH (c) WHERE c.name IS NULL SET c.name=replace(c.samaccountname,'$','')+'?'+c.domain;


// Normalize fields in bloodhound
MATCH (uc)
WHERE (uc:Computer OR uc:User)
	AND (
		uc.lastlogontimestamp IS NULL
	OR
		uc.lastlogon IS NULL
	)
SET uc.lastlogontimestamp = CASE
    WHEN uc.lastlogontimestamp IS NULL THEN -1
    WHEN uc.lastlogontimestamp >= uc.lastlogon THEN uc.lastlogontimestamp
    ELSE uc.lastlogon
    END,
    uc.lastlogon = CASE
    WHEN uc.lastlogon IS NULL OR uc.lastlogon = -1 THEN -1
    WHEN uc.lastlogon >= uc.lastlogontimestamp THEN uc.lastlogon
    ELSE uc.lastlogontimestamp
    END;


MATCH (g:Group) WHERE g.objectid ENDS WITH '-S-1-5-11' SET g.name = "Authenticated Users@"+g.domain;


// Create a relation MemberOf between authenticated users and S-1-5-11
MATCH (g:Group{objectid:"S-1-5-11"})
MATCH (g2:Group) WHERE g2.objectid = toUpper(g2.domain)+'-S-1-5-11'
MERGE (g)-[r1:MemberOf]->(g2)
MERGE (g2)-[r2:MemberOf]->(g);


// Fix GPO labels
MATCH (g:Gpo) SET g:GPO REMOVE g:Gpo;


// Normalize Cert
MATCH (n:GPO) WHERE n.type = 'Certificate Template' SET n:CertificateTemplate;
MATCH (n:GPO) WHERE n.type = 'Enrollment Service' SET n:CA;

MATCH (c) WHERE c.samaccountname IS NOT NULL SET c.samaccountname=toUpper(c.samaccountname);
