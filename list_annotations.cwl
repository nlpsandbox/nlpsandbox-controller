#!/usr/bin/env cwl-runner
#
# List annotation store annotations
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [datanode, list-annotations]

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
  - id: annotation_store_id
    type: string
    inputBinding:
      prefix: --annotation_store_id
  - id: output
    type: string
    inputBinding:
      prefix: --output

outputs:
  annotations:
    type: File
    outputBinding:
      glob: $(inputs.output)
