# WebClerk Flowchart Color Palette

Standard colors for all WC3/WC2 flowcharts. Use consistently across charts.

## Node Fill Colors by Semantic Role

| Role | Fill Color | Hex | Used For |
|------|-----------|-----|----------|
| **Transaction** | Light yellow | `#FCF3CF` | Order, Proposal, Invoice, Purchase, Requisition, PO |
| **Finance/Payment** | Mint green | `#ABEBC6` | Payment, GL, Invoice (financial), journals |
| **Contact/Identity** | Light pink | `#FADBD8` | Contact, OrgBase, identity decisions |
| **Product/Inventory** | Light blue | `#D6EAF8` | Item, inventory, quantities |
| **Action/Workflow** | Tan | `#F5CBA7` | Workflow, backorder, forecast (octagon) |
| **Management** | Light gray | `#D5D8DC` | Objectives, risk, management nodes |
| **Module/System** | Pale gray | `#EAECEE` | Module sidebar items |
| **AI/Alice** | Soft blue | `#AED6F1` | Alice, communications, AI features |
| **Setting/Config** | Warm yellow | `#F4D03F` | Setting model, configuration |
| **Security** | Coral | `#F5B7B1` | Athena, security, access control |
| **Approval/Success** | Green | `#ABEBC6` | Promote, activate, approved |
| **Cross-reference** | Lavender | `#F4ECF7` | "See also" notes |
| **JSON/Data** | Soft green | `#D5F5E3` | Journals, data processing |
| **External** | Orange-tinted | `#E59866` | External sources, vendors, any_record |
| **Loop/Pattern** | Purple | `#E8DAEF` | Observe→log→pattern loop, cleanup |

## Cluster Fill Colors

| Cluster Type | Fill | Border | Hex |
|-------------|------|--------|-----|
| **Input/Source** | Ice blue | Soft blue | `#EBF5FB` / `#AED6F1` |
| **Processing** | Warm cream | Gold | `#FEF9E7` / `#F9E79F` |
| **Output/Target** | Ice blue | Blue | `#E3F2FD` / `#90CAF9` |
| **Views/Display** | Mint | Teal | `#E8F8F5` / `#A3E4D7` |
| **Alert/Error** | Blush | Salmon | `#FDEDEC` / `#F5B7B1` |
| **Loop/Cycle** | Lavender | Purple | `#F4ECF7` / `#D2B4DE` |
| **Config/PJPV** | Peach | Tan | `#FDF2E9` / `#F5CBA7` |

## Node Shapes

| Shape | Used For |
|-------|----------|
| `box` | Models, records, standard nodes |
| `diamond` | Central hub models (Contact, Action), decisions |
| `octagon` | Process/workflow steps |
| `note` | Rules, cross-references, annotations |
| `ellipse` | Start/end states, external actors |
| `cylinder` | Databases, persistent stores |
| `parallelogram` | External input/output |

## Edge Colors

| Color | Hex | Used For |
|-------|-----|----------|
| Default gray | `#666666` | Standard flow |
| Green | `#27AE60` | Linkage, positive flow |
| Blue | `#2980B9` | Data flow, queries |
| Red | `#E74C3C` | Alerts, errors, reverse flow |
| Orange | `#E67E22` | External integration |
| Purple | `#8E44AD` | Pattern loop, internal cycle |
| Dark red | `#922B21` | Pending records, inventory impact |
