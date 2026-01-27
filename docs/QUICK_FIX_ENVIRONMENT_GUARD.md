# Quick Fix: Environment Guard Error

## The Problem

The "Environment Guard" node has an error: `process is not defined [line 16]`

This is because n8n doesn't support `process.env` - you must use `$env` instead.

---

## Option 1: Manual Fix in n8n UI (30 seconds)

### Steps:

1. **Open the "Environment Guard" node** (click on it)

2. **Go to the "Parameters" tab**

3. **Find line 16** which says:
   ```javascript
   const value = process.env[key] || $env[key];
   ```

4. **Replace it with:**
   ```javascript
   const value = $env[key];
   ```

5. **Click "Execute node"** to test

6. **Click "Save"** (top right)

---

## Option 2: Copy/Paste Fixed Code (15 seconds)

### Steps:

1. **Open the "Environment Guard" node**

2. **Delete all the code**

3. **Paste this fixed code:**

```javascript
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
  // Use only $env in n8n (process.env is not available)
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
```

4. **Click "Execute node"** to test

5. **Click "Save"**

---

## After Fixing

You'll likely see a **new error** about missing environment variables:

```
❌ WORKFLOW BLOCKED - Environment Configuration Issues:

Missing variables:
  - OPENAI_API_KEY
  - AIRTABLE_TOKEN
  - SUPABASE_URL
  - SUPABASE_SERVICE_ROLE_KEY
```

This is **EXPECTED** and actually **GOOD** - it means the node is working correctly!

---

## Next Step: Set Environment Variables

### In n8n:

1. Go to **Settings** → **Environment Variables**

2. Add these variables:

   ```
   OPENAI_API_KEY = sk-proj-...
   AIRTABLE_TOKEN = pat...
   SUPABASE_URL = https://...supabase.co
   SUPABASE_SERVICE_ROLE_KEY = eyJ...
   ```

3. **Save**

4. **Restart workflow** or **Re-execute**

---

## Expected Result After Fix

✅ Environment Guard node should show:
```
OUTPUT:
1 item

✅ Environment validation passed
```

Then the workflow will continue to "Set Client Config" node.

---

## Why This Happened

I made a mistake in the code using `process.env[key]` which works in Node.js but **not** in n8n's code execution environment.

In n8n, you must use `$env[key]` to access environment variables.

**Fixed in:** Line 16
**Change:** `process.env[key] || $env[key]` → `$env[key]`

---

## Need Help?

If you still get errors after the fix, share a screenshot and I'll help debug!
