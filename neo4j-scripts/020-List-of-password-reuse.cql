WITH "

MATCH (u:User)
WHERE u.samaccountname IS NOT NULL AND u.pwdNtHash IS NOT NULL AND u.pwdNtHash<>'<NO NTHASH>' AND u.pwdNtHash<>'?' AND u.pwdNtHash<>''
WITH u.pwdNtHash AS pwdNtHash, COUNT(*) AS nb, u.pwdClearText AS pwdClearText, u.pwdHIBP AS pwdHIBP
WHERE nb > 2
RETURN pwdNtHash AS `Hash`, nb AS `Reused`, pwdClearText, pwdHIBP AS `Password leaked on the Internet`
ORDER BY nb DESC;
	
" AS query

CALL apoc.export.csv.query(query, "Report-List-of-password-reuse.csv", {}) 
YIELD data
RETURN data;



WITH "

MATCH (u:User)
WHERE u.samaccountname IS NOT NULL AND u.pwdNtHash IS NOT NULL AND u.pwdNtHash<>'<NO NTHASH>' AND u.pwdNtHash<>'?' AND u.pwdNtHash<>'' and u.pwdHIBP = TRUE
WITH u.pwdNtHash AS pwdNtHash, COUNT(*) AS nb, u.pwdClearText AS pwdClearText, u.pwdHIBP AS pwdHIBP
RETURN pwdNtHash AS `Hash`, pwdClearText
ORDER BY nb DESC;
	
" AS query

CALL apoc.export.csv.query(query, "Report-List-of-password-leaked.csv", {}) 
YIELD data
RETURN data;
