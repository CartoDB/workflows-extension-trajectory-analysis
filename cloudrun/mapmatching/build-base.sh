NAME="map-matching"
PROJECT_ID="cartodb-on-gcp-datascience"
REGION="us-east1"
GOOGLE_REGISTRY_URL="us-east1-docker.pkg.dev"
ARTIFACTS_REPOSITORY="map-matching"
DOCKER_LABEL="latest"

gcloud auth configure-docker ${GOOGLE_REGISTRY_URL}
docker buildx build --platform linux/amd64 -t ${GOOGLE_REGISTRY_URL}/${PROJECT_ID}/${ARTIFACTS_REPOSITORY}/${NAME}:${DOCKER_LABEL} -f Dockerfile.base .
docker push ${GOOGLE_REGISTRY_URL}/${PROJECT_ID}/${ARTIFACTS_REPOSITORY}/${NAME}:${DOCKER_LABEL}