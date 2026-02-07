/**
 * Actor Schema
 *
 * Type definitions for the Actors table
 */

import { AirtableRecord, AirtableAttachment } from './AirtableBase';

/**
 * Actor record fields
 */
export interface ActorFields {
  'Name': string;
  'Demographics'?: string;
  'Description'?: string;
  'Reference Images'?: AirtableAttachment[];
}

/**
 * Actor record type
 */
export type ActorRecord = AirtableRecord<ActorFields>;
