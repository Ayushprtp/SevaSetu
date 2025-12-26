# SevaSetu System Flowchart - Image Generator Prompt

## Prompt for Detailed Flowchart Generation

---

**Create a detailed, professional flowchart diagram for the SevaSetu Civic Issue Management System with the following specifications:**

### Visual Style Requirements:
- Modern, clean design with rounded rectangles for processes
- Use a consistent color scheme:
  - **Blue (#2196F3)** for user actions and inputs
  - **Green (#4CAF50)** for AI/automated processes
  - **Orange (#FF9800)** for decision points
  - **Red (#F44336)** for emergency/escalation paths
  - **Purple (#9C27B0)** for department routing
  - **Teal (#009688)** for office assignment
  - **Gray (#607D8B)** for data storage/database
- Clear directional arrows with labels where needed
- Hierarchical top-to-bottom flow with left-right branching for parallel processes
- Include icons where appropriate (camera, AI brain, calculator, building, alert)

---

### Main Flow Structure:

**SECTION 1: CITIZEN INPUT (Top - Blue)**
```
START → Citizen Opens App → Captures/Uploads Image → Enters Location (GPS/Manual) → Adds Description → Submit Issue
```

**SECTION 2: AI ANALYSIS PIPELINE (Green)**
```
Image Upload → Pre-Processing (resize, validate) → AI Model Analysis (Gemini/GPT-4V) → Generate Structured Output
                                                                                              ↓
                                                                    ┌─────────────────────────────────────┐
                                                                    │ AI Analysis Output:                 │
                                                                    │ • Detected Category                 │
                                                                    │ • Confidence Score (0-1)            │
                                                                    │ • Severity Level                    │
                                                                    │ • Population Impact                 │
                                                                    │ • Hazard Indicators                 │
                                                                    │ • Affected Area (sqm)               │
                                                                    └─────────────────────────────────────┘
```
Include a decision diamond: "AI Analysis Successful?" → Yes continues, No → "Manual Category Selection"

**SECTION 3: PRIORITY CALCULATION (Orange/Yellow)**
Show 6 parallel input streams merging into Priority Calculator:
```
┌──────────────────┐
│ SEVERITY SCORE   │ (30% weight, max 30 pts)
│ CRITICAL=30      │
│ HIGH=24          │
│ MEDIUM=15        │
│ LOW=8            │
└────────┬─────────┘
         │
┌────────┴─────────┐
│ POPULATION SCORE │ (25% weight, max 25 pts)
│ + Location       │
│   Multipliers    │
│ (School=2x,      │
│  Hospital=2x,    │
│  Main Road=1.8x) │
└────────┬─────────┘
         │
┌────────┴─────────┐
│ CATEGORY URGENCY │ (15% weight, max 15 pts)
│ POWER_CUT=15     │
│ WATER_LEAK=14    │
│ POTHOLE=12       │
│ STREETLIGHT=10   │
│ GARBAGE=8        │
└────────┬─────────┘
         │
┌────────┴─────────┐
│ COMMUNITY SCORE  │ (15% weight, max 15 pts)
│ Logarithmic      │
│ scaling of       │
│ upvotes          │
└────────┬─────────┘
         │
┌────────┴─────────┐
│ TIME FACTOR      │ (10% weight, max 10 pts)
│ <24hrs=10        │
│ 1-3 days=8       │
│ 3-7 days=6       │
│ 7-14 days=7      │
│ 14-30 days=8     │
│ >30 days=10      │
└────────┬─────────┘
         │
┌────────┴─────────┐
│ AI CONFIDENCE    │ (5% weight, max 5 pts)
│ Bonus if >0.8    │
└────────┬─────────┘
         │
         ▼
┌─────────────────────────┐
│   PRIORITY CALCULATOR   │
│   Final Score: 0-100    │
└─────────────────────────┘
```

**SECTION 4: CHAOS/EMERGENCY DETECTION (Red)**
```
AI Analysis → Chaos Score Calculator
                    │
    ┌───────────────┼───────────────┐
    │               │               │
    ▼               ▼               ▼
Hazard Count   Severity Bonus   Population Bonus
(+0.1 each)    CRITICAL=+0.3    CRITICAL=+0.25
               HIGH=+0.2        HIGH=+0.15
                    │
                    ▼
         Special Hazard Bonuses:
         • Flooding: +0.15
         • Traffic Blocked: +0.1
         • Structural Damage: +0.2
         • Fire Hazard: +0.3
                    │
                    ▼
            CHAOS SCORE (0.0-1.0)
                    │
    ┌───────────────┼───────────────┬───────────────┐
    │               │               │               │
    ▼               ▼               ▼               ▼
≥0.8            ≥0.6            ≥0.4            <0.4
EMERGENCY       HIGH PRIORITY   ELEVATED        NORMAL
    │               │               │               │
    ▼               ▼               ▼               ▼
• State Admin   • District      • Flag for      Continue
  Notification    Admin Alert     Review        Normal Flow
• Auto-Assign   • Fast-Track    • Priority
• Priority=100    Assignment      Boost +20
```

**SECTION 5: DEPARTMENT ROUTING (Purple)**
```
Issue Category → Department Router
                      │
    ┌─────────────────┼─────────────────┐─────────────────┐─────────────────┐
    │                 │                 │                 │                 │
    ▼                 ▼                 ▼                 ▼                 ▼
POTHOLE          GARBAGE          STREETLIGHT      WATER_LEAK         OTHER
DRAINAGE         SEWAGE           POWER_CUT
    │                 │                 │                 │                 │
    ▼                 ▼                 ▼                 ▼                 ▼
┌───────┐       ┌───────────┐    ┌───────────┐    ┌───────┐       ┌─────────┐
│  PWD  │       │ SANITATION│    │ELECTRICITY│    │ WATER │       │ GENERAL │
└───────┘       └───────────┘    └───────────┘    └───────┘       └─────────┘
```

**SECTION 6: OFFICE ASSIGNMENT (Teal)**
```
Department + District + Location
            │
            ▼
┌─────────────────────────────┐
│ Find District Offices       │
│ for Department              │
└─────────────────────────────┘
            │
            ▼
    ┌───────────────┐
    │ Offices Found?│
    └───────┬───────┘
        Yes │ No
            │   │
            │   ▼
            │ ┌─────────────────────────────┐
            │ │ Find State-Level Offices    │
            │ │ Mark as ESCALATED           │
            │ └─────────────────────────────┘
            │   │
            ▼   ▼
┌─────────────────────────────┐
│ Calculate Distance to Each  │
│ Office from Issue Location  │
└─────────────────────────────┘
            │
            ▼
┌─────────────────────────────┐
│ Select NEAREST Office       │
└─────────────────────────────┘
            │
            ▼
┌─────────────────────────────┐
│ Assignment Result:          │
│ • Office ID                 │
│ • Escalated: true/false     │
│ • Distance                  │
└─────────────────────────────┘
```

**SECTION 7: ADMINISTRATIVE HIERARCHY (Right Side - Vertical)**
```
┌─────────────────────────────────────┐
│           STATE LEVEL               │
│  • State Admin Dashboard            │
│  • Cross-district analytics         │
│  • Policy decisions                 │
│  • Emergency escalation endpoint    │
└─────────────────────────────────────┘
                  ↑ Escalation
┌─────────────────────────────────────┐
│         DEPARTMENT LEVEL            │
│  • PWD, Sanitation, Electricity     │
│  • Water, General                   │
│  • Resource allocation              │
│  • Performance monitoring           │
└─────────────────────────────────────┘
                  ↑ Escalation
┌─────────────────────────────────────┐
│       DISTRICT/OFFICE LEVEL         │
│  • Local government offices         │
│  • Direct issue assignment          │
│  • Field worker management          │
└─────────────────────────────────────┘
                  ↑ Assignment
┌─────────────────────────────────────┐
│        FIELD WORKER LEVEL           │
│  • On-ground resolution             │
│  • Status updates                   │
│  • Photo verification               │
│  • Citizen communication            │
└─────────────────────────────────────┘
```

**SECTION 8: HIGH PRIORITY DETERMINATION (Decision Diamond)**
```
            ┌─────────────────────────┐
            │ HIGH PRIORITY CHECK     │
            └───────────┬─────────────┘
                        │
    ┌───────────────────┼───────────────────┐
    │                   │                   │
    ▼                   ▼                   ▼
Score > 70?      Severity=CRITICAL?   Chaos ≥ 0.7?
    │                   │                   │
    └───────────────────┼───────────────────┘
                        │
                   ANY TRUE?
                   /        \
                 Yes         No
                  │           │
                  ▼           ▼
         ┌──────────────┐  ┌──────────────┐
         │ HIGH PRIORITY│  │   NORMAL     │
         │    FLAG      │  │   QUEUE      │
         └──────────────┘  └──────────────┘
```

**SECTION 9: RESOLUTION FLOW (Bottom)**
```
Office Receives Issue → Admin Reviews → Assigns Field Worker → Worker Travels to Site
                                                                        │
                                                                        ▼
                                                              ┌─────────────────┐
                                                              │ Issue Resolution│
                                                              │ • Fix Problem   │
                                                              │ • Take Photos   │
                                                              │ • Update Status │
                                                              └─────────────────┘
                                                                        │
                                                                        ▼
                                                              ┌─────────────────┐
                                                              │  Verification   │
                                                              │ • Before/After  │
                                                              │ • Citizen       │
                                                              │   Confirmation  │
                                                              └─────────────────┘
                                                                        │
                                                                        ▼
                                                              ┌─────────────────┐
                                                              │ Issue RESOLVED  │
                                                              │ • Close Ticket  │
                                                              │ • Update Stats  │
                                                              │ • Notify Citizen│
                                                              └─────────────────┘
```

---

### Additional Elements to Include:

1. **Legend Box** (bottom right):
   - Color coding explanation
   - Shape meanings (rectangle=process, diamond=decision, parallelogram=input/output)
   - Arrow types (solid=main flow, dashed=escalation)

2. **Data Flow Indicators**:
   - Show database symbols for: Issues DB, Offices DB, Users DB
   - API call indicators between AI service and main system

3. **Feedback Loops**:
   - Upvote mechanism feeding back to priority recalculation
   - Escalation timeout triggers (if unresolved after X days)

4. **Title and Metadata**:
   - Title: "SevaSetu - Civic Issue Management System Flow"
   - Subtitle: "AI-Powered Hierarchical Issue Resolution"
   - Version indicator

---

### Output Format:
- High resolution (minimum 4000x6000 pixels)
- Clean white background
- Professional infographic style
- Suitable for technical documentation
- Include subtle grid lines for alignment reference

---

**Generate a comprehensive, visually appealing flowchart that clearly illustrates the complete lifecycle of a civic issue from citizen report to resolution, highlighting the AI analysis, priority calculation, department routing, and hierarchical escalation mechanisms.**
