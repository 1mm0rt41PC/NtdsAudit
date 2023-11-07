CALL db.clearQueryCaches;
// Speedup database (from Bloodhound)
MATCH (n) OPTIONAL MATCH (n)-[r]->() RETURN count(n.name) + count(r.isacl)