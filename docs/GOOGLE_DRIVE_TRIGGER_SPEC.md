# Google Drive Trigger Enhancement Specification

## Overview
Enable automatic workflow execution when client discovery documents are uploaded to a specific Google Drive folder.

---

## Workflow Architecture

### Phase 1: Document Upload & Trigger
```
1. Client uploads discovery docs to monitored folder
2. Google Drive Trigger fires
3. Document processor extracts text/data
4. Data enrichment layer structures information
5. Enhanced workflow executes with rich context
```

---

## Node Structure

### NEW Node 0: Google Drive Trigger (Watch Folder)
**Type:** Google Drive Trigger
**Configuration:**
- Trigger: On File Created
- Folder: `/Client Discovery Uploads/`
- File Types: PDF, DOCX, XLSX, PPTX, TXT

**Output:** File metadata + binary content

---

### NEW Node 0.1: Document Type Router
**Type:** Switch
**Routes based on file type:**
- PDF → PDF Text Extractor
- DOCX → Word Extractor
- XLSX → Excel Parser
- PPTX → PowerPoint Extractor
- TXT → Direct text

---

### NEW Node 0.2: Text Extraction Nodes

**For PDFs:**
```javascript
// Extract text from PDF using pdf-parse
const pdfParse = require('pdf-parse');
const binary = $input.first().binary.data;
const buffer = Buffer.from(binary.data, 'base64');
const pdfData = await pdfParse(buffer);

return [{
  json: {
    content: pdfData.text,
    pages: pdfData.numpages,
    file_name: $input.first().json.name
  }
}];
```

**For DOCX:**
```javascript
// Extract text from Word using mammoth
const mammoth = require('mammoth');
const buffer = Buffer.from($input.first().binary.data.data, 'base64');
const result = await mammoth.extractRawText({buffer});

return [{
  json: {
    content: result.value,
    file_name: $input.first().json.name
  }
}];
```

**For Excel (Process Mapping, Tech Stack):**
```javascript
// Parse Excel to structured data
const XLSX = require('xlsx');
const buffer = Buffer.from($input.first().binary.data.data, 'base64');
const workbook = XLSX.read(buffer);

// Extract sheets
const sheets = {};
workbook.SheetNames.forEach(name => {
  sheets[name] = XLSX.utils.sheet_to_json(workbook.Sheets[name]);
});

return [{
  json: {
    sheets,
    file_name: $input.first().json.name
  }
}];
```

---

### NEW Node 0.3: Discovery Data Analyzer (GPT-4o)
**Purpose:** Structure the uploaded discovery data into usable format

**Prompt:**
```
You are analyzing client discovery documentation.

Extract and structure the following:

1. **Process Inventory**
   - List all business processes mentioned
   - Current state description
   - Pain points
   - Manual vs automated percentage

2. **Technology Stack**
   - All tools/systems mentioned
   - Purpose of each
   - Integration points
   - Costs (if mentioned)

3. **Organizational Structure**
   - Teams/departments
   - Roles mentioned
   - Reporting structure
   - Headcount

4. **KPIs & Metrics**
   - Any metrics mentioned
   - Current performance
   - Target performance

5. **Business Context**
   - Industry/sector
   - Strategic priorities
   - Challenges
   - Goals

Document Content:
```
{{ $json.content }}
```

Return ONLY valid JSON:
{
  "processes": [...],
  "technology_stack": [...],
  "organization": {...},
  "kpis": [...],
  "business_context": {...}
}
```

**Output:** Structured discovery data

---

### NEW Node 0.4: Data Enrichment Layer
**Purpose:** Merge uploaded data with Google Sheets data

```javascript
// Merge uploaded discovery data with sheets data
const discoveryData = $('Discovery Data Analyzer').first().json;
const sheetsData = {
  raci: $('1.2 Google Sheets - RACI Matrix').all(),
  tools: $('1.3 Google Sheets - Tool Inventory').all(),
  kpis: $('1.4 KPI Snapshot - Sheets').all()
};

// Enrich sheets data with discovery insights
const enrichedData = {
  processes: [
    ...sheetsData.raci,
    ...discoveryData.processes.map(p => ({
      source: 'discovery_doc',
      ...p
    }))
  ],
  tools: [
    ...sheetsData.tools,
    ...discoveryData.technology_stack
  ],
  kpis: {
    ...sheetsData.kpis,
    ...discoveryData.kpis
  },
  context: discoveryData.business_context
};

return [{ json: enrichedData }];
```

---

### ENHANCED Node 2.1: Data Cleaner (Updated)
**Now accepts both sheets + discovery data**

