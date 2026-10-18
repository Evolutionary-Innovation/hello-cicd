# Waits for cloud-init (user-data: docker install) to finish; fails if user-data failed.
if ! timeout 300 cloud-init status --wait; then
  echo "cloud-init did not finish cleanly; tail of /var/log/user-data.log:" >&2
  tail -n 30 /var/log/user-data.log >&2 || true
  exit 1
fi
docker info >/dev/null 2>&1 || { echo "docker is not running" >&2; exit 1; }
echo "instance bootstrap complete"
