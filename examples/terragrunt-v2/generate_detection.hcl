locals {
  user_inputs = read_terragrunt_config("common_user_inputs.hcl").inputs
  region_details = read_terragrunt_config("common_region_details.hcl").inputs

  generate_detection_tg = {
    for id, region_config in local.region_details.regions_with_global:
    "${id}-depoyment-tg" => {
      contents = templatefile("detection_template.hcl", region_config)
      path = ".generated/detection/${id}/"
      filename = "terragrunt.hcl"
    }
  }

  output_detection_tg = { for id, filedata in merge(local.generate_detection_tg):
    "${filedata.path}" => run_cmd(
      #"--terragrunt-quiet", 
      "bash", "-c", "echo \"$0\" > ${filedata.path}/${filedata.filename}", filedata.contents )
  }
}