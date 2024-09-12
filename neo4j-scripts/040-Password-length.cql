WITH "

MATCH (u:User) WHERE u.pwdNtHash <> '?'
WITH COUNT(u.pwdLength) AS nb, CASE u.pwdLength
	WHEN -1 THEN 'Secure password'
	ELSE 'Weak password with a length of '+u.pwdLength
END AS lenTxt,u.pwdLength AS len
RETURN lenTxt AS `Info`,nb AS `Number of`
ORDER BY len
	
" AS query

CALL apoc.export.csv.query(query, "Report-Passwords-length.csv", {}) 
YIELD data
RETURN data;
