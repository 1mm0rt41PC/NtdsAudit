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
	OR g.objectid ENDS WITH '-522'// Clonable Domain Controllers
	OR g.objectid ENDS WITH '-525'// Protected Users
	OR g.objectid ENDS WITH '-526'// Key Admins
	OR g.objectid ENDS WITH '-527'// Enterprise Key Admins
//	OR g.objectid ENDS WITH '-574'// Certificate Service DCOM Access
	OR g.objectid ENDS WITH 'S-1-5-9'// Enterprise Domain Controllers
	OR g.objectid ENDS WITH 'S-1-5-32-544'// Administrators
	OR g.objectid ENDS WITH 'S-1-5-32-547'// Power Users
	OR g.objectid ENDS WITH 'S-1-5-32-548'// Account Operators
	OR g.objectid ENDS WITH 'S-1-5-32-549'// Server Operators
	OR g.objectid ENDS WITH 'S-1-5-32-550'// Print Operators
	OR g.objectid ENDS WITH 'S-1-5-32-551'// Backup Operators
	OR g.objectid ENDS WITH 'S-1-5-32-552'// Replicator
	OR g.objectid ENDS WITH 'S-1-5-32-557'// BUILTIN\Incoming Forest Trust Builders
	OR g.samaccountname = 'DNSADMINS'
SET
	g.isTier0=True,
	g.isTier0Reason='Core System',
	g.highvalue=True;
	
// High value for CA manager
MATCH p=(x)-[:ManageCa|ManageCertificates]->()
WHERE x.isTier0Reason IS NULL
SET
	x.highvalue=True,
	x.isTier0=True,
	x.isTier0Reason='PKI Administrator';

// DcSync users
MATCH p=(x)-[:DCSync|AllExtendedRights|GenericAll]->(:Domain)
WHERE x.isTier0Reason IS NULL
SET
	x.highvalue=True,
	x.isTier0=True,
	x.isTier0Reason='Allowed to copy domain and all passwords (DCSync)';

// SCCM
MATCH (u)
WHERE
	u.isTier0Reason IS NULL
	AND (
		   toLower(u.description) CONTAINS 'sccm' or toLower(u.samaccountname) CONTAINS 'sccm'
		OR toLower(u.description) CONTAINS 'veeam' or toLower(u.samaccountname) CONTAINS 'veeam'
		OR toLower(u.description) CONTAINS 'bomgar' or toLower(u.samaccountname) CONTAINS 'bomgar'
		OR toLower(u.description) CONTAINS 'altiris' or toLower(u.samaccountname) CONTAINS 'altiris'
	)
SET
	u.highvalue=true,
	u.isTier0=true,
	u.isTier0Reason='System deployement';

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