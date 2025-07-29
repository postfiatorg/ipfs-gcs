#!/bin/bash
set -e

# Setup Branch Protection for main branch
# Requires GitHub CLI: https://cli.github.com/

echo "🔒 Setting up branch protection for main branch..."

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI not found. Please install it first:"
    echo "   brew install gh        # macOS"
    echo "   apt install gh         # Ubuntu"
    echo "   Or visit: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "🔑 Please authenticate with GitHub first:"
    gh auth login
fi

# Get repository info
REPO=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')
echo "📁 Repository: $REPO"

# Set up branch protection
echo "🔒 Applying branch protection rules..."

gh api "repos/$REPO/branches/main/protection" \
  --method PUT \
  --input - << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["test"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "restrict_reviews_to_code_owners": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "required_linear_history": true
}
EOF

echo "✅ Branch protection configured successfully!"
echo ""
echo "📋 Protection rules applied:"
echo "   • Require PR before merging"
echo "   • Require 1 approval"
echo "   • Require status checks (CI must pass)"
echo "   • Require code owner reviews"
echo "   • Dismiss stale reviews"
echo "   • Require conversation resolution"
echo "   • Require linear history"
echo "   • Block force pushes and deletions"
echo "   • Apply to administrators"
echo ""
echo "🎉 Main branch is now protected!"
echo "   All changes must go through pull requests with review and passing CI."