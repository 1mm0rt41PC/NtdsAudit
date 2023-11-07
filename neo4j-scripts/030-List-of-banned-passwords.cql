WITH "

MATCH (u:User{enabled:True,pwdBadWord:True})
WHERE u.samaccountname IS NOT NULL AND u.pwdClearText IS NOT NULL
WITH apoc.text.base64Decode(u.pwdClearText) AS `ClearText`, COUNT(u.pwdClearText) as nb, u.pwdNtHash AS NtHash
RETURN NtHash, ClearText, nb AS `Reused`
ORDER BY nb DESC;
	
" AS query

CALL apoc.export.csv.query(query, "Report-List-of-banned-passwords.csv", {}) 
YIELD data
RETURN data;