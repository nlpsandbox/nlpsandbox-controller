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
  - id: docker_script
    type: File

arguments: 
  - valueFrom: $(inputs.docker_script.path)
  - valueFrom: $(inputs.output)
    prefix: -o
  - valueFrom: $(inputs.data_endpoint)
    prefix: -e

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
