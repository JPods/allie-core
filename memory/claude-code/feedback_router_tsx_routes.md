---
name: Router.tsx is the real route registration
description: New pages must be added to Router.tsx (BrowserRouter routes) not just protectedRoutesConfig.tsx (WindowManager only)
type: feedback
---

New page routes must be registered in BOTH files:
- `React2025/src/routes/Router.tsx` — the actual BrowserRouter that renders pages at URLs
- `React2025/src/routes/protectedRoutesConfig.tsx` — used by WindowManager for in-app window resolution

**Why:** Adding only to protectedRoutesConfig caused a 404 at `/flight-sim/inventory` on the Vite dev server (port 5173). The page only worked through Django's hash-router path until Router.tsx was updated.

**How to apply:** When adding any new page route, always add to Router.tsx first (that's what the browser resolves), then protectedRoutesConfig.tsx (for WindowManager). Use `React.lazy()` + `<S>` suspense wrapper in Router.tsx.
