# Network Activity Enhanced Sampling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the activity page refresh process data every second and restore richer occupancy metrics without changing other app surfaces.

**Architecture:** Keep the existing always-on throughput path intact. Add richer activity-page-only process sampling in `ProcessTrafficHelperBridge`, derive rolling-window metrics in `ProcessTrafficStore`, and surface the new fields in `NetworkActivityPageView`.

**Tech Stack:** Swift, SwiftUI, AppKit, `nettop`, standalone Swift regression runner for pure derivation logic, Xcode build verification

---

### Task 1: Add testable rolling-window derivation logic

**Files:**
- Create: `vm-net/Models/ProcessTrafficTag.swift`
- Create: `vm-net/Services/ProcessTrafficActivityDeriver.swift`
- Create: `vm-netTests/ProcessTrafficActivityDeriverTests.swift`

- [ ] Step 1: Write failing tests for 10-second/1-minute accumulation, retry-like tagging, and burst tagging.
- [ ] Step 2: Run the standalone Swift regression runner and verify the tests fail.
- [ ] Step 3: Implement the minimal derivation helper and tag model to make the tests pass.
- [ ] Step 4: Run the standalone Swift regression runner again and verify it passes.

### Task 2: Restore enhanced activity-page sampling

**Files:**
- Modify: `vm-net/Services/ProcessTrafficHelperBridge.swift`
- Modify: `vm-net/Models/ProcessTrafficProcessRecord.swift`
- Modify: `vm-net/Models/ProcessTrafficSnapshot.swift`
- Modify: `vm-net/Stores/ProcessTrafficStore.swift`

- [ ] Step 1: Add failing tests for the derivation helper inputs needed by the store if gaps remain.
- [ ] Step 2: Change the bridge to run a 1-second connection-level `nettop` parse in activity-page mode.
- [ ] Step 3: Feed parsed samples through the deriver and publish enriched process records.
- [ ] Step 4: Run the regression runner and a project build to verify the bridge/store compile with the new model.

### Task 3: Restore richer activity-page UI

**Files:**
- Modify: `vm-net/Views/NetworkActivityPageView.swift`
- Modify: `vm-net/Resources/Localization/zh-Hans.lproj/Localizable.strings`
- Modify: `vm-net/Resources/Localization/en.lproj/Localizable.strings`

- [ ] Step 1: Update the activity page to sort/filter/render the new metrics and tags without changing other pages.
- [ ] Step 2: Add the new localized copy for metrics, windows, tags, and refreshed page wording.
- [ ] Step 3: Run a project build to verify the UI compiles cleanly.

### Task 4: Verify end-to-end activity-page behavior

**Files:**
- Modify as needed: files from Tasks 1-3

- [ ] Step 1: Run the unit tests.
- [ ] Step 2: Run a macOS app build.
- [ ] Step 3: If the build succeeds, summarize the exact scope: activity page only, no throughput/menu bar changes.
