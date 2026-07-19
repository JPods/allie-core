# Bend to Perception

**Source:** Bill James, 2026-07-17
**Context:** Building live-data report editing for WC3

---

> *"The user is more connected to the data than the program.
> We need to have the program bend to her perception."*

---

## What This Means

The user doesn't think in templates, schemas, field maps, or JSON
envelopes. She thinks in invoices, customers, and products. She
knows that proposal #42 is the Precor deal with the 30% terms and
the five line items. She doesn't know that it's `model_name=proposal`,
`id=42`, `totals.subtotal=28700.00`.

When she edits a report layout, she's not editing a template. She's
editing *her proposal to Precor*. The template is an abstraction the
program needs. The proposal is the reality she lives in.

**Every time the program forces the user to think in program terms
instead of data terms, the program is wrong.**

## The Principle

The program must present the user's world, not its own. This means:

1. **Show real data, not placeholders.** When editing a report template,
   render it with the user's actual proposal — not "Lorem ipsum" or
   "Sample Customer." She needs to see if the layout works for *her*
   data, not hypothetical data.

2. **Name things the way the user names them.** "Proposal to Precor"
   not "Report #243 model_name=proposal record_id=42". The ida, the
   customer name, the dollar amount — those are the user's handles.

3. **Navigate by data, not by program structure.** The user doesn't
   want to go to /pdf-designer/243. She wants to click the proposal
   she's looking at and say "fix the layout." The program figures out
   the route.

4. **Validate with real consequences.** Don't show "template saved
   successfully." Show the proposal re-rendered with the new layout
   so she can see what changed. The save is an implementation detail.
   The result is what she cares about.

5. **Errors in data terms.** Don't say "field 'totals.subtotal' is
   null." Say "This proposal has no subtotal — the layout can't
   calculate the total without it."

## Applied to WC3

| Program thinking | User thinking | Bend to |
|-----------------|---------------|---------|
| Report #243, template key "proposal" | "My proposal to Precor" | Show Precor's name and data |
| pdfme schema, field positions in mm | "Move the address block down" | Visual drag-and-drop with live data |
| `model_name=proposal, filters={}` | "Show me my proposals" | Click Proposal in the sidebar |
| `is_active=false` | "I don't need this report" | Trash button, not a checkbox |
| `metadata.flow.use_count=0` | "Nobody uses this" | Alice says "this has never been used" |
| `config.pdfme_template.schemas[0][4]` | "The line items table" | Show the table with her items in it |

## For Alice

This is Alice's core coaching principle. When a user asks "how do
I print this proposal?", Alice doesn't explain the report system
architecture. She says "click Print, choose Proposal / Quote, and
it will show you a preview with your data. If the layout isn't right,
click ✏️ to adjust it."

Alice speaks in the user's data, not in program structure.

When Alice creates an Action for a vague report description, she
doesn't say "Report #115 has description length < 30 characters."
She says "You have a report called 'Proposal 2' — when you look
at the report list, you can't tell what this one does differently
from 'Proposal 1.' Open it, look at the output, and write what
makes it different."

## For Andi

Andi monitors from the program's perspective — she sees API calls,
error rates, field values. But when she flags something to a human
(via Alice Action), she translates to data terms:

Not: "Report #72 metadata.flow.use_count=0 for 30 days"
But: "The 'Invoice - Standard' report hasn't been used in a month.
      Your team may be using 'Invoice - Shipping' instead."

## For All of Us

The program is the trellis. The data is the rose. The user cares
about the rose. We build the trellis to support it — but the moment
the trellis gets in the way of the rose, the trellis is wrong.

This is the same principle as Allie's foundation:
> *"I am a trellis, not the rose. The moment I become the thing
> people serve rather than the thing that serves people, I have failed."*

Applied to program design: the moment the user serves the program's
abstractions instead of the program serving the user's data, we
have failed.

---

## Humans Are Tactile

> *"Humans are tactile. We must make their touch feel balanced and sturdy."*

A printed invoice is not a PDF file. It is a piece of paper a human
holds in her hand. She feels the weight of the paper, sees the alignment
of the columns, notices whether the totals line up, whether the logo
is crisp, whether the address block is where she expects it.

If the form feels flimsy — misaligned, crowded, data in wrong places,
fonts too small — the human loses trust. Not in the software. In the
business. The invoice IS the business at the moment of payment.

Balanced: the visual weight is distributed. The eye flows naturally
from company to customer to lines to totals. Nothing crowds. Nothing
floats unmoored.

Sturdy: the form looks like it was designed by someone who cares.
The borders are consistent. The columns align. The numbers right-justify.
The footer doesn't collide with the last line item.

This is not aesthetics. This is trust. The form is the handshake
between the business and the customer. Make it feel like a firm grip,
not a limp hand.
