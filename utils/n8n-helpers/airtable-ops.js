/**
 * Airtable Operations Helper for n8n
 *
 * Provides reusable functions for common Airtable operations
 * Use these in n8n Code nodes for consistent API interactions
 *
 * Usage in n8n Code node:
 * const { fetchRecord, updateRecord } = require('./utils/n8n-helpers/airtable-ops.js');
 * const record = fetchRecord('recXXXXXX', $env.AIRTABLE_TABLE_AD_COPY);
 */

/**
 * Fetch a record by ID
 * @param {string} recordId - Airtable record ID
 * @param {string} tableId - Airtable table ID
 * @param {string} baseId - (Optional) Airtable base ID, defaults to env var
 * @returns {object} Record data with fields
 */
function fetchRecord(recordId, tableId, baseId = null) {
  const base = baseId || $env.AIRTABLE_BASE_ID;
  const pat = $env.AIRTABLE_PAT;

  if (!base || !pat) {
    throw new Error('Missing Airtable configuration: AIRTABLE_BASE_ID or AIRTABLE_PAT');
  }

  if (!recordId || !tableId) {
    throw new Error('Missing required parameters: recordId and tableId');
  }

  try {
    const response = $http.request({
      method: 'GET',
      url: `https://api.airtable.com/v0/${base}/${tableId}/${recordId}`,
      headers: {
        'Authorization': `Bearer ${pat}`,
        'Content-Type': 'application/json'
      }
    });

    return response.body;
  } catch (error) {
    throw new Error(`Failed to fetch record ${recordId}: ${error.message}`);
  }
}

/**
 * Update a record
 * @param {string} recordId - Airtable record ID
 * @param {string} tableId - Airtable table ID
 * @param {object} fields - Fields to update (key-value pairs)
 * @param {string} baseId - (Optional) Airtable base ID, defaults to env var
 * @returns {object} Updated record
 */
function updateRecord(recordId, tableId, fields, baseId = null) {
  const base = baseId || $env.AIRTABLE_BASE_ID;
  const pat = $env.AIRTABLE_PAT;

  if (!base || !pat) {
    throw new Error('Missing Airtable configuration: AIRTABLE_BASE_ID or AIRTABLE_PAT');
  }

  if (!recordId || !tableId || !fields) {
    throw new Error('Missing required parameters: recordId, tableId, and fields');
  }

  try {
    const response = $http.request({
      method: 'PATCH',
      url: `https://api.airtable.com/v0/${base}/${tableId}/${recordId}`,
      headers: {
        'Authorization': `Bearer ${pat}`,
        'Content-Type': 'application/json'
      },
      body: {
        fields: fields
      }
    });

    return response.body;
  } catch (error) {
    throw new Error(`Failed to update record ${recordId}: ${error.message}`);
  }
}

/**
 * Create a new record
 * @param {string} tableId - Airtable table ID
 * @param {object} fields - Fields to set (key-value pairs)
 * @param {string} baseId - (Optional) Airtable base ID, defaults to env var
 * @returns {object} Created record
 */
function createRecord(tableId, fields, baseId = null) {
  const base = baseId || $env.AIRTABLE_BASE_ID;
  const pat = $env.AIRTABLE_PAT;

  if (!base || !pat) {
    throw new Error('Missing Airtable configuration: AIRTABLE_BASE_ID or AIRTABLE_PAT');
  }

  if (!tableId || !fields) {
    throw new Error('Missing required parameters: tableId and fields');
  }

  try {
    const response = $http.request({
      method: 'POST',
      url: `https://api.airtable.com/v0/${base}/${tableId}`,
      headers: {
        'Authorization': `Bearer ${pat}`,
        'Content-Type': 'application/json'
      },
      body: {
        fields: fields
      }
    });

    return response.body;
  } catch (error) {
    throw new Error(`Failed to create record: ${error.message}`);
  }
}

/**
 * Search records with filter formula
 * @param {string} tableId - Airtable table ID
 * @param {string} filterFormula - Airtable filter formula
 * @param {object} options - Optional parameters (maxRecords, sort, view, fields)
 * @param {string} baseId - (Optional) Airtable base ID, defaults to env var
 * @returns {array} Matching records
 */
