#!/bin/bash

CHART_NAME="gpu-operator"
CHART_DIR="$(pwd)/gpu-operator-charts"
MINIO_BUCKET="helm-charts"
LATEST_CHART_VERSION="${1}"

# Create directory for chart downloads
mkdir -p "${CHART_DIR}"

# List existing chart versions in MinIO
EXISTING_VERSIONS=$(mc ls myminio/${MINIO_BUCKET}/nvidia/ | awk '{print $NF}' | grep "${CHART_NAME}-" | sed "s|${CHART_NAME}-||;s|.tgz||")

# Print existing versions
echo "Existing versions in MinIO: ${EXISTING_VERSIONS}"

# Check if the latest chart version exists in MinIO
if echo "${EXISTING_VERSIONS}" | grep -q "${LATEST_CHART_VERSION}"; then
  echo "Latest version ${LATEST_CHART_VERSION} already exists in MinIO. Checking index.yaml..."
else
  echo "Latest version ${LATEST_CHART_VERSION} does not exist in MinIO. Pulling latest version."
  helm pull nvidia/gpu-operator --version "${LATEST_CHART_VERSION}" --destination "${CHART_DIR}"
  # Upload the latest version after pulling
  mc cp "${CHART_DIR}/${CHART_NAME}-${LATEST_CHART_VERSION}.tgz" myminio/${MINIO_BUCKET}/nvidia/
fi

# Download index.yaml if it exists in MinIO
mc cp myminio/${MINIO_BUCKET}/nvidia/index.yaml "${CHART_DIR}/index.yaml" || echo "index.yaml not found in MinIO."

# Check if index.yaml contains the latest version
if [ -f "${CHART_DIR}/index.yaml" ]; then
  if grep -q "${LATEST_CHART_VERSION}" "${CHART_DIR}/index.yaml"; then
    echo "index.yaml already contains the latest version ${LATEST_CHART_VERSION}. Skipping index update."
  else
    echo "index.yaml does not contain the latest version ${LATEST_CHART_VERSION}."
  fi
else
  echo "index.yaml not found."
fi

# Pull each existing version and place them in the directory
for VERSION in ${EXISTING_VERSIONS}; do
  if [ ! -f "${CHART_DIR}/${CHART_NAME}-${VERSION}.tgz" ]; then
    echo "Pulling version ${VERSION}..."
    helm pull nvidia/gpu-operator --version "${VERSION}" --destination "${CHART_DIR}"
  else
    echo "Version ${VERSION} already downloaded. Skipping."
  fi
done

# Generate index.yaml from all charts in the directory
helm repo index "${CHART_DIR}" --url https://minio.ewr.vultrlabs.dev/helm-charts/nvidia

# Upload all charts and the updated index.yaml
for FILE in "${CHART_DIR}"/*.tgz; do
  mc cp "${FILE}" myminio/${MINIO_BUCKET}/nvidia/
done
mc cp "${CHART_DIR}/index.yaml" myminio/${MINIO_BUCKET}/nvidia/

echo "Upload complete for all versions."
