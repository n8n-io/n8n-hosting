/**
 * Ad Copy Analysis Schema
 *
 * Type definitions for the Ad Copy table and related workflows
 */

import { AirtableRecord, AirtableAttachment } from './AirtableBase';

/**
 * Ad Copy record fields
 */
export interface AdCopyFields {
  // Core identification
  'Record ID'?: string;

  // Ad concept fields
  'Full Concept': string;
  'Avatar Target'?: string;
  'Angle'?: string;
  'Headline'?: string;
  'CTA'?: string;

  // Linked records
  'Product'?: string[];  // Link to Products table

  // Image prompt generation
  'Generate Image Prompts'?: 'Not Started' | 'In Progress' | 'Done';
  'Prompt 1'?: string;
  'Prompt 2'?: string;
  'Prompt 3'?: string;
  'Image Prompts'?: string;  // Alternative multiline format

  // Image generation status
  'Image Generated'?: boolean;
  'Image Gen Timestamp'?: string;
  'Image Seed'?: number;
  'Image Gen Error'?: string;
  'Image Gen Failed At'?: string;
  'Image Gen Attempts'?: number;

  // Image URLs
  'Base Image URL'?: string;
  'Final Image URL'?: string;

  // Overall status
  'Status'?: 'Pending' | 'Generated' | 'Failed';

  // Image metadata
  'Model'?: string;
  'Width'?: number;
  'Height'?: number;
  'Generated At'?: string;
}

/**
 * Ad Copy record type
 */
export type AdCopyRecord = AirtableRecord<AdCopyFields>;

/**
 * Pipeline start workflow input
 */
export interface PipelineStartInput {
  recordId: string;
  skipOverlay?: boolean;
  format?: 'square' | 'story' | 'landscape' | 'landscape_16_9';
  highQuality?: boolean;
  promptIndex?: number;  // Which prompt to use (1-3)
}

/**
 * Pipeline start workflow output
 */
export interface PipelineStartOutput {
  pipelineId: string;
  status: 'queued' | 'processing' | 'completed' | 'failed';
  recordId: string;
  baseImageUrl?: string;
  finalImageUrl?: string;
  estimatedTime?: number;
  error?: string;
  timestamp: string;
}

/**
 * Batch processing input
 */
export interface PipelineBatchInput {
  recordIds: string[];
  skipOverlay?: boolean;
  format?: 'square' | 'story' | 'landscape' | 'landscape_16_9';
  highQuality?: boolean;
}

/**
 * Batch processing output
 */
export interface PipelineBatchOutput {
  batchId: string;
  jobCount: number;
  estimatedTime: number;
  status: 'processing' | 'completed' | 'failed';
  progress: number;  // 0-100
  results?: PipelineStartOutput[];
  failedCount?: number;
  successCount?: number;
}

/**
 * Pipeline status check input
 */
export interface PipelineStatusInput {
  pipelineId: string;
}

/**
 * Pipeline status check output
 */
export interface PipelineStatusOutput {
  pipelineId: string;
  status: 'queued' | 'processing' | 'completed' | 'failed';
  progress: number;  // 0-100
  startedAt?: string;
  completedAt?: string;
  error?: string;
  result?: any;
}

/**
 * Webhook payload for image generation trigger
 */
export interface ImageGenerationWebhookPayload {
  recordId: string;
  action?: 'generate' | 'regenerate';
  promptIndex?: number;
  options?: {
    imageSize?: string;
    numInferenceSteps?: number;
    guidanceScale?: number;
    seed?: number;
  };
}

/**
 * Airtable automation trigger payload
 */
export interface AirtableAutomationPayload {
  recordId: string;
  fields: Partial<AdCopyFields>;
  timestamp: string;
}
