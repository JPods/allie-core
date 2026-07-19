#!/usr/bin/env python3
"""
Allie Vector Store — semantic search across all Allie knowledge.

Usage:
    python3 allie-vectorstore.py index          # Index all knowledge files
    python3 allie-vectorstore.py search "query"  # Search for relevant content
    python3 allie-vectorstore.py stats           # Show store statistics

Indexes: knowledge/, readmes/, thoughts/, handoff/, facets/, process/snippets/
Persists to: ~/Allie/.chroma_db/
"""
import argparse
import hashlib
import os
import sys
from pathlib import Path

import chromadb

ALLIE_HOME = Path.home() / "Allie"
CHROMA_DIR = str(ALLIE_HOME / ".chroma_db")
COLLECTION = "allie_knowledge"

# Directories to index
INDEX_DIRS = [
    ("knowledge", ALLIE_HOME / "knowledge"),
    ("readmes", ALLIE_HOME / "readmes"),
    ("thoughts", ALLIE_HOME / "thoughts"),
    ("handoff", ALLIE_HOME / "handoff"),
    ("facets", ALLIE_HOME / "facets"),
    ("snippets", ALLIE_HOME / "process" / "snippets"),
    ("wisdom", ALLIE_HOME / "readmes" / "wisdom"),
    ("specs", ALLIE_HOME / "specs"),
    ("fusion", ALLIE_HOME / "Fusion"),
]

# File extensions to index
EXTENSIONS = {".md", ".txt", ".json", ".yaml", ".yml"}

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


def get_collection():
    client = chromadb.PersistentClient(path=CHROMA_DIR)
    return client.get_or_create_collection(
        name=COLLECTION,
        metadata={"hnsw:space": "cosine"},
    )


def index_all():
    """Index all knowledge files into the vector store."""
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
            # Skip hidden files and archives
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
                print(f"  {doc_id}: {len(ids)} chunks")

    print(f"\nIndexed {total_files} files, {total_chunks} chunks total")
    print(f"Store: {collection.count()} chunks in {CHROMA_DIR}")


def search(query, n_results=5):
    """Search the vector store."""
    collection = get_collection()
    results = collection.query(query_texts=[query], n_results=n_results)

    if not results or not results["documents"]:
        print("No results found.")
        return

    for i, doc in enumerate(results["documents"][0]):
        meta = results["metadatas"][0][i] if results["metadatas"] else {}
        dist = results["distances"][0][i] if results["distances"] else None
        print(f"\n--- Result {i+1} (distance: {dist:.4f}) ---")
        print(f"Source: {meta.get('doc_id', '?')} (chunk {meta.get('chunk_index', '?')}/{meta.get('total_chunks', '?')})")
        print(doc[:500])


def stats():
    """Show store statistics."""
    collection = get_collection()
    print(f"Collection: {COLLECTION}")
    print(f"Persist dir: {CHROMA_DIR}")
    print(f"Total chunks: {collection.count()}")


def main():
    parser = argparse.ArgumentParser(description="Allie Vector Store")
    parser.add_argument("command", choices=["index", "search", "stats"])
    parser.add_argument("query", nargs="?", default="")
    parser.add_argument("--n", type=int, default=5)
    args = parser.parse_args()

    if args.command == "index":
        index_all()
    elif args.command == "search":
        if not args.query:
            print("Usage: allie-vectorstore.py search 'your query'")
            sys.exit(1)
        search(args.query, n_results=args.n)
    elif args.command == "stats":
        stats()


if __name__ == "__main__":
    main()
