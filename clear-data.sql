-- Run this in Supabase SQL Editor to add the "Clear All" function
CREATE OR REPLACE FUNCTION public.clear_all_submissions()
RETURNS JSON AS $$
BEGIN
  DELETE FROM public.submissions;
  RETURN json_build_object('success', true, 'message', 'All submissions deleted');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
