---
description: Show what Cleetus is providing in this project — components, stack profile, agents, MCP servers, bookshelf, and session markers.
---

Print the full harness status for the current project (read-only):

```
bash "${CLAUDE_PLUGIN_ROOT}/tools/harness_status.sh"
```

This is the fuller companion to the SessionStart banner: which components are on, the resolved stack
profile, BYO agents present, MCP servers configured, the reference bookshelf (`TOMES_DIR`) and MCP
guides, and any session-local markers. After it runs, summarize anything notable — e.g. a gate on with
no `test_command`, an unset `TOMES_DIR`, or broken agent symlinks. For "is anything broken/missing?"
use `/harness:doctor`.
