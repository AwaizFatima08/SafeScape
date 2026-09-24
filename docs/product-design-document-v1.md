Sensory SafeScape
Comprehensive Product Design Document & Engineering Specification (V1 — Android)
Step 1: Executive Summary & Core Objectives
Executive Summary
Sensory SafeScape is an interactive, low-stimulation sensory regulation and transition management mobile application designed specifically for children on the Autism Spectrum (ASD), those with Sensory Processing Sensitivity (SPS), and neurodivergent young learners (ages 2–10).
Children with sensory integration differences often experience sensory overload, emotional dysregulation, and high anxiety during unpredictable daily routine shifts (e.g., leaving for school, visiting a medical clinic, or transitioning to bedtime). Sensory SafeScape provides a predictable, self-soothing digital sanctuary that combines tactile-visual sensory regulation with structured, step-by-step visual transition schedules.
┌───────────────────────────────────────────────────────────┐
│                 SENSORY SAFESCAPE ENGINE                  │
│                                                           │
│   [ Self-Regulation Layer ]       [ Transition Layer ]    │
│   - Fluid Visual Waves            - Step-by-Step Stories  │
│   - Tactile Particle Flows        - Visual Task Counters  │
│   - Soothing Acoustic Hums        - Positive Reinforcement│
│                                                           │
│              ┌─────────────────────────────┐              │
│              │    SENSORY CONTROL BOARD    │              │
│              │ - Light & Motion Limiter    │              │
│              │ - Frequency Audio Notch     │              │
│              └─────────────────────────────┘              │
└───────────────────────────────────────────────────────────┘
Primary Rehab & Developmental Objectives
    1. Promote Emotional Self-Regulation: Provide an immediate, controllable digital coping mechanism that helps children de-escalate during moments of sensory distress or meltdown.
    2. Tactile & Visual Desensitization: Offer customizable, smooth visual and audio feedback loops that help children build tolerance to movement, spatial transitions, and subtle acoustic changes.
    3. Reduce Transition-Induced Anxiety: Use clear, predictable visual schedules and social micro-stories to help children prepare for, understand, and complete daily life shifts.
    4. Empower Parents & Occupational Therapists (OTs): Capture objective, non-intrusive data regarding a child's sensory preferences, calming durations, and routine completion rates to share during clinical evaluations.
Step 2: V1 Architecture Strategy & Answering Core Engineering Questions
Q1: Do we need an upfront user login?
    • For V1: No upfront or mandatory login.
    • Rationale: Mandatory registration forms cause friction and can be overwhelming for a parent managing an dysregulated child.
    • Implementation: The app launches directly in Guest Mode. On first launch, a 30-second setup asks for the child's alias/nickname, age group, and initial sensory preferences. Firebase Anonymous Authentication creates a secure, unique identifier (UID) silently in the background without requiring an email or password.
First Launch ──► Guest Mode ──► Silent Firebase Anonymous Auth ──► Store Profile Locally & Sync Cloud
Q2: If the user changes or resets their Android device, will progress be preserved?
    • Yes. All local settings, customized visual schedules, and historical calming data are saved to Cloud Firestore under the anonymous UID.
    • Account Linking: Inside the protected Parent Zone, an optional "Backup & Sync Progress" button lets parents link an Email or Google Account at any time. When signed in on a new Android device, Firebase merges the existing cloud profile effortlessly.
Q3: Can a parent profile manage multiple child aliases?
    • Yes. A single parent/guardian account supports multiple child profiles (aliases), allowing parents or therapists with multiple neurodivergent children to customize separate sensory profiles for each child.
    • Data Hierarchy:
      $$\text{Parent Account (UID)} \longrightarrow \text{Child Profiles (Sub-collection)} \longrightarrow \text{Sensory Preferences \& Logs}$$
