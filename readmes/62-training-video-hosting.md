# Training Video Hosting — Vimeo + YouTube

## Decision

Upload every training video to both Vimeo and YouTube. Different platforms, different purposes, same content.

## Platform Assessment

| Factor | Vimeo | YouTube |
|--------|-------|---------|
| **Player quality** | Clean, no distractions, no competitor ads | Ads on your content unless you pay for Premium |
| **Embedding** | Professional — ideal for WC3 training pages, MeshMobility Examples panel, investor decks | Cluttered — related videos, subscribe buttons, end screens |
| **Password protection** | Yes — control who sees pre-release content | No — public or unlisted only |
| **Discovery** | Poor — nobody browses Vimeo looking for transit planning videos | Excellent — second largest search engine in the world |
| **SEO** | Minimal | Strong — Google indexes YouTube content, shows video cards in search results |
| **Cost** | Paid plans for storage/bandwidth | Free |
| **Analytics** | Good — heat maps, engagement, finish rate | Good — demographics, traffic sources, retention |
| **Audience** | Partners, investors, existing customers, internal team | Students, city planners, engineers, the public |
| **Brand control** | High — your player, your colors, no surprises | Low — YouTube decides what plays next |

## Why Both

Vimeo alone means nobody finds you. YouTube alone means your training pages look unprofessional with ads and distractions.

- **Vimeo** = the controlled experience (internal training, partner demos, investor presentations)
- **YouTube** = the world finds you (every training video is also a product demo)

A student searching "automated transit network design" finds your YouTube video, watches the MeshMobility tutorial, and discovers JPods exists. That's free marketing. Not using YouTube is leaving reach on the table.

## Implementation

### WC3 Document Record

Every training video is a Document record with both links:

```json
{
  "name": "MM-01: Getting Started with MeshMobility",
  "description": "Launch, load a network, navigate the map — 2 min",
  "status": "published",
  "refs": {
    "keywords": ["training", "video", "meshmobility", "getting-started"],
    "links": {
      "vimeo": "https://vimeo.com/XXXXXXXXX",
      "youtube": "https://www.youtube.com/watch?v=XXXXXXXXXXX"
    },
    "spec_refs": ["readmes/27-route-time.md"]
  },
  "config": {
    "duration_seconds": 120,
    "feature": "01-getting-started",
    "quiz": "QUIZ-MM-01-GETTING-STARTED"
  }
}
```

### Internal Training Pages

Embed Vimeo:
```html
<iframe src="https://player.vimeo.com/video/XXXXXXXXX" width="640" height="360" frameborder="0" allow="autoplay; fullscreen" allowfullscreen></iframe>
```

### Public / Marketing

Link to YouTube. Optimize titles and descriptions for search:
- Title: "How to Design a Transit Network in 2 Minutes | MeshMobility by JPods"
- Description: Include keywords, links to jpods.com, 5x5FreeMarket.com
- Tags: automated transit, PRT, personal rapid transit, network design, JPods

### View Tracking

Alice tracks views from both platforms:
- Vimeo: API at `https://api.vimeo.com/videos/{id}/stats` (requires auth token)
- YouTube: API at `https://www.googleapis.com/youtube/v3/videos?part=statistics&id={id}` (requires API key)

Combined view count stored in Document metadata for reporting.

## Workflow

1. Record screen capture (QuickTime) following the script in `training/{feature}/script.md`
2. Upload to Vimeo first — set privacy, add to JPods Training showcase
3. Cross-post to YouTube — optimize title/description/tags for search
4. Create Document record in WC3 with both links
5. Link the quiz from `training/{feature}/qa.json` to the Document
6. Embed Vimeo player in MeshMobility Examples panel and WC3 training pages

## File Locations

- Video scripts: `route_time/training/{feature}/script.md`
- Quiz questions: `route_time/training/{feature}/qa.json`
- Feature readme: `route_time/training/{feature}/README.md`
- Recorded videos: `/Volumes/Allie/jpods/library/training/` (local backup)
