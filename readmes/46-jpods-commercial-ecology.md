# JPods Commercial Ecology
**Last Updated:** 2026-05-22
**Owner:** Bill James
**Related:** `readmes/45-fare-and-payment.md`, `readmes/09-carryon.md`, `readmes/12-jpods.md`
**Action:** Reference when designing capital structure, LMC governance, or NCC accounting

---

## Five Single-Purpose Company Types

JPods operates through five distinct, single-purpose company types. Each has a defined role; none bleeds into another's domain.

| # | Type | Abbreviation | Role |
|---|------|-------------|------|
| 1 | JPods LLC | JPOD | Technology developer and standards enforcement |
| 2 | Network Construction Companies | NCC | Build certified networks; sell to LMCs |
| 3 | Local Mobility Companies | LMC | Own and operate networks; serve farebox payers |
| 4 | Supply Chain Companies | SC | Manufacture and supply certified components to NCCs |
| 5 | Finance Sources | FIN | Provide capital to NCCs (construction) and LMCs (acquisition) |

The dependency flow:

```
Finance → NCC → LMC → Farebox payers (passengers + cargo)
               ↑
          Supply chain
               ↑
          JPods LLC (standards + certification)
```

---

## JPods LLC (JPOD)

Technology owner and standards enforcer. JPods LLC does not build networks, own networks, or operate transit. It:

- Develops and licenses the JPods technology standard
- Certifies networks built by NCCs before they can be sold
- Certifies components manufactured by supply chain companies
- Enforces the 5X5 Standard across all network deployments
- Holds the patents and licenses them to NCCs and LMCs

JPods LLC is the franchisor analog. It sets the rules; others operate within them.

---

## Network Construction Companies (NCC)

NCCs build JPods networks to the standard set by JPods LLC. They are construction companies, not operators.

**Weekly accounting cycle:** NCCs operate on a one-week build-and-sell cycle.

> **Every Wednesday at 3:00 PM local time**, networks certified by JPods LLC that week are sold to Local Mobility Companies.

This regularizes the NCC revenue cycle. The NCC knows its sale date before construction begins. Finance can underwrite against a known schedule. LMCs know their acquisition cost in advance.

**NCC customers are LMCs** — not passengers, not cities. The NCC builds; the LMC buys.

**Finance for NCCs:** NCCs need construction financing for the period between groundbreaking and the Wednesday sale. Finance sources underwrite this bridge. The certified-network sale retires the construction loan.

Most NCCs are expected to be taken public.

---

## Local Mobility Companies (LMC)

LMCs own and operate JPods networks. They are the ongoing businesses — the utilities of the JPods ecology.

**LMC customers are farebox payers** — passengers and cargo shippers.

**LMC revenue:** farebox receipts, cargo fees, bike loan fees, advertising on guideway structure (where permitted by operator).

**LMC obligations:** maintain the network to JPods standards, honor the 5X5 Standard, service acquisition debt, pay dividends to customer and employee equity holders.

Most LMCs are expected to be taken public.

---

## Supply Chain Companies

Supply chain companies manufacture the physical components of JPods networks: guideway beams, columns, solar panels, pods (vehicles), station components, sensors, and control hardware.

Supply chain companies sell to NCCs. They must meet JPods LLC component certification to participate in the supply chain.

**Market-competitive, not locally captive.** Multiple vendors may meet the standard for any given component. Normal market discipline applies — JPods LLC standards control quality; competition controls price. The 10%/10% customer/employee equity structure (see below) does not apply to supply chain companies; they are not local monopolies.

---

## Finance Sources

Finance sources provide capital to NCCs (construction loans retired at Wednesday sale) and to LMCs (acquisition financing for network purchase).

**The non-diluteable equity block self-selects for capital type.** The 20% locked equity block (10% customers + 10% employees, see below) is permanent and cannot be restructured away. This attracts:

- Patient capital (infrastructure funds, community development financial institutions)
- Municipal bonds and local bond markets
- Rural cooperative-style member investment

And repels:

- Growth equity expecting restructuring rights
- Private equity expecting full exit on their timeline

This filter is a feature. JPods infrastructure should attract the same capital that finances water systems and electric cooperatives — long-horizon, community-aligned capital — not capital that optimizes for extraction.

---

## Capital Structure — LMC Equity

### The 10% / 10% Non-Diluteable Rule

Every LMC issues equity in three classes:

| Class | Block | Non-diluteable | Governance |
|-------|-------|---------------|-----------|
| Customer | 10% | Yes | One board seat, elected by customers |
| Employee | 10% | Yes | One board seat, elected by employees |
| Investor / Public | 80% | Investor terms | Standard board representation |

