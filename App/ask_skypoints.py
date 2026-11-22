#!/usr/bin/env python3
"""Ask the SkyPoints Gold layer questions in plain English.

question -> OpenAI writes one SELECT over the Gold views -> guard checks it ->
runs on Snowflake with a read-only role -> OpenAI explains the rows.

Usage:
    python App/ask_skypoints.py "Which country has the highest stale member percentage?"
    python App/ask_skypoints.py            # interactive mode
"""
import json
import os
import re
import sys

MODEL = os.getenv("OPENAI_MODEL", "gpt-4o")
MAX_ROWS = 50

SCHEMA_CONTEXT = """
You query the Snowflake database SKYPOINTS, schema GOLD, for an airline loyalty program.
Use ONLY these two views, always fully qualified.

SKYPOINTS.GOLD.VW_MEMBER_HORIZON_SUMMARY  (one row per member)
  MEMBER_ID NUMBER, MEMBER_NAME, COUNTRY, STATE, TIER_CODE, AGE NUMBER,
  STALE_MEMBER BOOLEAN, IS_ACTIVE ('A' or 'I'), ENROLLMENT_DATE DATE, LAST_FLIGHT_DATE DATE,
  DAYS_SINCE_LAST_FLIGHT NUMBER, FLEW_LAST_30D / FLEW_LAST_90D / FLEW_LAST_1Y / FLEW_LAST_5Y BOOLEAN,
  and for each horizon H in (30D, 90D, 1Y, 5Y): TXNS_H, COMPLETED_TXNS_H, COMPLETED_MILES_H, ACTIVE_PARTNERS_H,
  LIFETIME_TXNS, LIFETIME_COMPLETED_MILES, LIFETIME_PENDING_MILES, LIFETIME_CANCELLED_MILES,
  LAST_REDEMPTION_DATE DATE, ENGAGEMENT_SEGMENT.

SKYPOINTS.GOLD.VW_REDEMPTIONS_ENRICHED  (one row per redemption transaction)
  TXN_ID, TXN_DATE DATE, FEED_DATE DATE, PARTNER, MILES_REDEEMED NUMBER, REDEMPTION_STATUS,
  MEMBER_ID NUMBER, MEMBER_NAME, TIER_CODE, COUNTRY, STATE, DOB DATE, AGE, STALE_MEMBER BOOLEAN,
  IS_ACTIVE, ENROLLMENT_DATE DATE, LAST_FLIGHT_DATE DATE, DAYS_SINCE_ENROLLMENT_AT_TXN NUMBER,
  IS_ORPHAN_MEMBER BOOLEAN (transaction has no matching member profile).

Business rules:
- TIER_CODE: SLV = Silver, GLD = Gold, PLT = Platinum.
- COUNTRY holds codes: AU, CAN, IND, PHIL, UK, USA, XX. Map India to IND, United States to USA,
  Australia to AU, Canada to CAN, Philippines to PHIL, United Kingdom to UK.
- XX looks like an unknown or unmapped country bucket. Exclude it from country rankings and
  comparisons unless the user asks for it.
- A stale member (STALE_MEMBER = TRUE) has not flown in over 90 days. IS_ACTIVE is a separate account flag.
- ENGAGEMENT_SEGMENT values, most to least engaged: HIGHLY_ACTIVE_30D, ACTIVE_90D, COOLING_1Y, DORMANT_OVER_1Y.
- REDEMPTION_STATUS values: COMPLETED, PENDING, CANCELLED. "Miles redeemed" means COMPLETED only,
  unless the user asks about pending or cancelled miles. The *_COMPLETED_MILES columns are already COMPLETED only.
- Compute percentages from counts at member level (for example
  100.0 * COUNT_IF(STALE_MEMBER) / COUNT(*)). Never average percentages.
- For top-N questions without a number, use LIMIT 10. Round percentages to 2 decimals.
- Use Snowflake SQL. Write exactly one SELECT (a WITH clause is fine). No comments. No trailing semicolons.
""".strip()

SQL_SYSTEM = (
    SCHEMA_CONTEXT
    + """

Task: turn the user's question into one read-only Snowflake SELECT.
Reply with ONLY a JSON object, no other text:
{"sql": "<the query>", "note": "<one short sentence on the filters or assumptions used>"}
If the question cannot be answered from these views, reply:
{"sql": null, "note": "<why not>"}"""
)

ANSWER_SYSTEM = """You explain SQL results about the SkyPoints loyalty program in plain English.
Use only the numbers in the rows you are given. Do not invent or estimate anything.
Answer in one to three sentences, then stop. Mention filters that matter (for example excluding country XX).
If there are zero rows, say so. If the rows were truncated, say only the first rows are shown.
If the data looks surprising or old (for example everyone is stale), say so briefly."""

FORBIDDEN = re.compile(
    r"\b(insert|update|delete|merge|drop|create|alter|truncate|grant|revoke|call|copy|put|get|"
    r"use|execute|remove|undrop|set|unset|comment)\b",
    re.IGNORECASE,
)


