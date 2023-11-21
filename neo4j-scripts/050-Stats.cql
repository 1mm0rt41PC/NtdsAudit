WITH "

      OPTIONAL MATCH (u:User) WHERE u.samaccountname IS NOT NULL RETURN 'Number of accounts' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User{enabled:True}) WHERE u.samaccountname IS NOT NULL RETURN 'Number of active accounts' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User{enabled:True,passwordnotreqd:True}) WHERE u.samaccountname IS NOT NULL RETURN 'Number of active users which do not require a password' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User{enabled:True,pwdneverexpires:True}) WHERE u.samaccountname IS NOT NULL RETURN 'Number of active users with non-expiring passwords' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User{enabled:True,isMemberOfTier0:True}) WHERE u.samaccountname IS NOT NULL RETURN 'Number of active Tier0 Admin' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User{owned:True}) WHERE u.samaccountname IS NOT NULL RETURN 'Number of compromised accounts' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User{owned:True,enabled:True}) WHERE u.samaccountname IS NOT NULL AND u.owned = TRUE RETURN 'Number of compromised active accounts' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User{owned:True,enabled:True,isMemberOfTier0:True}) WHERE u.samaccountname IS NOT NULL RETURN 'Number of compromised active Tier0 Admin' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User) WHERE u.samaccountname IS NOT NULL AND u.weakAclPathCount > 0 RETURN 'Number of users that can take over AD items' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User) WHERE u.samaccountname IS NOT NULL AND u.tier0PathCount > 0 RETURN 'Number of users that can take over AD Tier0 items' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User{enabled:True,pwdBadWord:True}) WHERE u.samaccountname IS NOT NULL RETURN 'Number of active users who use a banned word in their password' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User{owned:True,enabled:True,pwdBadWord:True,isMemberOfTier0:True}) WHERE u.samaccountname IS NOT NULL RETURN 'Number of active Tier0 users that have an banned word as password' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User{pwdHIBP:True,enabled:True}) WHERE u.samaccountname IS NOT NULL RETURN 'Number of active users that use a leaked password' AS `Info`, COUNT(u) AS Number
UNION OPTIONAL MATCH (u:User{pwdHIBP:True,enabled:True,isMemberOfTier0:True}) WHERE u.samaccountname IS NOT NULL RETURN 'Number of active Tier0 users that use a leaked password' AS `Info`, COUNT(u) AS Number

	
" AS query

CALL apoc.export.csv.query(query, "Report-Stats.csv", {}) 
YIELD data
RETURN data;
