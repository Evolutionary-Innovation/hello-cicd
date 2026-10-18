# args: image container-name port region
IMAGE="$1"; NAME="$2"; PORT="$3"; REGION="$4"
REGISTRY="${IMAGE%%/*}"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
docker pull -q "$IMAGE"
docker rm -f "$NAME" || true
docker run -d --name "$NAME" --restart unless-stopped -e PORT="$PORT" -p "$PORT:$PORT" "$IMAGE"
