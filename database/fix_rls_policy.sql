-- Fix RLS policy for user_tickets to handle TEXT user_id column
-- The issue: user_id is TEXT but auth.uid() returns UUID
-- The fix: Cast user_id to UUID when comparing

-- First, drop existing policies (we'll recreate them correctly)
DROP POLICY IF EXISTS "Users can view their own tickets" ON user_tickets;
DROP POLICY IF EXISTS "Users can insert their own tickets" ON user_tickets;
DROP POLICY IF EXISTS "Users can update their own tickets" ON user_tickets;
DROP POLICY IF EXISTS "Users can delete their own tickets" ON user_tickets;

-- Recreate policies with proper type casting
-- SELECT policy: Users can see tickets they own OR tickets they purchased
CREATE POLICY "Users can view their own tickets" ON user_tickets
FOR SELECT
USING (
    user_id::uuid = auth.uid()  -- Cast TEXT user_id to UUID for comparison
);

-- INSERT policy: Users can only insert tickets for themselves
CREATE POLICY "Users can insert their own tickets" ON user_tickets
FOR INSERT
WITH CHECK (
    user_id::uuid = auth.uid()
);

-- UPDATE policy: Users can only update their own tickets
CREATE POLICY "Users can update their own tickets" ON user_tickets
FOR UPDATE
USING (
    user_id::uuid = auth.uid()
)
WITH CHECK (
    user_id::uuid = auth.uid()
);

-- DELETE policy: Users can only delete their own tickets (and not sold ones)
CREATE POLICY "Users can delete their own tickets" ON user_tickets
FOR DELETE
USING (
    user_id::uuid = auth.uid()
    AND (sale_status IS NULL OR sale_status != 'sold')
);

-- Verify policies
SELECT
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'user_tickets';
