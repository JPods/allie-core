#!/usr/bin/env python3
"""
Vector Store Blind Evaluation — scores retrieval quality against known-good answers.

Questions are in questions.json (NOT indexed by any store).
Results are appended to results.jsonl for tracking over time.

Usage:
    python3 run_eval.py                # Run all questions, print report
    python3 run_eval.py --store alice  # Run only alice store questions
    python3 run_eval.py --verbose      # Show full result content
"""
import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import chromadb

ALLIE_HOME = Path.home() / "Allie"
EVAL_DIR = Path(__file__).parent
QUESTIONS_FILE = EVAL_DIR / "questions.json"
RESULTS_FILE = EVAL_DIR / "results.jsonl"

STORES = {
    "allie": {
        "path": str(ALLIE_HOME / ".chroma_db"),
        "collection": "allie_knowledge",
    },
    "claude": {
        "path": str(ALLIE_HOME / ".chroma_db_claude"),
        "collection": "claude_session_knowledge",
    },
    "alice": {
        "path": str(ALLIE_HOME / ".chroma_db_alice"),
        "collection": "alice_commerce_knowledge",
    },
}


def get_collection(store_name):
    info = STORES[store_name]
    client = chromadb.PersistentClient(path=info["path"])
    return client.get_or_create_collection(
        name=info["collection"],
        metadata={"hnsw:space": "cosine"},
    )


def score_result(result_doc, result_meta, question):
    """Score a single result against expected answer."""
    score = 0
    reasons = []

    # Check if expected source appears in the result metadata
    expected_src = question.get("expected_source", "")
    doc_id = result_meta.get("doc_id", "")
    filename = result_meta.get("filename", "")

    if expected_src.lower() in doc_id.lower() or expected_src.lower() in filename.lower():
        score += 50
        reasons.append(f"source_match:{doc_id}")

    # Check if expected keywords appear in the result content
    content_lower = result_doc.lower()
    keywords = question.get("expected_keywords", [])
    matched_kw = [kw for kw in keywords if kw.lower() in content_lower]
    keyword_score = int(50 * len(matched_kw) / max(len(keywords), 1))
    score += keyword_score
    if matched_kw:
        reasons.append(f"keywords:{len(matched_kw)}/{len(keywords)}")

    return score, reasons


def evaluate_question(question, collection, verbose=False):
    """Run one question against the store and score the results."""
    query = question["question"]
    results = collection.query(query_texts=[query], n_results=5)

    if not results or not results["documents"] or not results["documents"][0]:
        return {"question_id": question["id"], "score": 0, "top_score": 0, "details": "no_results"}

    top3_scores = []
    for i in range(min(3, len(results["documents"][0]))):
        doc = results["documents"][0][i]
        meta = results["metadatas"][0][i] if results["metadatas"] else {}
        dist = results["distances"][0][i] if results["distances"] else None
        s, reasons = score_result(doc, meta, question)
        top3_scores.append({
            "rank": i + 1,
            "score": s,
            "distance": round(dist, 4) if dist else None,
            "source": meta.get("doc_id", "?"),
            "reasons": reasons,
        })
        if verbose:
            print(f"    [{i+1}] score={s} dist={dist:.4f if dist else 0} src={meta.get('doc_id','?')}")
            print(f"        {doc[:150]}")

    best = max(top3_scores, key=lambda x: x["score"])
    return {
        "question_id": question["id"],
        "question": query,
        "category": question.get("category", ""),
        "score": best["score"],
        "top3": top3_scores,
        "best_rank": best["rank"],
        "best_source": best["source"],
    }


def run_eval(store_filter=None, verbose=False):
    """Run the full evaluation."""
    with open(QUESTIONS_FILE) as f:
        data = json.load(f)

    questions = data["questions"]
    if store_filter:
        questions = [q for q in questions if q.get("store") == store_filter]

    if not questions:
        print("No questions to evaluate.")
        return

    # Group by store
    by_store = {}
    for q in questions:
        by_store.setdefault(q.get("store", "alice"), []).append(q)

    all_results = []
    dt_run = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    for store_name, store_questions in sorted(by_store.items()):
        print(f"\n{'='*60}")
        print(f"  Store: {store_name} ({len(store_questions)} questions)")
        print(f"{'='*60}")

        try:
            collection = get_collection(store_name)
        except Exception as e:
            print(f"  ERROR: Could not open {store_name} store: {e}")
            continue

        store_scores = []
        for q in store_questions:
            if verbose:
                print(f"\n  Q: {q['question']}")
            result = evaluate_question(q, collection, verbose=verbose)
            all_results.append(result)
            store_scores.append(result["score"])

            grade = "A" if result["score"] >= 80 else "B" if result["score"] >= 60 else "C" if result["score"] >= 40 else "D" if result["score"] >= 20 else "F"
            print(f"  [{grade}] {result['score']:3d}/100  {q['id']}  {q['question'][:60]}")
            if result["score"] < 60:
                print(f"         best source: {result.get('best_source', '?')}")

        avg = sum(store_scores) / len(store_scores) if store_scores else 0
        passing = sum(1 for s in store_scores if s >= 60)
        print(f"\n  Average: {avg:.0f}/100 | Passing (>=60): {passing}/{len(store_scores)}")

    # Overall
    all_scores = [r["score"] for r in all_results]
    if all_scores:
        print(f"\n{'='*60}")
        overall_avg = sum(all_scores) / len(all_scores)
        overall_pass = sum(1 for s in all_scores if s >= 60)
        print(f"  OVERALL: {overall_avg:.0f}/100 avg | {overall_pass}/{len(all_scores)} passing")

        # By category
        cats = {}
        for r in all_results:
            cat = r.get("category", "other")
            cats.setdefault(cat, []).append(r["score"])
        print(f"\n  By category:")
        for cat, scores in sorted(cats.items()):
            avg_cat = sum(scores) / len(scores)
            print(f"    {cat:20s}  {avg_cat:.0f}/100  ({len(scores)} questions)")

        print(f"{'='*60}")

    # Save results
    run_record = {
        "dt": dt_run,
        "store_filter": store_filter,
        "questions": len(all_results),
        "average": round(sum(all_scores) / len(all_scores), 1) if all_scores else 0,
        "passing": sum(1 for s in all_scores if s >= 60),
        "results": all_results,
    }
    with open(RESULTS_FILE, "a") as f:
        f.write(json.dumps(run_record) + "\n")
    print(f"\nResults saved to {RESULTS_FILE}")


def main():
    parser = argparse.ArgumentParser(description="Vector Store Blind Evaluation")
    parser.add_argument("--store", choices=["allie", "claude", "alice"], default=None)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()
    run_eval(store_filter=args.store, verbose=args.verbose)


if __name__ == "__main__":
    main()
