// ═══════════════════════════════════════════════════════════════
// DATA CLEANER v3 - COPY THIS INTO YOUR WORKFLOW
// For Google Sheets Edition (Node: 2.1 Data Cleaner)
// ═══════════════════════════════════════════════════════════════

const items = $input.all();

console.log(`\n${'='.repeat(60)}`);
console.log('📊 DATA CLEANER - STARTING (Google Sheets Edition)');
console.log(`Total items received: ${items.length}`);
console.log(`${'='.repeat(60)}\n`);

const currentModelData = {
  client_name: items[0].json.client_name,
  audit_id: items[0].json.audit_id,
  audit_timestamp: items[0].json.audit_timestamp || new Date().toISOString(),
  org_structure: [],
  tools: [],
  processes: [],
  kpis: {}
};

// ─────────────────────────────────────────────────────────────
// HELPER: Flexible field getter (case-insensitive)
// ─────────────────────────────────────────────────────────────
function getField(obj, ...possibleNames) {
  for (const name of possibleNames) {
    if (obj[name] !== undefined) return obj[name];

    // Try case-insensitive match
    const lowerName = name.toLowerCase();
    for (const key of Object.keys(obj)) {
      if (key.toLowerCase() === lowerName) return obj[key];
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────
// PROCESS EACH INPUT
// ─────────────────────────────────────────────────────────────
let raciCount = 0;
let toolCount = 0;
let kpiCount = 0;

for (let i = 0; i < items.length; i++) {
  const item = items[i];

  console.log(`\n--- Processing item ${i + 1}/${items.length} ---`);
  console.log('Available keys:', Object.keys(item.json).slice(0, 20).join(', '));

  // RACI Matrix - flexible field matching
  const process = getField(item.json, 'Process/Task', 'Process', 'process', 'Task', 'task', 'ProcessTask');

  if (process && String(process).trim()) {
    const raciEntry = {
      type: 'raci_matrix',
      process: String(process).trim(),
      responsible: String(getField(item.json, 'Responsible', 'responsible', 'R') || ''),
      accountable: String(getField(item.json, 'Accountable', 'accountable', 'A') || ''),
      consulted: String(getField(item.json, 'Consulted', 'consulted', 'C') || ''),
      informed: String(getField(item.json, 'Informed', 'informed', 'I') || ''),
      tool_used: String(getField(item.json, 'Tool Used', 'Tool', 'tool', 'ToolUsed') || ''),
      manual_pct: parseFloat(getField(item.json, 'Manual %', 'Manual', 'manual', 'ManualPct') || 0)
    };

    currentModelData.org_structure.push(raciEntry);
    raciCount++;
    console.log(`✅ RACI entry added: ${raciEntry.process}`);
  }

  // Tool Inventory - Google Sheets format
  const toolName = getField(item.json, 'ToolName', 'toolname', 'Tool Name', 'tool_name', 'Name', 'name');

  if (toolName && String(toolName).trim()) {
    const toolEntry = {
      name: String(toolName).trim(),
      purpose: String(getField(item.json, 'Purpose', 'purpose', 'Description', 'description') || ''),
      users: parseInt(getField(item.json, 'UserCount', 'usercount', 'Users', 'users', 'User Count') || 0),
      annual_cost: parseFloat(getField(item.json, 'AnnualCost', 'annualcost', 'Annual Cost', 'Cost', 'cost') || 0)
    };

    currentModelData.tools.push(toolEntry);
    toolCount++;
    console.log(`✅ Tool added: ${toolEntry.name}`);
  }

  // KPIs - flexible field matching
  const metricName = getField(item.json, 'Metric', 'metric', 'KPI', 'kpi', 'MetricName');
  const metricValue = getField(item.json, 'Value', 'value', 'Vale', 'vale', 'Amount', 'amount');

  if (metricName && String(metricName).trim()) {
    const metric = String(metricName).toLowerCase();
    const value = parseFloat(metricValue || 0);

    if (metric.includes('turnaround') || metric.includes('tat')) {
      currentModelData.kpis.turnaround_time_avg = value;
      kpiCount++;
      console.log(`✅ KPI added: turnaround_time_avg = ${value}`);
    } else if (metric.includes('utilization') || metric.includes('fte')) {
      currentModelData.kpis.fte_utilization = value;
      kpiCount++;
      console.log(`✅ KPI added: fte_utilization = ${value}`);
    } else if (metric.includes('cost')) {
      currentModelData.kpis.cost_per_asset = value;
      kpiCount++;
      console.log(`✅ KPI added: cost_per_asset = ${value}`);
    } else if (metric.includes('error') || metric.includes('quality')) {
      currentModelData.kpis.error_rate = value;
      kpiCount++;
      console.log(`✅ KPI added: error_rate = ${value}`);
    } else if (metric.includes('volume') || metric.includes('throughput')) {
      currentModelData.kpis.volume_per_month = value;
      kpiCount++;
      console.log(`✅ KPI added: volume_per_month = ${value}`);
    }
  }
}

console.log(`\n📊 DATA COLLECTION SUMMARY:`);
console.log(`- RACI entries: ${raciCount}`);
console.log(`- Tools: ${toolCount}`);
console.log(`- KPIs: ${kpiCount}`);

// ─────────────────────────────────────────────────────────────
// FALLBACK DATA - If sources are empty
// ─────────────────────────────────────────────────────────────
if (currentModelData.org_structure.length === 0) {
  console.warn('⚠️  No RACI data found - using fallback sample data');
  currentModelData.org_structure = [
    { type: 'raci_matrix', process: 'Content Creation', responsible: 'Creative Team', accountable: 'Creative Director', consulted: 'Brand Team', informed: 'Client', tool_used: 'Adobe Creative Suite', manual_pct: 60 },
    { type: 'raci_matrix', process: 'Asset Review & Approval', responsible: 'Account Manager', accountable: 'Client', consulted: 'Creative Team', informed: 'Production', tool_used: 'Email/Manual', manual_pct: 80 },
    { type: 'raci_matrix', process: 'Localization', responsible: 'Production Team', accountable: 'Project Manager', consulted: 'Translation Service', informed: 'Client', tool_used: 'Manual Process', manual_pct: 90 },
    { type: 'raci_matrix', process: 'Quality Assurance', responsible: 'QA Team', accountable: 'Production Lead', consulted: 'Creative Team', informed: 'Client', tool_used: 'Manual Checklist', manual_pct: 85 },
    { type: 'raci_matrix', process: 'Asset Distribution', responsible: 'Production Team', accountable: 'Account Manager', consulted: 'IT', informed: 'Client', tool_used: 'FTP/Email', manual_pct: 70 }
  ];
}

if (currentModelData.tools.length === 0) {
  console.warn('⚠️  No tool data found - using fallback sample data');
  currentModelData.tools = [
    { name: 'Adobe Creative Cloud', purpose: 'Content creation and editing', users: 50, annual_cost: 75000 },
    { name: 'Project Management Tool', purpose: 'Task tracking and collaboration', users: 100, annual_cost: 24000 },
    { name: 'DAM System', purpose: 'Digital asset storage', users: 80, annual_cost: 60000 },
    { name: 'Email/Manual Review', purpose: 'Asset review and approval', users: 120, annual_cost: 0 }
  ];
}

if (Object.keys(currentModelData.kpis).length === 0) {
  console.warn('⚠️  No KPI data found - using fallback estimates');
  currentModelData.kpis = {
    turnaround_time_avg: 5.2,
    fte_utilization: 68,
    cost_per_asset: 850,
    error_rate: 12,
    volume_per_month: 450
  };
}

// Remove duplicates
currentModelData.tools = [...new Map(currentModelData.tools.map(t => [t.name, t])).values()];
currentModelData.org_structure = [...new Map(currentModelData.org_structure.map(o => [o.process, o])).values()];

// ─────────────────────────────────────────────────────────────
// VALIDATION
// ─────────────────────────────────────────────────────────────
const validation = {
  processCount: currentModelData.org_structure.length,
  toolCount: currentModelData.tools.length,
  kpiCount: Object.keys(currentModelData.kpis).length,
  dataQuality: 100,
  usedFallbackData: raciCount === 0 || toolCount === 0 || kpiCount === 0
};

const issues = [];

if (validation.processCount < 3) {
  issues.push(`Only ${validation.processCount} processes found`);
  validation.dataQuality -= 20;
}

if (validation.toolCount < 2) {
  issues.push(`Only ${validation.toolCount} tools found`);
  validation.dataQuality -= 15;
}

if (validation.kpiCount < 2) {
  issues.push(`Only ${validation.kpiCount} KPIs found`);
  validation.dataQuality -= 10;
}

if (validation.usedFallbackData) {
  console.warn('⚠️  Using fallback data - connect real Google Sheets for accurate results');
}

console.log(`\n✅ Data Cleaner complete:`);
console.log(`   - Processes: ${validation.processCount}`);
console.log(`   - Tools: ${validation.toolCount}`);
console.log(`   - KPIs: ${validation.kpiCount}`);
console.log(`   - Data Quality: ${validation.dataQuality}%`);
console.log(`${'='.repeat(60)}\n`);

return [{
  json: {
    ...currentModelData,
    validation
  }
}];
