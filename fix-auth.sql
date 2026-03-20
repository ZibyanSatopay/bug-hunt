-- ═══════════════════════════════════════════════════════
-- FIX: Remove auth requirement for participants
-- Run this in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════

-- 1. Add participant info directly to login_codes
ALTER TABLE public.login_codes
  ADD COLUMN IF NOT EXISTS participant_name TEXT,
  ADD COLUMN IF NOT EXISTS participant_roll TEXT;

-- 2. Make scores.user_id nullable (participants won't have auth users)
ALTER TABLE public.scores
  ALTER COLUMN user_id DROP NOT NULL;

-- 3. Add code_id to scores to link participant scores to their code
ALTER TABLE public.scores
  ADD COLUMN IF NOT EXISTS code_id UUID REFERENCES public.login_codes(id);

-- 4. RPC: Claim a code (no auth needed, runs as superuser)
CREATE OR REPLACE FUNCTION public.claim_code(
  p_code TEXT,
  p_name TEXT,
  p_roll TEXT
) RETURNS JSON AS $$
DECLARE
  v_row public.login_codes%ROWTYPE;
BEGIN
  -- Find unused code
  SELECT * INTO v_row
  FROM public.login_codes
  WHERE code = upper(p_code) AND used_at IS NULL
  LIMIT 1;

  IF v_row.id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid or already-used code');
  END IF;

  -- Mark as used
  UPDATE public.login_codes
  SET used_at = NOW(),
      participant_name = p_name,
      participant_roll = p_roll
  WHERE id = v_row.id;

  RETURN json_build_object(
    'success', true,
    'code_id', v_row.id,
    'code', v_row.code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC: Submit score (no auth needed)
CREATE OR REPLACE FUNCTION public.submit_score(
  p_code_id UUID,
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
  v_code public.login_codes%ROWTYPE;
  v_existing INT;
BEGIN
  -- Verify code exists and was claimed
  SELECT * INTO v_code FROM public.login_codes WHERE id = p_code_id;
  IF v_code.id IS NULL OR v_code.used_at IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid code');
  END IF;

  -- Check if score already submitted for this code
  SELECT COUNT(*) INTO v_existing FROM public.scores WHERE code_id = p_code_id;
  IF v_existing > 0 THEN
    RETURN json_build_object('success', false, 'error', 'Score already submitted');
  END IF;

  -- Insert score
  INSERT INTO public.scores (
    user_id, code_id, language, total_score, accuracy_pts, time_bonus,
    correct_easy, correct_medium, correct_hard, total_correct, time_used, answers
  ) VALUES (
    NULL, p_code_id, p_language, p_total_score, p_accuracy_pts, p_time_bonus,
    p_correct_easy, p_correct_medium, p_correct_hard, p_total_correct, p_time_used, p_answers
  );

  RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Update leaderboard view to include code-based participants
DROP VIEW IF EXISTS public.leaderboard;
CREATE VIEW public.leaderboard AS
SELECT
  s.id AS score_id,
  s.user_id,
  s.code_id,
  COALESCE(p.full_name, lc.participant_name, 'Unknown') AS full_name,
  COALESCE(p.roll_number, lc.participant_roll, '') AS roll_number,
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
LEFT JOIN public.profiles p ON p.id = s.user_id
LEFT JOIN public.login_codes lc ON lc.id = s.code_id
ORDER BY s.total_score DESC, s.time_used ASC;

-- Done! No auth needed for participants now.
