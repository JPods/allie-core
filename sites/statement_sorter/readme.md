# Statement Sorter — Folder Organization

## Recommended Folder Structure

Keep all your tax-related files in one folder per year:

```
~/Taxes/
  2025/
    categories.json          ← your custom category lists (saved from Statement Sorter)
    WellsFargo/
      checking-2025.csv
      cc-2025.csv
    USAA/
      checking-2025.csv
      cc-2025.csv
    Wise/
      wise-2025.csv
    GoDaddy/
      domains-2025.csv
    sorted/                  ← export your sorted results here
      business-2025.csv
      business-2025.json
      personal-2025.csv
  2024/
    categories.json
    ...
```

## How It Works

1. **Drop your year folder** onto Statement Sorter — it reads all CSV/JSON files in the folder and subfolders
2. **Sort** each line as business or personal by picking a category — the classification is automatic
3. **Edit Categories** — customize the business and personal category lists for your needs
4. **Save categories.json** to your year folder so next year you start with the same lists
5. **Export** business lines as CSV or JSON for your accountant; personal lines stay private

## categories.json Format

```json
{
  "business": [
    "Advertising",
    "Bank Fees",
    "Domains",
    "Equipment",
    "Hosting",
    "..."
  ],
  "personal": [
    "Clothing",
    "Dining Out",
    "Groceries",
    "..."
  ]
}
```

One category per entry. Edit freely — add your own, remove what you don't use. Load the file next time you open Statement Sorter.

## Privacy

- Your data never leaves your browser
- Nothing is uploaded to any server
- Statement Sorter is a single HTML file — no dependencies, no tracking
- Your categories.json is a plain text file you control

## Supported Banks

- Wells Fargo (credit card + checking)
- USAA (credit card + checking)
- Wise
- GoDaddy / domain registrars
- Any CSV with date + amount + description columns

---

Free by [WebClerk](https://webclerk.com) — open source commerce for sovereign businesses.
