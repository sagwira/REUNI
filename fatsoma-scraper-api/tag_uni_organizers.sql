-- Add a column to track university-focused organizers
ALTER TABLE public.organizers
ADD COLUMN IF NOT EXISTS is_university_focused BOOLEAN DEFAULT FALSE;

-- Add a column for tags/categories
ALTER TABLE public.organizers
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- Tag Nottingham university club organizers
UPDATE public.organizers
SET
    is_university_focused = TRUE,
    tags = ARRAY['university', 'nightlife', 'nottingham']
WHERE name IN (
    'Stealth',
    'NG-ONE',
    'The Palais',
    'Ghost Nottingham',
    'The Mixologist',
    'Unit 13',
    'The Cell',
    'Campus Nottingham Events',
    'Rock City',
    'Outwork Events',
    'INK',
    'INK Nottingham'
);

-- Create an index for faster filtering
CREATE INDEX IF NOT EXISTS idx_organizers_uni_focused
ON public.organizers(is_university_focused)
WHERE is_university_focused = TRUE;

-- View results
SELECT name, location, is_university_focused, tags
FROM public.organizers
WHERE is_university_focused = TRUE
ORDER BY name;
