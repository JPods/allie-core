---
name: Training video hosting — Vimeo + YouTube
description: Internal training uses Vimeo embeds; YouTube for public reach; WC3 Document record holds both links; track views on both
type: reference
---

Training videos upload to Vimeo first (Bill's existing workflow), then cross-post to YouTube.

- **Vimeo:** Internal training embeds, partner/investor sharing, password protection, clean player
- **YouTube:** Public discovery, SEO, students/planners finding JPods, free marketing
- **WC3 Document record:** Holds both links (refs.links.vimeo, refs.links.youtube), tracks view counts on both
- **Internal training pages** (MeshMobility Examples, WC3 training) embed Vimeo
- Marketing discussion coming soon

**How to apply:** Every training video Document record should have:
```json
{
  "refs": {
    "links": {
      "vimeo": "https://vimeo.com/...",
      "youtube": "https://youtube.com/watch?v=..."
    },
    "keywords": ["training", "video", "meshmobility"]
  }
}
```
