#!/bin/bash
# Run migration to remove pending payment states

echo "=========================================="
echo "Running migration: Remove pending states"
echo "=========================================="
echo ""

# Execute SQL migration
supabase db remote query --file database/remove_pending_payment_states.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Migration completed successfully!"
else
    echo ""
    echo "❌ Migration failed. Check errors above."
    exit 1
fi
