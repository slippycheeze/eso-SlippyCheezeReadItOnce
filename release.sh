#!/usr/bin/env zsh
#
# Create a release zip file ready for pushing to esoui
set -e
set +u
set WARN_CREATE_GLOBAL

function log() {echo "release: $*"; }
function die() { log "$@" >&2;  exit 1; }

# check we have the tools we need
[[ -x =git-chglog ]] || die "the (golang) git-chglog tool is missing"
[[ -x =md2bbcode ]] || die "the md2bbcode script is missing"
[[ -x =jq ]] || die "the jq utility is missing"
[[ -x =curl ]] || die "curl is missing"

# grab the ESOUI token from the git config
token="X-API-Token: $(git config esoui.token)"
if [[ $? > 0 || ${token} == 'X-API-Token: ' ]]; then
  die "git config esoui.token failed: '${esoui_token:-not found in config file}'"
fi


IS_RELEASE_VERSION='true'
if [[ $1 == test ]]; then
  IS_RELEASE_VERSION='false'
  tag=$(date +%s)
else
  # check we are at the head of the current branch?
  if [[ $(git rev-parse master) != $(git rev-parse HEAD) ]]; then
    die "not currently at the head of branch 'master'"
  fi

  tag=($(git tag --list --points-at master))
  tag=(${(@n)tag})                # sort tags
  case ${#tag} in
    0) die "current 'master' is not tagged"; ;;
    1) ;;  # success, this is what we want!
    *) die "current 'master' has more than one tag: ${tag}"; ;;
  esac

  if [[ ! ( $tag =~ ^[0-9]+$ ) ]]; then
    die "current 'master' is tagged '${tag}', but must be tagged with an integer"
  fi
fi

# figure out the addon name, and build directory
root=${PWD?}
addon=${${(s:/:)PWD?}[-1]}
manifest=${addon}.txt
distdir=${HOME}/wslhome/Documents/esoui-release

release=${PWD?}/release
mkdir -p ${release}

if [[ $IS_RELEASE_VERSION == false ]]; then
  zipfile=test-${addon}.zip
  rm -f ${release}/${zipfile}
else
  zipfile=${addon}-${tag}.zip
fi

# logic for building the version we package for esoui
log "building ${addon} with release=${IS_RELEASE_VERSION}"
build=${PWD?}/build/${addon}
[[ -d ${build} ]] && rm -rf ${build}
mkdir -p ${build}

function verify() {
  log "verify '$@'"
  output=$($@ >&1)
  if (( $? > 0 )); then
    die "${output}"
  fi
  return 0
}

function check_lua() {
  luac -p ${1} || die ${2}
}

function ship() {
  case $1 in
    (*.lua)
      log "ship ${1} with IS_RELEASE_VERSION=${IS_RELEASE_VERSION}"
      # make sure it was good before we started
      check_lua ${1} "${1} was corrupted before shipping"
      # we burn in the release type on the way
      mkdir --parents ${${~1}:h}
      perl -p -e 'BEGIN { $irv=shift; } s/(IS_RELEASE_VERSION *= *)(?:true|false)/$1$irv/' \
           -- ${IS_RELEASE_VERSION} < ${1} > ${build}/${1}
      # ...and make sure we didn't screw it up.
      check_lua ${build}/${1} "${1} was corrupted after shipping"
      ;;
    (*)
      log "copy ${1}"
      cp --parents ${1} ${build}
      ;;
  esac
}

# ship the manifest
# update the version tags in the files
log "writing manifest with AddOnVersion ${tag}"
filter=
perl -p -e 'BEGIN { $v=shift; } s/^## (AddOn)?Version:.*$/## \1Version: $v/' \
     -- ${tag} < ${manifest} > ${build}/${manifest}

# parse the files out of the manifest, and ship
< ${manifest} while read file; do
  file=${file%%#*}
  file=${file//[[:cntrl:]]/}
  if [[ -n $file ]]; then
    if [[ -f $file ]]; then
      ship ${file}
    else
      log "skipping !-f file: ${(qq)file}"
    fi
  fi
done

# add any embedded libraries wholesale!
log "shipping local embedded libraries"
for embed in [lL]ib*/**/*(.); do
  log "embed ${embed}"
  cp --parents ${embed} ${build}
done

log "fetching remote embedded libraries"
< ${manifest} while read _ tag name id _; do
  if [[ ${tag:l} == x-vendoraddon: ]]; then
    if [[ -z ${name} || -z ${id} ]]; then
      die "missing name or id for vendoring from esoui: [${name}] [${id}]"
    fi

    log "fetching release information for ${id}:${name}"
    data=$(curl -sSLH ${token} https://api.esoui.com/addons/details/${id}.json)

    json_id=$(jq -M -r '.[0].id' <<<${data})
    if [[ ${id} != ${json_id} ]]; then
      die "vendoring ${id}:${name} - remote {id: '${json_id}'} does not match"
    fi

    json_name=$(jq -M -r '.[0].title' <<<${data})
    if [[ ${name} != ${json_name} ]]; then
      die "vendoring ${id}:${name} - remote {title: '${json_name}'} does not match"
    fi

    json_filename=$(jq -M -r '.[0].filename' <<<${data})
    if [[ ${json_filename} != ${name}*.zip ]]; then
      die "vendoring ${id}:${name} - remote {filename: '${json_filename}'} does not match expectations"
    fi

    # we actually have a validated set of data, and a filename, fetch it down
    # and unpack into the build directory!
    log "downloading ${json_id}:${json_name} from ${json_filename} and unpacking"
    unzip -bD =(curl -L -H ${token} http://www.esoui.com/downloads/dl${id}/${json_filename}) -d ${build}
  fi
done

# generate the changelog and description files
if [[ -f README.md ]]; then
  ship README.md

  log "generating readme.bbcode"
  md2bbcode README.md > README.bbcode
fi

log "shipped changelog and generating changelog.bbcode"
git chglog | tee ${build}/changelog.md | md2bbcode > CHANGELOG.bbcode

log "creating the ESOUI distribution package ${zipfile}"
(cd ${build}/.. && test -d ${addon} && zip -9TXr ${release}/${zipfile} ${addon})

if [[ $IS_RELEASE_VERSION == false ]]; then
  log "fully built, in test mode"
  exit 0
fi

log "fully build, adding to distdir"
cp ${release}/${zipfile} ${distdir}
log "now upload your addon..."
