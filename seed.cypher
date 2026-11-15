// Seed graph for the Knowledge Graph RAG demo.
// Incident shapes from the SRE Copilot project (seed examples only).
// Safe to re-run: MERGE never duplicates nodes or relationships.

// --- Services ---
MERGE (s:Service {name: 'payment-api'})
SET s.type = 'api';
MERGE (s:Service {name: 'database'})
SET s.type = 'postgres';
MERGE (s:Service {name: 'api-gateway'})
SET s.type = 'gateway';
MERGE (s:Service {name: 'notification-service'})
SET s.type = 'worker';

// --- Alerts ---
MERGE (a:Alert {name: 'Payment API latency high'})
SET a.severity = 'high', a.detail = 'p95 latency above 2s for 10 minutes';
MERGE (a:Alert {name: 'DB pool exhausted'})
SET a.severity = 'critical', a.detail = 'pool 100/100 connections, 240 waiting';
MERGE (a:Alert {name: 'Notification delivery failing'})
SET a.severity = 'high', a.detail = 'delivery success below 90 percent';

// --- Causes ---
MERGE (c:Cause {name: 'DB pool exhaustion'})
SET c.detail = 'connections not returned after slow queries';
MERGE (c:Cause {name: 'Bad deploy'})
SET c.status = 'ruled out', c.detail = 'deploy happened after the alert started';
MERGE (c:Cause {name: 'Downstream timeout'})
SET c.detail = 'email provider timing out after 30s';

// --- Runbooks ---
MERGE (r:Runbook {name: 'Increase DB pool size and restart pool'})
SET r.approval = 'needs approval', r.detail = 'raise pool 100 to 200, restart pool, watch for 15 minutes';
MERGE (r:Runbook {name: 'Roll back to previous deploy'})
SET r.approval = 'needs approval', r.detail = 'roll back the last deploy, verify latency recovers';
MERGE (r:Runbook {name: 'Retry with backoff and check downstream health'})
SET r.approval = 'needs approval', r.detail = 'enable retry with backoff, check provider status page';

// --- Relationships: Service raises Alert ---
MATCH (s:Service {name: 'payment-api'}), (a:Alert {name: 'Payment API latency high'})
MERGE (s)-[:RAISES]->(a);
MATCH (s:Service {name: 'database'}), (a:Alert {name: 'DB pool exhausted'})
MERGE (s)-[:RAISES]->(a);
MATCH (s:Service {name: 'notification-service'}), (a:Alert {name: 'Notification delivery failing'})
MERGE (s)-[:RAISES]->(a);

// --- Relationships: Alert caused by Cause ---
MATCH (a:Alert {name: 'Payment API latency high'}), (c:Cause {name: 'DB pool exhaustion'})
MERGE (a)-[:CAUSED_BY]->(c);
MATCH (a:Alert {name: 'Payment API latency high'}), (c:Cause {name: 'Bad deploy'})
MERGE (a)-[:CAUSED_BY]->(c);
MATCH (a:Alert {name: 'DB pool exhausted'}), (c:Cause {name: 'DB pool exhaustion'})
MERGE (a)-[:CAUSED_BY]->(c);
MATCH (a:Alert {name: 'Notification delivery failing'}), (c:Cause {name: 'Downstream timeout'})
MERGE (a)-[:CAUSED_BY]->(c);

// --- Relationships: Cause fixed by Runbook ---
MATCH (c:Cause {name: 'DB pool exhaustion'}), (r:Runbook {name: 'Increase DB pool size and restart pool'})
MERGE (c)-[:FIXED_BY]->(r);
MATCH (c:Cause {name: 'Bad deploy'}), (r:Runbook {name: 'Roll back to previous deploy'})
MERGE (c)-[:FIXED_BY]->(r);
MATCH (c:Cause {name: 'Downstream timeout'}), (r:Runbook {name: 'Retry with backoff and check downstream health'})
MERGE (c)-[:FIXED_BY]->(r);

// --- Relationships: Service depends on Service ---
MATCH (s:Service {name: 'payment-api'}), (d:Service {name: 'database'})
MERGE (s)-[:DEPENDS_ON]->(d);
MATCH (s:Service {name: 'payment-api'}), (d:Service {name: 'api-gateway'})
MERGE (s)-[:DEPENDS_ON]->(d);
MATCH (s:Service {name: 'notification-service'}), (d:Service {name: 'database'})
MERGE (s)-[:DEPENDS_ON]->(d);
MATCH (s:Service {name: 'api-gateway'}), (d:Service {name: 'payment-api'})
MERGE (s)-[:DEPENDS_ON]->(d);
MATCH (s:Service {name: 'payment-api'}), (d:Service {name: 'notification-service'})
MERGE (s)-[:DEPENDS_ON]->(d);
