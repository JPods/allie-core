#!/usr/bin/env python3
"""
Agent Database Setup — One schema, many instances.

Creates a PostgreSQL database for any agent in the team. Each agent gets:
  1. Core tables (universal): episodes, observations, agent_messages,
     agent_facets, sessions, vector_index, tfts
  2. Agent-specific log table with domain-relevant columns
  3. ChromaDB collections: knowledge, episodes, hc (hippocampus)

Usage:
    python3 agent-db-setup.py allie          # set up Allie's database
    python3 agent-db-setup.py andi           # set up Andi's database
    python3 agent-db-setup.py noelle         # set up Noelle's database
    python3 agent-db-setup.py --list         # show all known agents
    python3 agent-db-setup.py --status       # check which databases exist
    python3 agent-db-setup.py --all          # set up all agents

Each agent's database is named: agent_{name} (e.g., agent_andi, agent_noelle).
Exception: Allie's database is named 'allie' (legacy — already exists).

Established 2026-08-31. Reusable across all agents.
"""

import sys
import os
import pathlib

ALLIE_HOME = pathlib.Path.home() / "Allie"
DB_USER = os.environ.get("PGUSER", os.getlogin())
DB_HOST = "localhost"

# ── Agent Registry ──────────────────────────────────────────────────

AGENTS = {
    "allie": {
        "db_name": "allie",  # legacy name
        "description": "Cross-domain persistent intelligence",
        "domain": "CROSS",
        "chroma_dir": ".chroma_db",
        "log_type": "general",
    },
    "andi": {
        "db_name": "agent_andi",
        "description": "WCHQ server — production Alice, escalation, user-facing commerce",
        "domain": "WC3",
        "chroma_dir": ".chroma_db_andi",
        "log_type": "commerce",
    },
    "alice": {
        "db_name": "agent_alice",
        "description": "Commerce agent — pricing, billing, data quality, patterns",
        "domain": "WC3",
        "chroma_dir": ".chroma_db_alice",
        "log_type": "commerce",
    },
    "noelle": {
        "db_name": "agent_noelle",
        "description": "Network validator + load balancer",
        "domain": "SU",
        "chroma_dir": ".chroma_db_noelle",
        "log_type": "validation",
    },
    "natalie": {
        "db_name": "agent_natalie",
        "description": "Router — trip plans, route sequences",
        "domain": "PH",
        "chroma_dir": ".chroma_db_natalie",
        "log_type": "routing",
    },
    "nora": {
        "db_name": "agent_nora",
        "description": "Vehicle — navigation, encoders, telemetry",
        "domain": "PH",
        "chroma_dir": ".chroma_db_nora",
        "log_type": "telemetry",
    },
    "sally": {
        "db_name": "agent_sally",
        "description": "Station processor — slot registry, parking queue",
        "domain": "SU",
        "chroma_dir": ".chroma_db_sally",
        "log_type": "station",
    },
}

# ── Core Schema (every agent gets these) ─────────────────────────────

