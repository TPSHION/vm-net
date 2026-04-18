# vm-net

[English](README.md) | [简体中文](README.zh-CN.md)

![vm-net logo](img/vm-net-logo.png)

`vm-net` is a macOS menu bar network utility focused on always-on visibility and fast troubleshooting. It combines real-time throughput monitoring, a draggable floating capsule, per-process activity inspection, built-in speed tests, network diagnosis, and an optional desktop pet overlay.

## Highlights

- Real-time upload and download monitoring from a shared data pipeline
- Menu bar presentation with compact dual-line throughput display
- Draggable floating capsule with persisted position, colors, and transparency
- Network Activity page with per-process traffic ranking, anomaly alerts, event timeline, and quick process actions
- Speed test workflow powered by Measurement Lab (M-Lab / NDT7)
- Network diagnosis workflow with path, DNS, and HTTPS checks plus recent history
- Optional Desktop Pet overlay with roaming behavior, Rive-based animation, and StoreKit-backed unlock flow
- Built-in English and Simplified Chinese localization

## Current Scope

This repository currently ships these app surfaces:

- `Settings`: display mode, launch behavior, floating capsule, localization, and activity settings
- `Network Activity`: process traffic, alerts, timeline, and live summary
- `Speed Test`: latency, download, upload, and recent results
- `Network Diagnosis`: preset target checks and diagnosis history
- `Desktop Pet`: optional pet overlay attached to the floating capsule

The AI diagnosis document in [`docs/ai-diagnosis-implementation.md`](docs/ai-diagnosis-implementation.md) is a design reference for future work. It is not part of the current implementation.

## Requirements

- macOS `13.5` or later
- Xcode `16.3` or later recommended
- Internet access for speed tests and diagnosis targets

## Build And Run

### Option 1: Xcode

1. Open [`vm-net.xcodeproj`](vm-net.xcodeproj).
2. Select the `vm-net` scheme.
3. Build and run on macOS.

### Option 2: Script

```bash
./script/build_and_run.sh
```

The first build resolves the Swift Package dependency for `RiveRuntime`.

## Project Structure

```text
vm-net/
  App/           app lifecycle, preferences, window wiring
  MenuBar/       menu bar UI and status item controller
  FloatingBall/  floating capsule window and content
  DesktopPet/    pet world, renderer bridge, and behavior engine
  Models/        app models and snapshots
  Services/      monitoring, diagnosis, speed test, and process services
  Stores/        long-lived observable stores
  Views/         SwiftUI pages
  Support/       formatters, localization, helpers
docs/            implementation notes and design documents
site/            static privacy policy page
img/             marketing and screenshot assets
```

## Privacy And Data Notes

- The app is designed to be local-first for preferences and recent history.
- Speed tests contact external Measurement Lab endpoints.
- Diagnosis flows contact the selected diagnosis target.
- Desktop Pet purchase and restore flows rely on Apple StoreKit.

The current privacy page lives at [`site/privacy-policy.html`](site/privacy-policy.html).

## Related Docs

- [Throughput display design](docs/throughput-display-implementation.md)
- [Desktop Pet implementation](docs/desktop-pet-implementation.md)
- [Network observability implementation](docs/network-observability-implementation.md)
- [AI diagnosis design note](docs/ai-diagnosis-implementation.md)

## License

Released under the [MIT License](LICENSE).