function searchRecords(tableId, filterFormula, options = {}, baseId = null) {
  const base = baseId || $env.AIRTABLE_BASE_ID;
  const pat = $env.AIRTABLE_PAT;

  if (!base || !pat) {
    throw new Error('Missing Airtable configuration: AIRTABLE_BASE_ID or AIRTABLE_PAT');
  }

  if (!tableId) {
    throw new Error('Missing required parameter: tableId');
  }

  // Build query string
  const queryParams = {};
  if (filterFormula) {
    queryParams.filterByFormula = filterFormula;
  }
  if (options.maxRecords) {
    queryParams.maxRecords = options.maxRecords;
  }
  if (options.view) {
    queryParams.view = options.view;
  }
  if (options.sort) {
    queryParams.sort = JSON.stringify(options.sort);
  }
  if (options.fields && Array.isArray(options.fields)) {
    options.fields.forEach((field, index) => {
      queryParams[`fields[${index}]`] = field;
    });
  }

  try {
    const response = $http.request({
      method: 'GET',
      url: `https://api.airtable.com/v0/${base}/${tableId}`,
      headers: {
        'Authorization': `Bearer ${pat}`,
        'Content-Type': 'application/json'
      },
      qs: queryParams
    });

    return response.body.records || [];
  } catch (error) {
    throw new Error(`Failed to search records: ${error.message}`);
  }
}

/**
 * Delete a record
 * @param {string} recordId - Airtable record ID
 * @param {string} tableId - Airtable table ID
 * @param {string} baseId - (Optional) Airtable base ID, defaults to env var
 * @returns {object} Deleted record info
 */
function deleteRecord(recordId, tableId, baseId = null) {
  const base = baseId || $env.AIRTABLE_BASE_ID;
  const pat = $env.AIRTABLE_PAT;

  if (!base || !pat) {
    throw new Error('Missing Airtable configuration: AIRTABLE_BASE_ID or AIRTABLE_PAT');
  }

  if (!recordId || !tableId) {
    throw new Error('Missing required parameters: recordId and tableId');
  }

  try {
    const response = $http.request({
      method: 'DELETE',
      url: `https://api.airtable.com/v0/${base}/${tableId}/${recordId}`,
      headers: {
        'Authorization': `Bearer ${pat}`,
        'Content-Type': 'application/json'
      }
    });

    return response.body;
  } catch (error) {
    throw new Error(`Failed to delete record ${recordId}: ${error.message}`);
  }
}

/**
 * Batch update multiple records
 * @param {string} tableId - Airtable table ID
 * @param {array} updates - Array of {id, fields} objects
 * @param {string} baseId - (Optional) Airtable base ID, defaults to env var
 * @returns {array} Updated records
 */
function batchUpdate(tableId, updates, baseId = null) {
  const base = baseId || $env.AIRTABLE_BASE_ID;
  const pat = $env.AIRTABLE_PAT;

  if (!base || !pat) {
    throw new Error('Missing Airtable configuration: AIRTABLE_BASE_ID or AIRTABLE_PAT');
  }

  if (!tableId || !updates || !Array.isArray(updates)) {
    throw new Error('Missing or invalid parameters: tableId and updates array required');
  }

  // Airtable limits batch operations to 10 records
  if (updates.length > 10) {
    throw new Error('Batch update limited to 10 records at a time');
  }

  try {
    const response = $http.request({
      method: 'PATCH',
      url: `https://api.airtable.com/v0/${base}/${tableId}`,
      headers: {
        'Authorization': `Bearer ${pat}`,
        'Content-Type': 'application/json'
      },
      body: {
        records: updates
      }
    });

    return response.body.records || [];
  } catch (error) {
    throw new Error(`Failed to batch update records: ${error.message}`);
  }
}

// Export for use in n8n Code nodes
module.exports = {
  fetchRecord,
  updateRecord,
  createRecord,
  searchRecords,
  deleteRecord,
  batchUpdate
};
