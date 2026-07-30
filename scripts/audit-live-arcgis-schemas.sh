#!/bin/sh

set -eu

metadata_file="$(mktemp -t dc-pulse-arcgis-metadata.XXXXXX)"
sample_file="$(mktemp -t dc-pulse-arcgis-sample.XXXXXX)"
trap 'rm -f "$metadata_file" "$sample_file"' EXIT

audit_source() {
    source_name="$1"
    endpoint="$2"
    required_fields="$3"

    curl -fsS --retry 2 --get \
        --data-urlencode "f=json" \
        "$endpoint" > "$metadata_file"

    jq -e '
        (.error == null) and
        (.geometryType == "esriGeometryPoint") and
        (.capabilities | contains("Query")) and
        (.maxRecordCount > 0)
    ' "$metadata_file" >/dev/null

    for field in $required_fields; do
        jq -e --arg field "$field" 'any(.fields[]; .name == $field)' \
            "$metadata_file" >/dev/null
    done

    out_fields="$(printf '%s' "$required_fields" | tr ' ' ',')"
    curl -fsS --retry 2 --get \
        --data-urlencode "f=json" \
        --data-urlencode "where=1=1" \
        --data-urlencode "outFields=$out_fields" \
        --data-urlencode "returnGeometry=true" \
        --data-urlencode "resultRecordCount=1" \
        "$endpoint/query" > "$sample_file"

    jq -e '
        (.error == null) and
        (.features | length == 1) and
        (.features[0].geometry.x | type == "number") and
        (.features[0].geometry.y | type == "number")
    ' "$sample_file" >/dev/null

    for field in $required_fields; do
        jq -e --arg field "$field" '.features[0].attributes | has($field)' \
            "$sample_file" >/dev/null
    done

    field_count="$(jq '.fields | length' "$metadata_file")"
    maximum_records="$(jq '.maxRecordCount' "$metadata_file")"
    printf '%s: queryable point layer, %s fields, maxRecordCount %s, required contract present\n' \
        "$source_name" "$field_count" "$maximum_records"
}

audit_source \
    "DC 311" \
    "https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/ServiceRequests/FeatureServer/21" \
    "SERVICEREQUESTID SERVICECODEDESCRIPTION SERVICETYPECODEDESCRIPTION ORGANIZATIONACRONYM ADDDATE RESOLUTIONDATE SERVICEORDERSTATUS STATUS_CODE DETAILS PRIORITY STREETADDRESS WARD EDITED LATITUDE LONGITUDE"

audit_source \
    "Building Permits" \
    "https://maps2.dcgis.dc.gov/dcgis/rest/services/FEEDS/DCRA/FeatureServer/18" \
    "PERMIT_ID PERMIT_TYPE_NAME PERMIT_SUBTYPE_NAME PERMIT_CATEGORY_NAME APPLICATION_STATUS_NAME FULL_ADDRESS DESC_OF_WORK ISSUE_DATE LASTMODIFIEDDATE WARD NEIGHBORHOODCLUSTER LATITUDE LONGITUDE FEES_PAID ZONING SSL"

audit_source \
    "DDOT Construction Permits" \
    "https://maps2.dcgis.dc.gov/dcgis/rest/services/FEEDS/DDOT/FeatureServer/48" \
    "TRACKINGNUMBER PERMITNUMBER APPLICATIONDATE ISSUEDATE EFFECTIVEDATE EXPIRATIONDATE STATUS WLFULLADDRESS PERMITTEENAME WORKDETAIL ISEXCAVATION ISFIXTURE ISPAVING ISLANDSCAPING ISPROJECTIONS ISPSRENTAL LATITUDE LONGITUDE EDITED"
