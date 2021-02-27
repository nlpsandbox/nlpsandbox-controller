#!/usr/bin/env cwl-runner
#
# Run Docker Submission
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [community, store-annotations]

hints:
  DockerRequirement:
    dockerPull: nlpsandbox/cli:0.4.1

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
  - id: annotation_json
    type: File
    inputBinding:
      prefix: --annotation_json
  - id: previous_step
    type: boolean?

outputs: []