Q4: Does V1 require Cloud Firestore and backend integration?
    • Yes. A lightweight Cloud Firestore setup is essential for V1 due to three key requirements:
        1. Offline-First Resilience: Firestore caches data locally on the Android device. If the child is using the app in a location without internet (e.g., in a car or clinic waiting room), the app functions seamlessly and syncs data to the cloud once Wi-Fi or cellular connectivity is restored.
        2. Cross-Device Continuity: Ensures visual routine cards created on a parent's phone appear instantly on a child's dedicated tablet.
        3. Therapist Data Export: Allows parents to generate longitudinal summaries of calming sessions for Occupational Therapy (OT) visits.
Step 3: Sensory-Safe Design System & Accessibility Rules
Children on the Autism Spectrum often process visual and auditory input differently. High-contrast flashiness, fast animations, or harsh buzzer sounds can trigger sensory overload or distress. Sensory SafeScape adheres to strict sensory accessibility guidelines.
   [ Primary Palette ]        [ Secondary Palette ]        [ Canvas Base ]
┌───────────────────────┐  ┌───────────────────────┐  ┌───────────────────────┐
│      Soft Lavender    │  │     Muted Mint        │  │     Deep Slate        │
│        #9D8DF1        │  │       #90DBB7         │  │       #12131C         │
└───────────────────────┘  └───────────────────────┘  └───────────────────────┘
1. Color Palette & Lighting
    • Base Canvas: Deep Slate (#12131C) reduces glare and eye strain.
    • Accent Pastels: Soft Lavender (#9D8DF1), Muted Mint (#90DBB7), Warm Sand (#F4E4BA), and Powder Blue (#89CFF0).
    • Forbidden Visuals: No pure white backgrounds (#FFFFFF), no high-frequency strobe effects, no sudden camera shakes, and no aggressive red alert banners.
2. Interaction Design & Touch Targets
    • Chubby Touch Boundaries: All interactive icons have minimum physical hit target dimensions of $72 \times 72 \text{ dp}$ with smooth, rounded corners ($24\text{ px}$ corner radius).
    • Predictable Gesture Physics: Touch gestures yield smooth fluid-like ripples or slow-moving particle trails with natural drag resistance.
    • Zero Negative Reinforcement: The app contains no timer buzzers, no failing grades, no "Wrong Answer" crosses, and no loss of points. Incorrect or incomplete interactions result in a soft idle state.
3. Audio & Acoustic Engineering
    • Frequency Filtering: All sound assets are pre-filtered to remove high-pitched frequencies ($>6\text{ kHz}$) that can trigger auditory hypersensitivity.
    • Soft Acoustic Responses: Uses binaural ambient drones, soft wooden marimba tones, gentle rainfall, and warm acoustic hums.
    • Audio Ducking & Mute: Global one-tap mute button accessible across all screens.
Step 4: Complete Screen Workflows & Detailed Visual Mockups
                            ┌───────────────────┐
                            │   Splash Screen   │
                            └─────────┬─────────┘
                                      │
                            ┌─────────▼─────────┐
                            │ Onboarding Setup  │
                            │ (Alias & Profile) │
                            └─────────┬─────────┘
                                      │
                            ┌─────────▼─────────┐
                            │ Main Sensory Hub  │
                            └─────────┬─────────┘
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         │                            │                            │
┌────────▼────────┐          ┌────────▼────────┐          ┌────────▼────────┐
│ Screen 3: Flow  │          │ Screen 4: Visual│          │ Screen 5: Parent│
│ Calming Canvas  │          │ Transition Card │          │ & OT Dashboard  │
└─────────────────┘          └─────────────────┘          └─────────────────┘
Screen 1: Child Alias & Sensory Sensitivity Onboarding
    • Header: Warm, animated mascot (Sammy the Turtle) peeking gently from a cozy shell.
    • Inputs:
        ◦ "What is your child's name or nickname?" (Large, high-contrast TextField).
        ◦ Age Selector Pills: 2-4 | 5-7 | 8-10.
    • Sensory Preset Toggles:
        ◦ [x] Low Motion Mode (Reduces particle speed by 50%).
        ◦ [x] Soft Lighting (Applies a warm color overlay).
        ◦ [x] Mute High Pitch (Filters sharp audio frequencies).
    • Primary Action: Large glowing "Enter SafeScape" pill button.
Screen 2: Main Sensory Hub
    • Visual Layout: Uncluttered grid with three primary visual cards:
        1. Calming Canvas: "Touch, drag, and relax with gentle waves."
        2. My Visual Routines: "Step-by-step guides for today's activities."
        3. Soothing Sounds: "Listen to warm rain and ambient hums."
    • Top Security Anchor: Lock icon leading to the Parent Zone (Requires a 3-second multi-finger hold or simple math gate).
Screen 3: "Flow Canvas" (Tactile Self-Regulation Screen)
    • Concept: Interactive fluid and particle simulation designed for tactile input and self-soothing.
    • User Mechanics:
        ◦ Touching or dragging across the screen creates smooth, glowing pastel waves that ripple and expand with physical fluid dynamics.
        ◦ Multi-touch support allows children to use both hands or full palms.
        ◦ Breathing Rhythm Ring: A translucent central circle expands and contracts slowly (4 seconds in, 6 seconds out), providing an optional visual breathing guide.
+-------------------------------------------------------------+
|  [Exit Home]                                  [Mute Sound]  |
|                                                             |
|                   .  :  *  .  :  *                          |
|                :   ( Smooth Glowing )   :                   |
|              *   (   Pastel Waves   )   *                   |
|                :   (    & Particles   )   :                 |
|                   '  :  *  .  :  *                          |
|                                                             |
|                     (( Breathing ))                         |
|                     ((   Circle    ))                       |
|                                                             |
|  +-------------------------------------------------------+  |
|  | [ Soft Ambient Drone Playing ]      [Reset Canvas]     |  |
|  +-------------------------------------------------------+  |
+-------------------------------------------------------------+
Screen 4: Visual Transition & Task Card Screen
    • Concept: Breaks complex daily activities into linear, manageable visual steps.
    • User Mechanics:
        1. Routine Selection: Child or parent selects a routine card (e.g., "Going to the Dentist" or "Bedtime Routine").
        2. Step-by-Step Progress: Each step is represented by a large vector card (e.g., Step 1: Put on Shoes $\rightarrow$ Step 2: Get in Car $\rightarrow$ Step 3: Sit in Waiting Room).
        3. Task Completion: Tapping a completed card triggers a gentle star burst animation and a warm marimba chime. Progress is displayed via a visual progress bar (e.g., 2 of 4 Steps Done).
+-------------------------------------------------------------+
|  [Back to Hub]        ROUTINE: CLINIC VISIT        [2/4 Done]|
|                                                             |
|   +---------------------+       +---------------------+     |
|   |   [ COMPLETED ]     |       |   [ CURRENT STEP ]  |     |
|   |   ( Shoe Icon )     |       |   ( Car Icon )      |     |
|   |  1. Put on shoes    |       |  2. Ride in car     |     |
|   +---------------------+       +---------------------+     |
|                                                             |
|   +---------------------+       +---------------------+     |
|   |    [ UPCOMING ]     |       |    [ UPCOMING ]     |     |
|   |  ( Waiting Room )   |       |   ( Doctor Icon )   |     |
|   |  3. Wait quietly    |       |  4. See Doctor      |     |
|   +---------------------+       +---------------------+     |
+-------------------------------------------------------------+
Screen 5: Parent & Therapist Control Dashboard
    • Security Gate: Protected behind a 3-second multi-touch hold gate to prevent accidental access by children.
    • Dashboard Features:
        1. Sensory Sensitivity Sliders: Adjust motion speed, audio pitch cutoff, particle density, and color temperature.
        2. Custom Routine Builder: Add custom routines, upload custom step images, or type custom step titles.
        3. Therapy Logs & Analytics: Displays session durations, soothing frequency, and routine completion rates.
Step 5: Visual Learning Curve & Progress Metrics for Parents
Parents and Occupational Therapists need clear, encouraging insights without clinical jargon. The Parent Dashboard presents data through the "Calm & Focus Horizon" metric map.
                CALM & FOCUS HORIZON MAP
                
  ( Total Self-Regulation Time )        ( Routine Completion Rate )
         [ 42 Minutes ]                       [ 85% Completed ]
               │                                      │
               ▼                                      ▼
┌──────────────────────────────┐       ┌──────────────────────────────┐
│  Weekly Usage Breakdown      │       │  Top Calming Modes           │
│  Mon: 12m  [■■■■■■]          │       │  1. Flow Canvas (Lavender)   │
│  Tue: 08m  [■■■■]            │       │  2. Rain Acoustic Drone      │
│  Wed: 15m  [■■■■■■■■]        │       │  3. Bedtime Visual Schedule  │
└──────────────────────────────┘       └──────────────────────────────┘
Metric Tracking Specification
    1. Regulation Session Duration: Tracks the total time a child engages with the Flow Canvas during dysregulation events.
    2. Transition Task Success Rate: Measures how many visual task steps are marked complete relative to initiated routines.
    3. Sensory Preference Matrix: Identifies which color palettes and audio frequency profiles yield the longest undisturbed engagement.
    4. Export to OT (PDF): One-tap generation of a clean PDF summary containing usage timelines and routine completion charts to share with pediatric OTs and behavioral therapists.
Step 6: Required Software Tools, Assets & Libraries
Core Technical Stack
Category
Tool / Library
Purpose & Justification
Framework
Flutter (Dart)
Fast rendering, strong cross-platform support, built-in vector support.
Animation Engine
Flutter CustomPainter / Flame Engine
Low-overhead vector rendering for real-time particle and fluid physics.
Backend / DB
Firebase Cloud Firestore
Offline-first database caching, anonymous auth, cross-device sync.
Vector Animations
lottie
Lightweight, high-performance vector character and button animations.
Data Analytics
fl_chart
Accessible charts for parent analytics and usage tracking.
State Management
flutter_riverpod
Reactive state management for real-time sensory setting adjustments.
Visual & Audio Asset Requirements
    1. Character Assets: Sammy the Turtle vector character (Idle, Sleeping, Celebrating, Shell-Tuck animations in Lottie JSON format).
    2. Iconography: High-contrast, friendly rounded SVG vectors for 30 standard routine activities (e.g., Toothbrush, Shoes, Backpack, Bus, Dentist, Bed, Mealtime).
    3. Audio Assets:
        ◦ Pre-filtered, seamless 30-second loop audio files (ambient_drone_low.wav, soft_rain_filtered.wav, marimba_chime_c4.wav).
        ◦ Low-frequency sound effects without high-frequency spikes.
Step 7: Complete Cloud Firestore Database Schema
The database uses an offline-first architecture. When offline, Firestore saves reads and writes to local cache memory, syncing with the cloud when internet access becomes available.
JSON
{
  "parents": {
    "ANONYMOUS_FIREBASE_UID_987": {
      "parent_email": null,
      "is_anonymous": true,
      "created_at": "2026-09-24T20:28:39Z",
      "last_login": "2026-09-24T20:28:39Z",
      "global_settings": {
        "audio_muted": false,
        "master_volume": 0.8,
        "parent_gate_type": "long_press"
      },
      "children": {
        "CHILD_ALIAS_ID_01": {
          "alias_name": "Sammy",
          "age_group": "5-7",
          "avatar_type": "turtle_sammy",
          "sensory_profile": {
            "low_motion_mode": true,
            "color_temperature": "warm_sand",
            "audio_cutoff_hz": 4000,
            "particle_density": 0.5,
            "haptic_feedback_enabled": false
          },
          "stats_summary": {
            "total_calming_minutes": 124,
            "routines_completed_count": 18,
            "favorite_mode": "flow_canvas"
          }
        }
      }
    }
  },
  "visual_routines": [
    {
      "routine_id": "ROUTINE_CLINIC_VISIT",
      "child_id": "CHILD_ALIAS_ID_01",
      "title": "Visiting the Doctor",
      "icon_key": "clinic_building",
      "created_at": "2026-09-24T20:28:39Z",
      "steps": [
        {
          "step_order": 1,
          "title": "Put on shoes",
          "icon_asset": "assets/icons/shoes.svg",
          "is_completed": true
        },
        {
          "step_order": 2,
          "title": "Ride in car",
          "icon_asset": "assets/icons/car.svg",
          "is_completed": true
        },
        {
          "step_order": 3,
          "title": "Wait in room",
          "icon_asset": "assets/icons/waiting_room.svg",
          "is_completed": false
        },
        {
          "step_order": 4,
          "title": "See the doctor",
          "icon_asset": "assets/icons/doctor.svg",
          "is_completed": false
        }
      ]
    }
  ],
  "sensory_sessions": [
    {
      "session_id": "SESS_20260924_001",
      "child_id": "CHILD_ALIAS_ID_01",
      "mode_used": "flow_canvas",
      "start_time": "2026-09-24T18:10:00Z",
      "duration_seconds": 420,
      "avg_touch_frequency": "slow_rhythmic",
      "preset_applied": "warm_sand"
    }
  ]
}





Summary:

### What is included in `sensory_safescape_gdd.md`: 1. **Step 1: Executive Summary & Rehab Objectives** * Detailed breakdown of the self-regulation layer, transition management system, and sensory control board. * Four core rehab objectives: Emotional Self-Regulation, Tactile/Visual Desensitization, Reducing Transition Anxiety, and Occupational Therapist Data Empowerment. 2. **Step 2: Architecture Strategy & Core Engineering Answers** * Guest-First Mode workflow with silent, anonymous Firebase authentication. * Cross-device cloud sync strategy and multi-child profile collection hierarchy under a single parent login. * Offline-first Cloud Firestore architecture rationale. 3. **Step 3: Sensory-Safe Design System & Accessibility Rules** * Deep slate base canvas (`#12131C`) with soft pastel accents and explicit rules on forbidden visual triggers. * Touch target specifications ($72 \times 72 \text{ dp}$) and predictable fluid gesture physics. * Acoustic frequency filtering ($>6\text{ kHz}$ cutoff) and sound ducking/mute controls. 4. **Step 4: Detailed Screen Workflows & Mockup Specifications** * **Screen 1:** Onboarding, child alias setup, and sensory preset toggles. * **Screen 2:** Uncluttered Main Sensory Hub with Parent Zone security gate. * **Screen 3:** Tactile "Flow Canvas" with fluid particle mechanics and breathing ring visual guide. * **Screen 4:** Visual Transition & Task Card screen with step-by-step task completion mechanics. * **Screen 5:** Parent & Therapist Control Dashboard with sensitivity sliders and custom routine builder. 5. **Step 5: Visual Learning Curve & Progress Metrics** * Comprehensive explanation of the **Calm & Focus Horizon** map. * Metrics covering regulation session durations, transition task success rates, sensory preference matrices, and one-tap PDF exports for OT clinic visits. 6. **Step 6: Required Software Tools, Assets & Libraries** * Complete technical stack table (Flutter, CustomPainter/Flame, Firebase, Lottie, Riverpod). * Detailed specifications for vector character animations (*Sammy the Turtle*), 30 activity icons, and pre-filtered acoustic audio loops. 7. **Step 7: Cloud Firestore Database Schema** * Complete JSON schema covering parent accounts, child profiles, sensory profiles, custom visual routines, and individual calming session tracking logs.
