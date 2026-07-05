---
name: REST URLs for routing, wcapi for data — strictly enforced
description: Django REST paths are for browser routing only; all data CRUD must flow through wcapi.ts; no direct Django URL calls from components
type: feedback
---

REST-style URLs (`/org/customer/list`, `/transactions/order/42`) are for React Router navigation only — readable, teachable, in the browser address bar and sidebar links.

All data operations MUST go through wcapi.ts functions: `getRecords`, `getRecord`, `saveRecord`, `deleteRecord`. The axios interceptor (`restToWcapi.ts`) auto-converts stray REST calls, but components should call wcapi directly.

**Why:** wcapi is the single security gate — RBAC, query scoping, field filtering, audit trail. Bypassing it bypasses security.

**How to apply:** When writing or reviewing any React component that touches data, verify it imports from `@/api/wcapi` not from `apiClient.get('/api/...')`. The interceptor is a safety net, not the intended path.
