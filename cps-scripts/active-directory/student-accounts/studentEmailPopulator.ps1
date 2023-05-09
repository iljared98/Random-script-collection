# Created by   : I. Jared
# Date Created : 5/9/2023
# Purpose      : Auto populates email fields into Powerschool from a generated CSV file.

$excludedUPNs = @("CE_STUDENT@cowetaps.com", "SS_STUDENT@cowetaps.com", "NW_Student@cowetaps.com")

$EMAIL_LIST_CSV = ""
