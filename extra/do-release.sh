#!/usr/bin/env zsh

print "The production build and deploy capabilities are provided by:"
print " "
print "  MCP Full Release"
print "  ----------------"
print "   a. extra/mcp/prod-release.sh"
print " "
print "  MCR Full Release"
print "  ----------------"
print "   a. extra/deploy-mcr-firmware.sh"
print " "
print "  NOTES:"
print "   a. Use 'env SKIP_PULL=1 extra/mcp/prod-release.sh' to prevent git pull"
print "   a. The MCR Full Release script deploys the firmware to htdocs"
print "      and creates the latest-* symbolic links.  Use Remote.ota_update/1"
print "      to trigger the firmware update."
exit 1
