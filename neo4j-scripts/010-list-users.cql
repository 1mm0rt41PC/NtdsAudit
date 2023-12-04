WITH "

MATCH (u:User)
WHERE u.samaccountname IS NOT NULL
RETURN
	u.objectid AS SID,
	u.samaccountname AS `SamAccountName`,
	u.distinguishedname AS `Distinguished Name`,
	date(datetime({epochSeconds:toInteger(u.lastlogontimestamp)})) AS LastLogon,
	u.enabled AS Enabled,
	u.owned AS `Weak password`,
	u.pwdClearText AS `b64:`,
	u.pwdBadWord AS `Password containing a forbidden word`,
	u.pwdLength AS `Password length`,u.pwdHIBP AS `Password leaked on the Internet`,
	u.pwdneverexpires AS `Password never expires`,
	u.passwordnotreqd AS `Password not required`,
	date(datetime({epochSeconds:toInteger(u.pwdlastset)})) AS `Password last set`,
	u.unconstraineddelegation AS `Unconstrained Delegation`,
	u.hasspn AS `Has SPN`,
	u.admincount AS `Was in a Tier0 group`,
	u.isMemberOfTier0 AS `Member Of Tier0`,
	u.tier0PathCount AS `Number of items of Tier0 that can be compromised`,
	u.tier0Path AS `Path to item of Tier0 that can be compromised`,
	u.weakAclPathCount AS `Number of items that can be compromised`,
	u.weakAclPath AS `Path to item that can be compromised`,
	u.memberOf AS `Member Of`
	ORDER BY u.isMemberOfTier0, u.tier0PathCount DESC
	
" AS query

CALL apoc.export.csv.query(query, "Report-List-Of-Users.csv", {}) 
YIELD data
RETURN data;
