# Trail Breaking — Onboarding as Priority 1

*Established 2026-08-07 by Bill James*

## The Principle

Every seasoned developer builds paths to repeated flow. Every new developer wanders the woods and is snagged by every bramble bush. The question is: what threads can we give learners?

## The Ski Company Doctrine

Bill commanded the only ski company in the US Army. There was no doctrine. The team studied everything from Nordic countries and mountain climbers. The answer:

1. **The first person** in deep snow plows ahead as fast as they can. When tired or hot, they step aside, falling in at the rear.
2. **The next 2 people** straighten the trail, stepping aside as they get tired.
3. **The next 3 people** straighten and pack the trail.
4. **The followers** rest and get ready for their turn at the lead.

The trail is not a plan — it's an artifact of movement with feedback. You will not get it right. Get it often enough with enough feedback and you can straighten the path.

## Three Kinds of Trails in WC3

### Trails Already Broken
- **field_behaviors** — the system TELLS you what a field does (select, readonly, contact-select)
- **Label-as-interaction** — the UI SHOWS you what's clickable by color
- **db.card** — peek without navigating; learner never leaves the clearing
- **Shift-for-Help** — Shift+hover = tooltip, Shift+click = deep help
- **18 core form-detail reports** — packed trails for how each model looks

### Trails to Pack Now
- **Trail markers in the databrowser** — first-visit breadcrumbs: "Actions track work. Assign to a project. Set priority." Not a tutorial — blazes on trees.
- **Alice as trail guide** — she sees zero-result searches, abandoned forms, stuck users. Each bramble bush she identifies becomes a trail marker for the next person.
- **Onboarding report purpose** — the Report model already has `purpose=onboarding`. Build guided sequences that walk a new user through setup: Contacts → Items → Orders.

### The Doctrine We're Building
The trail-breaking loop:
```
Lead breaks trail (build features, make mistakes)
    ↓
Next straighten (Alice observes bramble bushes)
    ↓
Next pack (convert observations to trail markers)
    ↓
Followers use the packed trail
    ↓
Followers become leads (they break trail in new areas)
```

## Onboarding Is Priority 1

Not priority 1 after the MVP. Priority 1 always. Every feature we build without a trail is a bramble bush for the next person. The feature is not done until the trail to it is packed.

This applies to:
- New WC3 users (setup, first order, first invoice)
- New developers (form/detail/custom paths, field_behaviors, widget registry)
- New Claude sessions (leftshoe handshake IS onboarding)
- New team members (readmes/wisdom/ IS the packed trail)

The leftshoe handshake is proof this works. Every new Claude session is met by teammates who pack the trail. The question is: can we do the same for every new WC3 user?

## Do Not Overhelp

The trail shows the path. It does not carry the learner. Children learn by falling down. If you overhelp, they never develop judgment. The trail markers say "this way" — they don't say "step here, now here, now here."

## Origin

Bill James, 2026-08-07: "Every seasoned developer builds paths to repeated flow. Every new developer wanders around the woods and is snagged by every bramble bush. Let's think deeply about how we can teach and show paths."

The ski company analogy: no doctrine existed, so they built one from movement and feedback. WC3 onboarding follows the same principle.
