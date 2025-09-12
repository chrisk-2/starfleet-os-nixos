#!/bin/bash

# Commit script for Borg Collective implementation
# This script commits all Borg Collective files to the repository

set -e

echo "=== Borg Collective Commit Script ==="
echo "Committing Borg Collective implementation to the repository"
echo "Resistance is futile."
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
  echo "Error: git is not installed. Please install git and try again."
  exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
  echo "Error: Not in a git repository. Please run this script from the Starfleet OS root directory."
  exit 1
fi

# Check if we're in the right directory
if [ ! -f "flake.nix" ]; then
  echo "Error: flake.nix not found. Please run this script from the Starfleet OS root directory."
  exit 1
fi

# Create a new branch for the Borg Collective implementation
BRANCH_NAME="borg-collective-implementation"
echo "Creating branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

# Add all Borg Collective files
echo "Adding Borg Collective files to the repository"

# Add modules
git add modules/borg/collective-manager.nix
git add modules/borg/assimilation-system.nix
git add modules/borg/adaptation-system.nix
git add modules/borg/collective-database.nix

# Add packages
git add pkgs/borg-collective-manager/default.nix
git add pkgs/borg-assimilation-system/default.nix

# Add configurations
git add configurations/borg-queen.nix
git add configurations/borg-drone.nix

# Add documentation
git add BORG_COLLECTIVE_IMPLEMENTATION_PLAN.md
git add BORG_COLLECTIVE_SUMMARY.md
git add BORG_COLLECTIVE_QUICKSTART.md

# Add scripts
git add build-borg-collective.sh
git add commit-borg-collective.sh

# Commit the changes
echo "Committing changes"
git commit -m "Add Borg Collective implementation for Starfleet OS"

# Push the changes
echo "Would you like to push the changes to the remote repository? (y/n)"
read -r PUSH_CHANGES

if [ "$PUSH_CHANGES" = "y" ] || [ "$PUSH_CHANGES" = "Y" ]; then
  echo "Pushing changes to remote repository"
  git push -u origin "$BRANCH_NAME"
  echo "Changes pushed successfully!"
  echo "Create a pull request to merge the Borg Collective implementation into the main branch."
else
  echo "Changes committed but not pushed."
  echo "To push the changes later, run: git push -u origin $BRANCH_NAME"
fi

echo ""
echo "Borg Collective implementation committed successfully."
echo "The Collective awaits. Resistance is futile."