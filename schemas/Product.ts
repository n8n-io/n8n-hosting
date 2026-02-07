/**
 * Product Schema
 *
 * Type definitions for the Products table
 */

import { AirtableRecord, AirtableAttachment } from './AirtableBase';

/**
 * Product record fields
 */
export interface ProductFields {
  'Name': string;
  'Description'?: string;
  'Category'?: 'Electronics' | 'Fashion' | 'Home' | 'Beauty' | 'Food' | 'Other';
  'Product Images'?: AirtableAttachment[];
}

/**
 * Product record type
 */
export type ProductRecord = AirtableRecord<ProductFields>;
