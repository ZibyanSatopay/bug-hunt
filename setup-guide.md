# BUG HUNT — Setup Guide

## Quick Setup (15 minutes)

### Step 1: Create Supabase Project
1. Go to [supabase.com](https://supabase.com) and sign up (free)
2. Click **New Project**
3. Name it `bughunt`, set a database password, choose nearest region
4. Wait for project to provision (~2 minutes)

### Step 2: Run Database Schema
1. In your Supabase dashboard, go to **SQL Editor** (left sidebar)
2. Click **New Query**
3. Paste the entire contents of `schema.sql`
4. Click **Run** (or Ctrl+Enter)
5. You should see "Success" — all tables, policies, and triggers are created

### Step 3: Get Your API Keys
1. Go to **Settings → API** in Supabase dashboard
2. Copy:
   - **Project URL** (looks like `https://abcdefgh.supabase.co`)
   - **anon public** key (long string starting with `eyJ...`)

### Step 4: Configure the HTML Files
Open **both** `index.html` and `admin.html` and replace:
```javascript
const SUPABASE_URL  = 'https://YOUR_PROJECT.supabase.co';
const SUPABASE_ANON = 'YOUR_ANON_KEY';
```
with your actual values from Step 3.

### Step 5: Create Your Admin Account
1. Open `index.html` in a browser
2. Register with your admin email and password
3. Go to Supabase dashboard → **SQL Editor**
4. Run this query (replace the email with yours):
```sql
UPDATE public.profiles
SET is_admin = true
WHERE id = (
  SELECT id FROM auth.users WHERE email = 'your-admin@email.com'
);
```
5. Now open `admin.html` and sign in — you'll see the admin panel

### Step 6: Disable Email Confirmation (Recommended for Events)
1. Go to **Authentication → Providers → Email** in Supabase
2. Toggle OFF **"Confirm email"**
3. This lets participants register and start immediately without email verification

---

## Event Day Workflow

### Before the Event
1. Open `admin.html` → go to **Event Codes** tab
2. Generate codes (e.g., 50 codes labeled "Round 1")
3. Print or distribute codes to participants

### During the Event
Participants can login two ways:
- **Email + Password**: Self-register with name, email, roll number, password
- **Event Code**: Enter their unique 8-character code + their name

### Monitoring
- Keep `admin.html` open on your laptop
- Click **Refresh** to see new submissions in real-time
- Leaderboard is auto-ranked by total score (accuracy + speed bonus)
- Click any row to see their full answer sheet

### After the Event
- Click **Export CSV** to download the full leaderboard
- Share results as needed

---

## Scoring System

| Component | Calculation | Max Points |
|-----------|------------|------------|
| Easy (10 Q) | 10 pts per correct answer | 100 |
| Medium (10 Q) | 20 pts per correct answer | 200 |
| Hard (10 Q) | 30 pts per correct answer | 300 |
| Speed Bonus | (time_remaining / 1200) × 400 | 400 |
| **Total** | | **1000** |

---

## File Structure
```
BugHunt/
├── index.html      ← Participant quiz (single HTML file)
├── admin.html      ← Admin panel (single HTML file)
├── schema.sql      ← Database schema (run once in Supabase)
└── setup-guide.md  ← This file
```

## Troubleshooting

**"Backend not configured"** — You forgot to replace `YOUR_PROJECT` and `YOUR_ANON_KEY` in the HTML files.

**"Not an admin account"** — Run the SQL in Step 5 to make your account an admin.

**"Invalid or already-used code"** — The code was already claimed by someone. Generate new codes.

**Scores not appearing** — Check that RLS policies were created (Step 2). Check browser console for errors.

**Offline mode** — If Supabase is unreachable, the quiz still works locally but scores won't be saved to the server.
