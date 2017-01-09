#!/usr/bin/env bash

# ALL-INKL KAS API shell interface
# Source: https://github.com/o1oo11oo/kasapi.sh
# See https://kasapi.kasserver.com/dokumentation/phpdoc/packages/API%20Funktionen.html for function documentation

# Find directory in which this script is stored by traversing all symbolic links
SOURCE="${0}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# POST target URL
AUTHURL="$(curl -s "http://kasapi.kasserver.com/soap/wsdl/KasAuth.wsdl" | grep -oP "(?<=<soap:address location=')[^']+" | sed 's|http://|https://|')"
APIURL="$(curl -s "http://kasapi.kasserver.com/soap/wsdl/KasApi.wsdl" | grep -oP "(?<=<soap:address location=')[^']+" | sed 's|http://|https://|')"

# Request template
AUTHREQUEST='<?xml version="1.0" encoding="UTF-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:xmethodsKasApiAuthentication" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:KasAuth><Params xsi:type="xsd:string">{"KasUser":"USER","KasAuthType":"sha1","KasPassword":"PWHASH","SessionLifeTime":SESSIONLIFE,"SessionUpdateLifeTime":"SESSIONUPDATE"}</Params></ns1:KasAuth></SOAP-ENV:Body></SOAP-ENV:Envelope>'
APIREQUEST='<?xml version="1.0" encoding="UTF-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:xmethodsKasApi" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:KasApi><Params xsi:type="xsd:string">{"KasUser":"USER","KasAuthType":"AUTHTYPE","KasAuthData":"AUTHDATA","KasRequestType":"REQUESTTYPE","KasRequestParams":PARAMS}</Params></ns1:KasApi></SOAP-ENV:Body></SOAP-ENV:Envelope>'

# Default config values
session_lifetime="1800"
session_update_lifetime="Y"

_exiterr() {
  echo "ERROR: ${1}" >&2
  exit 1
}

# Get config
if [[ -f "${SCRIPTDIR}/config" ]]; then
	. "${SCRIPTDIR}/config"
elif [[ -f "${SCRIPTDIR}/config.sh" ]]; then
	. "${SCRIPTDIR}/config.sh"
else
	_exiterr "No config file found"
fi

# Verify login credentials
[[ -z "${kas_user}" ]] && _exiterr '${kas_user}'" not found in config."
if [[ -z "${kas_pass}" && -z "${kas_pass_hash}" ]]; then
    _exiterr '${kas_pass} or ${kass_pass_hash}'" not found in config."
elif [[ -z "${kas_pass_hash}" ]]; then
    kas_pass_hash="$(printf "%s" "${kas_pass}" | sha1sum | awk '{print $1}')"
fi

command_help() {
    local helptext
    read -r -d '' helptext <<"ENDL"
Usage: KASAPISH [-h] [command [argument]] [parameter [argument]] [parameter [argument]] ...

Default command: help

Commands:
 --help (-h)                    Show this help text
 --login (-l)                   Login to ALL-INKL and get a session token
 --function (-f)                API Function to call

Parameters:
 --no-session (-n)              Don't use/create session token for API request (default)
 --session (-s)                 Use/create session token, send request and return new token with result (if one got created)
 --token (-t)                   API session token for continuous API requests (implies --session)
 --params (-p)                  JSON formatted function parameters (defaults to "{}")
ENDL

    helptext="${helptext/KASAPISH/${0}}"
    echo "${helptext}"
}

# login to ALL-INKL
command_login() {
    # build login request
    local authreq="${AUTHREQUEST}"
    authreq="${authreq/USER/${kas_user}}"
    authreq="${authreq/PWHASH/${kas_pass_hash}}"
    authreq="${authreq/SESSIONLIFE/${session_lifetime}}"
    authreq="${authreq/SESSIONUPDATE/${session_update_lifetime}}"

    # send login request and receive session token
    login_response=$(curl -s -X POST -H "Content-Type: text/xml" -H "SOAPAction: \"urn:xmethodsKasApiAuthentication#KasAuth\"" --data "${authreq}" "${AUTHURL}")
    session_token=$(<<<"${login_response}" grep -oP "(?<=<return xsi:type=\"xsd:string\">)[^<]+")
    faultstring=$(<<<"${login_response}" grep -oP "(?<=<faultstring>)[^<]+")

    # check if login was successful
    [[ -n "${faultstring}" ]] && _exiterr "Login failed, faultstring: ${faultstring}"
    echo "${session_token}"
}

