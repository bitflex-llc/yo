#!/bin/sh

# Emergency Git Conflict Fix - One Command Solution
# Run this on the remote server to quickly resolve the merge conflict

echo "🚨 EMERGENCY GIT CONFLICT FIX"
echo "=============================="

# Check if we're in the right directory
if [ ! -f "force_install_official_explorer.sh" ]; then
    echo "❌ force_install_official_explorer.sh not found"
    echo "💡 Make sure you're in the correct directory"
    exit 1
fi

echo "📍 Current location: $(pwd)"
echo "📋 Git status:"
git status --porcelain

# Backup the current file
echo ""
echo "💾 Creating backup..."
cp force_install_official_explorer.sh force_install_official_explorer.sh.$(date +%Y%m%d_%H%M%S).backup

# Add and commit current changes
echo ""
echo "✅ Committing current changes..."
git add force_install_official_explorer.sh
git commit -m "Update explorer: port 3011, apps/explorer directory, remove fallbacks - $(date)"

# Try to pull
echo ""
echo "📥 Pulling latest changes..."
if git pull; then
    echo "✅ SUCCESS! Git conflict resolved"
else
    echo "⚠️  Pull failed, trying alternative method..."
    
    # Alternative: fetch and merge
    git fetch origin
    if git merge origin/main; then
        echo "✅ SUCCESS! Merge completed"
    else
        echo "❌ Manual intervention required"
        echo ""
        echo "🔧 MANUAL STEPS:"
        echo "1. Edit force_install_official_explorer.sh"
        echo "2. Remove conflict markers (<<<<<<< ======= >>>>>>>)"
        echo "3. Run: git add force_install_official_explorer.sh"
        echo "4. Run: git commit -m 'Resolve merge conflict'"
        
        # Show conflict markers if they exist
        if grep -q "<<<<<<< HEAD" force_install_official_explorer.sh 2>/dev/null; then
            echo ""
            echo "🔍 Found conflict markers:"
            grep -n "<<<<<<< HEAD\|=======\|>>>>>>> " force_install_official_explorer.sh
        fi
        
        exit 1
    fi
fi

echo ""
echo "🎉 GIT CONFLICT RESOLVED!"
echo "========================="
echo "✅ Changes committed and merged"
echo "✅ Explorer script updated"
echo "✅ Ready to deploy"
echo ""
echo "🚀 NEXT STEPS:"
echo "sudo ./force_install_official_explorer.sh"
