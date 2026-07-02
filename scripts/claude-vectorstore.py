#!/usr/bin/env python3
"""
Claude Code Vector Store — semantic search across session history.

Usage:
    python3 claude-vectorstore.py index          # Index all session files
    python3 claude-vectorstore.py search "query"  # Search for relevant content
    python3 claude-vectorstore.py stats           # Show store statistics
    python3 claude-vectorstore.py remember "category" "title" "content"  # Save to claude_memory table

Indexes: sessions/, handoff/, process/inbox/, readmes/retrospections/, readmes/wisdom/
Persists to: ~/Allie/.chroma_db_claude/
Also writes metadata to PostgreSQL allie.vector_index table.
"""
import argparse
import hashlib
import os
import sys
import time
from pathlib import Path

import chromadb

try:
    import psycopg2
    HAS_PSYCOPG = True
except ImportError:
    HAS_PSYCOPG = False

ALLIE_HOME = Path.home() / "Allie"
CHROMA_DIR = str(ALLIE_HOME / ".chroma_db_claude")
COLLECTION = "claude_session_knowledge"
DB_NAME = "allie"
DB_USER = os.environ.get("PGUSER", os.getlogin())
DB_HOST = "localhost"

# Directories to index
INDEX_DIRS = [
    ("sessions", ALLIE_HOME / "sessions"),
    ("handoff", ALLIE_HOME / "handoff"),
    ("process", ALLIE_HOME / "process" / "inbox"),
    ("retrospections", ALLIE_HOME / "readmes" / "retrospections"),
    ("wisdom", ALLIE_HOME / "readmes" / "wisdom"),
    ("agents", ALLIE_HOME / "readmes" / "agents"),
]

EXTENSIONS = {".md", ".txt"}
CHUNK_SIZE = 1500
CHUNK_OVERLAP = 200


def _chunk_text(text, chunk_size=CHUNK_SIZE, overlap=CHUNK_OVERLAP):
    if len(text) <= chunk_size:
        return [text]
    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunk = text[start:end]
        if chunk.strip():
            chunks.append(chunk)
        start = end - overlap
    return chunks


def _content_hash(content):
    return hashlib.md5(content.encode()).hexdigest()[:12]


def _now_ms():
    return int(time.time() * 1000)


def get_collection():
    client = chromadb.PersistentClient(path=CHROMA_DIR)
    return client.get_or_create_collection(
        name=COLLECTION,
        metadata={"hnsw:space": "cosine"},
    )


def _db_conn():
    if not HAS_PSYCOPG:
        return None
    try:
        return psycopg2.connect(dbname=DB_NAME, user=DB_USER, host=DB_HOST)
    except Exception:
        return None


def _record_index(store, doc_id, source_path, category, chunk_count, content_hash):
    conn = _db_conn()
    if not conn:
        return
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO vector_index (store, doc_id, source_path, category, chunk_count, dt_indexed, content_hash)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (store, doc_id) DO UPDATE SET
                    chunk_count = EXCLUDED.chunk_count,
                    dt_indexed = EXCLUDED.dt_indexed,
                    content_hash = EXCLUDED.content_hash
            """, (store, doc_id, source_path, category, chunk_count, _now_ms(), content_hash))
        conn.commit()
    except Exception:
        pass
    finally:
        conn.close()


def index_all():
    """Index all session/knowledge files into Claude's vector store."""
    collection = get_collection()
    total_files = 0
    total_chunks = 0

    for category, directory in INDEX_DIRS:
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*")):
            if not path.is_file():
                continue
            if path.suffix.lower() not in EXTENSIONS:
                continue
            if any(part.startswith(".") for part in path.parts):
                continue
            if "archive" in str(path).lower():
                continue

            try:
                content = path.read_text(errors="replace")
            except Exception:
                continue

            if not content.strip():
                continue

            doc_id = f"{category}/{path.relative_to(directory)}"
            chunks = _chunk_text(content)
            file_hash = _content_hash(content)

            ids = []
            documents = []
            metadatas = []

            for i, chunk in enumerate(chunks):
                chunk_id = f"{doc_id}::chunk_{i}::{_content_hash(chunk)}"
                ids.append(chunk_id)
                documents.append(chunk)
                metadatas.append({
                    "doc_id": doc_id,
                    "category": category,
                    "filename": path.name,
                    "path": str(path),
                    "chunk_index": i,
                    "total_chunks": len(chunks),
                })

            if ids:
                collection.upsert(ids=ids, documents=documents, metadatas=metadatas)
                total_chunks += len(ids)
                total_files += 1
                _record_index("claude", doc_id, str(path), category, len(ids), file_hash)
                print(f"  {doc_id}: {len(ids)} chunks")

    print(f"\nIndexed {total_files} files, {total_chunks} chunks total")
    print(f"Store: {collection.count()} chunks in {CHROMA_DIR}")


