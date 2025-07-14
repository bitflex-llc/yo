#!/bin/sh

# Git Conflict Resolution Script for Sui Explorer
# This script helps resolve git merge conflicts on the remote server

echo "🔧 Git Conflict Resolution - Sui Explorer"
echo "========================================="

echo ""
echo "📍 Current Git Status:"
git status

echo ""
echo "🔍 Checking for conflicted files..."
CONFLICTED_FILES=$(git diff --name-only --diff-filter=U 2>/dev/null || true)

if [ -n "$CONFLICTED_FILES" ]; then
    echo "❌ Found conflicted files:"
    echo "$CONFLICTED_FILES"
else
    echo "✅ No merge conflicts detected"
fi

echo ""
echo "🔧 RESOLUTION OPTIONS:"
echo "======================="
echo ""
echo "1. 💾 COMMIT CURRENT CHANGES (Recommended)"
echo "   git add ."
echo "   git commit -m 'Update explorer to use apps/explorer directory and port 3011'"
echo "   git pull"
echo ""
echo "2. 📦 STASH CHANGES TEMPORARILY"
echo "   git stash push -m 'Explorer updates for port 3011'"
echo "   git pull"
echo "   git stash pop"
echo ""
echo "3. 🔄 RESET TO REMOTE (DANGER: Loses local changes)"
echo "   git fetch origin"
echo "   git reset --hard origin/main"
echo ""
echo "4. 🔍 VIEW DIFFERENCES"
echo "   git diff HEAD"
echo ""

echo "🤖 AUTOMATED FIX OPTIONS:"
echo "========================="
echo ""

read -p "Choose an option (1-4) or 'auto' for automated fix: " choice

case "$choice" in
    "1")
        echo "💾 Committing current changes..."
        git add .
        git commit -m "Update Sui Explorer: use apps/explorer directory, port 3011, remove fallbacks"
        
        echo "📥 Pulling latest changes..."
        if git pull; then
            echo "✅ Successfully merged changes"
        else
            echo "❌ Merge conflicts detected. Manual resolution needed."
            echo "Edit conflicted files and run: git add . && git commit"
        fi
        ;;
    "2")
        echo "📦 Stashing current changes..."
        git stash push -m "Explorer updates for port 3011 - $(date)"
        
        echo "📥 Pulling latest changes..."
        git pull
        
        echo "📤 Restoring stashed changes..."
        if git stash pop; then
            echo "✅ Successfully restored changes"
        else
            echo "❌ Stash conflicts detected. Manual resolution needed."
            echo "Resolve conflicts and run: git add . && git commit"
        fi
        ;;
    "3")
        read -p "⚠️  This will LOSE all local changes. Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            echo "🔄 Resetting to remote state..."
            git fetch origin
            git reset --hard origin/main
            echo "✅ Reset complete. All local changes lost."
        else
            echo "❌ Reset cancelled"
        fi
        ;;
    "4")
        echo "🔍 Showing differences..."
        git diff HEAD
        ;;
    "auto")
        echo "🤖 Running automated fix..."
        
        # Check if we're in a merge state
        if [ -d ".git/MERGE_HEAD" ]; then
            echo "🔧 Merge in progress, aborting first..."
            git merge --abort
        fi
        
        # Backup current state
        echo "💾 Creating backup..."
        cp force_install_official_explorer.sh force_install_official_explorer.sh.backup 2>/dev/null || true
        
        # Stash changes
        echo "📦 Stashing changes..."
        git stash push -m "Auto-backup: Explorer port 3011 updates - $(date)"
        
        # Pull latest
        echo "📥 Pulling latest changes..."
        git pull
        
        # Restore our changes
        echo "📤 Restoring our changes..."
        if git stash pop; then
            echo "✅ Auto-fix successful"
        else
            echo "⚠️  Conflicts detected, but backup created"
            echo "Your changes are backed up in:"
            echo "- Git stash: git stash list"
            echo "- File backup: force_install_official_explorer.sh.backup"
        fi
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo ""
echo "📋 FINAL STATUS:"
echo "================"
git status

echo ""
echo "💡 NEXT STEPS:"
echo "=============="
echo "1. If conflicts remain, edit the files manually"
echo "2. Run: git add . && git commit -m 'Resolve merge conflicts'"
echo "3. Test the explorer: sudo ./force_install_official_explorer.sh"
echo ""
echo "🆘 EMERGENCY COMMANDS:"
echo "====================="
echo "View current stashes: git stash list"
echo "Restore backup file: cp force_install_official_explorer.sh.backup force_install_official_explorer.sh"
echo "View conflict markers: grep -n '<<<<<<< HEAD' force_install_official_explorer.sh"
