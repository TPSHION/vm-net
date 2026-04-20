# Network Activity Enhanced Sampling Design

## Goal

Improve the `网络活动` page only so it refreshes faster and exposes richer process-level occupancy data after the user explicitly starts analysis, without changing the menu bar, floating ball, settings dashboard, or always-on monitoring chain.

## Scope

Included:

- Faster process sampling while `NetworkActivityPageView` is visible
- Richer per-process metrics for the activity page
- Activity-page-only rolling windows and tags
- Activity page UI updates to show the restored metrics

Excluded:

- `ThroughputStore`
- `NetworkMonitor`
- Menu bar and floating ball rendering
- Settings dashboard summaries
- Background persistence or long-term history

## Approach

`ProcessTrafficStore` gains an activity-page monitoring mode backed by an enhanced `ProcessTrafficHelperBridge`. In this mode, the bridge samples `nettop` every second with connection-level rows enabled, parses connection counts, remote host frequency, and retry-like socket states, then passes raw samples into a derived-metrics layer inside the store. The store keeps short-lived rolling windows in memory and publishes enriched process records to `NetworkActivityPageView`.

The heavier sampling only runs after the user presses Start Analysis on the activity page. Leaving the page or pressing Stop stops the helper process and clears all rolling-window buffers.

## Data Restored To The Activity Page

- Current download rate
- Current upload rate
- 10-second cumulative download/upload
- 1-minute cumulative download/upload
- Active connection count
- Top remote hosts
- Failure/retry-like count delta
- Process tags: high download, high upload, background active, retry-like, burst

## Performance Guardrails

- Enhanced sampling starts only after the user explicitly starts analysis from the activity page
- Sampling interval is 1 second
- Rolling windows live in memory only and are cleared on stop
- Only the top remote hosts per process are retained
- No persistence, no background warm cache, no changes to always-on stores
