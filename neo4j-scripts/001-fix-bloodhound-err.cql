CALL db.clearQueryCaches;

// Fix tipo in bloodhound
MATCH (cp:Computer) SET cp.name=replace(cp.samaccoutname,'$','')+'.'+cp.domain, cp.samaccountname=toUpper(cp.samaccoutname);


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
MATCH (n:CertificateTemplate) SET n.samaccountname=toUpper(n.name);