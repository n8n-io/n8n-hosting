/**
 * Error Handling and Retry Logic for n8n Workflows
 *
 * Provides utilities for handling API errors, implementing retry logic,
 * and logging failures to Airtable
 *
 * Usage in n8n Code node:
 * const { isRetryable, getRetryDelay } = require('./utils/n8n-helpers/error-handler.js');
 * if (isRetryable(response.statusCode)) { ... }
 */

/**
 * Determine if an error is retryable based on status code or error type
 * @param {number} statusCode - HTTP status code
 * @param {object} error - Optional error object
 * @returns {boolean} Whether the error should be retried
 */
function isRetryable(statusCode, error = {}) {
  // HTTP status codes that warrant retry
  const retryableCodes = [
    429,  // Too Many Requests (rate limit)
    500,  // Internal Server Error
    502,  // Bad Gateway
    503,  // Service Unavailable
    504   // Gateway Timeout
  ];

  // Check if status code is retryable
  if (retryableCodes.includes(statusCode)) {
    return true;
  }

  // Check for network-level errors
  if (error && error.code) {
    const retryableErrorCodes = [
      'ECONNRESET',      // Connection reset
      'ETIMEDOUT',       // Connection timeout
      'ECONNREFUSED',    // Connection refused
      'EHOSTUNREACH',    // Host unreachable
      'ENETUNREACH',     // Network unreachable
      'EAI_AGAIN'        // DNS lookup timeout
    ];

    if (retryableErrorCodes.includes(error.code)) {
      return true;
    }
  }

  return false;
}

/**
 * Parse error details from API response
 * @param {object} response - HTTP response or error object
 * @returns {object} Parsed error details
 */
function parseError(response) {
  let errorMessage = 'Unknown error occurred';
  let errorCode = 500;
  let errorDetails = null;

  try {
    // Handle different response formats
    if (response.statusCode) {
      errorCode = response.statusCode;
    } else if (response.code) {
      errorCode = response.code;
    }

    // Extract error message
    const body = response.body || response;

    if (typeof body === 'string') {
      errorMessage = body;
    } else if (body && typeof body === 'object') {
      // Try different common error message fields
      errorMessage = body.detail || body.error || body.message || body.error_message || JSON.stringify(body);
      errorDetails = body;
    } else if (response.message) {
      errorMessage = response.message;
    }
  } catch (parseErr) {
    errorMessage = response.message || String(response);
  }

  return {
    code: errorCode,
    message: errorMessage,
    details: errorDetails,
    isRetryable: isRetryable(errorCode, response),
    timestamp: new Date().toISOString()
  };
}

/**
 * Calculate retry delay using exponential backoff
 * @param {number} attemptNumber - Current attempt number (1-based)
 * @param {number} baseDelay - Base delay in milliseconds (default 1000)
 * @param {number} maxDelay - Maximum delay in milliseconds (default 60000)
 * @returns {number} Delay in milliseconds
 */
function getRetryDelay(attemptNumber, baseDelay = 1000, maxDelay = 60000) {
  if (attemptNumber < 1) {
    return 0;
  }

  // Exponential backoff: baseDelay * 2^(attemptNumber - 1)
  const delay = baseDelay * Math.pow(2, attemptNumber - 1);

  // Apply jitter (random factor to prevent thundering herd)
  const jitter = Math.random() * 0.3 * delay; // 0-30% jitter

  // Cap at max delay
  return Math.min(delay + jitter, maxDelay);
}

/**
 * Log error to Airtable for tracking and debugging
 * @param {string} recordId - Airtable record ID
 * @param {string} tableId - Airtable table ID
 * @param {object} error - Error details
 * @param {number} attemptNumber - Current attempt number
 */
function logErrorToAirtable(recordId, tableId, error, attemptNumber = 1) {
  const baseId = $env.AIRTABLE_BASE_ID;
  const pat = $env.AIRTABLE_PAT;

  if (!baseId || !pat) {
    console.error('Cannot log error to Airtable: missing credentials');
    return;
  }

  try {
    const errorMessage = typeof error === 'string' ? error : error.message || JSON.stringify(error);

    $http.request({
      method: 'PATCH',
      url: `https://api.airtable.com/v0/${baseId}/${tableId}/${recordId}`,
      headers: {
        'Authorization': `Bearer ${pat}`,
        'Content-Type': 'application/json'
      },
      body: {
        fields: {
          'Image Gen Error': errorMessage.substring(0, 1000), // Limit to 1000 chars
          'Image Gen Failed At': new Date().toISOString(),
          'Image Gen Attempts': attemptNumber
        }
      }
    });
  } catch (logError) {
    console.error('Failed to log error to Airtable:', logError);
  }
}

/**
 * Check if maximum retries have been exceeded
 * @param {number} currentAttempt - Current attempt number
 * @param {number} maxAttempts - Maximum allowed attempts (default 3)
 * @returns {boolean} True if max retries exceeded
 */
function maxRetriesExceeded(currentAttempt, maxAttempts = 3) {
  return currentAttempt >= maxAttempts;
}

/**
 * Wait for specified milliseconds (for use in retry logic)
 * @param {number} ms - Milliseconds to wait
 * @returns {Promise} Promise that resolves after delay
 */
async function wait(ms) {
  return new Promise(resolve => {
    setTimeout(resolve, ms);
  });
}

/**
 * Execute function with retry logic
 * @param {function} fn - Function to execute
 * @param {object} options - Retry options (maxAttempts, baseDelay, onRetry)
 * @returns {Promise} Result of function execution
 */
async function withRetry(fn, options = {}) {
  const {
    maxAttempts = 3,
    baseDelay = 1000,
    maxDelay = 60000,
    onRetry = null
  } = options;

  let lastError;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      const parsedError = parseError(error);

      // Don't retry if error is not retryable or max attempts reached
      if (!parsedError.isRetryable || attempt >= maxAttempts) {
        throw error;
      }

      // Calculate delay and wait
      const delay = getRetryDelay(attempt, baseDelay, maxDelay);

      // Call onRetry callback if provided
      if (onRetry) {
        onRetry(attempt, parsedError, delay);
      }

      await wait(delay);
    }
  }

  throw lastError;
}

/**
 * Create error response object for n8n
 * @param {object} error - Error object
 * @param {string} context - Context where error occurred
 * @returns {object} Formatted error object
 */
function createErrorResponse(error, context = '') {
  const parsedError = parseError(error);

  return {
    error: true,
    errorCode: parsedError.code,
    errorMessage: parsedError.message,
    context: context,
    timestamp: parsedError.timestamp,
    isRetryable: parsedError.isRetryable,
    details: parsedError.details
  };
}

// Export for use in n8n Code nodes
module.exports = {
  isRetryable,
  parseError,
  getRetryDelay,
  logErrorToAirtable,
  maxRetriesExceeded,
  wait,
  withRetry,
  createErrorResponse
};
