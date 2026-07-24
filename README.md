# HKN Portal — Project README
*Last updated: July 24, 2026*

---

## What This Project Is

A web-based student management portal for **Hindi Ki Neev (HKN)**, a Bay Area community Hindi school.
Built as a single HTML file (`index.html`) with a Supabase PostgreSQL backend and Google OAuth login.

**Status: cutover complete.** `portal.hindikineev.org` is now running the new
Supabase-based system in production. The old Drive/Apps Script backend has
been retired from active use.

**Notable features:**
- **Send Email** and the **Template Editor** both have a rich-text formatting
  toolbar (Bold/Italic/Underline/color/size) — compose messages get saved as
  real HTML, not plain text
- **School Attributes** is organized into 4 subtabs: Portal Settings,
  Teachers, Classes, and Edit Scoring Guide
- **Book Inventory** page tracks starting stock, replacements, and teacher
  copies, with distributed-book counts calculated live from student data
- **Parent portal** (anonymous access) lets parents look up their child's
  status, attendance, and scores without logging in

---

## Files in This Repo / Folder

| File | Purpose | How to edit |
|------|---------|-------------|
| `index.html` | The entire portal — staff portal, parent portal, all features | VS Code or any text editor. Deploy by uploading to GitHub (overwrites by matching filename — no deletion needed). |
| `HKN_Parent_Guide.html` | Parent-facing policy guide (opens when parent clicks "Parent Guide" button) | VS Code — find the question/answer text you want to change, edit between the tags, save. |
| `schema.sql` | Complete, consolidated database schema — every table, function, RLS policy, and grant, built from live introspection of production. Used to stand up a fresh (e.g. dev/staging) Supabase project from scratch. | Reference/setup only — not something you "run" against an already-configured project. |
| `book_inventory_plan.md` | Original implementation plan for the book inventory feature (now built) | Reference document |

---

## Running Locally

```bash
cd D:\hkn-portal
npx serve . -l 8080
```

Then open `http://localhost:8080` in Chrome.

**Requirements:** Node.js installed on your machine.

**To stop:** press `Ctrl+C` in the Command Prompt window.

---

## Supabase (Database)

**Project URL:** `https://dovmjcanfmswxofazvgc.supabase.co`
**Dashboard:** `https://supabase.com/dashboard/project/dovmjcanfmswxofazvgc`
**Publishable key:** stored in `index.html` (safe to be public)
**Secret/service role key:** never put this in `index.html` — only used for one-time admin tasks directly in Supabase

### Tables (11 total)

| Table | What it stores |
|-------|---------------|
| `students` | All student records — bio info, `session_data` (attendance, scores, teacher, class level, book level per session), `status_history`, `last_parent_access` |
| `sessions` | School sessions (Fall-2026, Spring-2026 etc.) with class dates, fees, enrollment status |
| `teachers` | Teacher/admin accounts |
| `templates` | Email templates |
| `settings` | Portal settings (MOTD, intake/staff enabled, inactivity timer) — single row, `id = 1` |
| `lookup_config` | Class levels, book levels, class times, class names |
| `scoring_guide` | Scoring guide content per class level (9 rows: Beg-1 through Adv-2), editable by admin in-portal |
| `book_inventory` | Starting book stock per session/book level/type |
| `book_replacements` | Log of replacement books issued to students |
| `book_teacher_copies` | Log of books given to teachers |
| `admins` | Two protected admin accounts (`rajiv@`, `portal@`) — see "Admin Safety Net" below |

### SECURITY DEFINER Functions (8 total)
- `is_admin()` / `is_portal_user()` — core role-check functions used by every RLS policy
- `get_teacher_by_email(lookup_email)` — returns role for a logged-in user; checks `admins` first, then `teachers`
- `get_public_data()` — returns settings + sessions for the anonymous parent portal. **Sessions are ordered by each session's actual earliest class date** (not by year/term text — see "Known Fixes" below for why this matters)
- `lookup_student(email, first_name, dob)` — anonymous parent lookup
- `save_student_from_intake(student_json)` — anonymous parent enrollment/interest submission
- `get_distributed_books(session, prev_session)` — calculates new books needed for a session
- `rls_auto_enable()` — Supabase-platform event trigger support function (not actively required by the app)

### Supabase Daily Backups
Supabase automatically backs up the database daily. For self-managed backups, use the
portal's **Backup & Restore** page to download a JSON file.

---

## Admin Safety Net — the `admins` table

**Do not delete or modify this table casually.** It exists specifically so that
`rajiv@hindikineev.org` and `portal@hindikineev.org` can never be locked out
of the portal, no matter what happens to the `teachers` table.

