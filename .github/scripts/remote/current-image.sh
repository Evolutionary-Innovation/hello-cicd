# args: container-name. Prints the image the container was created from, or nothing.
docker inspect --format '{{.Config.Image}}' "$1" 2>/dev/null || true
