/**
 * Image Record Schema
 *
 * Type definitions for the Images table and API responses
 */

import { AirtableRecord } from './AirtableBase';

/**
 * Images table record fields
 */
export interface ImageFields {
  'Name': string;
  'Image URL': string;
  'Source Record'?: string[];  // Link to Ad Copy table
  'Prompt Index'?: number;
  'Seed'?: number;
  'Model'?: string;
  'Generated At'?: string;
  'Width'?: number;
  'Height'?: number;
}

/**
 * Image record type
 */
export type ImageRecord = AirtableRecord<ImageFields>;

/**
 * fal.ai API response structure
 */
export interface FalAIResponse {
  images: FalAIImage[];
  seed: number;
  has_nsfw_concepts?: boolean[];
  prompt?: string;
  timings?: {
    inference: number;
  };
}

/**
 * Individual image in fal.ai response
 */
export interface FalAIImage {
  url: string;
  width: number;
  height: number;
  content_type: string;
}

/**
 * fal.ai API request parameters
 */
export interface FalAIRequest {
  prompt: string;
  negative_prompt?: string;
  image_size?: 'square' | 'square_hd' | 'portrait_4_3' | 'portrait_16_9' | 'landscape_4_3' | 'landscape_16_9';
  num_inference_steps?: number;
  guidance_scale?: number;
  num_images?: number;
  enable_safety_checker?: boolean;
  output_format?: 'jpeg' | 'png';
  seed?: number;
}

/**
 * Bannerbear API response structure
 */
export interface BannerbearResponse {
  uid: string;
  status: 'pending' | 'completed' | 'failed';
  image_url: string | null;
  template: string;
  modifications: BannerbearModification[];
  webhook_url?: string;
  created_at: string;
  updated_at?: string;
}

/**
 * Bannerbear modification object
 */
export interface BannerbearModification {
  name: string;
  text?: string;
  image_url?: string;
  color?: string;
}

/**
 * Bannerbear API request
 */
export interface BannerbearRequest {
  template: string;
  modifications: BannerbearModification[];
  webhook_url?: string;
  metadata?: Record<string, any>;
}

/**
 * Image generation metadata
 */
export interface ImageGenerationMetadata {
  recordId: string;
  prompt: string;
  seed: number;
  model: string;
  imageSize: string;
  timestamp: string;
  processingTime?: number;
}
