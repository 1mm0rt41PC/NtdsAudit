CALL db.clearQueryCaches;

// Mark all users of critical groups => memberOf Tier0
MATCH (g:Group)
WHERE
	   g.objectid ENDS WITH '-498'// Enterprise Read-only Domain Controllers
	OR g.objectid ENDS WITH '-512'// Domain Admins
	OR g.objectid ENDS WITH '-516'// Domain Controllers
	OR g.objectid ENDS WITH '-517'// Cert Publishers
	OR g.objectid ENDS WITH '-518'// Schema Admins
	OR g.objectid ENDS WITH '-519'// Enterprise Admins
	OR g.objectid ENDS WITH '-520'// Group Policy Creator Owners
	OR g.objectid ENDS WITH '-521'// Read-only Domain Controllers
	OR g.objectid ENDS WITH '-526'// Key Admins
	OR g.objectid ENDS WITH '-527'// Enterprise Key Admins
	OR g.objectid ENDS WITH '-574'// Certificate Service DCOM Access
	OR g.objectid ENDS WITH '-S-1-5-9'// Enterprise Domain Controllers
	OR g.objectid ENDS WITH '-S-1-5-32-544'// Administrators
	OR g.objectid ENDS WITH '-S-1-5-32-548'// Account Operators
	OR g.objectid ENDS WITH '-S-1-5-32-549'// Server Operators
	OR g.objectid ENDS WITH '-S-1-5-32-550'// Print Operators
	OR g.objectid ENDS WITH '-S-1-5-32-551'// Backup Operators
	OR g.objectid ENDS WITH '-S-1-5-32-552'// Replicator
	OR g.objectid ENDS WITH '-S-1-5-32-574'// Certificate Service DCOM Access
	OR g.samaccountname = 'DNSADMINS'
SET
	g.isTier0=True,
	g.highvalue=True;

// DcSync users
MATCH p=(x)-[:DCSync|AllExtendedRights|GenericAll]->(:Domain) SET x.highvalue=True; // return p;

// SCCM
MATCH (u) where toLower(u.description) CONTAINS 'sccm' or toLower(u.distinguishedname) CONTAINS 'sccm' set u.highvalue=true; // return u.samaccountname,u.description;

// Veeam
MATCH (u) where toLower(u.description) CONTAINS 'veeam' or toLower(u.distinguishedname) CONTAINS 'veeam' set u.highvalue=true; // return u.samaccountname,u.description;
MATCH (u) where toLower(u.description) CONTAINS 'bomgar' or toLower(u.distinguishedname) CONTAINS 'bomgar' set u.highvalue=true; // return u.samaccountname,u.description;

// Mark GPO that apply to high value target a high value target
MATCH p1 = (g:GPO)-[r:GPLink]->(container: OU)-[r2:Contains*1..]->(n2{highvalue: true}) SET g.highvalue=true;

// Mark all member of high value as high value
MATCH (u:User)-[:MemberOf*1..]->(g:Group{highvalue:true}) SET u.highvalue=true;



// Mark all users of critical groups => memberOf Tier0
MATCH (g:Group{isTier0:True})
WITH g
MATCH (u:User)-[:MemberOf*..]->(g)
SET
	u.isMemberOfTier0=True;