def search(query, n_results=5):
    """Search Claude's vector store."""
    collection = get_collection()
    results = collection.query(query_texts=[query], n_results=n_results)

    if not results or not results["documents"]:
        print("No results found.")
        return []

    items = []
    for i, doc in enumerate(results["documents"][0]):
        meta = results["metadatas"][0][i] if results["metadatas"] else {}
        dist = results["distances"][0][i] if results["distances"] else None
        items.append({"content": doc, "metadata": meta, "distance": dist})
        print(f"\n--- Result {i+1} (distance: {dist:.4f}) ---")
        print(f"Source: {meta.get('doc_id', '?')} (chunk {meta.get('chunk_index', '?')}/{meta.get('total_chunks', '?')})")
        print(doc[:500])

    return items


def remember(category, title, content, domain="CROSS"):
    """Save a structured memory to PostgreSQL for cross-session recall."""
    conn = _db_conn()
    if not conn:
        print("Cannot connect to allie database")
        return
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO claude_memory (dt_created, category, domain, title, content)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id
            """, (_now_ms(), category, domain, title, content))
            row = cur.fetchone()
            conn.commit()
            print(f"Saved memory id={row[0]}: [{category}] {title}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()


def recall(query=None, category=None, limit=10):
    """Recall memories from PostgreSQL."""
    conn = _db_conn()
    if not conn:
        print("Cannot connect to allie database")
        return []
    try:
        with conn.cursor() as cur:
            if query:
                cur.execute("""
                    SELECT id, category, domain, title, content, dt_created
                    FROM claude_memory WHERE still_valid = true
                    AND (title ILIKE %s OR content ILIKE %s)
                    ORDER BY dt_created DESC LIMIT %s
                """, (f"%{query}%", f"%{query}%", limit))
            elif category:
                cur.execute("""
                    SELECT id, category, domain, title, content, dt_created
                    FROM claude_memory WHERE still_valid = true AND category = %s
                    ORDER BY dt_created DESC LIMIT %s
                """, (category, limit))
            else:
                cur.execute("""
                    SELECT id, category, domain, title, content, dt_created
                    FROM claude_memory WHERE still_valid = true
                    ORDER BY dt_created DESC LIMIT %s
                """, (limit,))

            rows = cur.fetchall()
            for row in rows:
                print(f"\n[{row[1]}:{row[2]}] {row[3]} (id={row[0]})")
                print(f"  {row[4][:200]}")
            return rows
    except Exception as e:
        print(f"Error: {e}")
        return []
    finally:
        conn.close()


def stats():
    """Show store statistics."""
    collection = get_collection()
    print(f"Collection: {COLLECTION}")
    print(f"Persist dir: {CHROMA_DIR}")
    print(f"Total chunks: {collection.count()}")

    conn = _db_conn()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM claude_memory WHERE still_valid = true")
                print(f"Memories in DB: {cur.fetchone()[0]}")
                cur.execute("SELECT COUNT(*) FROM vector_index WHERE store = 'claude'")
                print(f"Indexed docs in DB: {cur.fetchone()[0]}")
        except Exception:
            pass
        finally:
            conn.close()


def main():
    parser = argparse.ArgumentParser(description="Claude Code Vector Store")
    parser.add_argument("command", choices=["index", "search", "stats", "remember", "recall"])
    parser.add_argument("args", nargs="*", default=[])
    parser.add_argument("--n", type=int, default=5)
    parser.add_argument("--category", default=None)
    parser.add_argument("--domain", default="CROSS")
    args = parser.parse_args()

    if args.command == "index":
        index_all()
    elif args.command == "search":
        if not args.args:
            print("Usage: claude-vectorstore.py search 'your query'")
            sys.exit(1)
        search(" ".join(args.args), n_results=args.n)
    elif args.command == "stats":
        stats()
    elif args.command == "remember":
        if len(args.args) < 3:
            print("Usage: claude-vectorstore.py remember 'category' 'title' 'content'")
            sys.exit(1)
        remember(args.args[0], args.args[1], args.args[2], domain=args.domain)
    elif args.command == "recall":
        query = " ".join(args.args) if args.args else None
        recall(query=query, category=args.category, limit=args.n)


if __name__ == "__main__":
    main()
