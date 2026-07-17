# Vector Store Push — 2026-07-16 session learnings
# Run this at next session start when MCP servers are up

## Push to Allie vector store (allie_db_remember)
1. GEEKOM IT15 hybrid architecture ordered 2026-07-16. MacBook keeps Ollama/LLM, GEEKOM hosts PostgreSQL, WC3, MeshMobility, Chroma, 5TB. Ubuntu Server 24.04. Expected ~2026-07-20. Full plan: readmes/55-mac-mini-migration.md
2. Python cleanup completed 2026-07-16. Single framework: Homebrew ARM 3.13.3. One venv per project. Framework installs and Homebrew Intel removed. Full guide: readmes/57-python-setup.md

## Push to Noelle vector store
1. MeshMobility moves to GEEKOM IT15 as always-on systemd service. No longer depends on MacBook being open. Port 5000, accessible at geekom:5000 from MacBook.
2. Network data and simulations will run 24/7 on GEEKOM. 32GB RAM, 1TB SSD, 2.5GbE for NFS access to 5TB.

## Push to Alice vector store
1. WC3 Django + Celery + PostgreSQL + React move to GEEKOM IT15. Always-on via systemd. Gunicorn + Nginx in production (not runserver). 
2. Chroma vector stores (Alice 4521 chunks + Noelle 49K chunks) move to GEEKOM, HTTP mode on port 8100.
3. MCP servers on MacBook will connect to GEEKOM backends via network (geekom:5432, geekom:8100).

## Alternatives rejected (for reference)
- Mac Mini M4 base 32GB: memory bandwidth too low (120 vs 273 GB/s), undersized
- GEEKOM A9 Max: IT15 better (2.5GbE, 128GB upgrade ceiling, 2TB option)
- KAMRUI H1: 24GB soldered, budget tier, not suitable for always-on
- Intel MacBook Pro: 16GB can't run 20b model
- GEEKOM as sole Allie host: 32GB too tight with Ollama
