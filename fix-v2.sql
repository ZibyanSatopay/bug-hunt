-- ═══════════════════════════════════════════════════════
-- BUG HUNT v2 — Simple: No auth needed for participants
-- Run this in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════

-- Drop old view if exists
DROP VIEW IF EXISTS public.leaderboard;

-- Single table for all quiz submissions
CREATE TABLE IF NOT EXISTS public.submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_name TEXT NOT NULL,
  contact TEXT NOT NULL,
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

CREATE INDEX IF NOT EXISTS idx_submissions_contact ON public.submissions(contact);
CREATE INDEX IF NOT EXISTS idx_submissions_score ON public.submissions(total_score DESC);

ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;

-- Only admins can SELECT submissions
CREATE POLICY "Admins can read submissions"
  ON public.submissions FOR SELECT
  USING (public.is_admin());

-- RPC: Submit quiz — anyone can call, no auth needed
CREATE OR REPLACE FUNCTION public.submit_quiz(
  p_name TEXT,
  p_contact TEXT,
  p_language TEXT,
  p_total_score INT,
  p_accuracy_pts INT,
  p_time_bonus INT,
  p_correct_easy INT,
  p_correct_medium INT,
  p_correct_hard INT,
  p_total_correct INT,
  p_time_used INT,
  p_answers JSONB
) RETURNS JSON AS $$
DECLARE
  v_existing INT;
BEGIN
  -- Prevent duplicate submissions from same contact
  SELECT COUNT(*) INTO v_existing FROM public.submissions WHERE contact = p_contact;
  IF v_existing > 0 THEN
    RETURN json_build_object('success', false, 'error', 'Already submitted');
  END IF;

  INSERT INTO public.submissions (
    participant_name, contact, language, total_score, accuracy_pts, time_bonus,
    correct_easy, correct_medium, correct_hard, total_correct, time_used, answers
  ) VALUES (
    p_name, p_contact, p_language, p_total_score, p_accuracy_pts, p_time_bonus,
    p_correct_easy, p_correct_medium, p_correct_hard, p_total_correct, p_time_used, p_answers
  );

  RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Leaderboard view for admin panel
CREATE VIEW public.leaderboard AS
SELECT
  s.id AS score_id,
  s.participant_name AS full_name,
  s.contact,
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
FROM public.submissions s
ORDER BY s.total_score DESC, s.time_used ASC;
