# Zonar — Technical Documentation

## Overview

Zonar is a submarine battle game (Battleship-style) built on **Midnight Network** — a privacy-focused blockchain that uses **zero-knowledge proofs (ZKPs)** to let players make moves that are verified on-chain without ever exposing their secret submarine positions to the public ledger.

The core guarantee: a player can prove *"I fired at coordinate B4 and it was a miss"* — cryptographically verifiable by anyone — without the blockchain ever recording where the fleet actually is.

---

## How Zero-Knowledge Proofs Enable Private Gameplay

In a traditional on-chain game, every action is transparent. Recording "submarine at B4" on a public ledger would let opponents read the chain and cheat. Midnight Network solves this with ZKPs.

**The ZK model in Zonar:**

1. At game start, a player's submarine fleet positions are committed to the Midnight ledger as a **cryptographic commitment** — a hash that binds the player to their configuration without revealing it.
2. When a player fires at a coordinate, a ZK circuit is executed locally. The circuit takes:
   - The secret: actual submarine positions (known only to the player's device)
   - The public input: the targeted tile index
   - It produces a **proof** that the result (hit or miss) is correct, given the committed fleet — without revealing any other positions.
3. The proof is submitted to the Midnight ledger. The ledger verifies the proof and records the result publicly. No submarine position information leaks.

This means the entire game history is on-chain and fully auditable, yet the fleet layout remains private until a player chooses to reveal it.

---

## Project Structure

```
zonar/                          # Flutter application root
├── lib/
│   ├── main.dart               # App entry point, DI wiring
│   └── features/
│       └── battle_map/
│           ├── data/
│           │   ├── models/
│           │   │   └── tile_model.dart          # TileModel, TileStatus enum
│           │   └── repositories/
│           │       ├── game_repository.dart     # Abstract interface
│           │       └── game_repository_impl.dart # ZK-backed implementation
│           ├── domain/
│           │   └── services/
│           │       └── midnight_service.dart    # Midnight JS engine bridge
│           └── presentation/
│               ├── bloc/
│               │   ├── battle_map_bloc.dart     # Game state machine
│               │   ├── battle_map_event.dart    # Events
│               │   └── battle_map_state.dart    # State model
│               ├── game/
│               │   ├── submarine_flame_game.dart  # Flame 10×10 grid
│               │   └── components/
│               │       ├── tile_component.dart    # Individual cell rendering
│               │       └── radar_ping_effect.dart # Sonar ring animation
│               └── views/
│                   ├── battle_map_screen.dart   # Root screen
│                   └── widgets/
│                       ├── status_hud.dart      # Top HUD (score, log, ZKP status)
│                       └── game_controls_overlay.dart # Bottom bar
│
zonar_js_engine/                # Node.js Midnight runtime
├── package.json                # @midnight-ntwrk/midnight-js dependencies
└── (midnight_runtime.html)     # Loaded inside a headless WebView
```

---

## Architecture

Zonar uses a clean layered architecture with a Flutter↔JavaScript bridge as the ZK execution boundary.

```
┌─────────────────────────────────────────────────────┐
│                    Flutter UI Layer                 │
│  BattleMapScreen  ←→  SubmarineFlameGame (Flame)   │
│              ↑ BlocListener/BlocBuilder             │
├─────────────────────────────────────────────────────┤
│                 State Management (BLoC)             │
│              BattleMapBloc                          │
│   StrikeCoordinate event → _LedgerUpdated event    │
├─────────────────────────────────────────────────────┤
│                   Repository Layer                  │
│              GameRepositoryImpl                     │
│   fireTorpedo() → awaits ZK result stream          │
├─────────────────────────────────────────────────────┤
│                   Domain Service                    │
│              MidnightService                        │
│   WebView bridge: Flutter ↔ JavaScript             │
├─────────────────────────────────────────────────────┤
│            Midnight JS Engine (WebView)             │
│   window.executeAttackProof(index)                  │
│   @midnight-ntwrk/midnight-js SDK                  │
│   → ZK proof generation → Midnight Network ledger  │
└─────────────────────────────────────────────────────┘
```

### Key Design Decisions

- **WebView as ZK runtime**: The Midnight JS SDK runs inside a `WebViewController` (via `webview_flutter`). This keeps ZK proof generation self-contained in JavaScript while the game UI remains pure Flutter/Dart. The WebView is never shown to the user — it acts as a headless JS engine.
- **Stream-based ledger state**: `MidnightService` exposes a broadcast stream (`onZKPayloadReceived`) that carries confirmed on-chain results. This decouples the ZK engine's async callback from the Flutter state machine.
- **BLoC as single source of truth**: `BattleMapBloc` owns all game state. The Flame canvas is an output-only renderer — it receives state pushes from `BattleMapScreen._synchronizeGameEngine` and never drives state itself.

---

## Data Flow: Firing a Torpedo

```
User taps tile [index]
        │
        ▼
TileComponent.onTapDown()
        │
        ▼
onTileSelected(index) callback
        │
        ▼
BattleMapBloc.add(StrikeCoordinate(index))
        │
        ▼
_onStrikeCoordinate()
  • Guards: skip if already pending or confirmed
  • Emits: pendingTiles[index] = processing
           status = generatingProof
           logMessage = "Computing zero-knowledge state proof locally…"
        │
        ▼
GameRepository.fireTorpedo(index)
        │
        ▼
MidnightService.evaluateMoveOnChain(index)
  → webViewController.runJavaScript('window.executeAttackProof($index)')
        │
        ▼ (async, inside the WebView)
Midnight JS SDK
  • Reads committed fleet state (private witness)
  • Runs ZK circuit for coordinate [index]
  • Generates proof
  • Submits transaction to Midnight Network
  • Calls: MidnightBridgeChannel.postMessage(JSON)
        │
        ▼ (back in Flutter)
MidnightService._zkResponseController.add(payload)
        │
        ├── GameRepositoryImpl (via onZKPayloadReceived)
        │     • payload['status'] == 'SUCCESS'
        │     • result == 2 → TileStatus.hit, else TileStatus.miss
        │     • _stateStreamController.add(updatedBoardState)
        │
        ▼
BattleMapBloc._LedgerUpdated(ledgerMap)
  • Moves tile from pendingTiles → confirmedTiles
  • Logs: "Direct Hit — submarine position verified on-chain."
       or "Sector clear — zero presence confirmed by ZK proof."
        │
        ▼
BattleMapScreen._synchronizeGameEngine(state)
  → SubmarineFlameGame.updateTile(index, TileDisplayState.hit/miss)
        │
        ▼
TileComponent renders result + RadarPingEffect spawned
```

---

## Core Components

### `MidnightService` — ZK Bridge

**File:** `lib/features/battle_map/domain/services/midnight_service.dart`

Owns the hidden WebView that hosts the Midnight JS runtime. Exposes two entry points:

| Method | Description |
|---|---|
| `initializeEngine()` | Initializes the WebViewController, registers `MidnightBridgeChannel`, and loads `assets/midnight_runtime.html` |
| `evaluateMoveOnChain(int index)` | Calls `window.executeAttackProof(index)` in JS to trigger ZK proof generation |
| `onZKPayloadReceived` | Broadcast stream of JSON payloads from the JS engine |

**Payload schema** (from JS engine via `MidnightBridgeChannel`):
```json
{
  "status": "SUCCESS" | "ERROR",
  "tile": 42,
  "result": 2,
  "message": "optional error string"
}
```
`result == 2` encodes a hit; any other value is a miss.

---

### `GameRepositoryImpl` — Ledger State Manager

**File:** `lib/features/battle_map/data/repositories/game_repository_impl.dart`

Translates raw ZK payloads into domain-level `TileStatus` values and maintains a cumulative board state cache (`_cachedBoardState`). Exposes:

- `fireTorpedo(int tileIndex)` — triggers the ZK execution and returns a `Future<TileStatus>` that resolves once the ledger confirms the result for that specific tile.
- `ledgerStateStream` — a continuous stream of the full confirmed board as a `Map<int, TileStatus>`.

---

### `BattleMapBloc` — Game State Machine

**File:** `lib/features/battle_map/presentation/bloc/battle_map_bloc.dart`

Manages two parallel tile maps:

| Map | Contents |
|---|---|
| `pendingTiles` | Tiles awaiting ZK proof confirmation |
| `confirmedTiles` | Tiles with ledger-confirmed results |

`revealedTiles` merges both (confirmed wins on conflict) — this is what the renderer reads.

**Game turn statuses:**

| Status | Meaning |
|---|---|
| `idle` | Ready for player input |
| `generatingProof` | ZK proof is being computed; HUD shows spinner |

---

### `SubmarineFlameGame` — Game Renderer

**File:** `lib/features/battle_map/presentation/game/submarine_flame_game.dart`

A `FlameGame` that renders a 10×10 grid of `TileComponent`s. Grid coordinates are labeled A–J (rows) × 1–10 (columns). The game is driven externally via:

- `updateTile(int index, TileDisplayState state)` — sets a tile to hit/miss and spawns a `RadarPingEffect`
- `setTileProcessing(int index)` — marks a tile as pending (shows cyan sonar rings)
- `triggerImpactShake()` — applies a camera `MoveEffect` on confirmed hits

The `_ScanLineComponent` runs continuously for atmospheric effect — a slow horizontal strip that drifts down the board with occasional cyan glitch flickers.

---

### `TileComponent` — Individual Grid Cell

**File:** `lib/features/battle_map/presentation/game/components/tile_component.dart`

Each tile handles its own rendering and animation state:

| `TileDisplayState` | Visual |
|---|---|
| `unrevealed` | Dark fill with breathing sine-wave opacity |
| `processing` | Pulsing cyan sonar rings (loops every 1.3s) |
| `hit` | Red fill + white cross + camera shake + red sonar rings |
| `miss` | Blue-grey fill + small dot + dark sonar rings |

Only `unrevealed` tiles respond to tap events. All other states are locked.

---

## JS Engine (`zonar_js_engine`)

**Location:** `zonar/zonar_js_engine/`

A Node.js package that bundles the Midnight Network ZK runtime into a HTML asset loaded by the Flutter WebView.

**Dependencies:**

| Package | Role |
|---|---|
| `@midnight-ntwrk/midnight-js` | Core Midnight Network client SDK |
| `@midnight-ntwrk/midnight-js-contracts` | Smart contract interaction |
| `@midnight-ntwrk/midnight-js-http-client-proof-provider` | HTTP-based proof generation provider |

**Interface contract:**

The bundled JS must expose `window.executeAttackProof(index: number)` and communicate results back to Flutter via:
```javascript
MidnightBridgeChannel.postMessage(JSON.stringify({
  status: 'SUCCESS',
  tile: index,
  result: 2,  // 2 = hit
}));
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | Flutter 3 / Dart |
| Game Engine | Flame 1.37 |
| State Management | flutter_bloc 8 |
| ZK Runtime Bridge | webview_flutter 4 |
| Blockchain | Midnight Network |
| ZK SDK | @midnight-ntwrk/midnight-js 4.x |

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.1`
- Node.js (for building the JS engine)
- Access to a Midnight Network node (testnet or devnet)

### Running the Flutter App

```bash
cd zonar
flutter pub get
flutter run
```

### Building the JS Engine

```bash
cd zonar/zonar_js_engine
npm install
# Bundle into assets/midnight_runtime.html per your build pipeline
```

The compiled JS bundle must be placed at `assets/midnight_runtime.html` and declared in `pubspec.yaml` under `flutter.assets`.

---

## Privacy Model Summary

| What is public (on Midnight ledger) | What stays private |
|---|---|
| Which coordinates have been fired at | Submarine fleet positions |
| Whether each shot was a hit or miss | Total fleet layout |
| ZK proofs for each outcome | Private witness data |
| Game result and history | Opponent's strategic information |

Every action is verifiable. No position is ever leaked. This is the core value proposition of building on Midnight Network — full auditability with configurable privacy.
