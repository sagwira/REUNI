-- Check if pgcrypto extension is installed
SELECT extname, extversion
FROM pg_extension
WHERE extname = 'pgcrypto';

-- If no results, pgcrypto is not installed
