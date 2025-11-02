"""
Add university columns to organizers table
Run this ONCE in Supabase SQL Editor
"""

sql = """
-- Add university-focused columns to organizers table
ALTER TABLE public.organizers
ADD COLUMN IF NOT EXISTS is_university_focused BOOLEAN DEFAULT FALSE;

ALTER TABLE public.organizers
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- Create index for faster filtering
CREATE INDEX IF NOT EXISTS idx_organizers_uni_focused
ON public.organizers(is_university_focused)
WHERE is_university_focused = TRUE;

-- Show columns to verify
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'organizers'
AND column_name IN ('is_university_focused', 'tags');
"""

print("=" * 70)
print("COPY THIS SQL AND RUN IN SUPABASE SQL EDITOR")
print("=" * 70)
print("\n1. Go to: https://supabase.com/dashboard")
print("2. Select your project")
print("3. Click 'SQL Editor' in the left sidebar")
print("4. Click 'New query'")
print("5. Paste the SQL below")
print("6. Click 'Run' or press Cmd/Ctrl + Enter")
print("\n" + "=" * 70)
print(sql)
print("=" * 70)