def check_sql(sql):
    """Defence in depth. The real guard is the read-only Snowflake role."""
    if not isinstance(sql, str) or not sql.strip():
        raise ValueError("No SQL was produced.")
    s = re.sub(r";+\s*$", "", sql.strip()).strip()
    no_strings = re.sub(r"'(?:[^']|'')*'", "''", s)
    if ";" in no_strings:
        raise ValueError("Only one statement is allowed.")
    if not re.match(r"^(select|with)\b", s, re.IGNORECASE):
        raise ValueError("Only SELECT queries are allowed.")
    if "--" in no_strings or "/*" in no_strings:
        raise ValueError("SQL comments are not allowed.")
    m = FORBIDDEN.search(no_strings)
    if m:
        raise ValueError("Blocked keyword in SQL: " + m.group(1).upper())
    return s


def parse_json_reply(text):
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end == -1:
        raise ValueError("Model reply had no JSON object.")
    return json.loads(text[start : end + 1])


def ask_openai(client, system, messages, max_tokens=1500, json_mode=False):
    full_messages = [{"role": "system", "content": system}] + messages
    kwargs = dict(model=MODEL, max_tokens=max_tokens, messages=full_messages)
    if json_mode:
        kwargs["response_format"] = {"type": "json_object"}
    resp = client.chat.completions.create(**kwargs)
    return resp.choices[0].message.content or ""


def connect():
    import snowflake.connector

    params = dict(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        role=os.getenv("SNOWFLAKE_ROLE", "SKYPOINTS_READER"),
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database="SKYPOINTS",
        schema="GOLD",
    )
    if os.getenv("SNOWFLAKE_PAT"):
        params["authenticator"] = "PROGRAMMATIC_ACCESS_TOKEN"
        params["token"] = os.environ["SNOWFLAKE_PAT"]
    else:
        params["password"] = os.environ["SNOWFLAKE_PASSWORD"]
    conn = snowflake.connector.connect(**params)
    conn.cursor().execute("ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = 60")
    print(f"Connected: role={conn.role}")
    return conn


def run_query(conn, sql):
    cur = conn.cursor()
    try:
        cur.execute(sql)
        cols = [c[0] for c in cur.description]
        rows = cur.fetchmany(MAX_ROWS + 1)
    finally:
        cur.close()
    truncated = len(rows) > MAX_ROWS
    return cols, [list(r) for r in rows[:MAX_ROWS]], truncated


def print_table(cols, rows):
    if not rows:
        print("(no rows)")
        return
    text_rows = [[("" if v is None else str(v)) for v in r] for r in rows]
    widths = [max(len(c), *(len(r[i]) for r in text_rows)) for i, c in enumerate(cols)]
    print("  ".join(c.ljust(w) for c, w in zip(cols, widths)))
    print("  ".join("-" * w for w in widths))
    for r in text_rows:
        print("  ".join(v.ljust(w) for v, w in zip(r, widths)))


def answer_question(client, conn, question, show_sql=True):
    messages = [{"role": "user", "content": question}]
    sql, note, last_error = None, "", None
    for attempt in range(2):
        reply = ask_openai(client, SQL_SYSTEM, messages, json_mode=True)
        try:
            data = parse_json_reply(reply)
            note = data.get("note", "")
            if data.get("sql") is None:
                print("\n" + note)
                return
            sql = check_sql(data["sql"])
            cols, rows, truncated = run_query(conn, sql)
            break
        except Exception as exc:  # retry once with the error
            last_error = str(exc)
            messages += [
                {"role": "assistant", "content": reply},
                {"role": "user", "content": "That failed: " + last_error + ". Fix the query and reply with the JSON only."},
            ]
            sql = None
    if sql is None:
        print("\nCould not produce a working query: " + str(last_error))
        return

    if show_sql:
        print("\nSQL used:\n" + sql)
    print()
    print_table(cols, rows)

    payload = (
        "Question: " + question
        + "\nSQL: " + sql
        + "\nColumns: " + json.dumps(cols)
        + "\nRows (truncated=" + str(truncated) + "): " + json.dumps(rows, default=str)
    )
    summary = ask_openai(client, ANSWER_SYSTEM, [{"role": "user", "content": payload}], max_tokens=400)
    print("\n" + summary.strip())
    if note:
        print("(" + note.strip() + ")")


def main():
    from dotenv import load_dotenv
    from openai import OpenAI

    load_dotenv()
    client = OpenAI()
    conn = connect()
    try:
        if len(sys.argv) > 1:
            answer_question(client, conn, " ".join(sys.argv[1:]))
            return
        print("SkyPoints assistant. Ask a question, or type 'quit'.")
        while True:
            try:
                q = input("\n> ").strip()
            except (EOFError, KeyboardInterrupt):
                break
            if q.lower() in {"quit", "exit", ""}:
                break
            answer_question(client, conn, q)
    finally:
        conn.close()


if __name__ == "__main__":
    main()