---
name: Payment checkbook architecture
description: Payment model with signed amounts, received/expense types, category→GL mapping, method CharField, customer/vendor FKs, DataBrowser checkbook view, dashboard buttons
type: project
---

Payment model redesigned as a checkbook register (2026-07-31):

- **Signed amounts**: positive=received, negative=expense. SUM(amount)=net cash position.
- **Two types**: received (money in), expense (money out). Fixed by entry point, not user choice.
- **category** CharField with select list + freehand + gl_map in Setting for GL posting.
- **method** CharField replacing payment_method FK. Freehand: visa_3425, check-WellsFargo, cash.
- **customer/vendor FKs** added. Received→customer, expense→vendor.
- **contact** nullable with name-search lookup (LookupSearch in BehaviorField.tsx).
- **Journalizer** reads sign: positive→Cash debit/AR credit, negative→category GL debit/Cash credit.
- **Dashboard buttons**: Payments (teal), Expenses (rose) in Home.tsx QUICK_ADDS.
- **DataBrowser**: checkbook named view as default. Draggable splitter between list/detail.
- **Setting.prefs.defaults**: installation-level defaults for new records (type, method, category).
- **Action #31061**: evaluate payment processing services, due 2026-08-21.

**Why:** Bill thinks in checkbook terms. Money in or money out. Category tells the rest. Users avoid GL codes — the bucket is their language.

**How to apply:** All payment work references this architecture. The AddPaymentModal in invoice/order context sets type=received. The Expenses dashboard entry sets type=expense.
