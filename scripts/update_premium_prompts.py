#!/usr/bin/env python3
"""
Update Premium Workflow Prompts
Enhances all analysis and report nodes with detailed, table-rich prompts
"""

import json

# Read workflow
with open('workflows/workflow_premium_report.json', 'r') as f:
    workflow = json.load(f)

# Enhanced Prompts
PROMPTS = {
    "2.2 Inefficiency Scorer": """You are a senior management consultant analyzing operational inefficiencies.

Client: {{ $json.client_name }}

Analyze the operating model data below and identify 8-12 specific inefficiencies.

Data:
```json
{{ JSON.stringify({
  processes: $json.org_structure,
  tools: $json.tools,
  kpis: $json.kpis
}, null, 2) }}
```

For each inefficiency, provide:
- **Category**: redundancy, bottleneck, manual_dependency, communication_gap, tool_sprawl, quality_issue
- **Description**: 2-3 sentence detailed explanation
- **Affected Process**: Which process is impacted
- **Root Cause**: Why this inefficiency exists
- **Annual Cost**: Estimated cost ($) - be realistic
- **Urgency**: Low, Medium, High, Very High
- **Automation Readiness** (1-10): How ready for AI automation
- **Impact Potential** (1-10): Business impact if fixed
- **Risk Level** (1-10): Risk of making the change

Return ONLY valid JSON:
{
  "inefficiencies": [
    {
      "category": "manual_dependency",
      "description": "Detailed description...",
      "affected_process": "Process name",
      "root_cause": "Why it exists",
      "annual_cost": 35000,
      "urgency": "High",
      "automation_readiness": 8,
      "impact_potential": 9,
      "risk_level": 3
    }
  ],
  "total_inefficiency_cost": 185000,
  "summary": "2-3 sentence overall summary"
}""",

    "2.3 AI Fit Mapper": """You are an AI transformation strategist identifying automation opportunities.

Client: {{ $('2.1 Data Cleaner').first().json.client_name }}

Operating Model Data:
- Processes: {{ $('2.1 Data Cleaner').first().json.org_structure.length }}
- Tools: {{ $('2.1 Data Cleaner').first().json.tools.length }}
- Manual processes: {{ $('2.1 Data Cleaner').first().json.org_structure.filter(p => p.manual_pct > 50).map(p => p.process).join(', ') }}

Identify 7-10 specific, high-value AI use cases for this client.

Return ONLY valid JSON:
{
  "overall_summary": {
    "headline": "One sentence transformation opportunity",
    "current_state": "2-3 sentences on current limitations",
    "ai_opportunity_theme": "Main AI opportunity area"
  },
  "use_cases": [
    {
      "id": "UC01",
      "title": "Specific use case title",
      "short_description": "2-3 sentences",
      "detailed_description": "4-5 sentences explaining how it works",
      "ai_technologies": ["GPT-4o", "Computer Vision", "NLP"],
      "processes_impacted": ["Process 1", "Process 2"],
      "readiness_level": "ready_now",
      "impact_score_1_to_5": 5,
      "complexity_score_1_to_5": 2,
      "estimated_annual_saving": 75000,
      "implementation_timeline_months": 3
    }
  ]
}""",

    "3.1 Blueprint Generator": """You are an enterprise architect designing AI-enabled operating models.

Client: {{ $('Set Client Config').first().json.client_name }}

Context:
- Inefficiencies found: {{ $('Parse Inefficiency Response').first().json.inefficiencies?.length || 0 }}
- AI use cases identified: {{ $('Parse AI Fit Response').first().json.use_cases?.length || 0 }}

Design a comprehensive future-state operating model.

Return ONLY valid JSON with detailed data:
{
  "organization_structure": {
    "model_type": "Hub-and-Spoke",
    "description": "2-3 sentences explaining the model",
    "new_roles": [
      {
        "role": "AI Agent Supervisor",
        "team": "Technology",
        "description": "Detailed role description",
        "reports_to": "CTO",
        "key_responsibilities": ["Resp 1", "Resp 2"]
      }
    ],
    "roles_to_retire": ["Manual QA Analyst", "Data Entry Coordinator"]
  },
  "ai_agents": [
    {
      "agent_name": "Content Generation Agent",
      "platform": "GPT-4o",
      "responsibilities": "Detailed responsibilities",
      "triggers": "What triggers this agent",
      "outputs": "What it produces",
      "integrations": ["System 1", "System 2"],
      "human_touchpoints": "When humans are involved",
      "automation_level": "85%"
    }
  ],
  "n8n_workflows": [
    {
      "workflow_name": "Content Lifecycle Automation",
      "purpose": "End-to-end content workflow",
      "trigger": "New brief submitted",
      "steps": "Generate → Translate → QA → Notify",
      "systems_connected": ["Production Studio", "Supabase", "DAM"],
      "frequency": "Real-time",
      "estimated_time_saving_per_execution": "4 hours"
    }
  ],
  "raci_matrix": [
    {
      "process": "Content Creation",
      "responsible": "Content Generation Agent",
      "accountable": "Content Strategist",
      "consulted": "Localization Manager",
      "informed": "Project Manager",
      "automation_level": "85%"
    }
  ],
  "tools_to_retire": [
    {"tool": "Google Sheets", "reason": "Replaced by automation", "annual_saving": 50000}
  ],
  "tools_to_add": [
    {"tool": "n8n Enterprise", "purpose": "Workflow orchestration", "annual_cost": 12000}
  ],
  "technology_architecture": {
    "orchestration_layer": "n8n",
    "data_layer": "Supabase",
    "ai_layer": "GPT-4o, GPT-4o Vision",
    "integration_layer": "n8n + APIs",
    "key_integrations": ["Production Studio", "DAM", "CRM"]
  }
}""",

    "3.4a Exec Overview": """You are a senior consultant writing an executive overview for a C-suite audience.

Client: {{ $('Set Client Config').first().json.client_name }}

Financial Impact (Hybrid Scenario):
- 3-Year ROI: {{ $('3.2 ROI Simulator').first().json.scenarios.hybrid.three_year_roi }}%
- Annual Savings: ${{ $('3.2 ROI Simulator').first().json.scenarios.hybrid.annual_saving }}
- Implementation Cost: ${{ $('3.2 ROI Simulator').first().json.scenarios.hybrid.implementation_cost }}
- FTE Saved: {{ $('3.2 ROI Simulator').first().json.scenarios.hybrid.fte_saved }}
- Payback: {{ $('3.2 ROI Simulator').first().json.scenarios.hybrid.payback_period_months }} months
- Efficiency Gain: {{ $('3.2 ROI Simulator').first().json.scenarios.hybrid.efficiency_gain_pct }}%

Write a comprehensive **Section 1: EXECUTIVE OVERVIEW** (1,000-1,500 words) with these subsections:

### 1.1 Situation Analysis
- Current operating model challenges
- Market context and competitive pressure
- Why change is needed now

### 1.2 Transformation Opportunity
- What AI enablement can achieve
- Strategic alignment with business priorities
- Unique advantages for this organization

### 1.3 Recommended Approach
- Why Hybrid scenario is optimal
- 4-phase transformation approach
- Critical success factors

### 1.4 Expected Business Impact
Present this as a formatted markdown list:
- **3-Year ROI:** X%
- **Annual Savings:** $X
- **Implementation Investment:** $X
- **Payback Period:** X months
- **FTE Optimization:** X FTEs
- **Efficiency Gain:** X%

Write in a confident, professional consulting tone. Be specific with numbers and timeframes.""",

    "3.4b Current State": """You are a senior consultant analyzing current state operations.

Client: {{ $('Set Client Config').first().json.client_name }}

Inefficiencies Data:
{{ JSON.stringify($('Parse Inefficiency Response').first().json.inefficiencies, null, 2) }}

Write **Section 2: CURRENT STATE ASSESSMENT** (1,200-1,800 words):

### 2.1 Operating Model Maturity
- Current maturity level ("Walk" stage)
- Key characteristics of current state
- Comparison to industry leaders
- Capability gaps

### 2.2 Key Inefficiencies & Pain Points
Create a detailed markdown table:

| Inefficiency | Description | Annual Cost | Root Cause | Urgency |
|--------------|-------------|-------------|------------|---------|
| Row 1 data | ... | ... | ... | ... |

Then analyze:
- Patterns across inefficiencies
- Systemic issues
- Total cost of inefficiency: $XXX,XXX annually

### 2.3 Cost of Inaction
- 3-year cost if nothing changes: $XXX,XXX
- Competitive risks
- Strategic risks
- Employee satisfaction impacts

Use specific data from the inefficiencies. Be quantitative.""",

    "3.4c Future State": """You are a senior consultant designing future state operating models.

Client: {{ $('Set Client Config').first().json.client_name }}

Blueprint Data:
{{ JSON.stringify($('Parse Blueprint').first().json, null, 2) }}

AI Use Cases:
{{ $('Parse AI Fit Response').first().json.use_cases?.length || 0 }} use cases identified

Write **Section 3: FUTURE STATE VISION** (2,000-2,500 words):

### 3.1 AI-Enabled Operating Model Overview
- Hub-and-Spoke structure explained
- How AI agents fit into the organization
- Human-AI collaboration model

### 3.2 Core Capabilities Enabled
- Intelligent Automation
- Enhanced Quality & Speed
- Scalability & Flexibility
- Data-Driven Decision Making
- Workflow Orchestration
- Tool Consolidation
- Human-AI Collaboration

### 3.3 AI Agents & Automation Architecture
Create this markdown table:

| Agent Name | Platform | Responsibilities | Triggers | Outputs | Integrations | Human Touchpoints |
|------------|----------|------------------|----------|---------|--------------|-------------------|
| Data here | ... | ... | ... | ... | ... | ... |

### 3.4 n8n Workflow Automation
Create this table:

| Workflow Name | Purpose | Trigger | Steps | Systems Connected | Frequency |
|---------------|---------|---------|-------|-------------------|-----------|
| Data | ... | ... | ... | ... | ... |

### 3.5 New RACI Matrix
Create this table:

| Process | Responsible | Accountable | Consulted | Informed | Automation Level |
|---------|-------------|-------------|-----------|----------|------------------|
| Data | ... | ... | ... | ... | 85% |

Include:
- **New Roles:** AI Agent Supervisor, Automation Specialist
- **Eliminated Roles:** Manual QA Analyst, etc.

Be comprehensive and specific. Use actual data from the blueprint.""",

    "3.4d Governance": """You are a senior consultant defining governance and next steps.

Client: {{ $('Set Client Config').first().json.client_name }}

Write **Sections 4-8** (total 2,000-2,500 words):

## 4. FINANCIAL ANALYSIS & ROI

### 4.1 Investment Required
Markdown table:
| Category | Cost |
|----------|------|
| Technology Licenses | $50,000 |
| Total | $XXX,XXX |

### 4.2 Expected Benefits
Table showing benefit breakdown

### 4.3 ROI Scenarios
Table with Cautious, Hybrid, Aggressive scenarios

### 4.4 Recommendation
Why Hybrid is optimal

---

## 5. IMPLEMENTATION ROADMAP

### 5.1 Phase 1: Quick Wins (0-3 months)
- Objectives
- Key Deliverables
- Success Metrics

### 5.2 Phase 2: Foundation (3-9 months)
Same structure

### 5.3 Phase 3: Scale (9-18 months)
Same structure

### 5.4 Phase 4: Optimize (18-24 months)
Same structure

---

## 6. RISKS & MITIGATION

### 6.1 Key Risks
By category: Technical, Organizational, Operational, External

### 6.2 Mitigation Strategies
Table:
| Risk | Mitigation | Owner | Timeline |
|------|------------|-------|----------|

---

## 7. GOVERNANCE & DECISION FRAMEWORK

### 7.1 Program Governance
- Steering Committee composition
- Decision rights
- Review cadence

### 7.2 Success Metrics & KPIs
List of KPIs to track

---

## 8. NEXT STEPS & CALL TO ACTION

### 8.1 Immediate Actions (Next 30 Days)
Numbered list

### 8.2 Decision Points
What needs approval

### 8.3 Timeline to Value
Week-by-week timeline

Be comprehensive, specific, and actionable."""
}

# Update prompts
updates_made = 0
for node in workflow['nodes']:
    node_name = node.get('name', '')
    if node_name in PROMPTS:
        if 'parameters' in node and 'messages' in node['parameters']:
            # Find the content message
            for msg in node['parameters']['messages']['values']:
                if 'content' in msg and not msg.get('role'):
                    msg['content'] = '=' + PROMPTS[node_name]
                    updates_made += 1
                    print(f"✅ Updated prompt: {node_name}")
                    break

# Save
with open('workflows/workflow_premium_report.json', 'w') as f:
    json.dump(workflow, f, indent=2)

print(f"\n✅ Updated {updates_made} node prompts for premium quality")
