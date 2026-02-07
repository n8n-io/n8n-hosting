# n8n Workflow Implementation Guide

This guide provides step-by-step instructions for building the three critical workflows needed for the mass production pipeline.

## Prerequisites

- n8n Cloud account (or self-hosted n8n)
- Airtable Personal Access Token configured in n8n credentials
- fal.ai API key configured in n8n credentials
- Bannerbear API key configured in n8n credentials

## Workflow 1: pipeline-start (Single Record Pipeline)

**Purpose:** Process a single Airtable record through the full creative pipeline.

**Webhook URL:** `https://williamsforeal.app.n8n.cloud/webhook/pipeline-start`

**Expected Input:**
```json
{
  "recordId": "recXXXXXXXXXXXXXX",
  "skipOverlay": false,
  "format": "square",
  "highQuality": false
}
```

**Expected Output:**
```json
{
  "pipelineId": "pipeline-{timestamp}-{recordId}",
  "status": "queued",
  "estimatedTime": 45
}
```

### Step-by-Step Workflow Construction

#### Node 1: Webhook (Trigger)
- **Type:** Webhook
- **Method:** POST
- **Path:** `pipeline-start`
- **Response Mode:** Respond to Webhook
- **Output:** `{{ $json }}`

#### Node 2: Extract Parameters
- **Type:** Code
- **Code:**
```javascript
const recordId = $input.item.json.body.recordId;
const skipOverlay = $input.item.json.body.skipOverlay || false;
const format = $input.item.json.body.format || 'square';
const highQuality = $input.item.json.body.highQuality || false;
const pipelineId = `pipeline-${Date.now()}-${recordId}`;

return {
  recordId,
  skipOverlay,
  format,
  highQuality,
  pipelineId,
  startTime: Date.now()
};
```

#### Node 3: Fetch Airtable Record
- **Type:** HTTP Request
- **Method:** GET
- **URL:** `https://api.airtable.com/v0/{{ $env.AIRTABLE_BASE_ID }}/{{ $env.AIRTABLE_TABLE_ID }}/{{ $json.recordId }}`
- **Authentication:** Generic Credential Type
  - **Type:** Header Auth
  - **Name:** Authorization
  - **Value:** `Bearer {{ $env.AIRTABLE_PAT }}`
- **Headers:**
  - `Content-Type: application/json`

**Expected Response Structure:**
```json
{
  "id": "rec...",
  "fields": {
    "Full Concept": "...",
    "Headline": "...",
    "CTA": "...",
    "Generate Image Prompts": "Done",
    "Image Prompts": ["prompt1", "prompt2", ...]
  }
}
```

#### Node 4: Extract Prompt and Copy
- **Type:** Code
- **Code:**
```javascript
const record = $input.item.json;
const fields = record.fields;

// Get the first prompt from Image Prompts array, or use Full Concept
const prompt = (fields['Image Prompts'] && fields['Image Prompts'].length > 0) 
  ? fields['Image Prompts'][0] 
  : fields['Full Concept'] || '';

const headline = fields['Headline'] || fields['Full Concept'] || '';
const cta = fields['CTA'] || 'Shop Now';
const format = $('Extract Parameters').item.json.format;

// Determine dimensions based on format
const dimensions = {
  square: { width: 1080, height: 1080 },
  story: { width: 1080, height: 1920 },
  landscape: { width: 1200, height: 628 }
}[format] || { width: 1080, height: 1080 };

return {
  ...$('Extract Parameters').item.json,
  prompt: prompt,
  headline: headline,
  cta: cta,
  width: dimensions.width,
  height: dimensions.height,
  recordFields: fields
};
```

#### Node 5: Generate Image with fal.ai
- **Type:** HTTP Request
- **Method:** POST
- **URL:** `https://fal.run/fal-ai/flux/schnell`
- **Authentication:** Generic Credential Type
  - **Type:** Header Auth
  - **Name:** Authorization
  - **Value:** `Key {{ $env.FAL_API_KEY }}`
