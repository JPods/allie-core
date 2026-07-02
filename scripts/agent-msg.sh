#!/bin/bash
# agent-msg — CLI for the inter-agent message bus
#
# Usage:
#   agent-msg send --from claude --to alice --subject "Build failed" --body "Details" --priority 1
#   agent-msg inbox alice
#   agent-msg inbox alice --all
#   agent-msg read 42
#   agent-msg ack 42
#   agent-msg reply 42 --from alice --body "Fixed it"
#   agent-msg broadcast --from noelle --subject "Validation complete"
#   agent-msg thread 42
#   agent-msg count alice
#   agent-msg cleanup --days 30

~/Allie/source/bin/python ~/Allie/scripts/agent_bus.py "$@"
