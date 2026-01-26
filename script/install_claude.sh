#!/bin/bash

######################################################
##                                                  ##
##          Claude Code Installation Script        ##
##          Based on everything-claude-code         ##
##                                                  ##
######################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Claude is installed
check_claude_installed() {
    if ! command -v claude &> /dev/null; then
        print_error "Claude Code is not installed!"
        print_info "Please install Claude Code first from: https://claude.ai/download"
        exit 1
    fi
    print_success "Claude Code is installed"
}

# Create necessary directories
create_directories() {
    print_info "Creating Claude configuration directories..."
    
    mkdir -p ~/.claude/agents
    mkdir -p ~/.claude/rules
    mkdir -p ~/.claude/commands
    mkdir -p ~/.claude/skills
    
    print_success "Directories created"
}

# Clone or update everything-claude-code repository
setup_repository() {
    local repo_dir="$HOME/.claude/everything-claude-code"
    
    if [ -d "$repo_dir" ]; then
        print_info "Repository already exists, updating..."
        cd "$repo_dir"
        git pull
    else
        print_info "Cloning everything-claude-code repository..."
        git clone https://github.com/affaan-m/everything-claude-code.git "$repo_dir"
    fi
    
    print_success "Repository ready at $repo_dir"
}

# Install as plugin (Option 1 - Recommended)
install_as_plugin() {
    print_info "Installing everything-claude-code as plugin..."
    
    local settings_file="$HOME/.claude/settings.json"
    
    # Create settings.json if it doesn't exist
    if [ ! -f "$settings_file" ]; then
        echo '{}' > "$settings_file"
    fi
    
    # Backup existing settings
    cp "$settings_file" "$settings_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create the plugin configuration
    cat > "$settings_file" <<'EOF'
{
  "extraKnownMarketplaces": {
    "everything-claude-code": {
      "source": {
        "source": "github",
        "repo": "affaan-m/everything-claude-code"
      }
    }
  },
  "enabledPlugins": {
    "everything-claude-code@everything-claude-code": true
  }
}
EOF
    
    print_success "Plugin configuration added to settings.json"
}

# Manual installation (Option 2)
install_manually() {
    local repo_dir="$HOME/.claude/everything-claude-code"
    
    print_info "Installing components manually..."
    
    # Copy agents
    if [ -d "$repo_dir/agents" ]; then
        cp -r "$repo_dir/agents/"* ~/.claude/agents/ 2>/dev/null || true
        print_success "Agents installed"
    fi
    
    # Copy rules
    if [ -d "$repo_dir/rules" ]; then
        cp -r "$repo_dir/rules/"* ~/.claude/rules/ 2>/dev/null || true
        print_success "Rules installed"
    fi
    
    # Copy commands
    if [ -d "$repo_dir/commands" ]; then
        cp -r "$repo_dir/commands/"* ~/.claude/commands/ 2>/dev/null || true
        print_success "Commands installed"
    fi
    
    # Copy skills
    if [ -d "$repo_dir/skills" ]; then
        cp -r "$repo_dir/skills/"* ~/.claude/skills/ 2>/dev/null || true
        print_success "Skills installed"
    fi
    
    # Handle hooks
    if [ -f "$repo_dir/hooks/hooks.json" ]; then
        print_warning "Hooks need to be manually merged into ~/.claude/settings.json"
        print_info "Hooks file location: $repo_dir/hooks/hooks.json"
    fi
    
    # Handle MCP configs
    if [ -f "$repo_dir/mcp-configs/mcp-servers.json" ]; then
        print_warning "MCP configs need to be manually merged into ~/.claude.json"
        print_info "MCP configs location: $repo_dir/mcp-configs/mcp-servers.json"
        print_warning "Remember to replace YOUR_*_HERE placeholders with actual API keys!"
    fi
}

# Main installation flow
main() {
    echo ""
    echo "╔════════════════════════════════════════════════╗"
    echo "║   Claude Code Configuration Installation       ║"
    echo "║   Based on: everything-claude-code             ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    
    # Check prerequisites
    check_claude_installed
    
    # Create directories
    create_directories
    
    # Setup repository
    setup_repository
    
    # Ask user for installation method
    echo ""
    print_info "Choose installation method:"
    echo "  1) Plugin installation (Recommended - easier updates)"
    echo "  2) Manual installation (More control)"
    echo ""
    read -p "Enter choice [1-2]: " choice
    
    case $choice in
        1)
            install_as_plugin
            ;;
        2)
            install_manually
            ;;
        *)
            print_error "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    
    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Restart Claude Code to load the new configuration"
    echo "  2. If you chose manual installation, review hooks and MCP configs"
    echo "  3. Configure any API keys in ~/.claude.json if using MCPs"
    echo ""
    print_info "Repository location: ~/.claude/everything-claude-code"
    print_info "Documentation: https://github.com/affaan-m/everything-claude-code"
    echo ""
}

# Run main function
main
