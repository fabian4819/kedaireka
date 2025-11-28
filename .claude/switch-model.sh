#!/bin/bash

# Switch between GLM and Claude models in Claude Code configuration
# Usage: ./switch-model.sh [claude|glm]

set -e

SETTINGS_FILE="$HOME/.claude/settings.json"

if [ $# -eq 0 ]; then
    echo "Usage: $0 [claude|glm]"
    echo "  claude - Use actual Claude models"
    echo "  glm    - Use GLM models"
    exit 1
fi

MODEL_FAMILY="$1"

case $MODEL_FAMILY in
    "claude")
        HAIKU_MODEL="claude-3-5-haiku-20241022"
        SONNET_MODEL="claude-3-5-sonnet-20241022"
        OPUS_MODEL="claude-3-opus-20240229"
        echo "Switching to Claude models..."
        ;;
    "glm")
        HAIKU_MODEL="GLM-4.5-Air"
        SONNET_MODEL="GLM-4.6"
        OPUS_MODEL="GLM-4.6"
        echo "Switching to GLM models..."
        ;;
    *)
        echo "Error: Invalid model family '$MODEL_FAMILY'"
        echo "Use 'claude' or 'glm'"
        exit 1
        ;;
esac

# Backup current settings
cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"

# Update the models using sed
sed -i '' "s/\"ANTHROPIC_DEFAULT_HAIKU_MODEL\": \".*\"/\"ANTHROPIC_DEFAULT_HAIKU_MODEL\": \"$HAIKU_MODEL\"/" "$SETTINGS_FILE"
sed -i '' "s/\"ANTHROPIC_DEFAULT_SONNET_MODEL\": \".*\"/\"ANTHROPIC_DEFAULT_SONNET_MODEL\": \"$SONNET_MODEL\"/" "$SETTINGS_FILE"
sed -i '' "s/\"ANTHROPIC_DEFAULT_OPUS_MODEL\": \".*\"/\"ANTHROPIC_DEFAULT_OPUS_MODEL\": \"$OPUS_MODEL\"/" "$SETTINGS_FILE"

echo "✅ Updated model configuration:"
echo "  Haiku:  $HAIKU_MODEL"
echo "  Sonnet: $SONNET_MODEL"
echo "  Opus:   $OPUS_MODEL"
echo ""
echo "Restart Claude Code to apply changes."