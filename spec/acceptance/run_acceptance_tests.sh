#!/bin/bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Bard Acceptance Tests ===${NC}\n"

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo -e "${RED}Error: podman is not installed${NC}"
    echo "Install with: sudo apt install podman (Ubuntu/Debian)"
    exit 1
fi

echo -e "${GREEN}✓ Podman installed:${NC} $(podman --version)"

# Check if we can pull images
echo -en "${YELLOW}Checking network access to registries...${NC} "
if podman pull ubuntu:22.04 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}Cannot pull images from registry. Tests will be skipped.${NC}"
    echo "This is expected in restricted network environments."
    echo ""
fi

# Check SSH keys exist
if [[ ! -f spec/acceptance/docker/test_key ]]; then
    echo -e "${YELLOW}Generating SSH test keys...${NC}"
    ssh-keygen -t rsa -b 2048 -f spec/acceptance/docker/test_key -N '' -C 'bard-test-key'
    chmod 600 spec/acceptance/docker/test_key
    chmod 644 spec/acceptance/docker/test_key.pub
    echo -e "${GREEN}✓ SSH keys generated${NC}"
else
    echo -e "${GREEN}✓ SSH keys exist${NC}"
fi

echo ""
echo -e "${GREEN}Running acceptance tests...${NC}"
echo ""

# Find rspec (check various locations)
RSPEC_CMD=""
if command -v rspec &> /dev/null; then
    RSPEC_CMD="rspec"
elif command -v bundle &> /dev/null && bundle exec rspec --version &> /dev/null 2>&1; then
    RSPEC_CMD="bundle exec rspec"
elif [[ -x /opt/rbenv/versions/3.3.6/bin/rspec ]]; then
    RSPEC_CMD="/opt/rbenv/versions/3.3.6/bin/rspec"
elif [[ -x /usr/local/bin/rspec ]]; then
    RSPEC_CMD="/usr/local/bin/rspec"
else
    echo -e "${RED}Error: rspec not found${NC}"
    echo "Run: bundle install && gem install rspec"
    exit 1
fi

# Run the tests
$RSPEC_CMD spec/acceptance/podman_ssh_spec.rb spec/acceptance/podman_testcontainers_spec.rb --format documentation

echo ""
echo -e "${GREEN}=== Tests Complete ===${NC}"
