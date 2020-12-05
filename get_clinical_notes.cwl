#!/usr/bin/env cwl-runner
#
# Run Docker Submission
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

inputs:
  - id: data_endpoint
    type: string?
  - id: output
    type: string
  - id: dataset_id
    type: string
  - id: fhir_store_id
    type: string
  - id: docker_script
    type: File

arguments: 
  - valueFrom: $(inputs.docker_script.path)
  - valueFrom: $(inputs.output)
    prefix: -o
  - valueFrom: $(inputs.data_endpoint)
    prefix: -e
  - valueFrom: $(inputs.dataset_id)
    prefix: -d
  - valueFrom: $(inputs.fhir_store_id)
    prefix: -f

requirements:
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.docker_script)
  - class: InlineJavascriptRequirement

outputs:
  notes:
    type: File
    outputBinding:
      glob: $(inputs.output)
