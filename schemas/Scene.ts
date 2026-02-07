/**
 * Scene Schema
 *
 * Type definitions for the Scenes table
 */

import { AirtableRecord } from './AirtableBase';

/**
 * Scene record fields
 */
export interface SceneFields {
  'Name': string;
  'Description'?: string;
  'Lighting'?: string;
  'Mood'?: string;
}

/**
 * Scene record type
 */
export type SceneRecord = AirtableRecord<SceneFields>;
