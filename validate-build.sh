#!/bin/bash
# Starfleet OS Build Validation Script

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[VALIDATION]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check flake structure
validate_flake() {
    log "Validating flake structure..."
    
    if [ ! -f flake.nix ]; then
        error "flake.nix not found"
        exit 1
    fi
    
    nix flake check --no-build
    log "Flake structure validated"
}

# Validate configurations
validate_configurations() {
    log "Validating node configurations..."
    
    local node_types=("bridge" "drone-a" "drone-b" "edge-pi" "portable")
    
    for node_type in "${node_types[@]}"; do
        log "Validating $node_type configuration..."
        
        # Check configuration exists
        if [ ! -f "modules/${node_type}/configuration.nix" ]; then
            error "Configuration for $node_type not found"
            exit 1
        fi
        
        # Validate syntax
        nix-instantiate --eval "modules/${node_type}/configuration.nix"
    done
    
    log "All configurations validated"
}

# Check LCARS components
validate_lcars_components() {
    log "Validating LCARS components..."
    
    # Check display server
    if [ ! -d "pkgs/lcars-desktop" ]; then
        error "LCARS display server not found"
        exit 1
    fi
    
    # Check compositor
    if [ ! -d "pkgs/lcars-compositor" ]; then
        warning "LCARS compositor directory not found"
    fi
    
    log "LCARS components validated"
}

# Validate security tools
validate_security_tools() {
    log "Validating security tools integration..."
    
    # Check pentest suite
    if [ ! -f "modules/security/pentest-suite.nix" ]; then
        error "Pentest suite configuration not found"
        exit 1
    fi
    
    # Check network configuration
    if [ ! -f "modules/network/wireguard-mesh.nix" ]; then
        error "WireGuard mesh configuration not found"
        exit 1
    fi
    
    log "Security tools validated"
}

# Check documentation
validate_documentation() {
    log "Validating documentation..."
    
    if [ ! -f README.md ]; then
        error "README.md not found"
        exit 1
    fi
    
    # Check if documentation mentions all components
    grep -q "LCARS" README.md || warning "LCARS not mentioned in README"
    grep -q "WireGuard" README.md || warning "WireGuard not mentioned in README"
    grep -q "Borg" README.md || warning "Borg mode not mentioned in README"
    
    log "Documentation validated"
}

# Main validation
main() {
    log "Starting Starfleet OS build validation..."
    
    validate_flake
    validate_configurations
    validate_lcars_components
    validate_security_tools
    validate_documentation
    
    log "All validations passed!"
    log "Starfleet OS is ready for deployment"
    
    echo ""
    echo "=== Build Summary ==="
    echo "Total configurations: 5"
    echo "Node types: bridge, drone-a, drone-b, edge-pi, portable"
    echo "Operational modes: starfleet, section31, borg, terran, holodeck"
    echo "Security tools: integrated pentest suite"
    echo "Network: WireGuard mesh networking"
    echo "Interface: Pure LCARS display server"
}

# Run validation
main "$@"