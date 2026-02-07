/**
 * Base Airtable Type Definitions
 *
 * Foundational types used across all Airtable table schemas
 */

/**
 * Generic Airtable record structure
 */
export interface AirtableRecord<T = any> {
  id: string;
  fields: T;
  createdTime: string;
}

/**
 * Airtable API response for list queries
 */
export interface AirtableResponse<T = any> {
  records: AirtableRecord<T>[];
  offset?: string;
}

/**
 * Airtable attachment (image, file, etc.)
 */
export interface AirtableAttachment {
  id: string;
  url: string;
  filename: string;
  size: number;
  type: string;
  width?: number;
  height?: number;
  thumbnails?: {
    small: AirtableThumbnail;
    large: AirtableThumbnail;
    full: AirtableThumbnail;
  };
}

/**
 * Thumbnail metadata within attachment
 */
export interface AirtableThumbnail {
  url: string;
  width: number;
  height: number;
}

/**
 * Possible Airtable field value types
 */
export type AirtableFieldValue =
  | string
  | number
  | boolean
  | string[]
  | AirtableAttachment[]
  | AirtableRecord[]
  | null
  | undefined;

/**
 * Airtable filter formula helper type
 */
export type AirtableFormula = string;

/**
 * Airtable sort configuration
 */
export interface AirtableSort {
  field: string;
  direction: 'asc' | 'desc';
}

/**
 * Airtable query options
 */
export interface AirtableQueryOptions {
  filterByFormula?: AirtableFormula;
  maxRecords?: number;
  pageSize?: number;
  sort?: AirtableSort[];
  view?: string;
  fields?: string[];
}

/**
 * Airtable error response
 */
export interface AirtableError {
  error: {
    type: string;
    message: string;
  };
}

/**
 * Airtable create/update request body
 */
export interface AirtableUpdateRequest<T> {
  fields: Partial<T>;
  typecast?: boolean;
}

/**
 * Airtable batch operation request
 */
export interface AirtableBatchRequest<T> {
  records: Array<{
    id?: string;
    fields: Partial<T>;
  }>;
  typecast?: boolean;
}