# make API request
command_api_request() {
    # check required parameters
    [[ -z "${PARAM_FUNCTION}" ]] && _exiterr "Missing parameter: --function"
    [[ -z "${PARAM_PARAMS}" ]] && PARAM_PARAMS="{}"

    # wait for KasFloodDelay
    if [[ -f "${SCRIPTDIR}/next_request_timestamp" && "$(<"${SCRIPTDIR}/next_request_timestamp")" -gt "$(date +%s%3N)" ]]; then
        local diff="$(($(<"${SCRIPTDIR}/next_request_timestamp")-$(date +%s%3N)))"
        sleep "$(awk "BEGIN {printf \"%.1f\",${diff}/1000}")"
    fi

    # build API request
    local apireq="${APIREQUEST}"
    apireq="${apireq/USER/${kas_user}}"
    apireq="${apireq/REQUESTTYPE/${PARAM_FUNCTION}}"
    apireq="${apireq/PARAMS/${PARAM_PARAMS}}"

    # add authentication parameters depending on the method
    if [[ "${PARAM_SESSION}" != "yes" ]]; then
        apireq="${apireq/AUTHTYPE/sha1}"
        apireq="${apireq/AUTHDATA/${kas_pass_hash}}"
    else
        if [[ -z "${PARAM_TOKEN}" ]]; then
            PARAM_TOKEN="$(command_login)"
            echo "session_token: ${PARAM_TOKEN}"
        fi
        apireq="${apireq/AUTHTYPE/session}"
        apireq="${apireq/AUTHDATA/${PARAM_TOKEN}}"
    fi

    # send API request and receive response
    response=$(curl -s -X POST -H "Content-Type: text/xml" -H "SOAPAction: \"urn:xmethodsKasApi#KasApi\"" --data "${apireq}" "${APIURL}")
    faultstring=$(<<<"${response}" grep -oPm1 "(?<=<faultstring>)[^<]+")

    # save new KasFloodDelay
    flood_delay_ms="$(awk "BEGIN {printf \"%.0f\",$(<<<"${response}" grep -oP '(?<=KasFloodDelay</key><value xsi:type="xsd:(?:int">)|(?:float">))[^<]+')*1000}")"
    printf "%s" "$(($(date +%s%3N) + flood_delay_ms))" > "${SCRIPTDIR}/next_request_timestamp"

    # check if request was successful
    [[ -n "${faultstring}" ]] && _exiterr "Request failed, faultstring: ${faultstring}"
    echo "${response}"
}

main() {
    COMMAND=""
    set_command() {
        [[ -z "${COMMAND}" ]] || _exiterr "Only one command can be executed at a time. See help (-h) for more information."
        COMMAND="${1}"
    }

    check_parameters() {
        if [[ -z "${1:-}" ]]; then
            echo "The specified command requires additional parameters. See help:" >&2
            echo >&2
            command_help >&2
            exit 1
        elif [[ "${1:0:1}" = "-" ]]; then
            _exiterr "Invalid argument: ${1}"
        fi
    }

    [[ -z "${@}" ]] && eval set -- "--help"

    while (( ${#} )); do
        case "${1}" in
            --help|-h)
                command_help
                exit 0
                ;;

            --login|-l)
                set_command "login"
                ;;

            --function|-f)
                shift 1
                set_command "api_request"
                check_parameters "${1:-}"
                PARAM_FUNCTION="${1}"
                ;;

            --no-session|-n)
                [[ "${PARAM_SESSION}" = "yes" ]] && _exiterr "Invalid parameter combination: --no-session can't be used with --session or --token"
                PARAM_SESSION="no"
                ;;

            --session|-s)
                [[ "${PARAM_SESSION}" = "no" ]] && _exiterr "Invalid parameter combination: --session can't be used with --no-session"
                PARAM_SESSION="yes"
                ;;

            --token|-t)
                [[ "${PARAM_SESSION}" = "no" ]] && _exiterr "Invalid parameter combination: --token can't be used with --no-session"
                shift 1
                check_parameters "${1:-}"
                PARAM_TOKEN="${1}"
                PARAM_SESSION="yes"
                ;;

            --params|-p)
                shift 1
                check_parameters "${1:-}"
                PARAM_PARAMS="${1}"
                ;;

            *)
                echo "Unknown parameter detected: ${1}" >&2
                echo >&2
                command_help >&2
                exit 1
                ;;
        esac

        shift 1
    done

    case "${COMMAND}" in
        login) command_login;;
        api_request) command_api_request;;
        *) command_help; exit 1;;
    esac
}

main "${@:-}"
