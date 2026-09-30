# Onset — a 60-second stroke check that uses your iPhone as the instrument

When someone has a stroke, every minute without treatment costs brain. Yet most people don't recognise the signs, or wait to see if they pass. Paramedics use the **FAST** test — Face, Arms, Speech, Time. Onset lets anyone run it in about a minute, with the iPhone measuring instead of guessing:

| | What Onset measures | How |
|---|---|---|
| **F — Face** | Is one side of the smile weaker or drooping? | TrueDepth face mesh (ARKit) reads left/right mouth muscle activation at rest and in a big smile |
| **A — Arms** | Does one arm sink or turn when held out with eyes closed? | The phone lies on the palm; CoreMotion measures how far it tilts over 10 seconds, left arm then right |
| **S — Speech** | Is speech slurred or wrong? | On-device speech recognition scores a standard sentence (“You can't teach an old dog new tricks”) |
| **T — Time** | When were they last seen normal? | Recorded and shown on a live paramedic card, because treatment options depend on it |

It also asks about the two signs FAST misses (sudden **B**alance loss and **E**ye/vision change — "BE-FAST"), plus sudden severe headache or confusion.

If anything is found, Onset says so plainly and puts a one-tap call button to the local ambulance number (998 in the UAE, 112 in Turkey and Europe, 911 in the US…) on the screen. The call button is on every screen of the check.

### Why a personal baseline matters
No face, arm or voice is perfectly symmetric. Comparing against an average creates false alarms. Onset lets you record each person's **normal** on a good day, and every later check is compared with *their own* face, arms and voice — so a small change becomes visible.

## Monetization (RevenueCat)
**The emergency check is free for everyone, forever.** We never charge for the moment someone might be having a stroke.

**Onset Family** (monthly or yearly subscription via RevenueCat) is for the ongoing care around it — the people most at risk, usually our parents:
- Up to 6 family members, each with a saved normal
- Weekly 20-second check-ins with reminders, compared with their normal
- A trend chart that shows when a smile is getting weaker week by week
- Paramedic cards with blood thinners and conditions ready

Free plan: yourself + unlimited emergency checks on anyone. The paywall is built natively with RevenueCat Offerings; the entitlement is `family`.

## Privacy
Everything runs and stays on the iPhone: no account, no server, no analytics. Audio and camera frames are never stored.

## Build and run
Requirements: Xcode 16 or newer, an iPhone with Face ID (TrueDepth camera), iOS 17+.

1. Open `Onset.xcodeproj` in Xcode. The RevenueCat package downloads automatically.
2. Select the **Onset** target → *Signing & Capabilities* → choose your Team (a free Apple ID "Personal Team" works) and, if needed, change the bundle identifier to something unique.
3. Plug in your iPhone, select it as the run destination and press **Run** (Debug configuration).

Purchases run through **RevenueCat Test Store**, so no App Store Connect setup is needed to try the Family plan. The Test Store SDK key is in `Onset/App/Config.swift`. Test Store keys only work in Debug builds.

## Project structure
```
Onset/
  App/        OnsetApp, Config (RevenueCat key, emergency numbers)
  Models/     Profile, Baseline, measurements, CheckRecord, Grader (thresholds)
  Services/   OnsetStore (on-device JSON storage, reminders), PurchaseManager (RevenueCat)
  Check/      FaceTracker (ARKit), ArmTracker (CoreMotion), SpeechTracker (Speech),
              step screens, CheckFlowView, ResultView + ParamedicCardView
  Views/      Home, profiles & trend chart, paywall, onboarding, settings
```

## Important
Onset is a screening aid based on the FAST / BE-FAST stroke signs. It is **not a medical device and does not diagnose**. A normal result does not rule out a stroke. If you think someone is having a stroke, call emergency services immediately.

Built for RevenueCat Shipaton 2026 (Next Gen Award) by Sulaiman AbuQamar. MIT licensed.
