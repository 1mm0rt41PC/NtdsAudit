WITH "

MATCH (g:Group{isTier0:True})
RETURN g.domain AS Domain, apoc.text.capitalizeAll(toLower(SPLIT(g.name,'@')[0])) AS `List of Tier0 items`, g.isTier0Reason AS `Tier0 reason`;

	
" AS query

CALL apoc.export.csv.query(query, "Report-Definition-T0.csv", {}) 
YIELD data
RETURN data;
