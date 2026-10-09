export interface Cluster {
  name: string;
  running: boolean;
  /** A few words about it, shown in the cluster list. */
  detail?: string;
}

export type Log = (line: string) => void;

/**
 * A place to run the lab. It manages named clusters and hands back a kube context; everything else is shared.
 * A cluster outlives its deployments: `down` removes deployments, only `cluster delete` removes a cluster.
 */
export interface Provider {
  name: string;
  /** Local providers can use images loaded into the cluster and run Compose targets. */
  local: boolean;
  /** True when the cluster list may hold clusters the lab did not create, so deleting one needs extra care. */
  shared?: boolean;
  /** CLIs this provider drives. A missing one stops the run before anything is created. */
  clis: string[];
  /** The name offered when you create a new cluster. */
  defaultName(): string;
  /** Turns a name you typed into the one the provider uses, so the lab can find its own clusters again. */
  normalize?(name: string): string;
  /** What creating a cluster will cost and take, shown before the user is asked to confirm. */
  plan?(name: string): Promise<string>;
  /** What a running cluster is costing, shown by `status` so an idle one is not forgotten. */
  info?(name: string): Promise<string>;
  list(): Promise<Cluster[]>;
  /** Creates the cluster, or starts it if it exists but is stopped. */
  create(name: string, log: Log): Promise<void>;
  /** Returns the kube context for the cluster. */
  connect(name: string): Promise<string>;
  destroy(name: string, log: Log): Promise<void>;
  /** A registry the cluster can pull from. Optional: a local provider uses images loaded into the cluster. */
  registry?: {
    /** Creates the registry if needed, lets the cluster pull from it and logs Docker in. Returns the repository to push to. */
    ensure(cluster: string, log: Log): Promise<string>;
    remove(cluster: string, log: Log): Promise<void>;
  };
  /** Removes storage a deleted namespace left behind. Optional: a cloud cluster takes its disks with it. */
  wipeStorage?(namespaces: string[], ctx: string): Promise<void>;
}
