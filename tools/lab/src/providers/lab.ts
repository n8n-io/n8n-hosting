import { userInfo } from 'node:os';

/** Who is running the lab. It ends up in cloud tags and default cluster names, so it is made safe for both. */
export const owner = userInfo().username.toLowerCase().replace(/[^a-z0-9-]/g, '-');

/** The tag on everything the lab creates in a cloud. Clusters made before the rename carry the old value. */
export const LAB_TAG = 'n8n-hosting-lab';
export const OLD_LAB_TAG = 'n8n-deployment-lab';
export const isLabTag = (value: string) => value === LAB_TAG || value === OLD_LAB_TAG;
export const LAB_TAGS = [`lab=${LAB_TAG}`, `owner=${owner}`];

/** Only clusters whose name starts with lab- are the lab's, so a name you type gets the prefix. */
export const labName = (name: string) => (name.startsWith('lab-') ? name : `lab-${name}`);

/** "running for 3h 5m", from the time a cluster was created. */
export function runningFor(createdAt: string, now = Date.now()): string {
  const minutes = createdAt ? Math.floor((now - new Date(createdAt).getTime()) / 60000) : 0;
  return `running for ${Math.floor(minutes / 60)}h ${minutes % 60}m`;
}
