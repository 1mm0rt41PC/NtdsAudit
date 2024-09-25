CALL db.clearQueryCaches;

RETURN "[*] Mark HasSession of SPN" AS `002-tier0-tag.cql`;
// FNCEWS/host_name
// FNCEWS/host_name@DOMAIN.COM
// FNCEWS/host_name.DOMAIN.COM
// classe_du_service/hostname_ou_FQDN
// classe_du_service/hostname_ou_FQDN:port
// classe_du_service/hostname_ou_FQDN:port/nom_arbitraire

// Mark HasSession of SPN
MATCH (u:User{hasspn:True})
WHERE NOT (u.objectid ENDS WITH '-502')
UNWIND u.serviceprincipalnames AS spn
WITH u, split(replace(toUpper(spn),'@','.'),'/') AS tmp
WITH u, tmp[0] AS krbService, split(tmp[1],':') AS tmp
WITH u, split(tmp[0],'.')[0]+'$' AS san, (CASE WHEN size(tmp)>1 THEN krbService+':'+tmp[1] ELSE krbService END) AS krbService
MATCH (c:Computer{samaccountname:san})
MERGE (c)-[r:HasSession]->(u)
	SET r.port=apoc.coll.toSet(coalesce(r.port, []) + [krbService])
MERGE q=(c)-[r2:HasKerberosService]->(u)
	SET r2.port=apoc.coll.toSet(coalesce(r.port, []) + [krbService])
RETURN COUNT(r) AS `Nb Sessions VIA SPN`;


RETURN "[*] List open ports via SPN" AS `002-tier0-tag.cql`;
MATCH (u:Computer)
WHERE SIZE(u.serviceprincipalnames) > 0
UNWIND [s in u.serviceprincipalnames WHERE not (toUpper(s) CONTAINS 'HOST') AND not (toUpper(s) CONTAINS 'RESTRICTEDKRBHOST')] AS spn
WITH u, split(replace(toUpper(spn),'@','.'),'/') AS tmp
WITH u, tmp[0] AS krbService, split(tmp[1],':') AS tmp
WITH u, split(tmp[0],'.')[0]+'$' AS san, 'Port '+(CASE WHEN size(tmp)>1 THEN krbService+':'+tmp[1] ELSE krbService END) AS krbService
MERGE (p:Group:Port{objectid:krbService})
	ON CREATE SET
		p.samaccountname=krbService,
		p.name=krbService
MERGE (u)-[:HasOpenPort]->(p)
MERGE (u)-[:MemberOf]->(p)
RETURN COUNT(p) AS `Nb open ports`;


// Mark all users of critical groups => memberOf Tier0
RETURN "[*] Mark all users of critical groups => memberOf Tier0" AS `002-tier0-tag.cql`;
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
	OR g.samaccountname = 'EXCHANGE WINDOWS PERMISSIONS'
SET
	g.isTier0=True,
	g.isTier0Reason='Core System',
	g.highvalue=True
RETURN g.name AS `Tier0 List - Core System`;


// High value for Azure
MATCH (g:User)
WHERE
	LEFT(g.samaccountname,5)='MSOL_'
SET
	g.isTier0=True,
	g.isTier0Reason='Core System Azure',
	g.highvalue=True
RETURN g.name AS `Tier0 List - Core System Azure`;

	
// High value for CA manager
RETURN "[*] Mark High value for CA manager" AS `002-tier0-tag.cql`;
MATCH p=(x)-[:ManageCa|ManageCertificates]->()
WHERE x.isTier0Reason IS NULL
SET
	x.highvalue=True,
	x.isTier0=True,
	x.isTier0Reason='PKI Administrator'
RETURN x.name AS `Tier0 List - PKI Administrator`;


// DcSync users
RETURN "[*] Mark High value for DcSync users" AS `002-tier0-tag.cql`;
MATCH p=(x)-[:DCSync|AllExtendedRights|GenericAll]->(:Domain)
WHERE x.isTier0Reason IS NULL
SET
	x.highvalue=True,
	x.isTier0=True,
	x.isTier0Reason='Allowed to copy domain and all passwords (DCSync)'
RETURN x.name AS `Tier0 List - DCSync`;


RETURN "[*] Mark High value for critical apps" AS `002-tier0-tag.cql`;
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
	u.highvalue=True,
	u.isTier0=True,
	u.isTier0Reason='System deployement'
RETURN u.name AS `Tier0 List - System deployement`;


// Mark GPO that apply to high value target a high value target
MATCH p1 = (g:GPO)-[r:GPLink]->(container: OU)-[r2:Contains*1..]->(n2{highvalue: True}) SET g.highvalue=True;

// Mark all member of high value as high value
MATCH (u:Group)-[:MemberOf]->(g:Group{highvalue:True}) SET u.highvalue=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{highvalue:True}) SET u.highvalue=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{highvalue:True}) SET u.highvalue=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{highvalue:True}) SET u.highvalue=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{highvalue:True}) SET u.highvalue=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{highvalue:True}) SET u.highvalue=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{highvalue:True}) SET u.highvalue=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{highvalue:True}) SET u.highvalue=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{highvalue:True}) SET u.highvalue=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{highvalue:True}) SET u.highvalue=True;
MATCH (u:User)-[:MemberOf]->(g:Group{highvalue:True}) SET u.highvalue=True;


// Mark all users of critical groups => memberOf Tier0
MATCH (u:Group)-[:MemberOf]->(g:Group{isTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:Group)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:User)-[:MemberOf]->(g:Group{isTier0:True}) SET u.isMemberOfTier0=True;
MATCH (u:User)-[:MemberOf]->(g:Group{isMemberOfTier0:True}) SET u.isMemberOfTier0=True
RETURN COUNT(u) AS `Nb Member Of Tier0`;
