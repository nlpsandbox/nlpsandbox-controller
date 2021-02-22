#!/usr/bin/env cwl-runner
#
# Create an annotation json with dataset name, dataset version and api version
#
cwlVersion: v1.0
class: CommandLineTool
# Needs a basecommand, so use echo as a hack
baseCommand: echo

inputs:
  - id: dataset_name
    type: string
  - id: dataset_version
    type: string
  - id: api_version
    type: string

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: update_status.json
        entry: |
          {"dataset_version": \"$(inputs.dataset_version)\",
           "dataset_name": \"$(inputs.dataset_name)\",
           "api_version": \"$(inputs.api_version)\"}

outputs:
  - id: json_out
    type: File
    outputBinding:
      glob: update_status.json
  - id: dataset_id
    type: string
    outputBinding:
      outputEval: $(inputs.dataset_name)-$(inputs.dataset_version)