CORE_TABLES_SQL = """
-- Episodes — episodic memory (TFTS arcs, faults, scars, events)
CREATE TABLE IF NOT EXISTS episodes (
    id               SERIAL PRIMARY KEY,
    episode_id       VARCHAR(20) NOT NULL UNIQUE,
    dt_created       BIGINT NOT NULL DEFAULT 0,
    dt_start         BIGINT,
    dt_end           BIGINT,
    episode_type     VARCHAR(30) NOT NULL,
    domain           VARCHAR(20) DEFAULT 'CROSS',
    title            TEXT NOT NULL,
    narrative        TEXT,
    principle        TEXT,
    actors           JSONB DEFAULT '[]',
    outcome          VARCHAR(20) DEFAULT 'unresolved',
    severity         VARCHAR(20) DEFAULT 'lesson',
    related_episodes JSONB DEFAULT '[]',
    tags             JSONB DEFAULT '[]',
    source_ref       TEXT,
    recall_count     INTEGER DEFAULT 0,
    last_recalled    BIGINT,
    metadata         JSONB DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_episodes_type ON episodes (episode_type);
CREATE INDEX IF NOT EXISTS idx_episodes_domain ON episodes (domain);
CREATE INDEX IF NOT EXISTS idx_episodes_outcome ON episodes (outcome);
CREATE INDEX IF NOT EXISTS idx_episodes_severity ON episodes (severity);
CREATE INDEX IF NOT EXISTS idx_episodes_dt ON episodes (dt_created DESC);
CREATE INDEX IF NOT EXISTS idx_episodes_recall ON episodes (recall_count DESC);

-- Observations — what the agent noticed
CREATE TABLE IF NOT EXISTS observations (
    id         SERIAL PRIMARY KEY,
    dt_created BIGINT NOT NULL DEFAULT 0,
    observer   VARCHAR(20) NOT NULL,
    domain     VARCHAR(20) DEFAULT 'CROSS',
    category   VARCHAR(50),
    content    TEXT NOT NULL,
    resolved   BOOLEAN DEFAULT FALSE,
    outcome    TEXT,
    accurate   BOOLEAN,
    metadata   JSONB DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_observations_category ON observations (category);
CREATE INDEX IF NOT EXISTS idx_observations_observer ON observations (observer);
CREATE INDEX IF NOT EXISTS idx_observations_dt ON observations (dt_created DESC);

-- Agent messages — inter-agent communication bus
CREATE TABLE IF NOT EXISTS agent_messages (
    id              SERIAL PRIMARY KEY,
    dt_created      BIGINT NOT NULL DEFAULT 0,
    from_agent      VARCHAR(50) NOT NULL,
    to_agent        VARCHAR(50) NOT NULL,
    subject         VARCHAR(255) NOT NULL,
    body            TEXT,
    priority        INTEGER DEFAULT 0,
    category        VARCHAR(50),
    context         JSONB DEFAULT '{}',
    read            BOOLEAN DEFAULT FALSE,
    dt_read         BIGINT,
    acknowledged    BOOLEAN DEFAULT FALSE,
    dt_acknowledged BIGINT,
    response_to     INTEGER,
    metadata        JSONB DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_messages_to ON agent_messages (to_agent);
CREATE INDEX IF NOT EXISTS idx_messages_from ON agent_messages (from_agent);
CREATE INDEX IF NOT EXISTS idx_messages_read ON agent_messages (read);
CREATE INDEX IF NOT EXISTS idx_messages_dt ON agent_messages (dt_created DESC);

-- Agent facets — agent state snapshots
CREATE TABLE IF NOT EXISTS agent_facets (
    id          SERIAL PRIMARY KEY,
    agent_name  VARCHAR(50) NOT NULL UNIQUE,
    facet       JSONB NOT NULL DEFAULT '{}',
    dt_modified BIGINT NOT NULL DEFAULT 0
);

-- Sessions — session records
CREATE TABLE IF NOT EXISTS sessions (
    id                SERIAL PRIMARY KEY,
    session_date      DATE NOT NULL,
    session_id        VARCHAR(100),
    domain            VARCHAR(20) DEFAULT 'CROSS',
    summary           TEXT,
    lessons_for_allie TEXT,
    scars             TEXT,
    files_changed     TEXT[],
    actions_created   INTEGER DEFAULT 0,
    tests_passed      INTEGER DEFAULT 0,
    tests_failed      INTEGER DEFAULT 0,
    dt_start          BIGINT,
    dt_end            BIGINT,
    dt_created        BIGINT NOT NULL DEFAULT 0,
    metadata          JSONB DEFAULT '{}'
);

-- Vector index — tracks what's been indexed in ChromaDB
CREATE TABLE IF NOT EXISTS vector_index (
    id           SERIAL PRIMARY KEY,
    store        VARCHAR(50) NOT NULL,
    doc_id       VARCHAR(255) NOT NULL,
    source_path  TEXT,
    category     VARCHAR(50),
    chunk_count  INTEGER DEFAULT 0,
    dt_indexed   BIGINT NOT NULL DEFAULT 0,
    content_hash VARCHAR(32),
    UNIQUE(store, doc_id)
);
CREATE INDEX IF NOT EXISTS idx_vector_index_store ON vector_index (store);

-- TFTS — try-fail-try-succeed arcs
CREATE TABLE IF NOT EXISTS tfts (
    id               SERIAL PRIMARY KEY,
    dt_created       BIGINT NOT NULL DEFAULT 0,
    domain           VARCHAR(20) NOT NULL,
    problem          TEXT NOT NULL,
    principle        TEXT,
    fault_ref        VARCHAR(100),
    arc              JSONB DEFAULT '[]',
    resolved         BOOLEAN DEFAULT FALSE,
    understanding_id VARCHAR(20),
    metadata         JSONB DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_tfts_domain ON tfts (domain);
CREATE INDEX IF NOT EXISTS idx_tfts_resolved ON tfts (resolved);
"""

# ── Agent-Specific Log Tables ────────────────────────────────────────

