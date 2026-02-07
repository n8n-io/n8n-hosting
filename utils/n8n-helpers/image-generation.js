/**
 * Image Generation Helper for fal.ai
 *
 * Provides reusable functions for image generation workflows
 * Optimized for Flux models via fal.ai API
 *
 * Usage in n8n Code node:
 * const { generateImage, validatePrompt } = require('./utils/n8n-helpers/image-generation.js');
 * const result = generateImage(prompt, { image_size: 'square_hd' });
 */

/**
 * Generate image with fal.ai Flux model
 * @param {string} prompt - Image generation prompt
 * @param {object} options - Generation options (image_size, num_inference_steps, etc.)
 * @returns {object} Generated image data from fal.ai
 */
function generateImage(prompt, options = {}) {
  const apiKey = $env.FAL_API_KEY;

  if (!apiKey) {
    throw new Error('Missing FAL_API_KEY environment variable');
  }

  if (!prompt || typeof prompt !== 'string' || prompt.trim() === '') {
    throw new Error('Invalid prompt: must be a non-empty string');
  }

  // Default parameters (can be overridden by options)
  const defaults = {
    image_size: 'landscape_16_9',
    num_inference_steps: 28,
    guidance_scale: 3.5,
    num_images: 1,
    enable_safety_checker: false,
    output_format: 'jpeg'
  };

  const params = { ...defaults, ...options };

  // Clean and enhance prompt
  const cleanPrompt = cleanPromptText(prompt);
  const enhancedPrompt = `${cleanPrompt}, clean composition, no text, no watermark, no logo, professional photography`;

  // Generate random seed if not provided
  if (!params.seed) {
    params.seed = Math.floor(Math.random() * 2147483647);
  }

  const negativePrompt = 'text, words, letters, watermark, logo, signature, writing, captions, subtitles, blurry, low quality, distorted, deformed';

  try {
    const response = $http.request({
      method: 'POST',
      url: 'https://fal.run/fal-ai/flux/dev',
      headers: {
        'Authorization': `Key ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: {
        prompt: enhancedPrompt,
        negative_prompt: negativePrompt,
        ...params
      },
      timeout: 120000 // 2 minute timeout
    });

    return response.body;
  } catch (error) {
    throw new Error(`Image generation failed: ${error.message}`);
  }
}

/**
 * Clean prompt text by removing problematic characters
 * @param {string} prompt - Raw prompt text
 * @returns {string} Cleaned prompt
 */
function cleanPromptText(prompt) {
  if (!prompt) {
    return '';
  }

  return prompt
    .replace(/\n+/g, ' ')           // Remove newlines
    .replace(/\s+/g, ' ')           // Normalize whitespace
    .replace(/["']/g, '')           // Remove quotes
    .replace(/[^\w\s,.-]/g, '')     // Remove special characters except common punctuation
    .trim();
}

/**
 * Validate prompt before generation
 * @param {string} prompt - Prompt to validate
 * @returns {object} Validation result with isValid, errors, and cleanedPrompt
 */
function validatePrompt(prompt) {
  const errors = [];

  if (!prompt || typeof prompt !== 'string') {
    errors.push('Prompt must be a string');
    return {
      isValid: false,
      errors: errors,
      cleanedPrompt: ''
    };
  }

  const cleaned = cleanPromptText(prompt);

  if (cleaned === '') {
    errors.push('Prompt is empty after cleaning');
  }

  if (cleaned.length > 2000) {
    errors.push('Prompt exceeds 2000 character limit');
  }

  if (cleaned.length < 10) {
    errors.push('Prompt is too short (minimum 10 characters)');
  }

  // Check for forbidden terms
  const forbidden = ['nsfw', 'explicit', 'nude', 'naked'];
  const lowerPrompt = cleaned.toLowerCase();
  forbidden.forEach(term => {
    if (lowerPrompt.includes(term)) {
      errors.push(`Prompt contains forbidden term: ${term}`);
    }
  });

  return {
    isValid: errors.length === 0,
    errors: errors,
    cleanedPrompt: cleaned
  };
}

/**
 * Get image dimensions for a format preset
 * @param {string} format - Format name (square, story, landscape, etc.)
 * @returns {object} Width and height in pixels
 */
function getDimensionsForFormat(format) {
  const dimensions = {
    square: { width: 1024, height: 1024 },
    square_hd: { width: 1024, height: 1024 },
    story: { width: 1080, height: 1920 },
    landscape: { width: 1200, height: 628 },
    landscape_4_3: { width: 1024, height: 768 },
    landscape_16_9: { width: 1344, height: 768 },
    portrait_4_3: { width: 768, height: 1024 },
    portrait_16_9: { width: 768, height: 1344 }
  };

  return dimensions[format] || dimensions.square;
}

/**
 * Build fal.ai API URL for specific model
 * @param {string} model - Model name (fluxDev, fluxSchnell, fluxPro)
 * @returns {string} Full API endpoint URL
 */
function getModelUrl(model = 'fluxDev') {
  const models = {
    fluxDev: 'https://fal.run/fal-ai/flux/dev',
    fluxSchnell: 'https://fal.run/fal-ai/flux/schnell',
    fluxPro: 'https://fal.run/fal-ai/flux-pro'
  };

  return models[model] || models.fluxDev;
}

/**
 * Parse fal.ai error response
 * @param {object} error - Error object from API call
 * @returns {object} Parsed error details
 */
function parseError(error) {
  let errorMessage = 'Unknown error';
  let errorCode = 500;
  let isRetryable = false;

  try {
    if (error.response) {
      errorCode = error.response.statusCode || 500;
      const body = error.response.body;

      if (typeof body === 'string') {
        errorMessage = body;
      } else if (body && body.detail) {
        errorMessage = body.detail;
      } else if (body && body.error) {
        errorMessage = body.error;
      } else if (body) {
        errorMessage = JSON.stringify(body);
      }
    } else {
      errorMessage = error.message || String(error);
    }

    // Determine if error is retryable
    const retryableCodes = [429, 500, 502, 503, 504];
    isRetryable = retryableCodes.includes(errorCode);

  } catch (parseError) {
    errorMessage = error.message || String(error);
  }

  return {
    code: errorCode,
    message: errorMessage,
    isRetryable: isRetryable,
    timestamp: new Date().toISOString()
  };
}

/**
 * Extract image URL from fal.ai response
 * @param {object} response - fal.ai API response
 * @returns {string} Image URL or null
 */
function extractImageUrl(response) {
  try {
    if (response && response.images && Array.isArray(response.images) && response.images.length > 0) {
      return response.images[0].url;
    }
    return null;
  } catch (error) {
    return null;
  }
}

// Export for use in n8n Code nodes
module.exports = {
  generateImage,
  cleanPromptText,
  validatePrompt,
  getDimensionsForFormat,
  getModelUrl,
  parseError,
  extractImageUrl
};
