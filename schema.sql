-- ═══════════════════════════════════════════════════════
-- BUG HUNT — Supabase Schema
-- Run this in your Supabase SQL Editor (supabase.com/dashboard)
-- ═══════════════════════════════════════════════════════

-- 1. PROFILES TABLE (extends auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  roll_number TEXT,
  is_admin BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. LOGIN CODES TABLE
CREATE TABLE IF NOT EXISTS public.login_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL DEFAULT '',
  used_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_login_codes_code ON public.login_codes(code);
CREATE INDEX IF NOT EXISTS idx_login_codes_used_by ON public.login_codes(used_by);

-- 3. SCORES TABLE
CREATE TABLE IF NOT EXISTS public.scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  language TEXT NOT NULL DEFAULT 'C',
  total_score INT NOT NULL DEFAULT 0,
  accuracy_pts INT NOT NULL DEFAULT 0,
  time_bonus INT NOT NULL DEFAULT 0,
  correct_easy INT NOT NULL DEFAULT 0,
  correct_medium INT NOT NULL DEFAULT 0,
  correct_hard INT NOT NULL DEFAULT 0,
  total_correct INT NOT NULL DEFAULT 0,
  time_used INT NOT NULL DEFAULT 0,
  answers JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scores_user_id ON public.scores(user_id);
CREATE INDEX IF NOT EXISTS idx_scores_total_score ON public.scores(total_score DESC);

-- ═══════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scores ENABLE ROW LEVEL SECURITY;

-- Helper: check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()),
    FALSE
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ── PROFILES POLICIES ──
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
  ON public.profiles FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Service role can insert profiles"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- ── LOGIN CODES POLICIES ──
-- Allow anon (not-yet-logged-in) users to check codes during login flow
CREATE POLICY "Anyone can read codes for validation"
  ON public.login_codes FOR SELECT
  USING (true);

CREATE POLICY "Admins can insert codes"
  ON public.login_codes FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "Users can claim a code"
  ON public.login_codes FOR UPDATE
  USING (used_by IS NULL OR used_by = auth.uid())
  WITH CHECK (used_by = auth.uid());

CREATE POLICY "Admins can manage codes"
  ON public.login_codes FOR ALL
  USING (public.is_admin());

-- ── SCORES POLICIES ──
CREATE POLICY "Users can insert own scores"
  ON public.scores FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own scores"
  ON public.scores FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all scores"
  ON public.scores FOR SELECT
  USING (public.is_admin());

-- ═══════════════════════════════════════════════════════
-- AUTO-CREATE PROFILE ON SIGNUP (trigger)
-- ═══════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, roll_number)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'roll_number', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ═══════════════════════════════════════════════════════
-- HELPER: Generate N random login codes
-- Usage: SELECT * FROM generate_codes(50, 'Event Day 1');
-- ═══════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.generate_codes(p_count INT, code_label TEXT DEFAULT '')
RETURNS SETOF public.login_codes AS $$
DECLARE
  rec public.login_codes%ROWTYPE;
  new_code TEXT;
BEGIN
  FOR i IN 1..p_count LOOP
    new_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
    INSERT INTO public.login_codes (code, label)
    VALUES (new_code, code_label)
    RETURNING * INTO rec;
    RETURN NEXT rec;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════
-- ADMIN VIEW: Leaderboard with names
-- ═══════════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.leaderboard AS
SELECT
  s.id AS score_id,
  s.user_id,
  p.full_name,
  p.roll_number,
  s.language,
  s.total_score,
  s.accuracy_pts,
  s.time_bonus,
  s.correct_easy,
  s.correct_medium,
  s.correct_hard,
  s.total_correct,
  s.time_used,
  s.answers,
  s.created_at,
  RANK() OVER (ORDER BY s.total_score DESC, s.time_used ASC) AS rank
FROM public.scores s
JOIN public.profiles p ON p.id = s.user_id
ORDER BY s.total_score DESC, s.time_used ASC;

-- ═══════════════════════════════════════════════════════
-- FIRST-TIME SETUP:
-- After running this SQL, create your admin account:
-- 1. Sign up via the quiz app or Supabase Auth dashboard
-- 2. Then run:
--    UPDATE public.profiles SET is_admin = true WHERE id = 'YOUR-USER-UUID';
-- ═══════════════════════════════════════════════════════
