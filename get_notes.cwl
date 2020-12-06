#!/usr/bin/env cwl-runner
#
# Run Docker Submission
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [community, get-notes]

hints:
  DockerRequirement:
    dockerPull: nlpsandbox/cli:edge

requirements:
  - class: InlineJavascriptRequirement

inputs:
  - id: data_endpoint
    type: string?
    inputBinding:
      prefix: --data_node_host
  - id: dataset_id
    type: string
    inputBinding:
      prefix: --dataset_id
  - id: fhir_store_id
    type: string
    inputBinding:
      prefix: --fhir_store_id
  - id: output
    type: string
    inputBinding:
      prefix: --output

outputs:
  notes:
    type: File
    outputBinding:
      glob: $(inputs.output)
