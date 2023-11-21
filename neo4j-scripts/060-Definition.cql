WITH "

MATCH (g:Group)
WHERE
	   g.objectid ENDS WITH '-512'
	OR g.objectid ENDS WITH '-517'
	OR g.objectid ENDS WITH '-518'
	OR g.objectid ENDS WITH '-519'
	OR g.objectid ENDS WITH '-520'
	OR g.objectid ENDS WITH '-526'
	OR g.objectid ENDS WITH '-527'
	OR g.objectid ENDS WITH '-1101'
	OR g.objectid ENDS WITH '-S-1-5-32-544'
	OR g.objectid ENDS WITH '-S-1-5-32-548'
	OR g.objectid ENDS WITH '-S-1-5-32-574'
return apoc.text.capitalizeAll(toLower(SPLIT(g.name,'@')[0])) AS `List of Tier0 items`

	
" AS query

CALL apoc.export.csv.query(query, "Report-Definition-T0.csv", {}) 
YIELD data
RETURN data;