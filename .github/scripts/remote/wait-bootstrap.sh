# Waits for cloud-init user-data (docker install) to finish on a new instance.
for i in $(seq 1 60); do
  if [ -f /tmp/bootstrap-success.txt ] && docker info >/dev/null 2>&1; then
    echo "instance bootstrap complete"
    exit 0
  fi
  sleep 5
done
echo "bootstrap did not complete within 300s; tail of /var/log/user-data.log:" >&2
tail -n 30 /var/log/user-data.log >&2 || true
exit 1