AGENT_LOG_SQL = {
    "commerce": """
-- Commerce agent log (Alice, Andi)
CREATE TABLE IF NOT EXISTS agent_log (
    id           SERIAL PRIMARY KEY,
    dt_created   BIGINT NOT NULL DEFAULT 0,
    event        VARCHAR(50) NOT NULL,
    model_name   VARCHAR(50),
    record_id    BIGINT,
    customer_id  BIGINT,
    message      TEXT,
    data         JSONB DEFAULT '{}',
    action_taken TEXT,
    source       VARCHAR(20) DEFAULT 'WC3'
);
CREATE INDEX IF NOT EXISTS idx_agent_log_dt ON agent_log (dt_created);
CREATE INDEX IF NOT EXISTS idx_agent_log_event ON agent_log (event);
CREATE INDEX IF NOT EXISTS idx_agent_log_model ON agent_log (model_name);
""",
    "validation": """
-- Validation agent log (Noelle)
CREATE TABLE IF NOT EXISTS agent_log (
    id         SERIAL PRIMARY KEY,
    dt_created BIGINT NOT NULL DEFAULT 0,
    event      VARCHAR(50) NOT NULL,
    network    VARCHAR(100),
    station    VARCHAR(100),
    severity   VARCHAR(20) DEFAULT 'info',
    message    TEXT,
    data       JSONB DEFAULT '{}',
    resolved   BOOLEAN DEFAULT FALSE,
    source     VARCHAR(20) DEFAULT 'SU'
);
CREATE INDEX IF NOT EXISTS idx_agent_log_dt ON agent_log (dt_created);
CREATE INDEX IF NOT EXISTS idx_agent_log_event ON agent_log (event);
CREATE INDEX IF NOT EXISTS idx_agent_log_severity ON agent_log (severity);
""",
    "routing": """
-- Routing agent log (Natalie)
CREATE TABLE IF NOT EXISTS agent_log (
    id          SERIAL PRIMARY KEY,
    dt_created  BIGINT NOT NULL DEFAULT 0,
    event       VARCHAR(50) NOT NULL,
    pod_name    VARCHAR(50),
    origin      VARCHAR(100),
    destination VARCHAR(100),
    path_length INTEGER,
    duration_ms BIGINT,
    message     TEXT,
    data        JSONB DEFAULT '{}',
    source      VARCHAR(20) DEFAULT 'PH'
);
CREATE INDEX IF NOT EXISTS idx_agent_log_dt ON agent_log (dt_created);
CREATE INDEX IF NOT EXISTS idx_agent_log_event ON agent_log (event);
CREATE INDEX IF NOT EXISTS idx_agent_log_pod ON agent_log (pod_name);
""",
    "telemetry": """
-- Telemetry agent log (Nora)
CREATE TABLE IF NOT EXISTS agent_log (
    id               SERIAL PRIMARY KEY,
    dt_created       BIGINT NOT NULL DEFAULT 0,
    event            VARCHAR(50) NOT NULL,
    pod_name         VARCHAR(50) NOT NULL,
    sensor           VARCHAR(50),
    value_raw        DOUBLE PRECISION,
    value_calibrated DOUBLE PRECISION,
    message          TEXT,
    data             JSONB DEFAULT '{}',
    source           VARCHAR(20) DEFAULT 'PH'
);
CREATE INDEX IF NOT EXISTS idx_agent_log_dt ON agent_log (dt_created);
CREATE INDEX IF NOT EXISTS idx_agent_log_event ON agent_log (event);
CREATE INDEX IF NOT EXISTS idx_agent_log_pod ON agent_log (pod_name);
""",
    "station": """
-- Station agent log (Sally)
CREATE TABLE IF NOT EXISTS agent_log (
    id         SERIAL PRIMARY KEY,
    dt_created BIGINT NOT NULL DEFAULT 0,
    event      VARCHAR(50) NOT NULL,
    station    VARCHAR(100),
    slot_id    VARCHAR(50),
    pod_name   VARCHAR(50),
    dwell_ms   BIGINT,
    message    TEXT,
    data       JSONB DEFAULT '{}',
    source     VARCHAR(20) DEFAULT 'SU'
);
CREATE INDEX IF NOT EXISTS idx_agent_log_dt ON agent_log (dt_created);
CREATE INDEX IF NOT EXISTS idx_agent_log_event ON agent_log (event);
CREATE INDEX IF NOT EXISTS idx_agent_log_station ON agent_log (station);
""",
    "general": """
-- General agent log (Allie, or any agent without domain-specific needs)
CREATE TABLE IF NOT EXISTS agent_log (
    id           SERIAL PRIMARY KEY,
    dt_created   BIGINT NOT NULL DEFAULT 0,
    event        VARCHAR(50) NOT NULL,
    domain       VARCHAR(20) DEFAULT 'CROSS',
    category     VARCHAR(50),
    message      TEXT,
    data         JSONB DEFAULT '{}',
    action_taken TEXT,
    source       VARCHAR(20) DEFAULT 'ALLIE'
);
CREATE INDEX IF NOT EXISTS idx_agent_log_dt ON agent_log (dt_created);
CREATE INDEX IF NOT EXISTS idx_agent_log_event ON agent_log (event);
CREATE INDEX IF NOT EXISTS idx_agent_log_domain ON agent_log (domain);
""",
}