```javascript
// Process discovery data in addition to sheets
const discoveryProcesses = items.filter(i => i.json.source === 'discovery_doc');
const sheetsProcesses = items.filter(i => i.json.source !== 'discovery_doc');

// Merge and deduplicate
currentModelData.org_structure = [
  ...sheetsProcesses.map(processSheet),
  ...discoveryProcesses.map(processDiscovery)
];

// Add business context to all analysis
currentModelData.business_context = {
  industry: discoveryData?.business_context?.industry || 'Unknown',
  strategic_priorities: discoveryData?.business_context?.priorities || [],
  challenges: discoveryData?.business_context?.challenges || []
};
```

---

### ENHANCED Analysis Prompts
**All LLM nodes get enriched context**

**Example - Enhanced 2.2 Inefficiency Scorer:**
```
Client: {{ $json.client_name }}
Industry: {{ $json.business_context.industry }}
Strategic Priorities: {{ $json.business_context.strategic_priorities.join(', ') }}

Current Challenges:
{{ $json.business_context.challenges.join('\n') }}

Analyze inefficiencies in light of:
- Industry best practices
- Strategic priorities alignment
- Documented pain points from discovery

Data:
```json
{{ JSON.stringify($json.org_structure, null, 2) }}
```

Return detailed inefficiency analysis...
```

---

## Data Quality Tiers

### Tier 1: Basic (Sheets Only)
- Uses Google Sheets RACI, Tools, KPIs
- Generic analysis
- Fallback sample data if empty
- **Current state**

### Tier 2: Enhanced (Sheets + Simple Upload)
- Sheets data + basic document upload
- Text extraction only
- Manual mapping to structure
- **Better context**

### Tier 3: Premium (Sheets + Structured Discovery)
- Comprehensive discovery documents
- Automated structuring via GPT-4o
- Rich business context
- Industry benchmarks
- **Consultant-grade input → Consultant-grade output**

---

## Document Templates for Clients

**Recommended Upload Documents:**

1. **Process Mapping Document**
   - Current state process flows
   - Roles and responsibilities
   - Pain points and bottlenecks
   - Volume metrics

2. **Technology Stack Analysis**
   - List of all tools/systems
   - Purpose and ownership
   - Integration landscape
   - Costs and contracts

3. **Organizational Chart**
   - Structure diagram
   - Headcount by function
   - Reporting lines

4. **KPI Dashboard Export**
   - Current performance metrics
   - Historical trends
   - Target metrics

5. **Strategic Plan Summary**
   - Business priorities
   - Transformation goals
   - Timeline and milestones

---

## Folder Structure

```
Google Drive: /Client Discovery Uploads/
├── /Hogarth_Worldwide/
│   ├── Process_Mapping_2026.pdf
│   ├── Tech_Stack_Analysis.xlsx
│   ├── Org_Chart.pptx
│   └── KPI_Dashboard_Export.pdf
├── /Client_Name_2/
│   └── ...
└── /Templates/
    ├── Process_Mapping_Template.docx
    ├── Tech_Stack_Template.xlsx
    └── Discovery_Questionnaire.pdf
```

**Workflow Logic:**
- Watches `/Client Discovery Uploads/` folder
- Detects client name from folder structure
- Processes all files for that client
- Auto-sets client_name in workflow

---

## Implementation Steps

### Phase 1: Basic Trigger (Week 1)
1. Add Google Drive Trigger node
2. Add simple text extraction
3. Pass to existing workflow
4. Test with sample documents

### Phase 2: Smart Parsing (Week 2-3)
1. Add GPT-4o discovery analyzer
2. Structure extraction prompts
3. Merge with sheets data
4. Enhanced LLM prompts

### Phase 3: Multi-Document (Week 4)
1. Handle multiple files per client
2. Aggregate across documents
3. Conflict resolution
4. Quality scoring

---

## Cost Impact

**Additional GPT-4o costs:**
- Document analysis: 10,000-15,000 tokens per doc
- Cost: ~$0.15-$0.30 per document
- Total per client: ~$0.50-$1.00 (for 3-5 docs)

**New total cost:**
- Document processing: $0.50-$1.00
- Premium report: $0.99
- **Total: $1.49-$1.99 per audit**

Still 0.003% - 0.01% of consulting value.

---

## Benefits

✅ **Zero manual data entry** - Upload docs, get report
✅ **Richer analysis** - More context = better insights
✅ **Client-friendly** - Send discovery template, upload, done
✅ **Scalable** - Process hundreds of clients
✅ **Audit trail** - All source docs stored in Drive

---

## Example Client Flow

1. **Sales sends discovery template** to client
2. **Client fills out and uploads** to shared Drive folder
3. **Workflow auto-triggers** on upload
4. **Analysis runs** with rich context (2-3 min)
5. **Premium report delivered** to client Drive + Sheets
6. **Notification sent** to client via Slack/Email

**Total time: 3 minutes** (vs 2-4 weeks for traditional consulting)

---

**Next Steps:**
Would you like me to build this Google Drive trigger enhancement?
