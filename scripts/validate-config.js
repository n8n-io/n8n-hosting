#!/usr/bin/env node
/**
 * Validate Configuration Files for Cyclone-S5
 *
 * Checks all configuration files for validity and completeness
 * Run before deployment to catch configuration errors early
 *
 * Usage:
 *   node validate-config.js
 */

const fs = require('fs');
const path = require('path');

// ANSI color codes
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
};

// Configuration paths
const SCRIPT_DIR = __dirname;
const PROJECT_ROOT = path.join(SCRIPT_DIR, '..');
const CONFIG_DIR = path.join(PROJECT_ROOT, 'config');
const SCHEMAS_DIR = path.join(PROJECT_ROOT, 'schemas');
const WORKFLOWS_DIR = path.join(PROJECT_ROOT, 'workflows');

let errors = 0;
let warnings = 0;

/**
 * Log error message
 */
function logError(message) {
  console.log(`${colors.red}✗ ERROR: ${message}${colors.reset}`);
  errors++;
}

/**
 * Log warning message
 */
function logWarning(message) {
  console.log(`${colors.yellow}⚠ WARNING: ${message}${colors.reset}`);
  warnings++;
}

/**
 * Log success message
 */
function logSuccess(message) {
  console.log(`${colors.green}✓ ${message}${colors.reset}`);
}

/**
 * Log info message
 */
function logInfo(message) {
  console.log(`${colors.blue}ℹ ${message}${colors.reset}`);
}

/**
 * Validate JSON file
 */
function validateJSONFile(filePath, schema = null) {
  const fileName = path.basename(filePath);

  if (!fs.existsSync(filePath)) {
    logError(`File not found: ${fileName}`);
    return false;
  }

  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const data = JSON.parse(content);

    // Optional schema validation
    if (schema && typeof schema === 'function') {
      schema(data, fileName);
    }

    logSuccess(`Valid JSON: ${fileName}`);
    return true;
  } catch (e) {
    logError(`Invalid JSON in ${fileName}: ${e.message}`);
    return false;
  }
}

/**
 * Validate .env.example file
 */
function validateEnvExample() {
  const envPath = path.join(CONFIG_DIR, '.env.example');

  logInfo('Validating .env.example...');

  if (!fs.existsSync(envPath)) {
    logError('.env.example file not found in config/');
    return false;
  }

  const content = fs.readFileSync(envPath, 'utf8');

  // Required environment variables
  const requiredKeys = [
    'N8N_ENCRYPTION_KEY',
    'AIRTABLE_BASE_ID',
    'AIRTABLE_PAT',
    'FAL_API_KEY',
    'BANNERBEAR_API_KEY',
    'POSTGRES_PASSWORD'
  ];

  const missingKeys = [];
  requiredKeys.forEach(key => {
    if (!content.includes(key)) {
      missingKeys.push(key);
    }
  });

  if (missingKeys.length > 0) {
    logError(`.env.example missing required keys: ${missingKeys.join(', ')}`);
    return false;
  }

  logSuccess('.env.example contains all required keys');
  return true;
}

/**
 * Validate Airtable schemas
 */
function validateAirtableSchemas() {
  const schemasPath = path.join(CONFIG_DIR, 'airtable-schemas.json');

  logInfo('Validating airtable-schemas.json...');

  const isValid = validateJSONFile(schemasPath, (schemas, fileName) => {
    // Check required tables
    const requiredTables = ['adCopy', 'images', 'actors', 'products', 'scenes'];
    const missingTables = requiredTables.filter(table => !schemas.tables || !schemas.tables[table]);

    if (missingTables.length > 0) {
      logError(`Missing required tables in ${fileName}: ${missingTables.join(', ')}`);
      return false;
    }

    // Validate each table has required properties
    Object.keys(schemas.tables).forEach(tableKey => {
      const table = schemas.tables[tableKey];
      if (!table.name) {
        logWarning(`Table '${tableKey}' missing 'name' property`);
      }
      if (!table.fields || Object.keys(table.fields).length === 0) {
        logWarning(`Table '${tableKey}' has no fields defined`);
      }
    });
  });

  return isValid;
}

/**
 * Validate API endpoints configuration
 */
function validateApiEndpoints() {
  const endpointsPath = path.join(CONFIG_DIR, 'api-endpoints.json');

  logInfo('Validating api-endpoints.json...');

  const isValid = validateJSONFile(endpointsPath, (config, fileName) => {
    // Check required APIs
    const requiredApis = ['fal', 'bannerbear', 'airtable'];
    const missingApis = requiredApis.filter(api => !config.apis || !config.apis[api]);

    if (missingApis.length > 0) {
      logError(`Missing required APIs in ${fileName}: ${missingApis.join(', ')}`);
      return false;
    }

    // Validate each API has required properties
    Object.keys(config.apis).forEach(apiKey => {
      const api = config.apis[apiKey];
      if (!api.baseUrl) {
        logWarning(`API '${apiKey}' missing 'baseUrl' property`);
      }
      if (!api.endpoints || Object.keys(api.endpoints).length === 0) {
        logWarning(`API '${apiKey}' has no endpoints defined`);
      }
    });
  });

  return isValid;
}

