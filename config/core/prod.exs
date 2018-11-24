use Mix.Config

prefix = "${HELIX_DB_PREFIX}"

config :helix, Helix.Core.Repo,
  pool_size: "${HELIX_DB_POOL_SIZE}",
  username: "${HELIX_DB_USER}",
  password: "${HELIX_DB_PASS}",
  hostname: "${HELIX_DB_HOST}",
  database: prefix <> "_prod_core"

config :helix, :node,
  public_ip: "${HELIX_NODE_IP_PUBLIC}",
  private_ip: "${HELIX_NODE_IP_PRIVATE}",
  provider: "${HELIX_NODE_PROVIDER}",
  region: "${HELIX_NODE_REGION}"