- **Body (JSON):**
```json
{
  "prompt": "{{ $json.prompt }}, clean composition, no text, no watermark, no logo, professional photography",
  "negative_prompt": "text, words, letters, watermark, logo, signature, writing, captions, subtitles, blurry, low quality",
  "image_size": {
    "width": {{ $json.width }},
    "height": {{ $json.height }}
  },
  "num_images": 1,
  "num_inference_steps": 28,
  "guidance_scale": 7.5
}
```

**Expected Response:**
```json
{
  "images": [
    {
      "url": "https://fal.media/files/...",
      "width": 1080,
      "height": 1080
    }
  ],
  "seed": 12345
}
```

#### Node 6: Check if Overlay Needed
- **Type:** IF
- **Condition:** `{{ $json.skipOverlay }}` equals `false`

**True Branch (Apply Bannerbear Overlay):**

#### Node 7: Prepare Bannerbear Request
- **Type:** Code
- **Code:**
```javascript
const falResult = $('Generate Image with fal.ai').item.json;
const baseImageUrl = falResult.images[0].url;
const params = $('Extract Prompt and Copy').item.json;

// Get template ID based on format (these should match your Bannerbear templates)
const templateIds = {
  square: '{{ $env.BANNERBEAR_TEMPLATE_SQUARE }}',
  story: '{{ $env.BANNERBEAR_TEMPLATE_STORY }}',
  landscape: '{{ $env.BANNERBEAR_TEMPLATE_LANDSCAPE }}'
};

const templateId = templateIds[params.format] || templateIds.square;

const modifications = [
  {
    name: 'background',
    image_url: baseImageUrl
  },
  {
    name: 'headline_text',
    text: params.headline
  },
  {
    name: 'cta_button',
    text: params.cta
  }
];

return {
  template: templateId,
  modifications: modifications,
  synchronous: false
};
```

#### Node 8: Create Bannerbear Image
- **Type:** HTTP Request
- **Method:** POST
- **URL:** `https://api.bannerbear.com/v2/images`
- **Authentication:** Generic Credential Type
  - **Type:** Header Auth
  - **Name:** Authorization
  - **Value:** `Bearer {{ $env.BANNERBEAR_API_KEY }}`
- **Body (JSON):** `{{ $json }}`

**Expected Response:**
```json
{
  "uid": "bb_...",
  "status": "pending",
  "image_url": null
}
```

#### Node 9: Poll Bannerbear Completion
- **Type:** HTTP Request (Loop)
- **Method:** GET
- **URL:** `https://api.bannerbear.com/v2/images/{{ $json.uid }}`
- **Authentication:** Same as Node 8
- **Loop:** Continue until `status === "completed"` (max 30 attempts, 2s interval)

#### Node 10: Merge Results (True Branch)
- **Type:** Code
- **Code:**
```javascript
const falResult = $('Generate Image with fal.ai').item.json;
const bannerbearResult = $('Poll Bannerbear Completion').item.json;
const params = $('Extract Prompt and Copy').item.json;

return {
  ...params,
  baseImageUrl: falResult.images[0].url,
  finalImageUrl: bannerbearResult.image_url,
  bannerbearUid: bannerbearResult.uid,
  seed: falResult.seed
};
```

**False Branch (Skip Overlay):**

#### Node 11: Merge Results (False Branch)
- **Type:** Code
- **Code:**
```javascript
const falResult = $('Generate Image with fal.ai').item.json;
const params = $('Extract Prompt and Copy').item.json;

return {
  ...params,
  baseImageUrl: falResult.images[0].url,
  finalImageUrl: null,
  seed: falResult.seed
};
```

#### Node 12: Update Airtable Record
- **Type:** HTTP Request
- **Method:** PATCH
- **URL:** `https://api.airtable.com/v0/{{ $env.AIRTABLE_BASE_ID }}/{{ $env.AIRTABLE_TABLE_ID }}/{{ $json.recordId }}`
- **Authentication:** Same as Node 3
- **Body (JSON):**
```json
{
  "fields": {
    "Base Image URL": "{{ $json.baseImageUrl }}",
    "Final Image URL": "{{ $json.finalImageUrl || '' }}",
    "Status": "Generated",
    "Generated At": "{{ $now.toISO() }}",
    "Seed": {{ $json.seed }},
    "Model": "fal-ai/flux/schnell",
    "Width": {{ $json.width }},
    "Height": {{ $json.height }}
  }
}
```