**Why it exists:** restoring an old JSON backup (from before Supabase existed,
or any backup whose `teachers` list doesn't include admin rows) wipes every
teacher record in Supabase — including admins — since restore does a true
delete-then-insert on `teachers`, not a merge. Without this table, that would
mean nobody could log in to fix it.

**How it protects you:** `admins` has **no client-facing access at all** —
Row Level Security is enabled with zero policies for `anon` or `authenticated`,
so no code in the portal can ever read or write it directly. Only two SQL
functions can see it: `get_teacher_by_email()` and `is_admin()`.

**To add a protected admin**, this must be done directly in Supabase SQL Editor:
```sql
insert into admins (email, first_name, last_name) values
  ('newemail@hindikineev.org', 'First', 'Last');
```

---

## Google OAuth

**Google Cloud Console:** `https://console.cloud.google.com`
**OAuth Client ID:** `403780981402-4d6k69prpesahb6911vqukrbiiji2ech.apps.googleusercontent.com`

### Authorized JavaScript Origins ✅ all registered
- `http://localhost:8080`
- `https://portal-new.hindikineev.org`
- `https://portal.hindikineev.org`

---

## Supabase Auth URL Configuration — two separate settings, easy to confuse

**Site URL** (Authentication → URL Configuration → top of page): the
*fallback* redirect destination used when nothing else matches. Currently
set to `https://portal.hindikineev.org`.

**Redirect URLs** (same page, separate list below Site URL): the actual
allow-list of destinations OAuth is permitted to send users to. Currently
contains:
- `http://localhost:8080`
- `https://portal-new.hindikineev.org`
- `https://portal.hindikineev.org`

**Why both matter:** these are genuinely separate settings. Having a domain
in Redirect URLs does *not* make it the Site URL, and vice versa. Production
login broke once (August 2026) because `portal.hindikineev.org` had only
ever been discussed as "added," but was actually never added to the Redirect
URLs list — login was silently working only because it happened to match
Site URL. If Site URL is ever changed for any reason, anything not
*explicitly* in Redirect URLs will break immediately. Always add new domains
to **both** settings, and verify by checking the actual list, not by memory.

### Adding a new domain (do both steps)
1. Google Cloud Console → APIs & Services → Credentials → the OAuth Client ID
   → add under both "Authorized JavaScript origins" and "Authorized redirect URIs"
2. Supabase Dashboard → Authentication → URL Configuration → add to
   **Redirect URLs** (click "Add URL" or the "+" control below the list)

---

## Deployment (GitHub Pages — no Git installed, use the web UI)

**Production repo:** `https://github.com/portal-sudo/HKN-Portal` → `portal.hindikineev.org`
**Dev/staging repo:** `https://github.com/portal-sudo/HKN-Portal-New` → `portal-new.hindikineev.org`

There is no Git installed on this machine — updates are done entirely through
the GitHub website, no command line needed.

### To deploy an update
1. Make changes to `index.html` locally (test at `localhost:8080` or on
   `portal-new` first)
2. Go to the target repo on GitHub
3. Click **Add file → Upload files** and drag the updated file in — uploading
   with the same filename **overwrites** the old version automatically. No
   need to delete anything first, and the `CNAME` file (which controls the
   custom domain) is untouched as long as you don't upload a file named `CNAME`
4. Commit — GitHub Pages rebuilds within 1-2 minutes (check progress under
   the repo's **Actions** tab)

### DNS (Squarespace)
- `portal` → CNAME → `portal-sudo.github.io`
- `portal-new` → CNAME → `portal-sudo.github.io`
- Both repos have their own `CNAME` file internally, which is what actually
  determines which domain each repo serves — this is separate from the
  Squarespace DNS records above, and is why file-swapping between the two
  repos never requires touching DNS at all.

---

## Editing the Parent Guide

**File:** `HKN_Parent_Guide.html`, uploaded alongside `index.html` in the
production repo.

The file is organized in 7 sections. Each question/answer looks like this:

```html
<div class="question">What is Hindi Ki Neev?</div>
<div class="answer">
  Hindi Ki Neev (HKN) is a community Hindi language school...
</div>
```

**To edit text:** open in VS Code, search for the text you want to change,
edit the words between the tags, save. Do not change anything inside `< >` brackets.

After editing, upload the updated file to the production repo (see Deployment above).

---

## Editing the Scoring Guide

The scoring guide is stored in Supabase (not a file). To edit:

1. Sign into the portal as admin
2. Go to **School Attributes** → **Edit Scoring Guide** tab
3. Select a class level from the dropdown
4. Edit the content using the formatting toolbar
5. Click **Save level**

Changes are immediate — no deployment needed.

---

## Backup and Restore

### Manual backup (do this regularly and before any major changes)
1. Sign into portal as admin
2. Go to **Backup & Restore** in the left sidebar
3. Click **Download Backup**
4. Save the JSON file to a safe location (Google Drive recommended)

### Restore from backup
1. Sign into portal as admin
2. Go to **Backup & Restore**
3. Upload the JSON backup file
4. Click **Restore** and confirm

### What restore actually does — important to understand

Restore is a **true point-in-time snapshot**, not a merge. For `students`,
`sessions`, `teachers`, and `templates`, it deletes every existing row in
Supabase and replaces it with exactly what's in the JSON file.

**`settings` is the one exception** — it merges instead of replacing. Any
field present in the JSON overrides the current value, but any field the
JSON doesn't have keeps whatever is currently live in Supabase, rather than
reverting to a hardcoded default.

**Restoring an old JSON will remove teacher rows not in that file** — this
is expected and **safe**, since `rajiv@hindikineev.org` and
`portal@hindikineev.org` are protected separately in the `admins` table,
which restore can never touch.

**Not touched by restore, in either direction:** `scoring_guide`,
`book_inventory`, `book_replacements`, `book_teacher_copies`, `admins`. These
live in Supabase only, protected by daily snapshots, not by JSON backup/restore.

---

## Known Fixes (worth understanding, not just historical trivia)

### Parent portal showing the wrong session (fixed August 2026)
`get_public_data()` originally sorted sessions with `order by sess.year,
sess.term`. Since `term` is plain text, this only works correctly by
coincidence — two sessions sharing the same `year` value (e.g. Fall-2026
and Spring-2026, both `year = 2026`) get tie-broken alphabetically by term
name, and `'Fall'` sorts before `'Spring'` — putting the *earlier* Spring
session after the *later* Fall session in the list. The parent-facing
`getBestSession()` logic picks the *last* session a student has data for,
so this caused Active students to see Spring-2026 info instead of the
correct, current Fall-2026 info.

**Fixed by sorting on each session's actual earliest class date instead:**
```sql
order by (select min(d) from unnest(sess.class_dates) d)
```
This is robust regardless of how `year`/`term` happen to be labeled or
populated (two sessions, Winter-2026 and Spring-2027, even had `null`
term/year at the time this was found, and still sorted correctly under the
new approach).

### Supabase Site URL vs Redirect URLs (fixed August 2026)
Production login was found redirecting to `http://localhost:3000` — a
default Supabase creates for every new project. The cause: Site URL had
never been changed off that default, and `portal.hindikineev.org` was never
actually added to Redirect URLs (only assumed to have been). Both settings
are now correctly configured — see the "Supabase Auth URL Configuration"
section above for what each setting does and why both matter.

---

## Accounts In Use (reference only)

| Email | Used for |
|-------|----------|
| `rajiv@hindikineev.org` | Personal admin account; portal admin login |
| `portal@hindikineev.org` | Day-to-day portal admin; also owns the **GitHub** account (`portal-sudo`) used for deployment |
| `admin@hindikineev.org` | Google Workspace admin, Squarespace domain admin |

---

## Admin Accounts (in `admins` and/or `teachers` tables)

| Name | Email | Role |
|------|-------|------|
| Rajiv Mathur | rajiv@hindikineev.org | Admin (protected in `admins`) |
| HKN Portal | portal@hindikineev.org | Admin (protected in `admins`) |

---

## Key Contacts / Resources

- **Supabase support:** `https://supabase.com/support`
- **GitHub Pages docs:** `https://docs.github.com/en/pages`
- **School website:** `https://www.hindikineev.org`
- **School email:** `info@hindikineev.org`

---

## Post-Cutover Notes

- [x] Parallel deployment at `portal-new.hindikineev.org` tested and confirmed working
- [x] `admins` table verified to contain both rajiv@ and portal@
- [x] Cutover completed — `portal.hindikineev.org` running new Supabase-based system
- [x] Production login fully verified — both Site URL and Redirect URLs correctly configured
- [x] Parent portal session-selection bug found and fixed
- [ ] Old Drive/Apps Script backend — no urgency, retire whenever convenient
- [ ] Populate remaining scoring guide content (most levels still placeholder text)
- [ ] Decide long-term purpose of `portal-new` — currently kept as an ongoing
      dev/staging environment; consider a separate Supabase project for it if
      real testing there ever risks touching production data
