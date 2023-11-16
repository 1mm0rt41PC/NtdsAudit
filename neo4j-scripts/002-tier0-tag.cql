CALL db.clearQueryCaches;

// Mark all users of critical groups => memberOf Tier0
MATCH (u:User)-[:MemberOf*..]->(g:Group)
WHERE
	   g.objectid ENDS WITH '-512'
	OR g.objectid ENDS WITH '-517'// CERT PUBLISHERS
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
