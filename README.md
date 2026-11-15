# Knowledge Graph RAG (GraphSage)

Ask a question in plain English. The app turns it into Cypher, traverses a Neo4j knowledge graph, and answers from connected facts — not just from similar text.

**The interview line:** "Vector search finds similar text; the graph finds connected facts."

## How it works

1. **Groq** (gpt-oss-120b) turns the plain-English question into a Cypher query, using a hand-written schema of the graph.
2. The **neo4j driver** runs that Cypher against Neo4j.
3. **Groq** answers the question using ONLY the rows that came back from the graph.

No APOC plugin, no black-box chain — the whole flow is ~100 lines of readable Python.

## The graph

SRE incident shapes (seed examples): 13 nodes, 15 relationships.

- **Services:** payment-api, database, api-gateway, notification-service
- **Alerts:** Payment API latency high, DB pool exhausted, Notification delivery failing
- **Causes:** DB pool exhaustion, Bad deploy (ruled out), Downstream timeout
- **Runbooks:** Increase DB pool size and restart pool, Roll back to previous deploy, Retry with backoff and check downstream health

Relationships: `(Service)-[:RAISES]->(Alert)-[:CAUSED_BY]->(Cause)-[:FIXED_BY]->(Runbook)`, plus `(Service)-[:DEPENDS_ON]->(Service)`.

## Setup

```powershell
# 1. Start Neo4j (Docker)
docker run --name neo4j-kg -p 7474:7474 -p 7687:7687 -e NEO4J_AUTH=neo4j/password -v neo4j-data:/data -d neo4j:latest

# 2. Load the graph: open http://localhost:7474, log in (neo4j / password),
#    paste seed.cypher into the query box and run it.

# 3. Install + configure
pip install -r requirements.txt
# Put your Groq key in .env: GROQ_API_KEY=your-key-here

# 4. Run
python ask_graph.py
```

## Test questions (all 3 pass)

1. Which runbook fixes DB pool exhaustion? → Increase DB pool size and restart pool
2. What caused the payment-api alert? → DB pool exhaustion (Bad deploy was ruled out)
3. Which services depend on the database? → notification-service, payment-api

## Files

- `seed.cypher` — the graph: nodes + relationships (MERGE, safe to re-run)
- `ask_graph.py` — the 3-step chain: question → Cypher → rows → answer
- `requirements.txt` — Python packages
- `.env` — your Groq key (never committed; see `.gitignore`)
