# KahootP2P

A Kahoot-style multiplayer quiz game for iOS that works **completely offline** using peer-to-peer networking. No internet, no servers - just devices on the same local network.


https://github.com/user-attachments/assets/2b2882bf-3083-451d-bc11-f318fcb76f21


Built with **Couchbase Lite Enterprise** P2P replication and **SwiftUI**.

## How It Works

One device acts as the **host** and others join as **players**. The host creates a quiz, players discover and connect via Bonjour, and game state syncs in real-time through Couchbase Lite's URLEndpointListener.

```
┌─────────┐     P2P Replication     ┌─────────┐
│  Host   │◄──────────────────────►│ Player  │
│ (Auth)  │     Bonjour Discovery   │         │
└─────────┘                         └─────────┘
     ▲                                   
     │          P2P Replication          
     ▼                                   
┌─────────┐                              
│ Player  │                              
│         │                              
└─────────┘                              
```

**Host-authoritative architecture** - the host controls question flow, scores answers, and manages the leaderboard. Clients submit answers and receive results through document replication.

## Features

- **Offline P2P** - No internet or router needed. Works over Wi-Fi Direct / local network
- **Bonjour Discovery** - Players automatically find nearby games
- **Kahoot-style UI** - Dark purple theme, colored answer tiles, countdown timer
- **Speed-based Scoring** - Faster correct answers earn more points (up to 1000)
- **Live Leaderboard** - Rankings update after each question with gold/silver/bronze badges
- **Countdown Timer** - Animated progress bar with numeric display
- **Answer Reveal** - Shows the correct answer when you get it wrong or time runs out

## Requirements

- iOS 16.0+
- Xcode 15.0+
- [Couchbase Lite Swift Enterprise Edition](https://www.couchbase.com/downloads) 4.0.3+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to generate the Xcode project)

## Setup

```bash
# Clone the repo
git clone https://github.com/midopooler/KahootP2P.git
cd KahootP2P

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open KahootP2P.xcodeproj
```

Build and run on **two or more physical devices** on the same local network (simulators don't support Bonjour/local networking).

## Playing

1. **Host** - Enter your name, tap "Host a Game". Share the game PIN with players.
2. **Players** - Enter your name, tap "Join a Game". Select the discovered game.
3. **Host** - Once all players have joined the lobby, tap "Start".
4. **Answer** - Tap one of the four colored answer tiles before the timer runs out. Faster = more points.
5. **Results** - See the final leaderboard after all questions.

## Project Structure

```
QuizBlitz/
├── App/                  # App entry point, Info.plist
├── Database/             # DatabaseManager (Couchbase Lite collections & queries)
├── Engine/
│   ├── HostEngine        # Game orchestration, scoring, question flow
│   ├── ClientEngine      # Answer submission, state observation
│   └── TimingService     # NTP-free timing for score calculation
├── Models/               # Game, Player, Question, Answer, Score, Leaderboard
├── Networking/           # P2P service (URLEndpointListener + Bonjour)
├── ViewModels/           # GameViewModel (bridges engines to SwiftUI)
└── Views/                # SwiftUI views with Kahoot theme
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| UI | SwiftUI |
| Database | Couchbase Lite Enterprise 4.0.3 |
| P2P Transport | URLEndpointListener (CB Lite) |
| Discovery | Bonjour (NetService / NetServiceBrowser) |
| Reactive Layer | Combine (change publishers) |
| Project Gen | XcodeGen |

## License

MIT