# ── Database Operations ──────────────────────────────────────────────

def _pg_connect(dbname="postgres"):
    import psycopg2
    return psycopg2.connect(dbname=dbname, user=DB_USER, host=DB_HOST)


def db_exists(db_name):
    conn = _pg_connect()
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (db_name,))
            return cur.fetchone() is not None
    finally:
        conn.close()


def create_database(db_name):
    conn = _pg_connect()
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(f'CREATE DATABASE "{db_name}"')
        print(f"  Created database: {db_name}")
    except Exception as e:
        if "already exists" in str(e):
            print(f"  Database exists: {db_name}")
        else:
            raise
    finally:
        conn.close()


def run_sql(db_name, sql):
    conn = _pg_connect(db_name)
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()
    finally:
        conn.close()


def setup_chroma(agent_name, agent_config):
    """Create ChromaDB collections for the agent."""
    try:
        import chromadb
    except ImportError:
        print("  ChromaDB not installed — skipping vector store setup")
        return

    chroma_path = str(ALLIE_HOME / agent_config["chroma_dir"])
    client = chromadb.PersistentClient(path=chroma_path)

    collections = [
        (f"{agent_name}_knowledge", "Primary knowledge store"),
        (f"{agent_name}_episodes", "Episodic memory — associative recall"),
        (f"{agent_name}_hc", "Hippocampus — learned patterns, hypotheses"),
    ]

    for name, desc in collections:
        client.get_or_create_collection(
            name=name,
            metadata={"hnsw:space": "cosine"},
        )
        print(f"  ChromaDB collection: {name}")


def setup_agent(agent_name):
    """Full setup for one agent."""
    if agent_name not in AGENTS:
        print(f"Unknown agent: {agent_name}")
        print(f"Known agents: {', '.join(AGENTS.keys())}")
        return False

    config = AGENTS[agent_name]
    db_name = config["db_name"]
    log_type = config["log_type"]

    print(f"\n{'=' * 50}")
    print(f"Agent: {agent_name} — {config['description']}")
    print(f"Database: {db_name}")
    print(f"Domain: {config['domain']}")
    print(f"{'=' * 50}")

    # 1. Create database
    already_exists = db_exists(db_name)
    if not already_exists:
        create_database(db_name)
    else:
        print(f"  Database exists: {db_name}")

    # 2. Core tables
    print("  Creating core tables...")
    run_sql(db_name, CORE_TABLES_SQL)
    print("  Core tables ready: episodes, observations, agent_messages,")
    print("    agent_facets, sessions, vector_index, tfts")

    # 3. Agent-specific log table
    if log_type in AGENT_LOG_SQL:
        print(f"  Creating agent_log ({log_type} type)...")
        run_sql(db_name, AGENT_LOG_SQL[log_type])
        print(f"  agent_log ready ({log_type})")
    else:
        print(f"  No log type defined for: {log_type}")

    # 4. ChromaDB collections
    print("  Setting up ChromaDB collections...")
    setup_chroma(agent_name, config)

    print(f"\n  ✓ {agent_name} database ready")
    return True


def show_status():
    """Check which agent databases exist."""
    print("\nAgent Database Status")
    print("=" * 60)
    for name, config in AGENTS.items():
        db_name = config["db_name"]
        exists = db_exists(db_name)
        chroma_path = ALLIE_HOME / config["chroma_dir"]
        chroma_exists = chroma_path.exists()

        status = "✓" if exists else "✗"
        chroma_status = "✓" if chroma_exists else "✗"

        # Count episodes if DB exists
        ep_count = ""
        if exists:
            try:
                conn = _pg_connect(db_name)
                with conn.cursor() as cur:
                    cur.execute("SELECT count(*) FROM episodes")
                    ep_count = f" ({cur.fetchone()[0]} episodes)"
                conn.close()
            except Exception:
                ep_count = ""

        print(f"  {status} {name:10s} db={db_name:20s} chroma={chroma_status}{ep_count}")
        print(f"    {config['description']}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 agent-db-setup.py <agent_name> | --list | --status | --all")
        sys.exit(1)

    arg = sys.argv[1].lower()

    if arg == "--list":
        print("\nKnown Agents:")
        for name, config in AGENTS.items():
            print(f"  {name:10s} — {config['description']} (db: {config['db_name']})")

    elif arg == "--status":
        show_status()

    elif arg == "--all":
        for name in AGENTS:
            setup_agent(name)
        print("\n\nAll agents set up.")
        show_status()

    elif arg in AGENTS:
        setup_agent(arg)

    else:
        print(f"Unknown argument: {arg}")
        print(f"Known agents: {', '.join(AGENTS.keys())}")
        print("Other options: --list, --status, --all")
        sys.exit(1)


if __name__ == "__main__":
    main()
