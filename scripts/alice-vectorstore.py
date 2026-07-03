#!/usr/bin/env python3
"""
Alice Vector Store — semantic search across WebClerk commerce knowledge.

Usage:
    python3 alice-vectorstore.py index          # Index all commerce files
    python3 alice-vectorstore.py search "query"  # Search for relevant content
    python3 alice-vectorstore.py stats           # Show store statistics

Indexes: WC3 readmes, WC3 model source, Alice-related Allie readmes,
         alice_log entries, process files tagged WC3
Persists to: ~/Allie/.chroma_db_alice/
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
WC3_HOME = Path.home() / "Documents" / "CommerceExpert" / "webClerk3"
CHROMA_DIR = str(ALLIE_HOME / ".chroma_db_alice")
COLLECTION = "alice_commerce_knowledge"
DB_NAME = "allie"
DB_USER = os.environ.get("PGUSER", os.getlogin())
DB_HOST = "localhost"

# Directories to index
INDEX_DIRS = [
    # WC3 documentation — Alice's primary domain
    ("wc3_readmes", WC3_HOME / "readmes"),
    # WC3 Django models — the data structures Alice works with
    ("wc3_models_core", WC3_HOME / "apps" / "core" / "models"),
    ("wc3_models_products", WC3_HOME / "apps" / "products" / "models"),
    ("wc3_models_transactions", WC3_HOME / "apps" / "transactions" / "models"),
    ("wc3_models_accounts", WC3_HOME / "apps" / "accounts" / "models"),
    ("wc3_models_orgs", WC3_HOME / "apps" / "orgs" / "models"),
    ("wc3_models_sync", WC3_HOME / "apps" / "sync" / "models"),
    ("wc3_models_comms", WC3_HOME / "apps" / "communications" / "models"),
    # WC3 API views — how data flows
    ("wc3_views_core", WC3_HOME / "apps" / "core" / "views"),
    ("wc3_views_transactions", WC3_HOME / "apps" / "transactions" / "views"),
    ("wc3_views_accounts", WC3_HOME / "apps" / "accounts" / "views"),
    # Alice's agent readme and related Allie docs
    ("alice_agent", ALLIE_HOME / "readmes" / "agents"),
    # Commerce-related process files
    ("process_wc3", ALLIE_HOME / "process" / "wc3"),
    # Ingrid — data ingestion (feeds Alice)
    ("ingrid", ALLIE_HOME / "Ingrid" / "readmes"),
    # Fare and payment readmes
    ("fare_payment", ALLIE_HOME / "readmes"),
    # Legacy foundation documents (PDFs)
    ("legacy_book", WC3_HOME / "readmes" / "legacy"),
]

# File extensions to index
EXTENSIONS = {".md", ".txt", ".py", ".json", ".yaml", ".yml", ".pdf"}

# Filename filters — for directories with mixed content, only index relevant files
FILENAME_FILTERS = {
    "alice_agent": {"alice.md", "README.md"},
    "fare_payment": lambda f: any(kw in f.lower() for kw in
        ["fare", "payment", "small-sting", "webclerk", "alice", "trip-api",
         "commerce", "dynamic-catalog", "data-structure"]),
}

CHUNK_SIZE = 1500
CHUNK_OVERLAP = 200


def _extract_pdf_text(path):
    """Extract text from a PDF file using PyMuPDF."""
    try:
        import pymupdf
        doc = pymupdf.open(str(path))
        parts = []
        for page_num in range(len(doc)):
            text = doc[page_num].get_text("text")
            if text.strip():
                parts.append(f"[Page {page_num + 1}]\n{text}")
        doc.close()
        return "\n\n".join(parts)
    except ImportError:
        return ""
    except Exception:
        return ""


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


def _record_index(doc_id, source_path, category, chunk_count, content_hash):
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
            """, ("alice", doc_id, source_path, category, chunk_count, _now_ms(), content_hash))
        conn.commit()
    except Exception:
        pass
    finally:
        conn.close()


def _should_index(category, filename):
    """Check if a file should be indexed based on category filters."""
    filt = FILENAME_FILTERS.get(category)
    if filt is None:
        return True
    if isinstance(filt, set):
        return filename in filt
    if callable(filt):
        return filt(filename)
    return True