/**
 * Validate prompt templates
 */
function validatePromptTemplates() {
  const templatesPath = path.join(CONFIG_DIR, 'prompt-templates.json');

  logInfo('Validating prompt-templates.json...');

  const isValid = validateJSONFile(templatesPath, (config, fileName) => {
    if (!config.templates) {
      logError(`${fileName} missing 'templates' object`);
      return false;
    }

    // Check for key templates
    const expectedTemplates = ['imageGeneration', 'promptGeneration'];
    expectedTemplates.forEach(template => {
      if (!config.templates[template]) {
        logWarning(`Missing template: ${template}`);
      }
    });
  });

  return isValid;
}

/**
 * Validate workflow files
 */
function validateWorkflows() {
  logInfo('Validating workflow files...');

  if (!fs.existsSync(WORKFLOWS_DIR)) {
    logError(`Workflows directory not found: ${WORKFLOWS_DIR}`);
    return false;
  }

  const files = fs.readdirSync(WORKFLOWS_DIR);
  const jsonFiles = files.filter(f => f.endsWith('.json') && f !== 'README.json');

  if (jsonFiles.length === 0) {
    logWarning('No workflow JSON files found in workflows/');
    return true;
  }

  let allValid = true;
  jsonFiles.forEach(file => {
    const filePath = path.join(WORKFLOWS_DIR, file);
    if (!validateJSONFile(filePath)) {
      allValid = false;
    }
  });

  return allValid;
}

/**
 * Check if TypeScript schemas exist
 */
function checkTypeScriptSchemas() {
  logInfo('Checking TypeScript schemas...');

  if (!fs.existsSync(SCHEMAS_DIR)) {
    logWarning('Schemas directory not found (TypeScript schemas optional)');
    return true;
  }

  const expectedSchemas = [
    'AirtableBase.ts',
    'AdCopyAnalysis.ts',
    'ImageRecord.ts',
    'Actor.ts',
    'Product.ts',
    'Scene.ts'
  ];

  let found = 0;
  expectedSchemas.forEach(schema => {
    const schemaPath = path.join(SCHEMAS_DIR, schema);
    if (fs.existsSync(schemaPath)) {
      found++;
    }
  });

  logInfo(`Found ${found}/${expectedSchemas.length} TypeScript schema files`);

  return true;
}

/**
 * Check helper scripts exist
 */
function checkHelperScripts() {
  logInfo('Checking helper scripts...');

  const helpersDir = path.join(PROJECT_ROOT, 'utils', 'n8n-helpers');

  if (!fs.existsSync(helpersDir)) {
    logWarning('Helper scripts directory not found: utils/n8n-helpers/');
    return true;
  }

  const expectedHelpers = [
    'airtable-ops.js',
    'image-generation.js',
    'prompt-builder.js',
    'error-handler.js'
  ];

  let found = 0;
  expectedHelpers.forEach(helper => {
    const helperPath = path.join(helpersDir, helper);
    if (fs.existsSync(helperPath)) {
      found++;
    } else {
      logWarning(`Helper script not found: ${helper}`);
    }
  });

  logInfo(`Found ${found}/${expectedHelpers.length} helper scripts`);

  return true;
}

/**
 * Main validation
 */
function main() {
  console.log('================================================');
  console.log('Cyclone-S5 Configuration Validation');
  console.log('================================================\n');

  // Validate configuration files
  console.log('Validating Configuration Files...\n');

  validateEnvExample();
  validateAirtableSchemas();
  validateApiEndpoints();
  validatePromptTemplates();

  console.log('');

  // Validate workflows
  validateWorkflows();

  console.log('');

  // Check additional resources
  checkTypeScriptSchemas();
  checkHelperScripts();

  // Summary
  console.log('\n================================================');
  console.log('Validation Summary');
  console.log('================================================');
  console.log(`Errors: ${errors}`);
  console.log(`Warnings: ${warnings}`);

  if (errors === 0 && warnings === 0) {
    console.log(`${colors.green}✓ All validations passed!${colors.reset}`);
    process.exit(0);
  } else if (errors === 0) {
    console.log(`${colors.yellow}⚠ Validations passed with warnings${colors.reset}`);
    process.exit(0);
  } else {
    console.log(`${colors.red}✗ Validation failed${colors.reset}`);
    process.exit(1);
  }
}

// Run validation
main();