**Non-diluteable** means every future capital raise maintains the customer block at 10% and the employee block at 10%. New shares issued to investors do not reduce these blocks — they are recalculated to maintain the 10% floor. Investors know this before they invest.

**Why:** LMCs are local monopolies. There is one JPods network per corridor. Without competition, the standard protection against extraction is regulation — a regulator who can be captured. The structural alternative is ownership: make the captive customers into owners. A customer who receives dividends from the network has an interest in its health. A customer with a board seat has a voice in its governance. This is more durable than regulatory protection.

**Historical precedent:** Rural Electric Cooperatives (RECs) have operated this model since the 1930s. Credit unions apply it to banking. The JPods version applies it to transit infrastructure.

---

## Customer Equity — CarryOn as Equity Ledger

JPods ridership privacy policy prohibits central tracking of individual travel. The LMC cannot maintain a database mapping person → trips → equity. Instead:

1. Rider completes a trip
2. LMC credits a small equity unit to the rider's **myCarryOn** (CarryOn UUID)
3. CarryOn accumulates voting weight and dividend credits
4. On dividend declaration, rider presents CarryOn; LMC pays without learning travel history

The record is the rider's, on their device. The LMC sees a CarryOn with X credits presenting a dividend claim — not a person with a travel history.

**Anonymous QR riders receive no equity.** Voting rights and dividends require a registered CarryOn UUID. An anonymous equity path would allow a wealthy actor to purchase QR passes in volume, accumulate votes without identification, and capture the customer board seat — defeating the purpose of the non-diluteable customer block. Equity is tied to the person, not the transaction. Anonymous riders get the trip; registered riders get ownership.

**Board seat election:** Registered CarryOn holders vote by accumulated voting weight. Privacy-preserving voting (blind signatures or zero-knowledge proof) tabulates the result without revealing individual voter identity or travel history.

**Encrypted tokens — all equity instruments:** Voting rights and dividend benefits are issued and redeemed as encrypted tokens. The token encodes the right and the issuing LMC, but not the holder's identity. The LMC verifies the token is valid and unspent without learning who holds it. Tokens are non-transferable (bound to the CarryOn UUID at issuance) and marked spent on redemption — cannot be double-used.

See `readmes/09-carryon.md` — Equity Ledger section for the full schema.

---

## Employee Equity

Employees hold 10% of LMC equity, non-diluteable, with one elected board seat.

Employee equity is held on the employee's CarryOn under `equity.holdings` with `"class": "employee"`. Vesting schedule and dividend rights are set at employment. The board seat is elected by employees.

**Why:** Employees who are owners behave differently from employees who are wage earners. They have a stake in network quality, customer satisfaction, and long-term financial health. This is the same logic as the customer equity — align incentives structurally rather than through management directives.

---

## NCC Equity

NCCs are build-and-sell companies. They do not have an ongoing customer relationship equivalent to LMC farebox payers. The 10%/10% customer/employee equity structure applies at the LMC level, not the NCC level.

NCC employees may hold standard employee equity per the NCC's own structure. NCC governance is conventional — no mandated customer equity class, because NCCs have no captive customers. The LMC-as-NCC-customer already participates in the LMC equity structure.

---

## LMC Acquisition — Wednesday Sale Mechanics

1. NCC completes a network segment and submits for JPods LLC certification
2. JPods LLC certifies (or rejects with required corrections)
3. Wednesday 3:00 PM: certified networks offered to LMCs at the weekly clearing price
4. LMC acquires with finance from FIN sources
5. Construction loan retired from sale proceeds
6. LMC begins operating; farebox revenue services acquisition debt and funds dividends

**Pre-arranged sales are permitted.** An LMC may contract with an NCC before construction begins, locking the acquisition price and the Wednesday delivery date. This reduces NCC financing cost (the sale is pre-sold) and gives the LMC a predictable activation date.

---

## Open Questions

- LMC creditworthiness: who qualifies an LMC to purchase at the Wednesday sale? JPods LLC certifies the network; finance sources assess the LMC. Is there a JPods LLC role in LMC financial qualification, or does that belong entirely to the finance source?
- Customer board seat election mechanism: how are elections run? Minimum participation threshold? Frequency?
- Employee vesting: standard schedule, or LMC-defined?
- NCC certification timeline: how long does JPods LLC certification take? What is the failure path if a network fails certification the week it was expected to sell?
- Supply chain certification: component-level certification, or vendor-level? What happens when a certified component is discontinued?