#### Node 13: Return Success Response
- **Type:** Code
- **Code:**
```javascript
const params = $('Extract Parameters').item.json;
const result = $input.item.json;

return {
  pipelineId: params.pipelineId,
  status: 'completed',
  recordId: params.recordId,
  baseImageUrl: result.baseImageUrl,
  finalImageUrl: result.finalImageUrl,
  estimatedTime: Math.round((Date.now() - params.startTime) / 1000)
};
```

#### Node 14: Error Handler
- **Type:** Code (On Error)
- **Code:**
```javascript
const error = $input.item.json.error;
const params = $('Extract Parameters').item.json;

// Update Airtable with error
// (Add HTTP Request node here to update Airtable Status = "Failed", Error = error.message)

return {
  pipelineId: params.pipelineId,
  status: 'failed',
  error: error.message
};
```

---

## Workflow 2: pipeline-batch (Batch Processing)

**Purpose:** Process multiple records in parallel with progress tracking.

**Webhook URL:** `https://williamsforeal.app.n8n.cloud/webhook/pipeline-batch`

**Expected Input:**
```json
{
  "recordIds": ["rec1", "rec2", "rec3"],
  "skipOverlay": false,
  "highQuality": false
}
```

**Expected Output:**
```json
{
  "batchId": "batch-{timestamp}",
  "jobCount": 3,
  "estimatedTime": 135
}
```

### Step-by-Step Workflow Construction

#### Node 1: Webhook (Trigger)
- **Type:** Webhook
- **Method:** POST
- **Path:** `pipeline-batch`

#### Node 2: Create Batch Job
- **Type:** Code
- **Code:**
```javascript
const recordIds = $input.item.json.body.recordIds || [];
const batchId = `batch-${Date.now()}`;
const skipOverlay = $input.item.json.body.skipOverlay || false;
const highQuality = $input.item.json.body.highQuality || false;

// Store batch job in n8n database or Airtable
// For now, we'll track in memory (in production, use n8n database)

return {
  batchId,
  recordIds,
  skipOverlay,
  highQuality,
  total: recordIds.length,
  completed: 0,
  failed: 0,
  results: [],
  startTime: Date.now()
};
```

#### Node 3: Split into Items
- **Type:** Split In Batches
- **Batch Size:** 5 (process 5 records at a time)

#### Node 4: Process Each Record (Sub-workflow or Loop)
- **Type:** Execute Workflow (or HTTP Request to pipeline-start)
- **For each recordId:**
  - Call `pipeline-start` workflow
  - Or inline the pipeline logic

**Option A: Call pipeline-start workflow**
- **Type:** HTTP Request
- **Method:** POST
- **URL:** `https://williamsforeal.app.n8n.cloud/webhook/pipeline-start`
- **Body:**
```json
{
  "recordId": "{{ $json.recordId }}",
  "skipOverlay": "{{ $json.skipOverlay }}",
  "highQuality": "{{ $json.highQuality }}"
}
```

#### Node 5: Aggregate Results
- **Type:** Code
- **Code:**
```javascript
const batchData = $('Create Batch Job').item.json;
const results = $input.all();

const completed = results.filter(r => r.json.status === 'completed').length;
const failed = results.filter(r => r.json.status === 'failed').length;

return {
  batchId: batchData.batchId,
  status: completed + failed === batchData.total ? 'completed' : 'processing',
  progress: Math.round(((completed + failed) / batchData.total) * 100),
  completed: completed,
  total: batchData.total,
  results: results.map(r => ({
    recordId: r.json.recordId,
    status: r.json.status,
    baseImageUrl: r.json.baseImageUrl,
    finalImageUrl: r.json.finalImageUrl,
    error: r.json.error
  }))
};
```

