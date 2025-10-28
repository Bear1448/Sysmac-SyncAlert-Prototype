\## Summary

Describe what changed and why.



\## Export Info

\- Exported by: @<!-- your handle -->

\- Branch: <!-- e.g., feature/2025-10-28-watcher-v2 -->

\- Note used in lock-start: 

\- Export timestamp (from Teams \[EXPORT]): 

\- Tag created? (y/n)  Name:



\## Checklist (Phase 1 – No Team Dev)

\- \[ ] \*\*Lock acquired\*\* before editing (`tools/lock-start.ps1 "note"`) and Teams \*\*\[LOCK]\*\* appeared

\- \[ ] Edited in Sysmac and \*\*exported once\*\* (watcher committed \& pushed)

\- \[ ] Teams \*\*\[EXPORT]\*\* message appeared with correct filename

\- \[ ] \*\*Lock released\*\* (`tools/lock-end.ps1 "summary"`) and Teams ✅ appeared

\- \[ ] I did \*\*not\*\* attempt to merge `.smc2` (binary/no merge policy)

\- \[ ] Project \*\*opens in Sysmac\*\* locally after export

\- \[ ] Added/confirmed \*\*weekly tag\*\* (restore point) if this is an integration PR

\- \[ ] PR targets \*\*main\*\* and will be \*\*Squash merged\*\* (branch protection)



\## Notes for Reviewer (Team Lead)

\- Verify the PR shows \*\*only one\*\* final `.smc2` export for this change

\- Confirm lock and export events in Teams channel #sysmac-syncalert

\- If anything looks off, request re-export rather than attempting a merge



