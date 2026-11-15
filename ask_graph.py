# ask_graph.py — Knowledge Graph RAG, Part 2
# No APOC plugin needed. No langchain-neo4j needed.
#
# How it works, in 3 steps:
#   1. Ask Groq: turn the plain-English question into Cypher.
#      (The graph's shape is written in SCHEMA below — that is the
#      only thing the APOC helper used to do for us.)
#   2. Run that Cypher against Neo4j with the plain neo4j driver.
#   3. Ask Groq again: answer the question using ONLY the rows
#      that came back from the graph.
#
# FILE: save this as ask_graph.py in your kg-graphrag-demo folder
# (replace the old version completely).
# TERMINAL: python ask_graph.py

from neo4j import GraphDatabase
from langchain_groq import ChatGroq
from langchain_core.messages import SystemMessage, HumanMessage
from dotenv import load_dotenv

load_dotenv()

URI = "bolt://localhost:7687"
USERNAME = "neo4j"
PASSWORD = "password"

# The shape of our graph, written out for the model.
SCHEMA = """
Nodes (every node identifies itself by its 'name' property):
  Service: name, type
  Alert: name, severity, detail
  Cause: name, detail, status
  Runbook: name, approval, detail

Relationships:
  (Service)-[:RAISES]->(Alert)
  (Alert)-[:CAUSED_BY]->(Cause)
  (Cause)-[:FIXED_BY]->(Runbook)
  (Service)-[:DEPENDS_ON]->(Service)
"""

llm = ChatGroq(model="openai/gpt-oss-120b", temperature=0)
driver = GraphDatabase.driver(URI, auth=(USERNAME, PASSWORD))

QUESTIONS = [
    "Which runbook fixes DB pool exhaustion?",
    "What caused the payment-api alert?",
    "Which services depend on the database?",
]


def question_to_cypher(question):
    messages = [
        SystemMessage(
            content="You are an expert Neo4j Cypher generator. "
            "Given a schema and a question, output ONLY the Cypher query. "
            "Never ask a question. Never ask for clarification. "
            "Never explain anything."
        ),
        HumanMessage(
            content=(
                "Use ONLY the node labels, property names and "
                "relationship types in this schema. "
                "Relationships go in this direction ONLY, never reversed:\n"
                "  (Service)-[:RAISES]->(Alert)-[:CAUSED_BY]->(Cause)"
                "-[:FIXED_BY]->(Runbook)\n"
                "Service names are: payment-api, database, api-gateway, "
                "notification-service. Cause names are: 'DB pool exhaustion', "
                "'Bad deploy', 'Downstream timeout'.\n\n"
                f"Schema:\n{SCHEMA}\n\n"
                "Example (do not repeat this query):\n"
                "Question: What caused the payment-api alert?\n"
                "Cypher: MATCH (s:Service)-[:RAISES]->(a:Alert)-[:CAUSED_BY]->"
                "(c:Cause) WHERE s.name = 'payment-api' RETURN c\n\n"
                f"Now write the Cypher query for this question: {question}"
            )
        ),
    ]
    cypher = llm.invoke(messages).content.strip()
    # Strip code fences in case the model wraps the query in ```cypher ... ```
    cypher = cypher.replace("```cypher", "").replace("```", "").strip()
    return cypher


def run_cypher(cypher):
    with driver.session() as session:
        result = session.run(cypher)
        rows = []
        for record in result:
            row = {}
            for key, value in dict(record).items():
                # Turn graph nodes into plain name/value facts
                # so the answer step reads them easily.
                try:
                    row[key] = dict(value)
                except (TypeError, ValueError):
                    row[key] = value
            rows.append(row)
        return rows


def answer_from_rows(question, cypher, rows):
    prompt = (
        "Answer the question using ONLY the facts below. "
        "If several items match, list ALL of them — do not leave any out. "
        "If the facts do not contain the answer, "
        'say "I don\'t know based on the graph."\n\n'
        f"Question: {question}\n\n"
        f"Cypher used: {cypher}\n\n"
        f"Facts from the graph:\n{rows}\n\n"
        "Answer:"
    )
    return llm.invoke(prompt).content.strip()


if __name__ == "__main__":
    for q in QUESTIONS:
        print("Q:", q)
        cypher = question_to_cypher(q)
        print("Cypher:", cypher)
        try:
            rows = run_cypher(cypher)
        except Exception as e:
            print("Cypher failed:", e)
            print("-" * 60)
            continue
        print("Rows:", rows)
        print("A:", answer_from_rows(q, cypher, rows))
        print("-" * 60)
    driver.close()
