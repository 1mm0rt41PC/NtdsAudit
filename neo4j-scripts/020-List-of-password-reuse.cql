WITH "

MATCH (u:User)
WHERE u.samaccountname IS NOT NULL AND u.pwdNtHash IS NOT NULL
WITH u.pwdNtHash AS pwdNtHash, COUNT(*) as nb, u.pwdClearText AS pwdClearText
WHERE nb > 2
RETURN pwdNtHash AS `Hash`, nb AS `Reused`, CASE pwdClearText
	WHEN NULL THEN '<NOT FOUND>'
	ELSE apoc.text.base64Decode(pwdClearText)
END AS `ClearText`
ORDER BY nb DESC;
	
" AS query

CALL apoc.export.csv.query(query, "Report-List-of-password-reuse.csv", {}) 
YIELD data
RETURN data;