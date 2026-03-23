## Hermes Agent Overlay

Hermes Agent supports parallel execution via worktree isolation (`hermes -w`).
Use separate worktree sessions for parallel review and triage work.

### Review workflow

1. Run `desloppify review --prepare` to generate `query.json` and `.desloppify/review_packet_blind.json`.
2. Split dimensions into 3-4 batches by theme (e.g., naming + clarity,
   abstraction + error consistency, testing + coverage).
3. Launch parallel Hermes sessions with worktree isolation, one per batch:
   ```
   hermes -w -q "Score these dimensions: <list>. Read .desloppify/review_packet_blind.json for the blind packet. Score from code evidence only."
   ```
4. Each session writes output to a separate file. Merge assessments
   (average overlapping dimension scores) and concatenate findings.
5. Import: `desloppify review --import merged.json --manual-override --attest "Hermes agents ran blind reviews against review_packet_blind.json" --scan-after-import`.

Each session must consume `.desloppify/review_packet_blind.json` (not full
`query.json`) to avoid score anchoring.

### Triage workflow

Orchestrate triage with per-stage Hermes sessions:

1. For each stage (observe → reflect → organize → enrich → sense-check):
   - Get prompt: `desloppify plan triage --stage-prompt <stage>`
   - Launch a Hermes session with that prompt: `hermes -w -q "<prompt>"`
   - Verify: `desloppify plan triage` (check dashboard)
   - Confirm: `desloppify plan triage --confirm <stage> --attestation "..."`
2. Complete: `desloppify plan triage --complete --strategy "..." --attestation "..."`

Run stages sequentially. Within observe and sense-check, use parallel
worktree sessions (`hermes -w`) for per-dimension-group and per-cluster
batches respectively.

<!-- desloppify-overlay: hermes -->
<!-- desloppify-end -->