def _index_alice_log(collection):
    """Index alice_log entries from PostgreSQL into the vector store."""
    conn = _db_conn()
    if not conn:
        return 0
    chunks_added = 0
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, dt_created, event, source, message, model_name, action_taken
                FROM alice_log ORDER BY dt_created DESC LIMIT 500
            """)
            rows = cur.fetchall()
            for row in rows:
                log_id, dt, event, source, message, model_name, action_taken = row
                if not message:
                    continue
                doc_text = f"[{event}] source={source} model={model_name}\n{message}"
                if action_taken:
                    doc_text += f"\nAction: {action_taken}"
                doc_id = f"alice_log/{log_id}"
                chunks = _chunk_text(doc_text)

                ids = []
                documents = []
                metadatas = []

                for i, chunk in enumerate(chunks):
                    chunk_id = f"{doc_id}::chunk_{i}::{_content_hash(chunk)}"
                    ids.append(chunk_id)
                    documents.append(chunk)
                    metadatas.append({
                        "doc_id": doc_id,
                        "category": "alice_log",
                        "filename": f"log_{log_id}",
                        "path": f"postgresql://allie/alice_log/{log_id}",
                        "chunk_index": i,
                        "total_chunks": len(chunks),
                        "event_type": event_type or "",
                        "source": source or "",
                    })

                if ids:
                    collection.upsert(ids=ids, documents=documents, metadatas=metadatas)
                    chunks_added += len(ids)

            if chunks_added:
                print(f"  alice_log: {len(rows)} entries, {chunks_added} chunks")
    except Exception as e:
        print(f"  alice_log: skipped ({e})")
    finally:
        conn.close()
    return chunks_added


def index_all():
    """Index all commerce knowledge files into Alice's vector store."""
    collection = get_collection()
    total_files = 0
    total_chunks = 0

    for category, directory in INDEX_DIRS:
        if not directory.exists():
            print(f"  {category}: directory not found, skipping")
            continue
        for path in sorted(directory.rglob("*")):
            if not path.is_file():
                continue
            if path.suffix.lower() not in EXTENSIONS:
                continue
            # Skip hidden files and archives
            if any(part.startswith(".") for part in path.parts):
                continue
            if "archive" in str(path).lower():
                continue
            # Skip migrations, __pycache__
            if "__pycache__" in str(path) or "/migrations/" in str(path):
                continue

            if not _should_index(category, path.name):
                continue

            try:
                if path.suffix.lower() == ".pdf":
                    content = _extract_pdf_text(path)
                else:
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
                _record_index(doc_id, str(path), category, len(ids), file_hash)
                print(f"  {doc_id}: {len(ids)} chunks")

    # Index alice_log from PostgreSQL
    log_chunks = _index_alice_log(collection)
    total_chunks += log_chunks

    print(f"\nIndexed {total_files} files + alice_log, {total_chunks} chunks total")
    print(f"Store: {collection.count()} chunks in {CHROMA_DIR}")


def search(query, n_results=5, category=None):
    """Search Alice's vector store."""
    collection = get_collection()

    where = {"category": category} if category else None
    results = collection.query(
        query_texts=[query],
        n_results=n_results,
        where=where,
    )

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


def stats():
    """Show store statistics."""
    collection = get_collection()
    print(f"Collection: {COLLECTION}")
    print(f"Persist dir: {CHROMA_DIR}")
    print(f"Total chunks: {collection.count()}")

    # Category breakdown
    all_meta = collection.get(include=["metadatas"])
    if all_meta and all_meta["metadatas"]:
        cats = {}
        for m in all_meta["metadatas"]:
            cat = m.get("category", "unknown")
            cats[cat] = cats.get(cat, 0) + 1
        print("\nBy category:")
        for cat, count in sorted(cats.items()):
            print(f"  {cat}: {count} chunks")

    conn = _db_conn()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM vector_index WHERE store = 'alice'")
                print(f"\nIndexed docs in DB: {cur.fetchone()[0]}")
                cur.execute("SELECT COUNT(*) FROM alice_log")
                print(f"alice_log entries: {cur.fetchone()[0]}")
        except Exception:
            pass
        finally:
            conn.close()


def main():
    parser = argparse.ArgumentParser(description="Alice Vector Store")
    parser.add_argument("command", choices=["index", "search", "stats"])
    parser.add_argument("query", nargs="?", default="")
    parser.add_argument("--n", type=int, default=5)
    parser.add_argument("--category", default=None)
    args = parser.parse_args()

    if args.command == "index":
        index_all()
    elif args.command == "search":
        if not args.query:
            print("Usage: alice-vectorstore.py search 'your query'")
            sys.exit(1)
        search(args.query, n_results=args.n, category=args.category)
    elif args.command == "stats":
        stats()


if __name__ == "__main__":
    main()
