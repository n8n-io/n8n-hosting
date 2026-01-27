// ═══════════════════════════════════════════════════════════════
// ENVIRONMENT VALIDATION - Runs on ALL triggers (FIXED)
// ═══════════════════════════════════════════════════════════════

const requiredEnv = [
  'OPENAI_API_KEY',
  'AIRTABLE_TOKEN',
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY'
];

const missing = [];
const invalid = [];

for (const key of requiredEnv) {
  // FIXED: Use only $env in n8n (process.env is not available)
  const value = $env[key];

  if (!value) {
    missing.push(key);
  } else if (value.length < 10) {
    invalid.push(`${key} (too short, likely invalid)`);
  }
}

if (missing.length > 0 || invalid.length > 0) {
  let errorMsg = '❌ WORKFLOW BLOCKED - Environment Configuration Issues:\n\n';

  if (missing.length > 0) {
    errorMsg += `Missing variables:\n  - ${missing.join('\n  - ')}\n\n`;
  }

  if (invalid.length > 0) {
    errorMsg += `Invalid variables:\n  - ${invalid.join('\n  - ')}\n\n`;
  }

  errorMsg += 'Please configure these in n8n Settings > Environment Variables';

  throw new Error(errorMsg);
}

console.log('✅ Environment validation passed');

// Pass through input data
return $input.all();