#### Node 6: Return Batch Response
- **Type:** Code
- **Code:**
```javascript
const aggregated = $input.item.json;
const batchData = $('Create Batch Job').item.json;

return {
  batchId: aggregated.batchId,
  jobCount: aggregated.total,
  estimatedTime: Math.round((Date.now() - batchData.startTime) / 1000),
  status: aggregated.status,
  progress: aggregated.progress
};
```

---

## Workflow 3: pipeline-status (Status Check)

**Purpose:** Check the status of a batch or single pipeline job.

**Webhook URL:** `https://williamsforeal.app.n8n.cloud/webhook/pipeline-status`

**Expected Input (Query Params):**
- `id`: Batch ID or Pipeline ID
- `type`: `"batch"` or `"pipeline"`

**Expected Output:**
```json
{
  "id": "batch-1234567890",
  "status": "processing",
  "progress": 60,
  "completed": 3,
  "total": 5,
  "results": [...]
}
```

### Step-by-Step Workflow Construction

#### Node 1: Webhook (Trigger)
- **Type:** Webhook
- **Method:** GET
- **Path:** `pipeline-status`
- **Query Parameters:** `id`, `type`

#### Node 2: Extract Parameters
- **Type:** Code
- **Code:**
```javascript
const id = $input.item.json.query.id;
const type = $input.item.json.query.type || 'pipeline';

return { id, type };
```

#### Node 3: Check Type and Fetch Status
- **Type:** IF
- **Condition:** `{{ $json.type }}` equals `"batch"`

**True Branch (Batch Status):**
- Fetch batch job from n8n database or Airtable
- Return aggregated status

**False Branch (Pipeline Status):**
- Check if pipeline is complete
- Return single record status

#### Node 4: Return Status Response
- **Type:** Code
- **Code:**
```javascript
// This would fetch from your storage (n8n database, Airtable, or Redis)
// For now, return structure:

return {
  id: $('Extract Parameters').item.json.id,
  status: 'processing', // or 'completed', 'failed', 'queued'
  progress: 60,
  completed: 3,
  total: 5,
  results: [
    {
      recordId: 'rec1',
      status: 'success',
      baseImageUrl: 'https://...',
      finalImageUrl: 'https://...'
    },
    // ...
  ]
};
```

---

## Environment Variables in n8n

Configure these in your n8n Cloud account settings:

- `AIRTABLE_BASE_ID`: Your Airtable base ID
- `AIRTABLE_TABLE_ID`: Your Airtable table ID (Images table)
- `AIRTABLE_PAT`: Your Airtable Personal Access Token
- `FAL_API_KEY`: Your fal.ai API key
- `BANNERBEAR_API_KEY`: Your Bannerbear API key
- `BANNERBEAR_TEMPLATE_SQUARE`: Your square template UID
- `BANNERBEAR_TEMPLATE_STORY`: Your story template UID
- `BANNERBEAR_TEMPLATE_LANDSCAPE`: Your landscape template UID

## Testing Workflows

1. **Test pipeline-start:**
   ```bash
   curl -X POST https://williamsforeal.app.n8n.cloud/webhook/pipeline-start \
     -H "Content-Type: application/json" \
     -d '{"recordId": "recYOURRECORDID", "skipOverlay": false, "format": "square"}'
   ```

2. **Test pipeline-batch:**
   ```bash
   curl -X POST https://williamsforeal.app.n8n.cloud/webhook/pipeline-batch \
     -H "Content-Type: application/json" \
     -d '{"recordIds": ["rec1", "rec2"], "skipOverlay": false}'
   ```

3. **Test pipeline-status:**
   ```bash
   curl "https://williamsforeal.app.n8n.cloud/webhook/pipeline-status?id=batch-123&type=batch"
   ```

## Important Notes

1. **Error Handling:** Always wrap API calls in error handlers
2. **Rate Limiting:** Add delays between API calls to respect rate limits
3. **Storage:** For batch status tracking, consider using n8n's database or Airtable itself
4. **Webhook URLs:** Make sure webhook paths match exactly what's in `src/lib/n8n.ts`
5. **Testing:** Test each workflow individually before connecting them
