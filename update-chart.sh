#!/bin/bash

# Set variables
CHART_NAME="gpu-operator"
CHART_DIR="gpu-operator-charts"
MINIO_BUCKET="helm-charts"
LATEST_CHART_VERSION="${1}"  # Pass latest version as the first argument

# Create directory for chart downloads
mkdir -p ${CHART_DIR}

# List existing chart versions in MinIO
EXISTING_VERSIONS=$(mc ls myminio/${MINIO_BUCKET}/nvidia/ | awk '{print $NF}' | grep "${CHART_NAME}-" | sed "s|${CHART_NAME}-||;s|.tgz||")

# Pull the latest version if not present
if ! echo "${EXISTING_VERSIONS}" | grep -q "${LATEST_CHART_VERSION}"; then
  echo "Pulling latest version ${LATEST_CHART_VERSION}..."
  helm pull nvidia/gpu-operator --version ${LATEST_CHART_VERSION} --destination ${CHART_DIR}
fi

# Pull each existing version and place them in the directory
for VERSION in ${EXISTING_VERSIONS}; do
  if [ ! -f "${CHART_DIR}/${CHART_NAME}-${VERSION}.tgz" ]; then
    echo "Pulling version ${VERSION}..."
    helm pull nvidia/gpu-operator --version ${VERSION} --destination ${CHART_DIR}
  fi
done

# Verify the contents of the chart directory
echo "Contents of ${CHART_DIR}:"
ls -l ${CHART_DIR}

# Generate a comprehensive index.yaml from all charts in the directory
helm repo index ${CHART_DIR} --url https://minio.ewr.vultrlabs.dev/helm-charts/nvidia

# Ensure that the index.yaml includes all the versions
if ! grep -q "${LATEST_CHART_VERSION}" ${CHART_DIR}/index.yaml; then
  echo "Index generation failed for some versions. Please check the chart files."
  exit 1
fi

# Upload all charts and the updated index.yaml
for FILE in ${CHART_DIR}/*.tgz; do
  mc cp "${FILE}" myminio/${MINIO_BUCKET}/nvidia/
done
mc cp ${CHART_DIR}/index.yaml myminio/${MINIO_BUCKET}/nvidia/

echo "Upload complete for all versions."
