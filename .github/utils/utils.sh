#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

show_help() {
cat << EOF
Usage: $(basename "$0") <options>

    -h, --help                Display help
    -t, --type                Operation type
                                1) remove v prefix
                                2) replace '-' with '.'
                                3) get release asset upload url
                                4) update release latest
                                5) update release latest
                                6) get the ci trigger mode
    -tn, --tag-name           Release tag name
    -gr, --github-repo        Github Repo
    -gt, --github-token       Github token
EOF
}

GITHUB_API="https://api.github.com"
LATEST_REPO=JashBook/hzs-test

main() {
    local TYPE
    local TAG_NAME
    local GITHUB_REPO
    local GITHUB_TOKEN
    local TRIGGER_MODE=""

    parse_command_line "$@"

    case $TYPE in
        1)
            echo "${TAG_NAME/v/}"
        ;;
        2)
            echo "${TAG_NAME/-/.}"
        ;;
        3)
            get_upload_url
        ;;
        4)
            get_latest_tag
        ;;
        5)
            update_release_latest
        ;;
        6)
            get_trigger_mode
        ;;
        7)
            check_image_exists
        ;;
        *)
            show_help
            break
        ;;
    esac

}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            -t|--type)
                if [[ -n "${2:-}" ]]; then
                    TYPE="$2"
                    shift
                fi
                ;;
            -tn|--tag-name)
                if [[ -n "${2:-}" ]]; then
                    TAG_NAME="$2"
                    shift
                fi
                ;;
            -gr|--github-repo)
                if [[ -n "${2:-}" ]]; then
                    GITHUB_REPO="$2"
                    shift
                fi
                ;;
            -gt|--github-token)
                if [[ -n "${2:-}" ]]; then
                    GITHUB_TOKEN="$2"
                    shift
                fi
                ;;
            *)
                break
                ;;
        esac

        shift
    done
}

gh_curl() {
    curl -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3.raw" \
      $@
}

get_upload_url() {
    gh_curl -s $GITHUB_API/repos/$GITHUB_REPO/releases/tags/$TAG_NAME > release_body.json
    echo $(jq '.upload_url' release_body.json) | sed 's/\"//g'
}

update_release_latest() {
    latest_release_tag=`gh_curl -s $GITHUB_API/repos/$LATEST_REPO/releases/latest | jq -r '.tag_name'`

    release_id=`gh_curl -s $GITHUB_API/repos/$GITHUB_REPO/releases/tags/$latest_release_tag | jq -r '.id'`

    gh_curl -X PATCH \
        $GITHUB_API/repos/$GITHUB_REPO/releases/$release_id \
        -d '{"draft":false,"prerelease":false,"make_latest":true}'
}

add_trigger_mode() {
    trigger_mode=$1
    if [[ "$TRIGGER_MODE" != *"$trigger_mode"* ]]; then
        TRIGGER_MODE="["$trigger_mode"]"$TRIGGER_MODE
    fi
}

get_trigger_mode() {
    for filePath in $( git diff --name-only HEAD HEAD^ ); do

        if [[ "$filePath" == "go."* || "$filePath" == "Makefile" ]]; then
            add_trigger_mode "test"
            break
        elif [[ "$filePath" != *"/"* ]]; then
          echo $filePath
            add_trigger_mode "other"
            continue
        fi

        case $filePath in
            docs/*)
                add_trigger_mode "docs"
            ;;
            docker/*)
                add_trigger_mode "docker"
            ;;
            deploy/*)
                add_trigger_mode "deploy"
            ;;
            .github/*|.devcontainer/*|githooks/*|examples/*)
                add_trigger_mode "other"
            ;;
            *)
                add_trigger_mode "test"
                break
            ;;
        esac
    done
    echo $TRIGGER_MODE
}

check_image_exists() {
    image=registry.cn-hangzhou.aliyuncs.com/apecloud/configmap-reload:v0.5.0
    for i in {1..5}; do
        exists_flag=$(docker manifest inspect "$image" | grep digest)
        if [[ -z "$exists_flag" ]]; then
            if [[ $i -lt 5 ]]; then
                sleep 1
                continue
            fi
        else
            echo "found $exists_flag"
            break
        fi
        echo "$(tput setaf 1)$image is not exists.$(tput sgr 0)"
        EXIT_STATUS=1
    done
}

main "$@"
