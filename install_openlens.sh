#!/bin/bash
set -e
# ShellCheck'ed for your pleasure.
declare -r NVM_MAJOR_RELEASE="16"
declare -r NVM_API_URL="https://api.github.com/repos/nvm-sh/nvm"
declare -r NVM_REPO_URL="https://raw.githubusercontent.com/nvm-sh/nvm"
declare -r OPENLENS_API_URL="https://api.github.com/repos/lensapp/lens/releases/latest"
declare -r OPENLENS_REPO_URL="https://github.com/lensapp/lens"
declare TMP_DIR NVM_DIR

function install_deps_debian()
{
  printf "%s\\n" "INFO: installing build dependencies for Debian"
  sudo apt-get install --quiet --yes curl g++ make tar
}

function install_nvm()
{
  if [ -z "${NVM_DIR}" ]; then
    if ! [ -d "${HOME}/.nvm" ]; then
      NVM_VERSION=$(curl -s "${NVM_API_URL}/releases/latest" | sed -En 's/  "tag_name": "(.+)",/\1/p')
      printf "%s\\n" "INFO: installing NVM version ${NVM_VERSION}"
      curl -sS -o- "${NVM_REPO_URL}/${NVM_VERSION}/install.sh" | bash
    fi
    NVM_DIR="${HOME}/.nvm"
  else
    printf "%s\\n" "INFO: nvm installation directory ${NVM_DIR}"
  fi
  if [ -s "${NVM_DIR}/nvm.sh" ]; then
    printf "%s\\n" "INFO: loading nvm"
    # shellcheck source=/dev/null
    source "${NVM_DIR}/nvm.sh"
  fi
}

function install_debian()
{
  printf "%s\\n" "INFO: installing OpenLens on Debian"
  find "${TMP_DIR}/lens/dist/" -type f -name "*.deb" -exec sudo apt-get install {} \;
  rm -rf "${TMP_DIR:-fallback}"
}

function build_openlens()
{
  TMP_DIR="$(mktemp -d)"
  printf "%s\\n" "INFO: using directory ${TMP_DIR}"
  cd "${TMP_DIR}"
  if [ -z "${1}" ]; then
    printf "%s\\n%s\\n%s\\n" "INFO: version of OpenLens has not been provided" "INFO: you can provide OpenLens version to the script, e.g." "${0} 6.0.0"
    printf "%s\\n" "INFO: checking GitHub API for the latest OpenLens tag"
    OPENLENS_VERSION=$(curl -sS "${OPENLENS_API_URL}" | sed -En 's/  "tag_name": "(.+)",/\1/p')
  else
    if [[ "${1}" == v* ]]; then
      OPENLENS_VERSION="${1}"
    else
      OPENLENS_VERSION="v${1}"
    fi
  fi
  if [ -z "${OPENLENS_VERSION}" ]; then
    printf "%s\\n" "ERROR: failed to get a valid version tag"
    exit 1
  else
    printf "%s\\n" "INFO: using supplied OpenLens tag ${OPENLENS_VERSION}"
  fi

  printf "%s\\n" "INFO: downloading OpenLens source code"
  curl -s -L "${OPENLENS_REPO_URL}/archive/refs/tags/${OPENLENS_VERSION}.tar.gz" | tar xz
  mv lens-* lens
  cd lens
  # Do not build rpm
  sed -i '/\"rpm\"\,/d' ./package.json
  NVM_CURRENT=$(nvm current)
  nvm install "${NVM_MAJOR_RELEASE}"
  nvm use "${NVM_MAJOR_RELEASE}"
  npm install -g yarn
  printf "%s\\n" "INFO: build OpenLens"
  make build
  nvm use "${NVM_CURRENT}"
}

main()
{
  if [[ "$(uname)" == "Linux" ]]; then
    install_deps_debian
    install_nvm
    build_openlens "${1}"
    install_debian
    printf "%s\\n" "INFO: finished"
  else
    printf "%s\\n" "ERROR: Linux system not detected"
    exit 1
  fi
}

main "$@"
