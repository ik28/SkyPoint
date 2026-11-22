# SkyPoints plain-English assistant

Ask questions about the SkyPoints Gold layer in plain English. This runs on a free
Snowflake account because only ordinary SQL runs inside Snowflake; the language model
runs outside it.

```
question -> Claude writes one SELECT -> guard checks it -> read-only Snowflake role runs it
         -> Claude explains the rows in plain English
```

## Status

| Piece | Status |
|---|---|
| Prompt, SQL guard, query runner | Written. Guard logic unit-checked locally. |
| End-to-end run against Snowflake | Not yet run. Needs your credentials and an Anthropic API key. |

## Safety

- Runs as `SKYPOINTS_READER`, a role with SELECT on two Gold views only (`setup_readonly_role.sql`).
  This is the real protection.
- A second check in code allows one SELECT/WITH statement and blocks write and admin keywords.
- 60 second query timeout, at most 50 rows returned.
- The model only sees column names and the rows returned by the query.

## Setup

1. Run `setup_readonly_role.sql` in Snowsight (replace `<WAREHOUSE>` and `<YOUR_USER>`).
2. `pip install -r requirements.txt`
3. Copy `.env.example` to `.env` and fill it in. `.env` is git-ignored. Never commit it.
4. Run:
   ```
   python ask_skypoints.py "Which country has the highest stale member percentage?"
   python ask_skypoints.py          # interactive
   ```

## Sample questions

- Which country has the highest stale member percentage?
- How many Platinum, Gold and Silver members are there in each country?
- Which partner has the most completed miles?
- Show pending vs completed miles by country.
- Top 5 Platinum members in India by miles redeemed in the last 90 days.

## Notes

- Sample data is old, so "last 30 days" questions return few or no rows.
- Country `XX` looks like an unmapped-country bucket and is excluded from rankings.
- Related: `Snowflake/Gold/Cortex/` holds the Cortex Analyst semantic view. Running a Cortex
  Agent is blocked on Snowflake trial accounts, which is why this app exists.
