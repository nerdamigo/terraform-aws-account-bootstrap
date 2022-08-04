variable "organization_prefix" {
    type = string
    description = "A string that will be used to prefix generated resources"
    validation {
        condition = lower(regex("[a-z0-9-]+", var.organization_prefix)) == var.organization_prefix
        error_message = "Prefix must consist of lowercase characters in the set { a-z, 0-9, - }"
    }
}

variable "common_tags" {
    type = map(string)
    description="Map of tags that should be applied to created resources"

    validation {
        error_message = "Missing required tag keys"
        condition = length(setsubtract(
            [] #["na:app_id", "na:app_version"] # required tag key list
            , keys(var.common_tags)
        )) == 0
    }
}

/*
variable "region_map" {
    type = map(object({ primary = bool }))
}
*/