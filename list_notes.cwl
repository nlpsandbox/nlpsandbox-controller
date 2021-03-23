#!/usr/bin/env cwl-runner
#
# Get clinical notes
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [datanode, list-notes]

hints:
  DockerRequirement:
    dockerPull: nlpsandbox/cli:1.0.0

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
