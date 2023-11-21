CALL db.clearQueryCaches;

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
