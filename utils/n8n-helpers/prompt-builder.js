/**
 * Prompt Builder for AI Image Generation
 *
 * Constructs optimized prompts from Airtable data
 * Uses templates from config/prompt-templates.json
 *
 * Usage in n8n Code node:
 * const { buildImagePrompt, extractPrompts } = require('./utils/n8n-helpers/prompt-builder.js');
 * const prompts = extractPrompts(record.fields);
 */

/**
 * Build image prompt from ad copy data
 * @param {object} adCopyData - Airtable Ad Copy record fields
 * @param {object} options - Build options
 * @returns {string} Optimized image prompt
 */
function buildImagePrompt(adCopyData, options = {}) {
  const {
    fullConcept,
    avatarTarget,
    angle,
    product,
    scene
  } = adCopyData;

  // Use existing prompt if available and requested
  if (options.useExisting && adCopyData['Prompt 1']) {
    return adCopyData['Prompt 1'];
  }

  // Build prompt from components
  let prompt = fullConcept || '';

  // Add context
  if (avatarTarget) {
    prompt += `, targeted at ${avatarTarget}`;
  }

  if (angle) {
    prompt += `, ${angle} marketing angle`;
  }

  // Add product details if available
  if (product && typeof product === 'object' && product.description) {
    prompt += `, featuring ${product.description}`;
  } else if (typeof product === 'string') {
    prompt += `, featuring ${product}`;
  }

  // Add scene details if available
  if (scene) {
    if (typeof scene === 'object') {
      if (scene.lighting) {
        prompt += `, ${scene.lighting} lighting`;
      }
      if (scene.mood) {
        prompt += `, ${scene.mood} mood`;
      }
    } else if (typeof scene === 'string') {
      prompt += `, ${scene}`;
    }
  }

  return prompt.trim();
}

/**
 * Extract prompts from Ad Copy record
 * @param {object} fields - Airtable record fields
 * @returns {array} Array of non-empty prompts
 */
function extractPrompts(fields) {
  const prompts = [];

  // Check if using Image Prompts array field
  if (fields['Image Prompts'] && typeof fields['Image Prompts'] === 'string') {
    // Split by newlines if multiline text
    const lines = fields['Image Prompts'].split('\n');
    lines.forEach(line => {
      const trimmed = line.trim();
      if (trimmed) {
        prompts.push(trimmed);
      }
    });
  }

  // Check individual prompt fields
  const promptFields = ['Prompt 1', 'Prompt 2', 'Prompt 3'];
  for (const field of promptFields) {
    if (fields[field] && typeof fields[field] === 'string') {
      const trimmed = fields[field].trim();
      if (trimmed && !prompts.includes(trimmed)) {
        prompts.push(trimmed);
      }
    }
  }

  // Fallback to Full Concept if no prompts found
  if (prompts.length === 0 && fields['Full Concept']) {
    prompts.push(fields['Full Concept']);
  }

  return prompts;
}

/**
 * Add style modifiers to prompt
 * @param {string} prompt - Base prompt
 * @param {string} style - Style type (photorealistic, artistic, minimal, cinematic, lifestyle)
 * @returns {string} Enhanced prompt with style modifiers
 */
function addStyleModifiers(prompt, style = 'photorealistic') {
  const styleModifiers = {
    photorealistic: 'photorealistic, highly detailed, 8k resolution, studio lighting, professional photography',
    artistic: 'artistic rendering, creative composition, vibrant colors, aesthetic',
    minimal: 'minimal design, clean aesthetic, simple composition, negative space',
    cinematic: 'cinematic composition, dramatic lighting, film grain, bokeh, depth of field',
    lifestyle: 'lifestyle photography, natural lighting, authentic moment, candid'
  };

  const modifier = styleModifiers[style] || styleModifiers.photorealistic;
  return `${prompt}, ${modifier}`;
}

/**
 * Add lighting preset to prompt
 * @param {string} prompt - Base prompt
 * @param {string} lighting - Lighting preset (goldenHour, studio, natural, dramatic, softDiffused)
 * @returns {string} Prompt with lighting description
 */
function addLightingPreset(prompt, lighting = 'natural') {
  const lightingPresets = {
    goldenHour: 'golden hour lighting, warm tones, soft shadows, sunset glow',
    studio: 'studio lighting, soft box, even illumination, professional setup',
    natural: 'natural daylight, window light, soft ambient',
    dramatic: 'dramatic lighting, strong shadows, high contrast, moody',
    softDiffused: 'soft diffused lighting, gentle shadows, flattering'
  };

  const preset = lightingPresets[lighting] || lightingPresets.natural;
  return `${prompt}, ${preset}`;
}

/**
 * Create prompt variations using different strategies
 * @param {string} basePrompt - Base prompt text
 * @param {number} count - Number of variations to create (1-5)
 * @returns {array} Array of prompt variations
 */
function createVariations(basePrompt, count = 3) {
  if (count < 1 || count > 5) {
    throw new Error('Variation count must be between 1 and 5');
  }

  const variations = [];

  // Strategy 1: Different angles
  const angles = ['close-up shot', 'wide angle view', 'eye level perspective', 'aerial view', 'low angle shot'];

  // Strategy 2: Different lighting
  const lightings = ['golden hour lighting', 'studio lighting', 'natural daylight', 'dramatic lighting', 'soft diffused light'];

  // Strategy 3: Different moods
  const moods = ['energetic and vibrant', 'calm and peaceful', 'professional and clean', 'playful and fun', 'elegant and sophisticated'];

  for (let i = 0; i < count; i++) {
    let variation = basePrompt;

    // Add angle variation
    if (angles[i]) {
      variation += `, ${angles[i]}`;
    }

    // Add lighting variation
    if (lightings[i]) {
      variation += `, ${lightings[i]}`;
    }

    // Add mood variation
    if (moods[i]) {
      variation += `, ${moods[i]} atmosphere`;
    }

    variations.push(variation);
  }

  return variations;
}

/**
 * Clean and normalize prompt text
 * @param {string} prompt - Raw prompt
 * @returns {string} Cleaned prompt
 */
function cleanPrompt(prompt) {
  if (!prompt) {
    return '';
  }

  return prompt
    .replace(/\n+/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/["']/g, '')
    .trim();
}

/**
 * Combine multiple prompt components
 * @param {object} components - Prompt components (subject, environment, lighting, mood, camera)
 * @returns {string} Combined prompt
 */
function combineComponents(components) {
  const {
    subject,
    environment,
    lighting,
    mood,
    camera,
    style
  } = components;

  const parts = [];

  if (subject) parts.push(subject);
  if (environment) parts.push(`in ${environment}`);
  if (camera) parts.push(camera);
  if (lighting) parts.push(lighting);
  if (mood) parts.push(`${mood} atmosphere`);
  if (style) parts.push(style);

  return parts.join(', ');
}

// Export for use in n8n Code nodes
module.exports = {
  buildImagePrompt,
  extractPrompts,
  addStyleModifiers,
  addLightingPreset,
  createVariations,
  cleanPrompt,
  combineComponents
};
