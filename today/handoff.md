# Handoff — 2026-07-11

## Where We Left Off

Major architectural session. DataBrowser is now the sole list engine — 63 ModelList.tsx files deleted, `/db/:model` routing live. Template resolution API built and tested. WCHQ Setting record seeded. Small-Stings complaint system live. Five subform types documented with calculated column approval chain.

Both repos committed:
- **webClerk3** `a2b9d80` — training tab, template API, WCHQ settings, Small-Stings, throttle fix
- **React2025** `dfdcf7c` — delete 63 ModelList.tsx, /db/:model routing, 3 readmes

## Do This First Next Session

1. **Test DataBrowser navigation** — click sidebar links (Contact, Customer, Proposal, Order, Invoice, Purchase, Item). Verify `/db/:model` loads the correct model every time.
2. **Polish Dashboard** — Action POLISH-DASHBOARD (#339) filed. Junky data, generic column names.
3. **Test Training tab** — Inventory Dashboard → Training tab. Follow guided steps.
4. **Wire BrowserDetail row-click cascade** — detail_route + detail_mode Setting config.
5. **Keyboard modifiers** — Cmd+Shift+Click (BrowserDetail), Cmd+Shift+Option+Click (ModelDetail).

## Open Problems

- DataBrowser detail pane doesn't navigate to custom Detail.tsx pages yet — cascade not wired
- Router.tsx has duplicate route definitions overlapping with protectedRoutesConfig.tsx — needs consolidation
- Some `/db/orgs.Employee` style routes use dotpath model names — verify wcapi registry resolves these

## Key Decisions (permanent)

- **No ModelList.tsx** — DataBrowser at `/db/:model` is the only list engine
- **Five subform types** — flat, JSON, BOM/tree, grouped, calculated columns
- **JS display, backend saves** — front-back mismatch is FAULT
- **zz/qq never tally** — permanent exclusion rule
- **JSON viewer read-only default** — authority-gated unlock
- **WCHQ Setting** (#439) — monthly admin review with dt_approved
- **Letters/emails via Word/Pages** — WC3 is data source via template API
